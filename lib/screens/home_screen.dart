import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../config/audio_config.dart';
import '../models/hizb.dart';
import '../services/hizb_service.dart';
import '../services/khatma_calculator.dart';
import '../services/links_service.dart';
import '../theme/app_theme.dart';
import '../widgets/hizb_card.dart';
import 'hizb_detail_screen.dart';
import 'pdf_viewer_screen.dart';
import 'settings_screen.dart';
import 'account_screen.dart';
import 'khatma_hub_screen.dart';
import '../services/wird_service.dart';
import '../services/account_service.dart';
import '../services/group_service.dart';
import '../services/audio_download_service.dart';
import '../services/reading_progress.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<Hizb>?          _ahzab;
  Map<int, HizbLinks>  _links     = {};
  List<int>            _todayNums = [];
  DateTime             _date      = DateTime.now();
  bool                 _loading   = true;
  String?              _error;
  int?                 _participants;   // إجمالي المشاركين اليوم (ختمة الإدارة + المجموعات)
  int                  _groupsCount = 0; // عدد مجموعات المستخدم
  Set<String>          _readToday = {}; // أحزاب قرأها المستخدم اليوم ('hizb:N')
  Set<int>             _audioSet  = {}; // الأحزاب التي رُفعت تلاوتها (mp3) على الخادم
  Set<int>             _downloaded = {}; // الأحزاب المنزّلة للاستماع دون إنترنت
  Set<int>             _cachedPT  = {}; // أحزاب لها أوقات صفحات محفوظة محلياً
  ({int hizb, int page})? _resume; // آخر موضع قراءة غير مكتمل (لاستئنافه)
  RealtimeChannel?     _partChannel;    // بثّ لحظي لعدّاد المشاركين
  Timer?               _partTimer;      // تحديث دوري للعدّاد (يعمل بلا تسجيل دخول)

  // لالتقاط صورة الشاشة عند المشاركة
  final GlobalKey _shotKey = GlobalKey();

  // ── أسماء الأيام والشهور بالعربية ──
  static const _days   = ['', 'الاثنين','الثلاثاء','الأربعاء','الخميس','الجمعة','السبت','الأحد'];
  static const _months = ['','يناير','فبراير','مارس','أبريل','مايو','يونيو',
                            'يوليو','أغسطس','سبتمبر','أكتوبر','نوفمبر','ديسمبر'];

  @override
  void initState() {
    super.initState();
    _loadData();
    _loadParticipants();
    _loadReadToday();
    _loadGroupsCount();
    _loadAudioStatus();
    _loadResume();
    _subscribeParticipants();
    // تحديث دوري كل 10 ثوانٍ — مسار موثوق يعمل بلا تسجيل دخول (لا يخضع لقيود RLS)
    _partTimer = Timer.periodic(const Duration(seconds: 10), (_) => _loadParticipants());
  }

  @override
  void dispose() {
    _partTimer?.cancel();
    if (_partChannel != null) Supabase.instance.client.removeChannel(_partChannel!);
    super.dispose();
  }

  // بثّ لحظي: يُحدّث العدّاد فور قراءة أي شخص حزباً (ورد الإدارة أو مجموعة)
  void _subscribeParticipants() {
    try {
      final sb = Supabase.instance.client;
      _partChannel = sb
          .channel('home_participants')
          .onPostgresChanges(
              event: PostgresChangeEvent.all,
              schema: 'public',
              table: 'group_reads',
              callback: (_) => _loadParticipants())
          .onPostgresChanges(
              event: PostgresChangeEvent.all,
              schema: 'public',
              table: 'wird_log',
              callback: (_) => _loadParticipants())
          .subscribe();
    } catch (_) {}
  }

  // عدد المشاركين اليوم (يعمل بدون تسجيل دخول؛ يُخفى عند الفشل أو الصفر)
  Future<void> _loadParticipants() async {
    try {
      final n = await WirdService.todaysParticipants();
      if (mounted) setState(() => _participants = n);
    } catch (_) {}
  }

  // عدد مجموعات المستخدم (لعرضه بين قوسين على زر المجموعات)
  Future<void> _loadGroupsCount() async {
    if (!AccountService.isLoggedIn) {
      if (mounted && _groupsCount != 0) setState(() => _groupsCount = 0);
      return;
    }
    try {
      final gs = await GroupService.myGroups();
      // لا تُحسب المجموعات التي لا تزال مشروعاً (أقل من 10 أعضاء)
      final n = gs.where((g) => g.memberCount >= 10).length;
      if (mounted) setState(() => _groupsCount = n);
    } catch (_) {}
  }

  // الأحزاب التي قرأها المستخدم اليوم (لعرض علامة ✓ على البطاقات)
  Future<void> _loadReadToday() async {
    if (!AccountService.isLoggedIn) return;
    try {
      final s = await WirdService.today();
      if (mounted) setState(() => _readToday = s);
    } catch (_) {}
  }

  // حالة الصوت: أي أحزاب متاحة للتلاوة وأيّها منزّلة (لعرض الأيقونات على البطاقات)
  Future<void> _loadAudioStatus() async {
    try {
      final remote = await AudioDownloadService.remoteAudioSet();
      final down   = await AudioDownloadService.downloadedSet();
      final cached = await AudioDownloadService.cachedPageTimesSet();
      if (mounted) setState(() { _audioSet = remote; _downloaded = down; _cachedPT = cached; });
    } catch (_) {}
  }

  Future<void> _loadData() async {
    try {
      // الأحزاب من الـ assets المحلية (فوري) — لا نُعلّق الواجهة على الشبكة
      final ahzab = await HizbService.loadAhzab();
      if (!mounted) return;
      setState(() {
        _ahzab     = ahzab;
        _todayNums = KhatmaCalculator.getHizbsForDate(_date);
        _loading   = false;
      });
      // الروابط (يوتيوب + Supabase) في الخلفية مع مهلة — لا تُعطّل الإقلاع
      _loadLinks();
    } catch (e) {
      if (!mounted) return;
      setState(() { _error = e.toString(); _loading = false; });
    }
  }

  // تحميل الروابط بلا حجب الواجهة؛ عند الفشل/المهلة تكفي الروابط الاحتياطية من ahzab.json
  Future<void> _loadLinks() async {
    try {
      final links = await LinksService.load()
          .timeout(const Duration(seconds: 10));
      if (!mounted) return;
      setState(() => _links = links);
    } catch (_) {
      // تجاهُل: youtube من ahzab.json و PDF محلي — التطبيق يعمل دون هذه الروابط
    }
  }

  void _changeDate(DateTime d) {
    setState(() {
      _date      = d;
      _todayNums = KhatmaCalculator.getHizbsForDate(d);
    });
  }

  bool get _isToday {
    final n = DateTime.now();
    return _date.year == n.year && _date.month == n.month && _date.day == n.day;
  }

  bool get _isFriday => _date.weekday == DateTime.friday;

  // ════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    if (_loading) return const _LoadingScreen();
    if (_error != null) return _ErrorScreen(error: _error!);

    return RepaintBoundary(
      key: _shotKey,
      child: Scaffold(
        backgroundColor: AppTheme.background,
        body: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            _buildAppBar(),
            SliverToBoxAdapter(child: _buildBody()),
          ],
        ),
      ),
    );
  }

  // ── AppBar ──
  Widget _buildAppBar() {
    return SliverAppBar(
      floating:      true,
      pinned:        true,
      snap:          true,
      expandedHeight: 0,
      backgroundColor: AppTheme.primary,
      title: const Text(
        'القرآن الكريم - ختمة الإدارة',
        style: TextStyle(
          color: Colors.white,
          fontSize: 17,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.3,
        ),
      ),
      actions: [
        IconButton(
          tooltip: 'مشاركة ورد اليوم',
          icon: const Icon(Icons.share_rounded, color: Colors.white),
          onPressed: _shareWird,
        ),
        IconButton(
          tooltip: 'اختر تاريخاً',
          icon: const Icon(Icons.calendar_month_rounded, color: Colors.white),
          onPressed: _pickDate,
        ),
        IconButton(
          tooltip: 'حسابي',
          icon: const Icon(Icons.account_circle_rounded, color: Colors.white),
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const AccountScreen()),
          ),
        ),
        IconButton(
          tooltip: 'الإعدادات',
          icon: const Icon(Icons.settings_rounded, color: Colors.white),
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const SettingsScreen()),
          ),
        ),
      ],
    );
  }

  // ── بطاقتا ختمتي / المجموعات (مميّزة: تتطلب تسجيل دخول) ──
  Widget _buildAccountCards() {
    final loggedIn = AccountService.isLoggedIn;
    final readCount = loggedIn
        ? _todayNums.where((n) => _readToday.contains('hizb:$n')).length
        : 0;
    return Row(
      children: [
        Expanded(
          child: _HubCard(
            icon: Icons.auto_stories_rounded,
            title: 'ختمتي',
            badgeCount: readCount,
            loggedIn: loggedIn,
            onTap: () async {
              await Navigator.push(context, _slide(const MyKhatmaHubScreen()));
              if (mounted) { _loadReadToday(); _loadParticipants(); }
            },
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _HubCard(
            icon: Icons.groups_rounded,
            title: (loggedIn && _groupsCount > 0) ? 'المجموعات ($_groupsCount)' : 'المجموعات',
            loggedIn: loggedIn,
            onTap: () async {
              await Navigator.push(context, _slide(const GroupsHubScreen()));
              if (mounted) { _loadReadToday(); _loadParticipants(); _loadGroupsCount(); }
            },
          ),
        ),
      ],
    );
  }

  // ── مشاركة ورد اليوم: صورة الشاشة + النص + روابط يوتيوب و PDF ──
  Future<void> _shareWird() async {
    final ahzab = _ahzab;
    if (ahzab == null) return;
    final hizbs   = HizbService.findMultiple(ahzab, _todayNums);
    final dateStr =
        '${_days[_date.weekday]} ${_date.day} ${_months[_date.month]} ${_date.year}';

    final buf = StringBuffer()
      ..writeln('القرآن الكريم - ختمة الإدارة')
      ..writeln()
      ..writeln('📖 ورد $dateStr:')
      ..writeln();
    for (final h in hizbs) {
      buf.writeln('• الحزب ${h.number}: ${h.rangeFull}');
      if (h.youtube.isNotEmpty) buf.writeln('   ▶️ استماع: ${h.youtube}');
      if (h.pdf.isNotEmpty)     buf.writeln('   📄 مصحف: ${h.pdf}');
      buf.writeln();
    }
    final text = buf.toString().trim();

    // التقاط صورة الشاشة الحالية
    XFile? shot;
    try {
      final boundary =
          _shotKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary != null) {
        final image = await boundary.toImage(pixelRatio: 2.0);
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        if (bytes != null) {
          final file = await File(
            '${Directory.systemTemp.path}/wird_share.png',
          ).writeAsBytes(bytes.buffer.asUint8List());
          shot = XFile(file.path, mimeType: 'image/png');
        }
      }
    } catch (_) {
      // تعذّر التقاط الصورة — نشارك النص فقط
    }

    if (shot != null) {
      await SharePlus.instance.share(ShareParams(
          files: [shot], text: text, subject: 'القرآن الكريم - ختمة الإدارة'));
    } else {
      await SharePlus.instance.share(
          ShareParams(text: text, subject: 'القرآن الكريم - ختمة الإدارة'));
    }
  }

  // ── جسم الشاشة ──
  Widget _buildBody() {
    final hizbs = HizbService.findMultiple(_ahzab!, _todayNums);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 80),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildDateCard(),
          const SizedBox(height: 8),
          if (_resume != null && _resume!.page < 8) ...[
            _buildResumeCard(),
            const SizedBox(height: 8),
          ],
          _buildMushafCard(),
          const SizedBox(height: 8),
          _buildAccountCards(),
          const SizedBox(height: 8),
          if (_isFriday) ...[_buildFridayBanner(), const SizedBox(height: 8)],
          const SizedBox(height: 4),
          // أحزاب اليوم، وبطاقة دعاء الختمة تُدرَج مباشرة بعد الحزب 60 (بينه والحزب 1)
          for (final e in hizbs.asMap().entries) ...[
            _hizbCard(e.value, e.key + 1),
            if (e.value.number == 60) _buildKhatmaDuaaCard(),
          ],
        ],
      ),
    );
  }

  // بطاقة استئناف القراءة — تظهر إن توقّف المستخدم قبل الصفحة الأخيرة
  Widget _buildResumeCard() {
    final r = _resume!;
    return GestureDetector(
      onTap: _resumeReading,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [AppTheme.primaryDk, AppTheme.primary],
            begin: Alignment.topRight, end: Alignment.bottomLeft,
          ),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.18),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 26),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('أكمل القراءة',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 15)),
                const SizedBox(height: 2),
                Text('توقّفت عند الحزب ${r.hizb} — الصفحة ${r.page}',
                    style: const TextStyle(color: Colors.white70, fontSize: 12)),
              ],
            ),
          ),
          const Icon(Icons.chevron_left_rounded, color: Colors.white, size: 24),
        ]),
      ),
    );
  }

  Widget _hizbCard(Hizb h, int dayIndex) {
    final lnk = LinksService.find(_links, h.number);
    final ytUrl = lnk?.youtube.isNotEmpty == true ? lnk!.youtube : h.youtube;
    final isDown = _downloaded.contains(h.number);
    return HizbCard(
      hizb:         h,
      dayIndex:     dayIndex,
      onTap:        () => _openDetail(h),
      onYoutube:    ytUrl.isNotEmpty ? () => _launch(ytUrl) : null,
      hasAudio:     _audioSet.contains(h.number) || isDown,
      hasPageTimes: (lnk?.pageTimes.isNotEmpty ?? false) || _cachedPT.contains(h.number),
      isDownloaded: isDown,
    );
  }

  // بطاقة دعاء ختم القرآن (تظهر يوم إتمام الختمة) — قراءة مع تلاوة (62.mp3)
  Widget _buildKhatmaDuaaCard() {
    return GestureDetector(
      onTap: () => Navigator.push(context, _slide(const PdfViewerScreen(
          title: 'دعاء ختم القرآن',
          assetPath: 'assets/pdf/douaa.pdf',
          audioNumber: AudioConfig.khatmaDuaa))),
      child: Container(
        margin: const EdgeInsets.only(top: 8, bottom: 12),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [AppTheme.primaryDk, AppTheme.primary],
            begin: Alignment.topRight, end: Alignment.bottomLeft),
          borderRadius: BorderRadius.circular(14),
          boxShadow: [BoxShadow(color: AppTheme.primary.withOpacity(0.30), blurRadius: 10, offset: const Offset(0, 4))],
        ),
        child: Row(children: [
          Container(
            width: 44, height: 44,
            alignment: Alignment.center,
            decoration: const BoxDecoration(color: Colors.white24, shape: BoxShape.circle),
            child: const Text('🤲', style: TextStyle(fontSize: 24)),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('دعاء ختم القرآن الكريم',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 15)),
              SizedBox(height: 3),
              Text('اكتملت الختمة اليوم — اضغط لقراءة الدعاء',
                  style: TextStyle(color: Colors.white70, fontSize: 12)),
            ]),
          ),
          const Icon(Icons.chevron_left_rounded, color: Colors.white),
        ]),
      ),
    );
  }

  // ── بطاقة التاريخ ──
  Widget _buildDateCard() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppTheme.primaryDk, AppTheme.primary, AppTheme.primaryLt],
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primary.withOpacity(0.35),
            blurRadius: 16,
            offset: const Offset(0, 7),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── السطر العلوي ──
          Row(
            children: [
              Expanded(
                child: Text(
                  _isToday
                      ? '🟢 شارك اليوم ${_participants ?? 0} في الختمات'
                      : 'التاريخ المختار',
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                ),
              ),
              if (!_isToday)
                _Chip(
                  label: 'العودة لليوم',
                  onTap: () => _changeDate(DateTime.now()),
                ),
            ],
          ),
          const SizedBox(height: 4),
          // ── اسم اليوم والتاريخ ──
          Text(
            '${_days[_date.weekday]} ${_date.day} ${_months[_date.month]} ${_date.year}',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  // ── بطاقة المصحف الكامل + ليلة الختمة ──
  Widget _buildMushafCard() {
    return Row(
      children: [
        Expanded(
          child: _MiniCard(
            icon: Icons.menu_book_rounded,
            iconColor: AppTheme.primary,
            title: 'المصحف الكامل',
            onTap: () => Navigator.push(
              context,
              _slide(_AllHizbsScreen(ahzab: _ahzab!, links: _links)),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _MiniCard(
            icon: Icons.nights_stay_rounded,
            iconColor: AppTheme.gold,
            title: 'ليالي الختمة',
            onTap: () => Navigator.push(
              context,
              _slide(const _KhatmaNightsScreen()),
            ),
          ),
        ),
      ],
    );
  }

  // ── بطاقة سورة الكهف (يوم الجمعة) — قراءة مع تلاوة (61.mp3) ──
  Widget _buildFridayBanner() {
    return GestureDetector(
      onTap: () => Navigator.push(context, _slide(const PdfViewerScreen(
          title: 'سورة الكهف',
          assetPath: 'assets/pdf/kahf.pdf',
          audioNumber: AudioConfig.kahf))),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppTheme.goldLight,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppTheme.gold.withOpacity(0.45)),
        ),
        child: Row(
          children: [
            Container(
              width: 44, height: 44,
              decoration: BoxDecoration(
                color: AppTheme.gold.withOpacity(0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.auto_stories_rounded, color: AppTheme.gold),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('🌟 يوم الجمعة المبارك',
                      style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                  SizedBox(height: 3),
                  Text('اضغط لقراءة سورة الكهف',
                      style: TextStyle(fontSize: 12, color: AppTheme.textMed)),
                ],
              ),
            ),
            const Icon(Icons.chevron_left_rounded, color: AppTheme.gold),
          ],
        ),
      ),
    );
  }

  // ── عنوان قسم ──
  Widget _buildSectionTitle(String title, String sub) {
    return Row(
      children: [
        Container(
          width: 4, height: 20,
          decoration: BoxDecoration(
            color: AppTheme.primary,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 8),
        Text(title,
          style: const TextStyle(
            fontSize: 18, fontWeight: FontWeight.w700, color: AppTheme.textHigh,
          ),
        ),
        const Spacer(),
        Text(sub, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }

  // ── اختيار التاريخ ──
  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context:     context,
      initialDate: _date,
      firstDate:   DateTime(2020),
      lastDate:    DateTime(2035),
      locale:      const Locale('ar'),
      builder:     (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.light(primary: AppTheme.primary),
        ),
        child: child!,
      ),
    );
    if (picked != null) _changeDate(picked);
  }

  void _openDetail(Hizb hizb) async {
    final lnk = LinksService.find(_links, hizb.number);
    await Navigator.push(context, _slide(HizbDetailScreen(hizb: hizb, links: lnk)));
    _loadResume(); // قد يكون المستخدم قرأ جزءاً من الحزب
  }

  // آخر موضع قراءة غير مكتمل (لعرض زر «أكمل القراءة»)
  Future<void> _loadResume() async {
    final r = await ReadingProgress.get();
    if (mounted) setState(() => _resume = r);
  }

  // فتح الحزب على الصفحة التي توقّف عندها المستخدم
  void _resumeReading() async {
    final r = _resume;
    if (r == null) return;
    final lnk = _ahzab == null ? null : LinksService.find(_links, r.hizb);
    await Navigator.push(context, _slide(PdfViewerScreen(
      title: 'الحزب ${r.hizb}',
      hizbNumber: r.hizb,
      initialPage: r.page,
      hizbLinks: lnk,
    )));
    _loadResume();
  }

  Future<void> _launch(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  Route _slide(Widget page) => PageRouteBuilder(
    pageBuilder: (_, a, __) => page,
    transitionsBuilder: (_, a, __, child) => SlideTransition(
      position: Tween(
        begin: const Offset(1, 0),
        end: Offset.zero,
      ).animate(CurvedAnimation(parent: a, curve: Curves.easeOutCubic)),
      child: child,
    ),
    transitionDuration: const Duration(milliseconds: 280),
  );
}

// ════════════════════════════════════════════
//  بطاقة مميّزة (خضراء) لِـ ختمتي / المجموعات — تُشير إلى الحاجة لتسجيل الدخول
class _HubCard extends StatelessWidget {
  final IconData     icon;
  final String       title;
  final int          badgeCount;
  final bool         loggedIn;
  final VoidCallback onTap;
  const _HubCard({
    required this.icon,
    required this.title,
    required this.loggedIn,
    required this.onTap,
    this.badgeCount = 0,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [AppTheme.primaryDk, AppTheme.primaryLt],
            begin: Alignment.topRight,
            end: Alignment.bottomLeft,
          ),
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: AppTheme.primary.withOpacity(0.30),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 38, height: 38,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.18),
                shape: BoxShape.circle,
              ),
              child: badgeCount > 0
                  ? Center(
                      child: Text('$badgeCount',
                          style: const TextStyle(
                              color: Colors.white, fontWeight: FontWeight.w800, fontSize: 17)))
                  : Icon(icon, color: Colors.white, size: 19),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(title,
                      style: const TextStyle(
                          fontSize: 13, fontWeight: FontWeight.w800, color: Colors.white)),
                  if (!loggedIn)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Row(
                        children: [
                          const Icon(Icons.lock_outline_rounded, size: 11, color: Colors.white70),
                          const SizedBox(width: 3),
                          Text('تسجيل الدخول',
                              style: TextStyle(fontSize: 10, color: Colors.white.withOpacity(0.8))),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════
class _Chip extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const _Chip({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white24,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(label, style: const TextStyle(color: Colors.white, fontSize: 11)),
    ),
  );
}

// ════════════════════════════════════════════
//  شاشة المصحف الكامل — قائمة الأحزاب الستين
// ════════════════════════════════════════════
class _AllHizbsScreen extends StatefulWidget {
  final List<Hizb>         ahzab;
  final Map<int, HizbLinks> links;
  const _AllHizbsScreen({required this.ahzab, required this.links});

  @override
  State<_AllHizbsScreen> createState() => _AllHizbsScreenState();
}

class _AllHizbsScreenState extends State<_AllHizbsScreen> {
  Set<int> _downloaded = {};
  Set<int> _audioSet = {}; // الأحزاب التي رُفعت تلاوتها (mp3) على الخادم
  Set<int> _cachedPT = {}; // أحزاب لها أوقات صفحات محفوظة محلياً
  bool _bulkBusy = false;  // تنزيل/حذف جماعي جارٍ
  int _bulkDone = 0;
  int _bulkTotal = 0;

  @override
  void initState() {
    super.initState();
    _loadDownloaded();
    _loadAudioSet();
    _loadCachedPT();
  }

  Future<void> _loadCachedPT() async {
    final s = await AudioDownloadService.cachedPageTimesSet();
    if (mounted) setState(() => _cachedPT = s);
  }

  // تنزيل كل التلاوات المتاحة غير المنزّلة (مع حفظ أوقات الصفحات)
  Future<void> _downloadAll() async {
    final targets = _audioSet.where((h) => !_downloaded.contains(h)).toList()..sort();
    if (targets.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('كل التلاوات المتاحة منزّلة بالفعل')));
      return;
    }
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('تنزيل الكل'),
        content: Text('تنزيل ${targets.length} تلاوة للاستماع دون إنترنت؟ قد يستهلك بيانات ومساحة تخزين.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primary),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('تنزيل', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (ok != true) return;
    setState(() { _bulkBusy = true; _bulkDone = 0; _bulkTotal = targets.length; });
    for (final h in targets) {
      final done = await AudioDownloadService.download(h);
      if (done) {
        _downloaded.add(h);
        final pt = widget.links[h]?.pageTimes ?? const <int>[];
        if (pt.isNotEmpty) await AudioDownloadService.savePageTimes(h, pt);
      }
      if (!mounted) return;
      setState(() => _bulkDone++);
    }
    if (!mounted) return;
    setState(() => _bulkBusy = false);
    ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('اكتمل التنزيل ($_bulkDone/$_bulkTotal)')));
  }

  // حذف جميع التلاوات المنزّلة
  Future<void> _deleteAllDownloads() async {
    if (_downloaded.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('لا توجد تلاوات منزّلة')));
      return;
    }
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('حذف جميع التلاوات'),
        content: Text('حذف جميع التلاوات المنزّلة (${_downloaded.length})؟ يمكنك تنزيلها لاحقاً.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('حذف الكل', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (ok != true) return;
    final had = _downloaded.toList();
    await AudioDownloadService.deleteAll();
    for (final h in had) {
      await AudioDownloadService.clearPageTimes(h);
    }
    if (!mounted) return;
    setState(() => _downloaded = {});
    ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('حُذفت جميع التلاوات المنزّلة')));
  }

  Future<void> _loadDownloaded() async {
    final set = await AudioDownloadService.downloadedSet();
    if (mounted) setState(() => _downloaded = set);
  }

  Future<void> _loadAudioSet() async {
    final set = await AudioDownloadService.remoteAudioSet();
    if (mounted) setState(() => _audioSet = set);
  }

  void _openDetail(BuildContext context, Hizb hizb) async {
    final lnk = widget.links[hizb.number];
    await Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (_, a, __) => HizbDetailScreen(hizb: hizb, links: lnk),
        transitionsBuilder: (_, a, __, child) => SlideTransition(
          position: Tween(begin: const Offset(1, 0), end: Offset.zero)
              .animate(CurvedAnimation(parent: a, curve: Curves.easeOutCubic)),
          child: child,
        ),
        transitionDuration: const Duration(milliseconds: 280),
      ),
    );
    // قد يكون المستخدم نزّل/حذف تلاوة أثناء التصفح — حدّث المؤشّرات
    _loadDownloaded();
  }

  Future<void> _deleteDownload(Hizb hizb) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('حذف التلاوة'),
        content: Text('حذف تلاوة الحزب ${hizb.number} المنزّلة؟ يمكنك تنزيلها لاحقاً.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('حذف', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await AudioDownloadService.delete(hizb.number);
    if (mounted) setState(() => _downloaded.remove(hizb.number));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('حُذفت تلاوة الحزب ${hizb.number}')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: AppTheme.primary,
        foregroundColor: Colors.white,
        title: const Text('المصحف الكامل',
            style: TextStyle(fontWeight: FontWeight.w700)),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        actions: _bulkBusy
            ? [
                Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    child: Text('$_bulkDone/$_bulkTotal',
                        style: const TextStyle(fontWeight: FontWeight.w700)),
                  ),
                ),
              ]
            : [
                IconButton(
                  icon: const Icon(Icons.download_for_offline_outlined),
                  tooltip: 'تنزيل جميع التلاوات',
                  onPressed: _downloadAll,
                ),
                IconButton(
                  icon: const Icon(Icons.delete_sweep_outlined),
                  tooltip: 'حذف جميع التلاوات المنزّلة',
                  onPressed: _deleteAllDownloads,
                ),
              ],
        bottom: _bulkBusy
            ? PreferredSize(
                preferredSize: const Size.fromHeight(3),
                child: LinearProgressIndicator(
                  value: _bulkTotal == 0 ? null : _bulkDone / _bulkTotal,
                  backgroundColor: Colors.white24,
                  color: Colors.white,
                  minHeight: 3,
                ),
              )
            : null,
      ),
      body: ListView.builder(
        padding: EdgeInsets.fromLTRB(
            16, 12, 16, 28 + MediaQuery.of(context).viewPadding.bottom),
        itemCount: widget.ahzab.length,
        itemBuilder: (ctx, i) {
          final hizb = widget.ahzab[i];
          final lnk  = widget.links[hizb.number];
          // علامة التشغيل: فقط إن وُجدت تلاوة mp3 لهذا الحزب على الخادم أو منزّلة
          final hasAudio = _audioSet.contains(hizb.number) || _downloaded.contains(hizb.number);
          // علامة تقسيم الصفحات: من الروابط أو من النسخة المحلية (تعمل دون إنترنت)
          final hasPageTimes =
              (lnk?.pageTimes.isNotEmpty ?? false) || _cachedPT.contains(hizb.number);
          final isDownloaded = _downloaded.contains(hizb.number);

          return GestureDetector(
            onTap: () => _openDetail(context, hizb),
            child: Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: AppTheme.surface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFE8E4DF)),
              ),
              child: Row(
                children: [
                  // رقم الحزب
                  CircleAvatar(
                    radius: 22,
                    backgroundColor: AppTheme.primary.withOpacity(0.1),
                    child: Text(
                      '${hizb.number}',
                      style: const TextStyle(
                          color: AppTheme.primary,
                          fontWeight: FontWeight.w700,
                          fontSize: 14),
                    ),
                  ),
                  const SizedBox(width: 14),
                  // فاتحة الحزب
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              'الحزب ${hizb.number}',
                              style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 14,
                                  color: AppTheme.textHigh),
                            ),
                            if (isDownloaded) ...[
                              const SizedBox(width: 6),
                              const Icon(Icons.offline_pin_rounded,
                                  color: Color(0xFF2E7D32), size: 16),
                            ],
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          hizb.openingVerse,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontSize: 12, color: AppTheme.textMed),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  // زر حذف التلاوة المنزّلة
                  if (isDownloaded) ...[
                    // علامة تقسيم الصفحات (حتى للأحزاب المنزّلة) للتمييز بينها
                    if (hasPageTimes)
                      Tooltip(
                        message: 'مزامنة الصوت مع الصفحات متاحة',
                        child: const Icon(Icons.auto_stories_rounded,
                            color: Color(0xFF1A73E8), size: 18),
                      ),
                    GestureDetector(
                      onTap: () => _deleteDownload(hizb),
                      behavior: HitTestBehavior.opaque,
                      child: const Padding(
                        padding: EdgeInsets.all(6),
                        child: Icon(Icons.delete_outline_rounded,
                            color: Colors.red, size: 22),
                      ),
                    ),
                  ]
                  else ...[
                    // علامة التشغيل: تظهر فقط عند توفّر تلاوة mp3 للحزب
                    if (hasAudio)
                      const Icon(Icons.play_circle_outline_rounded,
                          color: Colors.red, size: 18),
                    // علامة تقسيم الصفحات: تظهر فقط عند توفّر أوقات الصفحات
                    if (hasPageTimes) ...[
                      const SizedBox(width: 4),
                      Tooltip(
                        message: 'مزامنة الصوت مع الصفحات متاحة',
                        child: const Icon(Icons.auto_stories_rounded,
                            color: Color(0xFF1A73E8), size: 18),
                      ),
                    ],
                    const SizedBox(width: 4),
                    const Icon(Icons.chevron_left_rounded,
                        color: AppTheme.textLow, size: 20),
                  ],
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

