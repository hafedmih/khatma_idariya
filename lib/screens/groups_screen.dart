import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:share_plus/share_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/account_models.dart';
import '../models/hizb.dart';
import '../services/account_service.dart';
import '../services/group_service.dart';
import '../services/hizb_service.dart';
import '../theme/app_theme.dart';
import 'distribution_screen.dart';
import 'pdf_viewer_screen.dart';

class GroupsScreen extends StatefulWidget {
  final bool embedded; // داخل شاشة ختمتي والمجموعات الموحّدة
  const GroupsScreen({super.key, this.embedded = false});
  @override
  State<GroupsScreen> createState() => _GroupsScreenState();
}

class _GroupsScreenState extends State<GroupsScreen> {
  late Future<List<GroupInfo>> _future;
  List<GroupInfo> _groups = [];

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    final f = GroupService.myGroups();
    setState(() { _future = f; });
    f.then((g) { if (mounted) setState(() { _groups = g; }); }).catchError((_) {});
  }

  // هل يملك المستخدم مجموعة غير مكتملة (أقل من 10 أعضاء)؟
  bool get _hasIncompleteOwnGroup {
    final uid = AccountService.user?.id;
    return _groups.any((g) => g.ownerId == uid && g.memberCount < 10);
  }

  Future<void> _createDialog() async {
    final name = TextEditingController();
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('إنشاء مجموعة ختمة'),
        content: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            TextField(controller: name, decoration: const InputDecoration(labelText: 'اسم المجموعة')),
            const SizedBox(height: 10),
            const Text('تعتمد المجموعة على دورات؛ تُحدَّد كل دورة عند بدئها.',
                style: TextStyle(fontSize: 12, color: AppTheme.textMed)),
          ]),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
          ElevatedButton(
            onPressed: () async {
              if (name.text.trim().isEmpty) return;
              Navigator.pop(ctx);
              try {
                await GroupService.createGroup(name: name.text.trim(), mode: 'custom');
                _reload();
              } catch (e) {
                _snack('تعذّر: $e');
              }
            },
            child: const Text('إنشاء'),
          ),
        ],
      ),
    );
  }

  Future<void> _joinDialog() async {
    final code = TextEditingController();
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('الانضمام بمجموعة'),
        content: TextField(controller: code,
            textCapitalization: TextCapitalization.characters,
            decoration: const InputDecoration(labelText: 'رمز الدعوة')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                await GroupService.joinGroup(code.text.trim());
                _reload();
              } catch (e) {
                _snack('رمز غير صحيح');
              }
            },
            child: const Text('انضمام'),
          ),
        ],
      ),
    );
  }

  void _snack(String m) {
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));
  }

  Future<void> _scanToJoin() async {
    final raw = await Navigator.push<String>(
        context, MaterialPageRoute(builder: (_) => const QrScanScreen()));
    if (raw == null || raw.isEmpty) return;
    try {
      await GroupService.joinGroup(GroupService.extractCode(raw));
      _reload();
      _snack('تم الانضمام إلى المجموعة');
    } catch (e) {
      _snack('رمز غير صحيح');
    }
  }

  @override
  Widget build(BuildContext context) {
    final content = _content();
    if (widget.embedded) return content;
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: AppTheme.primary, foregroundColor: Colors.white,
        title: const Text('مجموعات الختمة', style: TextStyle(fontWeight: FontWeight.w700)),
        centerTitle: true,
      ),
      body: content,
    );
  }

  Widget _content() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: Column(children: [
            Row(children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _hasIncompleteOwnGroup ? null : _createDialog,
                  icon: const Icon(Icons.add, color: Colors.white),
                  label: const Text('مجموعة جديدة', style: TextStyle(color: Colors.white)),
                  style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primary, disabledBackgroundColor: const Color(0xFFBFC7C0)),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _scanToJoin,
                  icon: const Icon(Icons.qr_code_scanner_rounded, color: AppTheme.primary),
                  label: const Text('مسح للانضمام', style: TextStyle(color: AppTheme.primary)),
                ),
              ),
            ]),
            if (_hasIncompleteOwnGroup)
              const Align(
                alignment: AlignmentDirectional.centerStart,
                child: Padding(
                  padding: EdgeInsets.only(top: 6),
                  child: Text('أكمل مجموعتك الحالية (10 أعضاء) قبل إنشاء مجموعة جديدة.',
                      style: TextStyle(fontSize: 12, color: Color(0xFFB8860B), fontWeight: FontWeight.w600)),
                ),
              )
            else
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: TextButton(
                  onPressed: _joinDialog,
                  child: const Text('أو أدخل رمز الدعوة يدوياً', style: TextStyle(fontSize: 12)),
                ),
              ),
          ]),
        ),
        Expanded(
          child: FutureBuilder<List<GroupInfo>>(
            future: _future,
            builder: (context, snap) {
              if (!snap.hasData) return const Center(child: CircularProgressIndicator(color: AppTheme.primary));
              final groups = snap.data!;
              if (groups.isEmpty) {
                return const Center(child: Padding(padding: EdgeInsets.all(24),
                  child: Text('لا مجموعات بعد.\nأنشئ مجموعة أو انضم برمز دعوة.',
                    textAlign: TextAlign.center, style: TextStyle(color: AppTheme.textMed))));
              }
              return ListView(
                padding: const EdgeInsets.all(16),
                children: groups.map((g) => _groupTile(g)).toList(),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _groupTile(GroupInfo g) {
    // مجموعة لم تستوفِ النصاب (أقل من 10) = مشروع
    if (g.memberCount < 10) {
      return _ProjectGroupTile(key: ValueKey(g.id), group: g, onChanged: _reload);
    }
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(14),
        child: ListTile(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: const BorderSide(color: Color(0xFFE8E4DF)),
          ),
          leading: const CircleAvatar(backgroundColor: AppTheme.primary,
              child: Icon(Icons.groups_rounded, color: Colors.white)),
          title: Text(g.name, style: const TextStyle(fontWeight: FontWeight.w700)),
          subtitle: Text('${g.memberCount} ${g.memberCount == 1 ? 'عضو' : 'أعضاء'}'),
          trailing: const Icon(Icons.chevron_left_rounded),
          onTap: () async {
            await Navigator.push(context,
                MaterialPageRoute(builder: (_) => GroupDetailScreen(group: g)));
            _reload();
          },
        ),
      ),
    );
  }
}

// نافذة تفاصيل عضو (اسم + مستوى + تتابع) بلا أي إجراءات
void showMemberInfoSheet(BuildContext context, GroupAssignment a, {String? founderId}) {
  final name = (a.displayName != null && a.displayName!.trim().isNotEmpty) ? a.displayName!.trim() : 'عضو';
  final isFounder = founderId != null && a.userId == founderId;
  showModalBottomSheet<void>(
    context: context,
    backgroundColor: AppTheme.surface,
    useSafeArea: true,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
    builder: (ctx) => Padding(
      padding: EdgeInsets.fromLTRB(20, 20, 20, 28 + MediaQuery.of(ctx).viewPadding.bottom),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        CircleAvatar(
          radius: 30, backgroundColor: AppTheme.primary.withOpacity(.12),
          backgroundImage: a.avatarUrl != null ? NetworkImage(a.avatarUrl!) : null,
          child: a.avatarUrl == null ? const Icon(Icons.person, size: 32, color: AppTheme.primary) : null,
        ),
        const SizedBox(height: 10),
        Text(name, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
        if (isFounder)
          const Padding(
            padding: EdgeInsets.only(top: 4),
            child: Text('مؤسس المجموعة', style: TextStyle(color: AppTheme.gold, fontWeight: FontWeight.w700)),
          ),
        const SizedBox(height: 18),
        Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
          Column(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.workspace_premium_rounded, color: AppTheme.primary),
            const SizedBox(height: 4),
            Text('${a.level}', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
            const Text('المستوى', style: TextStyle(fontSize: 11, color: AppTheme.textMed)),
          ]),
          Column(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.local_fire_department_rounded, color: AppTheme.primary),
            const SizedBox(height: 4),
            Text('${a.streak}', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
            const Text('أيام التتابع', style: TextStyle(fontSize: 11, color: AppTheme.textMed)),
          ]),
        ]),
      ]),
    ),
  );
}

// ═══════════════════════════════════════════════
//  بطاقة مجموعة «مشروع» (لم تكتمل 10 أعضاء) في القائمة
// ═══════════════════════════════════════════════
class _ProjectGroupTile extends StatefulWidget {
  final GroupInfo group;
  final VoidCallback onChanged;
  const _ProjectGroupTile({super.key, required this.group, required this.onChanged});
  @override
  State<_ProjectGroupTile> createState() => _ProjectGroupTileState();
}

class _ProjectGroupTileState extends State<_ProjectGroupTile> {
  List<GroupAssignment> _members = [];

  @override
  void initState() {
    super.initState();
    _loadMembers();
  }

