/// Central place for all API-related constants.
///
/// When switching environments (dev → staging → production),
/// only this file needs to change.
class ApiConstants {
  ApiConstants._();

  static const String baseUrl = 'https://qjhcp0ph-3010.inc1.devtunnels.ms';

  // Auth
  static const String googleAuth = '$baseUrl/auth/google';

  // User
  static const String userMe = '$baseUrl/user/me';
  static const String userMeRoles = '$baseUrl/user/me/roles';
  static const String userMeOnboarding = '$baseUrl/user/me/onboarding';
  static const String userMeSessions = '$baseUrl/user/me/sessions';

  // Upload
  static const String uploadAvatar = '$baseUrl/upload/avatar';
  static const String uploadLogo = '$baseUrl/upload/logo';
  static const String uploadCover = '$baseUrl/upload/cover';
  static const String uploadNote = '$baseUrl/upload/note';
  static const String uploadNotes = '$baseUrl/upload/notes';

  // Coaching
  static const String coaching = '$baseUrl/coaching';
  static const String coachingMasters = '$baseUrl/coaching/masters';
  static const String coachingExplore = '$baseUrl/coaching/explore';
  static const String coachingSearch = '$baseUrl/coaching/search';
  static const String coachingSaved = '$baseUrl/coaching/saved';
  static String coachingSave(String id) => '$baseUrl/coaching/$id/save';
  static String coachingMy = '$baseUrl/coaching/my';
  static String coachingJoined = '$baseUrl/coaching/joined';
  static String coachingById(String id) => '$baseUrl/coaching/$id';
  static String coachingFull(String id) => '$baseUrl/coaching/$id/full';
  static String checkSlug(String slug) => '$baseUrl/coaching/check-slug/$slug';

  // Coaching Onboarding
  static String coachingOnboardingProfile(String id) =>
      '$baseUrl/coaching/$id/onboarding/profile';
  static String coachingOnboardingAddress(String id) =>
      '$baseUrl/coaching/$id/onboarding/address';
  static String coachingOnboardingBranch(String id) =>
      '$baseUrl/coaching/$id/onboarding/branch';
  static String coachingOnboardingComplete(String id) =>
      '$baseUrl/coaching/$id/onboarding/complete';
  static String coachingBranches(String id) => '$baseUrl/coaching/$id/branches';
  static String deleteBranch(String coachingId, String branchId) =>
      '$baseUrl/coaching/$coachingId/branches/$branchId';

  // Coaching Invitations
  static String inviteLookup(String coachingId) =>
      '$baseUrl/coaching/$coachingId/invite/lookup';
  static String inviteSend(String coachingId) =>
      '$baseUrl/coaching/$coachingId/invite';
  static String coachingInvitations(String coachingId) =>
      '$baseUrl/coaching/$coachingId/invitations';
  static String cancelInvitation(String coachingId, String invitationId) =>
      '$baseUrl/coaching/$coachingId/invitations/$invitationId';

  // Coaching Members
  static String coachingMembers(String coachingId) =>
      '$baseUrl/coaching/$coachingId/members';
  static String removeMember(String coachingId, String memberId) =>
      '$baseUrl/coaching/$coachingId/members/$memberId';
  static String updateMemberRole(String coachingId, String memberId) =>
      '$baseUrl/coaching/$coachingId/members/$memberId';
  static String memberAcademicHistory(String coachingId, String memberId) =>
      '$baseUrl/coaching/$coachingId/members/$memberId/academic-history';

  // User Invitations
  static const String userInvitations = '$baseUrl/user/invitations';
  static String respondInvitation(String invitationId) =>
      '$baseUrl/user/invitations/$invitationId/respond';

  // Academic
  static const String academicMasters = '$baseUrl/academic/masters';
  static const String academicProfile = '$baseUrl/academic/profile';
  static const String academicRemindLater = '$baseUrl/academic/remind-later';
  static const String academicOnboardingStatus =
      '$baseUrl/academic/onboarding-status';

