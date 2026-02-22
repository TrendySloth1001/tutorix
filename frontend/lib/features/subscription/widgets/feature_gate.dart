import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/theme/design_tokens.dart';
import '../screens/plan_selector_screen.dart';

/// Shows a paywall bottom sheet when a user tries to access a feature
/// locked behind a higher plan. Returns `true` if the user tapped Upgrade.
///
/// Usage:
/// ```dart
/// final upgraded = await FeatureGate.show(
///   context,
///   coachingId: coaching.id,
///   feature: 'Online Payments',
///   description: 'Accept payments online via Razorpay.',
///   requiredPlan: 'Standard',
///   icon: Icons.payment_rounded,
/// );
/// ```
class FeatureGate {
  FeatureGate._();

  /// Shows the upgrade bottom sheet. Returns `true` if user tapped Upgrade.
  static Future<bool> show(
    BuildContext context, {
    required String coachingId,
    required String feature,
    required String description,
    required String requiredPlan,
    IconData icon = Icons.lock_outline_rounded,
  }) async {
    HapticFeedback.mediumImpact();
    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _FeatureGateSheet(
        coachingId: coachingId,
        feature: feature,
        description: description,
        requiredPlan: requiredPlan,
        icon: icon,
      ),
    );
    return result ?? false;
  }

  /// Shows a quota-exceeded bottom sheet when the user has hit
  /// a resource limit (e.g., max students reached).
  static Future<bool> showQuotaExceeded(
    BuildContext context, {
    required String coachingId,
    required String resource,
    required int current,
    required int max,
  }) async {
    HapticFeedback.mediumImpact();
    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _QuotaExceededSheet(
        coachingId: coachingId,
        resource: resource,
        current: current,
        max: max,
      ),
    );
    return result ?? false;
  }
}

// ── Feature Gate Sheet ───────────────────────────────────────────────

class _FeatureGateSheet extends StatelessWidget {
  final String coachingId;
  final String feature;
  final String description;
  final String requiredPlan;
  final IconData icon;

  const _FeatureGateSheet({
    required this.coachingId,
    required this.feature,
    required this.description,
    required this.requiredPlan,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final bottom = MediaQuery.of(context).viewPadding.bottom;

    return Container(
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(Radii.xl),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            Spacing.sp24,
            Spacing.sp8,
            Spacing.sp24,
            bottom + Spacing.sp16,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Drag handle
              Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.only(bottom: Spacing.sp20),
                decoration: BoxDecoration(
                  color: cs.onSurface.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(Radii.full),
                ),
              ),

              // Locked icon
              Container(
                padding: const EdgeInsets.all(Spacing.sp16),
                decoration: BoxDecoration(
                  color: cs.primary.withValues(alpha: 0.08),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 32, color: cs.primary),
              ),
              const SizedBox(height: Spacing.sp16),

              // Feature name
              Text(
                feature,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: Spacing.sp8),

              // Description
              Text(
                description,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: cs.onSurface.withValues(alpha: 0.6),
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: Spacing.sp12),

              // Required plan badge
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: Spacing.sp12,
                  vertical: Spacing.sp8,
                ),
                decoration: BoxDecoration(
                  color: cs.tertiary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(Radii.full),
                  border: Border.all(color: cs.primary.withValues(alpha: 0.15)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.star_rounded, size: 16, color: cs.primary),
                    const SizedBox(width: Spacing.sp4),
                    Text(
                      'Available on $requiredPlan plan & above',
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: cs.primary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: Spacing.sp24),

              // Buttons
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () {
                    Navigator.pop(context, true);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) =>
                            PlanSelectorScreen(coachingId: coachingId),
                      ),
                    );
                  },
                  icon: const Icon(Icons.rocket_launch_rounded, size: 18),
                  label: const Text('Upgrade Now'),
                ),
              ),
              const SizedBox(height: Spacing.sp8),
              SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: Text(
                    'Maybe Later',
                    style: TextStyle(
                      color: cs.onSurface.withValues(alpha: 0.5),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Quota Exceeded Sheet ─────────────────────────────────────────────

class _QuotaExceededSheet extends StatelessWidget {
  final String coachingId;
  final String resource;
  final int current;
  final int max;

  const _QuotaExceededSheet({
    required this.coachingId,
    required this.resource,
    required this.current,
    required this.max,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final bottom = MediaQuery.of(context).viewPadding.bottom;

    return Container(
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(Radii.xl),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            Spacing.sp24,
            Spacing.sp8,
            Spacing.sp24,
            bottom + Spacing.sp16,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Drag handle
              Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.only(bottom: Spacing.sp20),
                decoration: BoxDecoration(
                  color: cs.onSurface.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(Radii.full),
                ),
              ),

              // Warning icon
              Container(
                padding: const EdgeInsets.all(Spacing.sp16),
                decoration: BoxDecoration(
                  color: cs.error.withValues(alpha: 0.08),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.warning_amber_rounded,
                  size: 32,
                  color: cs.error,
                ),
              ),
              const SizedBox(height: Spacing.sp16),

              Text(
                'Limit Reached',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: Spacing.sp8),

              Text(
                'You\'ve reached the maximum of $max $resource on your current plan ($current / $max used).',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: cs.onSurface.withValues(alpha: 0.6),
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: Spacing.sp8),

              Text(
                'Upgrade to add more.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: cs.primary,
                  fontWeight: FontWeight.w500,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: Spacing.sp24),

              // Progress bar
              ClipRRect(
                borderRadius: BorderRadius.circular(Radii.full),
                child: LinearProgressIndicator(
                  value: 1.0,
                  minHeight: 8,
                  backgroundColor: cs.outlineVariant.withValues(alpha: 0.2),
                  valueColor: AlwaysStoppedAnimation(cs.error),
                ),
              ),
              const SizedBox(height: Spacing.sp24),

              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () {
                    Navigator.pop(context, true);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) =>
                            PlanSelectorScreen(coachingId: coachingId),
                      ),
                    );
                  },
                  icon: const Icon(Icons.rocket_launch_rounded, size: 18),
                  label: const Text('Upgrade Plan'),
                ),
              ),
              const SizedBox(height: Spacing.sp8),
              SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: Text(
                    'Dismiss',
                    style: TextStyle(
                      color: cs.onSurface.withValues(alpha: 0.5),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
