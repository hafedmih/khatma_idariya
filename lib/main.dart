import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:audio_session/audio_session.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'config/supabase_config.dart';
import 'screens/home_screen.dart';
import 'services/notification_service.dart';
import 'services/push_service.dart';
import 'theme/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // لا نسمح لأي تهيئة بأن تمنع إقلاع الواجهة (تفادي التعلّق عند شاشة البداية)
  try {
    await Supabase.initialize(
      url:     SupabaseConfig.url,
      anonKey: SupabaseConfig.anonKey,
    );
  } catch (e) {
    debugPrint('Supabase init failed: $e');
  }

  // إعداد جلسة الصوت لتلاوة القرآن — تستمر التلاوة عند قفل الشاشة/الخلفية
  try {
    final session = await AudioSession.instance;
    await session.configure(const AudioSessionConfiguration.speech());
  } catch (e) {
    debugPrint('AudioSession config failed: $e');
  }

  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  runApp(const KhatmaApp());

  // تذكيرات الورد اليومية — تُهيَّأ بعد إقلاع الواجهة، وأي خطأ لا يُعطّل التطبيق
  _setupNotifications();
  _setupPush();
}

Future<void> _setupNotifications() async {
  try {
    await NotificationService.init();
    await NotificationService.requestPermission();
    await NotificationService.reschedule();
  } catch (e) {
    debugPrint('Notifications setup failed: $e');
  }
}

// إشعارات Firebase (Push) + ربط رمز الجهاز بالمستخدم عند الدخول/الخروج
Future<void> _setupPush() async {
  try {
    await PushService.init();
    // اربط المستخدم الحالي إن كان مسجّلاً، وتابع تغيّرات الجلسة
    final current = Supabase.instance.client.auth.currentUser;
    if (current != null) await PushService.login(current.id);
    Supabase.instance.client.auth.onAuthStateChange.listen((state) {
      final u = state.session?.user;
      if (u != null) {
        PushService.login(u.id);
      } else {
        PushService.logout();
      }
    });
  } catch (e) {
    debugPrint('Push setup failed: $e');
  }
}

class KhatmaApp extends StatelessWidget {
  const KhatmaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title:                 'القرآن الكريم - ختمة الإدارة',
      debugShowCheckedModeBanner: false,
      theme:                 AppTheme.theme,
      locale:                const Locale('ar'),
      supportedLocales:      const [Locale('ar'), Locale('en')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: const HomeScreen(),
    );
  }
}
