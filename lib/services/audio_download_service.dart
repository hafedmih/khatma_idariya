import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../config/audio_config.dart';

// ═══════════════════════════════════════════════
//  تنزيل تلاوات الأحزاب (MP3) وإدارتها للاستماع دون إنترنت
// ═══════════════════════════════════════════════
class AudioDownloadService {
  static Directory? _dir;

  static Future<Directory> _audioDir() async {
    if (_dir != null) return _dir!;
    final docs = await getApplicationDocumentsDirectory();
    final d = Directory('${docs.path}/audio');
    if (!await d.exists()) await d.create(recursive: true);
    _dir = d;
    return d;
  }

  static Future<File> localFile(int hizb) async =>
      File('${(await _audioDir()).path}/$hizb.mp3');

  static Future<bool> isDownloaded(int hizb) async {
    final f = await localFile(hizb);
    return await f.exists() && (await f.length()) > 1000;
  }

  // هل الملف موجود على الخادم؟ (للأحزاب التي لم تُرفع بعد)
  static Future<bool> remoteExists(int hizb) async {
    try {
      final r = await http.head(Uri.parse(AudioConfig.urlFor(hizb)));
      return r.statusCode >= 200 && r.statusCode < 300;
    } catch (_) {
      return false;
    }
  }

  // مجموعة الأحزاب التي رُفعت تلاوتها على الخادم (تُحسب مرّة وتُخزَّن للجلسة)
  static Set<int>? _remoteCache;
  static Future<Set<int>> remoteAudioSet() async {
    if (_remoteCache != null) return _remoteCache!;
    final set = <int>{};
    // 1) محاولة سرد ملفات bucket «audio» بنداء واحد
    try {
      final files = await Supabase.instance.client.storage
          .from('audio')
          .list()
          .timeout(const Duration(seconds: 8));
      for (final f in files) {
        final m = RegExp(r'^(\d+)\.mp3$').firstMatch(f.name);
        if (m != null) set.add(int.parse(m.group(1)!));
      }
    } catch (_) {}
    // 2) إن تعذّر السرد (صلاحيات) نتحقّق عبر HEAD بالتوازي
    if (set.isEmpty) {
      final futures = <Future<void>>[];
      for (var h = 1; h <= AudioConfig.lastTrack; h++) {
        futures.add(remoteExists(h).then((ok) { if (ok) set.add(h); }));
      }
      await Future.wait(futures);
    }
    _remoteCache = set;
    return set;
  }

  static void invalidateRemoteCache() => _remoteCache = null;

  // تنزيل حزب مع مؤشّر تقدّم — يُرجع true عند النجاح
  static Future<bool> download(int hizb, {void Function(double)? onProgress}) async {
    try {
      final req = http.Request('GET', Uri.parse(AudioConfig.urlFor(hizb)));
      final resp = await http.Client().send(req);
      if (resp.statusCode < 200 || resp.statusCode >= 300) return false;
      final total = resp.contentLength ?? 0;
      final f = await localFile(hizb);
      final tmp = File('${f.path}.part');
      final sink = tmp.openWrite();
      var received = 0;
      await for (final chunk in resp.stream) {
        sink.add(chunk);
        received += chunk.length;
        if (total > 0) onProgress?.call(received / total);
      }
      await sink.close();
      if (await f.exists()) await f.delete();
      await tmp.rename(f.path);
      return true;
    } catch (_) {
      return false;
    }
  }

  static Future<void> delete(int hizb) async {
    final f = await localFile(hizb);
    if (await f.exists()) await f.delete();
    await clearPageTimes(hizb);
  }

  // ── أوقات صفحات الحزب المخزّنة محلياً (للانتقال بين الصفحات دون إنترنت) ──
  static String _ptKey(int hizb) => 'page_times_$hizb';

  static Future<void> savePageTimes(int hizb, List<int> times) async {
    if (times.isEmpty) return;
    final p = await SharedPreferences.getInstance();
    await p.setString(_ptKey(hizb), times.join(','));
  }

  static Future<List<int>> cachedPageTimes(int hizb) async {
    final p = await SharedPreferences.getInstance();
    final s = p.getString(_ptKey(hizb));
    if (s == null || s.isEmpty) return const [];
    return s.split(',').map(int.parse).toList();
  }

  static Future<void> clearPageTimes(int hizb) async {
    final p = await SharedPreferences.getInstance();
    await p.remove(_ptKey(hizb));
  }

  // مجموعة الأحزاب التي لها أوقات صفحات محفوظة محلياً (تعمل دون إنترنت)
  static Future<Set<int>> cachedPageTimesSet() async {
    final p = await SharedPreferences.getInstance();
    final set = <int>{};
    for (final k in p.getKeys()) {
      final m = RegExp(r'^page_times_(\d+)$').firstMatch(k);
      if (m != null && (p.getString(k)?.isNotEmpty ?? false)) {
        set.add(int.parse(m.group(1)!));
      }
    }
    return set;
  }

  // مجموعة الأحزاب المنزّلة
  static Future<Set<int>> downloadedSet() async {
    final d = await _audioDir();
    final set = <int>{};
    for (final e in d.listSync()) {
      final name = e.path.split(Platform.pathSeparator).last;
      final m = RegExp(r'^(\d+)\.mp3$').firstMatch(name);
      if (m != null) set.add(int.parse(m.group(1)!));
    }
    return set;
  }

  // إجمالي المساحة المستخدمة (بايت)
  static Future<int> totalBytes() async {
    final d = await _audioDir();
    var sum = 0;
    for (final e in d.listSync()) {
      if (e is File) sum += await e.length();
    }
    return sum;
  }

  static Future<void> deleteAll() async {
    final d = await _audioDir();
    for (final e in d.listSync()) {
      if (e is File) await e.delete();
    }
  }
}
