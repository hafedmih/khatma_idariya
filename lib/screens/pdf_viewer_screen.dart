import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';
import '../theme/app_theme.dart';

class PdfViewerScreen extends StatefulWidget {
  final String  url;
  final String  title;
  final String? youtubeUrl;

  const PdfViewerScreen({
    super.key,
    required this.url,
    required this.title,
    this.youtubeUrl,
  });

  @override
  State<PdfViewerScreen> createState() => _PdfViewerScreenState();
}

class _PdfViewerScreenState extends State<PdfViewerScreen> {
  // ── PDF ────────────────────────────────────────────────
  late final WebViewController _pdfCtrl;
  bool _loading  = true;
  int  _progress = 0;

  // ── Audio ──────────────────────────────────────────────
  WebViewController? _audioCtrl;
  bool _playing    = false;
  bool _audioReady = false;

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

  // ── PDF WebView ────────────────────────────────────────
  void _initPdf() {
    _pdfCtrl = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(AppTheme.background)
      ..setNavigationDelegate(NavigationDelegate(
        onProgress:         (p) => setState(() { _progress = p; _loading = p < 100; }),
        onPageFinished:     (_) => setState(() => _loading = false),
        onWebResourceError: (_) => setState(() => _loading = false),
      ))
      ..loadRequest(Uri.parse(_toViewerUrl(widget.url)));
  }

  String _toViewerUrl(String raw) {
    final uri = Uri.parse(raw);
    if (uri.host.contains('drive.google.com') &&
        uri.queryParameters.containsKey('id')) {
      return 'https://drive.google.com/file/d/${uri.queryParameters['id']!}/preview';
    }
    final m = RegExp(r'/file/d/([^/]+)').firstMatch(uri.path);
    if (m != null) return 'https://drive.google.com/file/d/${m.group(1)!}/preview';
    return raw;
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
          // ignore: avoid_print
          print('[YT] ${msg.message}');
          if (!mounted) return;
          switch (msg.message) {
            case 'playing':
              setState(() { _playing = true; _audioReady = true; });
            case 'paused':
            case 'ended':
              setState(() => _playing = false);
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

  @override
  void dispose() => super.dispose();

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
            onPressed: () => _pdfCtrl.reload(),
          ),
        ],
        bottom: _loading
            ? PreferredSize(
                preferredSize: const Size.fromHeight(3),
                child: LinearProgressIndicator(
                  value: _progress / 100,
                  backgroundColor: Colors.white24,
                  valueColor: const AlwaysStoppedAnimation(Colors.white),
                ),
              )
            : null,
      ),
      body: Stack(
        children: [
          // PDF يأخذ كل الشاشة
          Positioned.fill(
            child: WebViewWidget(controller: _pdfCtrl),
          ),

          // YouTube WebView مخفي (1×1px) للصوت فقط
          if (hasAudio)
            Positioned(
              left: 0, top: 0,
              width: 1, height: 1,
              child: WebViewWidget(controller: _audioCtrl!),
            ),

          // شريط التحكم في الأسفل
          if (hasAudio)
            Positioned(
              left: 0, right: 0, bottom: 0,
              child: _AudioBar(
                playing:   _playing,
                ready:     _audioReady,
                onToggle:  _togglePlay,
                onBack:    () => _seekBy(-10),
                onForward: () => _seekBy(10),
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
  final VoidCallback onToggle;
  final VoidCallback onBack;
  final VoidCallback onForward;

  const _AudioBar({
    required this.playing,
    required this.ready,
    required this.onToggle,
    required this.onBack,
    required this.onForward,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppTheme.primaryDk,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            const Icon(Icons.headphones_rounded, color: Colors.white54, size: 18),
            const SizedBox(width: 8),
            Text(
              ready ? 'تلاوة صوتية' : 'جارٍ التحميل…',
              style: const TextStyle(color: Colors.white70, fontSize: 13),
            ),
            const Spacer(),

            IconButton(
              icon: const Icon(Icons.replay_10_rounded, color: Colors.white70),
              iconSize: 30,
              onPressed: ready ? onBack : null,
            ),

            GestureDetector(
              onTap: ready ? onToggle : null,
              child: Container(
                width: 54, height: 54,
                decoration: BoxDecoration(
                  color: ready ? AppTheme.gold : Colors.white24,
                  shape: BoxShape.circle,
                  boxShadow: ready
                      ? [BoxShadow(
                          color: AppTheme.gold.withOpacity(0.4),
                          blurRadius: 12, offset: const Offset(0, 4))]
                      : null,
                ),
                child: ready
                    ? Icon(
                        playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
                        color: Colors.white, size: 32)
                    : const SizedBox(
                        width: 24, height: 24,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white54)),
              ),
            ),

            IconButton(
              icon: const Icon(Icons.forward_10_rounded, color: Colors.white70),
              iconSize: 30,
              onPressed: ready ? onForward : null,
            ),
          ],
        ),
      ),
    );
  }
}
