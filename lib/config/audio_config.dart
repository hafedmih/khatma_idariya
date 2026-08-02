// ═══════════════════════════════════════════════
//  إعداد الملفات الصوتية (MP3) — حاوية Supabase العامة «audio»
//  الملفات: 1.mp3 … 60.mp3
// ═══════════════════════════════════════════════
class AudioConfig {
  static const String base =
      'https://lushhkoveifkmtyzevpg.supabase.co/storage/v1/object/public/audio';

  static String urlFor(int hizb) => '$base/$hizb.mp3';

  static bool hasAudioFor(int hizb) => hizb >= 1 && hizb <= 60;
}
