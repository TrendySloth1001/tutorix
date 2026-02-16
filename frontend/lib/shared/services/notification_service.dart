import '../../core/constants/api_constants.dart';
import '../../core/services/cache_manager.dart';
import 'api_client.dart';

class NotificationService {
  final ApiClient _api = ApiClient.instance;
  final CacheManager _cache = CacheManager.instance;

  /// Get notifications for a coaching.
  Future<Map<String, dynamic>> getCoachingNotifications(
    String coachingId, {
    int limit = 20,
    int offset = 0,
  }) async {
    final key = 'notif:coaching:$coachingId:$limit:$offset';
    try {
      final data = await _api.getAuthenticated(
        '${ApiConstants.coaching}/$coachingId/notifications?limit=$limit&offset=$offset',
      );
      await _cache.put(key, data);
      return data;
    } catch (e) {
      final cached = await _cache.get(key);
      if (cached != null) return Map<String, dynamic>.from(cached as Map);
      rethrow;
    }
  }

  /// Get personal notifications for the authenticated user.
  Future<Map<String, dynamic>> getUserNotifications({
    int limit = 20,
    int offset = 0,
  }) async {
    final key = 'notif:user:$limit:$offset';
    try {
      final data = await _api.getAuthenticated(
        '${ApiConstants.baseUrl}/notifications/me?limit=$limit&offset=$offset',
      );
      await _cache.put(key, data);
      return data;
    } catch (e) {
      final cached = await _cache.get(key);
      if (cached != null) return Map<String, dynamic>.from(cached as Map);
      rethrow;
    }
  }

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
