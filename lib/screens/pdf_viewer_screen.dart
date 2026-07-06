import 'dart:async';
import 'package:flutter/material.dart';
import 'package:pdfx/pdfx.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';
import '../theme/app_theme.dart';
import '../services/links_service.dart';

class PdfViewerScreen extends StatefulWidget {
  final int        hizbNumber; // يُحمَّل PDF من assets/pdf/<hizbNumber>.pdf
  final String     title;
  final String?    youtubeUrl;
  final HizbLinks? hizbLinks; // لأوقات الصفحات

  const PdfViewerScreen({
    super.key,
    required this.hizbNumber,
    required this.title,
    this.youtubeUrl,
    this.hizbLinks,
  });

  @override
  State<PdfViewerScreen> createState() => _PdfViewerScreenState();
}

class _PdfViewerScreenState extends State<PdfViewerScreen> {
  // ── PDF ────────────────────────────────────────────────
  late final PdfController _pdfCtrl;
  bool _loading   = true;
  int  _pageCount = 0;

  String get _assetPath => 'assets/pdf/${widget.hizbNumber}.pdf';

  // ── Audio ──────────────────────────────────────────────
  WebViewController? _audioCtrl;
  bool _playing    = false;
  bool _audioReady = false;
  int  _currentPage = 1;
  bool _looping    = false;
  Timer? _syncTimer;
  // يمنع مزامنة الصوت مرة واحدة عندما يكون تغيّر الصفحة ناتجاً عن
  // التقليب التلقائي (الصوت أصلاً عند بداية الصفحة، فلا حاجة لإعادة seek)
  bool _suppressSeekOnce = false;

  @override
  void initState() {
    super.initState();
    _initPdf();
    final yt = widget.youtubeUrl;
    if (yt != null && yt.isNotEmpty) {
      final id    = _extractVideoId(yt);
      final start = _extractStart(yt);
      if (id != null) _initAudio(id, start);
    }
  }


  // ── PDF محلي من assets ─────────────────────────────────
  void _initPdf() {
    _pdfCtrl = PdfController(
      document: PdfDocument.openAsset(_assetPath),
      initialPage: 1,
    );
  }

  // انتقال الصفحة عبر أزرار الشريط → يحرّك ملف PDF فعلياً،
  // ومزامنة الصوت تُنفَّذ في _onPageChanged
  void _goToPage(int page) {
    if (page < 1) return;
    if (_pageCount > 0 && page > _pageCount) return;
    _pdfCtrl.animateToPage(
      page,
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
    );
  }

  // يُستدعى عند تغيّر الصفحة (بالسحب أو بالأزرار):
  // ينتقل لوقت بداية الصفحة ويبدأ تشغيل صوتها تلقائياً.
  // أمّا إذا كان التغيّر ناتجاً عن التقليب التلقائي فلا يُعيد المزامنة.
  void _onPageChanged(int page) {
    setState(() => _currentPage = page);
    if (_suppressSeekOnce) {
      _suppressSeekOnce = false;
      return;
    }
    final links = widget.hizbLinks;
    // لا تتحرك إلى الثانية 0 إذا لم تكن هناك بيانات — فقط غيّر رقم الصفحة
    if (links != null && links.pageTimes.isNotEmpty) {
      final targetSec = links.secondsForPage(page);
      _audioCtrl?.runJavaScript('if(ytP){ytP.seekTo($targetSec,true);ytP.playVideo();}');
    }
  }

  void _toggleLoop() {
    setState(() => _looping = !_looping);
  }

  // مؤقّت يتابع وقت الصوت أثناء التشغيل: يقلّب الصفحات تلقائياً
  // أو يكرّر الصفحة الحالية عند تفعيل التكرار
  void _startSyncTimer() {
    _syncTimer?.cancel();
    final links = widget.hizbLinks;
    if (links == null || links.pageTimes.isEmpty) return;

    _syncTimer = Timer.periodic(const Duration(milliseconds: 500), (_) async {
      if (!mounted) return;
      // اجلب الوقت الحالي من المشغّل
      await _audioCtrl?.runJavaScript(
        'FlutterBridge.postMessage("time:" + Math.floor(ytP ? ytP.getCurrentTime() : 0));',
      );
    });
  }

  void _handleTimeMessage(String msg) {
    final secs = int.tryParse(msg.replaceFirst('time:', ''));
    if (secs == null) return;
    final links = widget.hizbLinks;
    if (links == null || links.pageTimes.isEmpty) return;

    final curStart  = links.secondsForPage(_currentPage);
    final nextStart = links.secondsForPage(_currentPage + 1);
    // لا يوجد وقت للصفحة التالية (آخر صفحة أو بيانات ناقصة)
    final hasNext = nextStart > curStart;

    if (_looping) {
      // ابقَ داخل الصفحة الحالية
      if (hasNext && secs >= nextStart - 1) {
        _audioCtrl?.runJavaScript('if(ytP)ytP.seekTo($curStart,true);');
      }
      return;
    }

    // تقليب تلقائي: إذا بلغ الصوت بداية الصفحة التالية انتقل إليها
    // (نتجاهل النبضة إذا كان هناك تقليب معلّق أصلاً)
    if (hasNext && secs >= nextStart && !_suppressSeekOnce) {
      _suppressSeekOnce = true; // الصوت أصلاً عند بداية الصفحة التالية
      _goToPage(_currentPage + 1);
    }
  }

