import 'dart:convert';
import 'dart:io';

// ═══════════════════════════════════════════════════════════
//  YoutubeService — يجلب روابط تلاوة كل حزب من YouTube Data API
//  بدلاً من Supabase. يقرأ playlist القارئ ويستخرج رقم الحزب من
//  عنوان الفيديو (مثال: "الحزب الأول (1)" أو "... 13")، وأوقات
//  الأثمان من وصف الفيديو (مثال: "03:26 - الثمن الثاني").
// ═══════════════════════════════════════════════════════════

/// معلومات فيديو حزب واحد: الرابط + أوقات الأثمان (بالثواني، للأثمان 2..8)
class YtVideo {
  final String    url;
  final List<int> pageTimes;
  const YtVideo(this.url, this.pageTimes);
}

class YoutubeService {
  static const String _apiKey     = 'AIzaSyAHik492WIsF1BDqCoo_35yt8VNhjJkPo0';
  static const String _playlistId = 'PLtLa7ryveIIIrO3elTmi-2UOLvWihbfX-';

  static Map<int, YtVideo>? _cache;

  /// خريطة: رقم الحزب → (رابط يوتيوب + أوقات الأثمان)
  static Future<Map<int, YtVideo>> load() async {
    if (_cache != null) return _cache!;

    final map = <int, YtVideo>{};
    try {
      String? pageToken;
      final client = HttpClient();
      try {
        // playlistItems محدودة بـ 50 عنصراً لكل صفحة → نتنقّل بالصفحات
        do {
          final uri = Uri.https(
            'www.googleapis.com',
            '/youtube/v3/playlistItems',
            {
              'part': 'snippet',
              'playlistId': _playlistId,
              'maxResults': '50',
              'key': _apiKey,
              if (pageToken != null) 'pageToken': pageToken,
            },
          );

          final req  = await client.getUrl(uri);
          final resp = await req.close();
          if (resp.statusCode != 200) break;

          final body = await resp.transform(utf8.decoder).join();
          final json = jsonDecode(body) as Map<String, dynamic>;

          for (final item in (json['items'] as List<dynamic>? ?? [])) {
            final snippet = (item as Map<String, dynamic>)['snippet']
                as Map<String, dynamic>?;
            if (snippet == null) continue;

            final title   = (snippet['title'] as String?) ?? '';
            final desc    = (snippet['description'] as String?) ?? '';
            final videoId =
                ((snippet['resourceId'] as Map<String, dynamic>?)?['videoId']
                    as String?) ?? '';
            if (videoId.isEmpty) continue;

            final hizb = _hizbFromTitle(title);
            if (hizb == null) continue; // "Private video" / "Deleted video"

            // في حال تكرار الحزب نأخذ الرفع الأحدث (الأخير في القائمة)
            map[hizb] = YtVideo(
              'https://www.youtube.com/watch?v=$videoId',
              _pageTimesFromDescription(desc),
            );
          }

          pageToken = json['nextPageToken'] as String?;
        } while (pageToken != null);
      } finally {
        client.close();
      }
    } catch (_) {
      // فشل الشبكة/الـAPI — نُرجع ما جُمِع (قد يكون فارغاً)
    }

    _cache = map;
    return map;
  }

  static void invalidateCache() => _cache = null;

  // ── يستخرج رقم الحزب (1..60) من عنوان الفيديو ──────────────
  static int? _hizbFromTitle(String title) {
    // حوّل الأرقام العربية-الهندية إلى لاتينية
    final normalized = title.replaceAllMapped(
      RegExp('[٠-٩]'),
      (m) => '${m.group(0)!.codeUnitAt(0) - 0x0660}',
    );
    // أول تسلسل أرقام في العنوان هو رقم الحزب
    final m = RegExp(r'\d{1,2}').firstMatch(normalized);
    if (m == null) return null;
    final n = int.tryParse(m.group(0)!);
    return (n != null && n >= 1 && n <= 60) ? n : null;
  }

  // ── يستخرج أوقات الأثمان من وصف الفيديو ────────────────────
  // يدعم mm:ss و hh:mm:ss (مثال: "03:26 - الثمن الثاني").
  // يُرجع القائمة بالثواني للأثمان 2..8 (الثمن الأول = 0 لا يُدرج).
  static List<int> _pageTimesFromDescription(String desc) {
    final re = RegExp(r'(?:(\d{1,2}):)?(\d{1,2}):(\d{2})');
    final times = <int>[];
    for (final m in re.allMatches(desc)) {
      final h  = int.tryParse(m.group(1) ?? '') ?? 0;
      final mi = int.parse(m.group(2)!);
      final s  = int.parse(m.group(3)!);
      final total = h * 3600 + mi * 60 + s;
      if (total > 0) times.add(total); // تجاهل 00:00 (الثمن الأول)
    }
    return times;
  }
}
