import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../../core/constants/api_constants.dart';
import '../../../core/services/cache_manager.dart';
import '../../../shared/services/api_client.dart';
import '../../../shared/services/secure_storage_service.dart';
import '../models/assessment_model.dart';
import '../models/assignment_model.dart';

class AssessmentService {
  final ApiClient _api = ApiClient.instance;
  final CacheManager _cache = CacheManager.instance;

  // ═══════════════════════════════════════════════════════════════════
  //  ASSESSMENTS
  // ═══════════════════════════════════════════════════════════════════

  /// Create assessment with questions.
  Future<AssessmentModel> createAssessment(
    String coachingId,
    String batchId, {
    required String title,
    String? description,
    String type = 'QUIZ',
    int? durationMinutes,
    String? startTime,
    String? endTime,
    int? passingMarks,
    bool shuffleQuestions = false,
    bool shuffleOptions = false,
    String showResultAfter = 'SUBMIT',
    int maxAttempts = 1,
    double negativeMarking = 0,
    List<Map<String, dynamic>>? questions,
  }) async {
    final body = <String, dynamic>{
      'title': title,
      'type': type,
      'shuffleQuestions': shuffleQuestions,
      'shuffleOptions': shuffleOptions,
      'showResultAfter': showResultAfter,
      'maxAttempts': maxAttempts,
      'negativeMarking': negativeMarking,
    };
    if (description != null) body['description'] = description;
    if (durationMinutes != null) body['durationMinutes'] = durationMinutes;
    if (startTime != null) body['startTime'] = startTime;
    if (endTime != null) body['endTime'] = endTime;
    if (passingMarks != null) body['passingMarks'] = passingMarks;
    if (questions != null) body['questions'] = questions;

    final data = await _api.postAuthenticated(
      ApiConstants.assessments(coachingId, batchId),
      body: body,
    );
    await _cache.invalidatePrefix('assess:$coachingId:$batchId');
    return AssessmentModel.fromJson(data);
  }

  /// List assessments for a batch (SWR).
  Stream<List<AssessmentModel>> watchAssessments(
    String coachingId,
    String batchId, {
    String? role,
  }) {
    final key =
        'assess:$coachingId:$batchId:list${role != null ? ':$role' : ''}';
    return _cache.swr<List<AssessmentModel>>(
      key,
      () {
        var url = ApiConstants.assessments(coachingId, batchId);
        if (role != null) url += '?role=$role';
        return _api.getAuthenticatedRaw(url);
      },
      (raw) {
        final list = (raw as List<dynamic>?) ?? [];
        return list
            .map(
              (e) =>
                  AssessmentModel.fromJson(Map<String, dynamic>.from(e as Map)),
            )
            .toList();
      },
    );
  }

  Future<List<AssessmentModel>> listAssessments(
    String coachingId,
    String batchId, {
    String? role,
  }) => watchAssessments(coachingId, batchId, role: role).last;

  /// Get assessment detail.
  Future<AssessmentModel> getAssessment(
    String coachingId,
    String batchId,
    String assessmentId, {
    String? role,
  }) async {
    var url = ApiConstants.assessmentById(coachingId, batchId, assessmentId);
    if (role != null) url += '?role=$role';
    final data = await _api.getAuthenticated(url);
    return AssessmentModel.fromJson(data);
  }

  /// Publish / close an assessment.
  Future<void> updateAssessmentStatus(
    String coachingId,
    String batchId,
    String assessmentId,
    String status,
  ) async {
    await _api.patchAuthenticated(
      ApiConstants.assessmentStatus(coachingId, batchId, assessmentId),
      body: {'status': status},
    );
    await _cache.invalidatePrefix('assess:$coachingId:$batchId');
  }

  /// Delete an assessment.
  Future<bool> deleteAssessment(
    String coachingId,
    String batchId,
    String assessmentId,
  ) async {
    final ok = await _api.deleteAuthenticated(
      ApiConstants.assessmentById(coachingId, batchId, assessmentId),
    );
    if (ok) await _cache.invalidatePrefix('assess:$coachingId:$batchId');
    return ok;
  }

  /// Add questions to existing assessment.
  Future<void> addQuestions(
    String coachingId,
    String batchId,
    String assessmentId,
    List<Map<String, dynamic>> questions,
  ) async {
    await _api.postAuthenticated(
      ApiConstants.assessmentQuestions(coachingId, batchId, assessmentId),
      body: {'questions': questions},
    );
    await _cache.invalidatePrefix('assess:$coachingId:$batchId');
  }

