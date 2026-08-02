import 'package:flutter/foundation.dart' show kIsWeb, Uint8List;
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
  static Future<void> signInWithApple()    => signInWith(OAuthProvider.apple);
  static Future<void> signInWithFacebook() => signInWith(OAuthProvider.facebook);

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
