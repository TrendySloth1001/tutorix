import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../models/fee_model.dart';
import '../services/fee_service.dart';
import 'fee_records_screen.dart';
import 'fee_structures_screen.dart';
import 'assign_fee_screen.dart';

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

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final s = await _svc.getSummary(widget.coachingId);
      setState(() {
        _summary = s;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
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
          color: AppColors.darkOlive,
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Fee Management',
          style: TextStyle(
            color: AppColors.darkOlive,
            fontWeight: FontWeight.w700,
            fontSize: 20,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: AppColors.darkOlive),
            onPressed: _load,
          ),
        ],
      ),
      body: RefreshIndicator(
        color: AppColors.darkOlive,
        onRefresh: _load,
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
            ? _ErrorView(error: _error!, onRetry: _load)
            : _Body(summary: _summary!, coachingId: widget.coachingId),
      ),
    );
  }
}

class _Body extends StatelessWidget {
  final FeeSummaryModel summary;
  final String coachingId;
  const _Body({required this.summary, required this.coachingId});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SummaryCards(summary: summary),
          const SizedBox(height: 24),
          _SectionTitle('Payment Breakdown'),
          const SizedBox(height: 12),
          _PaymentModeChips(modes: summary.paymentModes),
          const SizedBox(height: 24),
          _SectionTitle('Monthly Collection (Last 12 months)'),
          const SizedBox(height: 12),
          _MonthlyChart(data: summary.monthlyCollection),
          const SizedBox(height: 24),
          _SectionTitle('Quick Actions'),
          const SizedBox(height: 12),
          _QuickActions(coachingId: coachingId),
          const SizedBox(height: 32),
        ],
      ),
    );
  }
}

// ─── KPI Cards ────────────────────────────────────────────────────────

class _SummaryCards extends StatelessWidget {
  final FeeSummaryModel summary;
  const _SummaryCards({required this.summary});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _KpiCard(
                label: 'Collected',
                amount: summary.totalCollected,
                icon: Icons.account_balance_wallet_rounded,
                color: const Color(0xFF2E7D32),
                bgColor: const Color(0xFFE8F5E9),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _KpiCard(
                label: 'Pending',
                amount: summary.totalPending,
                icon: Icons.schedule_rounded,
                color: const Color(0xFF1565C0),
                bgColor: const Color(0xFFE3F2FD),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _KpiCard(
                label: 'Overdue',
                amount: summary.totalOverdue,
                icon: Icons.warning_amber_rounded,
                color: const Color(0xFFC62828),
                bgColor: const Color(0xFFFFEBEE),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _StatusCountCard(breakdown: summary.statusBreakdown),
            ),
          ],
        ),
      ],
    );
  }
}

class _KpiCard extends StatelessWidget {
  final String label;
  final double amount;
  final IconData icon;
  final Color color;
  final Color bgColor;
  const _KpiCard({
    required this.label,
    required this.amount,
    required this.icon,
    required this.color,
    required this.bgColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, size: 18, color: color),
              ),
              const Spacer(),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            '₹${_formatAmount(amount)}',
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w800,
              fontSize: 20,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              color: color.withValues(alpha: 0.7),
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusCountCard extends StatelessWidget {
  final List<FeeStatusGroup> breakdown;
  const _StatusCountCard({required this.breakdown});

  int _count(String status) =>
      breakdown.where((b) => b.status == status).fold(0, (a, b) => a + b.count);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.softGrey.withValues(alpha: 0.25),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.mutedOlive.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Status',
            style: TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 12,
              color: AppColors.mutedOlive,
            ),
          ),
          const SizedBox(height: 10),
          _StatusRow('Paid', _count('PAID'), const Color(0xFF2E7D32)),
          _StatusRow('Pending', _count('PENDING'), const Color(0xFF1565C0)),
          _StatusRow('Overdue', _count('OVERDUE'), const Color(0xFFC62828)),
          _StatusRow('Waived', _count('WAIVED'), AppColors.mutedOlive),
        ],
      ),
    );
  }
}

