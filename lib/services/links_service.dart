import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// ═══════════════════════════════════════════════════════════
//  LinksService — يجلب روابط يوتيوب/PDF من Supabase
//  مع رجوع تلقائي للملف المحلي عند انعدام الاتصال
// ═══════════════════════════════════════════════════════════

class HizbLinks {
  final int    hizb;
  final String youtube;
  final String pdf;

  const HizbLinks({
    required this.hizb,
    required this.youtube,
    required this.pdf,
  });

  factory HizbLinks.fromJson(Map<String, dynamic> j) => HizbLinks(
    hizb:    (j['hizb']    as int?)    ?? 0,
    youtube: (j['youtube'] as String?) ?? '',
    pdf:     (j['pdf']     as String?) ?? '',
  );

  HizbLinks copyWith({String? youtube, String? pdf}) => HizbLinks(
    hizb:    hizb,
    youtube: youtube ?? this.youtube,
    pdf:     pdf     ?? this.pdf,
  );

  Map<String, dynamic> toJson() => {'hizb': hizb, 'youtube': youtube, 'pdf': pdf};
}

// ─────────────────────────────────────────────────────────
class LinksService {
  static Map<int, HizbLinks>? _cache;

  static SupabaseClient get _db => Supabase.instance.client;

  // ─────────────────────────────────────────────────────
  /// يُرجع خريطة رقم الحزب → روابطه
  static Future<Map<int, HizbLinks>> load() async {
    if (_cache != null) return _cache!;

    try {
      final rows = await _db
          .from('hizb_links')
          .select('hizb, youtube, pdf')
          .order('hizb') as List<dynamic>;

      _cache = {
        for (final j in rows)
          (j['hizb'] as int): HizbLinks.fromJson(j as Map<String, dynamic>)
      };
    } catch (_) {
      // رجوع للملف المحلي عند انعدام الاتصال
      final str = await rootBundle.loadString('assets/links.json');
      final raw = jsonDecode(str) as List<dynamic>;
      _cache = {
        for (final j in raw)
          (j['hizb'] as int): HizbLinks.fromJson(j as Map<String, dynamic>)
      };
    }

    return _cache!;
  }

  /// مسح الكاش وإعادة التحميل من Supabase
  static Future<void> refresh() async {
    _cache = null;
    await load();
  }

  static void invalidateCache() => _cache = null;

  // ─────────────────────────────────────────────────────
  /// تحديث رابط حزب واحد في Supabase (للإدارة فقط)
  static Future<void> updateLinks(int hizbNumber, {String? youtube, String? pdf}) async {
    final updates = <String, String>{};
    if (youtube != null) updates['youtube'] = youtube;
    if (pdf     != null) updates['pdf']     = pdf;
    if (updates.isEmpty) return;

    await _db
        .from('hizb_links')
        .update(updates)
        .eq('hizb', hizbNumber);

    // تحديث الكاش مباشرة
    if (_cache != null && _cache!.containsKey(hizbNumber)) {
      _cache![hizbNumber] = _cache![hizbNumber]!.copyWith(
        youtube: youtube,
        pdf:     pdf,
      );
    }
  }

  // ─────────────────────────────────────────────────────
  /// إيجاد روابط حزب محدد
  static HizbLinks? find(Map<int, HizbLinks> links, int hizbNumber) =>
      links[hizbNumber];
}