  @override
  void dispose() {
    _syncTimer?.cancel();
    _pdfCtrl.dispose();
    super.dispose();
  }

  // ── Audio: IFrame Player API officielle de YouTube ────────
  Future<void> _initAudio(String videoId, int startAt) async {
    final startParam = startAt > 0 ? ', start: $startAt' : '';
    final html = '''
<!DOCTYPE html>
<html>
<head>
<meta name="viewport" content="width=device-width,initial-scale=1,maximum-scale=1">
<style>
*{margin:0;padding:0;box-sizing:border-box}
html,body{width:100%;height:100%;background:#000;overflow:hidden}
#p{width:100%;height:100%}
</style>
</head>
<body>
<div id="p"></div>
<script>
FlutterBridge.postMessage('dbg:page_start');
var tag=document.createElement('script');
tag.src='https://www.youtube.com/iframe_api';
tag.onload=function(){FlutterBridge.postMessage('dbg:api_script_loaded');};
tag.onerror=function(){FlutterBridge.postMessage('dbg:api_script_error');};
document.head.appendChild(tag);
var ytP;
function onYouTubeIframeAPIReady(){
  FlutterBridge.postMessage('dbg:api_ready');
  ytP=new YT.Player('p',{
    videoId:'$videoId',
    playerVars:{autoplay:1,controls:0,playsinline:1,rel:0,modestbranding:1,origin:'https://localhost'$startParam},
    events:{
      onReady:function(e){
        FlutterBridge.postMessage('dbg:player_ready');
        e.target.unMute();
        e.target.setVolume(100);
        e.target.playVideo();
      },
      onError:function(e){FlutterBridge.postMessage('dbg:err'+e.data);},
      onStateChange:function(e){
        FlutterBridge.postMessage('dbg:state'+e.data);
        if(e.data===1)      FlutterBridge.postMessage('playing');
        else if(e.data===2) FlutterBridge.postMessage('paused');
        else if(e.data===0) FlutterBridge.postMessage('ended');
      }
    }
  });
}
window.yt_play =function(){if(ytP)ytP.playVideo();};
window.yt_pause=function(){if(ytP)ytP.pauseVideo();};
window.yt_seek =function(s){if(ytP){var t=(ytP.getCurrentTime()||0)+s;ytP.seekTo(Math.max(0,t),true);}};
window.onerror=function(m){FlutterBridge.postMessage('dbg:jserr:'+m);};
</script>
</body>
</html>''';

    _audioCtrl = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..addJavaScriptChannel(
        'FlutterBridge',
        onMessageReceived: (msg) {
          if (!mounted) return;
          final m = msg.message;
          if (m.startsWith('time:')) { _handleTimeMessage(m); return; }
          if (m.startsWith('dbg:'))  { return; }
          switch (m) {
            case 'playing':
              setState(() { _playing = true; _audioReady = true; });
              _startSyncTimer();
            case 'paused':
            case 'ended':
              setState(() => _playing = false);
              _syncTimer?.cancel();
          }
        },
      );

    if (_audioCtrl!.platform is AndroidWebViewController) {
      await (_audioCtrl!.platform as AndroidWebViewController)
          .setMediaPlaybackRequiresUserGesture(false);
    }

    await _audioCtrl!.loadHtmlString(html, baseUrl: 'https://localhost');
    setState(() {});
  }

  // ── Controls ───────────────────────────────────────────
  void _togglePlay() {
    if (_audioCtrl == null) return;
    if (_playing) {
      _audioCtrl!.runJavaScript('yt_pause()');
    } else {
      _audioCtrl!.runJavaScript('yt_play()');
    }
  }

  void _seekBy(int seconds) {
    _audioCtrl?.runJavaScript('yt_seek($seconds)');
  }

  // ── Helpers ────────────────────────────────────────────
  String? _extractVideoId(String url) {
    for (final p in [
      RegExp(r'youtu\.be/([A-Za-z0-9_\-]{11})'),
      RegExp(r'[?&]v=([A-Za-z0-9_\-]{11})'),
    ]) {
      final m = p.firstMatch(url);
      if (m != null) return m.group(1);
    }
    return null;
  }

  int _extractStart(String url) {
    final m = RegExp(r'[?&]t=(\d+)').firstMatch(url);
    return m != null ? int.tryParse(m.group(1)!) ?? 0 : 0;
  }


  // ════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    final hasAudio = _audioCtrl != null;

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
          // PDF + WebView الصوت المخفي
          Expanded(
            child: Stack(
              children: [
                Positioned.fill(
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
                if (hasAudio)
                  Positioned(
                    left: 0, top: 0, width: 1, height: 1,
                    child: WebViewWidget(controller: _audioCtrl!),
                  ),
              ],
            ),
          ),

          // شريط التحكم ثابت في الأسفل — لا يغطي PDF
          if (hasAudio)
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