  Future<void> _loadMembers() async {
    try {
      final m = await GroupService.todayAssignments(widget.group.id);
      if (mounted) setState(() => _members = m);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final n = widget.group.memberCount;
    final pct = (n / 10 * 100).clamp(0, 100).round();
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF6E9),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.gold),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          CircleAvatar(backgroundColor: AppTheme.gold.withOpacity(.9),
              child: const Icon(Icons.hourglass_top_rounded, color: Colors.white)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Flexible(child: Text(widget.group.name,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15))),
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(color: AppTheme.gold, borderRadius: BorderRadius.circular(20)),
                  child: const Text('مشروع', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700)),
                ),
              ]),
              const SizedBox(height: 2),
              Text('$n / 10 أعضاء — لم يكتمل النصاب',
                  style: const TextStyle(fontSize: 12, color: AppTheme.textMed)),
            ]),
          ),
        ]),
        const SizedBox(height: 10),
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: LinearProgressIndicator(
            value: (n / 10).clamp(0.0, 1.0),
            minHeight: 10,
            backgroundColor: Colors.white,
            color: AppTheme.gold,
          ),
        ),
        const SizedBox(height: 4),
        Text('$pct%', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF8A6D00))),
        if (_members.isNotEmpty) ...[
          const SizedBox(height: 10),
          Wrap(
            spacing: 6, runSpacing: 6,
            children: _members.map((a) {
              final isFounder = widget.group.ownerId != null && a.userId == widget.group.ownerId;
              return GestureDetector(
                onTap: () => showMemberInfoSheet(context, a, founderId: widget.group.ownerId),
                child: CircleAvatar(
                  radius: 16,
                  backgroundColor: (isFounder ? AppTheme.gold : AppTheme.primary).withOpacity(.15),
                  backgroundImage: a.avatarUrl != null ? NetworkImage(a.avatarUrl!) : null,
                  child: a.avatarUrl == null
                      ? Icon(Icons.person, size: 18, color: isFounder ? AppTheme.gold : AppTheme.primary) : null,
                ),
              );
            }).toList(),
          ),
        ],
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: (widget.group.ownerId == AccountService.user?.id)
              ? ElevatedButton.icon(
                  onPressed: () async {
                    await Navigator.push(context,
                        MaterialPageRoute(builder: (_) => ProjectGroupScreen(group: widget.group)));
                    widget.onChanged();
                  },
                  icon: const Icon(Icons.qr_code_2_rounded, color: Colors.white, size: 18),
                  label: const Text('رمز الانضمام والتفاصيل',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                  style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primary),
                )
              : ElevatedButton(
                  onPressed: () async {
                    await Navigator.push(context,
                        MaterialPageRoute(builder: (_) => ProjectGroupScreen(group: widget.group)));
                    widget.onChanged();
                  },
                  style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primary),
                  child: const Text('عرض التفاصيل',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                ),
        ),
      ]),
    );
  }
}

// ═══════════════════════════════════════════════
//  تفاصيل المجموعة: نصيب كل عضو اليوم + التقدّم
// ═══════════════════════════════════════════════
class GroupDetailScreen extends StatefulWidget {
  final GroupInfo group;
  const GroupDetailScreen({super.key, required this.group});
  @override
  State<GroupDetailScreen> createState() => _GroupDetailScreenState();
}

class _GroupDetailScreenState extends State<GroupDetailScreen> {
  bool _loading = true;
  List<GroupAssignment> _assignments = [];
  Set<String> _blocked = {}; // مستخدمون حظرهم المستخدم الحالي — يُخفَون
  GroupProgress? _progress;
  Map<int, String> _reads = {};
  Map<int, String> _map = {}; // hizb → userId (التوزيع الدائم)
  List<Hizb>? _ahzab;
  GroupCycle? _cycle;

  RealtimeChannel? _channel;

  String get _uid => AccountService.user!.id;
  bool get _isOwner => widget.group.ownerId != null && widget.group.ownerId == AccountService.user?.id;

  @override
  void initState() {
    super.initState();
    _load();
    _subscribeRealtime();
  }

  @override
  void dispose() {
    if (_channel != null) Supabase.instance.client.removeChannel(_channel!);
    super.dispose();
  }

