import 'package:shared_preferences/shared_preferences.dart';

// ═══════════════════════════════════════════════
//  حفظ آخر موضع قراءة (حزب + صفحة) لاستئناف القراءة
// ═══════════════════════════════════════════════
class ReadingProgress {
  static const _kHizb = 'resume_hizb';
  static const _kPage = 'resume_page';

  // حفظ الموضع الحالي أثناء القراءة
  static Future<void> save(int hizb, int page) async {
    if (hizb < 1) return;
    final p = await SharedPreferences.getInstance();
    await p.setInt(_kHizb, hizb);
    await p.setInt(_kPage, page);
  }

  // آخر موضع محفوظ — {hizb, page} أو null
  static Future<({int hizb, int page})?> get() async {
    final p = await SharedPreferences.getInstance();
    final h = p.getInt(_kHizb);
    final pg = p.getInt(_kPage);
    if (h == null || pg == null) return null;
    return (hizb: h, page: pg);
  }

  static Future<void> clear() async {
    final p = await SharedPreferences.getInstance();
    await p.remove(_kHizb);
    await p.remove(_kPage);
  }
}
