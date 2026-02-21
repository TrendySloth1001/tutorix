import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../models/fee_model.dart';
import '../services/fee_service.dart';
import 'fee_records_screen.dart';
import 'fee_structures_screen.dart';
import 'assign_fee_screen.dart';
import 'fee_reports_screen.dart';
import 'fee_calendar_screen.dart';

/// Admin-facing fee dashboard for a coaching.
/// Shows summary KPIs + quick-access tabs.
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
            fontSize: 20,
          ),
        ),
        actions: [
          _FYDropdown(
            selected: _selectedFY!,
            options: _fyOptions,
            onChanged: (fy) {
              setState(() => _selectedFY = fy);
              _load();
            },
          ),
          IconButton(
            icon: Icon(Icons.refresh_rounded, color: cs.onSurface),
            onPressed: _load,
          ),
        ],
      ),
      body: RefreshIndicator(
        color: cs.primary,
        onRefresh: _load,
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
            ? _ErrorView(error: _error!, onRetry: _load)
            : _Body(
                summary: _summary!,
                coachingId: widget.coachingId,
                onBulkRemind: _bulkRemind,
                isSendingReminder: _sendingReminder,
              ),
      ),
    );
  }
}

class _Body extends StatelessWidget {
  final FeeSummaryModel summary;
  final String coachingId;
  final VoidCallback onBulkRemind;
  final bool isSendingReminder;
  const _Body({
    required this.summary,
    required this.coachingId,
    required this.onBulkRemind,
    required this.isSendingReminder,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (summary.overdueCount > 0) ...[
            _OverdueBanner(
              count: summary.overdueCount,
              onRemind: onBulkRemind,
              isLoading: isSendingReminder,
            ),
            const SizedBox(height: 16),
          ],

          // Financial Overview Card
          _FinancialOverviewCard(summary: summary),
          const SizedBox(height: 16),

          // Status Breakdown Card
          _SectionCard(
            title: 'Fee Status',
            child: _StatusCountRow(breakdown: summary.statusBreakdown),
          ),
          const SizedBox(height: 16),

          // Payment Breakdown Card
          _SectionCard(
            title: 'Recent Collections',
            child: _PaymentModeList(modes: summary.paymentModes),
          ),
          const SizedBox(height: 16),

          // Quick Actions Card
          _SectionCard(
            title: 'Quick Actions',
            child: _QuickActions(
              coachingId: coachingId,
              overdueCount: summary.overdueCount,
            ),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }
}

// ─── Cards ────────────────────────────────────────────────────────────

class _FinancialOverviewCard extends StatelessWidget {
  final FeeSummaryModel summary;
  const _FinancialOverviewCard({required this.summary});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      elevation: 0,
      color: theme.colorScheme.outlineVariant.withValues(alpha: 0.1),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.2),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Text(
              'Total Collected',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '₹${_formatAmount(summary.totalCollected)}',
              style: TextStyle(
                fontSize: 36,
                fontWeight: FontWeight.w800,
                color: theme.colorScheme.onSurface,
                height: 1.0,
              ),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: _MiniStat(
                    label: 'Today',
                    value: '₹${_formatAmount(summary.todayCollection)}',
                    color: theme.colorScheme.onSurface,
                  ),
                ),
                Container(
                  width: 1,
                  height: 30,
                  color: theme.colorScheme.outlineVariant,
                ),
                Expanded(
                  child: _MiniStat(
                    label: 'Pending',
                    value: '₹${_formatAmount(summary.totalPending)}',
                    color: theme.colorScheme.onSurface,
                  ),
                ),
                Container(
                  width: 1,
                  height: 30,
                  color: theme.colorScheme.outlineVariant,
                ),
                Expanded(
                  child: _MiniStat(
                    label: 'Overdue',
                    value: '₹${_formatAmount(summary.totalOverdue)}',
                    color: AppColors.error,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _MiniStat({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: color,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

class _SectionCard extends StatelessWidget {
  final String title;
  final Widget child;
  const _SectionCard({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      elevation: 0,
      color: theme.colorScheme.outlineVariant.withValues(alpha: 0.1),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.2),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: theme.colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 16),
            child,
          ],
        ),
      ),
    );
  }
}

// ─── Status & Payment Rows ────────────────────────────────────────────

class _StatusCountRow extends StatelessWidget {
  final List<FeeStatusGroup> breakdown;
  const _StatusCountRow({required this.breakdown});

  int _count(String status) =>
      breakdown.where((b) => b.status == status).fold(0, (a, b) => a + b.count);

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _SimpleStatusRow('Paid', _count('PAID')),
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 12),
          child: Divider(height: 1),
        ),
        _SimpleStatusRow('Pending', _count('PENDING')),
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 12),
          child: Divider(height: 1),
        ),
        _SimpleStatusRow('Overdue', _count('OVERDUE'), isAlert: true),
      ],
    );
  }
}

class _SimpleStatusRow extends StatelessWidget {
  final String label;
  final int count;
  final bool isAlert;
  const _SimpleStatusRow(this.label, this.count, {this.isAlert = false});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Text(
          label,
          style: TextStyle(fontSize: 15, color: theme.colorScheme.onSurface),
        ),
        const Spacer(),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: isAlert
                ? AppColors.errorBg
                : theme.colorScheme.outlineVariant.withValues(alpha: 0.3),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            '$count Students',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: isAlert ? AppColors.error : theme.colorScheme.onSurface,
            ),
          ),
        ),
      ],
    );
  }
}

