// ═══════════════════════════════════════════════
//  خوارزمية الختمة الإدارية — نظام الارتكاز
//  دورة واحدة = ٢١ يوماً = ٦٠ حزباً
//  ٦ أيام × ٣ أحزاب + الجمعة × ٢ = ٢٠ حزباً/أسبوع
// ═══════════════════════════════════════════════

class KhatmaCalculator {
  /// نقطة الارتكاز: ١ يوليو ٢٠٢٦ = الأحزاب ١٩، ٢٠، ٢١
  static final DateTime _anchor    = DateTime(2026, 7, 1);
  static const int _anchorFirst    = 19;
  static const int _hizbsPerCycle  = 60;
  static const int _hizbsPerWeek   = 20; // 6×3 + 1×2

  /// modulo دائماً موجب
  static int _mod(int a, int b) => ((a % b) + b) % b;

  // ─────────────────────────────────────────────
  /// يُرجع أرقام الأحزاب المقررة ليوم معين
  static List<int> getHizbsForDate(DateTime date) {
    final target = DateTime(date.year, date.month, date.day);
    final days   = target.difference(_anchor).inDays;

    final hizbsBefore = _countHizbsBeforeDay(days);
    final firstHizb   = _mod(_anchorFirst - 1 + hizbsBefore, _hizbsPerCycle) + 1;
    final isFriday    = target.weekday == DateTime.friday;

    if (isFriday) {
      return [
        firstHizb,
        _mod(firstHizb, _hizbsPerCycle) + 1,
      ];
    } else {
      return [
        firstHizb,
        _mod(firstHizb,     _hizbsPerCycle) + 1,
        _mod(firstHizb + 1, _hizbsPerCycle) + 1,
      ];
    }
  }

  // ─────────────────────────────────────────────
  /// عدد الأحزاب التي قُرئت بين الارتكاز واليوم المحدد
  static int _countHizbsBeforeDay(int days) {
    if (days == 0) return 0;

    if (days > 0) {
      final fullWeeks = days ~/ 7;
      final remaining = days % 7;
      var count = fullWeeks * _hizbsPerWeek;
      for (var i = 0; i < remaining; i++) {
        final d = _anchor.add(Duration(days: fullWeeks * 7 + i));
        count += (d.weekday == DateTime.friday) ? 2 : 3;
      }
      return count;
    } else {
      // قبل نقطة الارتكاز — عد بالعكس
      final absDays    = -days;
      final fullWeeks  = absDays ~/ 7;
      final remaining  = absDays % 7;
      var count = -(fullWeeks * _hizbsPerWeek);
      for (var i = 0; i < remaining; i++) {
        final d = _anchor.subtract(Duration(days: fullWeeks * 7 + i + 1));
        count -= (d.weekday == DateTime.friday) ? 2 : 3;
      }
      return count;
    }
  }

  // ─────────────────────────────────────────────
  /// رقم الدورة (١، ٢، ٣، ...)
  static int getCycleNumber(DateTime date) {
    final days = DateTime(date.year, date.month, date.day)
        .difference(_anchor).inDays;
    return (days ~/ 21) + 1;
  }

  /// يوم الدورة الحالية (١ – ٢١)
  static int getDayInCycle(DateTime date) {
    final days = DateTime(date.year, date.month, date.day)
        .difference(_anchor).inDays;
    return _mod(days, 21) + 1;
  }

  // ─────────────────────────────────────────────
  /// يُرجع تواريخ ليالي الختمة (الأيام التي يُقرأ فيها الحزب 60)
  /// من [from] إلى [to] مرتبةً تصاعدياً
  static List<DateTime> getKhatmaDates(DateTime from, DateTime to) {
    final result = <DateTime>[];
    var d = DateTime(from.year, from.month, from.day);
    final end = DateTime(to.year, to.month, to.day);
    while (!d.isAfter(end)) {
      if (getHizbsForDate(d).contains(60)) result.add(d);
      d = d.add(const Duration(days: 1));
    }
    return result;
  }

  /// أرقام الأحزاب لأسبوع كامل ابتداءً من تاريخ
  static Map<DateTime, List<int>> getWeekHizbs(DateTime weekStart) {
    final result = <DateTime, List<int>>{};
    for (var i = 0; i < 7; i++) {
      final d = weekStart.add(Duration(days: i));
      result[d] = getHizbsForDate(d);
    }
    return result;
  }
}
