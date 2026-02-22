import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../models/fee_model.dart';
import '../services/fee_service.dart';
import 'fee_records_screen.dart';
import 'fee_structures_screen.dart';
import 'assign_fee_screen.dart';
import 'fee_reports_screen.dart';
import 'fee_calendar_screen.dart';
import 'payment_settings_screen.dart';
import '../../../core/theme/design_tokens.dart';

// ═══════════════════════════════════════════════════════════════════════
// Fee Dashboard — admin-facing financial overview for a coaching.
// ═══════════════════════════════════════════════════════════════════════

class FeeDashboardScreen extends StatefulWidget {
  final String coachingId;
  const FeeDashboardScreen({super.key, required this.coachingId});

  @override
  State<FeeDashboardScreen> createState() => _FeeDashboardScreenState();
}

class _FeeDashboardScreenState extends State<FeeDashboardScreen> {
  final _svc = FeeService();
  FeeSummaryModel? _summary;
  bool _loading = true;
  String? _error;
  String? _selectedFY;
  bool _sendingReminder = false;

  List<String> get _fyOptions {
    final now = DateTime.now();
    final currentFYStart = now.month >= 4 ? now.year : now.year - 1;
    return List.generate(3, (i) {
      final y = currentFYStart - i;
      return '$y-${(y + 1).toString().substring(2)}';
    });
  }

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    final fyStart = now.month >= 4 ? now.year : now.year - 1;
    _selectedFY = '$fyStart-${(fyStart + 1).toString().substring(2)}';
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final s = await _svc.getSummary(
        widget.coachingId,
        financialYear: _selectedFY,
      );
      if (!mounted) return;
      setState(() {
        _summary = s;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _bulkRemind() async {
    setState(() => _sendingReminder = true);
    try {
      final res = await _svc.bulkRemind(widget.coachingId);
      final count = res['reminded'] ?? res['count'] ?? 0;
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Reminder sent to $count overdue students')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.toString())));
      }
    } finally {
      if (mounted) setState(() => _sendingReminder = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: cs.surface,
      appBar: AppBar(
        backgroundColor: cs.surface,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          color: cs.onSurface,
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Fee Management',
          style: TextStyle(
            color: cs.onSurface,
            fontWeight: FontWeight.w700,
            fontSize: FontSize.title,
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.calendar_month_rounded, color: cs.onSurface),
            tooltip: 'Fee Calendar',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) =>
                    FeeCalendarScreen(coachingId: widget.coachingId),
              ),
            ),
          ),
          IconButton(
            icon: Icon(Icons.settings_outlined, color: cs.onSurface),
            tooltip: 'Payment Settings',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) =>
                    PaymentSettingsScreen(coachingId: widget.coachingId),
              ),
            ),
          ),
        ],
      ),
      body: RefreshIndicator(
        color: cs.primary,
        onRefresh: _load,
        child: _loading
            ? const _ShimmerDashboard()
            : _error != null
            ? _ErrorView(error: _error!, onRetry: _load)
            : _Body(
                summary: _summary!,
                coachingId: widget.coachingId,
                selectedFY: _selectedFY!,
                fyOptions: _fyOptions,
                onFYChanged: (fy) {
                  setState(() => _selectedFY = fy);
                  _load();
                },
                onBulkRemind: _bulkRemind,
                isSendingReminder: _sendingReminder,
              ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════
// Body
// ═══════════════════════════════════════════════════════════════════════

class _Body extends StatelessWidget {
  final FeeSummaryModel summary;
  final String coachingId;
  final String selectedFY;
  final List<String> fyOptions;
  final ValueChanged<String> onFYChanged;
  final VoidCallback onBulkRemind;
  final bool isSendingReminder;

  const _Body({
    required this.summary,
    required this.coachingId,
    required this.selectedFY,
    required this.fyOptions,
    required this.onFYChanged,
    required this.onBulkRemind,
    required this.isSendingReminder,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(
        horizontal: Spacing.screenH,
        vertical: Spacing.screenTop,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Section 1: Smart Action Banners ──
          if (!summary.onboarding.razorpayActivated)
            _OnboardingBanner(
              onboarding: summary.onboarding,
              coachingId: coachingId,
            ),
          if (!summary.onboarding.razorpayActivated && summary.overdueCount > 0)
            const SizedBox(height: Spacing.listGap),
          if (summary.overdueCount > 0)
            _OverdueBanner(
              count: summary.overdueCount,
              onRemind: onBulkRemind,
              isLoading: isSendingReminder,
            ),
          if (!summary.onboarding.razorpayActivated || summary.overdueCount > 0)
            const SizedBox(height: Spacing.sectionGap),

          // ── Section 2: Financial Summary ──
          _FinancialSummaryCard(
            summary: summary,
            selectedFY: selectedFY,
            fyOptions: fyOptions,
            onFYChanged: onFYChanged,
          ),
          const SizedBox(height: Spacing.sectionGap),

          // ── Section 3: Collection Trend ──
          if (summary.monthlyCollection.isNotEmpty) ...[
            _CollectionTrendCard(data: summary.monthlyCollection),
            const SizedBox(height: Spacing.sectionGap),
          ],

          // ── Section 4: Status Breakdown ──
          _StatusBreakdownCard(breakdown: summary.statusBreakdown),
          const SizedBox(height: Spacing.sectionGap),

          // ── Section 5: Quick Actions ──
          _QuickActionsGrid(coachingId: coachingId),
          const SizedBox(height: Spacing.sectionGap),

          // ── Section 6: Recent Activity ──
          if (summary.recentActivity.isNotEmpty)
            _RecentActivityCard(activities: summary.recentActivity),

          const SizedBox(height: Spacing.sp32),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════
// Section 1a: Onboarding Banner
// ═══════════════════════════════════════════════════════════════════════

class _OnboardingBanner extends StatelessWidget {
  final FeeOnboardingStatus onboarding;
  final String coachingId;
  const _OnboardingBanner({required this.onboarding, required this.coachingId});

  String get _statusLabel {
    final status = onboarding.razorpayOnboardingStatus;
    if (status == null) return 'Set up online payments';
    switch (status) {
      case 'new':
        return 'Complete your payment setup';
      case 'under_review':
        return 'Account under review';
      case 'needs_clarification':
        return 'Action needed on your account';
      case 'activated':
        return 'Account activated';
      case 'suspended':
        return 'Account suspended';
      default:
        return 'Set up online payments';
    }
  }

  String get _statusDescription {
    final status = onboarding.razorpayOnboardingStatus;
    if (status == null || status == 'new') {
      return 'Enable online fee collection from students. '
          '${onboarding.stepsCompleted}/${onboarding.totalSteps} steps done.';
    }
    if (status == 'under_review') {
      return 'Razorpay is reviewing your account. This usually takes 2-3 business days.';
    }
    if (status == 'needs_clarification') {
      return 'Razorpay needs additional information. Open settings to resolve.';
    }
    if (status == 'suspended') {
      return 'Your payment account has been suspended. Contact support.';
    }
    return '${onboarding.stepsCompleted}/${onboarding.totalSteps} steps done.';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final progress = onboarding.totalSteps > 0
        ? onboarding.stepsCompleted / onboarding.totalSteps
        : 0.0;

    return InkWell(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => PaymentSettingsScreen(coachingId: coachingId),
        ),
      ),
      borderRadius: BorderRadius.circular(Radii.lg),
      child: Container(
        padding: const EdgeInsets.all(Spacing.cardPad),
        decoration: BoxDecoration(
          color: theme.colorScheme.primary.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(Radii.lg),
          border: Border.all(
            color: theme.colorScheme.primary.withValues(alpha: 0.2),
          ),
        ),
        child: Row(
          children: [
            // Progress circle
            SizedBox(
              width: Spacing.sp40,
              height: Spacing.sp40,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  CircularProgressIndicator(
                    value: progress,
                    strokeWidth: 3,
                    backgroundColor: theme.colorScheme.primary.withValues(
                      alpha: 0.15,
                    ),
                    valueColor: AlwaysStoppedAnimation<Color>(
                      theme.colorScheme.primary,
                    ),
                  ),
                  Text(
                    '${onboarding.stepsCompleted}/${onboarding.totalSteps}',
                    style: TextStyle(
                      fontSize: FontSize.nano,
                      fontWeight: FontWeight.w700,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: Spacing.sp12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _statusLabel,
                    style: TextStyle(
                      fontSize: FontSize.body,
                      fontWeight: FontWeight.w600,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                  const SizedBox(height: Spacing.labelGap),
                  Text(
                    _statusDescription,
                    style: TextStyle(
                      fontSize: FontSize.caption,
                      color: theme.colorScheme.primary.withValues(alpha: 0.7),
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              color: theme.colorScheme.primary.withValues(alpha: 0.5),
              size: Spacing.sp20,
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════
// Section 1b: Overdue Banner
// ═══════════════════════════════════════════════════════════════════════

class _OverdueBanner extends StatelessWidget {
  final int count;
  final VoidCallback onRemind;
  final bool isLoading;
  const _OverdueBanner({
    required this.count,
    required this.onRemind,
    required this.isLoading,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: Spacing.cardPad,
        vertical: Spacing.sp12,
      ),
      decoration: BoxDecoration(
        color: theme.colorScheme.error.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(Radii.lg),
        border: Border.all(
          color: theme.colorScheme.error.withValues(alpha: 0.15),
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.warning_amber_rounded,
            color: theme.colorScheme.error,
            size: Spacing.sp20,
          ),
          const SizedBox(width: Spacing.sp12),
          Expanded(
            child: Text(
              '$count student${count == 1 ? '' : 's'} have overdue fees',
              style: TextStyle(
                color: theme.colorScheme.error,
                fontWeight: FontWeight.w600,
                fontSize: FontSize.body,
              ),
            ),
          ),
          if (isLoading)
            SizedBox(
              width: Spacing.sp20,
              height: Spacing.sp20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: theme.colorScheme.error,
              ),
            )
          else
            TextButton(
              onPressed: onRemind,
              style: TextButton.styleFrom(
                foregroundColor: theme.colorScheme.error,
                padding: const EdgeInsets.symmetric(
                  horizontal: Spacing.sp12,
                  vertical: Spacing.sp6,
                ),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(Radii.md),
                  side: BorderSide(
                    color: theme.colorScheme.error.withValues(alpha: 0.3),
                  ),
                ),
              ),
              child: const Text(
                'Remind All',
                style: TextStyle(
                  fontSize: FontSize.caption,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════
// Section 2: Financial Summary Card
// ═══════════════════════════════════════════════════════════════════════

class _FinancialSummaryCard extends StatelessWidget {
  final FeeSummaryModel summary;
  final String selectedFY;
  final List<String> fyOptions;
  final ValueChanged<String> onFYChanged;

  const _FinancialSummaryCard({
    required this.summary,
    required this.selectedFY,
    required this.fyOptions,
    required this.onFYChanged,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(Spacing.sp20),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(
          alpha: 0.35,
        ),
        borderRadius: BorderRadius.circular(Radii.lg),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.4),
        ),
      ),
      child: Column(
        children: [
          // FY pill row
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _FYPill(
                selected: selectedFY,
                options: fyOptions,
                onChanged: onFYChanged,
              ),
            ],
          ),
          const SizedBox(height: Spacing.sp16),

          // Hero stat
          Text(
            'Total Collected',
            style: TextStyle(
              fontSize: FontSize.caption,
              fontWeight: FontWeight.w500,
              color: theme.colorScheme.onSurfaceVariant,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: Spacing.sp6),
          Text(
            '₹${_formatAmount(summary.totalCollected)}',
            style: TextStyle(
              fontSize: FontSize.hero,
              fontWeight: FontWeight.w800,
              color: theme.colorScheme.onSurface,
              height: 1.0,
            ),
          ),
          const SizedBox(height: Spacing.sp20),

          // 3-column mini stats
          IntrinsicHeight(
            child: Row(
              children: [
                Expanded(
                  child: _MiniStat(
                    label: 'Today',
                    value: '₹${_formatAmount(summary.todayCollection)}',
                    icon: Icons.today_rounded,
                  ),
                ),
                VerticalDivider(
                  width: 1,
                  thickness: 1,
                  color: theme.colorScheme.outlineVariant.withValues(
                    alpha: 0.5,
                  ),
                ),
                Expanded(
                  child: _MiniStat(
                    label: 'Pending',
                    value: '₹${_formatAmount(summary.totalPending)}',
                    icon: Icons.schedule_rounded,
                  ),
                ),
                VerticalDivider(
                  width: 1,
                  thickness: 1,
                  color: theme.colorScheme.outlineVariant.withValues(
                    alpha: 0.5,
                  ),
                ),
                Expanded(
                  child: _MiniStat(
                    label: 'Overdue',
                    value: '₹${_formatAmount(summary.totalOverdue)}',
                    icon: Icons.warning_amber_rounded,
                    isAlert: summary.totalOverdue > 0,
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

class _FYPill extends StatelessWidget {
  final String selected;
  final List<String> options;
  final ValueChanged<String> onChanged;
  const _FYPill({
    required this.selected,
    required this.options,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: Spacing.chipH,
        vertical: Spacing.chipV,
      ),
      decoration: BoxDecoration(
        color: theme.colorScheme.outlineVariant.withValues(alpha: 0.25),
        borderRadius: BorderRadius.circular(Radii.full),
      ),
      child: DropdownButton<String>(
        value: selected,
        underline: const SizedBox.shrink(),
        isDense: true,
        icon: Icon(
          Icons.keyboard_arrow_down_rounded,
          color: theme.colorScheme.onSurface,
          size: Spacing.sp16,
        ),
        style: TextStyle(
          color: theme.colorScheme.onSurface,
          fontWeight: FontWeight.w600,
          fontSize: FontSize.caption,
        ),
        items: options
            .map((fy) => DropdownMenuItem(value: fy, child: Text('FY $fy')))
            .toList(),
        onChanged: (v) {
          if (v != null) onChanged(v);
        },
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final bool isAlert;
  const _MiniStat({
    required this.label,
    required this.value,
    required this.icon,
    this.isAlert = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = isAlert
        ? theme.colorScheme.error
        : theme.colorScheme.onSurface;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: Spacing.sp8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize: FontSize.sub,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
          const SizedBox(height: Spacing.labelGap),
          Text(
            label,
            style: TextStyle(
              fontSize: FontSize.micro,
              fontWeight: FontWeight.w500,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════
// Section 3: Collection Trend (mini bar chart)
// ═══════════════════════════════════════════════════════════════════════

class _CollectionTrendCard extends StatelessWidget {
  final List<FeeMonthlyData> data;
  const _CollectionTrendCard({required this.data});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // Take last 6 months max
    final items = data.length > 6 ? data.sublist(data.length - 6) : data;
    final maxVal = items.fold<double>(0, (a, b) => math.max(a, b.total));

    return Container(
      padding: const EdgeInsets.all(Spacing.sp20),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(
          alpha: 0.35,
        ),
        borderRadius: BorderRadius.circular(Radii.lg),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.4),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Collection Trend',
            style: TextStyle(
              fontSize: FontSize.sub,
              fontWeight: FontWeight.w700,
              color: theme.colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: Spacing.sp16),
          SizedBox(
            height: Spacing.sp100,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: items.map((m) {
                final fraction = maxVal > 0
                    ? (m.total / maxVal).clamp(0.0, 1.0)
                    : 0.0;
                final monthLabel = _shortMonth(m.month);
                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: Spacing.sp2,
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        if (fraction > 0)
                          Text(
                            '₹${_formatAmountCompact(m.total)}',
                            style: TextStyle(
                              fontSize: FontSize.nano,
                              fontWeight: FontWeight.w600,
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        const SizedBox(height: Spacing.sp4),
                        Flexible(
                          child: FractionallySizedBox(
                            heightFactor: fraction > 0 ? fraction : 0.02,
                            child: Container(
                              decoration: BoxDecoration(
                                color: fraction > 0
                                    ? theme.colorScheme.primary.withValues(
                                        alpha: 0.7,
                                      )
                                    : theme.colorScheme.outlineVariant
                                          .withValues(alpha: 0.3),
                                borderRadius: const BorderRadius.vertical(
                                  top: Radius.circular(Radii.sm),
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: Spacing.sp6),
                        Text(
                          monthLabel,
                          style: TextStyle(
                            fontSize: FontSize.nano,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════
// Section 4: Status Breakdown (segmented bar)
// ═══════════════════════════════════════════════════════════════════════

class _StatusBreakdownCard extends StatelessWidget {
  final List<FeeStatusGroup> breakdown;
  const _StatusBreakdownCard({required this.breakdown});

  int _count(String status) =>
      breakdown.where((b) => b.status == status).fold(0, (a, b) => a + b.count);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final paid = _count('PAID');
    final pending = _count('PENDING');
    final overdue = _count('OVERDUE');
    final partial = _count('PARTIAL');
    final total = paid + pending + overdue + partial;

    return Container(
      padding: const EdgeInsets.all(Spacing.sp20),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(
          alpha: 0.35,
        ),
        borderRadius: BorderRadius.circular(Radii.lg),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.4),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Status Breakdown',
                style: TextStyle(
                  fontSize: FontSize.sub,
                  fontWeight: FontWeight.w700,
                  color: theme.colorScheme.onSurface,
                ),
              ),
              const Spacer(),
              Text(
                '$total total',
                style: TextStyle(
                  fontSize: FontSize.caption,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
          const SizedBox(height: Spacing.sp16),

          // Segmented bar
          if (total > 0)
            ClipRRect(
              borderRadius: BorderRadius.circular(Radii.sm),
              child: SizedBox(
                height: Spacing.sp8,
                child: Row(
                  children: [
                    if (paid > 0)
                      Flexible(
                        flex: paid,
                        child: Container(color: theme.colorScheme.primary),
                      ),
                    if (partial > 0)
                      Flexible(
                        flex: partial,
                        child: Container(color: theme.colorScheme.tertiary),
                      ),
                    if (pending > 0)
                      Flexible(
                        flex: pending,
                        child: Container(
                          color: theme.colorScheme.outlineVariant,
                        ),
                      ),
                    if (overdue > 0)
                      Flexible(
                        flex: overdue,
                        child: Container(color: theme.colorScheme.error),
                      ),
                  ],
                ),
              ),
            )
          else
            ClipRRect(
              borderRadius: BorderRadius.circular(Radii.sm),
              child: Container(
                height: Spacing.sp8,
                color: theme.colorScheme.outlineVariant.withValues(alpha: 0.3),
              ),
            ),

          const SizedBox(height: Spacing.sp14),

          // Legend row
          Wrap(
            spacing: Spacing.sp16,
            runSpacing: Spacing.sp8,
            children: [
              _LegendDot(
                color: theme.colorScheme.primary,
                label: 'Paid',
                count: paid,
              ),
              _LegendDot(
                color: theme.colorScheme.tertiary,
                label: 'Partial',
                count: partial,
              ),
              _LegendDot(
                color: theme.colorScheme.outlineVariant,
                label: 'Pending',
                count: pending,
              ),
              _LegendDot(
                color: theme.colorScheme.error,
                label: 'Overdue',
                count: overdue,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _LegendDot extends StatelessWidget {
  final Color color;
  final String label;
  final int count;
  const _LegendDot({
    required this.color,
    required this.label,
    required this.count,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: Spacing.sp8,
          height: Spacing.sp8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: Spacing.sp6),
        Text(
          '$label ($count)',
          style: TextStyle(
            fontSize: FontSize.micro,
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════
// Section 5: Quick Actions — 2×2 Grid
// ═══════════════════════════════════════════════════════════════════════

class _QuickActionsGrid extends StatelessWidget {
  final String coachingId;
  const _QuickActionsGrid({required this.coachingId});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Quick Actions',
          style: TextStyle(
            fontSize: FontSize.sub,
            fontWeight: FontWeight.w700,
            color: theme.colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: Spacing.sp12),
        Row(
          children: [
            Expanded(
              child: _ActionCard(
                icon: Icons.receipt_long_rounded,
                label: 'Fee Records',
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => FeeRecordsScreen(coachingId: coachingId),
                  ),
                ),
              ),
            ),
            const SizedBox(width: Spacing.listGap),
            Expanded(
              child: _ActionCard(
                icon: Icons.person_add_alt_1_rounded,
                label: 'Assign Fee',
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => AssignFeeScreen(coachingId: coachingId),
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: Spacing.listGap),
        Row(
          children: [
            Expanded(
              child: _ActionCard(
                icon: Icons.category_rounded,
                label: 'Structures',
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => FeeStructuresScreen(coachingId: coachingId),
                  ),
                ),
              ),
            ),
            const SizedBox(width: Spacing.listGap),
            Expanded(
              child: _ActionCard(
                icon: Icons.bar_chart_rounded,
                label: 'Reports',
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => FeeReportsScreen(coachingId: coachingId),
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _ActionCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _ActionCard({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(Radii.lg),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: Spacing.cardPad,
          vertical: Spacing.sp20,
        ),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest.withValues(
            alpha: 0.35,
          ),
          borderRadius: BorderRadius.circular(Radii.lg),
          border: Border.all(
            color: theme.colorScheme.outlineVariant.withValues(alpha: 0.4),
          ),
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(Spacing.sp10),
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(Radii.md),
              ),
              child: Icon(
                icon,
                size: Spacing.sp24,
                color: theme.colorScheme.primary,
              ),
            ),
            const SizedBox(height: Spacing.sp10),
            Text(
              label,
              style: TextStyle(
                fontSize: FontSize.body,
                fontWeight: FontWeight.w600,
                color: theme.colorScheme.onSurface,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════
// Section 6: Recent Activity Feed
// ═══════════════════════════════════════════════════════════════════════

class _RecentActivityCard extends StatelessWidget {
  final List<FeeRecentActivity> activities;
  const _RecentActivityCard({required this.activities});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(Spacing.sp20),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(
          alpha: 0.35,
        ),
        borderRadius: BorderRadius.circular(Radii.lg),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.4),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Recent Activity',
            style: TextStyle(
              fontSize: FontSize.sub,
              fontWeight: FontWeight.w700,
              color: theme.colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: Spacing.sp14),
          ...activities.map((a) => _ActivityRow(activity: a)),
        ],
      ),
    );
  }
}

class _ActivityRow extends StatelessWidget {
  final FeeRecentActivity activity;
  const _ActivityRow({required this.activity});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isRefund = activity.type == 'REFUND';
    final iconData = isRefund
        ? Icons.replay_rounded
        : Icons.check_circle_outline_rounded;
    final iconColor = isRefund
        ? theme.colorScheme.error
        : theme.colorScheme.primary;
    final amountPrefix = isRefund ? '−₹' : '+₹';
    final amountColor = isRefund
        ? theme.colorScheme.error
        : theme.colorScheme.primary;

    return Padding(
      padding: const EdgeInsets.only(bottom: Spacing.sp12),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(Spacing.sp8),
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.08),
              shape: BoxShape.circle,
            ),
            child: Icon(iconData, size: Spacing.sp16, color: iconColor),
          ),
          const SizedBox(width: Spacing.sp12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  activity.studentName,
                  style: TextStyle(
                    fontSize: FontSize.body,
                    fontWeight: FontWeight.w600,
                    color: theme.colorScheme.onSurface,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: Spacing.sp2),
                Text(
                  '${activity.feeTitle} · ${_timeAgo(activity.date)}',
                  style: TextStyle(
                    fontSize: FontSize.micro,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: Spacing.sp8),
          Text(
            '$amountPrefix${_formatAmount(activity.amount)}',
            style: TextStyle(
              fontSize: FontSize.body,
              fontWeight: FontWeight.w700,
              color: amountColor,
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════
// Shimmer Loading Skeleton
// ═══════════════════════════════════════════════════════════════════════

class _ShimmerDashboard extends StatefulWidget {
  const _ShimmerDashboard();

  @override
  State<_ShimmerDashboard> createState() => _ShimmerDashboardState();
}

class _ShimmerDashboardState extends State<_ShimmerDashboard>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, _) {
        final shimmerColor = theme.colorScheme.onSurface.withValues(
          alpha: 0.04 + (_ctrl.value * 0.04),
        );
        return SingleChildScrollView(
          physics: const NeverScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(
            horizontal: Spacing.screenH,
            vertical: Spacing.screenTop,
          ),
          child: Column(
            children: [
              // Banner placeholder
              _ShimmerBox(height: Spacing.sp60, color: shimmerColor),
              const SizedBox(height: Spacing.sectionGap),
              // Financial card placeholder
              _ShimmerBox(height: Spacing.sp200, color: shimmerColor),
              const SizedBox(height: Spacing.sectionGap),
              // Trend placeholder
              _ShimmerBox(height: Spacing.sp120, color: shimmerColor),
              const SizedBox(height: Spacing.sectionGap),
              // Breakdown placeholder
              _ShimmerBox(height: Spacing.sp80, color: shimmerColor),
              const SizedBox(height: Spacing.sectionGap),
              // Grid placeholder
              Row(
                children: [
                  Expanded(
                    child: _ShimmerBox(
                      height: Spacing.sp100,
                      color: shimmerColor,
                    ),
                  ),
                  const SizedBox(width: Spacing.listGap),
                  Expanded(
                    child: _ShimmerBox(
                      height: Spacing.sp100,
                      color: shimmerColor,
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

class _ShimmerBox extends StatelessWidget {
  final double height;
  final Color color;
  const _ShimmerBox({required this.height, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: height,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(Radii.lg),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════
// Error View
// ═══════════════════════════════════════════════════════════════════════

class _ErrorView extends StatelessWidget {
  final String error;
  final VoidCallback onRetry;
  const _ErrorView({required this.error, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(Spacing.sectionGap),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.error_outline_rounded,
              color: theme.colorScheme.error,
              size: Spacing.sp40,
            ),
            const SizedBox(height: Spacing.sp12),
            Text(
              error,
              textAlign: TextAlign.center,
              style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: Spacing.sp16),
            OutlinedButton(onPressed: onRetry, child: const Text('Retry')),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════
// Helpers
// ═══════════════════════════════════════════════════════════════════════

String _formatAmount(double v) {
  if (v >= 10000000) return '${(v / 10000000).toStringAsFixed(1)}Cr';
  if (v >= 100000) return '${(v / 100000).toStringAsFixed(1)}L';
  if (v >= 1000) return '${(v / 1000).toStringAsFixed(1)}K';
  return v.toStringAsFixed(0);
}

String _formatAmountCompact(double v) {
  if (v >= 100000) return '${(v / 100000).toStringAsFixed(0)}L';
  if (v >= 1000) return '${(v / 1000).toStringAsFixed(0)}K';
  return v.toStringAsFixed(0);
}

String _shortMonth(String yyyyMM) {
  const months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  final parts = yyyyMM.split('-');
  if (parts.length < 2) return yyyyMM;
  final m = int.tryParse(parts[1]);
  if (m == null || m < 1 || m > 12) return yyyyMM;
  return months[m - 1];
}

String _timeAgo(DateTime date) {
  final diff = DateTime.now().difference(date);
  if (diff.inMinutes < 1) return 'just now';
  if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
  if (diff.inHours < 24) return '${diff.inHours}h ago';
  if (diff.inDays < 7) return '${diff.inDays}d ago';
  return '${date.day}/${date.month}';
}
