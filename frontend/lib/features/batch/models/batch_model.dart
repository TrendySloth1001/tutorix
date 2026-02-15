/// A batch within a coaching (e.g. "Class 10 Maths Morning Batch").
class BatchModel {
  final String id;
  final String? coachingId;
  final String name;
  final String? subject;
  final String? description;
  final String? startTime;
  final String? endTime;
  final List<String> days;
  final int maxStudents;
  final String status;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  // Counts
  final int memberCount;
  final int noteCount;
  final int noticeCount;

  // Teacher info (first teacher from list query)
  final BatchTeacherInfo? teacher;

  const BatchModel({
    required this.id,
    this.coachingId,
    required this.name,
    this.subject,
    this.description,
    this.startTime,
    this.endTime,
    this.days = const [],
    this.maxStudents = 0,
    this.status = 'active',
    this.createdAt,
    this.updatedAt,
    this.memberCount = 0,
    this.noteCount = 0,
    this.noticeCount = 0,
    this.teacher,
  });

  factory BatchModel.fromJson(Map<String, dynamic> json) {
    final count = json['_count'] as Map<String, dynamic>?;
    final membersList = json['members'] as List<dynamic>?;

    // Extract first teacher from members list
    BatchTeacherInfo? teacher;
    if (membersList != null && membersList.isNotEmpty) {
      final first = membersList.first as Map<String, dynamic>;
      final member = first['member'] as Map<String, dynamic>?;
      final user = member?['user'] as Map<String, dynamic>?;
      if (user != null) {
        teacher = BatchTeacherInfo(
          memberId: member?['id'] as String? ?? '',
          userId: user['id'] as String? ?? '',
          name: user['name'] as String?,
          picture: user['picture'] as String?,
        );
      }
    }

    return BatchModel(
      id: json['id'] as String,
      coachingId: json['coachingId'] as String?,
      name: json['name'] as String,
      subject: json['subject'] as String?,
      description: json['description'] as String?,
      startTime: json['startTime'] as String?,
      endTime: json['endTime'] as String?,
      days: (json['days'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          [],
      maxStudents: json['maxStudents'] as int? ?? 0,
      status: json['status'] as String? ?? 'active',
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'] as String)
          : null,
      updatedAt: json['updatedAt'] != null
          ? DateTime.parse(json['updatedAt'] as String)
          : null,
      memberCount: count?['members'] as int? ?? 0,
      noteCount: count?['notes'] as int? ?? 0,
      noticeCount: count?['notices'] as int? ?? 0,
      teacher: teacher,
    );
  }

  /// Human-readable schedule, e.g. "Mon, Wed, Fri • 09:00 – 10:30"
  String get scheduleText {
    final dayStr = days.map(shortDay).join(', ');
    if (startTime != null && endTime != null) {
      return '$dayStr • $startTime – $endTime';
    }
    if (dayStr.isNotEmpty) return dayStr;
    return 'No schedule set';
  }

  /// Capacity label, e.g. "12 / 30 students" or "12 students"
  String capacityText(int current) {
    if (maxStudents > 0) return '$current / $maxStudents students';
    return '$current students';
  }

  bool get isActive => status == 'active';

  static String shortDay(String d) {
    const map = {
      'MON': 'Mon',
      'TUE': 'Tue',
      'WED': 'Wed',
      'THU': 'Thu',
      'FRI': 'Fri',
      'SAT': 'Sat',
      'SUN': 'Sun',
    };
    return map[d.toUpperCase()] ?? d;
  }
}

class BatchTeacherInfo {
  final String memberId;
  final String userId;
  final String? name;
  final String? picture;

  const BatchTeacherInfo({
    required this.memberId,
    required this.userId,
    this.name,
    this.picture,
  });
}
