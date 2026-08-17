// ═══════════════════════════════════════════════
//  إعداد الملفات الصوتية (MP3) — حاوية Supabase العامة «audio»
//  الملفات: 1.mp3 … 60.mp3 للأحزاب،
//           61.mp3 سورة الكهف، 62.mp3 دعاء ختم القرآن.
// ═══════════════════════════════════════════════
class AudioConfig {
  static const String base =
      'https://lushhkoveifkmtyzevpg.supabase.co/storage/v1/object/public/audio';

  /// أرقام التلاوات الخاصة (ليست أحزاباً) في نفس المجلد.
  static const int kahf       = 61; // سورة الكهف
  static const int khatmaDuaa = 62; // دعاء ختم القرآن

  static const int lastTrack = khatmaDuaa;

  static String urlFor(int track) => '$base/$track.mp3';

  static bool hasAudioFor(int track) => track >= 1 && track <= lastTrack;
}