class _StatusRow extends StatelessWidget {
  final String label;
  final int count;
  final Color color;
  const _StatusRow(this.label, this.count, this.color);
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(fontSize: 11, color: AppColors.darkOlive),
          ),
          const Spacer(),
          Text(
            '$count',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Payment Modes ────────────────────────────────────────────────────

class _PaymentModeChips extends StatelessWidget {
  final List<FeePaymentModeGroup> modes;
  const _PaymentModeChips({required this.modes});

  @override
  Widget build(BuildContext context) {
    if (modes.isEmpty) {
      return const _EmptyHint('No payments recorded yet');
    }
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: modes.map((m) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: AppColors.softGrey.withValues(alpha: 0.3),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: AppColors.mutedOlive.withValues(alpha: 0.25),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _modeLabel(m.mode),
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                  color: AppColors.darkOlive,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                '₹${_formatAmount(m.total)}',
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                  color: AppColors.darkOlive,
                ),
              ),
              Text(
                '${m.count} txn${m.count == 1 ? '' : 's'}',
                style: const TextStyle(
                  fontSize: 11,
                  color: AppColors.mutedOlive,
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  String _modeLabel(String mode) {
    switch (mode) {
      case 'CASH':
        return '💵 Cash';
      case 'ONLINE':
        return '💳 Online';
      case 'UPI':
        return '📱 UPI';
      case 'BANK_TRANSFER':
        return '🏦 Bank Transfer';
      case 'CHEQUE':
        return '📝 Cheque';
      default:
        return mode;
    }
  }
}

// ─── Monthly Chart (bar) ──────────────────────────────────────────────

class _MonthlyChart extends StatelessWidget {
  final List<FeeMonthlyData> data;
  const _MonthlyChart({required this.data});

  @override
  Widget build(BuildContext context) {
    if (data.isEmpty) return const _EmptyHint('No collections yet');
    final maxVal = data.map((d) => d.total).reduce((a, b) => a > b ? a : b);
    return SizedBox(
      height: 100,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: data.map((d) {
          final ratio = maxVal > 0 ? d.total / maxVal : 0.0;
          final label = d.month.length >= 7 ? d.month.substring(5) : d.month;
          return Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Flexible(
                    child: FractionallySizedBox(
                      heightFactor: ratio.clamp(0.04, 1.0),
                      child: Tooltip(
                        message: '₹${_formatAmount(d.total)}',
                        child: Container(
                          decoration: BoxDecoration(
                            color: AppColors.darkOlive.withValues(alpha: 0.75),
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    label,
                    style: const TextStyle(
                      fontSize: 9,
                      color: AppColors.mutedOlive,
                    ),
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

// ─── Quick Actions ────────────────────────────────────────────────────

class _QuickActions extends StatelessWidget {
  final String coachingId;
  const _QuickActions({required this.coachingId});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _ActionTile(
          icon: Icons.receipt_long_rounded,
          label: 'All Fee Records',
          subtitle: 'View, collect & manage dues',
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => FeeRecordsScreen(coachingId: coachingId),
            ),
          ),
        ),
        const SizedBox(height: 10),
        _ActionTile(
          icon: Icons.category_rounded,
          label: 'Fee Structures',
          subtitle: 'Create and manage templates',
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => FeeStructuresScreen(coachingId: coachingId),
            ),
          ),
        ),
        const SizedBox(height: 10),
        _ActionTile(
          icon: Icons.person_add_rounded,
          label: 'Assign Fee to Student',
          subtitle: 'Map a fee structure to a member',
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
  final String subtitle;
  final VoidCallback onTap;
  const _ActionTile({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.softGrey.withValues(alpha: 0.28),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.darkOlive.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, size: 20, color: AppColors.darkOlive),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        color: AppColors.darkOlive,
                        fontSize: 14,
                      ),
                    ),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        color: AppColors.mutedOlive,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_right_rounded,
                color: AppColors.mutedOlive,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Helpers ──────────────────────────────────────────────────────────

class _SectionTitle extends StatelessWidget {
  final String title;
  const _SectionTitle(this.title);
  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: const TextStyle(
        fontWeight: FontWeight.w700,
        fontSize: 15,
        color: AppColors.darkOlive,
      ),
    );
  }
}

class _EmptyHint extends StatelessWidget {
  final String text;
  const _EmptyHint(this.text);
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        text,
        style: const TextStyle(color: AppColors.mutedOlive, fontSize: 13),
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
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.error_outline_rounded,
              color: Colors.redAccent,
              size: 40,
            ),
            const SizedBox(height: 12),
            Text(
              error,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.mutedOlive),
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
