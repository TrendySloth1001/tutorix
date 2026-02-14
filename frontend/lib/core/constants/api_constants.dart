/// Central place for all API-related constants.
///
/// When switching environments (dev → staging → production),
/// only this file needs to change.
class ApiConstants {
  ApiConstants._();

  static const String baseUrl =
      'https://qjhcp0ph-3010.inc1.devtunnels.ms';

  // Auth
  static const String googleAuth = '$baseUrl/auth/google';

  // User
  static const String userMe = '$baseUrl/user/me';
  static const String userMeRoles = '$baseUrl/user/me/roles';
  static const String userMeOnboarding = '$baseUrl/user/me/onboarding';
  static const String userMeSessions = '$baseUrl/user/me/sessions';

  // Upload
  static const String uploadAvatar = '$baseUrl/upload/avatar';

  // Coaching
  static const String coaching = '$baseUrl/coaching';
  static String coachingMy = '$baseUrl/coaching/my';
  static String coachingById(String id) => '$baseUrl/coaching/$id';
  static String checkSlug(String slug) => '$baseUrl/coaching/check-slug/$slug';

  // Google
  static const String googleClientId =
      '299795936862-s70dge4e1k99b3db0faqss8qrcrjj12b.apps.googleusercontent.com';
}