  // تحديث فوري عند قراءة أي عضو حزباً (بدون خروج/دخول أو سحب لتحديث)
  void _subscribeRealtime() {
    try {
      final sb = Supabase.instance.client;
      _channel = sb
          .channel('group_reads_${widget.group.id}')
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'group_reads',
            filter: PostgresChangeFilter(
                type: PostgresChangeFilterType.eq,
                column: 'group_id',
                value: widget.group.id),
            callback: (_) { if (mounted) _load(quiet: true); },
          )
          .subscribe();
    } catch (_) {}
  }

  Future<void> _load({bool quiet = false}) async {
    if (!quiet) setState(() => _loading = true);
    // كل نداء محميّ على حدة حتى لا يُعلّق التحميل إن فشل أحدها (مثلاً SQL غير مطبّق)
    _ahzab = await HizbService.loadAhzab().catchError((_) => <Hizb>[]);
    _assignments = await GroupService.todayAssignments(widget.group.id)
        .catchError((_) => <GroupAssignment>[]);
    _progress = await GroupService.progress(widget.group.id).catchError((_) => null);
    _reads = await GroupService.reads(widget.group.id).catchError((_) => <int, String>{});
    _map = await GroupService.assignmentsMap(widget.group.id).catchError((_) => <int, String>{});
    _cycle = await GroupService.activeCycle(widget.group.id).catchError((_) => null);
    _blocked = await GroupService.blockedIds().catchError((_) => <String>{});
    if (mounted) setState(() => _loading = false);
  }

  // أحزاب المستخدم الحالي المُسندة إليه (مرتّبة)
  List<int> get _myHizbs =>
      (_map.entries.where((e) => e.value == _uid).map((e) => e.key).toList()..sort());

  // الأحزاب غير المُسندة لأي عضو (المجمّع)
  List<int> get _unassignedHizbs =>
      [for (var h = 1; h <= 60; h++) if (!_map.containsKey(h)) h];

  // الحد الأقصى للأحزاب لكل عضو (من الدورة أو 6)
  int get _cap => _cycle?.maxPerMember ?? 6;
  bool get _canSelfAssign => _myHizbs.length < _cap && _unassignedHizbs.isNotEmpty;

  // إسناد حزب غير مُسند للمستخدم نفسه (بحد أقصى)
  Future<void> _selfAssign(int h) async {
    if (_myHizbs.length >= _cap) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('بلغت الحد الأقصى ($_cap أحزاب)')));
      return;
    }
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('إسناد لنفسك'),
        content: Text('إسناد الحزب $h إليك؟'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primary),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('إسناد', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await GroupService.selfAssign(widget.group.id, h);
      await _load();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('تعذّر: $e')));
    }
  }

  // الأحزاب المُسندة التي لم تُقرأ بعد
  List<int> get _unreadAssignedHizbs =>
      (_map.keys.where((h) => !_reads.containsKey(h)).toList()..sort());

  // أعضاء متأخرون: لديهم أحزاب مُسندة ولم يُكملوا قراءتها بعد
  List<GroupAssignment> get _lateMembers => _orderedMembers.where((a) {
        final mine = _map.entries.where((e) => e.value == a.userId).map((e) => e.key);
        return mine.isNotEmpty && mine.any((h) => !_reads.containsKey(h));
      }).toList();

  // ترتيب الأعضاء: المؤسس أولاً، ثم العضو المتصل، ثم الباقي حسب أصغر حزب مُسند
  int _minHizbOf(String userId) {
    var m = 9999;
    for (final e in _map.entries) {
      if (e.value == userId && e.key < m) m = e.key;
    }
    return m;
  }

  List<GroupAssignment> get _orderedMembers {
    final ownerId = widget.group.ownerId;
    final me = AccountService.user?.id;
    // إخفاء الأعضاء المحظورين من طرف المستخدم الحالي
    final list = _assignments.where((a) => !_blocked.contains(a.userId)).toList();
    list.sort((a, b) {
      final aOwner = a.userId == ownerId, bOwner = b.userId == ownerId;
      if (aOwner != bOwner) return aOwner ? -1 : 1;
      final aMe = a.userId == me, bMe = b.userId == me;
      if (aMe != bMe) return aMe ? -1 : 1;
      return _minHizbOf(a.userId).compareTo(_minHizbOf(b.userId));
    });
    return list;
  }

  // ترتيب رتب الاحتياطي بالأحرف
  static const List<String> _ordinals = ['', 'الأول', 'الثاني', 'الثالث'];
  String _ord(int? r) => (r != null && r >= 1 && r <= 3) ? _ordinals[r] : '';

  // نصاب بدء الدورة: 10 أعضاء على الأقل
  static const int _quorum = 10;
  int get _memberCount => _progress?.members ?? _assignments.length;
  bool get _hasQuorum => _memberCount >= _quorum;

  Future<void> _markMine(int hizb) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('تأكيد القراءة'),
        content: Text('هل أتممت قراءة الحزب $hizb؟'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primary),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('نعم، تمت', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await GroupService.recordRead(widget.group.id, hizb);
      await _load();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('تعذّر: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final pct = (_progress?.percent ?? 0) / 100.0;
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: AppTheme.primary, foregroundColor: Colors.white,
        title: Text(widget.group.name, style: const TextStyle(fontWeight: FontWeight.w700)),
        centerTitle: true,
        actions: [
          if (_isOwner)
            IconButton(
              icon: const Icon(Icons.qr_code_2_rounded),
              tooltip: 'رمز الانضمام',
              onPressed: () => Navigator.push(context,
                  MaterialPageRoute(builder: (_) => GroupJoinCodeScreen(group: widget.group))),
            ),
          if (!_isOwner)
            IconButton(
              icon: const Icon(Icons.exit_to_app_rounded),
              tooltip: 'الخروج من المجموعة',
              onPressed: _leaveGroup,
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.primary))
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: EdgeInsets.fromLTRB(16, 16, 16, 24 + MediaQuery.of(context).viewPadding.bottom),
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(colors: [AppTheme.primaryDk, AppTheme.primaryLt]),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('تقدّم المجموعة • ${_progress?.members ?? 0} أعضاء',
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
                      const SizedBox(height: 10),
                      ClipRRect(borderRadius: BorderRadius.circular(8),
                        child: LinearProgressIndicator(value: pct, minHeight: 12,
                            backgroundColor: Colors.white24, color: AppTheme.gold)),
                      const SizedBox(height: 6),
                      Text('${_progress?.hizbsRead ?? 0} / 60 حزباً  (${(_progress?.percent ?? 0).toStringAsFixed(0)}%)',
                          style: const TextStyle(color: Colors.white70, fontSize: 12)),
                    ]),
                  ),
                  const SizedBox(height: 12),
                  if (_cycle == null)
                    _noCycleCard()
                  else ...[
                  _cycleCard(),
                  // أحزاب لم تُقرأ بعد — تظهر فقط عند اعتبار الدورة قاربت النهاية
                  if ((_cycle?.nearEnd ?? false) && _unreadAssignedHizbs.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    _unreadHizbsCard(),
                  ],
                  if (_isOwner) ...[
                    // أحزاب غير مسندة (المجمّع) — إن وُجدت
                    if (_unassignedHizbs.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      _unassignedCard(),
                    ],
                    // زر التوزيع اليدوي عند عدم وجود أحزاب غير مسندة
                    if (_unassignedHizbs.isEmpty) ...[
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: () async {
                            await Navigator.push(context, MaterialPageRoute(
                                builder: (_) => DistributionScreen(group: widget.group, members: _assignments)));
                            _load();
                          },
                          icon: const Icon(Icons.dashboard_customize_rounded, size: 18, color: AppTheme.primary),
                          label: const Text('توزيع الأحزاب على الأعضاء', style: TextStyle(color: AppTheme.primary)),
                          style: OutlinedButton.styleFrom(
                              side: const BorderSide(color: AppTheme.primary),
                              padding: const EdgeInsets.symmetric(vertical: 12)),
                        ),
                      ),
                    ],
                  ],
                  // أعضاء متأخرون — للجميع، فقط بعد اعتبار الدورة قاربت النهاية ووجود تأخّر
                  if ((_cycle?.nearEnd ?? false) && _lateMembers.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    _lateMembersCard(),
                  ],
                  ],
                  const SizedBox(height: 18),
                  // نصيبي (أحزابي المُسندة) مع بداية كل حزب
                  const Text('الأحزاب المسندة إليّ', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 8),
                  if (_myHizbs.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 8),
                      child: Text('لم يُسند إليك أحزاب بعد.', style: TextStyle(color: AppTheme.textMed)),
                    )
                  else
                    ..._myHizbs.map(_myHizbCard),
                  // أحزاب متاحة يمكن للعضو إسنادها لنفسه (حتى الحد الأقصى)
                  if (_canSelfAssign) ...[
                    const SizedBox(height: 12),
                    _availableCard(),
                  ],
                  const SizedBox(height: 18),
                  const Text('الأعضاء', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 8),
                  ..._orderedMembers.map(_memberCard),
                  const SizedBox(height: 18),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _shareToWhatsApp,
                      icon: const Icon(Icons.share_rounded, color: Colors.white),
                      label: const Text('مشاركة التوزيع على واتساب',
                          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                      style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF25D366),
                          padding: const EdgeInsets.symmetric(vertical: 14)),
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            ),
    );
  }

  // مشاركة الأحزاب غير المكتملة فقط (المتبقّية) مع أصحابها + غير المسندة
  Future<void> _shareToWhatsApp() async {
    final dateStr = _fmtD(DateTime.now());
    final buf = StringBuffer()
      ..writeln('📖 مجموعة: ${widget.group.name}')
      ..writeln('📅 $dateStr')
      ..writeln('⏳ الأحزاب المتبقّية (لم تُقرأ بعد):')
      ..writeln();
    var any = false;
    // لكل عضو: أحزابه المُسندة غير المقروءة فقط
    for (final a in _orderedMembers) {
      final name = (a.displayName != null && a.displayName!.trim().isNotEmpty)
          ? a.displayName!.trim()
          : 'عضو';
      final pending = (_map.entries
          .where((e) => e.value == a.userId && !_reads.containsKey(e.key))
          .map((e) => e.key)
          .toList()
        ..sort());
      if (pending.isEmpty) continue;
      any = true;
      buf.writeln('👤 $name');
      for (final h in pending) {
        final verse = _ahzab == null ? '' : (HizbService.find(_ahzab!, h)?.openingVerse ?? '');
        final v = verse.isEmpty ? '' : ' — ${verse.length > 70 ? '${verse.substring(0, 70)}…' : verse}';
        buf.writeln('  ⬜ الحزب $h$v');
      }
      buf.writeln();
    }
    // الأحزاب غير المسندة (متاحة لأي عضو)
    if (_unassignedHizbs.isNotEmpty) {
      any = true;
      buf.writeln('🟡 أحزاب غير مسندة (متاحة):');
      buf.writeln('  ${_unassignedHizbs.join('، ')}');
      buf.writeln();
    }
    if (!any) buf.writeln('✅ اكتملت كل الأحزاب، بارك الله فيكم.');
    final text = buf.toString().trim();

    // محاولة فتح واتساب مباشرة، وإلا مشاركة عامة
    final waApp = Uri.parse('whatsapp://send?text=${Uri.encodeComponent(text)}');
    final waWeb = Uri.parse('https://wa.me/?text=${Uri.encodeComponent(text)}');
    try {
      if (await canLaunchUrl(waApp)) {
        await launchUrl(waApp, mode: LaunchMode.externalApplication);
        return;
      }
      if (await canLaunchUrl(waWeb)) {
        await launchUrl(waWeb, mode: LaunchMode.externalApplication);
        return;
      }
    } catch (_) {}
    await SharePlus.instance.share(ShareParams(text: text, subject: widget.group.name));
  }

  String _fmtD(DateTime d) => '${d.day}/${d.month}/${d.year}';

  // بطاقة الأحزاب غير المسندة (المجمّع) — للمؤسس، مع دعوة لتوزيعها يدوياً
  Widget _unassignedCard() {
    final pool = _unassignedHizbs;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF6E9),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.gold),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Icon(Icons.inbox_rounded, size: 18, color: AppTheme.gold),
          const SizedBox(width: 8),
          Text('أحزاب غير مسندة (${pool.length})',
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
        ]),
        const SizedBox(height: 4),
        const Text('يمكنك توزيعها يدوياً على الأعضاء أو تركها للأعضاء الجدد.',
            style: TextStyle(fontSize: 12, color: AppTheme.textMed)),
        const SizedBox(height: 10),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: pool
              .map((h) => Container(
                    width: 32,
                    height: 32,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppTheme.gold.withOpacity(.5)),
                    ),
                    child: Text('$h',
                        style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: Color(0xFF8A6D00))),
                  ))
              .toList(),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: () async {
              await Navigator.push(context, MaterialPageRoute(
                  builder: (_) => DistributionScreen(group: widget.group, members: _assignments)));
              _load();
            },
            icon: const Icon(Icons.edit_rounded, size: 18, color: AppTheme.primary),
            label: const Text('توزيع الأحزاب غير المسندة', style: TextStyle(color: AppTheme.primary)),
            style: OutlinedButton.styleFrom(side: const BorderSide(color: AppTheme.primary)),
          ),
        ),
      ]),
    );
  }

  // بطاقة: أحزاب لم تُقرأ بعد (المسندة غير المقروءة)
  Widget _unreadHizbsCard() {
    final list = _unreadAssignedHizbs;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFDF0F0),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE1B4B4)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Icon(Icons.menu_book_rounded, size: 18, color: Color(0xFFB84A4A)),
          const SizedBox(width: 8),
          Text('أحزاب لم تُقرأ بعد (${list.length})',
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
        ]),
        const SizedBox(height: 10),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: list
              .map((h) => Container(
                    width: 32,
                    height: 32,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFE1B4B4)),
                    ),
                    child: Text('$h',
                        style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: Color(0xFFB84A4A))),
                  ))
              .toList(),
        ),
      ]),
    );
  }

  // بطاقة: أعضاء متأخرون — صور مصغّرة، الضغط يفتح تفاصيل العضو
  Widget _lateMembersCard() {
    final late = _lateMembers;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF2F4F8),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFC9D2E0)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Icon(Icons.schedule_rounded, size: 18, color: Color(0xFF3B5A8A)),
          const SizedBox(width: 8),
          Text('أعضاء متأخرون (${late.length})',
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
        ]),
        const SizedBox(height: 4),
        const Text('لم يُكملوا قراءة نصيبهم بعد. اضغط الصورة لعرض التفاصيل.',
            style: TextStyle(fontSize: 12, color: AppTheme.textMed)),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: late.map((a) {
            final isFounder = widget.group.ownerId != null && a.userId == widget.group.ownerId;
            final accent = isFounder ? AppTheme.gold : AppTheme.primary;
            return GestureDetector(
              onTap: () => _showMemberSheet(a),
              child: CircleAvatar(
                radius: 20,
                backgroundColor: accent.withOpacity(.15),
                backgroundImage: a.avatarUrl != null ? NetworkImage(a.avatarUrl!) : null,
                child: a.avatarUrl == null ? Icon(Icons.person, size: 22, color: accent) : null,
              ),
            );
          }).toList(),
        ),
      ]),
    );
  }

  // بطاقة: أحزاب متاحة يسندها العضو لنفسه (حتى الحد الأقصى)
  Widget _availableCard() {
    final pool = _unassignedHizbs;
    final remaining = _cap - _myHizbs.length;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.primary.withOpacity(.06),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.primary.withOpacity(.4)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Icon(Icons.add_circle_outline_rounded, size: 18, color: AppTheme.primary),
          const SizedBox(width: 8),
          const Text('أحزاب متاحة — أسندها لنفسك',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
        ]),
        const SizedBox(height: 4),
        Text('يمكنك أخذ حتى $remaining حزباً إضافياً (الحد الأقصى $_cap). اضغط الرقم لإسناده إليك.',
            style: const TextStyle(fontSize: 12, color: AppTheme.textMed)),
        const SizedBox(height: 10),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: pool
              .map((h) => GestureDetector(
                    onTap: () => _selfAssign(h),
                    child: Container(
                      width: 34,
                      height: 34,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppTheme.primary.withOpacity(.5)),
                      ),
                      child: Text('$h',
                          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: AppTheme.primary)),
                    ),
                  ))
              .toList(),
        ),
      ]),
    );
  }

  // لا توجد دورة بعد: دعوة المؤسس لبدء الدورة الأولى، وإشعار باقي الأعضاء بالانتظار
  Widget _noCycleCard() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE8E4DF)),
      ),
      child: Column(children: [
        Icon(Icons.menu_book_rounded, size: 40, color: AppTheme.primary.withOpacity(.85)),
        const SizedBox(height: 10),
        const Text('لم تبدأ الدورة بعد',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
        const SizedBox(height: 6),
        Text(
          _isOwner
              ? 'ابدأ الدورة الأولى وحدّد العدد الأقصى للأحزاب لكل عضو، وسيُوزّع التطبيق الأحزاب تلقائياً.'
              : 'بانتظار أن يبدأ مؤسس المجموعة الدورة ويوزّع الأحزاب.',
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 13, color: AppTheme.textMed, height: 1.6),
        ),
        if (_isOwner) ...[
          const SizedBox(height: 14),
          if (_hasQuorum)
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _newCycleDialog,
                icon: const Icon(Icons.play_arrow_rounded, color: Colors.white),
                label: const Text('بدء الدورة الأولى',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primary, padding: const EdgeInsets.symmetric(vertical: 13)),
              ),
            )
          else
            _quorumNotice(),
        ],
      ]),
    );
  }

  // إشعار انتظار اكتمال النصاب (أقل من 10 أعضاء)
  Widget _quorumNotice() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF6E9),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.gold),
      ),
      child: Column(children: [
        const Icon(Icons.groups_rounded, color: AppTheme.gold, size: 22),
        const SizedBox(height: 6),
        Text('في انتظار اكتمال النصاب',
            style: TextStyle(fontWeight: FontWeight.w800, color: AppTheme.gold.withOpacity(.95))),
        const SizedBox(height: 2),
        Text('يلزم $_quorum أعضاء على الأقل لبدء الدورة (لديك $_memberCount).',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 12, color: AppTheme.textMed)),
      ]),
    );
  }

  // بطاقة الدورة الحالية + أدوات المؤسس
  Widget _cycleCard() {
    final c = _cycle;
    final period = c == null
        ? ''
        : 'من ${_fmtD(c.startDate)}${c.endDate != null ? ' إلى ${_fmtD(c.endDate!)}' : ''}';
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE8E4DF)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Icon(Icons.event_repeat_rounded, color: AppTheme.primary, size: 20),
          const SizedBox(width: 8),
          Text('الدورة ${c?.cycleNo ?? 1}', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
        ]),
        if (period.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 4, right: 28),
            child: Text(period, style: const TextStyle(color: AppTheme.textMed, fontSize: 12)),
          ),
        if (_isOwner) ...[
          const SizedBox(height: 12),
          Row(children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => Navigator.push(context,
                    MaterialPageRoute(builder: (_) => CycleArchiveScreen(group: widget.group))),
                icon: const Icon(Icons.inventory_2_outlined, color: AppTheme.primary, size: 18),
                label: const Text('الأرشيف', style: TextStyle(color: AppTheme.primary)),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: _hasQuorum ? _newCycleDialog : null,
                icon: const Icon(Icons.add, color: Colors.white, size: 18),
                label: const Text('دورة جديدة', style: TextStyle(color: Colors.white)),
                style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primary, disabledBackgroundColor: const Color(0xFFBFC7C0)),
              ),
            ),
          ]),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: (c?.nearEnd ?? false)
                ? OutlinedButton.icon(
                    onPressed: () => _setNearEnd(false),
                    icon: const Icon(Icons.timelapse_rounded, size: 18, color: Color(0xFFB84A4A)),
                    label: const Text('الدورة قاربت النهاية ✓ (اضغط للإلغاء)',
                        style: TextStyle(color: Color(0xFFB84A4A), fontWeight: FontWeight.w700)),
                    style: OutlinedButton.styleFrom(side: const BorderSide(color: Color(0xFFB84A4A))),
                  )
                : OutlinedButton.icon(
                    onPressed: () => _setNearEnd(true),
                    icon: const Icon(Icons.timelapse_rounded, size: 18, color: AppTheme.gold),
                    label: const Text('اعتبار الدورة قاربت النهاية',
                        style: TextStyle(color: Color(0xFF8A6D00), fontWeight: FontWeight.w700)),
                    style: OutlinedButton.styleFrom(side: const BorderSide(color: AppTheme.gold)),
                  ),
          ),
          if (!_hasQuorum) ...[
            const SizedBox(height: 8),
            _quorumNotice(),
          ],
        ],
      ]),
    );
  }

  // اعتبار الدورة قاربت النهاية (يفعّل احتساب المتأخرين)
  Future<void> _setNearEnd(bool value) async {
    try {
      await GroupService.setCycleNearEnd(widget.group.id, value);
      await _load();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('تعذّر: $e')));
    }
  }

  Future<void> _newCycleDialog() async {
    final isFirst = _cycle == null;
    // القيمة المفضّلة للحد الأقصى: تقسيم 60 على عدد الأعضاء (محصورة بين 1 و6)
    final memberN = _assignments.isNotEmpty ? _assignments.length : (_progress?.members ?? 1);
    final recommended = memberN <= 0 ? 6 : (60 / memberN).ceil().clamp(1, 6);
    int maxPer = recommended;
    String mode = 'rotate'; // rotate | keep
    final created = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setL) => AlertDialog(
          title: Text(isFirst ? 'بدء الدورة الأولى' : 'دورة جديدة'),
          content: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              // اختيار طريقة التوزيع (يظهر فقط في الدورات اللاحقة)
              if (!isFirst) ...[
                const Text('طريقة التوزيع', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                const SizedBox(height: 8),
                _cycleModeOption(
                  selected: mode == 'rotate',
                  title: 'تدوير الأحزاب',
                  subtitle: 'إعادة توزيع مع حدٍّ أقصى لكل عضو (كل عضو ينتقل للكتلة التالية).',
                  onTap: () => setL(() => mode = 'rotate'),
                ),
                const SizedBox(height: 8),
                _cycleModeOption(
                  selected: mode == 'keep',
                  title: 'الحفاظ على نفس التوزيع',
                  subtitle: 'يبقى نصيب كل عضو كما هو. عند غياب عضو تُسند أحزابه للاحتياطي الأول أو تبقى غير مسندة.',
                  onTap: () => setL(() => mode = 'keep'),
                ),
                const SizedBox(height: 14),
              ] else
                const Text(
                  'سيُوزّع التطبيق الأحزاب تلقائياً على الأعضاء بحد أقصى لكل عضو. ما يتبقّى يبقى للأعضاء الجدد أو للتوزيع اليدوي.',
                  style: TextStyle(color: AppTheme.textMed, fontSize: 12),
                ),
              // الحد الأقصى: فقط في وضع التدوير أو الدورة الأولى
              if (isFirst || mode == 'rotate') ...[
                const SizedBox(height: 8),
                const Text('العدد الأقصى للأحزاب لكل عضو',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: List.generate(6, (i) {
                    final v = i + 1;
                    final sel = maxPer == v;
                    final isRec = v == recommended;
                    return GestureDetector(
                      onTap: () => setL(() => maxPer = v),
                      child: Container(
                        width: 42,
                        height: 48,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: sel ? AppTheme.primary : AppTheme.surface,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                              color: sel ? AppTheme.primary : (isRec ? AppTheme.gold : const Color(0xFFDDDDDD)),
                              width: isRec && !sel ? 1.6 : 1),
                        ),
                        child: Column(mainAxisSize: MainAxisSize.min, children: [
                          Text('$v',
                              style: TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 17,
                                  color: sel ? Colors.white : AppTheme.textHigh)),
                          if (isRec)
                            Text('مفضّل',
                                style: TextStyle(
                                    fontSize: 8,
                                    fontWeight: FontWeight.w700,
                                    color: sel ? Colors.white : AppTheme.gold)),
                        ]),
                      ),
                    );
                  }),
                ),
              ],
            ]),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
            ElevatedButton(onPressed: () => Navigator.pop(ctx, true),
                child: Text(isFirst ? 'بدء' : 'إنشاء')),
          ],
        ),
      ),
    );
    if (created != true) return;
    try {
      // تاريخ البداية = اليوم تلقائياً؛ تاريخ النهاية يُحدَّد عند بدء الدورة المقبلة
      await GroupService.startNewCycle(widget.group.id, maxPerMember: maxPer, mode: mode);
      await _load();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(isFirst ? 'بدأت الدورة الأولى' : 'بدأت دورة جديدة')));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('تعذّر: $e')));
    }
  }

  // خيار طريقة التوزيع في نافذة الدورة الجديدة
  Widget _cycleModeOption({
    required bool selected,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: selected ? AppTheme.primary.withOpacity(.08) : AppTheme.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: selected ? AppTheme.primary : const Color(0xFFDDDDDD), width: selected ? 1.6 : 1),
        ),
        child: Row(children: [
          Icon(selected ? Icons.radio_button_checked_rounded : Icons.radio_button_unchecked_rounded,
              size: 20, color: selected ? AppTheme.primary : AppTheme.textLow),
          const SizedBox(width: 8),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
              const SizedBox(height: 2),
              Text(subtitle, style: const TextStyle(fontSize: 11, color: AppTheme.textMed, height: 1.4)),
            ]),
          ),
        ]),
      ),
    );
  }

  // بطاقة حزب من نصيبي: الرقم + بداية الحزب + زر «تمت القراءة»
  Widget _myHizbCard(int h) {
    final done = _reads.containsKey(h);
    final verse = _ahzab == null ? '' : (HizbService.find(_ahzab!, h)?.openingVerse ?? '');
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: done ? AppTheme.primary.withOpacity(.06) : AppTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: done ? AppTheme.primary : const Color(0xFFE8E4DF), width: done ? 1.5 : 1),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            CircleAvatar(radius: 18, backgroundColor: AppTheme.primary.withOpacity(.12),
                child: Text('$h', style: const TextStyle(color: AppTheme.primary, fontWeight: FontWeight.w800))),
            const SizedBox(width: 10),
            Expanded(child: Text('الحزب $h', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16))),
            if (done) const Icon(Icons.check_circle_rounded, color: AppTheme.primary),
          ]),
          if (verse.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(verse, textAlign: TextAlign.right, maxLines: 3, overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 15, height: 1.9, color: AppTheme.textHigh)),
          ],
          const SizedBox(height: 12),
          Row(children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => Navigator.push(context, MaterialPageRoute(
                    builder: (_) => PdfViewerScreen(hizbNumber: h, title: 'الحزب $h'))),
                icon: const Icon(Icons.menu_book_rounded, size: 18, color: AppTheme.primary),
                label: const Text('قراءة', style: TextStyle(color: AppTheme.primary, fontWeight: FontWeight.w700)),
                style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: AppTheme.primary),
                    padding: const EdgeInsets.symmetric(vertical: 12)),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: done
                  ? OutlinedButton.icon(
                      onPressed: null,
                      icon: const Icon(Icons.check_circle_rounded, size: 18, color: AppTheme.primary),
                      label: const Text('تمت القراءة ✓',
                          style: TextStyle(color: AppTheme.primary, fontWeight: FontWeight.w700)),
                    )
                  : ElevatedButton(
                      onPressed: () => _markMine(h),
                      style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primary, padding: const EdgeInsets.symmetric(vertical: 12)),
                      child: const Text('تمت القراءة', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                    ),
            ),
          ]),
        ]),
      ),
    );
  }

  // أرقام أحزاب العضو كأيقونات صغيرة (عند أكثر من حزبين)
  Widget _memberHizbNumbers(String userId, List<int> hizbs) {
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: hizbs.map((h) {
        final done = _reads[h] == userId;
        return Container(
          width: 30,
          height: 30,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: done ? AppTheme.primary : AppTheme.primary.withOpacity(.10),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppTheme.primary.withOpacity(.4), width: done ? 0 : 1),
          ),
          child: Text('$h',
              style: TextStyle(
                  color: done ? Colors.white : AppTheme.primary,
                  fontWeight: FontWeight.w800,
                  fontSize: 13)),
        );
      }).toList(),
    );
  }

  // بداية حزب العضو (عند حزبين أو أقل)
  Widget _memberHizbVerse(String userId, int h) {
    final done = _reads[h] == userId;
    final verse = _ahzab == null ? '' : (HizbService.find(_ahzab!, h)?.openingVerse ?? '');
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: done ? AppTheme.primary : AppTheme.primary.withOpacity(.10),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text('$h',
              style: TextStyle(
                  color: done ? Colors.white : AppTheme.primary,
                  fontWeight: FontWeight.w800,
                  fontSize: 12)),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(verse.isEmpty ? 'الحزب $h' : verse,
              textAlign: TextAlign.right,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 13, height: 1.7, color: AppTheme.textHigh)),
        ),
      ]),
    );
  }

  Widget _memberCard(GroupAssignment a) {
    final isMe = a.userId == _uid;
    final isFounder = widget.group.ownerId != null && a.userId == widget.group.ownerId;
    final accent = isFounder ? AppTheme.gold : AppTheme.primary;
    final name = (a.displayName != null && a.displayName!.trim().isNotEmpty)
        ? a.displayName!.trim()
        : 'عضو';
    final hizbs = (_map.entries.where((e) => e.value == a.userId).map((e) => e.key).toList()..sort());
    final assigned = hizbs.length;
    final readN = _reads.values.where((u) => u == a.userId).length;
    return GestureDetector(
      onTap: _isOwner ? () => _showMemberSheet(a) : null,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isFounder
              ? AppTheme.goldLight
              : (isMe ? AppTheme.primary.withOpacity(.06) : AppTheme.surface),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isFounder ? AppTheme.gold : (isMe ? AppTheme.primary : const Color(0xFFE8E4DF)),
            width: isFounder ? 1.6 : 1,
          ),
        ),
        child: Row(children: [
          CircleAvatar(radius: 20, backgroundColor: accent.withOpacity(.15),
              backgroundImage: a.avatarUrl != null ? NetworkImage(a.avatarUrl!) : null,
              child: a.avatarUrl == null ? Icon(Icons.person, size: 22, color: accent) : null),
          const SizedBox(width: 10),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Flexible(
                  child: Text('$name${isMe ? ' (أنا)' : ''}',
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w700)),
                ),
                if (isFounder) ...[
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(color: AppTheme.gold, borderRadius: BorderRadius.circular(20)),
                    child: const Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(Icons.star_rounded, size: 12, color: Colors.white),
                      SizedBox(width: 3),
                      Text('المؤسس', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700)),
                    ]),
                  ),
                ],
                if (a.reserveRank != null) ...[
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(color: const Color(0xFF1E3A8A), borderRadius: BorderRadius.circular(20)),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      const Icon(Icons.bookmark_added_rounded, size: 12, color: Colors.white),
                      const SizedBox(width: 3),
                      Text('احتياطي ${_ord(a.reserveRank)}',
                          style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700)),
                    ]),
                  ),
                ],
              ]),
              const SizedBox(height: 4),
              Text('$assigned حزباً مُسند  •  $readN مقروء',
                  style: const TextStyle(fontSize: 12, color: AppTheme.textMed)),
              if (_isOwner)
                Text('المستوى ${a.level} • ${a.streak} يوم تتابع',
                    style: const TextStyle(fontSize: 11, color: AppTheme.textLow)),
              if (hizbs.isNotEmpty) ...[
                const SizedBox(height: 8),
                if (hizbs.length > 2)
                  _memberHizbNumbers(a.userId, hizbs)
                else
                  ...hizbs.map((h) => _memberHizbVerse(a.userId, h)),
              ],
            ]),
          ),
          if (_isOwner) const Icon(Icons.chevron_left_rounded, color: AppTheme.textLow),
        ]),
      ),
    );
  }

  Widget _sheetStat(String k, String v, IconData ic) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(ic, color: AppTheme.primary),
          const SizedBox(height: 4),
          Text(v, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
          Text(k, style: const TextStyle(fontSize: 11, color: AppTheme.textMed)),
        ],
      );

  void _showMemberSheet(GroupAssignment a) {
    final memberIsOwner = a.userId == widget.group.ownerId;
    final name = (a.displayName != null && a.displayName!.trim().isNotEmpty) ? a.displayName!.trim() : 'عضو';
    final assigned = _map.values.where((u) => u == a.userId).length;
    final readN = _reads.values.where((u) => u == a.userId).length;
    // متأخّر = لديه أحزاب مُسندة غير مقروءة
    final isLate = _map.entries.any((e) => e.value == a.userId && !_reads.containsKey(e.key));
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppTheme.surface,
      useSafeArea: true,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(20, 20, 20, 32 + MediaQuery.of(ctx).viewPadding.bottom),
        child: SingleChildScrollView(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          CircleAvatar(
            radius: 30, backgroundColor: AppTheme.primary.withOpacity(.12),
            backgroundImage: a.avatarUrl != null ? NetworkImage(a.avatarUrl!) : null,
            child: a.avatarUrl == null
                ? const Icon(Icons.person, size: 32, color: AppTheme.primary) : null,
          ),
          const SizedBox(height: 10),
          Text(name, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
          if (memberIsOwner)
            const Padding(
              padding: EdgeInsets.only(top: 4),
              child: Text('مؤسس المجموعة',
                  style: TextStyle(color: AppTheme.gold, fontWeight: FontWeight.w700)),
            ),
          const SizedBox(height: 18),
          Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
            _sheetStat('المستوى', '${a.level}', Icons.workspace_premium_rounded),
            _sheetStat('أيام التتابع', '${a.streak}', Icons.local_fire_department_rounded),
            _sheetStat('مقروء / مُسند', '$readN / $assigned', Icons.menu_book_rounded),
          ]),
          const SizedBox(height: 18),
          // تنبيهات المؤسس للعضو المتأخر (حد 3 في الدورة) + سجلّها
          if (_isOwner && !memberIsOwner && isLate)
            _MemberReminders(group: widget.group, member: a),
          const SizedBox(height: 6),
          // رتبة الاحتياطي: للمؤسس فقط، لعضو بلا أحزاب مُسندة
          if (_isOwner && !memberIsOwner && assigned == 0) ...[
            const Align(
              alignment: AlignmentDirectional.centerStart,
              child: Text('رتبة الاحتياطي', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
            ),
            const SizedBox(height: 8),
            Row(children: [
              for (final r in [1, 2, 3])
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 3),
                    child: OutlinedButton(
                      onPressed: () { Navigator.pop(ctx); _setReserve(a, a.reserveRank == r ? null : r); },
                      style: OutlinedButton.styleFrom(
                        backgroundColor: a.reserveRank == r ? const Color(0xFF1E3A8A) : Colors.transparent,
                        side: const BorderSide(color: Color(0xFF1E3A8A)),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                      ),
                      child: Text(_ordinals[r],
                          style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: a.reserveRank == r ? Colors.white : const Color(0xFF1E3A8A))),
                    ),
                  ),
                ),
            ]),
            if (a.reserveRank != null)
              TextButton(
                onPressed: () { Navigator.pop(ctx); _setReserve(a, null); },
                child: const Text('إلغاء رتبة الاحتياطي'),
              ),
            const SizedBox(height: 14),
          ],
          if (_isOwner && assigned > 0)
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () { Navigator.pop(ctx); _markAbsent(a); },
                icon: const Icon(Icons.person_off_rounded, size: 18, color: Color(0xFFB8860B)),
                label: const Text('تحديد كغائب (تحرير أحزابه)',
                    style: TextStyle(color: Color(0xFFB8860B), fontWeight: FontWeight.w700)),
                style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Color(0xFFB8860B)),
                    padding: const EdgeInsets.symmetric(vertical: 12)),
              ),
            ),
          if (_isOwner && !memberIsOwner) ...[
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () { Navigator.pop(ctx); _removeMember(a); },
                icon: const Icon(Icons.person_remove_rounded, color: Colors.white),
                label: const Text('حذف من المجموعة', style: TextStyle(color: Colors.white)),
                style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red, padding: const EdgeInsets.symmetric(vertical: 12)),
              ),
            ),
          ],
          // الإبلاغ عن عضو أو حظره — متاح لأي عضو تجاه غيره (متطلّب Apple 1.2)
          if (a.userId != _uid) ...[
            const SizedBox(height: 10),
            const Divider(height: 24),
            Row(children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () { Navigator.pop(ctx); _reportMember(a); },
                  icon: const Icon(Icons.flag_outlined, size: 18, color: Color(0xFFB8860B)),
                  label: const Text('إبلاغ', style: TextStyle(color: Color(0xFFB8860B), fontWeight: FontWeight.w700)),
                  style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Color(0xFFB8860B)),
                      padding: const EdgeInsets.symmetric(vertical: 12)),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () { Navigator.pop(ctx); _blockMember(a); },
                  icon: const Icon(Icons.block_rounded, size: 18, color: Colors.red),
                  label: const Text('حظر', style: TextStyle(color: Colors.red, fontWeight: FontWeight.w700)),
                  style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Colors.red),
                      padding: const EdgeInsets.symmetric(vertical: 12)),
                ),
              ),
            ]),
          ],
        ]),
        ),
      ),
    );
  }

  Future<void> _leaveGroup() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('الخروج من المجموعة'),
        content: const Text('هل تريد الخروج من هذه المجموعة؟ سيتحرّر نصيبك من الأحزاب.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('خروج', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await GroupService.leave(widget.group.id);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('تعذّر: $e')));
    }
  }

  Future<void> _removeMember(GroupAssignment a) async {
    final name = (a.displayName != null && a.displayName!.trim().isNotEmpty) ? a.displayName!.trim() : 'العضو';
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('حذف عضو'),
        content: Text('حذف $name من المجموعة؟'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('حذف', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await GroupService.removeMember(widget.group.id, a.userId);
      await _load();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('تعذّر: $e')));
    }
  }

  // الإبلاغ عن عضو مسيء (متطلّب مراجعة Apple للمحتوى من المستخدمين)
  Future<void> _reportMember(GroupAssignment a) async {
    final name = (a.displayName != null && a.displayName!.trim().isNotEmpty) ? a.displayName!.trim() : 'العضو';
    String reason = 'محتوى غير لائق';
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSt) => AlertDialog(
          title: Text('الإبلاغ عن $name'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('اختر سبب الإبلاغ:', style: TextStyle(fontSize: 13, color: AppTheme.textMed)),
              const SizedBox(height: 8),
              for (final r in const [
                'محتوى غير لائق',
                'اسم أو صورة مسيئة',
                'مضايقة أو إساءة',
                'انتحال شخصية',
                'سبب آخر',
              ])
                RadioListTile<String>(
                  value: r, groupValue: reason,
                  onChanged: (v) => setSt(() => reason = v!),
                  title: Text(r, style: const TextStyle(fontSize: 14)),
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFB8860B)),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('إرسال البلاغ', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
    if (ok != true) return;
    try {
      await GroupService.reportMember(widget.group.id, a.userId, reason);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('تم إرسال البلاغ. سيُراجَع خلال 24 ساعة.')));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('تعذّر: $e')));
    }
  }

  // حظر عضو — يُخفى محتواه عن هذا المستخدم فوراً (متطلّب مراجعة Apple)
  Future<void> _blockMember(GroupAssignment a) async {
    final name = (a.displayName != null && a.displayName!.trim().isNotEmpty) ? a.displayName!.trim() : 'العضو';
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('حظر عضو'),
        content: Text('لن ترى محتوى $name بعد الآن. هل تريد المتابعة؟'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('حظر', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await GroupService.blockUser(a.userId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('تم حظر $name')));
      }
      await _load();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('تعذّر: $e')));
    }
  }

  // تعيين/إلغاء رتبة احتياطي لعضو
  Future<void> _setReserve(GroupAssignment a, int? rank) async {
    try {
      await GroupService.setReserve(widget.group.id, a.userId, rank);
      await _load();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(rank == null ? 'أُلغيت رتبة الاحتياطي' : 'تم التعيين كاحتياطي ${_ord(rank)}')));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('تعذّر: $e')));
    }
  }

  // تحديد عضو كغائب: تُحرَّر أحزابه غير المقروءة إلى المجمّع
  Future<void> _markAbsent(GroupAssignment a) async {
    final name = (a.displayName != null && a.displayName!.trim().isNotEmpty) ? a.displayName!.trim() : 'العضو';
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('تحديد كغائب'),
        content: Text('تحرير الأحزاب غير المقروءة المسندة إلى $name وإعادتها إلى المجمّع لتوزيعها على غيره؟'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFB8860B)),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('تحرير', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      final freed = await GroupService.markAbsent(widget.group.id, a.userId);
      await _load();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('تم تحرير $freed حزباً إلى المجمّع')));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('تعذّر: $e')));
    }
  }
}

