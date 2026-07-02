// ═══════════════════════════════════════════════
//  نماذج بيانات الختمة الإدارية
// ═══════════════════════════════════════════════

class RangePoint {
  final String surah;
  final int    surahNumber;
  final int    ayah;

  const RangePoint({
    required this.surah,
    required this.surahNumber,
    required this.ayah,
  });

  factory RangePoint.fromJson(Map<String, dynamic> j) => RangePoint(
    surah:       (j['surah'] as String?)  ?? '',
    surahNumber: (j['surah_number'] as int?) ?? 0,
    ayah:        (j['ayah'] as int?)      ?? 0,
  );
}

// ─────────────────────────────────────────────
class Thumn {
  final int    number;
  final String surah;
  final int    surahNumber;
  final int    ayah;
  final String openingVerse;

  const Thumn({
    required this.number,
    required this.surah,
    required this.surahNumber,
    required this.ayah,
    required this.openingVerse,
  });

  factory Thumn.fromJson(Map<String, dynamic> j) => Thumn(
    number:       (j['thumn'] as int?)          ?? 0,
    surah:        (j['surah'] as String?)        ?? '',
    surahNumber:  (j['surah_number'] as int?)    ?? 0,
    ayah:         (j['ayah'] as int?)            ?? 0,
    openingVerse: (j['opening_verse'] as String?) ?? '',
  );

  static const _ordinals = [
    'الأول','الثاني','الثالث','الرابع',
    'الخامس','السادس','السابع','الثامن',
  ];

  String get ordinalLabel {
    final i = number - 1;
    return (i >= 0 && i < _ordinals.length) ? _ordinals[i] : '$number';
  }
}

// ─────────────────────────────────────────────
class Hizb {
  final int        number;
  final String     openingVerse;
  final String     youtube;
  final String     pdf;
  final RangePoint from;
  final RangePoint to;
  final List<Thumn> athman;

  const Hizb({
    required this.number,
    required this.openingVerse,
    required this.youtube,
    required this.pdf,
    required this.from,
    required this.to,
    required this.athman,
  });

  factory Hizb.fromJson(Map<String, dynamic> j) {
    final range = j['range'] as Map<String, dynamic>? ?? {};
    return Hizb(
      number:       (j['hizb'] as int?)          ?? 0,
      openingVerse: (j['opening_verse'] as String?) ?? '',
      youtube:      (j['youtube'] as String?)     ?? '',
      pdf:          (j['pdf'] as String?)         ?? '',
      from: RangePoint.fromJson(range['from'] as Map<String, dynamic>? ?? {}),
      to:   RangePoint.fromJson(range['to']   as Map<String, dynamic>? ?? {}),
      athman: (j['athman'] as List? ?? [])
          .map((t) => Thumn.fromJson(t as Map<String, dynamic>))
          .toList(),
    );
  }

  bool get hasYoutube => youtube.isNotEmpty;
  bool get hasPdf     => pdf.isNotEmpty;

  String get rangeShort =>
    '${from.surah} (${from.ayah}) ← ${to.surah} (${to.ayah})';

  String get rangeFull =>
    'من سورة ${from.surah} الآية ${from.ayah}'
    ' إلى سورة ${to.surah} الآية ${to.ayah}';
}
