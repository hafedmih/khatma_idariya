import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'config/supabase_config.dart';
import 'screens/home_screen.dart';
import 'services/notification_service.dart';
import 'theme/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url:     SupabaseConfig.url,
    anonKey: SupabaseConfig.anonKey,
  );

  // تذكيرات الورد اليومية
  await NotificationService.init();
  await NotificationService.requestPermission();
  await NotificationService.reschedule();

  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  runApp(const KhatmaApp());
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