// ═══════════════════════════════════════════════
//  شاشة مسح رمز QR — تُرجع النص الممسوح
// ═══════════════════════════════════════════════
class QrScanScreen extends StatefulWidget {
  const QrScanScreen({super.key});
  @override
  State<QrScanScreen> createState() => _QrScanScreenState();
}

class _QrScanScreenState extends State<QrScanScreen> {
  bool _handled = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: AppTheme.primary,
        foregroundColor: Colors.white,
        title: const Text('مسح رمز المجموعة', style: TextStyle(fontWeight: FontWeight.w700)),
        centerTitle: true,
      ),
      body: Stack(
        children: [
          MobileScanner(
            onDetect: (capture) {
              if (_handled) return;
              final codes = capture.barcodes;
              if (codes.isEmpty) return;
              final raw = codes.first.rawValue;
              if (raw == null || raw.isEmpty) return;
              _handled = true;
              Navigator.pop(context, raw);
            },
          ),
          Center(
            child: Container(
              width: 240, height: 240,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.white, width: 3),
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
          const Positioned(
            bottom: 40, left: 0, right: 0,
            child: Text('وجّه الكاميرا نحو رمز QR الخاص بالمجموعة',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white, fontSize: 14)),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════
//  أرشيف الدورات السابقة
// ═══════════════════════════════════════════════
class CycleArchiveScreen extends StatelessWidget {
  final GroupInfo group;
  const CycleArchiveScreen({super.key, required this.group});

  String _fmt(DateTime d) => '${d.day}/${d.month}/${d.year}';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: AppTheme.primary, foregroundColor: Colors.white,
        title: const Text('الدورات السابقة', style: TextStyle(fontWeight: FontWeight.w700)),
        centerTitle: true,
      ),
      body: FutureBuilder<List<GroupCycle>>(
        future: GroupService.archivedCycles(group.id),
        builder: (context, snap) {
          if (!snap.hasData) return const Center(child: CircularProgressIndicator(color: AppTheme.primary));
          final cycles = snap.data!;
          if (cycles.isEmpty) {
            return const Center(child: Padding(padding: EdgeInsets.all(24),
              child: Text('لا دورات سابقة بعد.', style: TextStyle(color: AppTheme.textMed))));
          }
          return ListView(
            padding: const EdgeInsets.all(16),
            children: cycles.map((c) {
              final period = 'من ${_fmt(c.startDate)}${c.endDate != null ? ' إلى ${_fmt(c.endDate!)}' : ''}';
              final pct = (c.hizbsRead * 100 / 60).round();
              return Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppTheme.surface,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFE8E4DF)),
                ),
                child: Row(children: [
                  CircleAvatar(
                    radius: 22, backgroundColor: AppTheme.primary.withOpacity(.1),
                    child: Text('${c.cycleNo}', style: const TextStyle(color: AppTheme.primary, fontWeight: FontWeight.w800)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('الدورة ${c.cycleNo}', style: const TextStyle(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 2),
                    Text(period, style: const TextStyle(fontSize: 12, color: AppTheme.textMed)),
                    if (c.durationLabel != null) ...[
                      const SizedBox(height: 3),
                      Row(children: [
                        const Icon(Icons.timer_outlined, size: 13, color: AppTheme.primary),
                        const SizedBox(width: 4),
                        Text('المدة: ${c.durationLabel}',
                            style: const TextStyle(
                                fontSize: 12, color: AppTheme.primary, fontWeight: FontWeight.w700)),
                      ]),
                    ],
                    const SizedBox(height: 2),
                    Text('${c.hizbsRead} / 60 حزباً مقروء ($pct%) • ${c.members} أعضاء',
                        style: const TextStyle(fontSize: 12, color: AppTheme.textLow)),
                  ])),
                ]),
              );
            }).toList(),
          );
        },
      ),
    );
  }
}