// ════════════════════════════════════════════
class _MiniCard extends StatelessWidget {
  final IconData     icon;
  final Color        iconColor;
  final String       title;
  final VoidCallback onTap;
  final int          badgeCount; // إن كان > 0 يُعرض الرقم بدل الأيقونة
  const _MiniCard({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.onTap,
    this.badgeCount = 0,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: iconColor.withOpacity(0.2)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 36, height: 36,
              decoration: BoxDecoration(
                color: badgeCount > 0 ? iconColor : iconColor.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: badgeCount > 0
                  ? Center(
                      child: Text('$badgeCount',
                          style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                              fontSize: 17)),
                    )
                  : Icon(icon, color: iconColor, size: 18),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(title,
                  style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textHigh)),
            ),
          ],
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════
//  شاشة تواريخ ليالي الختمة
// ════════════════════════════════════════════
class _KhatmaNightsScreen extends StatefulWidget {
  const _KhatmaNightsScreen();
  @override
  State<_KhatmaNightsScreen> createState() => _KhatmaNightsScreenState();
}

class _KhatmaNightsScreenState extends State<_KhatmaNightsScreen> {
  static const _months = ['','يناير','فبراير','مارس','أبريل','مايو','يونيو',
                            'يوليو','أغسطس','سبتمبر','أكتوبر','نوفمبر','ديسمبر'];
  static const _days   = ['','الاثنين','الثلاثاء','الأربعاء','الخميس','الجمعة','السبت','الأحد'];
  String _fmt(DateTime d) => '${_days[d.weekday]}  ${d.day} ${_months[d.month]} ${d.year}';

