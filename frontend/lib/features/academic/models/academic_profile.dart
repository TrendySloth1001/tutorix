/// User's academic profile
class AcademicProfile {
  final String id;
  final String userId;
  final String? schoolName;
  final String? board;
  final String? classId;
  final String? stream;
  final List<String> subjects;
  final List<String> competitiveExams;
  final int? targetYear;
  final String status; // PENDING, COMPLETED, REMIND_LATER
  final DateTime? remindAt;
  final DateTime? completedAt;

  const AcademicProfile({
    required this.id,
    required this.userId,
    this.schoolName,
    this.board,
    this.classId,
    this.stream,
    this.subjects = const [],
    this.competitiveExams = const [],
    this.targetYear,
    required this.status,
    this.remindAt,
    this.completedAt,
  });

  factory AcademicProfile.fromJson(Map<String, dynamic> json) {
    return AcademicProfile(
      id: json['id'] as String,
      userId: json['userId'] as String,
      schoolName: json['schoolName'] as String?,
      board: json['board'] as String?,
      classId: json['classId'] as String?,
      stream: json['stream'] as String?,
      subjects:
          (json['subjects'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          [],
      competitiveExams:
          (json['competitiveExams'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          [],
      targetYear: json['targetYear'] as int?,
      status: json['status'] as String? ?? 'PENDING',
      remindAt: json['remindAt'] != null
          ? DateTime.parse(json['remindAt'] as String)
          : null,
      completedAt: json['completedAt'] != null
          ? DateTime.parse(json['completedAt'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'schoolName': schoolName,
      'board': board,
      'classId': classId,
      'stream': stream,
      'subjects': subjects,
      'competitiveExams': competitiveExams,
      'targetYear': targetYear,
    };
  }

  bool get isCompleted => status == 'COMPLETED';
  bool get needsReminder =>
      status == 'REMIND_LATER' &&
      remindAt != null &&
      DateTime.now().isAfter(remindAt!);
}

/// Response from onboarding status check
class OnboardingStatus {
  final bool needsOnboarding;
  final String reason;
  final DateTime? remindAt;
  final AcademicProfile? profile;

  const OnboardingStatus({
    required this.needsOnboarding,
    required this.reason,
    this.remindAt,
    this.profile,
  });

  factory OnboardingStatus.fromJson(Map<String, dynamic> json) {
    return OnboardingStatus(
      needsOnboarding: json['needsOnboarding'] as bool,
      reason: json['reason'] as String,
      remindAt: json['remindAt'] != null
          ? DateTime.parse(json['remindAt'] as String)
          : null,
      profile: json['profile'] != null
          ? AcademicProfile.fromJson(json['profile'])
          : null,
    );
  }
}
