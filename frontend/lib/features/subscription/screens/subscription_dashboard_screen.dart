import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/design_tokens.dart';
import '../../../shared/widgets/app_alert.dart';
import '../models/subscription_model.dart';
import '../models/usage_model.dart';
import '../models/invoice_model.dart';
import '../services/subscription_service.dart';
import 'invoice_detail_screen.dart';
import 'plan_selector_screen.dart';

/// Billing & usage dashboard — shows current plan, resource usage,
/// billing status and invoice history.
class SubscriptionDashboardScreen extends StatefulWidget {
  final String coachingId;
  final bool isOwner;

  const SubscriptionDashboardScreen({
    super.key,
    required this.coachingId,
    this.isOwner = false,
  });

  @override
  State<SubscriptionDashboardScreen> createState() =>
      _SubscriptionDashboardScreenState();
}

class _SubscriptionDashboardScreenState
    extends State<SubscriptionDashboardScreen> {
  final _service = SubscriptionService.instance;

  SubscriptionModel? _subscription;
  UsageModel? _usage;
  List<InvoiceModel> _invoices = [];
  bool _isLoading = true;
  bool _isCancelling = false;
  String? _error;

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
        _service.getSubscription(widget.coachingId),
        _service.getInvoices(widget.coachingId),
      ]);
      final sub =
          results[0] as ({SubscriptionModel subscription, UsageModel usage});
      final invoices = results[1] as List<InvoiceModel>;

      if (!mounted) return;
      setState(() {
        _subscription = sub.subscription;
        _usage = sub.usage;
        _invoices = invoices;
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

  Future<void> _cancel() async {
    final confirmed = await AppAlert.confirm(
      context,
      title: 'Cancel Subscription',
      message:
          "Your subscription will remain active until the end of the current billing period. After that, you'll be downgraded to the Free plan.",
    );
    if (confirmed != true || !mounted) return;

    setState(() => _isCancelling = true);
    try {
      final msg = await _service.cancel(widget.coachingId);
      if (!mounted) return;
      AppAlert.success(context, msg);
      _load();
    } catch (e) {
      if (!mounted) return;
      AppAlert.error(context, e, fallback: 'Failed to cancel subscription');
    } finally {
      if (mounted) setState(() => _isCancelling = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Subscription'), centerTitle: true),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.cloud_off_rounded,
                    size: 48,
                    color: theme.colorScheme.error,
                  ),
                  const SizedBox(height: Spacing.sp16),
                  Text(
                    'Could not load subscription',
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
            )
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(
                  Spacing.sp24,
                  Spacing.sp8,
                  Spacing.sp24,
                  Spacing.sp48,
                ),
                children: [
                  _buildPlanCard(theme),
                  const SizedBox(height: Spacing.sp24),
                  if (_invoices.isNotEmpty) ...[
                    _buildInvoiceSection(theme),
                    const SizedBox(height: Spacing.sp24),
                  ],
                  _buildUsageSection(theme),
                  const SizedBox(height: Spacing.sp24),
                  if (widget.isOwner) _buildActions(theme),
                ],
              ),
            ),
    );
  }

  // ── Current Plan Card ──────────────────────────────────────────────

  Widget _buildPlanCard(ThemeData theme) {
    final cs = theme.colorScheme;
    final sub = _subscription!;
    final plan = sub.plan;
    final df = DateFormat('dd MMM yyyy');

    return Container(
      padding: const EdgeInsets.all(Spacing.sp20),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(Radii.lg),
        border: Border.all(color: cs.primary.withValues(alpha: 0.12)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(Spacing.sp10),
                decoration: BoxDecoration(
                  color: cs.tertiary.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(Radii.md),
                ),
                child: Icon(_planIcon(plan?.slug), color: cs.primary, size: 24),
              ),
              const SizedBox(width: Spacing.sp12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      plan?.name ?? 'Free',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      sub.billingCycle == 'YEARLY'
                          ? 'Billed yearly'
                          : 'Billed monthly',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: cs.onSurface.withValues(alpha: 0.5),
                      ),
                    ),
                  ],
                ),
              ),
              _StatusBadge(status: sub.status),
            ],
          ),
          if (!sub.isFree) ...[
            const SizedBox(height: Spacing.sp16),
            Divider(color: cs.outlineVariant.withValues(alpha: 0.3)),
            const SizedBox(height: Spacing.sp12),
            Row(
              children: [
                Icon(
                  Icons.calendar_today_rounded,
                  size: 14,
                  color: cs.onSurface.withValues(alpha: 0.4),
                ),
                const SizedBox(width: Spacing.sp8),
                Text(
                  'Current period: ${df.format(sub.currentPeriodStart)} \u2014 ${df.format(sub.currentPeriodEnd)}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: cs.onSurface.withValues(alpha: 0.5),
                    fontSize: FontSize.micro,
                  ),
                ),
              ],
            ),
            const SizedBox(height: Spacing.sp8),
            Row(
              children: [
                Icon(
                  Icons.access_time_rounded,
                  size: 14,
                  color: cs.onSurface.withValues(alpha: 0.4),
                ),
                const SizedBox(width: Spacing.sp8),
                Text(
                  '${sub.daysRemaining} days remaining',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: cs.onSurface.withValues(alpha: 0.5),
                    fontSize: FontSize.micro,
                  ),
                ),
              ],
            ),
          ],
          // Past due warning
          if (sub.isPastDue) ...[
            const SizedBox(height: Spacing.sp12),
            Container(
              padding: const EdgeInsets.all(Spacing.sp12),
              decoration: BoxDecoration(
                color: cs.error.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(Radii.sm),
              ),
              child: Row(
                children: [
                  Icon(Icons.warning_amber_rounded, size: 18, color: cs.error),
                  const SizedBox(width: Spacing.sp8),
                  Expanded(
                    child: Text(
                      'Payment failed. ${sub.graceDaysRemaining} day(s) left in grace period.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: cs.error,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          // Pending downgrade
          if (sub.hasPendingDowngrade) ...[
            const SizedBox(height: Spacing.sp12),
            Container(
              padding: const EdgeInsets.all(Spacing.sp12),
              decoration: BoxDecoration(
                color: cs.tertiary.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(Radii.sm),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.info_outline_rounded,
                    size: 18,
                    color: cs.tertiary,
                  ),
                  const SizedBox(width: Spacing.sp8),
                  Expanded(
                    child: Text(
                      'Your subscription will be downgraded at the end of the current billing period.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: cs.onSurface.withValues(alpha: 0.6),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ── Usage Section ──────────────────────────────────────────────────

  Widget _buildUsageSection(ThemeData theme) {
    final cs = theme.colorScheme;
    final plan = _subscription?.plan;
    final usage = _usage!;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionHeader(icon: Icons.bar_chart_rounded, title: 'Usage'),
        const SizedBox(height: Spacing.sp12),
        Container(
          padding: const EdgeInsets.all(Spacing.sp16),
          decoration: BoxDecoration(
            color: cs.surface,
            borderRadius: BorderRadius.circular(Radii.lg),
            border: Border.all(color: cs.primary.withValues(alpha: 0.08)),
          ),
          child: Column(
            children: [
              _UsageBar(
                label: 'Students',
                current: usage.students,
                max: plan?.maxStudents ?? 0,
                icon: Icons.people_outline_rounded,
              ),
              const SizedBox(height: Spacing.sp12),
              _UsageBar(
                label: 'Teachers',
                current: usage.teachers,
                max: plan?.maxTeachers ?? 0,
                icon: Icons.school_outlined,
              ),
              const SizedBox(height: Spacing.sp12),
              _UsageBar(
                label: 'Batches',
                current: usage.batches,
                max: plan?.maxBatches ?? 0,
                icon: Icons.inventory_2_outlined,
              ),
              const SizedBox(height: Spacing.sp12),
              _UsageBar(
                label: 'Assessments (this month)',
                current: usage.assessmentsThisMonth,
                max: plan?.maxAssessmentsPerMonth ?? 0,
                icon: Icons.quiz_outlined,
              ),
              const SizedBox(height: Spacing.sp12),
              _UsageBar(
                label: 'Storage',
                current: usage.storageBytes,
                max: plan?.storageLimitBytes ?? 0,
                icon: Icons.cloud_outlined,
                formatValue: _formatStorage,
              ),
            ],
          ),
        ),
      ],
    );
  }

  String _formatStorage(int bytes) {
    if (bytes == 0) return '0 MB';
    final mb = bytes / (1024 * 1024);
    if (mb >= 1024) return '${(mb / 1024).toStringAsFixed(1)} GB';
    return '${mb.toStringAsFixed(0)} MB';
  }

  // ── Invoice Section ────────────────────────────────────────────────

  Widget _buildInvoiceSection(ThemeData theme) {
    final cs = theme.colorScheme;
    final df = DateFormat('dd MMM yyyy');
    // Show max 3 most recent invoices; tap "View All" for the rest
    final preview = _invoices.take(3).toList();
    final hasMore = _invoices.length > 3;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const _SectionHeader(
              icon: Icons.receipt_long_rounded,
              title: 'Billing History',
            ),
            const Spacer(),
            if (hasMore)
              TextButton(
                onPressed: () => _showAllInvoices(theme),
                style: TextButton.styleFrom(
                  padding: EdgeInsets.zero,
                  minimumSize: const Size(0, 0),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: Text(
                  'View All (${_invoices.length})',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: cs.primary,
                    fontWeight: FontWeight.w600,
                    fontSize: FontSize.micro,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: Spacing.sp12),
        Container(
          decoration: BoxDecoration(
            color: cs.surface,
            borderRadius: BorderRadius.circular(Radii.lg),
            border: Border.all(color: cs.primary.withValues(alpha: 0.08)),
          ),
          child: Column(
            children: [
              for (var i = 0; i < preview.length; i++) ...[
                if (i > 0)
                  Divider(
                    height: 1,
                    color: cs.outlineVariant.withValues(alpha: 0.2),
                  ),
                _InvoiceTile(
                  invoice: preview[i],
                  dateFormat: df,
                  onTap: () => _openInvoiceDetail(preview[i]),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  void _openInvoiceDetail(InvoiceModel invoice) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => InvoiceDetailScreen(invoice: invoice),
      ),
    );
  }

  void _showAllInvoices(ThemeData theme) {
    final cs = theme.colorScheme;
    final df = DateFormat('dd MMM yyyy');

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: cs.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(Radii.xl)),
      ),
      builder: (ctx) {
        return DraggableScrollableSheet(
          initialChildSize: 0.7,
          maxChildSize: 0.95,
          minChildSize: 0.4,
          expand: false,
          builder: (_, scrollCtrl) {
            return Column(
              children: [
                // Handle bar
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: Spacing.sp12),
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: cs.onSurface.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(Radii.full),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: Spacing.sp24,
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.receipt_long_rounded,
                        size: 20,
                        color: cs.primary,
                      ),
                      const SizedBox(width: Spacing.sp8),
                      Text(
                        'All Transactions',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        '${_invoices.length} records',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: cs.onSurface.withValues(alpha: 0.4),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: Spacing.sp8),
                Divider(
                  color: cs.outlineVariant.withValues(alpha: 0.2),
                ),
                Expanded(
                  child: ListView.separated(
                    controller: scrollCtrl,
                    padding: const EdgeInsets.symmetric(
                      horizontal: Spacing.sp8,
                    ),
                    itemCount: _invoices.length,
                    separatorBuilder: (_, _) => Divider(
                      height: 1,
                      color: cs.outlineVariant.withValues(alpha: 0.15),
                    ),
                    itemBuilder: (_, i) => _InvoiceTile(
                      invoice: _invoices[i],
                      dateFormat: df,
                      onTap: () {
                        Navigator.pop(ctx); // close bottom sheet
                        _openInvoiceDetail(_invoices[i]);
                      },
                    ),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // ── Actions ────────────────────────────────────────────────────────

  Widget _buildActions(ThemeData theme) {
    final cs = theme.colorScheme;
    final sub = _subscription!;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Upgrade / Change plan
        FilledButton.icon(
          onPressed: () async {
            await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => PlanSelectorScreen(
                  coachingId: widget.coachingId,
                  currentPlanSlug: sub.plan?.slug,
                ),
              ),
            );
            _load(); // refresh after returning
          },
          icon: const Icon(Icons.rocket_launch_rounded, size: 18),
          label: Text(sub.isFree ? 'Upgrade Plan' : 'Change Plan'),
        ),

        // Cancel (only for paid plans)
        if (!sub.isFree && !sub.isCancelled) ...[
          const SizedBox(height: Spacing.sp12),
          OutlinedButton(
            onPressed: _isCancelling ? null : _cancel,
            style: OutlinedButton.styleFrom(
              foregroundColor: cs.error,
              side: BorderSide(color: cs.error.withValues(alpha: 0.3)),
            ),
            child: _isCancelling
                ? SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: cs.error,
                    ),
                  )
                : const Text('Cancel Subscription'),
          ),
        ],
      ],
    );
  }

  IconData _planIcon(String? slug) {
    return switch (slug) {
      'basic' => Icons.star_outline_rounded,
      'standard' => Icons.star_half_rounded,
      'premium' => Icons.star_rounded,
      _ => Icons.spa_outlined,
    };
  }
}

// ── Section Header ───────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final IconData icon;
  final String title;

  const _SectionHeader({required this.icon, required this.title});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Icon(icon, size: 18, color: theme.colorScheme.primary),
        const SizedBox(width: Spacing.sp8),
        Text(
          title,
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}

// ── Status Badge ─────────────────────────────────────────────────────

class _StatusBadge extends StatelessWidget {
  final String status;
  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    final (Color bg, Color fg, String label) = switch (status) {
      'ACTIVE' => (
        Colors.green.withValues(alpha: 0.1),
        Colors.green.shade700,
        'Active',
      ),
      'TRIALING' => (cs.primary.withValues(alpha: 0.1), cs.primary, 'Trial'),
      'PAST_DUE' => (cs.error.withValues(alpha: 0.1), cs.error, 'Past Due'),
      'CANCELLED' => (
        cs.onSurface.withValues(alpha: 0.08),
        cs.onSurface.withValues(alpha: 0.5),
        'Cancelled',
      ),
      'EXPIRED' => (cs.error.withValues(alpha: 0.1), cs.error, 'Expired'),
      'PAUSED' => (cs.tertiary.withValues(alpha: 0.1), cs.tertiary, 'Paused'),
      _ => (
        cs.onSurface.withValues(alpha: 0.08),
        cs.onSurface.withValues(alpha: 0.5),
        status,
      ),
    };

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: Spacing.sp10,
        vertical: Spacing.sp4,
      ),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(Radii.full),
      ),
      child: Text(
        label,
        style: theme.textTheme.bodySmall?.copyWith(
          fontSize: FontSize.nano,
          fontWeight: FontWeight.w600,
          color: fg,
        ),
      ),
    );
  }
}

// ── Usage Bar ────────────────────────────────────────────────────────

class _UsageBar extends StatelessWidget {
  final String label;
  final int current;
  final int max;
  final IconData icon;
  final String Function(int)? formatValue;

  const _UsageBar({
    required this.label,
    required this.current,
    required this.max,
    required this.icon,
    this.formatValue,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isUnlimited = max == -1;
    final ratio = isUnlimited ? 0.0 : (max == 0 ? 0.0 : current / max);
    final isOverLimit = !isUnlimited && ratio >= 0.9;

    final currentLabel = formatValue != null
        ? formatValue!(current)
        : '$current';
    final maxLabel = isUnlimited
        ? '\u221E'
        : (formatValue != null ? formatValue!(max) : '$max');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 14, color: cs.primary.withValues(alpha: 0.6)),
            const SizedBox(width: Spacing.sp8),
            Text(
              label,
              style: theme.textTheme.bodySmall?.copyWith(
                color: cs.onSurface.withValues(alpha: 0.6),
                fontSize: FontSize.micro,
              ),
            ),
            const Spacer(),
            Text(
              '$currentLabel / $maxLabel',
              style: theme.textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.w600,
                fontSize: FontSize.micro,
                color: isOverLimit ? cs.error : cs.onSurface,
              ),
            ),
          ],
        ),
        const SizedBox(height: Spacing.sp4),
        ClipRRect(
          borderRadius: BorderRadius.circular(Radii.full),
          child: LinearProgressIndicator(
            value: isUnlimited ? 0 : ratio.clamp(0.0, 1.0),
            minHeight: 6,
            backgroundColor: cs.outlineVariant.withValues(alpha: 0.2),
            valueColor: AlwaysStoppedAnimation(
              isOverLimit ? cs.error : cs.primary,
            ),
          ),
        ),
      ],
    );
  }
}

// ── Invoice Tile ─────────────────────────────────────────────────────

class _InvoiceTile extends StatelessWidget {
  final InvoiceModel invoice;
  final DateFormat dateFormat;
  final VoidCallback? onTap;

  const _InvoiceTile({
    required this.invoice,
    required this.dateFormat,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    final (Color color, IconData icon) = switch (invoice.status) {
      'PAID' => (Colors.green.shade700, Icons.check_circle_rounded),
      'FAILED' => (cs.error, Icons.cancel_rounded),
      'REFUNDED' => (cs.tertiary, Icons.replay_rounded),
      _ => (cs.onSurface.withValues(alpha: 0.5), Icons.pending_rounded),
    };

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(Radii.sm),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: Spacing.sp16,
          vertical: Spacing.sp12,
        ),
        child: Row(
          children: [
            Icon(icon, size: 18, color: color),
            const SizedBox(width: Spacing.sp12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${_typeLabel(invoice.type)} \u2014 ${invoice.planSlug?.toUpperCase() ?? ''}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    dateFormat.format(invoice.createdAt),
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontSize: FontSize.nano,
                      color: cs.onSurface.withValues(alpha: 0.4),
                    ),
                  ),
                ],
              ),
            ),
            Text(
              '\u20B9${invoice.totalRupees.toStringAsFixed(0)}',
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
            const SizedBox(width: Spacing.sp8),
            Icon(
              Icons.chevron_right_rounded,
              size: 18,
              color: cs.onSurface.withValues(alpha: 0.3),
            ),
          ],
        ),
      ),
    );
  }

  String _typeLabel(String type) => switch (type) {
    'INITIAL' => 'First Payment',
    'RENEWAL' => 'Renewal',
    'UPGRADE' => 'Upgrade',
    'REFUND' => 'Refund',
    _ => type,
  };
}
