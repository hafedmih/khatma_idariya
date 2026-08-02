import 'package:supabase_flutter/supabase_flutter.dart';

// ═══════════════════════════════════════════════
//  سجل الورد اليومي (الختمة الإدارية) + المشاركون اليوم
// ═══════════════════════════════════════════════
class WirdService {
  static SupabaseClient get _sb => Supabase.instance.client;

  static String _d(DateTime? d) {
    final x = d ?? DateTime.now();
    return '${x.year.toString().padLeft(4, '0')}-'
        '${x.month.toString().padLeft(2, '0')}-'
        '${x.day.toString().padLeft(2, '0')}';
  }

  static String hizbItem(int n) => 'hizb:$n';
  static const String kahfItem = 'kahf';

  // العناصر المقروءة اليوم للمستخدم الحالي
  static Future<Set<String>> today({DateTime? date}) async {
    final res = await _sb.rpc('wird_today', params: {'p_date': _d(date)});
    return ((res as List?) ?? const []).map((e) => e as String).toSet();
  }

  static Future<void> record(String item, {DateTime? date}) =>
      _sb.rpc('record_wird', params: {'p_item': item, 'p_date': _d(date)});

  static Future<void> unrecord(String item, {DateTime? date}) =>
      _sb.rpc('unrecord_wird', params: {'p_item': item, 'p_date': _d(date)});

  // عدد المشاركين اليوم (يعمل دون تسجيل دخول)
  static Future<int> todaysParticipants({DateTime? date}) async {
    final res = await _sb.rpc('todays_participants', params: {'p_date': _d(date)});
    return (res as num?)?.toInt() ?? 0;
  }

  // عدد المشاركين في ختمة الإدارة لكل فترة [بداية, نهاية] (بنفس ترتيب المُدخل)
  static Future<List<int>> khatmaPeriodParticipants(List<List<DateTime>> ranges) async {
    if (ranges.isEmpty) return const [];
    final payload = ranges.map((r) => [_d(r[0]), _d(r[1])]).toList();
    final res = await _sb.rpc('khatma_period_participants', params: {'p_ranges': payload});
    return ((res as List?) ?? const []).map((e) => (e as num).toInt()).toList();
  }

  // المشاركون اليوم مفصّلين: (idara) ختمة الإدارة و (groups) المجموعات
  static Future<({int idara, int groups})> todaysParticipantsSplit({DateTime? date}) async {
    final res = await _sb.rpc('todays_participants_split', params: {'p_date': _d(date)});
    final m = Map<String, dynamic>.from(res as Map);
    return (
      idara: (m['idara'] as num?)?.toInt() ?? 0,
      groups: (m['groups'] as num?)?.toInt() ?? 0,
    );
  }
}
