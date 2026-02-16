/// An assessment (quiz / test / practice) within a batch.
class AssessmentModel {
  final String id;
  final String title;
  final String? description;
  final String type; // QUIZ, TEST, PRACTICE
  final int? durationMinutes;
  final DateTime? startTime;
  final DateTime? endTime;
  final int totalMarks;
  final int? passingMarks;
  final String status; // DRAFT, PUBLISHED, CLOSED
  final int maxAttempts;
  final double negativeMarking;
  final bool shuffleQuestions;
  final bool shuffleOptions;
  final String showResultAfter; // SUBMIT, MANUAL
  final DateTime? createdAt;
  final CreatorInfo? createdBy;
  final int questionCount;
  final int attemptCount;
  final List<QuestionModel> questions;
  final List<AttemptSummary> myAttempts;

  const AssessmentModel({
    required this.id,
    required this.title,
    this.description,
    this.type = 'QUIZ',
    this.durationMinutes,
    this.startTime,
    this.endTime,
    this.totalMarks = 0,
    this.passingMarks,
    this.status = 'DRAFT',
    this.maxAttempts = 1,
    this.negativeMarking = 0,
    this.shuffleQuestions = false,
    this.shuffleOptions = false,
    this.showResultAfter = 'SUBMIT',
    this.createdAt,
    this.createdBy,
    this.questionCount = 0,
    this.attemptCount = 0,
    this.questions = const [],
    this.myAttempts = const [],
  });

