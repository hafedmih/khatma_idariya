import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/account_service.dart';
import '../theme/app_theme.dart';
import 'account_screen.dart';
import 'my_khatma_screen.dart';
import 'groups_screen.dart';

// ═══════════════════════════════════════════════
//  شاشة ختمتي (ختمة الإدارة) — مستقلّة عن المجموعات
// ═══════════════════════════════════════════════
class MyKhatmaHubScreen extends StatelessWidget {
  const MyKhatmaHubScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return _GatedScreen(
      title: 'ختمتي',
      loginHint: 'سجّل الدخول لمتابعة وردك في ختمة الإدارة\nواحتساب أيام التتابع',
      childBuilder: () => const MyKhatmaScreen(embedded: true),
    );
  }
}

// ═══════════════════════════════════════════════
//  شاشة المجموعات — لكل مجموعة ختمتها الخاصة
// ═══════════════════════════════════════════════
class GroupsHubScreen extends StatelessWidget {
  const GroupsHubScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return _GatedScreen(
      title: 'المجموعات',
      loginHint: 'سجّل الدخول لإنشاء مجموعاتك والانضمام إليها\nولكل مجموعة ختمتها الخاصة',
      childBuilder: () => const GroupsScreen(embedded: true),
    );
  }
}

// شاشة عامّة تتطلّب تسجيل الدخول ثم تعرض محتواها
class _GatedScreen extends StatelessWidget {
  final String title;
  final String loginHint;
  final Widget Function() childBuilder;
  const _GatedScreen({required this.title, required this.loginHint, required this.childBuilder});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AuthState>(
      stream: AccountService.authChanges,
      builder: (context, _) {
        final loggedIn = AccountService.isLoggedIn;
        return Scaffold(
          backgroundColor: AppTheme.background,
          appBar: AppBar(
            backgroundColor: AppTheme.primary,
            foregroundColor: Colors.white,
            centerTitle: true,
            title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
          ),
          body: loggedIn ? childBuilder() : _loginPrompt(context),
        );
      },
    );
  }

  Widget _loginPrompt(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.account_circle_rounded, size: 84, color: AppTheme.primary),
            const SizedBox(height: 14),
            Text(
              loginHint,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 16, color: AppTheme.textMed),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () => Navigator.push(
                  context, MaterialPageRoute(builder: (_) => const AccountScreen())),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primary,
                padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 13),
              ),
              child: const Text('تسجيل الدخول',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
            ),
          ],
        ),
      ),
    );
  }
}
