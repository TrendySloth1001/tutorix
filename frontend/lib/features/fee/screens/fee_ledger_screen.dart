import 'package:flutter/material.dart';
import '../models/fee_model.dart';
import '../services/fee_service.dart';
import '../../../core/theme/design_tokens.dart';

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
                fontSize: FontSize.sub,
              ),
            ),
            Text(
              name,
              style: TextStyle(
                color: cs.onSurfaceVariant,
                fontSize: FontSize.caption,
              ),
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
                      padding: const EdgeInsets.fromLTRB(
                        Spacing.sp16,
                        Spacing.sp8,
                        Spacing.sp16,
                        Spacing.sp32,
                      ),
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
      margin: const EdgeInsets.all(Spacing.sp16),
      padding: const EdgeInsets.all(Spacing.sp20),
      decoration: BoxDecoration(
        color: theme.colorScheme.primary,
        borderRadius: BorderRadius.circular(Radii.lg),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Account Summary',
            style: TextStyle(
              color: theme.colorScheme.onPrimary,
              fontWeight: FontWeight.w700,
              fontSize: FontSize.sub,
            ),
          ),
          const SizedBox(height: Spacing.sp16),
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
                  color: theme.colorScheme.primary.withValues(alpha: 0.5),
                ),
              ),
              if (summary.totalRefunded > 0)
                Expanded(
                  child: _LedgerStat(
                    label: 'Refunded',
                    amount: summary.totalRefunded,
                    color: theme.colorScheme.secondary,
                  ),
                ),
            ],
          ),
          const SizedBox(height: Spacing.sp16),
          const Divider(color: Colors.white24, height: 1),
          const SizedBox(height: Spacing.sp12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Outstanding Balance',
                style: TextStyle(
                  color: theme.colorScheme.onPrimary.withValues(alpha: 0.8),
                  fontSize: FontSize.body,
                ),
              ),
              Text(
                '₹${(summary.balance > 0 ? summary.balance : 0).toStringAsFixed(0)}',
                style: TextStyle(
                  color: summary.balance > 0
                      ? theme.colorScheme.error.withValues(alpha: 0.5)
                      : theme.colorScheme.primary.withValues(alpha: 0.5),
                  fontWeight: FontWeight.w800,
                  fontSize: FontSize.title,
                ),
              ),
            ],
          ),
          if (summary.balance < 0) ...[
            const SizedBox(height: Spacing.sp12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Available Credits',
                  style: TextStyle(
                    color: theme.colorScheme.primary.withValues(alpha: 0.5),
                    fontSize: FontSize.body,
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
                    backgroundColor: theme.colorScheme.primary.withValues(
                      alpha: 0.08,
                    ),
                    foregroundColor: theme.colorScheme.primary.withValues(
                      alpha: 0.5,
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: Spacing.sp12,
                    ),
                    minimumSize: const Size(0, 32),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    elevation: 0,
                  ),
                ),
              ],
            ),
          ],
          if (summary.nextDueDate != null) ...[
            const SizedBox(height: Spacing.sp8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Next Due',
                  style: TextStyle(
                    color: theme.colorScheme.onPrimary.withValues(alpha: 0.7),
                    fontSize: FontSize.caption,
                  ),
                ),
                Text(
                  '₹${summary.nextDueAmount.toStringAsFixed(0)} · ${_fmtDateShort(summary.nextDueDate!)}',
                  style: TextStyle(
                    color: theme.colorScheme.onPrimary,
                    fontSize: FontSize.caption,
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
            fontSize: FontSize.title,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            color: color.withValues(alpha: 0.7),
            fontSize: FontSize.micro,
          ),
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
    final config = _entryConfig(entry.type, theme.colorScheme);

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
                      margin: const EdgeInsets.symmetric(vertical: Spacing.sp2),
                      color: theme.colorScheme.outlineVariant,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: Spacing.sp12),
          // Content
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: isLast ? 0 : 16),
              child: Container(
                padding: const EdgeInsets.all(Spacing.sp12),
                decoration: BoxDecoration(
                  color: config.bgColor,
                  borderRadius: BorderRadius.circular(Radii.md),
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
                              fontSize: FontSize.body,
                            ),
                          ),
                        ),
                        Text(
                          '${config.sign}₹${entry.amount.toStringAsFixed(0)}',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            color: config.color,
                            fontSize: FontSize.body,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: Spacing.sp4),
                    Row(
                      children: [
                        Expanded(
                          child: Row(
                            children: [
                              Text(
                                _fmtDateShort(entry.date),
                                style: TextStyle(
                                  color: theme.colorScheme.onSurfaceVariant,
                                  fontSize: FontSize.micro,
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
                                      fontSize: FontSize.micro,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        const SizedBox(width: Spacing.sp8),
                        Text(
                          'Balance: ₹${entry.runningBalance.toStringAsFixed(0)}',
                          style: TextStyle(
                            color: entry.runningBalance > 0
                                ? theme.colorScheme.error
                                : theme.colorScheme.primary,
                            fontSize: FontSize.micro,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    if (entry.ref != null) ...[
                      const SizedBox(height: Spacing.sp2),
                      Text(
                        'Ref: ${entry.ref}',
                        style: TextStyle(
                          color: theme.colorScheme.onSurfaceVariant,
                          fontSize: FontSize.nano,
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

_EntryConfig _entryConfig(String type, ColorScheme cs) {
  switch (type) {
    case 'PAYMENT':
      return _EntryConfig(
        color: cs.primary,
        bgColor: cs.primary.withValues(alpha: 0.08),
        icon: Icons.check_circle_rounded,
        sign: '',
      );
    case 'REFUND':
      return _EntryConfig(
        color: cs.secondary,
        bgColor: cs.secondary.withValues(alpha: 0.08),
        icon: Icons.keyboard_return_rounded,
        sign: '-',
      );
    default: // RECORD
      return _EntryConfig(
        color: cs.secondary,
        bgColor: cs.secondary.withValues(alpha: 0.08),
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
    final theme = Theme.of(context);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.error_outline_rounded,
            color: theme.colorScheme.error,
            size: 40,
          ),
          const SizedBox(height: Spacing.sp10),
          Text(
            error,
            textAlign: TextAlign.center,
            style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: Spacing.sp16),
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
