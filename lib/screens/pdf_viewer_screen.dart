import 'dart:async';
import 'package:flutter/material.dart';
import 'package:pdfx/pdfx.dart';
import 'package:just_audio/just_audio.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../theme/app_theme.dart';
import '../services/links_service.dart';
import '../services/app_prefs.dart';
import '../services/audio_download_service.dart';
import '../services/reading_progress.dart';
import '../config/audio_config.dart';

class PdfViewerScreen extends StatefulWidget {
  final int        hizbNumber; // يُحمَّل PDF من assets/pdf/<hizbNumber>.pdf
  final String     title;
  final String?    youtubeUrl;
  final HizbLinks? hizbLinks; // لأوقات الصفحات
  final int        initialPage; // الصفحة المبدئية (لفتح ثمن معيّن)
  final String?    assetPath;  // مسار PDF مخصّص (سورة الكهف / دعاء الختمة)
  // رقم ملف التلاوة إن اختلف عن رقم الحزب: 61 سورة الكهف، 62 دعاء الختمة.
  // اتركه فارغاً للأحزاب فيُستخدم hizbNumber.
  final int?       audioNumber;

  const PdfViewerScreen({
    super.key,
    this.hizbNumber = 0,
    required this.title,
    this.youtubeUrl,
    this.hizbLinks,
    this.initialPage = 1,
    this.assetPath,
    this.audioNumber,
  });

  @override
  State<PdfViewerScreen> createState() => _PdfViewerScreenState();
}

class _PdfViewerScreenState extends State<PdfViewerScreen> {
  // ── PDF ────────────────────────────────────────────────
  late final PdfController _pdfCtrl;
  bool _loading   = true;
  int  _pageCount = 0;
  int  _currentPage = 1;

  String get _assetPath => widget.assetPath ?? 'assets/pdf/${widget.hizbNumber}.pdf';

  /// رقم ملف التلاوة في حاوية «audio» — يفترق عن رقم الحزب في
  /// سورة الكهف (61) ودعاء الختمة (62).
  int get _track => widget.audioNumber ?? widget.hizbNumber;

  // ── Audio (MP3 عبر just_audio) ─────────────────────────
  final AudioPlayer _player = AudioPlayer();
  bool _isHizb     = false; // حزب له تلاوة (1..60) وليس ملفاً خاصاً
  bool _hasAudio   = false; // التلاوة متوفّرة (محلياً أو على الخادم)
  bool _audioReady = false;
  bool _playing    = false;
  bool _looping    = false;
  bool _autoRecite = false;

  bool _downloaded = false;
  bool _downloading = false;
  double _dlProgress = 0;

  // مزامنة الصفحات مع الصوت (أوقات الصفحات من hizb_page_times)
  StreamSubscription<Duration>? _posSub;
  bool _suppressSeekOnce = false;
  List<int> _pageTimes = const []; // للصفحات 2..8 (الصفحة 1 = 0)
  bool get _hasPageTimes => _pageTimes.isNotEmpty;

  // وقت بداية الصفحة بالثواني
  int _secForPage(int page) {
    if (page <= 1) return 0;
    final idx = page - 2;
    return (idx >= 0 && idx < _pageTimes.length) ? _pageTimes[idx] : -1;
  }

  // تحميل أوقات الصفحات: من الروابط، ثم النسخة المحلية (تعمل دون إنترنت)، ثم قاعدة البيانات
  Future<void> _loadPageTimes() async {
    _pageTimes = widget.hizbLinks?.pageTimes ?? const [];
    if (_pageTimes.isNotEmpty) return;

    // 1) نسخة محلية محفوظة عند التنزيل — تُتيح الانتقال بين الصفحات دون إنترنت
    _pageTimes = await AudioDownloadService.cachedPageTimes(_track);
    if (_pageTimes.isNotEmpty) return;

    // 2) من قاعدة البيانات (مع تخزين النتيجة محلياً للاستخدام لاحقاً دون إنترنت)
    try {
      final m = await Supabase.instance.client
          .from('hizb_page_times')
          .select('page_times')
          .eq('hizb', _track)
          .maybeSingle()
          .timeout(const Duration(seconds: 6));
      if (m != null && m['page_times'] != null) {
        _pageTimes = (m['page_times'] as List).map((e) => (e as num).toInt()).toList();
        if (_downloaded && _pageTimes.isNotEmpty) {
          await AudioDownloadService.savePageTimes(_track, _pageTimes);
        }
      }
    } catch (_) {}
  }

