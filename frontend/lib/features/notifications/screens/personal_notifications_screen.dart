import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../shared/models/notification_model.dart';
import '../../../shared/services/notification_service.dart';

class PersonalNotificationsScreen extends StatefulWidget {
  const PersonalNotificationsScreen({super.key});

  @override
  State<PersonalNotificationsScreen> createState() =>
      _PersonalNotificationsScreenState();
}

class _PersonalNotificationsScreenState
    extends State<PersonalNotificationsScreen> {
  final _notificationService = NotificationService();
  List<NotificationModel> _notifications = [];
  bool _isLoading = true;
  String? _error;
  int _unreadCount = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    try {
      final result = await _notificationService.getUserNotifications();
      final list = (result['notifications'] as List)
          .map((e) => NotificationModel.fromJson(e))
          .toList();
      setState(() {
        _notifications = list;
        _unreadCount = result['unreadCount'] ?? 0;
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _markAsRead(NotificationModel notification) async {
    if (notification.read) return;
    try {
      await _notificationService.markAsRead(notification.id);
      setState(() {
        _notifications = _notifications.map((n) {
          if (n.id == notification.id) return n.copyWith(read: true);
          return n;
        }).toList();
        _unreadCount = (_unreadCount - 1).clamp(0, 999);
      });
    } catch (e) {
      // silent error
    }
  }

  Future<void> _delete(String id) async {
    try {
      await _notificationService.deleteNotification(id);
      setState(() {
        final wasUnread =
            _notifications.firstWhere((n) => n.id == id).read == false;
        _notifications.removeWhere((n) => n.id == id);
        if (wasUnread) _unreadCount = (_unreadCount - 1).clamp(0, 999);
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to delete: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  String _formatTime(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);

    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return DateFormat.MMMd().format(dt);
  }

  IconData _getIconForType(String type) {
    switch (type) {
      case 'REMOVED_FROM_COACHING':
      case 'WARD_REMOVED_FROM_COACHING':
        return Icons.person_remove_rounded;
      case 'INVITATION_ACCEPTED':
        return Icons.check_circle_rounded;
      case 'NEW_MEMBER':
        return Icons.person_add_rounded;
      default:
        return Icons.notifications_rounded;
    }
  }

  Color _getColorForType(String type, ThemeData theme) {
    switch (type) {
      case 'REMOVED_FROM_COACHING':
      case 'WARD_REMOVED_FROM_COACHING':
        return Colors.red;
      case 'INVITATION_ACCEPTED':
        return Colors.green;
      case 'NEW_MEMBER':
        return Colors.blue;
      default:
        return theme.colorScheme.primary;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        backgroundColor: theme.colorScheme.surface,
        elevation: 0,
        actions: [
          if (_unreadCount > 0)
            Center(
              child: Container(
                margin: const EdgeInsets.only(right: 16),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '$_unreadCount unread',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.error_outline,
                          size: 48,
                          color: theme.colorScheme.error.withValues(alpha: 0.5)),
                      const SizedBox(height: 16),
                      Text('Error: $_error'),
                      const SizedBox(height: 16),
                      TextButton.icon(
                        onPressed: _load,
                        icon: const Icon(Icons.refresh),
                        label: const Text('Retry'),
                      ),
                    ],
                  ),
                )
              : _notifications.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(40),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(32),
                              decoration: BoxDecoration(
                                color: theme.colorScheme.tertiary
                                    .withValues(alpha: 0.1),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                Icons.notifications_none_rounded,
                                size: 64,
                                color: theme.colorScheme.primary
                                    .withValues(alpha: 0.4),
                              ),
                            ),
                            const SizedBox(height: 24),
                            Text(
                              'No Notifications',
                              style: theme.textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'You\'re all caught up!',
                              textAlign: TextAlign.center,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _load,
                      child: ListView.separated(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        itemCount: _notifications.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (context, index) {
                          final n = _notifications[index];
                          final iconData = _getIconForType(n.type);
                          final iconColor = _getColorForType(n.type, theme);

                          return Dismissible(
                            key: Key(n.id),
                            direction: DismissDirection.endToStart,
                            background: Container(
                              color: Colors.red,
                              alignment: Alignment.centerRight,
                              padding: const EdgeInsets.only(right: 24),
                              child: const Icon(Icons.delete_rounded,
                                  color: Colors.white),
                            ),
                            onDismissed: (_) => _delete(n.id),
                            child: Material(
                              color: n.read
                                  ? Colors.transparent
                                  : theme.colorScheme.primary
                                      .withValues(alpha: 0.05),
                              child: InkWell(
                                onTap: () => _markAsRead(n),
                                child: Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Container(
                                        width: 48,
                                        height: 48,
                                        decoration: BoxDecoration(
                                          color: iconColor.withValues(alpha: 0.1),
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        child: Icon(iconData,
                                            color: iconColor, size: 24),
                                      ),
                                      const SizedBox(width: 16),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              children: [
                                                Expanded(
                                                  child: Text(
                                                    n.title,
                                                    style: theme
                                                        .textTheme.titleSmall
                                                        ?.copyWith(
                                                      fontWeight: n.read
                                                          ? FontWeight.w500
                                                          : FontWeight.bold,
                                                    ),
                                                    maxLines: 2,
                                                    overflow: TextOverflow.ellipsis,
                                                  ),
                                                ),
                                                if (!n.read)
                                                  Container(
                                                    width: 8,
                                                    height: 8,
                                                    margin: const EdgeInsets.only(
                                                        left: 8),
                                                    decoration: BoxDecoration(
                                                      color: theme
                                                          .colorScheme.primary,
                                                      shape: BoxShape.circle,
                                                    ),
                                                  ),
                                              ],
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              n.message,
                                              style:
                                                  theme.textTheme.bodyMedium,
                                              maxLines: 3,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                            const SizedBox(height: 8),
                                            Text(
                                              _formatTime(n.createdAt),
                                              style: theme.textTheme.labelSmall
                                                  ?.copyWith(
                                                color: theme.colorScheme
                                                    .onSurfaceVariant
                                                    .withValues(alpha: 0.6),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
    );
  }
}
