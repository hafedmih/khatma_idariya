// ═══════════════════════════════════════════════
//  نماذج بيانات المستخدم/الختمة/المجموعة (Supabase)
// ═══════════════════════════════════════════════

class Profile {
  final String id;
  final String? displayName;
  final String? avatarUrl;
  final int totalPoints;
  final int currentLevel;
  final int currentStreak;
  final int longestStreak;

  const Profile({
    required this.id,
    this.displayName,
    this.avatarUrl,
    this.totalPoints = 0,
    this.currentLevel = 1,
    this.currentStreak = 0,
    this.longestStreak = 0,
  });

  factory Profile.fromMap(Map<String, dynamic> m) => Profile(
        id: m['id'] as String,
        displayName: m['display_name'] as String?,
        avatarUrl: m['avatar_url'] as String?,
        totalPoints: (m['total_points'] as num?)?.toInt() ?? 0,
        currentLevel: (m['current_level'] as num?)?.toInt() ?? 1,
        currentStreak: (m['current_streak'] as num?)?.toInt() ?? 0,
        longestStreak: (m['longest_streak'] as num?)?.toInt() ?? 0,
      );
}

class UserStats {
  final int completedKhatmas;
  final int activeDays;
  final int totalHizbsRead;
  final int totalPoints;
  final int currentLevel;
  final int currentStreak;
  final int longestStreak;

  const UserStats({
    this.completedKhatmas = 0,
    this.activeDays = 0,
    this.totalHizbsRead = 0,
    this.totalPoints = 0,
    this.currentLevel = 1,
    this.currentStreak = 0,
    this.longestStreak = 0,
  });

  factory UserStats.fromMap(Map<String, dynamic> m) => UserStats(
        completedKhatmas: (m['completed_khatmas'] as num?)?.toInt() ?? 0,
        activeDays: (m['active_days'] as num?)?.toInt() ?? 0,
        totalHizbsRead: (m['total_hizbs_read'] as num?)?.toInt() ?? 0,
        totalPoints: (m['total_points'] as num?)?.toInt() ?? 0,
        currentLevel: (m['current_level'] as num?)?.toInt() ?? 1,
        currentStreak: (m['current_streak'] as num?)?.toInt() ?? 0,
        longestStreak: (m['longest_streak'] as num?)?.toInt() ?? 0,
      );
}

class UserKhatma {
  final String id;
  final String? title;
  final String mode; // idariya | custom
  final int totalDays;
  final DateTime startDate;
  final String status; // active | completed | abandoned

  const UserKhatma({
    required this.id,
    this.title,
    required this.mode,
    required this.totalDays,
    required this.startDate,
    required this.status,
  });

  bool get isIdariya => mode == 'idariya';

  factory UserKhatma.fromMap(Map<String, dynamic> m) => UserKhatma(
        id: m['id'] as String,
        title: m['title'] as String?,
        mode: (m['mode'] as String?) ?? 'custom',
        totalDays: (m['total_days'] as num?)?.toInt() ?? 21,
        startDate: DateTime.parse(m['start_date'] as String),
        status: (m['status'] as String?) ?? 'active',
      );
}

class KhatmaProgress {
  final int hizbsRead;
  final double percent;
  final int dayIndex;

  const KhatmaProgress({this.hizbsRead = 0, this.percent = 0, this.dayIndex = 1});

  factory KhatmaProgress.fromMap(Map<String, dynamic> m) => KhatmaProgress(
        hizbsRead: (m['hizbs_read'] as num?)?.toInt() ?? 0,
        percent: (m['percent'] as num?)?.toDouble() ?? 0,
        dayIndex: (m['day_index'] as num?)?.toInt() ?? 1,
      );
}

class AchievementInfo {
  final String code;
  final String title;
  final String? description;
  final String? icon;
  final int points;
  final bool earned;

  const AchievementInfo({
    required this.code,
    required this.title,
    this.description,
    this.icon,
    this.points = 0,
    this.earned = false,
  });
}

class GroupInfo {
  final String id;
  final String name;
  final String? inviteCode;
  final String? ownerId;
  final String mode;
  final int totalDays;
  final DateTime startDate;
  final String status;
  final int memberCount;
  final String joinMode; // invite | open | closed

  const GroupInfo({
    required this.id,
    required this.name,
    this.inviteCode,
    this.ownerId,
    required this.mode,
    required this.totalDays,
    required this.startDate,
    required this.status,
    this.memberCount = 0,
    this.joinMode = 'invite',
  });

  static int _countFrom(dynamic gm) {
    if (gm is List && gm.isNotEmpty && gm.first is Map) {
      return ((gm.first as Map)['count'] as num?)?.toInt() ?? 0;
    }
    return 0;
  }

