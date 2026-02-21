import 'package:flutter/material.dart';
import '../../../shared/services/invitation_service.dart';
import '../../../shared/widgets/accept_invite_sheet.dart';
import '../../../shared/widgets/app_alert.dart';
import '../../../shared/widgets/app_shimmer.dart';

class MyInvitationsScreen extends StatefulWidget {
  const MyInvitationsScreen({super.key});

  @override
  State<MyInvitationsScreen> createState() => _MyInvitationsScreenState();
}

class _MyInvitationsScreenState extends State<MyInvitationsScreen> {
  final InvitationService _invitationService = InvitationService();
  List<Map<String, dynamic>> _invitations = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadInvitations();
  }

  Future<void> _loadInvitations() async {
    setState(() => _isLoading = true);
    try {
      final invitations = await _invitationService.getMyInvitations();
      if (mounted) {
        setState(() {
          _invitations = invitations;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _respondToInvitation(
    String invitationId,
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

    try {
      await _invitationService.respondToInvitation(invitationId, accept);
      if (mounted) {
        AppAlert.success(
          context,
          accept ? 'Invitation accepted!' : 'Invitation declined.',
        );
        _loadInvitations();
      }
    } catch (e) {
      if (mounted) {
        AppAlert.error(context, e);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('My Invitations'), centerTitle: true),
      body: _isLoading
          ? const InvitationsShimmer()
          : _invitations.isEmpty
          ? _buildEmptyState(theme)
          : RefreshIndicator(
              onRefresh: _loadInvitations,
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: _invitations.length,
                itemBuilder: (context, index) =>
                    _buildInvitationCard(theme, _invitations[index]),
              ),
            ),
    );
  }

  Widget _buildEmptyState(ThemeData theme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.mail_outline_rounded,
            size: 64,
            color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
          ),
          const SizedBox(height: 16),
          Text(
            'No Pending Invitations',
            style: theme.textTheme.titleMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'You\'re all caught up!',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInvitationCard(
    ThemeData theme,
    Map<String, dynamic> invitation,
  ) {
    final coaching = invitation['coaching'] as Map<String, dynamic>?;
    final invitedBy = invitation['invitedBy'] as Map<String, dynamic>?;
    final ward = invitation['ward'] as Map<String, dynamic>?;
    final role = invitation['role'] as String? ?? 'STUDENT';
    final message = invitation['message'] as String?;
    final id = invitation['id'] as String;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 0,
      color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Coaching info
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.school_rounded,
                    color: theme.colorScheme.primary,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        coaching?['name'] ?? 'Unknown Coaching',
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'Invited by ${invitedBy?['name'] ?? 'Someone'}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                _roleChip(role, theme),
              ],
            ),

            // Ward info if applicable
            if (ward != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: theme.colorScheme.secondaryContainer.withValues(
                    alpha: 0.3,
                  ),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.child_care_rounded,
                      size: 18,
                      color: theme.colorScheme.secondary,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'For: ${ward['name']}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: theme.colorScheme.secondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],

            // Message
            if (message != null && message.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                '"$message"',
                style: theme.textTheme.bodySmall?.copyWith(
                  fontStyle: FontStyle.italic,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],

            const SizedBox(height: 16),

            // Action buttons
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => _respondToInvitation(id, false),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: theme.colorScheme.error,
                      side: BorderSide(color: theme.colorScheme.error),
                    ),
                    child: const Text('Decline'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    onPressed: () =>
                        _respondToInvitation(id, true, invitation: invitation),
                    child: const Text('Accept'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _roleChip(String role, ThemeData theme) {
    Color color;
    switch (role) {
      case 'TEACHER':
        color = theme.colorScheme.secondary;
        break;
      case 'PARENT':
        color = theme.colorScheme.secondary;
        break;
      default:
        color = theme.colorScheme.secondary;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        role,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