// ═══════════════════════════════════════════════
//  شاشة رمز الانضمام (QR) — للمالك فقط
// ═══════════════════════════════════════════════
class GroupJoinCodeScreen extends StatefulWidget {
  final GroupInfo group;
  const GroupJoinCodeScreen({super.key, required this.group});
  @override
  State<GroupJoinCodeScreen> createState() => _GroupJoinCodeScreenState();
}

class _GroupJoinCodeScreenState extends State<GroupJoinCodeScreen> {
  String? _code;
  String _mode = 'invite'; // invite | open | closed
  bool _loading = true;
  bool get _isOwner => widget.group.ownerId != null && widget.group.ownerId == AccountService.user?.id;

  @override
  void initState() {
    super.initState();
    _code = widget.group.inviteCode;
    _mode = widget.group.joinMode;
    _load();
  }

  Future<void> _load() async {
    try {
      final g = await GroupService.group(widget.group.id);
      if (g != null) {
        if (g.inviteCode != null && g.inviteCode!.isNotEmpty) _code = g.inviteCode;
        _mode = g.joinMode;
      }
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _setMode(String m) async {
    final prev = _mode;
    setState(() => _mode = m);
    try {
      await GroupService.setJoinMode(widget.group.id, m);
    } catch (e) {
      if (mounted) {
        setState(() => _mode = prev);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('تعذّر: $e')));
      }
    }
  }

