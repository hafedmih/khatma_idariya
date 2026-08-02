import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/account_models.dart';

// ═══════════════════════════════════════════════
//  مجموعات الختمة: إنشاء/انضمام/نصيب كل عضو اليوم
// ═══════════════════════════════════════════════
class GroupService {
  static SupabaseClient get _sb => Supabase.instance.client;

  static String _d(DateTime? d) {
    final x = d ?? DateTime.now();
    return '${x.year.toString().padLeft(4, '0')}-'
        '${x.month.toString().padLeft(2, '0')}-'
        '${x.day.toString().padLeft(2, '0')}';
  }

  static Future<String> createGroup({
    required String name,
    String mode = 'custom',
    int totalDays = 21,
    DateTime? startDate,
  }) async {
    final res = await _sb.rpc('create_group', params: {
      'p_name': name,
      'p_mode': mode,
      'p_total_days': totalDays,
      'p_start': _d(startDate),
    });
    return res as String;
  }

  static Future<String> joinGroup(String code) async {
    final res = await _sb.rpc('join_group', params: {'p_code': code.trim()});
    return res as String;
  }

  // توليد رمز دعوة جديد (للمالك) — يُرجع الرمز الجديد
  static Future<String> regenerateCode(String groupId) async {
    final res = await _sb.rpc('regenerate_group_code', params: {'p_group': groupId});
    return res as String;
  }

  // تغيير طور الانضمام (للمالك): invite | open | closed
  static Future<void> setJoinMode(String groupId, String mode) =>
      _sb.rpc('set_group_join_mode', params: {'p_group': groupId, 'p_mode': mode});

  // استخراج رمز الدعوة من محتوى QR (يقبل الرمز المجرّد أو رابطاً يحوي code=)
  static String extractCode(String raw) {
    final uri = Uri.tryParse(raw.trim());
    final q = uri?.queryParameters['code'];
    if (q != null && q.isNotEmpty) return q.trim();
    return raw.trim();
  }

  static Future<List<GroupInfo>> myGroups() async {
    final rows = await _sb
        .from('groups')
        .select('*, group_members(count)')
        .order('created_at', ascending: false);
    return (rows as List)
        .map((e) => GroupInfo.fromMap(e as Map<String, dynamic>))
        .toList();
  }

  static Future<GroupInfo?> group(String id) async {
    final m = await _sb.from('groups').select().eq('id', id).maybeSingle();
    return m == null ? null : GroupInfo.fromMap(m);
  }

  static Future<GroupProgress?> progress(String groupId) async {
    final m = await _sb
        .from('v_group_progress')
        .select()
        .eq('group_id', groupId)
        .maybeSingle();
    return m == null ? null : GroupProgress.fromMap(m);
  }

