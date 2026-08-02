import 'package:flutter/material.dart';
import '../models/account_models.dart';
import '../services/group_service.dart';
import '../theme/app_theme.dart';

// ═══════════════════════════════════════════════
//  توزيع الأحزاب على الأعضاء (للمؤسس): تلقائي + يدوي بالنقر
// ═══════════════════════════════════════════════
class DistributionScreen extends StatefulWidget {
  final GroupInfo group;
  final List<GroupAssignment> members;
  const DistributionScreen({super.key, required this.group, required this.members});
  @override
  State<DistributionScreen> createState() => _DistributionScreenState();
}

class _DistributionScreenState extends State<DistributionScreen> {
  static const _palette = [
    Color(0xFF1A5C38), Color(0xFF1E3A8A), Color(0xFF7C3238), Color(0xFFB8860B),
    Color(0xFF4A148C), Color(0xFF00695C), Color(0xFFBF360C), Color(0xFF37474F),
  ];

  Map<int, String> _map = {}; // hizb → userId
  Map<int, String> _reads = {}; // hizb → userId (المقروءة — مقفلة)
  bool _loading = true;
  String? _target; // العضو المختار حالياً (null = غير موزّعة)
  String _search = ''; // بحث في الأعضاء

  bool get _hasReads => _reads.isNotEmpty;

  List<GroupAssignment> get _filteredMembers {
    final q = _search.trim().toLowerCase();
    if (q.isEmpty) return widget.members;
    return widget.members
        .where((m) => _nameFor(m.userId).toLowerCase().contains(q))
        .toList();
  }

  Color _colorFor(String userId) {
    final i = widget.members.indexWhere((m) => m.userId == userId);
    return _palette[(i < 0 ? 0 : i) % _palette.length];
  }

  String _nameFor(String userId) {
    final m = widget.members.firstWhere((x) => x.userId == userId,
        orElse: () => const GroupAssignment(userId: ''));
    final n = m.displayName?.trim();
    return (n != null && n.isNotEmpty) ? n : 'عضو';
  }