  factory GroupInfo.fromMap(Map<String, dynamic> m) => GroupInfo(
        id: m['id'] as String,
        name: (m['name'] as String?) ?? '',
        inviteCode: m['invite_code'] as String?,
        ownerId: m['owner_id'] as String?,
        mode: (m['mode'] as String?) ?? 'custom',
        totalDays: (m['total_days'] as num?)?.toInt() ?? 21,
        startDate: DateTime.parse(m['start_date'] as String),
        status: (m['status'] as String?) ?? 'active',
        memberCount: _countFrom(m['group_members']),
        joinMode: (m['join_mode'] as String?) ?? 'invite',
      );
}

class GroupAssignment {
  final String userId;
  final String? displayName;
  final String? avatarUrl;
  final List<int> hizbs;
  final int level;
  final int streak;
  final int? reserveRank; // رتبة الاحتياطي (1..3) أو null

  const GroupAssignment({
    required this.userId,
    this.displayName,
    this.avatarUrl,
    this.hizbs = const [],
    this.level = 1,
    this.streak = 0,
    this.reserveRank,
  });

  factory GroupAssignment.fromMap(Map<String, dynamic> m) => GroupAssignment(
        userId: m['user_id'] as String,
        displayName: m['display_name'] as String?,
        avatarUrl: m['avatar_url'] as String?,
        hizbs: ((m['hizbs'] as List?) ?? const [])
            .map((e) => (e as num).toInt())
            .toList(),
        level: (m['level'] as num?)?.toInt() ?? 1,
        streak: (m['streak'] as num?)?.toInt() ?? 0,
        reserveRank: (m['reserve_rank'] as num?)?.toInt(),
      );
}

class GroupCycle {
  final String id;
  final int cycleNo;
  final DateTime startDate;
  final DateTime? endDate;
  final int hizbsRead;
  final int members;
  final int? maxPerMember;
  final bool nearEnd;
  // أوقات دقيقة (لحساب المدة بالأيام والساعات) — متاحة للدورات المؤرشفة
  final DateTime? startedAt;
  final DateTime? endedAt;

  const GroupCycle({
    required this.id,
    required this.cycleNo,
    required this.startDate,
    this.endDate,
    this.hizbsRead = 0,
    this.members = 0,
    this.maxPerMember,
    this.nearEnd = false,
    this.startedAt,
    this.endedAt,
  });

  factory GroupCycle.fromMap(Map<String, dynamic> m) => GroupCycle(
        id: m['id'] as String,
        cycleNo: (m['cycle_no'] as num?)?.toInt() ?? 1,
        startDate: DateTime.parse(m['start_date'] as String),
        endDate: m['end_date'] != null ? DateTime.parse(m['end_date'] as String) : null,
        hizbsRead: (m['hizbs_read'] as num?)?.toInt() ?? 0,
        members: (m['members'] as num?)?.toInt() ?? 0,
        maxPerMember: (m['max_per_member'] as num?)?.toInt(),
        nearEnd: (m['near_end'] as bool?) ?? false,
        startedAt: m['created_at'] != null ? DateTime.parse(m['created_at'] as String) : null,
        endedAt: m['ended_at'] != null ? DateTime.parse(m['ended_at'] as String) : null,
      );

  /// مدة الدورة نصّياً (أيام وساعات) — أو null إن تعذّر الحساب
  String? get durationLabel {
    Duration? d;
    if (startedAt != null && endedAt != null) {
      d = endedAt!.difference(startedAt!);
    } else if (endDate != null) {
      d = endDate!.difference(startDate); // بديل: فرق التواريخ (أيام فقط)
    }
    if (d == null || d.inSeconds <= 0) return null;
    final days = d.inDays;
    final hours = d.inHours % 24;
    final mins = d.inMinutes % 60;
    if (days > 0 && hours > 0) return '$days ${_dayWord(days)} و$hours ${_hourWord(hours)}';
    if (days > 0) return '$days ${_dayWord(days)}';
    if (hours > 0) return '$hours ${_hourWord(hours)}';
    if (mins > 0) return '$mins ${_minWord(mins)}';
    return 'أقل من دقيقة';
  }

  static String _dayWord(int n) => n == 1 ? 'يوم' : (n == 2 ? 'يومان' : 'يوماً');
  static String _hourWord(int n) => n == 1 ? 'ساعة' : (n == 2 ? 'ساعتان' : 'ساعات');
  static String _minWord(int n) => n == 1 ? 'دقيقة' : (n == 2 ? 'دقيقتان' : 'دقائق');
}

class GroupProgress {
  final int members;
  final int hizbsRead;
  final double percent;

  const GroupProgress({this.members = 0, this.hizbsRead = 0, this.percent = 0});

  factory GroupProgress.fromMap(Map<String, dynamic> m) => GroupProgress(
        members: (m['members'] as num?)?.toInt() ?? 0,
        hizbsRead: (m['hizbs_read'] as num?)?.toInt() ?? 0,
        percent: (m['percent'] as num?)?.toDouble() ?? 0,
      );
}