  String get _modeHint {
    switch (_mode) {
      case 'open':
        return 'مفتوحة: أي شخص يمسح الرمز ينضم، والرمز ثابت لا يتغيّر ويصلح لعدة أشخاص.';
      case 'closed':
        return 'مغلقة: لا يمكن لأحد الانضمام حتى عبر الرمز.';
      default:
        return 'بدعوة: يتغيّر الرمز تلقائياً بعد كل عضو جديد (يصلح لشخص واحد).';
    }
  }

  @override
  Widget build(BuildContext context) {
    final code = _code ?? '';
    final closed = _mode == 'closed';
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: AppTheme.primary, foregroundColor: Colors.white,
        title: const Text('رمز الانضمام', style: TextStyle(fontWeight: FontWeight.w700)),
        centerTitle: true,
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_isOwner) ...[
                const Text('طور الانضمام', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                const SizedBox(height: 10),
                _modeSelector(),
                const SizedBox(height: 12),
              ],
              Text(
                _modeHint,
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppTheme.textMed, fontSize: 13, height: 1.5),
              ),
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(.08), blurRadius: 12, offset: const Offset(0, 4))],
                ),
                child: closed
                    ? const SizedBox(
                        width: 240, height: 240,
                        child: Center(
                          child: Column(mainAxisSize: MainAxisSize.min, children: [
                            Icon(Icons.lock_rounded, size: 56, color: AppTheme.textMed),
                            SizedBox(height: 10),
                            Text('المجموعة مغلقة', style: TextStyle(color: AppTheme.textMed, fontWeight: FontWeight.w700)),
                          ]),
                        ),
                      )
                    : (_loading && code.isEmpty)
                        ? const SizedBox(width: 240, height: 240, child: Center(child: CircularProgressIndicator(color: AppTheme.primary)))
                        : code.isEmpty
                            ? const SizedBox(width: 240, height: 240, child: Center(child: Text('لا يوجد رمز', style: TextStyle(color: AppTheme.textMed))))
                            : QrImageView(data: code, size: 240, backgroundColor: Colors.white),
              ),
              const SizedBox(height: 20),
              if (!closed)
                SelectableText(
                  code.isEmpty ? '...' : code,
                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 26, letterSpacing: 3, color: AppTheme.primary),
                ),
              const SizedBox(height: 24),
              if (!closed)
                OutlinedButton.icon(
                  onPressed: code.isEmpty ? null : () {
                    Clipboard.setData(ClipboardData(text: code));
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم نسخ الرمز')));
                  },
                  icon: const Icon(Icons.copy_rounded, size: 18),
                  label: const Text('نسخ'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.primary,
                    side: const BorderSide(color: AppTheme.primary),
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _modeSelector() {
    Widget chip(String value, String label, IconData ic) {
      final sel = _mode == value;
      return Expanded(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 3),
          child: GestureDetector(
            onTap: sel ? null : () => _setMode(value),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(
                color: sel ? AppTheme.primary : AppTheme.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: sel ? AppTheme.primary : const Color(0xFFE0E0E0)),
              ),
              child: Column(children: [
                Icon(ic, size: 20, color: sel ? Colors.white : AppTheme.textMed),
                const SizedBox(height: 4),
                Text(label,
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: sel ? Colors.white : AppTheme.textMed)),
              ]),
            ),
          ),
        ),
      );
    }

    return Row(children: [
      chip('invite', 'بدعوة', Icons.confirmation_number_rounded),
      chip('open', 'مفتوحة', Icons.lock_open_rounded),
      chip('closed', 'مغلقة', Icons.lock_rounded),
    ]);
  }
}

