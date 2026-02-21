import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../../shared/models/notification_model.dart';
import '../../../../shared/services/notification_service.dart';
import '../../../../shared/widgets/app_alert.dart';
import '../../../../shared/widgets/app_shimmer.dart';
import '../services/member_service.dart';
import '../../../core/theme/design_tokens.dart';

class CoachingNotificationsScreen extends StatefulWidget {
  final String coachingId;
  const CoachingNotificationsScreen({super.key, required this.coachingId});

  @override
  State<CoachingNotificationsScreen> createState() =>
      _CoachingNotificationsScreenState();
}

class _CoachingNotificationsScreenState
    extends State<CoachingNotificationsScreen> {
  final _allowNotifications = NotificationService();
  final _memberService = MemberService();
  // Note: Member removal usually in MemberService or CoachingService

  List<NotificationModel> _notifications = [];
  bool _isLoading = true;
  StreamSubscription? _sub;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  void _load() {
    setState(() => _isLoading = true);
    _sub?.cancel();
    _sub = _allowNotifications
        .watchCoachingNotifications(widget.coachingId)
        .listen(
          (result) {
            if (!mounted) return;
            final list = (result['notifications'] as List)
                .map((e) => NotificationModel.fromJson(e))
                .toList();
            setState(() {
              _notifications = list;
              _isLoading = false;
            });
          },
          onError: (e) {
            if (mounted) {
              AppAlert.error(
                context,
                e,
                fallback: 'Failed to load notifications',
              );
              setState(() => _isLoading = false);
            }
          },
        );
  }

  Future<void> _markAsRead(NotificationModel notification) async {
    if (notification.read) return;
    try {
      await _allowNotifications.markAsRead(notification.id);
      setState(() {
        _notifications = _notifications.map((n) {
          if (n.id == notification.id) return n.copyWith(read: true);
          return n;
        }).toList();
      });
    } catch (e) {
      // shelf silent error
    }
  }

  Future<void> _archive(String id) async {
    try {
      // Optimistically remove from UI first for better UX
      setState(() {
        _notifications.removeWhere((n) => n.id == id);
      });

      // Then archive on backend
      await _allowNotifications.archiveNotification(id);
    } catch (e) {
      if (mounted) {
        // If archive fails, reload to get accurate state
        _load();
        AppAlert.error(context, e, fallback: 'Failed to archive');
      }
    }
  }

  Future<void> _removeMember(String memberId, String notificationId) async {
    final theme = Theme.of(context);

    // Show bottom sheet with options
    final action = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: EdgeInsets.fromLTRB(
          Spacing.sp24,
          Spacing.sp24,
          Spacing.sp24,
          Spacing.sp24 + MediaQuery.of(ctx).viewPadding.bottom,
        ),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: const BorderRadius.vertical(
            top: Radius.circular(Radii.xl),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: Spacing.sp20),
              decoration: BoxDecoration(
                color: theme.colorScheme.onSurfaceVariant.withValues(
                  alpha: 0.3,
                ),
                borderRadius: BorderRadius.circular(Radii.sm),
              ),
            ),
            Icon(
              Icons.warning_amber_rounded,
              size: 48,
              color: theme.colorScheme.secondary,
            ),
            const SizedBox(height: Spacing.sp16),
            Text(
              'Member in Another Coaching',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: Spacing.sp8),
            Text(
              'This member has joined another coaching. What would you like to do?',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: Spacing.sp32),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () => Navigator.pop(ctx, 'ok'),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: Spacing.sp16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(Radii.lg),
                  ),
                ),
                child: const Text('It\'s OK'),
              ),
            ),
            const SizedBox(height: Spacing.sp12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => Navigator.pop(ctx, 'remove'),
                icon: const Icon(Icons.person_remove_rounded, size: 20),
                label: const Text('Remove Membership'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: theme.colorScheme.error,
                  side: BorderSide(color: theme.colorScheme.error, width: 1.5),
                  padding: const EdgeInsets.symmetric(vertical: Spacing.sp16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(Radii.lg),
                  ),
                ),
              ),
            ),
            const SizedBox(height: Spacing.sp16),
          ],
        ),
      ),
    );

    if (action == 'remove') {
      try {
        await _memberService.removeMember(widget.coachingId, memberId);

        if (mounted) {
          // Archive the notification immediately from UI
          await _archive(notificationId);
        }

        if (mounted) {
          AppAlert.success(
            context,
            'Member removed successfully. They have been notified.',
          );
        }
      } catch (e) {
        if (mounted) {
          AppAlert.error(context, e, fallback: 'Failed to remove member');
        }
      }
    } else if (action == 'ok') {
      // Archive notification immediately when user dismisses
      if (mounted) {
        await _archive(notificationId);
      }
      if (mounted) {
        AppAlert.success(context, 'Notification dismissed');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Notifications'), centerTitle: true),
      body: _isLoading
          ? const NotificationsShimmer()
          : _notifications.isEmpty
          ? const Center(child: Text('No notifications'))
          : ListView.separated(
              padding: const EdgeInsets.all(Spacing.sp16),
              itemCount: _notifications.length,
              separatorBuilder: (_, _) => const SizedBox(height: Spacing.sp12),
              itemBuilder: (context, index) {
                final n = _notifications[index];
                return _buildNotificationItem(n);
              },
            ),
    );
  }

  Widget _buildNotificationItem(NotificationModel n) {
    final theme = Theme.of(context);
    final isJoinAlert = n.type == 'MEMBER_JOINED_ANOTHER_COACHING';

    return Dismissible(
      key: Key(n.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: Spacing.sp20),
        color: theme.colorScheme.surfaceContainerHighest,
        child: Icon(
          Icons.archive_rounded,
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
      onDismissed: (_) => _archive(n.id),
      child: Card(
        elevation: 0,
        color: n.read
            ? theme.colorScheme.surface
            : theme.colorScheme.primaryContainer.withValues(alpha: 0.1),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Radii.md),
          side: n.read
              ? BorderSide(color: theme.colorScheme.outlineVariant)
              : BorderSide.none,
        ),
        child: InkWell(
          onTap: () => _markAsRead(n),
          borderRadius: BorderRadius.circular(Radii.md),
          child: Padding(
            padding: const EdgeInsets.all(Spacing.sp16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(Spacing.sp8),
                      decoration: BoxDecoration(
                        color: isJoinAlert
                            ? Colors.amber.shade100
                            : theme.colorScheme.surfaceContainerHighest,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        isJoinAlert
                            ? Icons.warning_amber_rounded
                            : Icons.notifications_none_rounded,
                        size: 20,
                        color: isJoinAlert
                            ? Colors.amber.shade800
                            : theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(width: Spacing.sp12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Text(
                                  n.title,
                                  style: theme.textTheme.titleSmall?.copyWith(
                                    fontWeight: n.read
                                        ? FontWeight.normal
                                        : FontWeight.bold,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: Spacing.sp8),
                              Text(
                                _formatDate(n.createdAt),
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                  fontSize: FontSize.nano,
                                ),
                              ),
                              const SizedBox(width: Spacing.sp8),
                              GestureDetector(
                                onTap: () => _archive(n.id),
                                child: Icon(
                                  Icons.close_rounded,
                                  size: 20,
                                  color: theme.colorScheme.onSurfaceVariant
                                      .withValues(alpha: 0.5),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: Spacing.sp4),
                          Text(
                            n.message,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                if (isJoinAlert &&
                    n.data != null &&
                    n.data!['memberId'] != null) ...[
                  const SizedBox(height: Spacing.sp12),
                  Padding(
                    padding: const EdgeInsets.only(left: Spacing.sp48),
                    child: Row(
                      children: [
                        OutlinedButton.icon(
                          onPressed: () =>
                              _removeMember(n.data!['memberId'], n.id),
                          icon: const Icon(
                            Icons.person_remove_rounded,
                            size: 16,
                          ),
                          label: const Text('Remove Member'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: theme.colorScheme.error,
                            side: BorderSide(color: theme.colorScheme.error),
                            visualDensity: VisualDensity.compact,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _formatDate(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);

    if (diff.inDays == 0) {
      if (diff.inHours == 0) {
        return '${diff.inMinutes}m ago';
      }
      return '${diff.inHours}h ago';
    } else if (diff.inDays < 7) {
      return '${diff.inDays}d ago';
    } else {
      return DateFormat('MMM d').format(dt);
    }
  }
}
