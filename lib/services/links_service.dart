import 'package:supabase_flutter/supabase_flutter.dart';
import 'youtube_service.dart';

// ═══════════════════════════════════════════════════════════
//  LinksService — روابط الفيديو من YouTube Data API،
//  وأوقات الصفحات من Supabase. (لم تعد روابط الفيديو من Supabase)
// ═══════════════════════════════════════════════════════════

class HizbLinks {
  final int         hizb;
  final String      youtube;
  final String      pdf;
  // أوقات الصفحات 2→8 بالثواني (الصفحة 1 دائماً = 0)
  final List<int>   pageTimes;

  const HizbLinks({
    required this.hizb,
    required this.youtube,
    required this.pdf,
    this.pageTimes = const [],
  });

  factory HizbLinks.fromJson(Map<String, dynamic> j) => HizbLinks(
    hizb:      (j['hizb']    as int?)    ?? 0,
    youtube:   (j['youtube'] as String?) ?? '',
    pdf:       (j['pdf']     as String?) ?? '',
    pageTimes: (j['page_times'] as List<dynamic>?)
                   ?.map((e) => (e as num).toInt()).toList() ?? [],
  );

  HizbLinks copyWith({String? youtube, String? pdf, List<int>? pageTimes}) =>
      HizbLinks(
        hizb:      hizb,
        youtube:   youtube   ?? this.youtube,
        pdf:       pdf       ?? this.pdf,
        pageTimes: pageTimes ?? this.pageTimes,
      );

  /// وقت البداية (بالثواني) للصفحة المطلوبة
  int secondsForPage(int page) {
    if (page <= 1) return 0;
    final idx = page - 2;
    return (idx < pageTimes.length) ? pageTimes[idx] : 0;
  }

  Map<String, dynamic> toJson() => {
    'hizb': hizb, 'youtube': youtube, 'pdf': pdf, 'page_times': pageTimes
  };
}

// ─────────────────────────────────────────────────────────
class LinksService {
  static Map<int, HizbLinks>? _cache;

  static SupabaseClient get _db => Supabase.instance.client;

  // ─────────────────────────────────────────────────────
  /// يُرجع خريطة رقم الحزب → روابطه (فيديو من يوتيوب + أوقات الصفحات)
  static Future<Map<int, HizbLinks>> load() async {
    if (_cache != null) return _cache!;

    // 1) روابط الفيديو + أوقات الأثمان (من وصف الفيديو) من YouTube Data API
    final youtube = await YoutubeService.load();

    // 2) أوقات الصفحات من Supabase — تُستعمل فقط كبديل إن لم يوفّرها الوصف
    final times = <int, List<int>>{};
    try {
      final rows = await _db
          .from('hizb_page_times')
          .select('hizb, page_times')
          .timeout(const Duration(seconds: 6)) as List<dynamic>;
      for (final t in rows) {
        times[t['hizb'] as int] = (t['page_times'] as List<dynamic>)
            .map((e) => (e as num).toInt()).toList();
      }
    } catch (_) {
      // جدول page_times غير متاح — لا بأس
    }

    // 3) ادمج حسب رقم الحزب — أوقات يوتيوب أولاً ثم Supabase
    final hizbs = <int>{...youtube.keys, ...times.keys};
    _cache = {
      for (final h in hizbs)
        h: HizbLinks(
          hizb:      h,
          youtube:   youtube[h]?.url ?? '',
          pdf:       '',
          pageTimes: (youtube[h]?.pageTimes.isNotEmpty ?? false)
              ? youtube[h]!.pageTimes
              : (times[h] ?? const []),
        ),
    };
    return _cache!;
  }

  static Future<void> refresh() async {
    _cache = null;
    YoutubeService.invalidateCache();
    await load();
  }

  static void invalidateCache() => _cache = null;

  // ─────────────────────────────────────────────────────
  static Future<void> updateLinks(int hizbNumber, {String? youtube, String? pdf}) async {
    final updates = <String, String>{};
    if (youtube != null) updates['youtube'] = youtube;
    if (pdf     != null) updates['pdf']     = pdf;
    if (updates.isEmpty) return;

    await _db.from('hizb_links').update(updates).eq('hizb', hizbNumber);

    if (_cache != null && _cache!.containsKey(hizbNumber)) {
      _cache![hizbNumber] = _cache![hizbNumber]!.copyWith(youtube: youtube, pdf: pdf);
    }
  }

  // ─────────────────────────────────────────────────────
  /// تحديث أوقات الصفحات لحزب واحد
  static Future<void> updatePageTimes(int hizbNumber, List<int> pageTimes) async {
    await _db.from('hizb_page_times').upsert({
      'hizb': hizbNumber,
      'page_times': pageTimes,
    });

    if (_cache != null && _cache!.containsKey(hizbNumber)) {
      _cache![hizbNumber] = _cache![hizbNumber]!.copyWith(pageTimes: pageTimes);
    }
  }

  static HizbLinks? find(Map<int, HizbLinks> links, int hizbNumber) =>
      links[hizbNumber];
}