// ═══════════════════════════════════════════════
//  شاشة المجموعة «المشروع»: تقدّم نحو 10 أعضاء + رمز الانضمام + الأعضاء
// ═══════════════════════════════════════════════
class ProjectGroupScreen extends StatefulWidget {
  final GroupInfo group;
  const ProjectGroupScreen({super.key, required this.group});
  @override
  State<ProjectGroupScreen> createState() => _ProjectGroupScreenState();
}

class _ProjectGroupScreenState extends State<ProjectGroupScreen> {
  List<GroupAssignment> _members = [];
  String? _code;
  bool _loading = true;
  bool get _isOwner => widget.group.ownerId != null && widget.group.ownerId == AccountService.user?.id;

  @override
  void initState() {
    super.initState();
    _code = widget.group.inviteCode;
    _load();
  }

  Future<void> _load() async {
    try {
      _members = await GroupService.todayAssignments(widget.group.id);
    } catch (_) {}
    try {
      final g = await GroupService.group(widget.group.id);
      if (g?.inviteCode != null && g!.inviteCode!.isNotEmpty) _code = g.inviteCode;
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _leave() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('الخروج من المجموعة'),
        content: const Text('هل تريد الخروج من مشروع هذه المجموعة؟'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('خروج', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await GroupService.leave(widget.group.id);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('تعذّر: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final n = _members.isNotEmpty ? _members.length : widget.group.memberCount;
    final pct = (n / 10 * 100).clamp(0, 100).round();
    final code = _code ?? '';
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: AppTheme.primary, foregroundColor: Colors.white,
        title: Text(widget.group.name, style: const TextStyle(fontWeight: FontWeight.w700)),
        centerTitle: true,
        actions: [
          if (!_isOwner)
            IconButton(
              icon: const Icon(Icons.exit_to_app_rounded),
              tooltip: 'الخروج من المجموعة',
              onPressed: _leave,
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.primary))
          : ListView(
              padding: EdgeInsets.fromLTRB(16, 16, 16, 24 + MediaQuery.of(context).viewPadding.bottom),
              children: [
                // بطاقة التقدّم نحو النصاب
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF6E9),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppTheme.gold),
                  ),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      const Icon(Icons.hourglass_top_rounded, color: AppTheme.gold),
                      const SizedBox(width: 8),
                      const Text('مشروع مجموعة', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                      const Spacer(),
                      Text('$pct%', style: const TextStyle(fontWeight: FontWeight.w800, color: Color(0xFF8A6D00))),
                    ]),
                    const SizedBox(height: 10),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: LinearProgressIndicator(
                        value: (n / 10).clamp(0.0, 1.0), minHeight: 12,
                        backgroundColor: Colors.white, color: AppTheme.gold),
                    ),
                    const SizedBox(height: 6),
                    Text('انضمّ $n من 10 أعضاء. عند اكتمال العدد تتحوّل إلى مجموعة عادية وتبدأ الختمة.',
                        style: const TextStyle(fontSize: 12, color: AppTheme.textMed, height: 1.5)),
                  ]),
                ),
                const SizedBox(height: 16),
                // رمز الانضمام (للمؤسس) — مفتوح للجميع بنفس الرمز
                if (_isOwner) ...[
                  const Text('رمز الانضمام', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 4),
                  const Text('شارك هذا الرمز؛ المجموعة مفتوحة ويمكن لأي شخص الانضمام به.',
                      style: TextStyle(fontSize: 12, color: AppTheme.textMed)),
                  const SizedBox(height: 12),
                  Center(
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.white, borderRadius: BorderRadius.circular(16),
                        boxShadow: [BoxShadow(color: Colors.black.withOpacity(.08), blurRadius: 12, offset: const Offset(0, 4))],
                      ),
                      child: code.isEmpty
                          ? const SizedBox(width: 200, height: 200, child: Center(child: Text('لا يوجد رمز')))
                          : QrImageView(data: code, size: 200, backgroundColor: Colors.white),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Center(
                    child: SelectableText(code.isEmpty ? '...' : code,
                        style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 24, letterSpacing: 3, color: AppTheme.primary)),
                  ),
                  const SizedBox(height: 8),
                  Center(
                    child: OutlinedButton.icon(
                      onPressed: code.isEmpty ? null : () {
                        Clipboard.setData(ClipboardData(text: code));
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم نسخ الرمز')));
                      },
                      icon: const Icon(Icons.copy_rounded, size: 18),
                      label: const Text('نسخ'),
                      style: OutlinedButton.styleFrom(
                          foregroundColor: AppTheme.primary, side: const BorderSide(color: AppTheme.primary)),
                    ),
                  ),
                  const SizedBox(height: 18),
                ],
                // الأعضاء المنضمّون
                const Text('الأعضاء المنضمّون', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                const SizedBox(height: 4),
                const Text('اضغط الصورة لعرض التفاصيل.', style: TextStyle(fontSize: 12, color: AppTheme.textMed)),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 10, runSpacing: 10,
                  children: _members.map((a) {
                    final isFounder = widget.group.ownerId != null && a.userId == widget.group.ownerId;
                    return GestureDetector(
                      onTap: () => showMemberInfoSheet(context, a, founderId: widget.group.ownerId),
                      child: Column(mainAxisSize: MainAxisSize.min, children: [
                        CircleAvatar(
                          radius: 24,
                          backgroundColor: (isFounder ? AppTheme.gold : AppTheme.primary).withOpacity(.15),
                          backgroundImage: a.avatarUrl != null ? NetworkImage(a.avatarUrl!) : null,
                          child: a.avatarUrl == null
                              ? Icon(Icons.person, size: 26, color: isFounder ? AppTheme.gold : AppTheme.primary) : null,
                        ),
                        const SizedBox(height: 4),
                        SizedBox(
                          width: 60,
                          child: Text(
                            (a.displayName != null && a.displayName!.trim().isNotEmpty) ? a.displayName!.trim() : 'عضو',
                            maxLines: 1, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center,
                            style: const TextStyle(fontSize: 10, color: AppTheme.textMed),
                          ),
                        ),
                      ]),
                    );
                  }).toList(),
                ),
              ],
            ),
    );
  }
}

