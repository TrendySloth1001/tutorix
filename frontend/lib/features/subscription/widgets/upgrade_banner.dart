import 'package:flutter/material.dart';
import '../../../core/theme/design_tokens.dart';
import '../screens/plan_selector_screen.dart';

/// A compact inline banner that can be placed in any screen
/// to prompt the coaching owner to upgrade.
///
/// ```dart
/// UpgradeBanner(
///   coachingId: coaching.id,
///   message: 'Unlock auto-reminders with the Standard plan',
/// )
/// ```
class UpgradeBanner extends StatelessWidget {
  final String coachingId;
  final String message;
  final String buttonLabel;

  const UpgradeBanner({
    super.key,
    required this.coachingId,
    required this.message,
    this.buttonLabel = 'Upgrade',
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.all(Spacing.sp16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            cs.primary.withValues(alpha: 0.06),
            cs.primary.withValues(alpha: 0.02),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(Radii.lg),
        border: Border.all(color: cs.primary.withValues(alpha: 0.15)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(Spacing.sp8),
            decoration: BoxDecoration(
              color: cs.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(Radii.sm),
            ),
            child: Icon(
              Icons.rocket_launch_rounded,
              size: 18,
              color: cs.primary,
            ),
          ),
          const SizedBox(width: Spacing.sp12),
          Expanded(
            child: Text(
              message,
              style: theme.textTheme.bodySmall?.copyWith(
                color: cs.onSurface.withValues(alpha: 0.7),
                height: 1.3,
              ),
            ),
          ),
          const SizedBox(width: Spacing.sp8),
          FilledButton(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => PlanSelectorScreen(coachingId: coachingId),
              ),
            ),
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(
                horizontal: Spacing.sp16,
                vertical: Spacing.sp8,
              ),
              textStyle: theme.textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            child: Text(buttonLabel),
          ),
        ],
      ),
    );
  }
}
