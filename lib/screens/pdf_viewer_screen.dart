import 'dart:async';
import 'package:flutter/material.dart';
import 'package:pdfx/pdfx.dart';
import 'package:just_audio/just_audio.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';
import '../theme/app_theme.dart';
import '../services/links_service.dart';
import '../services/app_prefs.dart';
import '../services/audio_download_service.dart';
import '../services/reading_progress.dart';
import '../services/youtube_service.dart';
import '../config/audio_config.dart';

class PdfViewerScreen extends StatefulWidget {
  final int        hizbNumber;
  final String     title;
  final String?    youtubeUrl;
  final HizbLinks? hizbLinks;
  final int        initialPage;
  final String?    assetPath;
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
  bool _loading    = true;
  int  _pageCount  = 0;
  int  _currentPage = 1;

  String get _assetPath => widget.assetPath ?? 'assets/pdf/${widget.hizbNumber}.pdf';
  int    get _track     => widget.audioNumber ?? widget.hizbNumber;

  // ── Audio (just_audio — Supabase / محلي) ───────────────
  final AudioPlayer _player = AudioPlayer();
  bool _isHizb     = false;
  bool _hasAudio   = false;
  bool _audioReady = false;
  bool _playing    = false;
  bool _looping    = false;
  bool _autoRecite = false;
  bool _downloaded  = false;
  bool _downloading = false;
  double _dlProgress = 0;

  StreamSubscription<Duration>? _posSub;
  bool _suppressSeekOnce = false;
  List<int> _pageTimes = const [];
  bool get _hasPageTimes => _pageTimes.isNotEmpty;

  // ── YouTube WebView خفي — بديل شفّاف عند تعذّر Supabase ──
  WebViewController? _ytCtrl;
  bool _ytPlaying = false;
  bool _ytReady   = false;
  bool _ytInjected = false;

  // روابط ثابتة لتلاوات المنجيات (1..5) على يوتيوب
  static const _mounjyatYt = {
    101: 'https://youtu.be/nPQgx4Dsy60',
    102: 'https://youtu.be/d6Ue1xrCGmQ',
    103: 'https://youtu.be/bjABluRX2ns',
    104: 'https://youtu.be/7WtLi1zixjg',
    105: 'https://youtu.be/P0IfHTtGrlI',
  };

  int _secForPage(int page) {
    if (page <= 1) return 0;
    final idx = page - 2;
    return (idx >= 0 && idx < _pageTimes.length) ? _pageTimes[idx] : -1;
  }

  Future<void> _loadPageTimes() async {
    _pageTimes = widget.hizbLinks?.pageTimes ?? const [];
    if (_pageTimes.isNotEmpty) return;

    _pageTimes = await AudioDownloadService.cachedPageTimes(_track);
    if (_pageTimes.isNotEmpty) return;

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
    _isHizb = AudioConfig.hasAudioFor(_track);
    _player.playingStream.listen((p) { if (mounted) setState(() => _playing = p); });
    if (_isHizb) _setupAudio();
  }

