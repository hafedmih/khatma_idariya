import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/account_models.dart';
import '../services/account_service.dart';
import '../theme/app_theme.dart';

class AccountScreen extends StatefulWidget {
  const AccountScreen({super.key});
  @override
  State<AccountScreen> createState() => _AccountScreenState();
}

class _AccountScreenState extends State<AccountScreen> {
  bool _busy = false;
  bool _isSignUp = false; // تبديل بين تسجيل الدخول وإنشاء حساب
  final _emailCtrl = TextEditingController();
  final _passCtrl  = TextEditingController();

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  // تسجيل الدخول أو إنشاء حساب بالبريد وكلمة المرور
  Future<void> _emailAuth() async {
    final email = _emailCtrl.text.trim();
    final pass  = _passCtrl.text;
    if (email.isEmpty || pass.length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('أدخل بريداً صحيحاً وكلمة مرور لا تقل عن 6 أحرف')));
      return;
    }
    await _run(() async {
      if (_isSignUp) {
        await AccountService.signUpEmail(email, pass);
      } else {
        await AccountService.signInEmail(email, pass);
      }
    });
  }

  // اختيار صورة من المعرض ورفعها كصورة ملف شخصي
  Future<void> _pickAvatar() async {
    try {
      final x = await ImagePicker().pickImage(
          source: ImageSource.gallery, maxWidth: 600, imageQuality: 85);
      if (x == null) return;
      final bytes = await x.readAsBytes();
      final ext = x.name.contains('.') ? x.name.split('.').last.toLowerCase() : 'jpg';
      await _run(() => AccountService.uploadAvatar(bytes, ext, x.mimeType));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('تم تحديث الصورة')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('تعذّر: $e'), backgroundColor: Colors.red));
      }
    }
  }

  Future<void> _run(Future<void> Function() action) async {
    setState(() => _busy = true);
    try {
      await action();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('تعذّر: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: AppTheme.primary,
        foregroundColor: Colors.white,
        title: const Text('حسابي', style: TextStyle(fontWeight: FontWeight.w700)),
        centerTitle: true,
      ),
      body: StreamBuilder<AuthState>(
        stream: AccountService.authChanges,
        builder: (context, _) {
          return AccountService.isLoggedIn ? _profile() : _login();
        },
      ),
    );
  }

  // ── واجهة تسجيل الدخول ──
  Widget _login() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          const SizedBox(height: 20),
          const Icon(Icons.account_circle_rounded, size: 90, color: AppTheme.primary),
          const SizedBox(height: 12),
          const Text('سجّل الدخول لحفظ تقدّمك ومزامنته',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          const Text('نقاط، إنجازات، ختمات، ومجموعات',
              style: TextStyle(color: AppTheme.textMed, fontSize: 13)),
          const SizedBox(height: 28),
          // ── الدخول بالبريد وكلمة المرور ──
          TextField(
            controller: _emailCtrl,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.next,
            decoration: InputDecoration(
              labelText: 'البريد الإلكتروني',
              prefixIcon: const Icon(Icons.email_outlined),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              filled: true,
              fillColor: AppTheme.surface,
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _passCtrl,
            obscureText: true,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _emailAuth(),
            decoration: InputDecoration(
              labelText: 'كلمة المرور',
              prefixIcon: const Icon(Icons.lock_outline_rounded),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              filled: true,
              fillColor: AppTheme.surface,
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _busy ? null : _emailAuth,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primary,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: Text(_isSignUp ? 'إنشاء حساب' : 'تسجيل الدخول',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 15)),
            ),
          ),
          TextButton(
            onPressed: _busy ? null : () => setState(() => _isSignUp = !_isSignUp),
            child: Text(_isSignUp
                ? 'لديك حساب؟ تسجيل الدخول'
                : 'ليس لديك حساب؟ إنشاء حساب'),
          ),
          // ── فاصل ──
          Row(children: const [
            Expanded(child: Divider()),
            Padding(padding: EdgeInsets.symmetric(horizontal: 10),
                child: Text('أو', style: TextStyle(color: AppTheme.textMed))),
            Expanded(child: Divider()),
          ]),
          const SizedBox(height: 16),
          // تسجيل الدخول عبر Apple — مطلوب من Apple عند تقديم دخول اجتماعي آخر
          _oauthBtn('المتابعة عبر Apple', Colors.black, Icons.apple,
              () => _run(AccountService.signInWithApple)),
          const SizedBox(height: 10),
          _oauthBtn('المتابعة عبر Google', const Color(0xFF4285F4), Icons.g_mobiledata_rounded,
              () => _run(AccountService.signInWithGoogle)),
          const SizedBox(height: 10),
          _oauthBtn('المتابعة عبر Facebook', const Color(0xFF1877F2), Icons.facebook_rounded,
              () => _run(AccountService.signInWithFacebook)),
          const SizedBox(height: 20),
          if (_busy) const CircularProgressIndicator(color: AppTheme.primary),
        ],
      ),
    );
  }

  Widget _oauthBtn(String label, Color color, IconData icon, VoidCallback onTap) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: _busy ? null : onTap,
        icon: Icon(icon, color: Colors.white),
        label: Text(label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
    );
  }

  // ── واجهة الملف الشخصي ──
  Widget _profile() {
    return FutureBuilder<List<Object?>>(
      future: Future.wait([
        AccountService.myProfile(),
        AccountService.myStats(),
        AccountService.achievements(),
      ]),
      builder: (context, snap) {
        if (!snap.hasData) {
          return const Center(child: CircularProgressIndicator(color: AppTheme.primary));
        }
        final profile = snap.data![0] as Profile?;
        final stats = snap.data![1] as UserStats?;
        final achs = (snap.data![2] as List<AchievementInfo>).where((a) => a.earned).toList();
        return SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(16, 16, 16, 24 + MediaQuery.of(context).viewPadding.bottom),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _headerCard(profile, stats),
              const SizedBox(height: 14),
              _statsGrid(stats),
              const SizedBox(height: 20),
              const Text('الإنجازات', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
              const SizedBox(height: 10),
              if (achs.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: Text('لا إنجازات بعد. تابع القراءة لتحصل على إنجازاتك.',
                      style: TextStyle(color: AppTheme.textMed)),
                )
              else
                ...achs.map(_achTile),
              const SizedBox(height: 20),
              OutlinedButton.icon(
                onPressed: () => _run(AccountService.signOut),
                icon: const Icon(Icons.logout_rounded, color: AppTheme.primary),
                label: const Text('تسجيل الخروج', style: TextStyle(color: AppTheme.primary)),
              ),
              const SizedBox(height: 10),
              TextButton.icon(
                onPressed: _confirmDelete,
                icon: const Icon(Icons.delete_forever_rounded, color: Colors.red, size: 20),
                label: const Text('حذف الحساب وكل البيانات', style: TextStyle(color: Colors.red)),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _confirmDelete() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('حذف الحساب'),
        content: const Text(
          'سيُحذف حسابك وكل بياناتك (الختمات، التقدّم، النقاط، الإنجازات، المجموعات) '
          'نهائياً ولا يمكن التراجع. هل أنت متأكد؟',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('حذف نهائي', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (ok == true) {
      await _run(AccountService.deleteAccount);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تم حذف الحساب')),
        );
      }
    }
  }

  Widget _headerCard(Profile? p, UserStats? s) {
    final level = s?.currentLevel ?? p?.currentLevel ?? 1;
    final points = s?.totalPoints ?? p?.totalPoints ?? 0;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppTheme.primaryDk, AppTheme.primary, AppTheme.primaryLt],
          begin: Alignment.topRight, end: Alignment.bottomLeft,
        ),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: _busy ? null : _pickAvatar,
            child: Stack(children: [
              CircleAvatar(
                radius: 30, backgroundColor: Colors.white24,
                backgroundImage: (p?.avatarUrl != null) ? NetworkImage(p!.avatarUrl!) : null,
                child: p?.avatarUrl == null
                    ? const Icon(Icons.person, color: Colors.white, size: 32) : null,
              ),
              Positioned(
                right: 0, bottom: 0,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: AppTheme.gold,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 1.5),
                  ),
                  child: const Icon(Icons.camera_alt_rounded, color: Colors.white, size: 13),
                ),
              ),
            ]),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(p?.displayName ?? 'مستخدم',
                    style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800)),
                const SizedBox(height: 4),
                Text('المستوى $level  •  $points نقطة',
                    style: const TextStyle(color: Colors.white70, fontSize: 13)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _statsGrid(UserStats? s) {
    Widget cell(String k, String v, IconData ic) => Expanded(
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 4),
            padding: const EdgeInsets.symmetric(vertical: 14),
            decoration: BoxDecoration(
              color: AppTheme.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFE8E4DF)),
            ),
            child: Column(children: [
              Icon(ic, color: AppTheme.primary, size: 22),
              const SizedBox(height: 6),
              Text(v, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
              Text(k, style: const TextStyle(color: AppTheme.textMed, fontSize: 11)),
            ]),
          ),
        );
    return Row(children: [
      cell('ختمات', '${s?.completedKhatmas ?? 0}', Icons.menu_book_rounded),
      cell('أيام التزام', '${s?.activeDays ?? 0}', Icons.calendar_month_rounded),
      cell('أطول تتابع', '${s?.longestStreak ?? 0}', Icons.local_fire_department_rounded),
    ]);
  }

  Widget _achTile(AchievementInfo a) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: a.earned ? AppTheme.goldLight : AppTheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: a.earned ? AppTheme.gold.withOpacity(.5) : const Color(0xFFE8E4DF)),
      ),
      child: Row(children: [
        Opacity(opacity: a.earned ? 1 : .4, child: Text(a.icon ?? '🏅', style: const TextStyle(fontSize: 26))),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(a.title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
            if (a.description != null)
              Text(a.description!, style: const TextStyle(color: AppTheme.textMed, fontSize: 12)),
          ]),
        ),
        if (a.earned) const Icon(Icons.check_circle_rounded, color: AppTheme.gold),
      ]),
    );
  }
}
