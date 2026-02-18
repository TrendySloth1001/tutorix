import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../services/fee_service.dart';
import 'fee_record_detail_screen.dart';

/// Per-student fee breakdown — shows all assignments/records, ledger totals,
/// and quick actions (collect, remind) for an admin view.
class FeeMemberProfileScreen extends StatefulWidget {
  final String coachingId;
  final String memberId;
  final String? memberName;

  const FeeMemberProfileScreen({
    super.key,
    required this.coachingId,
    required this.memberId,
    this.memberName,
  });

  @override
  State<FeeMemberProfileScreen> createState() => _FeeMemberProfileScreenState();
}

class _FeeMemberProfileScreenState extends State<FeeMemberProfileScreen> {
  final _svc = FeeService();
  bool _loading = true;
  String? _error;
  Map<String, dynamic>? _profile;

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
      final data = await _svc.getMemberFeeProfile(
        widget.coachingId,
        widget.memberId,
      );
      setState(() {
        _profile = data;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _sendReminder(String recordId) async {
    try {
      await _svc.sendReminder(widget.coachingId, recordId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Reminder sent')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed: ${e.toString()}')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final memberData = _profile?['member'] as Map<String, dynamic>?;
    final displayName = widget.memberName ??
        (memberData?['name'] as String?) ??
        (memberData?['ward']?['name'] as String?) ??
        'Student';

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
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Fee Profile',
              style: TextStyle(
                color: AppColors.darkOlive,
                fontWeight: FontWeight.w700,
                fontSize: 17,
              ),
            ),
            Text(
              displayName,
              style: const TextStyle(
                color: AppColors.mutedOlive,
                fontSize: 12,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: AppColors.darkOlive),
            onPressed: _load,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? _ErrorRetry(error: _error!, onRetry: _load)
          : _ProfileBody(
              profile: _profile!,
              coachingId: widget.coachingId,
              onRemind: _sendReminder,
              onRecordTap: (recordId) async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => FeeRecordDetailScreen(
                      coachingId: widget.coachingId,
                      recordId: recordId,
                      isAdmin: true,
                    ),
                  ),
                );
                _load();
              },
            ),
    );
  }
}

// ── Body ──────────────────────────────────────────────────────────

class _ProfileBody extends StatelessWidget {
  final Map<String, dynamic> profile;
  final String coachingId;
  final Future<void> Function(String recordId) onRemind;
  final Future<void> Function(String recordId) onRecordTap;

  const _ProfileBody({
    required this.profile,
    required this.coachingId,
    required this.onRemind,
    required this.onRecordTap,
  });

  @override
  Widget build(BuildContext context) {
    final ledger = profile['ledger'] as Map<String, dynamic>? ?? {};
    final assignments = (profile['assignments'] as List<dynamic>?) ?? [];

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      children: [
        _LedgerBanner(ledger: ledger),
        const SizedBox(height: 20),
        if (assignments.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 40),
            child: Center(
              child: Text(
                'No active fee assignments',
                style: TextStyle(color: AppColors.mutedOlive),
              ),
            ),
          )
        else
          ...assignments.map((a) {
            final assignment = a as Map<String, dynamic>;
            return _AssignmentSection(
              assignment: assignment,
              onRemind: onRemind,
              onRecordTap: onRecordTap,
            );
          }),
      ],
    );
  }
}

// ── Ledger Banner ─────────────────────────────────────────────────

class _LedgerBanner extends StatelessWidget {
  final Map<String, dynamic> ledger;

  const _LedgerBanner({required this.ledger});

