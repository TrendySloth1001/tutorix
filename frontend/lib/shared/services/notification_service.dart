import '../../core/constants/api_constants.dart';
import 'api_client.dart';

class NotificationService {
  final ApiClient _api = ApiClient.instance;

  /// Get notifications for a coaching.
  Future<Map<String, dynamic>> getCoachingNotifications(
    String coachingId, {
    int limit = 20,
    int offset = 0,
  }) async {
    final data = await _api.getAuthenticated(
      '${ApiConstants.coaching}/$coachingId/notifications?limit=$limit&offset=$offset',
    );
    return data;
  }

  /// Get personal notifications for the authenticated user.
  Future<Map<String, dynamic>> getUserNotifications({
    int limit = 20,
    int offset = 0,
  }) async {
    final data = await _api.getAuthenticated(
      '${ApiConstants.baseUrl}/notifications/me?limit=$limit&offset=$offset',
    );
    return data;
  }

  /// Mark a notification as read.
  Future<void> markAsRead(String notificationId) async {
    await _api.patchAuthenticated(
      '${ApiConstants.baseUrl}/notifications/$notificationId/read',
      body: {},
    );
  }

  /// Archive a notification (mark as removed from view without deleting).
  Future<void> archiveNotification(String notificationId) async {
    await _api.patchAuthenticated(
      '${ApiConstants.baseUrl}/notifications/$notificationId/archive',
      body: {},
    );
  }

  /// Delete a notification.
  Future<void> deleteNotification(String notificationId) async {
    await _api.deleteAuthenticated(
      '${ApiConstants.baseUrl}/notifications/$notificationId',
    );
  }
}
