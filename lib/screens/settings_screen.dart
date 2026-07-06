import 'package:flutter/material.dart';
import '../services/notification_service.dart';
import '../theme/app_theme.dart';

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
  final Map<String, bool> _reminders = {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final master = await NotificationService.masterEnabled();
    final map = <String, bool>{};
    for (final r in NotificationService.reminders) {
      map[r.prefKey] = await NotificationService.reminderEnabled(r.prefKey);
    }
    if (!mounted) return;
    setState(() {
      _master    = master;
      _reminders..clear()..addAll(map);
      _loading   = false;
    });
  }

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
              padding: const EdgeInsets.all(16),
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
                      ? 'ستصلك التذكيرات المفعّلة يومياً في أوقاتها.'
                      : 'التذكيرات معطّلة. فعّلها لتصلك.',
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
    );
  }

  Widget _reminderTile(ReminderSlot r) {
    final enabled = _reminders[r.prefKey] ?? true;
    return SwitchListTile(
      activeColor: AppTheme.primary,
      title: Text(r.label, style: const TextStyle(fontWeight: FontWeight.w600)),
      subtitle: Text(r.body),
      secondary: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: AppTheme.primary.withOpacity(0.08),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(r.timeLabel,
            style: const TextStyle(
                color: AppTheme.primary, fontWeight: FontWeight.w700)),
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