class _PaymentModeList extends StatelessWidget {
  final List<FeePaymentModeGroup> modes;
  const _PaymentModeList({required this.modes});

  String _modeLabel(String mode) {
    switch (mode) {
      case 'CASH':
        return 'Cash';
      case 'ONLINE':
        return 'Online';
      case 'UPI':
        return 'UPI';
      case 'BANK_TRANSFER':
        return 'Bank Transfer';
      case 'CHEQUE':
        return 'Cheque';
      default:
        return mode;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (modes.isEmpty) {
      return Text(
        'No payments recorded yet',
        style: TextStyle(
          color: theme.colorScheme.onSurfaceVariant,
          fontSize: 13,
        ),
      );
    }
    return Column(
      children: modes.take(5).map((m) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: theme.colorScheme.outlineVariant.withValues(
                    alpha: 0.3,
                  ),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.payments_outlined,
                  size: 16,
                  color: theme.colorScheme.onSurface,
                ),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _modeLabel(m.mode),
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                  Text(
                    '${m.count} txns',
                    style: TextStyle(
                      fontSize: 11,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
              const Spacer(),
              Text(
                '₹${_formatAmount(m.total)}',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: theme.colorScheme.onSurface,
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}

class _QuickActions extends StatelessWidget {
  final String coachingId;
  final int overdueCount;
  const _QuickActions({required this.coachingId, required this.overdueCount});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _ActionTile(
          icon: Icons.calendar_month_rounded,
          label: 'Fee Calendar',
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => FeeCalendarScreen(coachingId: coachingId),
            ),
          ),
        ),
        const SizedBox(height: 12),
        _ActionTile(
          icon: Icons.receipt_long_rounded,
          label: 'Fee Records',
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => FeeRecordsScreen(coachingId: coachingId),
            ),
          ),
        ),
        const SizedBox(height: 12),
        _ActionTile(
          icon: Icons.bar_chart_rounded,
          label: 'Reports',
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => FeeReportsScreen(coachingId: coachingId),
            ),
          ),
        ),
        const SizedBox(height: 12),
        _ActionTile(
          icon: Icons.category_rounded,
          label: 'Fee Structures',
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => FeeStructuresScreen(coachingId: coachingId),
            ),
          ),
        ),
        const SizedBox(height: 12),
        _ActionTile(
          icon: Icons.person_add_rounded,
          label: 'Assign Fee',
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => AssignFeeScreen(coachingId: coachingId),
            ),
          ),
        ),
      ],
    );
  }
}

class _ActionTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _ActionTile({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 20, color: theme.colorScheme.onSurface),
          ),
          const SizedBox(width: 14),
          Text(
            label,
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: theme.colorScheme.onSurface,
              fontSize: 15,
            ),
          ),
          const Spacer(),
          Icon(
            Icons.chevron_right_rounded,
            color: theme.colorScheme.onSurfaceVariant,
            size: 20,
          ),
        ],
      ),
    );
  }
}

// ─── Shared Components ────────────────────────────────────────────────

class _FYDropdown extends StatelessWidget {
  final String selected;
  final List<String> options;
  final ValueChanged<String> onChanged;
  const _FYDropdown({
    required this.selected,
    required this.options,
    required this.onChanged,
  });
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        decoration: BoxDecoration(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.3),
          borderRadius: BorderRadius.circular(20),
        ),
        child: DropdownButton<String>(
          value: selected,
          underline: const SizedBox.shrink(),
          icon: Icon(
            Icons.keyboard_arrow_down_rounded,
            color: theme.colorScheme.onSurface,
            size: 18,
          ),
          style: TextStyle(
            color: theme.colorScheme.onSurface,
            fontWeight: FontWeight.w600,
            fontSize: 13,
          ),
          items: options
              .map((fy) => DropdownMenuItem(value: fy, child: Text('FY $fy')))
              .toList(),
          onChanged: (v) {
            if (v != null) onChanged(v);
          },
        ),
      ),
    );
  }
}

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
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.errorBg,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.warning_amber_rounded,
            color: AppColors.error,
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              '$count student${count == 1 ? '' : 's'} have overdue fees',
              style: const TextStyle(
                color: AppColors.error,
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
            ),
          ),
          if (isLoading)
            const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: AppColors.error,
              ),
            )
          else
            TextButton(
              onPressed: onRemind,
              style: TextButton.styleFrom(
                foregroundColor: AppColors.error,
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                backgroundColor: Colors.white.withValues(alpha: 0.5),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
              child: const Text(
                'Remind',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
              ),
            ),
        ],
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  final String error;
  final VoidCallback onRetry;
  const _ErrorView({required this.error, required this.onRetry});
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.error_outline_rounded,
              color: AppColors.error,
              size: 40,
            ),
            const SizedBox(height: 12),
            Text(
              error,
              textAlign: TextAlign.center,
              style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: 16),
            OutlinedButton(onPressed: onRetry, child: const Text('Retry')),
          ],
        ),
      ),
    );
  }
}

String _formatAmount(double v) {
  if (v >= 10000000) return '${(v / 10000000).toStringAsFixed(1)}Cr';
  if (v >= 100000) return '${(v / 100000).toStringAsFixed(1)}L';
  if (v >= 1000) return '${(v / 1000).toStringAsFixed(1)}K';
  return v.toStringAsFixed(0);
}
