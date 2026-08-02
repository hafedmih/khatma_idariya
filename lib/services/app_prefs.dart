import 'package:shared_preferences/shared_preferences.dart';

// ═══════════════════════════════════════════════
//  تفضيلات عامة للتطبيق
// ═══════════════════════════════════════════════
class AppPrefs {
  static const _kAutoRecite = 'auto_recite';

  // بدء التلاوة تلقائياً مع الحزب (افتراضياً: غير مفعّل)
  static Future<bool> autoRecite() async =>
      (await SharedPreferences.getInstance()).getBool(_kAutoRecite) ?? false;

  static Future<void> setAutoRecite(bool v) async =>
      (await SharedPreferences.getInstance()).setBool(_kAutoRecite, v);
}
