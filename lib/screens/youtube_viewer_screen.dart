import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';
import '../theme/app_theme.dart';

class YoutubeViewerScreen extends StatefulWidget {
  final String url;
  final String title;
  const YoutubeViewerScreen({super.key, required this.url, required this.title});

  @override
  State<YoutubeViewerScreen> createState() => _YoutubeViewerScreenState();
}

class _YoutubeViewerScreenState extends State<YoutubeViewerScreen> {
  late final WebViewController _ctrl;
  bool _loading = true;

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

  @override
  void initState() {
    super.initState();
    final videoId = _extractVideoId(widget.url);

    _ctrl = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.black)
      ..setNavigationDelegate(NavigationDelegate(
        onPageFinished: (_) async {
          setState(() => _loading = false);
          await _ctrl.runJavaScript(r"""
            (function unmute() {
              var v = document.querySelector('video');
              if (v) { v.muted = false; v.volume = 1; return; }
              setTimeout(unmute, 500);
            })();
          """);
          await _ctrl.runJavaScript(r"""
            (function hide() {
              var css = `
                ytm-comment-section-renderer, #comments,
                ytm-comments-entry-point-header-renderer { display:none!important; }
                ytm-item-section-renderer, ytm-shelf-renderer, ytm-reel-shelf-renderer,
                ytm-compact-video-renderer, ytm-video-with-context-renderer { display:none!important; }
                ytm-promoted-sparkles-web-renderer, ytm-banner-promo-renderer,
                .ytp-ad-module, .ad-showing .ytp-ad-skip-button-container { display:none!important; }
                ytm-single-column-watch-next-results-renderer > lazy-list >
                ytm-item-section-renderer:not(:first-child) { display:none!important; }
              `;
              var s = document.createElement('style');
              s.textContent = css;
              document.head.appendChild(s);
            })();
          """);
        },
      ));

    if (_ctrl.platform is AndroidWebViewController) {
      (_ctrl.platform as AndroidWebViewController)
          .setMediaPlaybackRequiresUserGesture(false);
    }

    final watchUrl = videoId != null
        ? 'https://m.youtube.com/watch?v=$videoId'
        : widget.url;
    _ctrl.loadRequest(Uri.parse(watchUrl));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: AppTheme.primary,
        foregroundColor: Colors.white,
        title: Text(widget.title, style: const TextStyle(fontSize: 15)),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Stack(
        children: [
          WebViewWidget(controller: _ctrl),
          if (_loading)
            const Center(child: CircularProgressIndicator(color: Colors.white)),
        ],
      ),
    );
  }
}
