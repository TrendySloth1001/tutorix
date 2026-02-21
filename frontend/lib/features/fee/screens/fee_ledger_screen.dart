import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../models/fee_model.dart';
import '../services/fee_service.dart';

/// Student financial ledger — shows a chronological timeline of all
/// fee records, payments, and refunds with a running balance.
class FeeLedgerScreen extends StatefulWidget {
  final String coachingId;
  final String memberId;
  final String? memberName;

  const FeeLedgerScreen({
    super.key,
    required this.coachingId,
    required this.memberId,
    this.memberName,
  });

  @override
  State<FeeLedgerScreen> createState() => _FeeLedgerScreenState();
}

class _FeeLedgerScreenState extends State<FeeLedgerScreen> {
  final _svc = FeeService();
  bool _loading = true;
  String? _error;
  StudentLedgerSummary? _summary;
  List<LedgerEntryModel> _timeline = [];
  Map<String, dynamic>? _member;

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
      final data = await _svc.getStudentLedger(
        widget.coachingId,
        widget.memberId,
      );
      final summaryData = data['summary'] as Map<String, dynamic>?;
      final timelineData = data['timeline'] as List<dynamic>?;

      if (!mounted) return;
      setState(() {
        _member = data['member'] as Map<String, dynamic>?;
        _summary = summaryData != null
            ? StudentLedgerSummary.fromJson(summaryData)
            : null;
        _timeline = (timelineData ?? [])
            .map((e) => LedgerEntryModel.fromJson(e as Map<String, dynamic>))
            .toList();
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

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final name =
        widget.memberName ?? (_member?['name'] as String?) ?? 'Student Ledger';

    return Scaffold(
      backgroundColor: cs.surface,
      appBar: AppBar(
        backgroundColor: cs.surface,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded, color: cs.onSurface),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Financial Ledger',
              style: TextStyle(
                color: cs.onSurface,
                fontWeight: FontWeight.w700,
                fontSize: 17,
              ),
            ),
            Text(
              name,
              style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh_rounded, color: cs.onSurface),
            onPressed: _load,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? _ErrorRetry(error: _error!, onRetry: _load)
          : RefreshIndicator(
              color: cs.primary,
              onRefresh: _load,
              child: CustomScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: [
                  if (_summary != null)
                    SliverToBoxAdapter(
                      child: _LedgerSummaryCard(summary: _summary!),
                    ),
                  if (_timeline.isEmpty)
                    SliverFillRemaining(
                      child: Center(
                        child: Text(
                          'No transactions yet',
                          style: TextStyle(color: cs.onSurfaceVariant),
                        ),
                      ),
                    )
                  else
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                      sliver: SliverList(
                        delegate: SliverChildBuilderDelegate((ctx, i) {
                          return _TimelineEntry(
                            entry: _timeline[i],
                            isLast: i == _timeline.length - 1,
                          );
                        }, childCount: _timeline.length),
                      ),
                    ),
                ],
              ),
            ),
    );
  }
}

// ─── Summary card ─────────────────────────────────────────────────────

class _LedgerSummaryCard extends StatelessWidget {
  final StudentLedgerSummary summary;
  const _LedgerSummaryCard({required this.summary});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.colorScheme.primary,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Account Summary',
            style: TextStyle(
              color: theme.colorScheme.onPrimary,
              fontWeight: FontWeight.w700,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _LedgerStat(
                  label: 'Charged',
                  amount: summary.totalCharged,
                  color: theme.colorScheme.onPrimary,
                ),
              ),
              Expanded(
                child: _LedgerStat(
                  label: 'Paid',
                  amount: summary.totalPaid,
                  color: AppColors.successLight,
                ),
              ),
              if (summary.totalRefunded > 0)
                Expanded(
                  child: _LedgerStat(
                    label: 'Refunded',
                    amount: summary.totalRefunded,
                    color: const Color(0xFF90CAF9),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(color: Colors.white24, height: 1),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Outstanding Balance',
                style: TextStyle(
                  color: theme.colorScheme.onPrimary.withValues(alpha: 0.8),
                  fontSize: 13,
                ),
              ),
              Text(
                '₹${(summary.balance > 0 ? summary.balance : 0).toStringAsFixed(0)}',
                style: TextStyle(
                  color: summary.balance > 0
                      ? AppColors.errorLight
                      : AppColors.successLight,
                  fontWeight: FontWeight.w800,
                  fontSize: 18,
                ),
              ),
            ],
          ),
          if (summary.balance < 0) ...[
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Available Credits',
                  style: TextStyle(
                    color: AppColors.successLight,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                FilledButton.icon(
                  onPressed: () {},
                  icon: const Icon(
                    Icons.account_balance_wallet_rounded,
                    size: 16,
                  ),
                  label: Text('₹${summary.balance.abs().toStringAsFixed(0)}'),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.successLight.withValues(
                      alpha: 0.15,
                    ),
                    foregroundColor: AppColors.successLight,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    minimumSize: const Size(0, 32),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    elevation: 0,
                  ),
                ),
              ],
            ),
          ],
          if (summary.nextDueDate != null) ...[
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Next Due',
                  style: TextStyle(
                    color: theme.colorScheme.onPrimary.withValues(alpha: 0.7),
                    fontSize: 12,
                  ),
                ),
                Text(
                  '₹${summary.nextDueAmount.toStringAsFixed(0)} · ${_fmtDateShort(summary.nextDueDate!)}',
                  style: TextStyle(
                    color: theme.colorScheme.onPrimary,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _LedgerStat extends StatelessWidget {
  final String label;
  final double amount;
  final Color color;
  const _LedgerStat({
    required this.label,
    required this.amount,
    required this.color,
  });
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '₹${_formatAmount(amount)}',
          style: TextStyle(
            color: color,
            fontWeight: FontWeight.w800,
            fontSize: 18,
          ),
        ),
        Text(
          label,
          style: TextStyle(color: color.withValues(alpha: 0.7), fontSize: 11),
        ),
      ],
    );
  }
}

