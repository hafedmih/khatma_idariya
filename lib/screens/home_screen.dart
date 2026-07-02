import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/hizb.dart';
import '../services/hizb_service.dart';
import '../services/khatma_calculator.dart';
import '../services/links_service.dart';
import '../theme/app_theme.dart';
import '../widgets/hizb_card.dart';
import 'hizb_detail_screen.dart';
import 'admin_screen.dart';

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

  // ── أسماء الأيام والشهور بالعربية ──
  static const _days   = ['', 'الاثنين','الثلاثاء','الأربعاء','الخميس','الجمعة','السبت','الأحد'];
  static const _months = ['','يناير','فبراير','مارس','أبريل','مايو','يونيو',
                            'يوليو','أغسطس','سبتمبر','أكتوبر','نوفمبر','ديسمبر'];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      // تحميل الأحزاب والروابط بشكل متوازٍ
      final results = await Future.wait([
        HizbService.loadAhzab(),
        LinksService.load(),
      ]);
      if (!mounted) return;
      setState(() {
        _ahzab     = results[0] as List<Hizb>;
        _links     = results[1] as Map<int, HizbLinks>;
        _todayNums = KhatmaCalculator.getHizbsForDate(_date);
        _loading   = false;
      });
    } catch (e) {
      setState(() { _error = e.toString(); _loading = false; });
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

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          _buildAppBar(),
          SliverToBoxAdapter(child: _buildBody()),
        ],
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
        'الختمة الإدارية',
        style: TextStyle(
          color: Colors.white,
          fontSize: 19,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.3,
        ),
      ),
      actions: [
        IconButton(
          tooltip: 'اختر تاريخاً',
          icon: const Icon(Icons.calendar_month_rounded, color: Colors.white),
          onPressed: _pickDate,
        ),
        IconButton(
          tooltip: 'الإدارة',
          icon: const Icon(Icons.admin_panel_settings_outlined,
              color: Colors.white70),
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const AdminScreen()),
          ),
        ),
      ],
    );
  }

  // ── جسم الشاشة ──
  Widget _buildBody() {
    final hizbs = HizbService.findMultiple(_ahzab!, _todayNums);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildDateCard(),
          const SizedBox(height: 20),
          if (_isFriday) ...[_buildFridayBanner(), const SizedBox(height: 16)],
          _buildSectionTitle('ورد اليوم', '${hizbs.length} أحزاب'),
          const SizedBox(height: 12),
          ...hizbs.asMap().entries.map((e) {
            final lnk = LinksService.find(_links, e.value.number);
            final ytUrl = lnk?.youtube.isNotEmpty == true
                ? lnk!.youtube : e.value.youtube;
            return HizbCard(
              hizb:      e.value,
              dayIndex:  e.key + 1,
              onTap:     () => _openDetail(e.value),
              onYoutube: ytUrl.isNotEmpty ? () => _launch(ytUrl) : null,
            );
          }),
          const SizedBox(height: 20),
          _buildWeekPreview(),
        ],
      ),
    );
  }

  // ── بطاقة التاريخ ──
  Widget _buildDateCard() {
    final cycle    = KhatmaCalculator.getCycleNumber(_date);
    final dayInCyc = KhatmaCalculator.getDayInCycle(_date);

    return Container(
      padding: const EdgeInsets.all(20),
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
              Text(
                _isToday ? 'اليوم' : 'التاريخ المختار',
                style: const TextStyle(color: Colors.white60, fontSize: 12),
              ),
              const Spacer(),
              if (!_isToday)
                _Chip(
                  label: 'العودة لليوم',
                  onTap: () => _changeDate(DateTime.now()),
                ),
            ],
          ),
          const SizedBox(height: 6),
          // ── اسم اليوم والتاريخ ──
          Text(
            '${_days[_date.weekday]} ${_date.day} ${_months[_date.month]} ${_date.year}',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 14),
          // ── إحصائيات ──
          Row(
            children: [
              _StatCol('الأحزاب', '${_todayNums.length}'),
              _divider(),
              _StatCol('الدورة', '$cycle'),
              _divider(),
              _StatCol('يوم الدورة', '$dayInCyc / ٢١'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _divider() => Container(
    width: 1, height: 30, color: Colors.white24,
    margin: const EdgeInsets.symmetric(horizontal: 16),
  );

  // ── بانر الجمعة ──
  Widget _buildFridayBanner() {
    return Container(
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
                Text('تذكّر قراءة سورة الكهف',
                    style: TextStyle(fontSize: 12, color: AppTheme.textMed)),
              ],
            ),
          ),
        ],
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

  // ── معاينة الأسبوع ──
  Widget _buildWeekPreview() {
    final monday  = _date.subtract(Duration(days: _date.weekday - 1));
    final weekMap = KhatmaCalculator.getWeekHizbs(monday);
    final daysAbb = ['', 'إث','ثل','أر','خم','جم','سب','أح'];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('هذا الأسبوع', ''),
        const SizedBox(height: 10),
        Row(
          children: List.generate(7, (i) {
            final d     = monday.add(Duration(days: i));
            final hizbs = weekMap[d] ?? [];
            final isSel = d.day == _date.day && d.month == _date.month;

            return Expanded(
              child: GestureDetector(
                onTap: () => _changeDate(d),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    color: isSel ? AppTheme.primary : AppTheme.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isSel
                          ? AppTheme.primary
                          : const Color(0xFFE8E4DF),
                    ),
                  ),
                  child: Column(
                    children: [
                      Text(
                        daysAbb[d.weekday],
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: isSel ? Colors.white70 : AppTheme.textLow,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${d.day}',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: isSel ? Colors.white : AppTheme.textHigh,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        hizbs.isNotEmpty ? '${hizbs.first}' : '—',
                        style: TextStyle(
                          fontSize: 10,
                          color: isSel ? Colors.white60 : AppTheme.textLow,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }),
        ),
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

  void _openDetail(Hizb hizb) {
    final lnk = LinksService.find(_links, hizb.number);
    Navigator.push(context, _slide(HizbDetailScreen(hizb: hizb, links: lnk)));
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
class _StatCol extends StatelessWidget {
  final String label;
  final String value;
  const _StatCol(this.label, this.value);

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label, style: const TextStyle(color: Colors.white54, fontSize: 11)),
      Text(value,  style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w700)),
    ],
  );
}

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