  // نصيب كل عضو من أحزاب اليوم
  static Future<List<GroupAssignment>> todayAssignments(String groupId,
      {DateTime? today}) async {
    final res = await _sb.rpc('group_today_assignments',
        params: {'p_group': groupId, 'p_today': _d(today)});
    return ((res as List?) ?? const [])
        .map((e) => GroupAssignment.fromMap(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  // الأحزاب المقروءة في المجموعة (حزب → معرّف العضو الذي قرأه)
  static Future<Map<int, String>> reads(String groupId) async {
    final rows =
        await _sb.from('group_reads').select('hizb, user_id').eq('group_id', groupId);
    return {
      for (final r in (rows as List))
        (r['hizb'] as num).toInt(): r['user_id'] as String
    };
  }

  static Future<Map<String, dynamic>> recordRead(String groupId, int hizb) async {
    final res = await _sb.rpc('record_group_hizb_read',
        params: {'p_group': groupId, 'p_hizb': hizb});
    return Map<String, dynamic>.from(res as Map);
  }

  // ── توزيع الأحزاب ──
  // خريطة: رقم الحزب → معرّف العضو (غير المُسندة لا تظهر = في المجمّع)
  static Future<Map<int, String>> assignmentsMap(String groupId) async {
    final res = await _sb.rpc('group_assignments_map', params: {'p_group': groupId});
    final out = <int, String>{};
    for (final r in ((res as List?) ?? const [])) {
      final m = Map<String, dynamic>.from(r as Map);
      out[(m['hizb'] as num).toInt()] = m['user_id'] as String;
    }
    return out;
  }

  static Future<void> setAssignment(String groupId, int hizb, String? userId) =>
      _sb.rpc('set_hizb_assignment',
          params: {'p_group': groupId, 'p_hizb': hizb, 'p_user': userId});

  static Future<void> autoDistribute(String groupId) =>
      _sb.rpc('auto_distribute_group', params: {'p_group': groupId});

  // العضو يُسند لنفسه حزباً غير مُسند (بحد أقصى للدورة)
  static Future<void> selfAssign(String groupId, int hizb) =>
      _sb.rpc('self_assign_hizb', params: {'p_group': groupId, 'p_hizb': hizb});

  // المؤسس يرسل تنبيهاً لعضو (حد 3 لكل عضو في الدورة) — يُرجع العدد الجديد
  static Future<int> remindMember(String groupId, String userId) async {
    final res = await _sb.rpc('remind_member', params: {'p_group': groupId, 'p_user': userId});
    return (res as num?)?.toInt() ?? 0;
  }

  // تنبيهات عضو في الدورة الحالية (تواريخ)
  static Future<List<DateTime>> memberReminders(String groupId, String userId) async {
    final res = await _sb.rpc('member_reminders', params: {'p_group': groupId, 'p_user': userId});
    return ((res as List?) ?? const [])
        .map((e) => DateTime.parse(e as String).toLocal())
        .toList();
  }

  // تحديد عضو كغائب: تُحرَّر أحزابه غير المقروءة إلى المجمّع — يُرجع عدد الأحزاب المحرَّرة
  static Future<int> markAbsent(String groupId, String userId) async {
    final res = await _sb.rpc('mark_member_absent',
        params: {'p_group': groupId, 'p_user': userId});
    return (res as num?)?.toInt() ?? 0;
  }

  // تعيين/إلغاء رتبة احتياطي لعضو (rank = 1..3 أو null للإلغاء)
  static Future<void> setReserve(String groupId, String userId, int? rank) =>
      _sb.rpc('set_group_reserve',
          params: {'p_group': groupId, 'p_user': userId, 'p_rank': rank});

  // ── الدورات ──
  static Future<GroupCycle?> activeCycle(String groupId) async {
    final res = await _sb.rpc('group_active_cycle', params: {'p_group': groupId});
    final list = (res as List?) ?? const [];
    if (list.isEmpty) return null;
    return GroupCycle.fromMap(Map<String, dynamic>.from(list.first as Map));
  }

  // mode: 'rotate' (تدوير مع حد أقصى) أو 'keep' (الحفاظ على نفس التوزيع)
  static Future<void> startNewCycle(String groupId,
          {DateTime? start, DateTime? end, int? maxPerMember, String mode = 'rotate'}) =>
      _sb.rpc('start_new_cycle', params: {
        'p_group': groupId,
        'p_start': _d(start),
        'p_end': end == null ? null : _d(end),
        'p_max': maxPerMember,
        'p_mode': mode,
      });

  // اعتبار الدورة قاربت النهاية (أو إلغاء ذلك) — للمالك
  static Future<void> setCycleNearEnd(String groupId, bool value) =>
      _sb.rpc('set_cycle_near_end', params: {'p_group': groupId, 'p_value': value});

  static Future<List<GroupCycle>> archivedCycles(String groupId) async {
    final res = await _sb.rpc('group_archived_cycles', params: {'p_group': groupId});
    return ((res as List?) ?? const [])
        .map((e) => GroupCycle.fromMap(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  // حذف عضو من المجموعة (للمالك)
  static Future<void> removeMember(String groupId, String userId) =>
      _sb.rpc('remove_group_member', params: {'p_group': groupId, 'p_user': userId});

  static Future<void> leave(String groupId) =>
      _sb.rpc('leave_group', params: {'p_group': groupId});

  // ── الإشراف على المحتوى (متطلّب مراجعة Apple) ──
  // الإبلاغ عن عضو مسيء داخل مجموعة
  static Future<void> reportMember(String groupId, String userId, String reason) =>
      _sb.rpc('report_member', params: {
        'p_group': groupId,
        'p_reported': userId,
        'p_reason': reason,
      });

  // حظر مستخدم — يُخفى محتواه عن المستخدم الحالي
  static Future<void> blockUser(String userId) =>
      _sb.rpc('block_user', params: {'p_blocked': userId});

  static Future<void> unblockUser(String userId) =>
      _sb.rpc('unblock_user', params: {'p_blocked': userId});

  // قائمة معرّفات المستخدمين المحظورين من طرف المستخدم الحالي
  static Future<Set<String>> blockedIds() async {
    final res = await _sb.rpc('my_blocked_users');
    if (res is List) {
      return res.map((e) => (e is Map ? e['blocked_id'] : e).toString()).toSet();
    }
    return <String>{};
  }

  // قائمة المحظورين مع الاسم والصورة (لشاشة إدارة الحظر)
  static Future<List<BlockedUser>> blockedUsers() async {
    final res = await _sb.rpc('my_blocked_users');
    if (res is List) {
      return res
          .whereType<Map>()
          .map((m) => BlockedUser(
                id: m['blocked_id'].toString(),
                displayName: m['display_name'] as String?,
                avatarUrl: m['avatar_url'] as String?,
              ))
          .toList();
    }
    return <BlockedUser>[];
  }
}

// مستخدم محظور
class BlockedUser {
  final String  id;
  final String? displayName;
  final String? avatarUrl;
  const BlockedUser({required this.id, this.displayName, this.avatarUrl});
}
