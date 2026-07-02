import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// ═══════════════════════════════════════════════════════════
//  LinksService — يجلب روابط يوتيوب/PDF وأوقات الصفحات من Supabase
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
  /// يُرجع خريطة رقم الحزب → روابطه (مع أوقات الصفحات)
  static Future<Map<int, HizbLinks>> load() async {
    if (_cache != null) return _cache!;

    try {
      // جلب الروابط
      final rows = await _db
          .from('hizb_links')
          .select('hizb, youtube, pdf')
          .order('hizb') as List<dynamic>;

      final map = <int, HizbLinks>{
        for (final j in rows)
          (j['hizb'] as int): HizbLinks.fromJson(j as Map<String, dynamic>)
      };

      // جلب أوقات الصفحات ودمجها
      try {
        final times = await _db
            .from('hizb_page_times')
            .select('hizb, page_times')
            as List<dynamic>;

        for (final t in times) {
          final h = t['hizb'] as int;
          if (map.containsKey(h)) {
            final pts = (t['page_times'] as List<dynamic>)
                .map((e) => (e as num).toInt()).toList();
            map[h] = map[h]!.copyWith(pageTimes: pts);
          }
        }
      } catch (_) {
        // جدول page_times غير موجود بعد — لا بأس
      }

      _cache = map;
    } catch (_) {
      final str = await rootBundle.loadString('assets/links.json');
      final raw = jsonDecode(str) as List<dynamic>;
      _cache = {
        for (final j in raw)
          (j['hizb'] as int): HizbLinks.fromJson(j as Map<String, dynamic>)
      };
    }

    return _cache!;
  }

  static Future<void> refresh() async {
    _cache = null;
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
