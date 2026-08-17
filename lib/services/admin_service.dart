import 'package:supabase_flutter/supabase_flutter.dart';

// ═══════════════════════════════════════════════
//  AdminService — التحقّق من صلاحية المشرف
//  القائمة في جدول public.app_admins (يقبل أكثر من مشرف)،
//  والتحقّق عبر الدالة public.is_admin() في Supabase.
//  ملاحظة: هذا التحقّق للواجهة فقط؛ الحماية الفعلية في RLS.
// ═══════════════════════════════════════════════
class AdminService {
  static SupabaseClient get _sb => Supabase.instance.client;

  static bool? _cached;

  /// هل المستخدم الحالي مشرف؟ يُخزَّن الجواب لتفادي نداءٍ متكرّر.
  static Future<bool> isAdmin({bool refresh = false}) async {
    if (_sb.auth.currentUser == null) {
      _cached = false;
      return false;
    }
    if (!refresh && _cached != null) return _cached!;
    try {
      final res = await _sb.rpc('is_admin');
      _cached = res == true;
    } catch (_) {
      // الدالة غير منشورة بعد أو تعذّر الاتصال — لا صلاحية.
      _cached = false;
    }
    return _cached!;
  }

  /// استدعِها عند تسجيل الدخول أو الخروج.
  static void invalidate() => _cached = null;
}
