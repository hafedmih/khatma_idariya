import 'package:flutter/material.dart';
import '../services/notification_service.dart';
import '../services/app_prefs.dart';
import '../services/account_service.dart';
import '../theme/app_theme.dart';
import 'blocked_users_screen.dart';

// ═══════════════════════════════════════════════════════════
//  شاشة الإعدادات — التحكم بتذكيرات الورد
// ═══════════════════════════════════════════════════════════

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _master = true;
  bool _autoRecite = false;
  final Map<String, bool> _reminders = {};
  final Map<String, TimeOfDay> _times = {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final master = await NotificationService.masterEnabled();
    final autoRecite = await AppPrefs.autoRecite();
    final enabled = <String, bool>{};
    final times = <String, TimeOfDay>{};
    for (final r in NotificationService.reminders) {
      enabled[r.prefKey] = await NotificationService.reminderEnabled(r.prefKey);
      final t = await NotificationService.timeOf(r);
      times[r.prefKey] = TimeOfDay(hour: t[0], minute: t[1]);
    }
    if (!mounted) return;
    setState(() {
      _master     = master;
      _autoRecite = autoRecite;
      _reminders..clear()..addAll(enabled);
      _times..clear()..addAll(times);
      _loading   = false;
    });
  }

  Future<void> _pickTime(ReminderSlot r) async {
    final current = _times[r.prefKey] ?? TimeOfDay(hour: r.hour, minute: r.minute);
    final picked = await showTimePicker(
      context: context,
      initialTime: current,
      helpText: 'اختر وقت ${r.label}',
      builder: (ctx, child) =>
          Directionality(textDirection: TextDirection.rtl, child: child!),
    );
    if (picked == null) return;
    setState(() => _times[r.prefKey] = picked);
    await NotificationService.setTime(r, picked.hour, picked.minute);
  }

  String _fmt(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  Future<void> _toggleMaster(bool v) async {
    setState(() => _master = v);
    if (v) await NotificationService.requestPermission();
    await NotificationService.setMaster(v);
  }

  Future<void> _toggleReminder(String key, bool v) async {
    setState(() => _reminders[key] = v);
    if (v) await NotificationService.requestPermission();
    await NotificationService.setReminder(key, v);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: AppTheme.primary,
        foregroundColor: Colors.white,
        title: const Text('الإعدادات', style: TextStyle(fontWeight: FontWeight.w700)),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.primary))
          : ListView(
              padding: EdgeInsets.fromLTRB(
                  16, 16, 16, 24 + MediaQuery.of(context).viewPadding.bottom),
              children: [
                _sectionTitle('تذكيرات الورد'),
                const SizedBox(height: 8),
                _card(
                  child: SwitchListTile(
                    activeColor: AppTheme.primary,
                    title: const Text('تفعيل جميع التذكيرات',
                        style: TextStyle(fontWeight: FontWeight.w700)),
                    subtitle: const Text('تذكير يومي بقراءة ورد القرآن'),
                    secondary: const Icon(Icons.notifications_active_rounded,
                        color: AppTheme.primary),
                    value: _master,
                    onChanged: _toggleMaster,
                  ),
                ),
                const SizedBox(height: 12),
                _card(
                  child: Column(
                    children: [
                      for (int i = 0; i < NotificationService.reminders.length; i++) ...[
                        if (i > 0) const Divider(height: 1),
                        _reminderTile(NotificationService.reminders[i]),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  _master
                      ? 'اضغط على الوقت لتغييره. ستصلك التذكيرات المفعّلة يومياً في أوقاتها.'
                      : 'التذكيرات معطّلة. فعّلها لتصلك.',
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 22),
                _sectionTitle('التلاوة'),
                const SizedBox(height: 8),
                _card(
                  child: SwitchListTile(
                    activeColor: AppTheme.primary,
                    title: const Text('بدء التلاوة تلقائياً مع الحزب',
                        style: TextStyle(fontWeight: FontWeight.w700)),
                    subtitle: const Text('عند تعطيله لا يبدأ الصوت تلقائياً؛ اضغط زر التشغيل في كل صفحة'),
                    secondary: const Icon(Icons.play_circle_outline_rounded, color: AppTheme.primary),
                    value: _autoRecite,
                    onChanged: (v) async {
                      setState(() => _autoRecite = v);
                      await AppPrefs.setAutoRecite(v);
                    },
                  ),
                ),
                if (AccountService.isLoggedIn) ...[
                  const SizedBox(height: 22),
                  _sectionTitle('الخصوصية والأمان'),
                  const SizedBox(height: 8),
                  _card(
                    child: ListTile(
                      leading: const Icon(Icons.block_rounded, color: AppTheme.primary),
                      title: const Text('المستخدمون المحظورون',
                          style: TextStyle(fontWeight: FontWeight.w700)),
                      subtitle: const Text('عرض من حظرتهم ورفع الحظر'),
                      trailing: const Icon(Icons.chevron_left_rounded, color: AppTheme.textLow),
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const BlockedUsersScreen()),
                      ),
                    ),
                  ),
                ],
              ],
            ),
    );
  }

  Widget _reminderTile(ReminderSlot r) {
    final enabled = _reminders[r.prefKey] ?? true;
    final time = _times[r.prefKey] ?? TimeOfDay(hour: r.hour, minute: r.minute);
    return SwitchListTile(
      activeColor: AppTheme.primary,
      title: Text(r.label, style: const TextStyle(fontWeight: FontWeight.w600)),
      subtitle: Text(r.body),
      // زر تغيير الوقت (اضغط لاختيار وقت مخصّص)
      secondary: InkWell(
        onTap: () => _pickTime(r),
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: AppTheme.primary.withOpacity(0.08),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.edit_rounded, size: 13, color: AppTheme.primary),
              const SizedBox(width: 4),
              Text(_fmt(time),
                  style: const TextStyle(
                      color: AppTheme.primary, fontWeight: FontWeight.w700)),
            ],
          ),
        ),
      ),
      value: _master && enabled,
      onChanged: _master ? (v) => _toggleReminder(r.prefKey, v) : null,
    );
  }

  Widget _sectionTitle(String t) => Text(
        t,
        style: const TextStyle(
            fontSize: 15, fontWeight: FontWeight.w700, color: AppTheme.primary),
      );

  Widget _card({required Widget child}) => Container(
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFE8E4DF)),
        ),
        child: child,
      );
}