  // Batches
  static String batches(String coachingId) =>
      '$baseUrl/coaching/$coachingId/batches';
  static String batchById(String coachingId, String batchId) =>
      '$baseUrl/coaching/$coachingId/batches/$batchId';
  static String myBatches(String coachingId) =>
      '$baseUrl/coaching/$coachingId/batches/my';
  static String recentNotes(String coachingId) =>
      '$baseUrl/coaching/$coachingId/batches/recent-notes';
  static String dashboardFeed(String coachingId) =>
      '$baseUrl/coaching/$coachingId/batches/dashboard-feed';
  static String batchStorage(String coachingId) =>
      '$baseUrl/coaching/$coachingId/batches/storage';
  static String batchMembers(String coachingId, String batchId) =>
      '$baseUrl/coaching/$coachingId/batches/$batchId/members';
  static String batchAvailableMembers(String coachingId, String batchId) =>
      '$baseUrl/coaching/$coachingId/batches/$batchId/members/available';
  static String removeBatchMember(
    String coachingId,
    String batchId,
    String batchMemberId,
  ) => '$baseUrl/coaching/$coachingId/batches/$batchId/members/$batchMemberId';
  static String batchNotes(String coachingId, String batchId) =>
      '$baseUrl/coaching/$coachingId/batches/$batchId/notes';
  static String deleteBatchNote(
    String coachingId,
    String batchId,
    String noteId,
  ) => '$baseUrl/coaching/$coachingId/batches/$batchId/notes/$noteId';
  static String batchNotices(String coachingId, String batchId) =>
      '$baseUrl/coaching/$coachingId/batches/$batchId/notices';
  static String deleteBatchNotice(
    String coachingId,
    String batchId,
    String noticeId,
  ) => '$baseUrl/coaching/$coachingId/batches/$batchId/notices/$noticeId';

  // Assessments
  static String assessments(String coachingId, String batchId) =>
      '$baseUrl/coaching/$coachingId/batches/$batchId/assessments';
  static String assessmentById(
    String coachingId,
    String batchId,
    String assessmentId,
  ) =>
      '$baseUrl/coaching/$coachingId/batches/$batchId/assessments/$assessmentId';
  static String assessmentStatus(
    String coachingId,
    String batchId,
    String assessmentId,
  ) =>
      '$baseUrl/coaching/$coachingId/batches/$batchId/assessments/$assessmentId/status';
  static String assessmentQuestions(
    String coachingId,
    String batchId,
    String assessmentId,
  ) =>
      '$baseUrl/coaching/$coachingId/batches/$batchId/assessments/$assessmentId/questions';
  static String deleteQuestion(
    String coachingId,
    String batchId,
    String questionId,
  ) =>
      '$baseUrl/coaching/$coachingId/batches/$batchId/assessments/questions/$questionId';
  static String startAttempt(
    String coachingId,
    String batchId,
    String assessmentId,
  ) =>
      '$baseUrl/coaching/$coachingId/batches/$batchId/assessments/$assessmentId/start';
  static String saveAnswer(
    String coachingId,
    String batchId,
    String attemptId,
  ) =>
      '$baseUrl/coaching/$coachingId/batches/$batchId/assessments/attempts/$attemptId/answer';
  static String submitAttempt(
    String coachingId,
    String batchId,
    String attemptId,
  ) =>
      '$baseUrl/coaching/$coachingId/batches/$batchId/assessments/attempts/$attemptId/submit';
  static String attemptResult(
    String coachingId,
    String batchId,
    String attemptId,
  ) =>
      '$baseUrl/coaching/$coachingId/batches/$batchId/assessments/attempts/$attemptId/result';
  static String attemptAnswers(
    String coachingId,
    String batchId,
    String attemptId,
  ) =>
      '$baseUrl/coaching/$coachingId/batches/$batchId/assessments/attempts/$attemptId/answers';
  static String assessmentAttempts(
    String coachingId,
    String batchId,
    String assessmentId,
  ) =>
      '$baseUrl/coaching/$coachingId/batches/$batchId/assessments/$assessmentId/attempts';

