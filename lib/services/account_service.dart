import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart'
    show kIsWeb, Uint8List, defaultTargetPlatform, TargetPlatform;
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/account_models.dart';

// ═══════════════════════════════════════════════
//  المصادقة + الملف الشخصي + الإحصائيات + الإنجازات
// ═══════════════════════════════════════════════
class AccountService {
  static SupabaseClient get _sb => Supabase.instance.client;

  // مخطط إعادة التوجيه بعد تسجيل الدخول (يجب ضبطه في المنصّات وفي Supabase)
  static const String _redirect = 'com.hafedmih.khatma://login-callback';

  static User? get user => _sb.auth.currentUser;
  static bool get isLoggedIn => user != null;
  static Stream<AuthState> get authChanges => _sb.auth.onAuthStateChange;

  // ── تسجيل الدخول عبر مزوّد (Google / Apple / Facebook) ──
  static Future<void> signInWith(OAuthProvider provider) {
    return _sb.auth.signInWithOAuth(
      provider,
      redirectTo: kIsWeb ? null : _redirect,
    );
  }

  static Future<void> signInWithGoogle()   => signInWith(OAuthProvider.google);
  static Future<void> signInWithFacebook() => signInWith(OAuthProvider.facebook);

  // ── تسجيل الدخول عبر Apple ──
  // على iOS/macOS نستخدم واجهة Apple الأصلية (Face ID، دون متصفّح)؛
  // أمّا على أندرويد والويب فنُكمل بمسار OAuth عبر المتصفّح.
  static bool get _appleIsNative =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.iOS ||
          defaultTargetPlatform == TargetPlatform.macOS);

  static Future<void> signInWithApple() async {
    if (!_appleIsNative) return signInWith(OAuthProvider.apple);

    // nonce: نُرسل بصمته إلى Apple ونُرسل الأصل إلى Supabase ليتحقّق من الرمز.
    final rawNonce = _randomNonce();
    final hashedNonce = sha256.convert(utf8.encode(rawNonce)).toString();

    final AuthorizationCredentialAppleID cred;
    try {
      cred = await SignInWithApple.getAppleIDCredential(
        scopes: const [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
        nonce: hashedNonce,
      );
    } on SignInWithAppleAuthorizationException catch (e) {
      // إلغاء المستخدم ليس خطأ — نخرج بهدوء دون رسالة حمراء.
      if (e.code == AuthorizationErrorCode.canceled) return;
      rethrow;
    }

    final idToken = cred.identityToken;
    if (idToken == null) {
      throw AuthException('لم تُرجع Apple رمز الهوية');
    }

    await _sb.auth.signInWithIdToken(
      provider: OAuthProvider.apple,
      idToken: idToken,
      nonce: rawNonce,
    );

    // Apple تُرسل الاسم في أوّل تصريح فقط — نحفظه قبل أن يضيع نهائياً،
    // لأنّ مُشغّل قاعدة البيانات يكتفي بمقطع البريد قبل @ عند غياب الاسم.
    final name = [cred.givenName, cred.familyName]
        .whereType<String>()
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .join(' ');
    if (name.isNotEmpty) {
      try {
        await _sb.auth.updateUser(UserAttributes(data: {'full_name': name}));
        await updateDisplayName(name);
      } catch (_) {
        // فشل حفظ الاسم لا يُبطل تسجيل دخول ناجح.
      }
    }
  }

  static String _randomNonce([int length = 32]) {
    const chars =
        '0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz-._';
    final rnd = Random.secure();
    return List.generate(length, (_) => chars[rnd.nextInt(chars.length)]).join();
  }

  // ── بديل: بريد/كلمة مرور (للاختبار قبل ضبط OAuth) ──
  static Future<void> signInEmail(String email, String password) =>
      _sb.auth.signInWithPassword(email: email, password: password);
  static Future<void> signUpEmail(String email, String password, {String? name}) =>
      _sb.auth.signUp(email: email, password: password, data: {
        if (name != null) 'full_name': name,
      });

  static Future<void> signOut() => _sb.auth.signOut();

  // ── حذف الحساب وكل بياناته نهائياً ──
  static Future<void> deleteAccount() async {
    await _sb.rpc('delete_my_account');
    try { await _sb.auth.signOut(); } catch (_) {}
  }

  // ── الملف الشخصي ──
  static Future<Profile?> myProfile() async {
    final u = user;
    if (u == null) return null;
    final m = await _sb
        .from('profiles')
        .select('id, display_name, avatar_url, total_points, current_level, current_streak, longest_streak')
        .eq('id', u.id)
        .maybeSingle();
    return m == null ? null : Profile.fromMap(m);
  }

  static Future<void> updateDisplayName(String name) async {
    final u = user;
    if (u == null) return;
    await _sb.from('profiles').update({'display_name': name}).eq('id', u.id);
  }

  // ── رفع صورة الملف الشخصي من المعرض إلى Supabase Storage (bucket: avatars) ──
  static Future<String?> uploadAvatar(Uint8List bytes, String ext, String? contentType) async {
    final u = user;
    if (u == null) return null;
    final safeExt = ext.isEmpty ? 'jpg' : ext;
    final path = '${u.id}/avatar_${DateTime.now().millisecondsSinceEpoch}.$safeExt';
    await _sb.storage.from('avatars').uploadBinary(
          path,
          bytes,
          fileOptions: FileOptions(upsert: true, contentType: contentType ?? 'image/$safeExt'),
        );
    final url = _sb.storage.from('avatars').getPublicUrl(path);
    await _sb.from('profiles').update({'avatar_url': url}).eq('id', u.id);
    return url;
  }

  // ── الإحصائيات ──
  static Future<UserStats?> myStats() async {
    final u = user;
    if (u == null) return null;
    final m = await _sb.from('v_user_stats').select().eq('user_id', u.id).maybeSingle();
    return m == null ? null : UserStats.fromMap(m);
  }

  // ── الإنجازات (الكتالوج + المكتسبة) ──
  static Future<List<AchievementInfo>> achievements() async {
    final u = user;
    final all = await _sb.from('achievements').select().order('sort');
    final earned = <String>{};
    if (u != null) {
      final mine = await _sb
          .from('user_achievements')
          .select('achievement_code')
          .eq('user_id', u.id);
      for (final r in (mine as List)) {
        earned.add(r['achievement_code'] as String);
      }
    }
    return (all as List).map((m) {
      final map = m as Map<String, dynamic>;
      return AchievementInfo(
        code: map['code'] as String,
        title: (map['title'] as String?) ?? '',
        description: map['description'] as String?,
        icon: map['icon'] as String?,
        points: (map['points'] as num?)?.toInt() ?? 0,
        earned: earned.contains(map['code']),
      );
    }).toList();
  }
}