// ─── Timeline entry ────────────────────────────────────────────────────

class _TimelineEntry extends StatelessWidget {
  final LedgerEntryModel entry;
  final bool isLast;
  const _TimelineEntry({required this.entry, required this.isLast});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final config = _entryConfig(entry.type);

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Timeline indicator column
          SizedBox(
            width: 32,
            child: Column(
              children: [
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: config.bgColor,
                    shape: BoxShape.circle,
                    border: Border.all(color: config.color, width: 2),
                  ),
                  child: Icon(config.icon, size: 14, color: config.color),
                ),
                if (!isLast)
                  Expanded(
                    child: Container(
                      width: 2,
                      margin: const EdgeInsets.symmetric(vertical: 2),
                      color: theme.colorScheme.outlineVariant,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          // Content
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: isLast ? 0 : 16),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: config.bgColor,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: config.color.withValues(alpha: 0.3),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            entry.label,
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: theme.colorScheme.onSurface,
                              fontSize: 13,
                            ),
                          ),
                        ),
                        Text(
                          '${config.sign}₹${entry.amount.toStringAsFixed(0)}',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            color: config.color,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Expanded(
                          child: Row(
                            children: [
                              Text(
                                _fmtDateShort(entry.date),
                                style: TextStyle(
                                  color: theme.colorScheme.onSurfaceVariant,
                                  fontSize: 11,
                                ),
                              ),
                              if (entry.mode != null) ...[
                                Text(
                                  ' · ',
                                  style: TextStyle(
                                    color: theme.colorScheme.onSurfaceVariant,
                                  ),
                                ),
                                Flexible(
                                  child: Text(
                                    entry.mode!,
                                    style: TextStyle(
                                      color: theme.colorScheme.onSurfaceVariant,
                                      fontSize: 11,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Balance: ₹${entry.runningBalance.toStringAsFixed(0)}',
                          style: TextStyle(
                            color: entry.runningBalance > 0
                                ? AppColors.error
                                : AppColors.success,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    if (entry.ref != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        'Ref: ${entry.ref}',
                        style: TextStyle(
                          color: theme.colorScheme.onSurfaceVariant,
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EntryConfig {
  final Color color;
  final Color bgColor;
  final IconData icon;
  final String sign;
  const _EntryConfig({
    required this.color,
    required this.bgColor,
    required this.icon,
    required this.sign,
  });
}

_EntryConfig _entryConfig(String type) {
  switch (type) {
    case 'PAYMENT':
      return const _EntryConfig(
        color: AppColors.success,
        bgColor: AppColors.successBg,
        icon: Icons.check_circle_rounded,
        sign: '',
      );
    case 'REFUND':
      return const _EntryConfig(
        color: AppColors.info,
        bgColor: AppColors.infoBg,
        icon: Icons.keyboard_return_rounded,
        sign: '-',
      );
    default: // RECORD
      return const _EntryConfig(
        color: AppColors.warning,
        bgColor: AppColors.warningBg,
        icon: Icons.receipt_long_rounded,
        sign: '+',
      );
  }
}

// ─── Helpers ──────────────────────────────────────────────────────────

class _ErrorRetry extends StatelessWidget {
  final String error;
  final VoidCallback onRetry;
  const _ErrorRetry({required this.error, required this.onRetry});
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.error_outline_rounded,
            color: AppColors.error,
            size: 40,
          ),
          const SizedBox(height: 10),
          Text(
            error,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 16),
          OutlinedButton(onPressed: onRetry, child: const Text('Retry')),
        ],
      ),
    );
  }
}

String _fmtDateShort(DateTime d) {
  final months = [
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
  return '${d.day} ${months[d.month - 1]} ${d.year}';
}

String _formatAmount(double v) {
  if (v >= 100000) return '${(v / 100000).toStringAsFixed(1)}L';
  if (v >= 1000) return '${(v / 1000).toStringAsFixed(1)}K';
  return v.toStringAsFixed(0);
}
