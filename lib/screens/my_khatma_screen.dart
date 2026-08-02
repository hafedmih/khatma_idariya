import 'package:flutter/material.dart';
import '../models/hizb.dart';
import '../models/account_models.dart';
import '../services/account_service.dart';
import '../services/hizb_service.dart';
import '../services/khatma_calculator.dart';
import '../services/wird_service.dart';
import '../theme/app_theme.dart';
import 'account_screen.dart';

// ═══════════════════════════════════════════════
//  ختمتي — متابعة ورد الختمة الإدارية اليومي
//  المستخدم يعلّم الأحزاب التي أتمّها (+ سورة الكهف يوم الجمعة)
//  فتُحتسب أيام التتابع.
// ═══════════════════════════════════════════════
class MyKhatmaScreen extends StatefulWidget {
  final bool embedded; // داخل شاشة ختمتي والمجموعات الموحّدة
  const MyKhatmaScreen({super.key, this.embedded = false});
  @override
  State<MyKhatmaScreen> createState() => _MyKhatmaScreenState();
}

class _MyKhatmaScreenState extends State<MyKhatmaScreen> {
  bool _loading = true;
  List<Hizb>? _ahzab;
  List<int> _today = [];
  bool _friday = false;
  Set<String> _done = {};
  int _streak = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (!AccountService.isLoggedIn) {
      setState(() => _loading = false);
      return;
    }
    setState(() => _loading = true);
    final now = DateTime.now();
    _today = KhatmaCalculator.getHizbsForDate(now);
    _friday = now.weekday == DateTime.friday;
    try {
      final results = await Future.wait([
        HizbService.loadAhzab(),
        WirdService.today(),
        AccountService.myProfile(),
      ]);
      _ahzab = results[0] as List<Hizb>;
      _done = results[1] as Set<String>;
      final profile = results[2] as Profile?;
      _streak = profile?.currentStreak ?? 0;
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _toggle(String item) async {
    final was = _done.contains(item);
    setState(() => was ? _done.remove(item) : _done.add(item));
    try {
      if (was) {
        await WirdService.unrecord(item);
      } else {
        await WirdService.record(item);
      }
      final p = await AccountService.myProfile();
      if (mounted) setState(() => _streak = p?.currentStreak ?? _streak);
    } catch (e) {
      if (mounted) {
        setState(() => was ? _done.add(item) : _done.remove(item));
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('تعذّر: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final content = !AccountService.isLoggedIn
        ? _needLogin()
        : _loading
            ? const Center(child: CircularProgressIndicator(color: AppTheme.primary))
            : _tracker();
    if (widget.embedded) return content;
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: AppTheme.primary,
        foregroundColor: Colors.white,
        title: const Text('ختمتي', style: TextStyle(fontWeight: FontWeight.w700)),
        centerTitle: true,
      ),
      body: content,
    );
  }

  Widget _needLogin() => Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Padding(
            padding: EdgeInsets.all(20),
            child: Text('سجّل الدخول لمتابعة وردك واحتساب أيام التتابع',
                textAlign: TextAlign.center, style: TextStyle(fontSize: 16)),
          ),
          ElevatedButton(
            onPressed: () async {
              await Navigator.push(context, MaterialPageRoute(builder: (_) => const AccountScreen()));
              if (mounted) _load();
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primary),
            child: const Text('تسجيل الدخول', style: TextStyle(color: Colors.white)),
          ),
        ]),
      );

  Widget _tracker() {
    final total = _today.length + (_friday ? 1 : 0);
    final doneCount = _today.where((n) => _done.contains(WirdService.hizbItem(n))).length +
        (_friday && _done.contains(WirdService.kahfItem) ? 1 : 0);

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // بطاقة التتابع
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [AppTheme.primaryDk, AppTheme.primaryLt]),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(children: [
              const Icon(Icons.local_fire_department_rounded, color: AppTheme.gold, size: 34),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('$_streak',
                      style: const TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.w800)),
                  const Text('أيام التتابع', style: TextStyle(color: Colors.white70, fontSize: 12)),
                ]),
              ),
              Text('$doneCount / $total اليوم',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
            ]),
          ),
          const SizedBox(height: 16),
          Row(children: const [
            SizedBox(width: 4, height: 20, child: DecoratedBox(decoration: BoxDecoration(color: AppTheme.primary))),
            SizedBox(width: 8),
            Text('ورد اليوم — الختمة الإدارية', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
          ]),
          const SizedBox(height: 10),
          ..._today.map(_hizbCard),
          if (_friday) _kahfCard(),
        ],
      ),
    );
  }

  Widget _hizbCard(int n) {
    final h = _ahzab == null ? null : HizbService.find(_ahzab!, n);
    final item = WirdService.hizbItem(n);
    final done = _done.contains(item);
    return _wirdCard(
      badge: '$n',
      title: 'الحزب $n',
      verse: h?.openingVerse ?? '',
      done: done,
      onTap: () => _toggle(item),
    );
  }

  Widget _kahfCard() {
    final done = _done.contains(WirdService.kahfItem);
    return _wirdCard(
      badge: '🕌',
      title: 'سورة الكهف',
      verse: 'من سنن يوم الجمعة',
      done: done,
      onTap: () => _toggle(WirdService.kahfItem),
      gold: true,
    );
  }

  Widget _wirdCard({
    required String badge,
    required String title,
    required String verse,
    required bool done,
    required VoidCallback onTap,
    bool gold = false,
  }) {
    final accent = gold ? AppTheme.gold : AppTheme.primary;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: done ? accent.withOpacity(.08) : AppTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: done ? accent : const Color(0xFFE8E4DF), width: done ? 1.5 : 1),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            CircleAvatar(
              radius: 20, backgroundColor: accent.withOpacity(.12),
              child: Text(badge, style: TextStyle(color: accent, fontWeight: FontWeight.w800, fontSize: 15)),
            ),
            const SizedBox(width: 12),
            Expanded(child: Text(title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16))),
          ]),
          if (verse.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(verse,
                textAlign: TextAlign.right,
                maxLines: 3, overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 15, height: 1.9, color: AppTheme.textHigh)),
          ],
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: done
                ? OutlinedButton.icon(
                    onPressed: onTap,
                    icon: Icon(Icons.check_circle_rounded, color: accent),
                    label: Text('تمت القراءة ✓', style: TextStyle(color: accent, fontWeight: FontWeight.w700)),
                    style: OutlinedButton.styleFrom(side: BorderSide(color: accent)),
                  )
                : ElevatedButton(
                    onPressed: onTap,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: accent,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: const Text('تمت القراءة', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                  ),
          ),
        ]),
      ),
    );
  }
}
