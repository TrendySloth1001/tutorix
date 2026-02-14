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

  // Coaching
  static const String coaching = '$baseUrl/coaching';
  static String coachingMy = '$baseUrl/coaching/my';
  static String coachingJoined = '$baseUrl/coaching/joined';
  static String coachingById(String id) => '$baseUrl/coaching/$id';
  static String checkSlug(String slug) => '$baseUrl/coaching/check-slug/$slug';

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

  // Google
  static const String googleClientId =
      '299795936862-s70dge4e1k99b3db0faqss8qrcrjj12b.apps.googleusercontent.com';
}