// ═══════════════════════════════════════════════
//  تنبيهات المؤسس لعضو متأخر: إرسال (حتى 3/دورة) + سجلّ التنبيهات السابقة
// ═══════════════════════════════════════════════
class _MemberReminders extends StatefulWidget {
  final GroupInfo group;
  final GroupAssignment member;
  const _MemberReminders({required this.group, required this.member});
  @override
  State<_MemberReminders> createState() => _MemberRemindersState();
}

class _MemberRemindersState extends State<_MemberReminders> {
  List<DateTime> _reminders = [];
  bool _loading = true;
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      _reminders = await GroupService.memberReminders(widget.group.id, widget.member.userId);
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _send() async {
    setState(() => _sending = true);
    try {
      await GroupService.remindMember(widget.group.id, widget.member.userId);
      await _load();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('أُرسل التنبيه')));
      }
    } catch (e) {
      final msg = '$e'.contains('reminder limit')
          ? 'بلغت الحد الأقصى (3 تنبيهات لهذا العضو في الدورة)'
          : 'تعذّر: $e';
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    }
    if (mounted) setState(() => _sending = false);
  }

  String _fmt(DateTime d) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${d.day}/${d.month}/${d.year} — ${two(d.hour)}:${two(d.minute)}';
  }

  @override
  Widget build(BuildContext context) {
    final count = _reminders.length;
    final canSend = count < 3 && !_sending;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF6E9),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.gold),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Icon(Icons.notifications_active_rounded, size: 18, color: AppTheme.gold),
          const SizedBox(width: 8),
          const Text('تذكير بإتمام القراءة', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
          const Spacer(),
          Text('$count / 3', style: const TextStyle(fontWeight: FontWeight.w700, color: Color(0xFF8A6D00))),
        ]),
        const SizedBox(height: 8),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: canSend ? _send : null,
            icon: _sending
                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.send_rounded, size: 18, color: Colors.white),
            label: Text(count >= 3 ? 'بلغ الحد الأقصى' : 'إرسال تنبيه',
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
            style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.gold, disabledBackgroundColor: const Color(0xFFCBB979)),
          ),
        ),
        if (_loading)
          const Padding(padding: EdgeInsets.only(top: 8),
              child: Text('...', style: TextStyle(color: AppTheme.textMed)))
        else if (_reminders.isNotEmpty) ...[
          const SizedBox(height: 8),
          const Text('التنبيهات السابقة:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppTheme.textMed)),
          const SizedBox(height: 4),
          ..._reminders.map((d) => Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Row(children: [
                  const Icon(Icons.schedule_rounded, size: 13, color: AppTheme.textLow),
                  const SizedBox(width: 6),
                  Text(_fmt(d), style: const TextStyle(fontSize: 12, color: AppTheme.textMed)),
                ]),
              )),
        ],
      ]),
    );
  }
}
