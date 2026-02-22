import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/error_strings.dart';
import '../../../core/theme/design_tokens.dart';
import '../../../core/services/error_logger_service.dart';
import '../../auth/controllers/auth_controller.dart';
import '../../../shared/services/invitation_service.dart';
import '../../../shared/widgets/accept_invite_sheet.dart';
import '../../../shared/widgets/app_alert.dart';
import '../../../shared/widgets/app_shimmer.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  final _invitationService = InvitationService();
  List<Map<String, dynamic>> _invitations = [];
  bool _loading = true;
  final Set<String> _responding = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      _invitations = await _invitationService.getMyInvitations();
    } catch (e, stack) {
      ErrorLoggerService.instance.error(
        'Failed to load invitations',
        category: LogCategory.api,
        error: e,
        stackTrace: stack,
      );
    }
    if (mounted) setState(() => _loading = false);
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
          accept ? MemberSuccess.accepted : MemberSuccess.declined,
        );
        _load();
        context.read<AuthController>().refreshInvitations();
      }
    } catch (e) {
      if (mounted) {
        AppAlert.error(context, e, fallback: MemberErrors.acceptFailed);
      }
    } finally {
      if (mounted) setState(() => _responding.remove(id));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Notifications'), centerTitle: true),
      body: _loading
          ? const NotificationsShimmer()
          : _invitations.isEmpty
          ? _buildEmpty(theme)
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView.separated(
                padding: const EdgeInsets.all(Spacing.sp16),
                itemCount: _invitations.length,
                separatorBuilder: (_, _) =>
                    const SizedBox(height: Spacing.sp10),
                itemBuilder: (_, i) => _buildCard(theme, _invitations[i]),
              ),
            ),
    );
  }

  Widget _buildEmpty(ThemeData theme) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.notifications_off_outlined,
            size: 56,
            color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.3),
          ),
          const SizedBox(height: Spacing.sp12),
          Text(
            "You're all caught up!",
            style: theme.textTheme.titleSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCard(ThemeData theme, Map<String, dynamic> inv) {
    final coaching = inv['coaching'] as Map<String, dynamic>?;
    final invitedBy = inv['invitedBy'] as Map<String, dynamic>?;
    final ward = inv['ward'] as Map<String, dynamic>?;
    final role = inv['role'] as String? ?? 'STUDENT';
    final message = inv['message'] as String?;
    final id = inv['id'] as String;
    final busy = _responding.contains(id);

    return Container(
      padding: const EdgeInsets.all(Spacing.sp14),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(Radii.md),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: theme.colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(Radii.md),
                ),
                child: Icon(
                  Icons.mail_rounded,
                  color: theme.colorScheme.primary,
                  size: 20,
                ),
              ),
              const SizedBox(width: Spacing.sp10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Invitation to ${coaching?['name'] ?? 'a coaching'}',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      'From ${invitedBy?['name'] ?? 'Someone'} • $role',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          if (ward != null) ...[
            const SizedBox(height: Spacing.sp8),
            Row(
              children: [
                Icon(
                  Icons.child_care_rounded,
                  size: 14,
                  color: theme.colorScheme.secondary,
                ),
                const SizedBox(width: Spacing.sp4),
                Text(
                  'For: ${ward['name']}',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.secondary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ],

          if (message != null && message.isNotEmpty) ...[
            const SizedBox(height: Spacing.sp6),
            Text(
              '"$message"',
              style: theme.textTheme.bodySmall?.copyWith(
                fontStyle: FontStyle.italic,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],

          const SizedBox(height: Spacing.sp12),

          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: busy ? null : () => _respond(id, false),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: theme.colorScheme.error,
                    side: BorderSide(color: theme.colorScheme.error),
                    visualDensity: VisualDensity.compact,
                  ),
                  child: const Text('Decline'),
                ),
              ),
              const SizedBox(width: Spacing.sp10),
              Expanded(
                child: FilledButton(
                  onPressed: busy
                      ? null
                      : () => _respond(id, true, invitation: inv),
                  style: FilledButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                  ),
                  child: busy
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text('Accept'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