  factory AssessmentModel.fromJson(Map<String, dynamic> json) {
    final count = json['_count'] as Map<String, dynamic>?;
    final qList = json['questions'] as List<dynamic>?;
    final aList = json['myAttempts'] as List<dynamic>?;

    return AssessmentModel(
      id: json['id'] as String,
      title: json['title'] as String,
      description: json['description'] as String?,
      type: json['type'] as String? ?? 'QUIZ',
      durationMinutes: json['durationMinutes'] as int?,
      startTime: json['startTime'] != null
          ? DateTime.parse(json['startTime'] as String)
          : null,
      endTime: json['endTime'] != null
          ? DateTime.parse(json['endTime'] as String)
          : null,
      totalMarks: json['totalMarks'] as int? ?? 0,
      passingMarks: json['passingMarks'] as int?,
      status: json['status'] as String? ?? 'DRAFT',
      maxAttempts: json['maxAttempts'] as int? ?? 1,
      negativeMarking: (json['negativeMarking'] as num?)?.toDouble() ?? 0,
      shuffleQuestions: json['shuffleQuestions'] as bool? ?? false,
      shuffleOptions: json['shuffleOptions'] as bool? ?? false,
      showResultAfter: json['showResultAfter'] as String? ?? 'SUBMIT',
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'] as String)
          : null,
      createdBy: json['createdBy'] != null
          ? CreatorInfo.fromJson(json['createdBy'] as Map<String, dynamic>)
          : null,
      questionCount: count?['questions'] as int? ?? 0,
      attemptCount: count?['attempts'] as int? ?? 0,
      questions: qList
              ?.map((e) =>
                  QuestionModel.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      myAttempts: aList
              ?.map((e) =>
                  AttemptSummary.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }

  bool get isPublished => status == 'PUBLISHED';
  bool get isClosed => status == 'CLOSED';
  bool get isDraft => status == 'DRAFT';

  bool get isAvailable {
    if (!isPublished) return false;
    final now = DateTime.now();
    if (startTime != null && now.isBefore(startTime!)) return false;
    if (endTime != null && now.isAfter(endTime!)) return false;
    return true;
  }

  bool get hasTimeLimit => durationMinutes != null && durationMinutes! > 0;

  /// Whether the student can still attempt this assessment.
  bool get canAttempt {
    if (!isAvailable) return false;
    final submitted =
        myAttempts.where((a) => a.status == 'SUBMITTED').length;
    return submitted < maxAttempts;
  }

  /// Best attempt score, if any.
  AttemptSummary? get bestAttempt {
    final submitted =
        myAttempts.where((a) => a.status == 'SUBMITTED').toList();
    if (submitted.isEmpty) return null;
    submitted.sort(
        (a, b) => (b.percentage ?? 0).compareTo(a.percentage ?? 0));
    return submitted.first;
  }
}

/// A single question in an assessment.
class QuestionModel {
  final String id;
  final String type; // MCQ, MSQ, NAT
  final String question;
  final String? imageUrl;
  final List<OptionModel> options;
  final dynamic correctAnswer; // MCQ: string, MSQ: list, NAT: {value,tolerance}
  final int marks;
  final int orderIndex;
  final String? explanation;

  const QuestionModel({
    required this.id,
    required this.type,
    required this.question,
    this.imageUrl,
    this.options = const [],
    this.correctAnswer,
    this.marks = 1,
    this.orderIndex = 0,
    this.explanation,
  });

  factory QuestionModel.fromJson(Map<String, dynamic> json) {
    final opts = json['options'] as List<dynamic>?;
    return QuestionModel(
      id: json['id'] as String,
      type: json['type'] as String,
      question: json['question'] as String,
      imageUrl: json['imageUrl'] as String?,
      options: opts
              ?.map((e) => OptionModel.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      correctAnswer: json['correctAnswer'],
      marks: json['marks'] as int? ?? 1,
      orderIndex: json['orderIndex'] as int? ?? 0,
      explanation: json['explanation'] as String?,
    );
  }

  bool get isMCQ => type == 'MCQ';
  bool get isMSQ => type == 'MSQ';
  bool get isNAT => type == 'NAT';
}

/// An option for MCQ / MSQ questions.
class OptionModel {
  final String id;
  final String text;
  final String? imageUrl;

  const OptionModel({
    required this.id,
    required this.text,
    this.imageUrl,
  });

  factory OptionModel.fromJson(Map<String, dynamic> json) {
    return OptionModel(
      id: json['id'] as String,
      text: json['text'] as String,
      imageUrl: json['imageUrl'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'text': text,
        if (imageUrl != null) 'imageUrl': imageUrl,
      };
}

/// Attempt summary attached to assessment list items.
class AttemptSummary {
  final String? assessmentId;
  final String status;
  final double? totalScore;
  final double? percentage;
  final DateTime? submittedAt;

  const AttemptSummary({
    this.assessmentId,
    this.status = 'IN_PROGRESS',
    this.totalScore,
    this.percentage,
    this.submittedAt,
  });

  factory AttemptSummary.fromJson(Map<String, dynamic> json) {
    return AttemptSummary(
      assessmentId: json['assessmentId'] as String?,
      status: json['status'] as String? ?? 'IN_PROGRESS',
      totalScore: (json['totalScore'] as num?)?.toDouble(),
      percentage: (json['percentage'] as num?)?.toDouble(),
      submittedAt: json['submittedAt'] != null
          ? DateTime.parse(json['submittedAt'] as String)
          : null,
    );
  }
}

/// Full attempt result with answers.
class AttemptResultModel {
  final String id;
  final DateTime? startedAt;
  final DateTime? submittedAt;
  final double totalScore;
  final double maxScore;
  final double percentage;
  final int correctCount;
  final int wrongCount;
  final int skippedCount;
  final String status;
  final CreatorInfo? user;
  final List<AnswerModel> answers;
  final AssessmentResultInfo? assessment;

  const AttemptResultModel({
    required this.id,
    this.startedAt,
    this.submittedAt,
    this.totalScore = 0,
    this.maxScore = 0,
    this.percentage = 0,
    this.correctCount = 0,
    this.wrongCount = 0,
    this.skippedCount = 0,
    this.status = 'SUBMITTED',
    this.user,
    this.answers = const [],
    this.assessment,
  });

  factory AttemptResultModel.fromJson(Map<String, dynamic> json) {
    final aList = json['answers'] as List<dynamic>?;
    return AttemptResultModel(
      id: json['id'] as String,
      startedAt: json['startedAt'] != null
          ? DateTime.parse(json['startedAt'] as String)
          : null,
      submittedAt: json['submittedAt'] != null
          ? DateTime.parse(json['submittedAt'] as String)
          : null,
      totalScore: (json['totalScore'] as num?)?.toDouble() ?? 0,
      maxScore: (json['maxScore'] as num?)?.toDouble() ?? 0,
      percentage: (json['percentage'] as num?)?.toDouble() ?? 0,
      correctCount: json['correctCount'] as int? ?? 0,
      wrongCount: json['wrongCount'] as int? ?? 0,
      skippedCount: json['skippedCount'] as int? ?? 0,
      status: json['status'] as String? ?? 'SUBMITTED',
      user: json['user'] != null
          ? CreatorInfo.fromJson(json['user'] as Map<String, dynamic>)
          : null,
      answers: aList
              ?.map(
                  (e) => AnswerModel.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      assessment: json['assessment'] != null
          ? AssessmentResultInfo.fromJson(
              json['assessment'] as Map<String, dynamic>)
          : null,
    );
  }
}

/// Minimal assessment info embedded in result.
class AssessmentResultInfo {
  final String title;
  final String showResultAfter;
  final double negativeMarking;
  final List<QuestionModel> questions;

  const AssessmentResultInfo({
    required this.title,
    this.showResultAfter = 'SUBMIT',
    this.negativeMarking = 0,
    this.questions = const [],
  });

  factory AssessmentResultInfo.fromJson(Map<String, dynamic> json) {
    final qList = json['questions'] as List<dynamic>?;
    return AssessmentResultInfo(
      title: json['title'] as String? ?? '',
      showResultAfter: json['showResultAfter'] as String? ?? 'SUBMIT',
      negativeMarking:
          (json['negativeMarking'] as num?)?.toDouble() ?? 0,
      questions: qList
              ?.map((e) =>
                  QuestionModel.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }
}

/// An individual answer in a result.
class AnswerModel {
  final String questionId;
  final dynamic answer;
  final bool isCorrect;
  final double marksAwarded;

  const AnswerModel({
    required this.questionId,
    this.answer,
    this.isCorrect = false,
    this.marksAwarded = 0,
  });

  factory AnswerModel.fromJson(Map<String, dynamic> json) {
    return AnswerModel(
      questionId: json['questionId'] as String,
      answer: json['answer'],
      isCorrect: json['isCorrect'] as bool? ?? false,
      marksAwarded: (json['marksAwarded'] as num?)?.toDouble() ?? 0,
    );
  }
}

/// Leaderboard entry (teacher view).
class AttemptLeaderboardEntry {
  final String id;
  final DateTime? startedAt;
  final DateTime? submittedAt;
  final double totalScore;
  final double maxScore;
  final double percentage;
  final int correctCount;
  final int wrongCount;
  final int skippedCount;
  final String status;
  final CreatorInfo? user;

  const AttemptLeaderboardEntry({
    required this.id,
    this.startedAt,
    this.submittedAt,
    this.totalScore = 0,
    this.maxScore = 0,
    this.percentage = 0,
    this.correctCount = 0,
    this.wrongCount = 0,
    this.skippedCount = 0,
    this.status = 'SUBMITTED',
    this.user,
  });

  factory AttemptLeaderboardEntry.fromJson(Map<String, dynamic> json) {
    return AttemptLeaderboardEntry(
      id: json['id'] as String,
      startedAt: json['startedAt'] != null
          ? DateTime.parse(json['startedAt'] as String)
          : null,
      submittedAt: json['submittedAt'] != null
          ? DateTime.parse(json['submittedAt'] as String)
          : null,
      totalScore: (json['totalScore'] as num?)?.toDouble() ?? 0,
      maxScore: (json['maxScore'] as num?)?.toDouble() ?? 0,
      percentage: (json['percentage'] as num?)?.toDouble() ?? 0,
      correctCount: json['correctCount'] as int? ?? 0,
      wrongCount: json['wrongCount'] as int? ?? 0,
      skippedCount: json['skippedCount'] as int? ?? 0,
      status: json['status'] as String? ?? 'SUBMITTED',
      user: json['user'] != null
          ? CreatorInfo.fromJson(json['user'] as Map<String, dynamic>)
          : null,
    );
  }
}

/// Shared creator/user model used across assessment entities.
class CreatorInfo {
  final String id;
  final String? name;
  final String? picture;

  const CreatorInfo({required this.id, this.name, this.picture});

  factory CreatorInfo.fromJson(Map<String, dynamic> json) {
    return CreatorInfo(
      id: json['id'] as String,
      name: json['name'] as String?,
      picture: json['picture'] as String?,
    );
  }
}
