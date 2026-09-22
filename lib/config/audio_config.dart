// ═══════════════════════════════════════════════
//  إعداد الملفات الصوتية (MP3) — حاوية Supabase العامة «audio»
//  الملفات: 1.mp3 … 60.mp3 للأحزاب،
//           61.mp3 سورة الكهف، 62.mp3 دعاء ختم القرآن.
//  المنجيات: حاوية «mounjyat» — الملفات 1.mp3…5.mp3 تُعامَل كمسارات 101–105.
// ═══════════════════════════════════════════════
class AudioConfig {
  static const String _audioBucket =
      'https://lushhkoveifkmtyzevpg.supabase.co/storage/v1/object/public/audio';
  static const String _mounjyatBucket =
      'https://lushhkoveifkmtyzevpg.supabase.co/storage/v1/object/public/mounjyat';

  /// أرقام التلاوات الخاصة في حاوية audio.
  static const int kahf        = 61; // سورة الكهف
  static const int khatmaDuaa  = 62; // دعاء ختم القرآن
  static const int lastTrack   = khatmaDuaa;

  /// المنجيات: أضف 100 على رقم السورة (1–5) للحصول على رقم المسار (101–105).
  static const int mounjyatOffset = 100;

  static String urlFor(int track) {
    if (track > mounjyatOffset) {
      return '$_mounjyatBucket/${track - mounjyatOffset}.mp3';
    }
    return '$_audioBucket/$track.mp3';
  }

  static bool hasAudioFor(int track) =>
      (track >= 1 && track <= lastTrack) ||
      (track > mounjyatOffset && track <= mounjyatOffset + 5);
}