  @override
  void initState() {
    super.initState();
    _initPdf();
    // التلاوة متاحة لأي رقم ملف صالح — أحزاباً كانت أو الكهف/الدعاء.
    _isHizb = AudioConfig.hasAudioFor(_track);
    _player.playingStream.listen((p) { if (mounted) setState(() => _playing = p); });
    if (_isHizb) _setupAudio();
  }

  // تقليب تلقائي للصفحة عند بلوغ الصوت وقت الصفحة التالية
  void _onPosition(Duration pos) {
    if (!_hasPageTimes || !_player.playing) return;
    final curStart  = _secForPage(_currentPage);
    final nextStart = _secForPage(_currentPage + 1);
    final hasNext = nextStart > curStart;
    final secs = pos.inSeconds;
    if (_looping) {
      if (hasNext && secs >= nextStart - 1) {
        _player.seek(Duration(seconds: curStart));
      }
      return;
    }
    if (hasNext && secs >= nextStart && !_suppressSeekOnce) {
      _suppressSeekOnce = true;
      _goToPage(_currentPage + 1);
    }
  }

  void _initPdf() {
    _currentPage = widget.initialPage;
    _pdfCtrl = PdfController(
      document: PdfDocument.openAsset(_assetPath),
      initialPage: widget.initialPage,
    );
  }

  // تهيئة التلاوة: من الملف المحلي إن كان منزّلاً، وإلا بثّاً من الخادم
  Future<void> _setupAudio() async {
    _autoRecite = await AppPrefs.autoRecite();
    _downloaded = await AudioDownloadService.isDownloaded(_track);
    await _loadPageTimes();
    try {
      if (_downloaded) {
        final f = await AudioDownloadService.localFile(_track);
        await _player.setFilePath(f.path);
        _hasAudio = true;
      } else {
        final exists = await AudioDownloadService.remoteExists(_track);
        if (exists) {
          await _player.setUrl(AudioConfig.urlFor(_track));
          _hasAudio = true;
        } else {
          _hasAudio = false; // لم تُرفع تلاوة هذا الحزب بعد
        }
      }
      if (_hasAudio) {
        _audioReady = true;
        _posSub = _player.positionStream.listen(_onPosition);
        if (_autoRecite) _player.play();
      }
    } catch (_) {
      _hasAudio = false;
    }
    if (mounted) setState(() {});
  }

