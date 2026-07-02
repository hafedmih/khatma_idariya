import 'dart:convert';
import 'package:flutter/services.dart';
import '../models/hizb.dart';

class HizbService {
  static List<Hizb>? _cache;

  /// تحميل الأحزاب من الـ assets (مع cache)
  static Future<List<Hizb>> loadAhzab() async {
    if (_cache != null) return _cache!;
    final jsonStr = await rootBundle.loadString('assets/ahzab.json');
    final list    = jsonDecode(jsonStr) as List;
    _cache = list.map((j) => Hizb.fromJson(j as Map<String, dynamic>)).toList();
    return _cache!;
  }

  /// إيجاد حزب برقمه (١-٦٠)
  static Hizb? find(List<Hizb> ahzab, int number) {
    try {
      return ahzab.firstWhere((h) => h.number == number);
    } catch (_) {
      return null;
    }
  }

  /// قائمة أحزاب محددة
  static List<Hizb> findMultiple(List<Hizb> ahzab, List<int> numbers) {
    return numbers
        .map((n) => find(ahzab, n))
        .whereType<Hizb>()
        .toList();
  }
}