  // Assignments
  static String assignments(String coachingId, String batchId) =>
      '$baseUrl/coaching/$coachingId/batches/$batchId/assignments';
  static String assignmentById(
    String coachingId,
    String batchId,
    String assignmentId,
  ) =>
      '$baseUrl/coaching/$coachingId/batches/$batchId/assignments/$assignmentId';
  static String assignmentStatus(
    String coachingId,
    String batchId,
    String assignmentId,
  ) =>
      '$baseUrl/coaching/$coachingId/batches/$batchId/assignments/$assignmentId/status';
  static String submitAssignment(
    String coachingId,
    String batchId,
    String assignmentId,
  ) =>
      '$baseUrl/coaching/$coachingId/batches/$batchId/assignments/$assignmentId/submit';
  static String assignmentSubmissions(
    String coachingId,
    String batchId,
    String assignmentId,
  ) =>
      '$baseUrl/coaching/$coachingId/batches/$batchId/assignments/$assignmentId/submissions';
  static String myAssignmentSubmission(
    String coachingId,
    String batchId,
    String assignmentId,
  ) =>
      '$baseUrl/coaching/$coachingId/batches/$batchId/assignments/$assignmentId/my-submission';
  static String gradeSubmission(
    String coachingId,
    String batchId,
    String submissionId,
  ) =>
      '$baseUrl/coaching/$coachingId/batches/$batchId/assignments/submissions/$submissionId/grade';

  // Fee Management
  static String feeStructures(String coachingId) =>
      '$baseUrl/coaching/$coachingId/fee/structures';
  static String feeStructureById(String coachingId, String structureId) =>
      '$baseUrl/coaching/$coachingId/fee/structures/$structureId';
  static String assignFees(String coachingId) =>
      '$baseUrl/coaching/$coachingId/fee/assign';
  static String feeRecords(String coachingId) =>
      '$baseUrl/coaching/$coachingId/fee/records';
  static String feeSummary(String coachingId) =>
      '$baseUrl/coaching/$coachingId/fee/summary';
  static String feeRecordById(String coachingId, String recordId) =>
      '$baseUrl/coaching/$coachingId/fee/records/$recordId';
  static String feeRecordPay(String coachingId, String recordId) =>
      '$baseUrl/coaching/$coachingId/fee/records/$recordId/pay';
  static String feeRecordRemind(String coachingId, String recordId) =>
      '$baseUrl/coaching/$coachingId/fee/records/$recordId/remind';
  static String feeRecordWaive(String coachingId, String recordId) =>
      '$baseUrl/coaching/$coachingId/fee/records/$recordId/waive';
  static String feeMember(String coachingId, String memberId) =>
      '$baseUrl/coaching/$coachingId/fee/members/$memberId';
  static String feesMy(String coachingId) =>
      '$baseUrl/coaching/$coachingId/fee/my';
  static String feeMemberLedger(String coachingId, String memberId) =>
      '$baseUrl/coaching/$coachingId/fee/members/$memberId/ledger';
  static String feeAssignmentPause(String coachingId, String assignmentId) =>
      '$baseUrl/coaching/$coachingId/fee/assignments/$assignmentId/pause';
  static String feeRecordRefund(String coachingId, String recordId) =>
      '$baseUrl/coaching/$coachingId/fee/records/$recordId/refund';
  static String feeBulkRemind(String coachingId) =>
      '$baseUrl/coaching/$coachingId/fee/bulk-remind';
  static String feeOverdueReport(String coachingId) =>
      '$baseUrl/coaching/$coachingId/fee/overdue-report';

  // Admin / Logging
  static const String logFrontendError = '$baseUrl/api/logs/frontend';
  static const String adminLogs = '$baseUrl/admin/logs';
  static const String adminLogsStats = '$baseUrl/admin/logs/stats';
  static const String adminLogsCleanup = '$baseUrl/admin/logs/cleanup';

  // Google
  static const String googleClientId =
      '299795936862-s70dge4e1k99b3db0faqss8qrcrjj12b.apps.googleusercontent.com';
}