  String? _avatarFor(String userId) {
    final m = widget.members.firstWhere((x) => x.userId == userId,
        orElse: () => const GroupAssignment(userId: ''));
    final a = m.avatarUrl?.trim();
    return (a != null && a.isNotEmpty) ? a : null;
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      _map = await GroupService.assignmentsMap(widget.group.id);
    } catch (_) {}
    try {
      _reads = await GroupService.reads(widget.group.id);
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _auto() async {
    try {
      await GroupService.autoDistribute(widget.group.id);
      await _load();
    } catch (e) {
      _snack('$e');
    }
  }

  Future<void> _assign(int hizb) async {
    if (_reads.containsKey(hizb)) {
      _snack('هذا الحزب تمت قراءته ولا يمكن تغييره');
      return;
    }
    final prev = _map[hizb];
    // ضغطة للإسناد للعضو المختار، وضغطة ثانية على حزبه نفسه للتحرير (toggle)
    final String? newOwner = (_target != null && _map[hizb] == _target) ? null : _target;
    setState(() => newOwner == null ? _map.remove(hizb) : _map[hizb] = newOwner);
    try {
      await GroupService.setAssignment(widget.group.id, hizb, newOwner);
    } catch (e) {
      if (mounted) {
        setState(() => prev == null ? _map.remove(hizb) : _map[hizb] = prev);
        _snack('$e');
      }
    }
  }

  void _snack(String m) {
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('تعذّر: $m')));
  }

  int _countFor(String? userId) =>
      userId == null ? 60 - _map.length : _map.values.where((u) => u == userId).length;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: AppTheme.primary, foregroundColor: Colors.white,
        title: const Text('توزيع الأحزاب', style: TextStyle(fontWeight: FontWeight.w700)),
        centerTitle: true,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.primary))
          : Column(children: [
              Padding(
                padding: const EdgeInsets.all(12),
                child: Column(children: [
                  if (!_hasReads)
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _auto,
                        icon: const Icon(Icons.auto_awesome_rounded, color: Colors.white),
                        label: const Text('توزيع تلقائي بالتساوي', style: TextStyle(color: Colors.white)),
                        style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.primary,
                            padding: const EdgeInsets.symmetric(vertical: 12)),
                      ),
                    ),
                  if (_hasReads)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF3EFEA),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Text(
                        'قُفل التوزيع التلقائي بعد بدء القراءة. يمكنك توزيع الأحزاب غير المسندة يدوياً فقط.',
                        style: TextStyle(fontSize: 12, color: AppTheme.textMed),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  const SizedBox(height: 8),
                  Text(
                    'المجمّع (غير مسندة): ${60 - _map.length} حزباً.  اختر عضواً ثم اضغط حزباً لإسناده. «غير موزّعة» لإرجاعه للمجمّع. الأحزاب المقروءة (✓) مقفلة.',
                    style: const TextStyle(fontSize: 12, color: AppTheme.textMed),
                    textAlign: TextAlign.center,
                  ),
                ]),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
                child: TextField(
                  onChanged: (v) => setState(() => _search = v),
                  decoration: InputDecoration(
                    isDense: true,
                    hintText: 'ابحث عن عضو بالاسم…',
                    prefixIcon: const Icon(Icons.search_rounded, size: 20),
                    contentPadding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
              SizedBox(
                height: 46,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  children: [
                    _targetChip(null, 'غير موزّعة', Colors.grey),
                    ..._filteredMembers.map((m) => _targetChip(m.userId, _nameFor(m.userId), _colorFor(m.userId))),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: GridView.count(
                  crossAxisCount: 6,
                  padding: EdgeInsets.fromLTRB(12, 12, 12, 16 + MediaQuery.of(context).viewPadding.bottom),
                  mainAxisSpacing: 8,
                  crossAxisSpacing: 8,
                  children: List.generate(60, (i) {
                    final h = i + 1;
                    final owner = _map[h];
                    final assigned = owner != null;
                    final isRead = _reads.containsKey(h);
                    final c = assigned ? _colorFor(owner) : const Color(0xFFE0E0E0);
                    final avatar = assigned ? _avatarFor(owner) : null;
                    // تمييز أحزاب العضو المختار حالياً (أو غير المسندة عند اختيار «غير موزّعة»)
                    final belongs = _target == null ? !assigned : owner == _target;
                    return GestureDetector(
                      onTap: () => _assign(h),
                      child: Opacity(
                        opacity: isRead ? .6 : 1,
                        child: Container(
                          clipBehavior: Clip.antiAlias,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: assigned ? c : AppTheme.surface,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                                color: belongs ? AppTheme.gold : (assigned ? c : const Color(0xFFCCCCCC)),
                                width: belongs ? 3 : 1),
                            boxShadow: belongs
                                ? [BoxShadow(color: AppTheme.gold.withOpacity(.5), blurRadius: 6)]
                                : null,
                          ),
                          child: Stack(fit: StackFit.expand, children: [
                            // صورة العضو المُسنَد تملأ المربّع كاملاً
                            if (avatar != null)
                              Image.network(avatar, fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) => const SizedBox()),
                            // تدرّج داكن أسفل لإبراز الرقم فوق الصورة
                            if (avatar != null)
                              const DecoratedBox(
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.center,
                                    end: Alignment.bottomCenter,
                                    colors: [Colors.transparent, Colors.black87],
                                  ),
                                ),
                              ),
                            // رقم الحزب في الأسفل والوسط
                            Align(
                              alignment: Alignment.bottomCenter,
                              child: Padding(
                                padding: const EdgeInsets.only(bottom: 3),
                                child: Text('$h',
                                    style: TextStyle(
                                        fontWeight: FontWeight.w800,
                                        fontSize: 15,
                                        color: assigned ? Colors.white : AppTheme.textMed,
                                        shadows: assigned
                                            ? const [Shadow(color: Colors.black, blurRadius: 3)]
                                            : null)),
                              ),
                            ),
                            if (isRead)
                              const Align(
                                alignment: Alignment.topLeft,
                                child: Padding(
                                  padding: EdgeInsets.all(2),
                                  child: Icon(Icons.check_circle, size: 13, color: Colors.white),
                                ),
                              ),
                          ]),
                        ),
                      ),
                    );
                  }),
                ),
              ),
            ]),
    );
  }

  Widget _targetChip(String? userId, String label, Color color) {
    final sel = _target == userId;
    final count = _countFor(userId);
    return Padding(
      padding: const EdgeInsets.only(left: 8),
      child: ChoiceChip(
        selected: sel,
        onSelected: (_) => setState(() => _target = userId),
        selectedColor: color,
        backgroundColor: color.withOpacity(.12),
        label: Text('$label ($count)',
            style: TextStyle(color: sel ? Colors.white : color, fontWeight: FontWeight.w700, fontSize: 12)),
      ),
    );
  }
}