  @override
  Widget build(BuildContext context) {
    final totalFee = (ledger['totalFee'] as num?)?.toDouble() ?? 0;
    final totalPaid = (ledger['totalPaid'] as num?)?.toDouble() ?? 0;
    final totalRefunded = (ledger['totalRefunded'] as num?)?.toDouble() ?? 0;
    final balance = (ledger['balance'] as num?)?.toDouble() ?? 0;
    final totalOverdue = (ledger['totalOverdue'] as num?)?.toDouble() ?? 0;

    // Progress bar: paid fraction of totalFee
    final paidFraction = totalFee > 0 ? (totalPaid / totalFee).clamp(0.0, 1.0) : 0.0;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.darkOlive,
        borderRadius: BorderRadius.circular(20),
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Total Fees',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '₹${_fmt(totalFee)}',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 32,
              fontWeight: FontWeight.w800,
              height: 1.0,
            ),
          ),
          const SizedBox(height: 16),
          // Progress bar
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: paidFraction,
              minHeight: 8,
              backgroundColor: Colors.white24,
              valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF81C784)),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _BannerStat(
                  label: 'Paid',
                  value: '₹${_fmt(totalPaid)}',
                  color: const Color(0xFF81C784),
                ),
              ),
              Expanded(
                child: _BannerStat(
                  label: 'Balance',
                  value: '₹${_fmt(balance)}',
                  color: balance > 0 ? const Color(0xFFFFB74D) : const Color(0xFF81C784),
                ),
              ),
              Expanded(
                child: _BannerStat(
                  label: 'Overdue',
                  value: '₹${_fmt(totalOverdue)}',
                  color: totalOverdue > 0 ? const Color(0xFFEF9A9A) : Colors.white54,
                ),
              ),
            ],
          ),
          if (totalRefunded > 0) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                const Icon(
                  Icons.keyboard_return_rounded,
                  size: 14,
                  color: Colors.white54,
                ),
                const SizedBox(width: 4),
                Text(
                  'Refunded: ₹${_fmt(totalRefunded)}',
                  style: const TextStyle(color: Colors.white54, fontSize: 12),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _BannerStat extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _BannerStat({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          label,
          style: const TextStyle(color: Colors.white54, fontSize: 11),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(
            color: color,
            fontSize: 14,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

// ── Assignment Section ────────────────────────────────────────────

class _AssignmentSection extends StatelessWidget {
  final Map<String, dynamic> assignment;
  final Future<void> Function(String recordId) onRemind;
  final Future<void> Function(String recordId) onRecordTap;

  const _AssignmentSection({
    required this.assignment,
    required this.onRemind,
    required this.onRecordTap,
  });

  @override
  Widget build(BuildContext context) {
    final feeStructure = assignment['feeStructure'] as Map<String, dynamic>? ?? {};
    final structureName = feeStructure['name'] as String? ?? 'Fee Plan';
    final cycle = feeStructure['cycle'] as String? ?? '';
    final customAmount = (assignment['customAmount'] as num?)?.toDouble();
    final discountAmount = (assignment['discountAmount'] as num?)?.toDouble() ?? 0;
    final scholarshipTag = assignment['scholarshipTag'] as String?;

    final records = (assignment['records'] as List<dynamic>?) ?? [];

    // Status summary counts
    var paidCount = 0;
    var partialCount = 0;
    var overdueCount = 0;
    var pendingCount = 0;

    for (final r in records) {
      final rec = r as Map<String, dynamic>;
      switch (rec['status'] as String? ?? '') {
        case 'PAID':
        case 'WAIVED':
          paidCount++;
        case 'PARTIALLY_PAID':
          partialCount++;
        case 'OVERDUE':
          overdueCount++;
        default:
          pendingCount++;
      }
    }

    final total = records.length;

    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Assignment header
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      structureName,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                        color: AppColors.darkOlive,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        _SmallChip(
                          label: _cycleName(cycle),
                          color: AppColors.mutedOlive,
                        ),
                        if (customAmount != null) ...[
                          const SizedBox(width: 4),
                          _SmallChip(
                            label: 'Custom ₹${_fmt(customAmount)}',
                            color: const Color(0xFF1565C0),
                          ),
                        ],
                        if (discountAmount > 0) ...[
                          const SizedBox(width: 4),
                          _SmallChip(
                            label: '-₹${_fmt(discountAmount)}',
                            color: const Color(0xFF2E7D32),
                          ),
                        ],
                        if (scholarshipTag != null) ...[
                          const SizedBox(width: 4),
                          _SmallChip(
                            label: scholarshipTag,
                            color: const Color(0xFFE65100),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              Text(
                '$paidCount/$total',
                style: const TextStyle(
                  color: AppColors.mutedOlive,
                  fontSize: 12,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Status bar
          if (total > 0) _StatusBar(
            paid: paidCount,
            partial: partialCount,
            overdue: overdueCount,
            pending: pendingCount,
            total: total,
          ),
          const SizedBox(height: 10),

          // Record tiles
          ...records.map((r) {
            final rec = r as Map<String, dynamic>;
            final recordId = rec['id'] as String? ?? '';
            return _RecordRow(
              record: rec,
              onTap: () => onRecordTap(recordId),
              onRemind: () => onRemind(recordId),
            );
          }),
        ],
      ),
    );
  }
}

// ── Status Bar ────────────────────────────────────────────────────

class _StatusBar extends StatelessWidget {
  final int paid;
  final int partial;
  final int overdue;
  final int pending;
  final int total;

  const _StatusBar({
    required this.paid,
    required this.partial,
    required this.overdue,
    required this.pending,
    required this.total,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: Row(
            children: [
              if (paid > 0)
                Expanded(
                  flex: paid,
                  child: Container(
                    height: 8,
                    color: const Color(0xFF2E7D32),
                  ),
                ),
              if (partial > 0)
                Expanded(
                  flex: partial,
                  child: Container(
                    height: 8,
                    color: const Color(0xFFE65100),
                  ),
                ),
              if (overdue > 0)
                Expanded(
                  flex: overdue,
                  child: Container(
                    height: 8,
                    color: const Color(0xFFC62828),
                  ),
                ),
              if (pending > 0)
                Expanded(
                  flex: pending,
                  child: Container(
                    height: 8,
                    color: AppColors.softGrey,
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            if (paid > 0) _BarLegend(label: 'Paid $paid', color: const Color(0xFF2E7D32)),
            if (partial > 0) _BarLegend(label: 'Partial $partial', color: const Color(0xFFE65100)),
            if (overdue > 0) _BarLegend(label: 'Overdue $overdue', color: const Color(0xFFC62828)),
            if (pending > 0) _BarLegend(label: 'Pending $pending', color: AppColors.mutedOlive),
          ],
        ),
      ],
    );
  }
}

class _BarLegend extends StatelessWidget {
  final String label;
  final Color color;

  const _BarLegend({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 10),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

// ── Record Row ────────────────────────────────────────────────────

class _RecordRow extends StatelessWidget {
  final Map<String, dynamic> record;
  final VoidCallback onTap;
  final VoidCallback onRemind;

  const _RecordRow({
    required this.record,
    required this.onTap,
    required this.onRemind,
  });

  @override
  Widget build(BuildContext context) {
    final title = record['title'] as String? ?? 'Fee';
    final status = record['status'] as String? ?? 'PENDING';
    final finalAmount = (record['finalAmount'] as num?)?.toDouble() ?? 0;
    final paidAmount = (record['paidAmount'] as num?)?.toDouble() ?? 0;
    final daysOverdue = record['daysOverdue'] as int? ?? 0;
    final dueDateRaw = record['dueDate'];
    DateTime? dueDate;
    if (dueDateRaw is String) dueDate = DateTime.tryParse(dueDateRaw);
    final statusColor = _statusColor(status);
    final isPaid = status == 'PAID' || status == 'WAIVED';
    final isOverdue = status == 'OVERDUE';

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: AppColors.softGrey.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              children: [
                Container(
                  width: 9,
                  height: 9,
                  decoration: BoxDecoration(
                    color: statusColor,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                          color: AppColors.darkOlive,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          _SmallChip(label: _statusLabel(status), color: statusColor),
                          if (dueDate != null) ...[
                            const SizedBox(width: 4),
                            _SmallChip(
                              label: 'Due ${_fmtDate(dueDate)}',
                              color: isOverdue
                                  ? const Color(0xFFC62828)
                                  : AppColors.mutedOlive,
                            ),
                          ],
                          if (daysOverdue > 0) ...[
                            const SizedBox(width: 4),
                            _SmallChip(
                              label: '${daysOverdue}d overdue',
                              color: const Color(0xFFC62828),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '₹${_fmt(finalAmount)}',
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        color: AppColors.darkOlive,
                        fontSize: 14,
                      ),
                    ),
                    if (paidAmount > 0 && !isPaid)
                      Text(
                        'Paid ₹${_fmt(paidAmount)}',
                        style: const TextStyle(
                          color: Color(0xFF2E7D32),
                          fontSize: 11,
                        ),
                      ),
                  ],
                ),
                if (!isPaid) ...[
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: onRemind,
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: AppColors.mutedOlive.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.notifications_active_outlined,
                        size: 16,
                        color: AppColors.mutedOlive,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Helpers ───────────────────────────────────────────────────────

class _SmallChip extends StatelessWidget {
  final String label;
  final Color color;

  const _SmallChip({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(5),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

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
          const Icon(Icons.error_outline_rounded, color: Colors.redAccent, size: 40),
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

String _fmt(double v) {
  if (v >= 1000) {
    return v.toStringAsFixed(0);
  }
  return v.toStringAsFixed(0);
}

Color _statusColor(String s) {
  switch (s) {
    case 'PAID':
      return const Color(0xFF2E7D32);
    case 'PENDING':
      return const Color(0xFF1565C0);
    case 'OVERDUE':
      return const Color(0xFFC62828);
    case 'PARTIALLY_PAID':
      return const Color(0xFFE65100);
    case 'WAIVED':
      return AppColors.mutedOlive;
    default:
      return AppColors.mutedOlive;
  }
}

String _statusLabel(String s) {
  switch (s) {
    case 'PAID':
      return 'Paid';
    case 'PENDING':
      return 'Pending';
    case 'OVERDUE':
      return 'Overdue';
    case 'PARTIALLY_PAID':
      return 'Partial';
    case 'WAIVED':
      return 'Waived';
    default:
      return s;
  }
}

String _cycleName(String c) {
  switch (c) {
    case 'MONTHLY':
      return 'Monthly';
    case 'QUARTERLY':
      return 'Quarterly';
    case 'HALF_YEARLY':
      return 'Half-Yearly';
    case 'YEARLY':
      return 'Yearly';
    case 'ONE_TIME':
      return 'One-Time';
    default:
      return c;
  }
}

String _fmtDate(DateTime d) {
  const months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];
  return '${d.day} ${months[d.month - 1]}';
}