  void _onPosition(Duration pos) {
    if (!_hasPageTimes || !_player.playing) return;
    final curStart  = _secForPage(_currentPage);
    final nextStart = _secForPage(_currentPage + 1);
    final hasNext   = nextStart > curStart;
    final secs      = pos.inSeconds;
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
      document:    PdfDocument.openAsset(_assetPath),
      initialPage: widget.initialPage,
    );
  }

  // تهيئة التلاوة: محلي → Supabase → يوتيوب WebView خفي
  Future<void> _setupAudio() async {
    _autoRecite = await AppPrefs.autoRecite();
    _downloaded = await AudioDownloadService.isDownloaded(_track);
    await _loadPageTimes();

    // 1) ملف محلي
    if (_downloaded) {
      try {
        final f = await AudioDownloadService.localFile(_track);
        await _player.setFilePath(f.path);
        _hasAudio = true;
      } catch (_) {}
    }

    // 2) Supabase
    if (!_hasAudio) {
      try {
        final exists = await AudioDownloadService.remoteExists(_track);
        if (exists) {
          await _player.setUrl(AudioConfig.urlFor(_track));
          _hasAudio = true;
        }
      } catch (_) {}
    }

    // إن نجح الملف المحلي أو Supabase → شغّل مباشرة
    if (_hasAudio) {
      _audioReady = true;
      _posSub = _player.positionStream.listen(_onPosition);
      if (_autoRecite) _player.play();
      if (mounted) setState(() {});
      return;
    }

    // 3) يوتيوب — WebView خفي (الأحزاب 1..60 والمنجيات 101..105)
    final isMounjyat = _track >= 101 && _track <= 105;
    if ((widget.hizbNumber >= 1 && widget.hizbNumber <= 60) || isMounjyat) {
      await _setupYoutubeWebAudio();
    }

    if (mounted) setState(() {});
  }

  // يُنشئ WebViewController مخفياً يشغّل صوت يوتيوب في الخلفية
  Future<void> _setupYoutubeWebAudio() async {
    try {
      // المنجيات: روابط ثابتة — الأحزاب: YouTube API (مخزّنة مؤقتاً)
      String? ytUrl;
      if (_track >= 101 && _track <= 105) {
        ytUrl = _mounjyatYt[_track];
      } else {
        final map = await YoutubeService.load();
        ytUrl = map[widget.hizbNumber]?.url;
      }
      if (ytUrl == null || ytUrl.isEmpty) return;

      final videoId = _ytVideoId(ytUrl);
      if (videoId == null) return;

      final ctrl = WebViewController()
        ..setJavaScriptMode(JavaScriptMode.unrestricted)
        ..setBackgroundColor(Colors.transparent)
        ..addJavaScriptChannel('FlutterYT', onMessageReceived: _onYtMessage)
        ..setNavigationDelegate(NavigationDelegate(
          onPageFinished: (_) {
            if (_ytInjected) return;
            _ytInjected = true;
            _ytInjectControls();
          },
        ));

      if (ctrl.platform is AndroidWebViewController) {
        (ctrl.platform as AndroidWebViewController)
            .setMediaPlaybackRequiresUserGesture(false);
      }

      _ytCtrl   = ctrl;
      _hasAudio = true;

      await ctrl.loadRequest(
          Uri.parse('https://m.youtube.com/watch?v=$videoId'));
    } catch (_) {}
  }

  String? _ytVideoId(String url) {
    for (final p in [
      RegExp(r'youtu\.be/([A-Za-z0-9_\-]{11})'),
      RegExp(r'[?&]v=([A-Za-z0-9_\-]{11})'),
    ]) {
      final m = p.firstMatch(url);
      if (m != null) return m.group(1);
    }
    return null;
  }

  // نحقن JavaScript بعد تحميل الصفحة للسيطرة على عنصر <video>
  Future<void> _ytInjectControls() async {
    await _ytCtrl?.runJavaScript(r"""
      (function() {
        var attempts = 0;
        function waitForVideo() {
          attempts++;
          // بعد 20 ثانية بدون <video>: الفيديو محذوف أو خاص
          if (attempts > 50) { FlutterYT.postMessage('unavailable'); return; }
          var v = document.querySelector('video');
          if (!v) { setTimeout(waitForVideo, 400); return; }
          v.muted  = false;
          v.volume = 1;
          v.addEventListener('play',  function(){ FlutterYT.postMessage('playing'); });
          v.addEventListener('pause', function(){ FlutterYT.postMessage('paused');  });
          v.addEventListener('ended', function(){ FlutterYT.postMessage('ended');   });
          // يُعيد رفع الصوت كلما أخمده يوتيوب
          setInterval(function() {
            var vid = document.querySelector('video');
            if (vid && (vid.muted || vid.volume < 0.5)) {
              vid.muted = false; vid.volume = 1;
            }
          }, 800);
          v.play()
            .then(function(){ FlutterYT.postMessage('ready'); })
            .catch(function(){ FlutterYT.postMessage('ready'); });
        }
        waitForVideo();
      })();
    """);
  }

  void _onYtMessage(JavaScriptMessage msg) {
    if (!mounted) return;
    switch (msg.message) {
      case 'ready':
        setState(() { _ytReady = true; _audioReady = true; });
        // إن لم يكن التشغيل التلقائي مفعّلاً، أوقف فوراً
        if (!_autoRecite) {
          _ytCtrl?.runJavaScript("document.querySelector('video')?.pause()");
        }
        break;
      case 'playing':
        setState(() => _ytPlaying = true);
        break;
      case 'paused':
      case 'ended':
        setState(() => _ytPlaying = false);
        break;
      case 'unavailable':
        // الفيديو محذوف أو خاص — أظهر "غير متوفّرة"
        setState(() { _ytCtrl = null; _hasAudio = false; _ytReady = false; });
        break;
    }
  }

  // ── تحكم في التشغيل (يوتيوب أو just_audio) ─────────────
  void _togglePlay() {
    if (_ytCtrl != null) {
      if (_ytPlaying) {
        _ytCtrl!.runJavaScript("document.querySelector('video')?.pause()");
      } else {
        _ytCtrl!.runJavaScript("document.querySelector('video')?.play()");
      }
      return;
    }
    if (!_hasAudio) return;
    _playing ? _player.pause() : _player.play();
  }

  void _seekBy(int seconds) {
    if (_ytCtrl != null) {
      _ytCtrl!.runJavaScript(
          "var v=document.querySelector('video');if(v)v.currentTime+=$seconds;");
      return;
    }
    final pos = _player.position + Duration(seconds: seconds);
    final dur = _player.duration ?? Duration.zero;
    _player.seek(pos < Duration.zero
        ? Duration.zero
        : (pos > dur ? dur : pos));
  }

  Future<void> _toggleLoop() async {
    setState(() => _looping = !_looping);
    if (_ytCtrl != null) {
      _ytCtrl!.runJavaScript(
          "var v=document.querySelector('video');if(v)v.loop=${_looping};");
      return;
    }
    await _player.setLoopMode(_looping ? LoopMode.one : LoopMode.off);
  }

  void _goToPage(int page) {
    if (page < 1) return;
    if (_pageCount > 0 && page > _pageCount) return;
    _pdfCtrl.animateToPage(page,
        duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
  }

  void _onPageChanged(int page) {
    setState(() => _currentPage = page);
    if (_isHizb && widget.hizbNumber >= 1) {
      if (_pageCount > 0 && page >= _pageCount) {
        ReadingProgress.clear();
      } else {
        ReadingProgress.save(widget.hizbNumber, page);
      }
    }
    if (_suppressSeekOnce) { _suppressSeekOnce = false; return; }
    if (_hasPageTimes && _hasAudio && _ytCtrl == null) {
      final t = _secForPage(page);
      if (t >= 0) _player.seek(Duration(seconds: t));
    }
  }

  // ── تنزيل / حذف ────────────────────────────────────────
  Future<void> _downloadCurrent() async {
    if (_downloading || _downloaded || !_hasAudio || _ytCtrl != null) return;
    setState(() { _downloading = true; _dlProgress = 0; });
    final ok = await AudioDownloadService.download(_track,
        onProgress: (p) { if (mounted) setState(() => _dlProgress = p); });
    if (!mounted) return;
    setState(() { _downloading = false; _downloaded = ok; });
    if (ok) {
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

  Future<void> _deleteCurrent() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('حذف التلاوة'),
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
    // مؤشر التشغيل والجاهزية: يوتيوب أو just_audio
    final isPlaying = _ytCtrl != null ? _ytPlaying : _playing;
    final isReady   = _ytCtrl != null ? _ytReady   : _audioReady;
    // زر التنزيل يظهر فقط للصوت الحقيقي (ليس يوتيوب)
    final canDownload = _isHizb && _hasAudio && _ytCtrl == null;

    final body = Column(
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
        if (_isHizb && _hasAudio)
          _AudioBar(
            playing:      isPlaying,
            ready:        isReady,
            currentPage:  _currentPage,
            pageCount:    _pageCount,
            looping:      _looping,
            onToggle:     _togglePlay,
            onBack:       () => _seekBy(-10),
            onForward:    () => _seekBy(10),
            onPagePrev:   () => _goToPage(_currentPage - 1),
            onPageNext:   () => _goToPage(_currentPage + 1),
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
    );

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
          if (canDownload)
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
                    icon: Icon(
                        _downloaded ? Icons.download_done_rounded : Icons.download_rounded,
                        size: 22,
                        color: _downloaded ? AppTheme.gold : Colors.white),
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
      // WebView يوتيوب مخفي: 1×50dp خارج الشاشة (يسار −2) — كبير كفاية لإبقاء Chromium نشطاً
      body: _ytCtrl != null
          ? Stack(
              clipBehavior: Clip.hardEdge,
              children: [
                body,
                Positioned(
                  left: -2, top: 0,
                  child: SizedBox(
                    width: 2, height: 50,
                    child: WebViewWidget(controller: _ytCtrl!),
                  ),
                ),
              ],
            )
          : body,
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
            Row(
              children: [
                IconButton(
                  icon: Icon(Icons.repeat_one_rounded,
                      color: looping ? AppTheme.gold : Colors.white38),
                  iconSize: 26,
                  onPressed: ready ? onLoopToggle : null,
                ),
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
                                ? [BoxShadow(
                                    color: AppTheme.gold.withOpacity(0.4),
                                    blurRadius: 10,
                                    offset: const Offset(0, 3))]
                                : null,
                          ),
                          child: ready
                              ? Icon(
                                  playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
                                  color: Colors.white, size: 30)
                              : const SizedBox(
                                  width: 22, height: 22,
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
                const SizedBox(width: 48),
              ],
            ),
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
