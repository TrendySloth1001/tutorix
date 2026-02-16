import 'assessment_model.dart';

/// An assignment within a batch.
class AssignmentModel {
  final String id;
  final String title;
  final String? description;
  final DateTime? dueDate;
  final bool allowLateSubmission;
  final int? totalMarks;
  final String status; // ACTIVE, CLOSED
  final DateTime? createdAt;
  final CreatorInfo? createdBy;
  final List<AttachmentModel> attachments;
  final int submissionCount;
  final SubmissionSummary? mySubmission;

  const AssignmentModel({
    required this.id,
    required this.title,
    this.description,
    this.dueDate,
    this.allowLateSubmission = false,
    this.totalMarks,
    this.status = 'ACTIVE',
    this.createdAt,
    this.createdBy,
    this.attachments = const [],
    this.submissionCount = 0,
    this.mySubmission,
  });

  factory AssignmentModel.fromJson(Map<String, dynamic> json) {
    final count = json['_count'] as Map<String, dynamic>?;
    final attachList = json['attachments'] as List<dynamic>?;

    return AssignmentModel(
      id: json['id'] as String,
      title: json['title'] as String,
      description: json['description'] as String?,
      dueDate: json['dueDate'] != null
          ? DateTime.parse(json['dueDate'] as String)
          : null,
      allowLateSubmission: json['allowLateSubmission'] as bool? ?? false,
      totalMarks: json['totalMarks'] as int?,
      status: json['status'] as String? ?? 'ACTIVE',
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'] as String)
          : null,
      createdBy: json['createdBy'] != null
          ? CreatorInfo.fromJson(json['createdBy'] as Map<String, dynamic>)
          : null,
      attachments:
          attachList
              ?.map((e) => AttachmentModel.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      submissionCount: count?['submissions'] as int? ?? 0,
      mySubmission: json['mySubmission'] != null
          ? SubmissionSummary.fromJson(
              json['mySubmission'] as Map<String, dynamic>,
            )
          : null,
    );
  }

  bool get isActive => status == 'ACTIVE';
  bool get isClosed => status == 'CLOSED';

  bool get isPastDue {
    if (dueDate == null) return false;
    return DateTime.now().isAfter(dueDate!);
  }

  bool get canSubmit {
    if (!isActive) return false;
    if (!isPastDue) return true;
    return allowLateSubmission;
  }
}

/// A file attachment on an assignment (teacher-provided reference files).
class AttachmentModel {
  final String id;
  final String url;
  final String fileName;
  final String fileType;
  final int fileSize;

  const AttachmentModel({
    required this.id,
    required this.url,
    required this.fileName,
    this.fileType = 'pdf',
    this.fileSize = 0,
  });

  factory AttachmentModel.fromJson(Map<String, dynamic> json) {
    return AttachmentModel(
      id: json['id'] as String,
      url: json['url'] as String,
      fileName: json['fileName'] as String,
      fileType: json['fileType'] as String? ?? 'pdf',
      fileSize: json['fileSize'] as int? ?? 0,
    );
  }
}

/// Short submission summary for list views (student's own submission).
class SubmissionSummary {
  final String? assignmentId;
  final String status; // SUBMITTED, GRADED, RETURNED
  final int? marks;
  final DateTime? submittedAt;
  final bool isLate;

  const SubmissionSummary({
    this.assignmentId,
    this.status = 'SUBMITTED',
    this.marks,
    this.submittedAt,
    this.isLate = false,
  });

  factory SubmissionSummary.fromJson(Map<String, dynamic> json) {
    return SubmissionSummary(
      assignmentId: json['assignmentId'] as String?,
      status: json['status'] as String? ?? 'SUBMITTED',
      marks: json['marks'] as int?,
      submittedAt: json['submittedAt'] != null
          ? DateTime.parse(json['submittedAt'] as String)
          : null,
      isLate: json['isLate'] as bool? ?? false,
    );
  }
}

/// Full submission model (teacher views submissions list, or student views own).
class SubmissionModel {
  final String id;
  final int? marks;
  final String? feedback;
  final DateTime? gradedAt;
  final bool isLate;
  final String status;
  final DateTime? submittedAt;
  final CreatorInfo? user;
  final List<SubmissionFileModel> files;

  const SubmissionModel({
    required this.id,
    this.marks,
    this.feedback,
    this.gradedAt,
    this.isLate = false,
    this.status = 'SUBMITTED',
    this.submittedAt,
    this.user,
    this.files = const [],
  });

  factory SubmissionModel.fromJson(Map<String, dynamic> json) {
    final fList = json['files'] as List<dynamic>?;
    return SubmissionModel(
      id: json['id'] as String,
      marks: json['marks'] as int?,
      feedback: json['feedback'] as String?,
      gradedAt: json['gradedAt'] != null
          ? DateTime.parse(json['gradedAt'] as String)
          : null,
      isLate: json['isLate'] as bool? ?? false,
      status: json['status'] as String? ?? 'SUBMITTED',
      submittedAt: json['submittedAt'] != null
          ? DateTime.parse(json['submittedAt'] as String)
          : null,
      user: json['user'] != null
          ? CreatorInfo.fromJson(json['user'] as Map<String, dynamic>)
          : null,
      files:
          fList
              ?.map(
                (e) => SubmissionFileModel.fromJson(e as Map<String, dynamic>),
              )
              .toList() ??
          [],
    );
  }
}

/// A file within a student's submission.
class SubmissionFileModel {
  final String id;
  final String url;
  final String fileName;
  final String fileType;
  final int fileSize;

  const SubmissionFileModel({
    required this.id,
    required this.url,
    required this.fileName,
    this.fileType = 'pdf',
    this.fileSize = 0,
  });

  factory SubmissionFileModel.fromJson(Map<String, dynamic> json) {
    return SubmissionFileModel(
      id: json['id'] as String,
      url: json['url'] as String,
      fileName: json['fileName'] as String,
      fileType: json['fileType'] as String? ?? 'pdf',
      fileSize: json['fileSize'] as int? ?? 0,
    );
  }
}
