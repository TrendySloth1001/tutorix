import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../models/fee_model.dart';
import '../services/fee_service.dart';
import 'fee_record_detail_screen.dart';

/// Admin reports screen —
/// • Overdue student list with days overdue badge
/// • Financial year summary with monthly breakdown bar chart
class FeeReportsScreen extends StatefulWidget {
  final String coachingId;
  const FeeReportsScreen({super.key, required this.coachingId});

  @override
  State<FeeReportsScreen> createState() => _FeeReportsScreenState();
}

class _FeeReportsScreenState extends State<FeeReportsScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;
  final _svc = FeeService();

  // Overdue tab state
  List<FeeRecordModel> _overdueRecords = [];
  bool _loadingOverdue = true;
  String? _overdueError;

  // Summary tab state
  FeeSummaryModel? _summary;
  bool _loadingSummary = true;
  String? _summaryError;
  late String _selectedFY;

  List<String> get _fyOptions {
    final now = DateTime.now();
    final currentFYStart = now.month >= 4 ? now.year : now.year - 1;
    return List.generate(4, (i) {
      final y = currentFYStart - i;
      return '$y-${(y + 1).toString().substring(2)}';
    });
  }

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
    final now = DateTime.now();
    final fyStart = now.month >= 4 ? now.year : now.year - 1;
    _selectedFY = '$fyStart-${(fyStart + 1).toString().substring(2)}';
    _loadOverdue();
    _loadSummary();
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  Future<void> _loadOverdue() async {
    setState(() {
      _loadingOverdue = true;
      _overdueError = null;
    });
    try {
      final records = await _svc.getOverdueReport(widget.coachingId);
      // Sort by most overdue first
      records.sort((a, b) => b.daysOverdue.compareTo(a.daysOverdue));
      if (!mounted) return;
      setState(() {
        _overdueRecords = records;
        _loadingOverdue = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _overdueError = e.toString();
        _loadingOverdue = false;
      });
    }
  }

  Future<void> _loadSummary() async {
    setState(() {
      _loadingSummary = true;
      _summaryError = null;
    });
    try {
      final s = await _svc.getSummary(
        widget.coachingId,
        financialYear: _selectedFY,
      );
      if (!mounted) return;
      setState(() {
        _summary = s;
        _loadingSummary = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _summaryError = e.toString();
        _loadingSummary = false;
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
          icon: Icon(
            Icons.arrow_back_ios_new_rounded,
            color: cs.onSurface,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Reports',
          style: TextStyle(
            color: cs.onSurface,
            fontWeight: FontWeight.w700,
            fontSize: 20,
          ),
        ),
        bottom: TabBar(
          controller: _tabs,
          indicatorColor: cs.primary,
          labelColor: cs.primary,
          unselectedLabelColor: cs.onSurfaceVariant,
          tabs: const [
            Tab(text: 'Overdue'),
            Tab(text: 'FY Collection'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabs,
        children: [
          // ── Overdue tab ──
          RefreshIndicator(
            color: cs.primary,
            onRefresh: _loadOverdue,
            child: _loadingOverdue
                ? const Center(child: CircularProgressIndicator())
                : _overdueError != null
                ? _ErrorRetry(error: _overdueError!, onRetry: _loadOverdue)
                : _overdueRecords.isEmpty
                ? ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    children: [
                      const SizedBox(height: 200),
                      Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.check_circle_outline_rounded,
                              size: 52,
                              color: AppColors.success,
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'No overdue fees!',
                              style: TextStyle(
                                color: cs.onSurface,
                                fontWeight: FontWeight.w700,
                                fontSize: 16,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  )
                : _OverdueList(
                    records: _overdueRecords,
                    coachingId: widget.coachingId,
                    onRefresh: _loadOverdue,
                  ),
          ),

          // ── FY Collection tab ──
          RefreshIndicator(
            color: cs.primary,
            onRefresh: _loadSummary,
            child: _loadingSummary
                ? const Center(child: CircularProgressIndicator())
                : _summaryError != null
                ? _ErrorRetry(error: _summaryError!, onRetry: _loadSummary)
                : _FYReport(
                    summary: _summary!,
                    selectedFY: _selectedFY,
                    fyOptions: _fyOptions,
                    onFYChanged: (fy) {
                      setState(() => _selectedFY = fy);
                      _loadSummary();
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

// ─── Overdue list ─────────────────────────────────────────────────────

// ─── Overdue list ─────────────────────────────────────────────────────

class _OverdueList extends StatelessWidget {
  final List<FeeRecordModel> records;
  final String coachingId;
  final Future<void> Function() onRefresh;
  const _OverdueList({
    required this.records,
    required this.coachingId,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      itemCount: records.length,
      itemBuilder: (ctx, i) {
        final r = records[i];
        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Card(
            elevation: 0,
            color: theme.colorScheme.outlineVariant.withValues(alpha: 0.1),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(
                color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.2),
              ),
            ),
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: () => Navigator.push(
                ctx,
                MaterialPageRoute(
                  builder: (_) => FeeRecordDetailScreen(
                    coachingId: coachingId,
                    recordId: r.id,
                    isAdmin: true,
                  ),
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: AppColors.error.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Center(
                        child: Text(
                          '${r.daysOverdue}d',
                          style: const TextStyle(
                            color: AppColors.error,
                            fontWeight: FontWeight.w800,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            r.member?.name ?? 'Unknown Student',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              color: theme.colorScheme.onSurface,
                              fontSize: 15,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            r.title,
                            style: TextStyle(
                              color: theme.colorScheme.onSurfaceVariant,
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Due since ${_fmtDate(r.dueDate)}',
                            style: const TextStyle(
                              color: AppColors.error,
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          '₹${r.balance.toStringAsFixed(0)}',
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            color: AppColors.error,
                            fontSize: 16,
                          ),
                        ),
                        if (r.fineAmount > 0) ...[
                          const SizedBox(height: 2),
                          Text(
                            '+₹${r.fineAmount.toStringAsFixed(0)} fine',
                            style: TextStyle(
                              color: theme.colorScheme.onSurfaceVariant,
                              fontSize: 10,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

// ─── FY Collection report ─────────────────────────────────────────────

// ─── FY Collection report ─────────────────────────────────────────────

class _FYReport extends StatelessWidget {
  final FeeSummaryModel summary;
  final String selectedFY;
  final List<String> fyOptions;
  final ValueChanged<String> onFYChanged;

  const _FYReport({
    required this.summary,
    required this.selectedFY,
    required this.fyOptions,
    required this.onFYChanged,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // FY selector
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: theme.colorScheme.outlineVariant.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.2),
                  ),
                ),
                child: DropdownButton<String>(
                  value: selectedFY,
                  underline: const SizedBox.shrink(),
                  isDense: true,
                  icon: Icon(
                    Icons.keyboard_arrow_down_rounded,
                    color: theme.colorScheme.onSurface,
                    size: 18,
                  ),
                  style: TextStyle(
                    color: theme.colorScheme.onSurface,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                  items: fyOptions
                      .map(
                        (fy) =>
                            DropdownMenuItem(value: fy, child: Text('FY $fy')),
                      )
                      .toList(),
                  onChanged: (v) {
                    if (v != null) onFYChanged(v);
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Financial Overview (Same as Dashboard)
          _FinancialOverviewCard(summary: summary),
          const SizedBox(height: 16),

          // Monthly Collection Section
          _SectionCard(
            title: 'Monthly Collection',
            child: Column(
              children: [
                if (summary.monthlyCollection.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 24),
                    child: Text(
                      'No data for this financial year',
                      style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
                    ),
                  )
                else ...[
                  AspectRatio(
                    aspectRatio: 1.7,
                    child: _MonthlyBarChart(data: summary.monthlyCollection),
                  ),
                  const SizedBox(height: 24),
                  const Divider(height: 1),
                  const SizedBox(height: 8),
                  ...summary.monthlyCollection.where((d) => d.total > 0).map((
                    d,
                  ) {
                    return Column(
                      children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          child: Row(
                            children: [
                              Text(
                                d.month,
                                style: TextStyle(
                                  fontSize: 15,
                                  color: theme.colorScheme.onSurface,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const Spacer(),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: theme.colorScheme.outlineVariant.withValues(
                                    alpha: 0.3,
                                  ),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  '${d.count} txn',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: theme.colorScheme.onSurfaceVariant,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              SizedBox(
                                width: 70,
                                child: Text(
                                  '₹${_formatAmount(d.total)}',
                                  textAlign: TextAlign.end,
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                    color: theme.colorScheme.onSurface,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Divider(height: 1),
                      ],
                    );
                  }),
                ],
              ],
            ),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }
}

// ─── Dashboard Style Components ───────────────────────────────────────

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
        side: BorderSide(color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.2)),
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
        side: BorderSide(color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.2)),
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
                Container(width: 1, height: 30, color: theme.colorScheme.outlineVariant),
                Expanded(
                  child: _MiniStat(
                    label: 'Pending',
                    value: '₹${_formatAmount(summary.totalPending)}',
                    color: theme.colorScheme.onSurface,
                  ),
                ),
                Container(width: 1, height: 30, color: theme.colorScheme.outlineVariant),
                Expanded(
                  child: _MiniStat(
                    label: 'Overdue',
                    value: '₹${_formatAmount(summary.totalOverdue)}',
                    color: AppColors.error,
                  ),
                ),
                if (summary.totalRefunded > 0) ...[
                  Container(width: 1, height: 30, color: theme.colorScheme.outlineVariant),
                  Expanded(
                    child: _MiniStat(
                      label: 'Refunded',
                      value: '₹${_formatAmount(summary.totalRefunded)}',
                      color: AppColors.info,
                    ),
                  ),
                ],
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

class _MonthlyBarChart extends StatelessWidget {
  final List<FeeMonthlyData> data;
  const _MonthlyBarChart({required this.data});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (data.isEmpty) return const SizedBox.shrink();
    final maxVal = data.map((d) => d.total).reduce((a, b) => a > b ? a : b);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: data.map((d) {
        final ratio = maxVal > 0 ? d.total / maxVal : 0.0;
        final month = d.month.length >= 7 ? d.month.substring(5) : d.month;
        return Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 3),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (d.total > 0)
                  Text(
                    _formatAmount(d.total),
                    style: TextStyle(
                      fontSize: 9,
                      color: theme.colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                const SizedBox(height: 4),
                Flexible(
                  child: FractionallySizedBox(
                    heightFactor: ratio.clamp(0.04, 1.0),
                    child: Tooltip(
                      message:
                          '₹${d.total.toStringAsFixed(0)} · ${d.count} payments',
                      child: Container(
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primary.withValues(alpha: 0.8),
                          borderRadius: BorderRadius.vertical(
                            top: Radius.circular(6),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  month,
                  style: TextStyle(
                    fontSize: 10,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
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
          const Icon(
            Icons.error_outline_rounded,
            color: AppColors.error,
            size: 40,
          ),
          const SizedBox(height: 10),
          Text(
            error,
            textAlign: TextAlign.center,
            style: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontSize: 13),
          ),
          const SizedBox(height: 16),
          OutlinedButton(onPressed: onRetry, child: const Text('Retry')),
        ],
      ),
    );
  }
}

String _fmtDate(DateTime d) {
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
  return '${d.day} ${months[d.month - 1]}';
}

String _formatAmount(double v) {
  if (v >= 100000) return '${(v / 100000).toStringAsFixed(1)}L';
  if (v >= 1000) return '${(v / 1000).toStringAsFixed(1)}K';
  return v.toStringAsFixed(0);
}