  void _goToPage(int page) {
    if (page < 1) return;
    if (_pageCount > 0 && page > _pageCount) return;
    _pdfCtrl.animateToPage(page,
        duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
  }

  void _onPageChanged(int page) {
    setState(() => _currentPage = page);
    // حفظ موضع القراءة للأحزاب: إن وصل آخر صفحة فقد اكتملت القراءة → امسح
    if (_isHizb && widget.hizbNumber >= 1) {
      if (_pageCount > 0 && page >= _pageCount) {
        ReadingProgress.clear();
      } else {
        ReadingProgress.save(widget.hizbNumber, page);
      }
    }
    // إن كان التغيّر ناتجاً عن التقليب التلقائي فالصوت أصلاً في مكانه
    if (_suppressSeekOnce) { _suppressSeekOnce = false; return; }
    // تغيير يدوي: انقل الصوت إلى بداية الصفحة
    if (_hasPageTimes && _hasAudio) {
      final t = _secForPage(page);
      if (t >= 0) _player.seek(Duration(seconds: t));
    }
  }

  void _togglePlay() {
    if (!_hasAudio) return;
    _playing ? _player.pause() : _player.play();
  }

  void _seekBy(int seconds) {
    final pos = _player.position + Duration(seconds: seconds);
    final dur = _player.duration ?? Duration.zero;
    _player.seek(pos < Duration.zero ? Duration.zero : (pos > dur ? dur : pos));
  }

  Future<void> _toggleLoop() async {
    setState(() => _looping = !_looping);
    await _player.setLoopMode(_looping ? LoopMode.one : LoopMode.off);
  }

  // تنزيل تلاوة الحزب الحالي للاستماع دون إنترنت
  Future<void> _downloadCurrent() async {
    if (_downloading || _downloaded || !_hasAudio) return;
    setState(() { _downloading = true; _dlProgress = 0; });
    final ok = await AudioDownloadService.download(_track,
        onProgress: (p) { if (mounted) setState(() => _dlProgress = p); });
    if (!mounted) return;
    setState(() { _downloading = false; _downloaded = ok; });
    if (ok) {
      // احفظ أوقات الصفحات محلياً ليعمل الانتقال بين الصفحات دون إنترنت
      if (_pageTimes.isEmpty) await _loadPageTimes();
      await AudioDownloadService.savePageTimes(_track, _pageTimes);
      try {
        final pos = _player.position;
        final wasPlaying = _player.playing;
        final f = await AudioDownloadService.localFile(_track);
        await _player.setFilePath(f.path);
        await _player.seek(pos);
        if (_looping) await _player.setLoopMode(LoopMode.one);
        if (wasPlaying) _player.play();
      } catch (_) {}
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تم التنزيل — يعمل الآن دون إنترنت')));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تعذّر التنزيل')));
    }
  }

  // حذف تلاوة الحزب المنزّلة والعودة للبثّ
  Future<void> _deleteCurrent() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('حذف التلاوة'),
        // العنوان يصلح للأحزاب وللكهف/الدعاء على السواء.
        content: Text('حذف تلاوة «${widget.title}» المنزّلة؟ يمكنك تنزيلها لاحقاً.'),
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
    await AudioDownloadService.delete(_track);
    if (!mounted) return;
    setState(() => _downloaded = false);
    // العودة للبثّ من الخادم (يحتاج إنترنت)
    try {
      final pos = _player.position;
      final wasPlaying = _player.playing;
      await _player.setUrl(AudioConfig.urlFor(_track));
      await _player.seek(pos);
      if (_looping) await _player.setLoopMode(LoopMode.one);
      if (wasPlaying) _player.play();
    } catch (_) {}
    ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم حذف التلاوة المنزّلة')));
  }

  @override
  void dispose() {
    _posSub?.cancel();
    _player.dispose();
    _pdfCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: AppTheme.primary,
        foregroundColor: Colors.white,
        title: Text(widget.title, style: const TextStyle(fontSize: 15)),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          // زر التنزيل (لأحزاب لها تلاوة متوفّرة)
          if (_isHizb && _hasAudio)
            _downloading
                ? Padding(
                    padding: const EdgeInsets.all(14),
                    child: SizedBox(
                      width: 20, height: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2.4, color: Colors.white,
                          value: _dlProgress > 0 ? _dlProgress : null),
                    ),
                  )
                : IconButton(
                    tooltip: _downloaded ? 'منزّلة — اضغط لحذف التلاوة' : 'تنزيل التلاوة',
                    icon: Icon(_downloaded ? Icons.download_done_rounded : Icons.download_rounded,
                        size: 22, color: _downloaded ? AppTheme.gold : Colors.white),
                    onPressed: _downloaded ? _deleteCurrent : _downloadCurrent,
                  ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded, size: 22),
            onPressed: () {
              setState(() => _loading = true);
              _pdfCtrl.loadDocument(PdfDocument.openAsset(_assetPath));
            },
          ),
        ],
        bottom: _loading
            ? const PreferredSize(
                preferredSize: Size.fromHeight(3),
                child: LinearProgressIndicator(
                  backgroundColor: Colors.white24,
                  valueColor: AlwaysStoppedAnimation(Colors.white),
                ),
              )
            : null,
      ),
      body: Column(
        children: [
          Expanded(
            child: PdfView(
              controller: _pdfCtrl,
              scrollDirection: Axis.horizontal,
              onPageChanged: _onPageChanged,
              onDocumentLoaded: (doc) => setState(() {
                _pageCount = doc.pagesCount;
                _loading   = false;
              }),
              onDocumentError: (_) => setState(() => _loading = false),
              builders: PdfViewBuilders<DefaultBuilderOptions>(
                options: const DefaultBuilderOptions(),
                documentLoaderBuilder: (_) => const Center(
                  child: CircularProgressIndicator(color: AppTheme.primary),
                ),
                pageLoaderBuilder: (_) => const Center(
                  child: CircularProgressIndicator(color: AppTheme.primary),
                ),
              ),
            ),
          ),
          // شريط التحكم بالتلاوة
          if (_isHizb && _hasAudio)
            _AudioBar(
              playing:     _playing,
              ready:       _audioReady,
              currentPage: _currentPage,
              pageCount:   _pageCount,
              looping:     _looping,
              onToggle:    _togglePlay,
              onBack:      () => _seekBy(-10),
              onForward:   () => _seekBy(10),
              onPagePrev:  () => _goToPage(_currentPage - 1),
              onPageNext:  () => _goToPage(_currentPage + 1),
              onLoopToggle: _toggleLoop,
            )
          else if (_isHizb && !_hasAudio)
            Container(
              width: double.infinity,
              color: AppTheme.primaryDk,
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: const SafeArea(
                top: false,
                child: Text('تلاوة هذا الحزب غير متوفّرة بعد',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white70, fontSize: 12)),
              ),
            ),
        ],
      ),
    );
  }
}


