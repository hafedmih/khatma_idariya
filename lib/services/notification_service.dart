import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

// ═══════════════════════════════════════════════════════════
//  NotificationService — تذكيرات يومية بقراءة الورد
//  ٠٥:٠٠ صباحاً — ١٨:٠٠ مساءً — ٢٠:٠٠ ليلاً
//  يمكن للمستخدم تعطيل كل تذكير على حدة أو تعطيلها جميعاً.
// ═══════════════════════════════════════════════════════════

/// تذكير واحد بوقت ثابت يومياً
class ReminderSlot {
  final int    id;
  final int    hour;
  final int    minute;
  final String prefKey;
  final String label;
  final String body;

  const ReminderSlot({
    required this.id,
    required this.hour,
    required this.minute,
    required this.prefKey,
    required this.label,
    required this.body,
  });

  String get timeLabel =>
      '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';
}

class NotificationService {
  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  static const String _masterKey = 'notif_all_enabled';

  static const String _channelId   = 'khatma_reminders';
  static const String _channelName = 'تذكير الورد';
  static const String _appName     = 'القرآن الكريم - ختمة الإدارة';

  /// التذكيرات الثلاثة
  static const List<ReminderSlot> reminders = [
    ReminderSlot(
      id: 1, hour: 5, minute: 0, prefKey: 'notif_0500',
      label: 'تذكير الصباح',
      body:  'ابدأ يومك بورد من كتاب الله 🌅',
    ),
    ReminderSlot(
      id: 2, hour: 18, minute: 0, prefKey: 'notif_1800',
      label: 'تذكير المساء',
      body:  'لا تنسَ وردك من القرآن الكريم 🌇',
    ),
    ReminderSlot(
      id: 3, hour: 20, minute: 0, prefKey: 'notif_2000',
      label: 'تذكير الليل',
      body:  'أكمل وردك اليومي قبل نهاية اليوم 🌙',
    ),
  ];

  static bool _initialized = false;

  // ── التهيئة ────────────────────────────────────────────
  static Future<void> init() async {
    if (_initialized) return;

    // المنطقة الزمنية (مطلوبة لجدولة zonedSchedule)
    tzdata.initializeTimeZones();
    try {
      final name = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(name));
    } catch (_) {
      tz.setLocalLocation(tz.getLocation('Africa/Nouakchott'));
    }

    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const darwin  = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );
    await _plugin.initialize(
      const InitializationSettings(android: android, iOS: darwin),
    );

    _initialized = true;
  }

  // ── طلب الإذن ──────────────────────────────────────────
  static Future<void> requestPermission() async {
    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    await android?.requestNotificationsPermission();
    await android?.requestExactAlarmsPermission();

    final ios = _plugin.resolvePlatformSpecificImplementation<
        IOSFlutterLocalNotificationsPlugin>();
    await ios?.requestPermissions(alert: true, badge: true, sound: true);
  }

  // ── الإعدادات (SharedPreferences) ──────────────────────
  static Future<bool> masterEnabled() async {
    final p = await SharedPreferences.getInstance();
    return p.getBool(_masterKey) ?? true;
  }

  static Future<bool> reminderEnabled(String key) async {
    final p = await SharedPreferences.getInstance();
    return p.getBool(key) ?? true;
  }

  static Future<void> setMaster(bool value) async {
    final p = await SharedPreferences.getInstance();
    await p.setBool(_masterKey, value);
    await reschedule();
  }

  static Future<void> setReminder(String key, bool value) async {
    final p = await SharedPreferences.getInstance();
    await p.setBool(key, value);
    await reschedule();
  }

  /// وقت التذكير الحالي (مخصّص إن وُجد، وإلا الوقت الافتراضي) — [ساعة, دقيقة]
  static Future<List<int>> timeOf(ReminderSlot r) async {
    final p = await SharedPreferences.getInstance();
    return [
      p.getInt('${r.prefKey}_h') ?? r.hour,
      p.getInt('${r.prefKey}_m') ?? r.minute,
    ];
  }

  /// تعيين وقت مخصّص لتذكير ثم إعادة الجدولة
  static Future<void> setTime(ReminderSlot r, int hour, int minute) async {
    final p = await SharedPreferences.getInstance();
    await p.setInt('${r.prefKey}_h', hour);
    await p.setInt('${r.prefKey}_m', minute);
    await reschedule();
  }

  // ── إعادة الجدولة حسب الإعدادات الحالية ────────────────
  static Future<void> reschedule() async {
    if (!_initialized) await init();
    await _plugin.cancelAll();

    final master = await masterEnabled();
    if (!master) return;

    final p = await SharedPreferences.getInstance();
    for (final r in reminders) {
      final on = p.getBool(r.prefKey) ?? true;
      if (!on) continue;
      final h = p.getInt('${r.prefKey}_h') ?? r.hour;
      final m = p.getInt('${r.prefKey}_m') ?? r.minute;
      await _schedule(r, h, m);
    }
  }

  static Future<void> _schedule(ReminderSlot r, int hour, int minute) async {
    const details = NotificationDetails(
      android: AndroidNotificationDetails(
        _channelId,
        _channelName,
        channelDescription: 'تذكيرات يومية بقراءة ورد القرآن',
        importance: Importance.high,
        priority:   Priority.high,
      ),
      iOS: DarwinNotificationDetails(),
    );

    await _plugin.zonedSchedule(
      r.id,
      _appName,
      r.body,
      _nextInstanceOf(hour, minute),
      details,
      // تنبيه دقيق حتى في وضع توفير الطاقة (Doze) — ضروري لموثوقية التذكير
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.time, // يتكرر يومياً
    );
  }

  static tz.TZDateTime _nextInstanceOf(int hour, int minute) {
    final now = tz.TZDateTime.now(tz.local);
    var scheduled =
        tz.TZDateTime(tz.local, now.year, now.month, now.day, hour, minute);
    if (!scheduled.isAfter(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }
    return scheduled;
  }
}