  late final DateTime _today;
  late final DateTime _currentEnd;         // نهاية الختمة الحالية (ليلة الحزب 60)
  late final List<DateTime> _pastEnds;     // 5 ختمات سابقة (الأحدث أولاً)
  late final List<DateTime> _upcomingEnds; // 5 ختمات قادمة
  int? _currentParticipants;
  List<int> _pastParticipants = [];
  bool _loading = true;

  // الختمة = 21 يوماً؛ بدايتها (الحزب 1) = النهاية ناقص 20 يوماً
  DateTime _start(DateTime end) => end.subtract(const Duration(days: 20));
  // 0 أو غير معروف → «غير محدد»
  String _cnt(int? c) => (c == null || c == 0) ? 'غير محدد' : '$c';

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _today = DateTime(now.year, now.month, now.day);
    final nights = KhatmaCalculator.getKhatmaDates(
        DateTime(now.year - 1, now.month, now.day),
        DateTime(now.year + 1, now.month, now.day));
    _currentEnd = nights.firstWhere((d) => !d.isBefore(_today),
        orElse: () => nights.isNotEmpty ? nights.last : _today);
    _pastEnds = nights.where((d) => d.isBefore(_today)).toList().reversed.take(5).toList();
    _upcomingEnds = nights.where((d) => d.isAfter(_currentEnd)).take(5).toList();
    _loadParticipants();
  }

  Future<void> _loadParticipants() async {
    try {
      final ranges = <List<DateTime>>[
        [_start(_currentEnd), _today],
        ..._pastEnds.map((e) => [_start(e), e]),
      ];
      final counts = await WirdService.khatmaPeriodParticipants(ranges);
      if (mounted) {
        setState(() {
          if (counts.isNotEmpty) _currentParticipants = counts.first;
          _pastParticipants = counts.length > 1 ? counts.sublist(1) : [];
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  // بطاقة ختمة في القائمة (سابقة أو قادمة)
  Widget _khatmaTile(DateTime end, {int? count, required bool upcoming}) {
    final start = _start(end);
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: upcoming ? const Color(0xFFF3EFEA) : AppTheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE8E4DF)),
      ),
      child: Row(children: [
        Container(width: 36, height: 36,
          decoration: BoxDecoration(
            color: (upcoming ? AppTheme.gold : AppTheme.primary).withOpacity(0.10),
            shape: BoxShape.circle),
          child: Center(child: Icon(upcoming ? Icons.schedule_rounded : Icons.check_rounded,
              size: 18, color: upcoming ? AppTheme.gold : AppTheme.primary))),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('${upcoming ? 'ختمة تنتهي' : 'ختمة انتهت'} ${_fmt(end)}',
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5)),
          const SizedBox(height: 2),
          Text('${start.day}/${start.month} — ${end.day}/${end.month}/${end.year}',
              style: const TextStyle(fontSize: 11.5, color: AppTheme.textMed)),
        ])),
        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Text(upcoming ? 'غير محدد' : (_loading ? '…' : _cnt(count)),
              style: TextStyle(fontWeight: FontWeight.w800,
                  fontSize: (upcoming || (count ?? 0) == 0) ? 12 : 16,
                  color: (upcoming || (count ?? 0) == 0) ? AppTheme.textMed : AppTheme.primary)),
          if (!upcoming && (count ?? 0) > 0)
            const Text('مشارك', style: TextStyle(fontSize: 10, color: AppTheme.textMed)),
        ]),
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    final daysLeft = _currentEnd.difference(_today).inDays;
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: AppTheme.primary, foregroundColor: Colors.white,
        title: const Text('ليالي الختمة', style: TextStyle(fontWeight: FontWeight.w700)),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        children: [
          // ── الختمة الحالية ──
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF7B5E2A), AppTheme.gold, Color(0xFFD4A84B)],
                begin: Alignment.topRight, end: Alignment.bottomLeft),
              borderRadius: BorderRadius.circular(18),
              boxShadow: [BoxShadow(color: AppTheme.gold.withOpacity(0.35), blurRadius: 14, offset: const Offset(0, 6))],
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Row(children: [
                Icon(Icons.nights_stay_rounded, color: Colors.white, size: 18),
                SizedBox(width: 8),
                Text('الختمة الحالية', style: TextStyle(color: Colors.white70, fontSize: 12)),
              ]),
              const SizedBox(height: 8),
              Text('تنتهي: ${_fmt(_currentEnd)}',
                  style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w800)),
              const SizedBox(height: 4),
              Text(daysLeft <= 0 ? 'تنتهي اليوم' : 'بعد $daysLeft يوماً',
                  style: const TextStyle(color: Colors.white70, fontSize: 13)),
              const SizedBox(height: 12),
              Row(children: [
                const Icon(Icons.groups_rounded, color: Colors.white, size: 18),
                const SizedBox(width: 6),
                Text(_loading ? 'جارٍ حساب المشاركين…' : 'شارك حتى الآن: ${_cnt(_currentParticipants)}',
                    style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w700)),
              ]),
            ]),
          ),
          const SizedBox(height: 22),
          // ── الختمات السابقة (5) ──
          const Text('الختمات السابقة', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
          const SizedBox(height: 10),
          if (_pastEnds.isEmpty)
            const Padding(padding: EdgeInsets.symmetric(vertical: 8),
                child: Text('لا ختمات سابقة بعد.', style: TextStyle(color: AppTheme.textMed)))
          else
            ...List.generate(_pastEnds.length, (i) => _khatmaTile(
                _pastEnds[i],
                count: i < _pastParticipants.length ? _pastParticipants[i] : null,
                upcoming: false)),
          const SizedBox(height: 18),
          // ── الختمات القادمة (5) ──
          const Text('الختمات القادمة', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
          const SizedBox(height: 10),
          ..._upcomingEnds.map((e) => _khatmaTile(e, upcoming: true)),
        ],
      ),
    );
  }
}

class _LoadingScreen extends StatelessWidget {
  const _LoadingScreen();
  @override
  Widget build(BuildContext context) => const Scaffold(
    backgroundColor: AppTheme.background,
    body: Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircularProgressIndicator(color: AppTheme.primary),
          SizedBox(height: 16),
          Text('جارٍ التحميل...', style: TextStyle(color: AppTheme.textMed)),
        ],
      ),
    ),
  );
}

class _ErrorScreen extends StatelessWidget {
  final String error;
  const _ErrorScreen({required this.error});
  @override
  Widget build(BuildContext context) => Scaffold(
    body: Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 56, color: Colors.red),
            const SizedBox(height: 12),
            const Text('حدث خطأ في التحميل', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text(error, textAlign: TextAlign.center, style: const TextStyle(color: AppTheme.textMed)),
          ],
        ),
      ),
    ),
  );
}
