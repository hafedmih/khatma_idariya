import 'package:flutter/foundation.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../firebase_options.dart';

// ═══════════════════════════════════════════════
//  إشعارات Firebase Cloud Messaging (FCM) — تصل حتى والتطبيق مغلق
//  نُسجّل رمز الجهاز (token) في جدول device_tokens مربوطاً بمعرّف المستخدم،
//  فيرسل الخادم الإشعار لأجهزة المستخدم المعنيّ.
// ═══════════════════════════════════════════════
class PushService {
  static bool _inited = false;
  static String? _token;

  static SupabaseClient get _sb => Supabase.instance.client;

  // تهيئة Firebase + الاستماع لتجديد الرمز — تُستدعى مرة عند الإقلاع
  static Future<void> init() async {
    if (_inited) return;
    try {
      await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
      _inited = true;
      await FirebaseMessaging.instance.requestPermission();
      _token = await FirebaseMessaging.instance.getToken();
      // سجّل الرمز إن كان المستخدم مسجّلاً بالفعل
      if (_sb.auth.currentUser != null) await _saveToken();
      FirebaseMessaging.instance.onTokenRefresh.listen((t) {
        _token = t;
        _saveToken();
      });
    } catch (e) {
      debugPrint('FCM init failed: $e');
    }
  }

  // حفظ/تحديث رمز الجهاز للمستخدم الحالي
  static Future<void> _saveToken() async {
    final u = _sb.auth.currentUser;
    final t = _token;
    if (u == null || t == null || t.isEmpty) return;
    try {
      await _sb.from('device_tokens').upsert({
        'token': t,
        'user_id': u.id,
        'platform': defaultTargetPlatform.name,
      });
    } catch (e) {
      debugPrint('save token failed: $e');
    }
  }

  // عند تسجيل الدخول: اربط رمز هذا الجهاز بالمستخدم
  static Future<void> login(String userId) async {
    if (!_inited) return;
    _token ??= await FirebaseMessaging.instance.getToken();
    await _saveToken();
  }

  // عند تسجيل الخروج: افصل رمز هذا الجهاز
  static Future<void> logout() async {
    final t = _token;
    if (t == null) return;
    try {
      await _sb.from('device_tokens').delete().eq('token', t);
    } catch (e) {
      debugPrint('delete token failed: $e');
    }
  }
}
