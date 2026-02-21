import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/design_tokens.dart';

import '../../auth/controllers/auth_controller.dart';
import '../../../shared/models/notification_model.dart';
import '../../../shared/services/invitation_service.dart';
import '../../../shared/services/notification_service.dart';
import '../../../shared/widgets/accept_invite_sheet.dart';
import '../../../shared/widgets/app_alert.dart';
import '../../../shared/widgets/app_shimmer.dart';
import '../../../shared/widgets/invitation_card.dart';

class PersonalNotificationsScreen extends StatefulWidget {
  const PersonalNotificationsScreen({super.key});

  @override
  State<PersonalNotificationsScreen> createState() =>
      _PersonalNotificationsScreenState();
}

class _PersonalNotificationsScreenState
    extends State<PersonalNotificationsScreen> {
  final _notificationService = NotificationService();
  final _invitationService = InvitationService();
  final Set<String> _responding = {};

  List<dynamic> _items =
      []; // Combined list of NotificationModel and Invitation Maps
  bool _isLoading = true;
  int _unreadCount = 0;
  StreamSubscription? _notifSub;

  @override
  void initState() {
    super.initState();
    Future.microtask(_load);
  }

  @override
  void dispose() {
    _notifSub?.cancel();
    super.dispose();
  }

  void _load() {
    if (!mounted) return;
    final userId = context.read<AuthController>().user?.id;
    if (userId == null) return;

    setState(() => _isLoading = true);
    _notifSub?.cancel();
    _notifSub = _notificationService.watchUserNotifications().listen(
      (notifResult) async {
        if (!mounted) return;
        try {
          final notifications = (notifResult['notifications'] as List)
              .map((e) => NotificationModel.fromJson(e))
              .toList();

          final invitationsData = await _invitationService.getMyInvitations();
          final invitations = List<Map<String, dynamic>>.from(invitationsData);

          final combined = <dynamic>[...notifications, ...invitations];
          combined.sort((a, b) {
            DateTime dateA;
            if (a is NotificationModel) {
              dateA = a.createdAt;
            } else {
              dateA = DateTime.tryParse(a['createdAt'] ?? '') ?? DateTime.now();
            }
            DateTime dateB;
            if (b is NotificationModel) {
              dateB = b.createdAt;
            } else {
              dateB = DateTime.tryParse(b['createdAt'] ?? '') ?? DateTime.now();
            }
            return dateB.compareTo(dateA);
          });

          if (mounted) {
            setState(() {
              _items = combined;
              _unreadCount =
                  (notifResult['unreadCount'] ?? 0) + invitations.length;
              _isLoading = false;
            });
          }
        } catch (e) {
          if (mounted) {
            AppAlert.error(
              context,
              e,
              fallback: 'Failed to load notifications',
            );
            setState(() => _isLoading = false);
          }
        }
      },
      onError: (e) {
        if (mounted) {
          AppAlert.error(context, e, fallback: 'Failed to load notifications');
          setState(() => _isLoading = false);
        }
      },
    );
  }

  Future<void> _markAsRead(NotificationModel notification) async {
    if (notification.read) return;
    try {
      await _notificationService.markAsRead(notification.id);
      setState(() {
        _items = _items.map((item) {
          if (item is NotificationModel && item.id == notification.id) {
            return item.copyWith(read: true);
          }
          return item;
        }).toList();
        _unreadCount = (_unreadCount - 1).clamp(0, 999);
      });
    } catch (e) {
      // silent error
    }
  }

  Future<void> _archive(String id) async {
    try {
      // Optimistically remove from UI first
      bool wasUnread = false;
      setState(() {
        _items.removeWhere((item) {
          if (item is NotificationModel && item.id == id) {
            if (!item.read) wasUnread = true;
            return true;
          }
          return false;
        });
        if (wasUnread) _unreadCount = (_unreadCount - 1).clamp(0, 999);
      });

      // Then archive on backend
      await _notificationService.archiveNotification(id);
    } catch (e) {
      if (mounted) {
        _load(); // Reload on failure
        AppAlert.error(context, e, fallback: 'Failed to archive');
      }
    }
  }

  Future<void> _respond(
    String id,
    bool accept, {
    Map<String, dynamic>? invitation,
  }) async {
    // If accepting, show confirmation sheet first
    if (accept && invitation != null) {
      final coaching = invitation['coaching'] as Map<String, dynamic>?;
      final role = invitation['role'] as String? ?? 'STUDENT';
      final existingMemberships =
          ((invitation['existingMemberships'] as List<dynamic>?) ?? [])
              .cast<Map<String, dynamic>>();

      final confirmed = await showAcceptInviteSheet(
        context: context,
        coachingName: coaching?['name'] ?? 'this coaching',
        role: role,
        existingMemberships: existingMemberships,
      );
      if (confirmed != true) return;
    }

    setState(() => _responding.add(id));
    try {
      await _invitationService.respondToInvitation(id, accept);
      if (mounted) {
        AppAlert.success(
          context,
          accept ? 'Invitation accepted!' : 'Declined.',
        );
        // Refresh list to remove the processed invitation
        _load();
        // Also refresh global auth state to update pending count badge
        if (mounted) {
          context.read<AuthController>().refreshInvitations();
        }
      }
    } catch (e) {
      if (mounted) {
        AppAlert.error(context, e);
      }
    } finally {
      if (mounted) setState(() => _responding.remove(id));
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
        return theme.colorScheme.error;
      case 'INVITATION_ACCEPTED':
        return theme.colorScheme.primary;
      case 'NEW_MEMBER':
        return theme.colorScheme.secondary;
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
                margin: const EdgeInsets.only(right: Spacing.sp16),
                padding: const EdgeInsets.symmetric(
                  horizontal: Spacing.sp12,
                  vertical: Spacing.sp6,
                ),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(Radii.lg),
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
          ? const NotificationsShimmer()
          : _items.isEmpty
          ? RefreshIndicator(
              onRefresh: () async {
                _load();
                await Future.delayed(const Duration(milliseconds: 500));
              },
              child: CustomScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: [
                  SliverFillRemaining(
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsets.all(Spacing.sp40),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(Spacing.sp32),
                              decoration: BoxDecoration(
                                color: theme.colorScheme.tertiary.withValues(
                                  alpha: 0.1,
                                ),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                Icons.notifications_none_rounded,
                                size: 64,
                                color: theme.colorScheme.primary.withValues(
                                  alpha: 0.4,
                                ),
                              ),
                            ),
                            const SizedBox(height: Spacing.sp24),
                            Text(
                              'No Notifications',
                              style: theme.textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: Spacing.sp8),
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
                    ),
                  ),
                ],
              ),
            )
          : RefreshIndicator(
              onRefresh: () async {
                _load();
                await Future.delayed(const Duration(milliseconds: 500));
              },
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(vertical: Spacing.sp8),
                itemCount: _items.length,
                separatorBuilder: (_, _) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final item = _items[index];

                  // 1. Check if Invitation
                  if (item is Map<String, dynamic>) {
                    // It's an invitation
                    final id = item['id'] as String;
                    final isResponding = _responding.contains(id);

                    return Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: Spacing.sp16,
                        vertical: Spacing.sp8,
                      ),
                      child: InvitationCard(
                        invitation: item,
                        isResponding: isResponding,
                        onAccept: () => _respond(id, true, invitation: item),
                        onDecline: () => _respond(id, false),
                      ),
                    );
                  }

                  // 2. Otherwise it's a NotificationModel
                  final n = item as NotificationModel;
                  final iconData = _getIconForType(n.type);
                  final iconColor = _getColorForType(n.type, theme);

                  return Dismissible(
                    key: Key(n.id),
                    direction: DismissDirection.endToStart,
                    background: Container(
                      color: theme.colorScheme.surfaceContainerHighest,
                      alignment: Alignment.centerRight,
                      padding: const EdgeInsets.only(right: Spacing.sp24),
                      child: Icon(
                        Icons.archive_rounded,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    onDismissed: (_) => _archive(n.id),
                    child: Material(
                      color: n.read
                          ? Colors.transparent
                          : theme.colorScheme.primary.withValues(alpha: 0.05),
                      child: InkWell(
                        onTap: () => _markAsRead(n),
                        child: Padding(
                          padding: const EdgeInsets.all(Spacing.sp16),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                width: 48,
                                height: 48,
                                decoration: BoxDecoration(
                                  color: iconColor.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(Radii.md),
                                ),
                                child: Icon(
                                  iconData,
                                  color: iconColor,
                                  size: 24,
                                ),
                              ),
                              const SizedBox(width: Spacing.sp16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            n.title,
                                            style: theme.textTheme.titleSmall
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
                                              left: Spacing.sp8,
                                            ),
                                            decoration: BoxDecoration(
                                              color: theme.colorScheme.primary,
                                              shape: BoxShape.circle,
                                            ),
                                          ),
                                        const SizedBox(width: Spacing.sp8),
                                        GestureDetector(
                                          onTap: () => _archive(n.id),
                                          child: Icon(
                                            Icons.close_rounded,
                                            size: 20,
                                            color: theme
                                                .colorScheme
                                                .onSurfaceVariant
                                                .withValues(alpha: 0.5),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: Spacing.sp4),
                                    Text(
                                      n.message,
                                      style: theme.textTheme.bodyMedium,
                                      maxLines: 3,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: Spacing.sp8),
                                    Text(
                                      _formatTime(n.createdAt),
                                      style: theme.textTheme.labelSmall
                                          ?.copyWith(
                                            color: theme
                                                .colorScheme
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