// ══════════════════════════════════════════════════════════════
class _AudioBar extends StatelessWidget {
  final bool         playing;
  final bool         ready;
  final int          currentPage;
  final int          pageCount;
  final bool         looping;
  final VoidCallback onToggle;
  final VoidCallback onBack;
  final VoidCallback onForward;
  final VoidCallback onPagePrev;
  final VoidCallback onPageNext;
  final VoidCallback onLoopToggle;

  const _AudioBar({
    required this.playing,
    required this.ready,
    required this.currentPage,
    required this.pageCount,
    required this.looping,
    required this.onToggle,
    required this.onBack,
    required this.onForward,
    required this.onPagePrev,
    required this.onPageNext,
    required this.onLoopToggle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppTheme.primaryDk,
      padding: const EdgeInsets.fromLTRB(4, 6, 4, 4),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ── صف التحكم بالصوت: زر التكرار يسار، تشغيل في الوسط تماماً ──
            Row(
              children: [
                // زر التكرار في اليسار
                IconButton(
                  icon: Icon(Icons.repeat_one_rounded,
                      color: looping ? AppTheme.gold : Colors.white38),
                  iconSize: 26,
                  onPressed: ready ? onLoopToggle : null,
                ),
                // مجموعة الوسط (←10 + تشغيل + 10→) مرتكزة
                Expanded(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.replay_10_rounded, color: Colors.white70),
                        iconSize: 28,
                        onPressed: ready ? onBack : null,
                      ),
                      const SizedBox(width: 8),
                      GestureDetector(
                        onTap: ready ? onToggle : null,
                        child: Container(
                          width: 52, height: 52,
                          decoration: BoxDecoration(
                            color: ready ? AppTheme.gold : Colors.white24,
                            shape: BoxShape.circle,
                            boxShadow: ready
                                ? [BoxShadow(color: AppTheme.gold.withOpacity(0.4),
                                    blurRadius: 10, offset: const Offset(0, 3))]
                                : null,
                          ),
                          child: ready
                              ? Icon(playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
                                  color: Colors.white, size: 30)
                              : const SizedBox(width: 22, height: 22,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2, color: Colors.white54)),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        icon: const Icon(Icons.forward_10_rounded, color: Colors.white70),
                        iconSize: 28,
                        onPressed: ready ? onForward : null,
                      ),
                    ],
                  ),
                ),
                // يمين فارغ بنفس عرض زر التكرار للتوازن
                const SizedBox(width: 48),
              ],
            ),
            // ── صف الصفحات في الأسفل ──
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  icon: const Icon(Icons.chevron_right_rounded, color: Colors.white60),
                  iconSize: 24,
                  onPressed: currentPage > 1 ? onPagePrev : null,
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.white10,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text('صفحة $currentPage',
                      style: const TextStyle(color: Colors.white70, fontSize: 12)),
                ),
                IconButton(
                  icon: const Icon(Icons.chevron_left_rounded, color: Colors.white60),
                  iconSize: 24,
                  onPressed: (pageCount == 0 || currentPage < pageCount)
                      ? onPageNext
                      : null,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
