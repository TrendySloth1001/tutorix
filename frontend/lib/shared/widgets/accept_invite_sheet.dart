import 'package:flutter/material.dart';
import '../../core/theme/design_tokens.dart';

/// Shows a confirmation bottom sheet before accepting an invitation.
/// If the user has existing coaching memberships, warns them that those
/// coachings will be notified. Returns `true` if confirmed, `null` if dismissed.
Future<bool?> showAcceptInviteSheet({
  required BuildContext context,
  required String coachingName,
  required String role,
  required List<Map<String, dynamic>> existingMemberships,
}) {
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _AcceptInviteSheet(
      coachingName: coachingName,
      role: role,
      existingMemberships: existingMemberships,
    ),
  );
}

class _AcceptInviteSheet extends StatelessWidget {
  final String coachingName;
  final String role;
  final List<Map<String, dynamic>> existingMemberships;

  const _AcceptInviteSheet({
    required this.coachingName,
    required this.role,
    required this.existingMemberships,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasExisting = existingMemberships.isNotEmpty;

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(Radii.xl),
        ),
      ),
      padding: const EdgeInsets.fromLTRB(
        Spacing.sp24,
        Spacing.sp12,
        Spacing.sp24,
        Spacing.sp32,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(Radii.sm),
            ),
          ),
          const SizedBox(height: Spacing.sp20),

          // Icon
          Container(
            padding: const EdgeInsets.all(Spacing.sp16),
            decoration: BoxDecoration(
              color: theme.colorScheme.primaryContainer.withValues(alpha: 0.5),
              shape: BoxShape.circle,
            ),
            child: Icon(
              hasExisting
                  ? Icons.swap_horiz_rounded
                  : Icons.check_circle_outline_rounded,
              size: 32,
              color: theme.colorScheme.primary,
            ),
          ),
          const SizedBox(height: Spacing.sp16),

          // Title
          Text(
            hasExisting ? 'Join $coachingName?' : 'Accept Invitation',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: Spacing.sp6),

          // Subtitle
          Text(
            'You\'ll be joining as ${role[0] + role.substring(1).toLowerCase()}',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),

          // Existing memberships warning
          if (hasExisting) ...[
            const SizedBox(height: Spacing.sp20),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(Spacing.sp14),
              decoration: BoxDecoration(
                color: Colors.amber.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(Radii.md),
                border: Border.all(color: Colors.amber.withValues(alpha: 0.25)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.info_outline_rounded,
                        size: 16,
                        color: Colors.amber[800],
                      ),
                      const SizedBox(width: Spacing.sp8),
                      Text(
                        'You\'re already in ${existingMemberships.length == 1 ? 'a coaching' : '${existingMemberships.length} coachings'}',
                        style: TextStyle(
                          fontSize: FontSize.caption,
                          fontWeight: FontWeight.w700,
                          color: Colors.amber[900],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: Spacing.sp10),
                  ...existingMemberships.map(
                    (m) => Padding(
                      padding: const EdgeInsets.only(bottom: Spacing.sp4),
                      child: Row(
                        children: [
                          Icon(
                            Icons.school_rounded,
                            size: 14,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                          const SizedBox(width: Spacing.sp8),
                          Expanded(
                            child: Text(
                              '${m['coachingName']}',
                              style: theme.textTheme.bodySmall?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: Spacing.sp6,
                              vertical: Spacing.sp2,
                            ),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.secondaryContainer
                                  .withValues(alpha: 0.5),
                              borderRadius: BorderRadius.circular(Radii.sm),
                            ),
                            child: Text(
                              (m['role'] as String? ?? '').toLowerCase(),
                              style: TextStyle(
                                fontSize: FontSize.nano,
                                fontWeight: FontWeight.w600,
                                color: theme.colorScheme.secondary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: Spacing.sp8),
                  Text(
                    'These coachings will be notified and may take action, such as updating your role or removing your membership.',
                    style: TextStyle(
                      fontSize: FontSize.micro,
                      height: 1.4,
                      color: Colors.amber[900]?.withValues(alpha: 0.8),
                    ),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: Spacing.sp24),

          // Accept button
          SizedBox(
            width: double.infinity,
            height: 48,
            child: FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(
                hasExisting ? 'Accept & Notify' : 'Accept Invitation',
              ),
            ),
          ),
          const SizedBox(height: Spacing.sp8),

          // Cancel
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancel',
              style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
            ),
          ),
        ],
      ),
    );
  }
}
