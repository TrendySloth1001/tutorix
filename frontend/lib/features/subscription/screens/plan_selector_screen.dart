import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/theme/design_tokens.dart';
import '../models/plan_model.dart';
import '../models/subscription_model.dart';
import '../models/usage_model.dart';
import '../services/subscription_service.dart';
import 'plan_detail_screen.dart';

/// Plan selector screen — shows all available tiers with pricing,
/// feature comparison, and a subscribe CTA.
class PlanSelectorScreen extends StatefulWidget {
  final String coachingId;
  final String? currentPlanSlug;

  const PlanSelectorScreen({
    super.key,
    required this.coachingId,
    this.currentPlanSlug,
  });

  @override
  State<PlanSelectorScreen> createState() => _PlanSelectorScreenState();
}

class _PlanSelectorScreenState extends State<PlanSelectorScreen> {
  final _service = SubscriptionService.instance;

  List<PlanModel> _plans = [];
  SubscriptionModel? _subscription;
  UsageModel? _usage;
  bool _isLoading = true;
  String? _error;
  bool _yearly = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final results = await Future.wait([
        _service.getPlans(),
        _service.getSubscription(widget.coachingId),
      ]);
      final plans = results[0] as List<PlanModel>;
      final sub =
          results[1] as ({SubscriptionModel subscription, UsageModel usage});
      if (!mounted) return;
      setState(() {
        _plans = plans..sort((a, b) => a.order.compareTo(b.order));
        _subscription = sub.subscription;
        _usage = sub.usage;
        _yearly = _subscription?.billingCycle == 'YEARLY';
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  void _openPlanDetail(PlanModel plan) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PlanDetailScreen(
          plan: plan,
          coachingId: widget.coachingId,
          yearly: _yearly,
        ),
      ),
    ).then((result) {
      if (result == true && mounted) {
        _load(); // Refresh after successful subscription
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Choose Plan'), centerTitle: true),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(Spacing.sp24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.cloud_off_rounded, size: 48, color: cs.error),
                    const SizedBox(height: Spacing.sp16),
                    Text(
                      'Could not load plans',
                      style: theme.textTheme.titleMedium,
                    ),
                    const SizedBox(height: Spacing.sp8),
                    FilledButton.icon(
                      onPressed: _load,
                      icon: const Icon(Icons.refresh_rounded, size: 18),
                      label: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(
                Spacing.sp16,
                Spacing.sp8,
                Spacing.sp16,
                Spacing.sp48,
              ),
              children: [
                _buildBillingToggle(theme),
                const SizedBox(height: Spacing.sp24),
                for (final plan in _plans) ...[
                  _PlanCard(
                    plan: plan,
                    yearly: _yearly,
                    isCurrent: _subscription?.plan?.slug == plan.slug,
                    usage: _usage,
                    isSubscribing: false,
                    onSubscribe: () => _openPlanDetail(plan),
                  ),
                  const SizedBox(height: Spacing.sp16),
                ],
                _buildEnterpriseCta(theme),
                const SizedBox(height: Spacing.sp24),
                _buildFeatureComparison(theme),
              ],
            ),
    );
  }

  Widget _buildBillingToggle(ThemeData theme) {
    final cs = theme.colorScheme;
    return Container(
      padding: const EdgeInsets.all(Spacing.sp4),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(Radii.md),
      ),
      child: Row(
        children: [
          Expanded(
            child: _TogglePill(
              label: 'Monthly',
              selected: !_yearly,
              onTap: () {
                HapticFeedback.selectionClick();
                setState(() => _yearly = false);
              },
            ),
          ),
          Expanded(
            child: _TogglePill(
              label: 'Yearly',
              badge: 'Save 20%',
              selected: _yearly,
              onTap: () {
                HapticFeedback.selectionClick();
                setState(() => _yearly = true);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEnterpriseCta(ThemeData theme) {
    final cs = theme.colorScheme;
    return Container(
      padding: const EdgeInsets.all(Spacing.sp20),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(Radii.lg),
        border: Border.all(color: cs.primary.withValues(alpha: 0.12)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(Spacing.sp10),
            decoration: BoxDecoration(
              color: cs.tertiary.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(Radii.md),
            ),
            child: Icon(Icons.business_rounded, color: cs.primary, size: 24),
          ),
          const SizedBox(width: Spacing.sp16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Enterprise',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: Spacing.sp4),
                Text(
                  "1000+ students? Let's talk.",
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: cs.onSurface.withValues(alpha: 0.6),
                  ),
                ),
              ],
            ),
          ),
          OutlinedButton(
            onPressed: () {
              launchUrl(
                Uri.parse(
                  'mailto:support@tutorix.in?subject=Enterprise%20Plan',
                ),
                mode: LaunchMode.externalApplication,
              );
            },
            child: const Text('Contact Us'),
          ),
        ],
      ),
    );
  }

  Widget _buildFeatureComparison(ThemeData theme) {
    final cs = theme.colorScheme;
    if (_plans.isEmpty) return const SizedBox.shrink();

    // Exclude the Web Portal plan from the comparison table — it's a separate
    // product and would make the table too wide for no benefit.
    final comparePlans = _plans.where((p) => !p.isWebPortal).toList();
    if (comparePlans.isEmpty) return const SizedBox.shrink();

    final features = <(String label, List<String> values)>[
      (
        'Students',
        comparePlans.map((p) => p.formatQuota(p.maxStudents)).toList(),
      ),
      (
        'Teachers',
        comparePlans.map((p) => p.formatQuota(p.maxTeachers)).toList(),
      ),
      (
        'Batches',
        comparePlans.map((p) => p.formatQuota(p.maxBatches)).toList(),
      ),
      ('Storage', comparePlans.map((p) => p.storageLabel).toList()),
      (
        'Assessments/mo',
        comparePlans
            .map((p) => p.formatQuota(p.maxAssessmentsPerMonth))
            .toList(),
      ),
      (
        'Online Pay',
        comparePlans.map((p) => p.hasRazorpay ? '\u2713' : '\u2014').toList(),
      ),
      (
        'Auto Remind',
        comparePlans.map((p) => p.hasAutoRemind ? '\u2713' : '\u2014').toList(),
      ),
      (
        'Fee Reports',
        comparePlans.map((p) => p.hasFeeReports ? '\u2713' : '\u2014').toList(),
      ),
      (
        'Fee Ledger',
        comparePlans.map((p) => p.hasFeeLedger ? '\u2713' : '\u2014').toList(),
      ),
      (
        'Custom Logo',
        comparePlans.map((p) => p.hasCustomLogo ? '\u2713' : '\u2014').toList(),
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Compare Plans',
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: Spacing.sp12),
        Container(
          decoration: BoxDecoration(
            color: cs.surface,
            borderRadius: BorderRadius.circular(Radii.lg),
            border: Border.all(color: cs.primary.withValues(alpha: 0.08)),
          ),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minWidth: MediaQuery.of(context).size.width - Spacing.sp32 - 2,
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(Radii.lg),
                child: Table(
                  defaultVerticalAlignment: TableCellVerticalAlignment.middle,
                  columnWidths: {
                    0: const FixedColumnWidth(90),
                    for (var i = 0; i < comparePlans.length; i++)
                      i + 1: const FixedColumnWidth(72),
                  },
                  children: [
                    TableRow(
                      decoration: BoxDecoration(
                        color: cs.primary.withValues(alpha: 0.06),
                      ),
                      children: [
                        _tableCell('', theme, isHeader: true),
                        for (final plan in comparePlans)
                          _tableCell(plan.name, theme, isHeader: true),
                      ],
                    ),
                    for (var i = 0; i < features.length; i++)
                      TableRow(
                        decoration: BoxDecoration(
                          color: i.isEven
                              ? Colors.transparent
                              : cs.primary.withValues(alpha: 0.02),
                        ),
                        children: [
                          _tableCell(features[i].$1, theme, isLabel: true),
                          for (final v in features[i].$2) _tableCell(v, theme),
                        ],
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _tableCell(
    String text,
    ThemeData theme, {
    bool isHeader = false,
    bool isLabel = false,
  }) {
    final cs = theme.colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: Spacing.sp8,
        vertical: Spacing.sp10,
      ),
      child: Text(
        text,
        style: theme.textTheme.bodySmall?.copyWith(
          fontWeight: isHeader || isLabel ? FontWeight.w600 : FontWeight.normal,
          color: isHeader
              ? cs.primary
              : isLabel
              ? cs.onSurface
              : cs.onSurface.withValues(alpha: 0.7),
          fontSize: FontSize.nano,
        ),
        textAlign: isLabel ? TextAlign.left : TextAlign.center,
      ),
    );
  }
}

// ── Billing toggle pill ─────────────────────────────────────────────

class _TogglePill extends StatelessWidget {
  final String label;
  final String? badge;
  final bool selected;
  final VoidCallback onTap;

  const _TogglePill({
    required this.label,
    this.badge,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeInOut,
        padding: const EdgeInsets.symmetric(vertical: Spacing.sp10),
        decoration: BoxDecoration(
          color: selected ? cs.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(Radii.sm),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              label,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
                color: selected
                    ? cs.onPrimary
                    : cs.onSurface.withValues(alpha: 0.5),
              ),
            ),
            if (badge != null) ...[
              const SizedBox(width: Spacing.sp4),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: Spacing.sp8,
                  vertical: Spacing.sp2,
                ),
                decoration: BoxDecoration(
                  color: selected
                      ? cs.onPrimary.withValues(alpha: 0.2)
                      : cs.tertiary.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(Radii.full),
                ),
                child: Text(
                  badge!,
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontSize: FontSize.nano,
                    fontWeight: FontWeight.w600,
                    color: selected ? cs.onPrimary : cs.primary,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ── Plan card ────────────────────────────────────────────────────────

class _PlanCard extends StatelessWidget {
  final PlanModel plan;
  final bool yearly;
  final bool isCurrent;
  final UsageModel? usage;
  final bool isSubscribing;
  final VoidCallback onSubscribe;

  const _PlanCard({
    required this.plan,
    required this.yearly,
    required this.isCurrent,
    this.usage,
    required this.isSubscribing,
    required this.onSubscribe,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isPopular = plan.isPopular;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(Radii.lg),
        border: Border.all(
          color: isCurrent
              ? cs.primary
              : isPopular
              ? cs.primary.withValues(alpha: 0.4)
              : cs.primary.withValues(alpha: 0.08),
          width: isCurrent || isPopular ? 1.5 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (isPopular || isCurrent || plan.hasOffer || plan.isWebPortal)
            Container(
              padding: const EdgeInsets.symmetric(vertical: Spacing.sp4),
              decoration: BoxDecoration(
                color: isCurrent
                    ? cs.primary
                    : plan.hasOffer
                    ? const Color(0xFFD32F2F)
                    : plan.isWebPortal
                    ? const Color(0xFF1565C0)
                    : cs.primary.withValues(alpha: 0.08),
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(Radii.lg - 1),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    isCurrent
                        ? Icons.check_circle_rounded
                        : plan.hasOffer
                        ? Icons.local_offer_rounded
                        : plan.isWebPortal
                        ? Icons.monitor_rounded
                        : Icons.workspace_premium_rounded,
                    size: 11,
                    color: (isCurrent || plan.hasOffer || plan.isWebPortal)
                        ? Colors.white
                        : cs.primary,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    isCurrent
                        ? 'Current Plan'
                        : plan.hasOffer
                        ? '${plan.discountPercent}% OFF — Limited Offer'
                        : plan.isWebPortal
                        ? 'Web Management Portal'
                        : 'Most Popular',
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontSize: FontSize.micro,
                      fontWeight: FontWeight.w700,
                      color: (isCurrent || plan.hasOffer || plan.isWebPortal)
                          ? Colors.white
                          : cs.primary,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
            ),
          Padding(
            padding: const EdgeInsets.all(Spacing.sp20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Plan name
                Row(
                  children: [
                    Text(
                      plan.name,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (plan.isFree) ...[
                      const SizedBox(width: Spacing.sp8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: Spacing.sp8,
                          vertical: Spacing.sp2,
                        ),
                        decoration: BoxDecoration(
                          color: cs.tertiary.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(Radii.full),
                        ),
                        child: Text(
                          'Forever Free',
                          style: theme.textTheme.bodySmall?.copyWith(
                            fontSize: FontSize.nano,
                            color: cs.primary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: Spacing.sp16),

                // Price
                if (plan.isFree)
                  Text(
                    '\u20B90',
                    style: theme.textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: cs.primary,
                    ),
                  )
                else ...[
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      if (plan.hasOffer && !yearly) ...[
                        Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: Text(
                            '\u20B9${plan.mrpMonthly.toStringAsFixed(0)}',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              decoration: TextDecoration.lineThrough,
                              decorationColor: cs.onSurface.withValues(
                                alpha: 0.45,
                              ),
                              color: cs.onSurface.withValues(alpha: 0.45),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        const SizedBox(width: Spacing.sp4),
                      ],
                      Text(
                        yearly
                            ? '\u20B9${plan.effectiveMonthlyRupees.toStringAsFixed(0)}'
                            : '\u20B9${plan.priceMonthly.toStringAsFixed(0)}',
                        style: theme.textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: cs.primary,
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Text(
                          '/mo',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: cs.onSurface.withValues(alpha: 0.4),
                          ),
                        ),
                      ),
                      if (plan.hasOffer && !yearly) ...[
                        const SizedBox(width: Spacing.sp8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: Spacing.sp8,
                            vertical: Spacing.sp2,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.green.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(Radii.full),
                          ),
                          child: Text(
                            '${plan.discountPercent}% off',
                            style: theme.textTheme.bodySmall?.copyWith(
                              fontSize: FontSize.nano,
                              fontWeight: FontWeight.w600,
                              color: Colors.green.shade700,
                            ),
                          ),
                        ),
                      ],
                      if (yearly) ...[
                        const SizedBox(width: Spacing.sp8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: Spacing.sp8,
                            vertical: Spacing.sp2,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.green.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(Radii.full),
                          ),
                          child: Text(
                            '${plan.yearlySavingsPercent}% off',
                            style: theme.textTheme.bodySmall?.copyWith(
                              fontSize: FontSize.nano,
                              fontWeight: FontWeight.w600,
                              color: Colors.green.shade700,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  if (yearly)
                    Padding(
                      padding: const EdgeInsets.only(top: Spacing.sp2),
                      child: Row(
                        children: [
                          if (plan.mrpYearly > 0 &&
                              plan.mrpYearly > plan.priceYearly) ...[
                            Text(
                              'Billed \u20B9${plan.mrpYearly.toStringAsFixed(0)}',
                              style: theme.textTheme.bodySmall?.copyWith(
                                fontSize: FontSize.nano,
                                decoration: TextDecoration.lineThrough,
                                decorationColor: cs.onSurface.withValues(
                                  alpha: 0.35,
                                ),
                                color: cs.onSurface.withValues(alpha: 0.35),
                              ),
                            ),
                            const SizedBox(width: Spacing.sp4),
                            Text(
                              '\u20B9${plan.priceYearly.toStringAsFixed(0)}/year',
                              style: theme.textTheme.bodySmall?.copyWith(
                                fontSize: FontSize.nano,
                                color: Colors.green.shade700,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ] else
                            Text(
                              'Billed \u20B9${plan.priceYearly.toStringAsFixed(0)}/year',
                              style: theme.textTheme.bodySmall?.copyWith(
                                fontSize: FontSize.nano,
                                color: cs.onSurface.withValues(alpha: 0.4),
                              ),
                            ),
                        ],
                      ),
                    ),
                ],
                const SizedBox(height: Spacing.sp16),

                // Key limits
                _QuotaRow(
                  icon: Icons.people_outline_rounded,
                  label: 'Students',
                  value: plan.formatQuota(plan.maxStudents),
                  current: usage?.students,
                ),
                _QuotaRow(
                  icon: Icons.school_outlined,
                  label: 'Teachers',
                  value: plan.formatQuota(plan.maxTeachers),
                  current: usage?.teachers,
                ),
                _QuotaRow(
                  icon: Icons.inventory_2_outlined,
                  label: 'Batches',
                  value: plan.formatQuota(plan.maxBatches),
                  current: usage?.batches,
                ),
                _QuotaRow(
                  icon: Icons.cloud_outlined,
                  label: 'Storage',
                  value: plan.storageLabel,
                ),
                const SizedBox(height: Spacing.sp16),

                // Feature chips
                Wrap(
                  spacing: Spacing.sp8,
                  runSpacing: Spacing.sp4,
                  children: [
                    for (final f in plan.featureLabels) _FeatureChip(label: f),
                  ],
                ),
                const SizedBox(height: Spacing.sp20),

                // CTA
                SizedBox(
                  width: double.infinity,
                  child: isCurrent
                      ? OutlinedButton(
                          onPressed: null,
                          child: const Text('Current Plan'),
                        )
                      : plan.isFree
                      ? const SizedBox.shrink()
                      : FilledButton(
                          onPressed: isSubscribing ? null : onSubscribe,
                          child: isSubscribing
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : Text('Get ${plan.name}'),
                        ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Quota row ────────────────────────────────────────────────────────

class _QuotaRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final int? current;

  const _QuotaRow({
    required this.icon,
    required this.label,
    required this.value,
    this.current,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: Spacing.sp8),
      child: Row(
        children: [
          Icon(icon, size: 16, color: cs.primary.withValues(alpha: 0.6)),
          const SizedBox(width: Spacing.sp8),
          Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
              color: cs.onSurface.withValues(alpha: 0.6),
            ),
          ),
          const Spacer(),
          if (current != null)
            Text(
              '$current / ',
              style: theme.textTheme.bodySmall?.copyWith(
                color: cs.primary.withValues(alpha: 0.6),
                fontWeight: FontWeight.w500,
              ),
            ),
          Text(
            value,
            style: theme.textTheme.bodySmall?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Feature chip ─────────────────────────────────────────────────────

class _FeatureChip extends StatelessWidget {
  final String label;

  const _FeatureChip({required this.label});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: Spacing.sp8,
        vertical: Spacing.sp4,
      ),
      decoration: BoxDecoration(
        color: cs.primary.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(Radii.full),
        border: Border.all(color: cs.primary.withValues(alpha: 0.15)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.check_circle_rounded, size: 12, color: cs.primary),
          const SizedBox(width: Spacing.sp4),
          Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
              fontSize: FontSize.nano,
              fontWeight: FontWeight.w500,
              color: cs.primary,
            ),
          ),
        ],
      ),
    );
  }
}
