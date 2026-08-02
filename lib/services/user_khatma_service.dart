import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/account_models.dart';

// ═══════════════════════════════════════════════
//  ختمة المستخدم: إنشاء/تتبّع/ورد اليوم/التقدّم
// ═══════════════════════════════════════════════
class UserKhatmaService {
  static SupabaseClient get _sb => Supabase.instance.client;

  static String _d(DateTime? d) {
    final x = d ?? DateTime.now();
    return '${x.year.toString().padLeft(4, '0')}-'
        '${x.month.toString().padLeft(2, '0')}-'
        '${x.day.toString().padLeft(2, '0')}';
  }

  // إنشاء ختمة جديدة (رسمية idariya أو مخصّصة custom)
  static Future<UserKhatma> createKhatma({
    required String mode,
    int totalDays = 21,
    DateTime? startDate,
    String? title,
  }) async {
    final uid = _sb.auth.currentUser!.id;
    final row = await _sb.from('khatmas').insert({
      'user_id': uid,
      'mode': mode,
      'total_days': totalDays,
      'start_date': _d(startDate),
      if (title != null) 'title': title,
    }).select().single();
    return UserKhatma.fromMap(row);
  }

  static Future<List<UserKhatma>> myKhatmas() async {
    final uid = _sb.auth.currentUser?.id;
    if (uid == null) return [];
    final rows = await _sb
        .from('khatmas')
        .select()
        .eq('user_id', uid)
        .order('created_at', ascending: false);
    return (rows as List)
        .map((e) => UserKhatma.fromMap(e as Map<String, dynamic>))
        .toList();
  }

  static Future<UserKhatma?> activeKhatma() async {
    final uid = _sb.auth.currentUser?.id;
    if (uid == null) return null;
    final m = await _sb
        .from('khatmas')
        .select()
        .eq('user_id', uid)
        .eq('status', 'active')
        .order('created_at', ascending: false)
        .limit(1)
        .maybeSingle();
    return m == null ? null : UserKhatma.fromMap(m);
  }

  static Future<void> abandon(String khatmaId) =>
      _sb.from('khatmas').update({'status': 'abandoned'}).eq('id', khatmaId);

  // ورد اليوم (يفرّق حسب الوضع في قاعدة البيانات)
  static Future<List<int>> todayHizbs(String khatmaId, {DateTime? today}) async {
    final res = await _sb.rpc('khatma_today_hizbs',
        params: {'p_khatma': khatmaId, 'p_today': _d(today)});
    return ((res as List?) ?? const []).map((e) => (e as num).toInt()).toList();
  }

  // الأحزاب المقروءة في هذه الختمة
  static Future<Set<int>> readHizbs(String khatmaId) async {
    final rows =
        await _sb.from('khatma_reads').select('hizb').eq('khatma_id', khatmaId);
    return (rows as List).map((e) => (e['hizb'] as num).toInt()).toSet();
  }

  // تسجيل قراءة حزب (نقاط + streak + إنجازات + إكمال) → يرجع {hizbs_read, percent, ...}
  static Future<Map<String, dynamic>> recordRead(String khatmaId, int hizb) async {
    final res = await _sb
        .rpc('record_hizb_read', params: {'p_khatma': khatmaId, 'p_hizb': hizb});
    return Map<String, dynamic>.from(res as Map);
  }

  static Future<void> unrecordRead(String khatmaId, int hizb) => _sb
      .rpc('unrecord_hizb_read', params: {'p_khatma': khatmaId, 'p_hizb': hizb});

  static Future<KhatmaProgress?> progress(String khatmaId) async {
    final m = await _sb
        .from('v_khatma_progress')
        .select()
        .eq('khatma_id', khatmaId)
        .maybeSingle();
    return m == null ? null : KhatmaProgress.fromMap(m);
  }
}
