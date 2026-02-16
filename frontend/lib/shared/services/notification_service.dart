import '../../core/constants/api_constants.dart';
import '../../core/services/cache_manager.dart';
import 'api_client.dart';

class NotificationService {
  final ApiClient _api = ApiClient.instance;
  final CacheManager _cache = CacheManager.instance;

  /// Get notifications for a coaching — SWR stream.
  Stream<Map<String, dynamic>> watchCoachingNotifications(
    String coachingId, {
    int limit = 20,
    int offset = 0,
  }) {
    final key = 'notif:coaching:$coachingId:$limit:$offset';
    return _cache.swr<Map<String, dynamic>>(
      key,
      () => _api.getAuthenticated(
        '${ApiConstants.coaching}/$coachingId/notifications?limit=$limit&offset=$offset',
      ),
      (raw) => Map<String, dynamic>.from(raw as Map),
    );
  }

  Future<Map<String, dynamic>> getCoachingNotifications(
    String coachingId, {
    int limit = 20,
    int offset = 0,
  }) =>
      watchCoachingNotifications(coachingId, limit: limit, offset: offset).last;

  /// Get personal notifications — SWR stream.
  Stream<Map<String, dynamic>> watchUserNotifications({
    int limit = 20,
    int offset = 0,
  }) {
    final key = 'notif:user:$limit:$offset';
    return _cache.swr<Map<String, dynamic>>(
      key,
      () => _api.getAuthenticated(
        '${ApiConstants.baseUrl}/notifications/me?limit=$limit&offset=$offset',
      ),
      (raw) => Map<String, dynamic>.from(raw as Map),
    );
  }

  Future<Map<String, dynamic>> getUserNotifications({
    int limit = 20,
    int offset = 0,
  }) => watchUserNotifications(limit: limit, offset: offset).last;

  /// Mark a notification as read.
  Future<void> markAsRead(String notificationId) async {
    await _api.patchAuthenticated(
      '${ApiConstants.baseUrl}/notifications/$notificationId/read',
      body: {},
    );
    await _cache.invalidatePrefix('notif:');
  }

  /// Archive a notification (mark as removed from view without deleting).
  Future<void> archiveNotification(String notificationId) async {
    await _api.patchAuthenticated(
      '${ApiConstants.baseUrl}/notifications/$notificationId/archive',
      body: {},
    );
    await _cache.invalidatePrefix('notif:');
  }

  /// Delete a notification.
  Future<void> deleteNotification(String notificationId) async {
    await _api.deleteAuthenticated(
      '${ApiConstants.baseUrl}/notifications/$notificationId',
    );
    await _cache.invalidatePrefix('notif:');
  }
}