  /// Delete a question.
  Future<bool> deleteQuestion(
    String coachingId,
    String batchId,
    String questionId,
  ) async {
    final ok = await _api.deleteAuthenticated(
      ApiConstants.deleteQuestion(coachingId, batchId, questionId),
    );
    if (ok) await _cache.invalidatePrefix('assess:$coachingId:$batchId');
    return ok;
  }

  // ── Attempts ──────────────────────────────────────────────────────

  /// Start or resume an attempt.
  Future<Map<String, dynamic>> startAttempt(
    String coachingId,
    String batchId,
    String assessmentId,
  ) async {
    return await _api.postAuthenticated(
      ApiConstants.startAttempt(coachingId, batchId, assessmentId),
    );
  }

  /// Auto-save a single answer.
  Future<void> saveAnswer(
    String coachingId,
    String batchId,
    String attemptId, {
    required String questionId,
    required dynamic answer,
  }) async {
    await _api.postAuthenticated(
      ApiConstants.saveAnswer(coachingId, batchId, attemptId),
      body: {'questionId': questionId, 'answer': answer},
    );
  }

  /// Submit attempt — triggers server-side grading.
  Future<AttemptResultModel> submitAttempt(
    String coachingId,
    String batchId,
    String attemptId,
  ) async {
    final data = await _api.postAuthenticated(
      ApiConstants.submitAttempt(coachingId, batchId, attemptId),
    );
    await _cache.invalidatePrefix('assess:$coachingId:$batchId');
    return AttemptResultModel.fromJson(data);
  }

  /// Get attempt result with all answers.
  Future<AttemptResultModel> getAttemptResult(
    String coachingId,
    String batchId,
    String attemptId,
  ) async {
    final data = await _api.getAuthenticated(
      ApiConstants.attemptResult(coachingId, batchId, attemptId),
    );
    return AttemptResultModel.fromJson(data);
  }

  /// Get saved answers for in-progress attempt.
  Future<List<Map<String, dynamic>>> getAttemptAnswers(
    String coachingId,
    String batchId,
    String attemptId,
  ) async {
    final data = await _api.getAuthenticatedRaw(
      ApiConstants.attemptAnswers(coachingId, batchId, attemptId),
    );
    return (data as List<dynamic>)
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
  }

  /// Get all submitted attempts for an assessment (teacher leaderboard).
  Future<List<AttemptLeaderboardEntry>> getAssessmentAttempts(
    String coachingId,
    String batchId,
    String assessmentId,
  ) async {
    final data = await _api.getAuthenticatedRaw(
      ApiConstants.assessmentAttempts(coachingId, batchId, assessmentId),
    );
    return (data as List<dynamic>)
        .map(
          (e) => AttemptLeaderboardEntry.fromJson(
            Map<String, dynamic>.from(e as Map),
          ),
        )
        .toList();
  }

  // ═══════════════════════════════════════════════════════════════════
  //  ASSIGNMENTS
  // ═══════════════════════════════════════════════════════════════════

