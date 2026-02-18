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
      setState(() {
        _overdueRecords = records;
        _loadingOverdue = false;
      });
    } catch (e) {
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
      setState(() {
        _summary = s;
        _loadingSummary = false;
      });
    } catch (e) {
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
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            color: AppColors.darkOlive,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Reports',
          style: TextStyle(
            color: AppColors.darkOlive,
            fontWeight: FontWeight.w700,
            fontSize: 20,
          ),
        ),
        bottom: TabBar(
          controller: _tabs,
          indicatorColor: AppColors.darkOlive,
          labelColor: AppColors.darkOlive,
          unselectedLabelColor: AppColors.mutedOlive,
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
            color: AppColors.darkOlive,
            onRefresh: _loadOverdue,
            child: _loadingOverdue
                ? const Center(child: CircularProgressIndicator())
                : _overdueError != null
                ? _ErrorRetry(error: _overdueError!, onRetry: _loadOverdue)
                : _overdueRecords.isEmpty
                ? ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    children: const [
                      SizedBox(height: 200),
                      Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.check_circle_outline_rounded,
                              size: 52,
                              color: Color(0xFF2E7D32),
                            ),
                            SizedBox(height: 12),
                            Text(
                              'No overdue fees!',
                              style: TextStyle(
                                color: AppColors.darkOlive,
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
            color: AppColors.darkOlive,
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
    return ListView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      itemCount: records.length,
      itemBuilder: (ctx, i) {
        final r = records[i];
        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Material(
            color: const Color(0xFFFFEBEE),
            borderRadius: BorderRadius.circular(14),
            child: InkWell(
              borderRadius: BorderRadius.circular(14),
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
                padding: const EdgeInsets.all(14),
                child: Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFCDD2),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Center(
                        child: Text(
                          '${r.daysOverdue}d',
                          style: const TextStyle(
                            color: Color(0xFFC62828),
                            fontWeight: FontWeight.w800,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            r.member?.name ?? 'Unknown Student',
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              color: AppColors.darkOlive,
                              fontSize: 14,
                            ),
                          ),
                          Text(
                            r.title,
                            style: const TextStyle(
                              color: AppColors.mutedOlive,
                              fontSize: 12,
                            ),
                          ),
                          Text(
                            'Due since ${_fmtDate(r.dueDate)}',
                            style: const TextStyle(
                              color: Color(0xFFC62828),
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          '₹${r.balance.toStringAsFixed(0)}',
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            color: Color(0xFFC62828),
                            fontSize: 15,
                          ),
                        ),
                        if (r.fineAmount > 0)
                          Text(
                            '+₹${r.fineAmount.toStringAsFixed(0)} fine',
                            style: const TextStyle(
                              color: AppColors.mutedOlive,
                              fontSize: 10,
                            ),
                          ),
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
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      children: [
        // FY selector
        Row(
          children: [
            const Text(
              'Financial Year',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: AppColors.darkOlive,
                fontSize: 15,
              ),
            ),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.softGrey.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: AppColors.mutedOlive.withValues(alpha: 0.3),
                ),
              ),
              child: DropdownButton<String>(
                value: selectedFY,
                underline: const SizedBox.shrink(),
                isDense: true,
                style: const TextStyle(
                  color: AppColors.darkOlive,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
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
        const SizedBox(height: 20),

        // KPI cards
        Row(
          children: [
            Expanded(
              child: _ReportKpi(
                label: 'Collected',
                amount: summary.totalCollected,
                color: const Color(0xFF2E7D32),
                bg: const Color(0xFFE8F5E9),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _ReportKpi(
                label: 'Overdue',
                amount: summary.totalOverdue,
                color: const Color(0xFFC62828),
                bg: const Color(0xFFFFEBEE),
                badge: summary.overdueCount > 0
                    ? '${summary.overdueCount} students'
                    : null,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _ReportKpi(
                label: 'Pending',
                amount: summary.totalPending,
                color: const Color(0xFF1565C0),
                bg: const Color(0xFFE3F2FD),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _ReportKpi(
                label: 'Today',
                amount: summary.todayCollection,
                color: const Color(0xFFE65100),
                bg: const Color(0xFFFFF3E0),
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),

        // Monthly bar chart
        const Text(
          'Monthly Collection',
          style: TextStyle(
            fontWeight: FontWeight.w700,
            color: AppColors.darkOlive,
            fontSize: 15,
          ),
        ),
        const SizedBox(height: 12),
        summary.monthlyCollection.isEmpty
            ? const Center(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: Text(
                    'No data for this financial year',
                    style: TextStyle(color: AppColors.mutedOlive),
                  ),
                ),
              )
            : _MonthlyBarChart(data: summary.monthlyCollection),
        const SizedBox(height: 32),
      ],
    );
  }
}

class _ReportKpi extends StatelessWidget {
  final String label;
  final double amount;
  final Color color;
  final Color bg;
  final String? badge;
  const _ReportKpi({
    required this.label,
    required this.amount,
    required this.color,
    required this.bg,
    this.badge,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
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
          if (badge != null) ...[
            const SizedBox(height: 4),
            Text(
              badge!,
              style: TextStyle(
                color: color,
                fontSize: 10,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _MonthlyBarChart extends StatelessWidget {
  final List<FeeMonthlyData> data;
  const _MonthlyBarChart({required this.data});

  @override
  Widget build(BuildContext context) {
    if (data.isEmpty) return const SizedBox.shrink();
    final maxVal = data.map((d) => d.total).reduce((a, b) => a > b ? a : b);
    return Column(
      children: [
        SizedBox(
          height: 120,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: data.map((d) {
              final ratio = maxVal > 0 ? d.total / maxVal : 0.0;
              final month = d.month.length >= 7
                  ? d.month.substring(5)
                  : d.month;
              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      if (d.total > 0)
                        Text(
                          _formatAmount(d.total),
                          style: const TextStyle(
                            fontSize: 8,
                            color: AppColors.mutedOlive,
                          ),
                        ),
                      const SizedBox(height: 2),
                      Flexible(
                        child: FractionallySizedBox(
                          heightFactor: ratio.clamp(0.04, 1.0),
                          child: Tooltip(
                            message:
                                '₹${d.total.toStringAsFixed(0)} · ${d.count} payments',
                            child: Container(
                              decoration: BoxDecoration(
                                color: AppColors.darkOlive.withValues(
                                  alpha: 0.75,
                                ),
                                borderRadius: BorderRadius.circular(4),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        month,
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
        ),
        const SizedBox(height: 8),
        // Month totals table
        ...data
            .where((d) => d.total > 0)
            .map(
              (d) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Row(
                  children: [
                    Text(
                      d.month,
                      style: const TextStyle(
                        color: AppColors.mutedOlive,
                        fontSize: 12,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      '${d.count} payment${d.count == 1 ? '' : 's'}',
                      style: const TextStyle(
                        color: AppColors.mutedOlive,
                        fontSize: 11,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      '₹${d.total.toStringAsFixed(0)}',
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        color: AppColors.darkOlive,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ),
      ],
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
            color: Colors.redAccent,
            size: 40,
          ),
          const SizedBox(height: 10),
          Text(
            error,
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppColors.mutedOlive, fontSize: 13),
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
