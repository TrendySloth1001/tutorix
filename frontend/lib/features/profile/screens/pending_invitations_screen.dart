import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../auth/controllers/auth_controller.dart';

import '../../../shared/services/invitation_service.dart';
import '../../../shared/widgets/accept_invite_sheet.dart';
import '../../../shared/widgets/app_alert.dart';
import '../../../shared/widgets/invitation_card.dart';

class PendingInvitationsScreen extends StatefulWidget {
  const PendingInvitationsScreen({super.key});

  @override
  State<PendingInvitationsScreen> createState() =>
      _PendingInvitationsScreenState();
}

class _PendingInvitationsScreenState extends State<PendingInvitationsScreen> {
  final _invitationService = InvitationService();
  final Set<String> _responding = {};

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
        await context.read<AuthController>().refreshInvitations();
      }
    } catch (e) {
      if (mounted) {
        AppAlert.error(context, e);
      }
    } finally {
      if (mounted) setState(() => _responding.remove(id));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final auth = context.watch<AuthController>();
    final invitations = auth.pendingInvitations;

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 40),

              // Header
              Icon(
                Icons.mail_rounded,
                size: 48,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(height: 16),
              Text(
                'You have invitations!',
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Someone invited you to join their coaching. Review below.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),

              const SizedBox(height: 28),

              // Invitation list
              Expanded(
                child: ListView.separated(
                  itemCount: invitations.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 12),
                  itemBuilder: (_, i) => _buildCard(theme, invitations[i]),
                ),
              ),

              // Skip button
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: SizedBox(
                  width: double.infinity,
                  child: TextButton(
                    onPressed: () => auth.dismissInvitations(),
                    child: const Text('Skip for now'),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCard(ThemeData theme, Map<String, dynamic> inv) {
    final id = inv['id'] as String;
    final isResponding = _responding.contains(id);

    return InvitationCard(
      invitation: inv,
      isResponding: isResponding,
      onAccept: () => _respond(id, true, invitation: inv),
      onDecline: () => _respond(id, false),
    );
  }
}