  /// Create assignment with optional file attachments.
  Future<AssignmentModel> createAssignment(
    String coachingId,
    String batchId, {
    required String title,
    String? description,
    String? dueDate,
    bool allowLateSubmission = false,
    int? totalMarks,
    List<String>? filePaths,
  }) async {
    if (filePaths != null && filePaths.isNotEmpty) {
      // Multipart upload with JSON data field
      final token = await SecureStorageService.instance.getToken();
      if (token == null) throw Exception('Not authenticated');

      final request = http.MultipartRequest(
        'POST',
        Uri.parse(ApiConstants.assignments(coachingId, batchId)),
      )..headers['Authorization'] = 'Bearer $token';

      final body = <String, dynamic>{
        'title': title,
        'allowLateSubmission': allowLateSubmission,
      };
      if (description != null) body['description'] = description;
      if (dueDate != null) body['dueDate'] = dueDate;
      if (totalMarks != null) body['totalMarks'] = totalMarks;

      request.fields['data'] = jsonEncode(body);
      for (final path in filePaths) {
        request.files.add(await http.MultipartFile.fromPath('files', path));
      }

      final streamed = await request.send();
      final response = await http.Response.fromStream(streamed);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        final err = jsonDecode(response.body);
        throw Exception(err['error'] ?? 'Upload failed');
      }
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      await _cache.invalidatePrefix('assign:$coachingId:$batchId');
      return AssignmentModel.fromJson(data);
    } else {
      final body = <String, dynamic>{
        'title': title,
        'allowLateSubmission': allowLateSubmission,
      };
      if (description != null) body['description'] = description;
      if (dueDate != null) body['dueDate'] = dueDate;
      if (totalMarks != null) body['totalMarks'] = totalMarks;

      final data = await _api.postAuthenticated(
        ApiConstants.assignments(coachingId, batchId),
        body: body,
      );
      await _cache.invalidatePrefix('assign:$coachingId:$batchId');
      return AssignmentModel.fromJson(data);
    }
  }

  /// List assignments (SWR).
  Stream<List<AssignmentModel>> watchAssignments(
    String coachingId,
    String batchId, {
    String? role,
  }) {
    final key =
        'assign:$coachingId:$batchId:list${role != null ? ':$role' : ''}';
    return _cache.swr<List<AssignmentModel>>(
      key,
      () {
        var url = ApiConstants.assignments(coachingId, batchId);
        if (role != null) url += '?role=$role';
        return _api.getAuthenticatedRaw(url);
      },
      (raw) {
        final list = (raw as List<dynamic>?) ?? [];
        return list
            .map(
              (e) =>
                  AssignmentModel.fromJson(Map<String, dynamic>.from(e as Map)),
            )
            .toList();
      },
    );
  }

  Future<List<AssignmentModel>> listAssignments(
    String coachingId,
    String batchId, {
    String? role,
  }) => watchAssignments(coachingId, batchId, role: role).last;

  /// Get assignment detail.
  Future<AssignmentModel> getAssignment(
    String coachingId,
    String batchId,
    String assignmentId,
  ) async {
    final data = await _api.getAuthenticated(
      ApiConstants.assignmentById(coachingId, batchId, assignmentId),
    );
    return AssignmentModel.fromJson(data);
  }

  /// Update assignment status.
  Future<void> updateAssignmentStatus(
    String coachingId,
    String batchId,
    String assignmentId,
    String status,
  ) async {
    await _api.patchAuthenticated(
      ApiConstants.assignmentStatus(coachingId, batchId, assignmentId),
      body: {'status': status},
    );
    await _cache.invalidatePrefix('assign:$coachingId:$batchId');
  }

  /// Delete assignment.
  Future<bool> deleteAssignment(
    String coachingId,
    String batchId,
    String assignmentId,
  ) async {
    final ok = await _api.deleteAuthenticated(
      ApiConstants.assignmentById(coachingId, batchId, assignmentId),
    );
    if (ok) await _cache.invalidatePrefix('assign:$coachingId:$batchId');
    return ok;
  }

  /// Submit assignment with files (student).
  Future<SubmissionModel> submitAssignment(
    String coachingId,
    String batchId,
    String assignmentId, {
    required List<String> filePaths,
  }) async {
    final token = await SecureStorageService.instance.getToken();
    if (token == null) throw Exception('Not authenticated');

    final request = http.MultipartRequest(
      'POST',
      Uri.parse(
        ApiConstants.submitAssignment(coachingId, batchId, assignmentId),
      ),
    )..headers['Authorization'] = 'Bearer $token';

    for (final path in filePaths) {
      request.files.add(await http.MultipartFile.fromPath('files', path));
    }

    final streamed = await request.send();
    final response = await http.Response.fromStream(streamed);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      final err = jsonDecode(response.body);
      throw Exception(err['error'] ?? 'Submission failed');
    }
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    await _cache.invalidatePrefix('assign:$coachingId:$batchId');
    return SubmissionModel.fromJson(data);
  }

  /// Get all submissions for an assignment (teacher).
  Future<List<SubmissionModel>> getSubmissions(
    String coachingId,
    String batchId,
    String assignmentId,
  ) async {
    final data = await _api.getAuthenticatedRaw(
      ApiConstants.assignmentSubmissions(coachingId, batchId, assignmentId),
    );
    return (data as List<dynamic>)
        .map(
          (e) => SubmissionModel.fromJson(Map<String, dynamic>.from(e as Map)),
        )
        .toList();
  }

  /// Get student's own submission.
  Future<SubmissionModel?> getMySubmission(
    String coachingId,
    String batchId,
    String assignmentId,
  ) async {
    final data = await _api.getAuthenticated(
      ApiConstants.myAssignmentSubmission(coachingId, batchId, assignmentId),
    );
    // Backend returns null when no submission exists
    if (data.isEmpty) return null;
    return SubmissionModel.fromJson(data);
  }

  /// Grade a submission (teacher).
  Future<SubmissionModel> gradeSubmission(
    String coachingId,
    String batchId,
    String submissionId, {
    required int marks,
    String? feedback,
  }) async {
    final body = <String, dynamic>{'marks': marks};
    if (feedback != null) body['feedback'] = feedback;

    final data = await _api.patchAuthenticated(
      ApiConstants.gradeSubmission(coachingId, batchId, submissionId),
      body: body,
    );
    await _cache.invalidatePrefix('assign:$coachingId:$batchId');
    return SubmissionModel.fromJson(data);
  }
}
