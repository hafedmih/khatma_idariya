import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class AppTheme {
  // ═══ الألوان الرئيسية ═══
  static const Color primary    = Color(0xFF1A5C38);
  static const Color primaryDk  = Color(0xFF0F3D26);
  static const Color primaryLt  = Color(0xFF2E8B57);
  static const Color gold       = Color(0xFFD4A017);
  static const Color goldLight  = Color(0xFFFFF3CD);

  // ═══ الخلفية والسطوح ═══
  static const Color background = Color(0xFFF8F5F0);
  static const Color surface    = Color(0xFFFFFFFF);
  static const Color surfaceDim = Color(0xFFF0EDE8);

  // ═══ النصوص ═══
  static const Color textHigh   = Color(0xFF1A1A1A);
  static const Color textMed    = Color(0xFF555555);
  static const Color textLow    = Color(0xFF999999);

  // ═══ ألوان الحزب الثلاثة ═══
  static const List<List<Color>> hizbGradients = [
    [Color(0xFF1A5C38), Color(0xFF2E8B57)], // حزب أول  — أخضر
    [Color(0xFF1E3A8A), Color(0xFF3B5FCC)], // حزب ثانٍ — أزرق
    [Color(0xFF7C3238), Color(0xFFA0522D)], // حزب ثالث — بني
  ];

  static ThemeData get theme => ThemeData(
    useMaterial3: true,
    fontFamily: 'Cairo',
    scaffoldBackgroundColor: background,
    colorScheme: ColorScheme.fromSeed(
      seedColor: primary,
      primary: primary,
      secondary: gold,
      surface: surface,
      brightness: Brightness.light,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: primary,
      foregroundColor: Colors.white,
      centerTitle: true,
      elevation: 0,
      systemOverlayStyle: SystemUiOverlayStyle(
        statusBarColor: primaryDk,
        statusBarIconBrightness: Brightness.light,
      ),
    ),
    cardTheme: CardThemeData(
      color: surface,
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    ),
    dividerTheme: const DividerThemeData(color: Color(0xFFE8E4DF), thickness: 1),
    textTheme: const TextTheme(
      headlineLarge:  TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: textHigh),
      headlineMedium: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: textHigh),
      titleLarge:     TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: textHigh),
      titleMedium:    TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: textHigh),
      bodyLarge:      TextStyle(fontSize: 16, height: 1.9,  color: textHigh),
      bodyMedium:     TextStyle(fontSize: 14, height: 1.7,  color: textMed),
      bodySmall:      TextStyle(fontSize: 12, color: textLow),
    ),
  );
}
