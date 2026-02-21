import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_colors.dart';
import '../../coaching/services/member_service.dart';
import '../services/fee_service.dart';
import 'fee_record_detail_screen.dart';

/// Unified Student Profile — Fees, Academic, and Personal details.
class FeeMemberProfileScreen extends StatefulWidget {
  final String coachingId;
  final String memberId;
  final String? memberName;
  final bool isAdmin;

  const FeeMemberProfileScreen({
    super.key,
    required this.coachingId,
    required this.memberId,
    this.memberName,
    this.isAdmin = true,
  });

  @override
  State<FeeMemberProfileScreen> createState() => _FeeMemberProfileScreenState();
}

class _FeeMemberProfileScreenState extends State<FeeMemberProfileScreen> {
  final _feeSvc = FeeService();
  bool _loading = true;
  String? _error;
  Map<String, dynamic>? _feeProfile;

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
      final data = await _feeSvc.getMemberFeeProfile(
        widget.coachingId,
        widget.memberId,
      );
      if (!mounted) return;
      setState(() {
        _feeProfile = data;
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
    final memberData = _feeProfile?['member'] as Map<String, dynamic>?;
    final displayName =
        widget.memberName ??
        (memberData?['name'] as String?) ??
        (memberData?['ward']?['name'] as String?) ??
        'Student';
    final picture =
        (memberData?['user']?['picture'] as String?) ??
        (memberData?['ward']?['picture'] as String?);

    return Scaffold(
      backgroundColor: cs.surface,
      appBar: AppBar(
        title: Row(
          children: [
            CircleAvatar(
              radius: 16,
              backgroundImage: picture != null ? NetworkImage(picture) : null,
              backgroundColor: AppColors.mutedOlive.withValues(alpha: 0.2),
              child: picture == null
                  ? Text(
                      displayName[0].toUpperCase(),
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.darkOlive,
                      ),
                    )
                  : null,
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  displayName,
                  style: const TextStyle(
                    color: AppColors.darkOlive,
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                  ),
                ),
                const Text(
                  'Student Profile',
                  style: TextStyle(color: AppColors.mutedOlive, fontSize: 12),
                ),
              ],
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: AppColors.darkOlive),
            onPressed: () {
              _load();
              setState(() {});
            },
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(
            color: Colors.grey.withValues(alpha: 0.2),
            height: 1,
          ),
        ),
      ),
      body: DefaultTabController(
        length: 3,
        child: Column(
          children: [
            TabBar(
              labelColor: AppColors.darkOlive,
              unselectedLabelColor: AppColors.mutedOlive,
              indicatorColor: AppColors.darkOlive,
              indicatorSize: TabBarIndicatorSize.label,
              labelStyle: const TextStyle(fontWeight: FontWeight.w600),
              tabs: const [
                Tab(text: 'Fees'),
                Tab(text: 'Academic'),
                Tab(text: 'Profile'),
              ],
            ),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _error != null
                  ? _ErrorRetry(error: _error!, onRetry: _load)
                  : TabBarView(
                      children: [
                        _FeeTab(
                          profile: _feeProfile!,
                          coachingId: widget.coachingId,
                          onRefresh: _load,
                          isAdmin: widget.isAdmin,
                        ),
                        _AcademicTab(
                          coachingId: widget.coachingId,
                          memberId: widget.memberId,
                        ),
                        _ProfileDetailsTab(member: memberData ?? {}),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Fee Tab ──────────────────────────────────────────────────────────

class _FeeTab extends StatelessWidget {
  final Map<String, dynamic> profile;
  final String coachingId;
  final VoidCallback onRefresh;
  final bool isAdmin;

  const _FeeTab({
    required this.profile,
    required this.coachingId,
    required this.onRefresh,
    this.isAdmin = true,
  });

  Future<void> _sendReminder(BuildContext context, String recordId) async {
    try {
      await FeeService().sendReminder(coachingId, recordId);
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Reminder sent')));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed: ${e.toString()}')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final ledger = profile['ledger'] as Map<String, dynamic>? ?? {};
    final assignments = (profile['assignments'] as List<dynamic>?) ?? [];

    // Filter assignments:
    // Show if status is NOT 'PENDING' (i.e. PAID, PARTIALLY_PAID, WAIVED, OVERDUE)
    // OR if dueDate is within the current or next month.
    final now = DateTime.now();
    final endOfNextMonth = DateTime(now.year, now.month + 2, 0);

    final filteredAssignments = assignments.where((a) {
      final assignment = a as Map<String, dynamic>;
      final records = (assignment['records'] as List<dynamic>?) ?? [];

      // We are displaying sections based on assignment, but the UI iterates over assignments?
      // Wait, _AssignmentSection iterates over records?
      // Let's check _AssignmentSection.
      // It seems _AssignmentSection might display multiple records.
      // If the assignment has ANY visible record, we show it?
      // Or does _AssignmentSection show all records?
      // Looking at the code for _AssignmentSection (not fully visible but inferred), it likely lists records.
      // I should probably pass the filter strictness down or filter the records within the assignment data structure before passing it.

      // Let's filter the records inside each assignment.
      final visibleRecords = records.where((r) {
        final record = r as Map<String, dynamic>;
        final status = record['status'] as String? ?? 'PENDING';
        final dateStr = record['dueDate'] as String?;
        DateTime? dueDate;
        if (dateStr != null) dueDate = DateTime.tryParse(dateStr);

        if (status != 'PENDING')
          return true; // Always show history/paid/overdue
        if (dueDate == null) return true; // Show if no date

        // Check if due date is before or on endOfNextMonth
        return dueDate.isBefore(endOfNextMonth) ||
            dueDate.isAtSameMomentAs(endOfNextMonth);
      }).toList();

      // Update the assignment's records with filtered list (creating a copy to avoid mutating original if needed, though here it's fine)
      assignment['records'] = visibleRecords;
      return visibleRecords.isNotEmpty;
    }).toList();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _LedgerBanner(ledger: ledger),
        const SizedBox(height: 20),
        if (filteredAssignments.isEmpty)
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
          ...filteredAssignments.map((a) {
            final assignment = a as Map<String, dynamic>;
            return _AssignmentSection(
              assignment: assignment,
              onRemind: isAdmin ? (id) => _sendReminder(context, id) : null,
              onRecordTap: (recordId) async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => FeeRecordDetailScreen(
                      coachingId: coachingId,
                      recordId: recordId,
                      isAdmin: isAdmin,
                    ),
                  ),
                );
                onRefresh();
              },
            );
          }),
      ],
    );
  }
}

// ── Academic Tab ─────────────────────────────────────────────────────

class _AcademicTab extends StatefulWidget {
  final String coachingId;
  final String memberId;

  const _AcademicTab({required this.coachingId, required this.memberId});

  @override
  State<_AcademicTab> createState() => _AcademicTabState();
}

class _AcademicTabState extends State<_AcademicTab>
    with AutomaticKeepAliveClientMixin {
  final _memberSvc = MemberService();
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _results = [];

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _loadResults();
  }

  Future<void> _loadResults() async {
    try {
      setState(() {
        _loading = true;
        _error = null;
      });
      final data = await _memberSvc.getMemberAcademicHistory(
        widget.coachingId,
        widget.memberId,
      );
      if (mounted) {
        setState(() {
          _results = data;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null)
      return _ErrorRetry(error: _error!, onRetry: _loadResults);
    if (_results.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.school_outlined, size: 48, color: AppColors.mutedOlive),
            SizedBox(height: 16),
            Text(
              'No academic records found',
              style: TextStyle(color: AppColors.mutedOlive),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _results.length,
      itemBuilder: (context, index) {
        final attempt = _results[index];
        final assessment = attempt['assessment'] as Map<String, dynamic>? ?? {};
        final title = assessment['title'] as String? ?? 'Assessment';
        final type = assessment['type'] as String? ?? '';
        final totalMarks = (assessment['totalMarks'] as num?)?.toDouble() ?? 0;
        final score = (attempt['totalScore'] as num?)?.toDouble() ?? 0;
        final percent = (attempt['percentage'] as num?)?.toDouble() ?? 0;
        final dateStr = attempt['submittedAt'] as String?;
        final date = dateStr != null ? DateTime.tryParse(dateStr) : null;

        return Card(
          elevation: 0,
          margin: const EdgeInsets.only(bottom: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: AppColors.softGrey.withValues(alpha: 0.5)),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    color: _gradeColor(percent).withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    '${percent.round()}%',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: _gradeColor(percent),
                      fontSize: 14,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                          color: AppColors.darkOlive,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${type.toUpperCase()} • ${date != null ? DateFormat('MMM d, y').format(date) : ''}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.mutedOlive,
                        ),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '${_fmt(score)}/${_fmt(totalMarks)}',
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                        color: AppColors.darkOlive,
                      ),
                    ),
                    const Text(
                      'Score',
                      style: TextStyle(
                        fontSize: 11,
                        color: AppColors.mutedOlive,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Color _gradeColor(double percent) {
    if (percent >= 80) return const Color(0xFF2E7D32);
    if (percent >= 60) return const Color(0xFF1565C0);
    if (percent >= 40) return const Color(0xFFE65100);
    return const Color(0xFFC62828);
  }
}

// ── Profile Tab ──────────────────────────────────────────────────────

class _ProfileDetailsTab extends StatelessWidget {
  final Map<String, dynamic> member;

  const _ProfileDetailsTab({required this.member});

  @override
  Widget build(BuildContext context) {
    final user = member['user'] as Map<String, dynamic>?;
    final ward = member['ward'] as Map<String, dynamic>?;
    final email = (user?['email'] as String?);
    final phone = (user?['phone'] as String?);
    final role = member['role'] as String? ?? 'STUDENT';
    final parent = ward?['parent'] as Map<String, dynamic>?;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _InfoCard(
          title: 'Contact Info',
          children: [
            if (email != null)
              _InfoRow(
                icon: Icons.email_outlined,
                label: 'Email',
                value: email,
              ),
            if (phone != null)
              _InfoRow(
                icon: Icons.phone_outlined,
                label: 'Phone',
                value: phone,
              ),
            _InfoRow(icon: Icons.badge_outlined, label: 'Role', value: role),
          ],
        ),
        if (ward != null && parent != null) ...[
          const SizedBox(height: 16),
          _InfoCard(
            title: 'Parent/Guardian',
            children: [
              _InfoRow(
                icon: Icons.person_outline,
                label: 'Name',
                value: parent['name'] ?? 'N/A',
              ),
              if (parent['email'] != null)
                _InfoRow(
                  icon: Icons.email_outlined,
                  label: 'Email',
                  value: parent['email'],
                ),
              if (parent['phone'] != null)
                _InfoRow(
                  icon: Icons.phone_outlined,
                  label: 'Phone',
                  value: parent['phone'],
                ),
            ],
          ),
        ],
      ],
    );
  }
}

class _InfoCard extends StatelessWidget {
  final String title;
  final List<Widget> children;

  const _InfoCard({required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: AppColors.softGrey.withValues(alpha: 0.5)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 14,
                color: AppColors.mutedOlive,
              ),
            ),
            const Divider(height: 24),
            ...children,
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Icon(icon, size: 18, color: AppColors.mutedOlive),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 11,
                  color: AppColors.mutedOlive,
                ),
              ),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: AppColors.darkOlive,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Shared Widgets ────────────────────────────────────────────────────

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
    final paidFraction = totalFee > 0
        ? (totalPaid / totalFee).clamp(0.0, 1.0)
        : 0.0;

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
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: paidFraction,
              minHeight: 8,
              backgroundColor: Colors.white24,
              valueColor: const AlwaysStoppedAnimation<Color>(
                Color(0xFF81C784),
              ),
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
                  value: '₹${_fmt(balance > 0 ? balance : 0)}',
                  color: balance > 0
                      ? const Color(0xFFFFB74D)
                      : const Color(0xFF81C784),
                ),
              ),
              Expanded(
                child: _BannerStat(
                  label: 'Overdue',
                  value: '₹${_fmt(totalOverdue)}',
                  color: totalOverdue > 0
                      ? const Color(0xFFEF9A9A)
                      : Colors.white54,
                ),
              ),
            ],
          ),
          if (balance < 0) ...[
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Available Credits',
                  style: TextStyle(
                    color: Color(0xFF81C784),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                FilledButton.icon(
                  onPressed: () {},
                  icon: const Icon(
                    Icons.account_balance_wallet_rounded,
                    size: 14,
                  ),
                  label: Text('₹${_fmt(balance.abs())}'),
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(
                      0xFF81C784,
                    ).withValues(alpha: 0.15),
                    foregroundColor: const Color(0xFF81C784),
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    minimumSize: const Size(0, 28),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    elevation: 0,
                  ),
                ),
              ],
            ),
          ],
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

class _AssignmentSection extends StatelessWidget {
  final Map<String, dynamic> assignment;
  final Function(String)? onRemind; // null = student view (no remind action)
  final Function(String) onRecordTap;

  const _AssignmentSection({
    required this.assignment,
    this.onRemind,
    required this.onRecordTap,
  });

  @override
  Widget build(BuildContext context) {
    final feeStructure =
        assignment['feeStructure'] as Map<String, dynamic>? ?? {};
    final structureName = feeStructure['name'] as String? ?? 'Fee Plan';
    final cycle = feeStructure['cycle'] as String? ?? '';
    final records = (assignment['records'] as List<dynamic>?) ?? [];

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
                    _SmallChip(
                      label: _cycleName(cycle),
                      color: AppColors.mutedOlive,
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
          if (total > 0)
            _StatusBar(
              paid: paidCount,
              partial: partialCount,
              overdue: overdueCount,
              pending: pendingCount,
              total: total,
            ),
          const SizedBox(height: 10),
          ...records.map((r) {
            final rec = r as Map<String, dynamic>;
            final recordId = rec['id'] as String? ?? '';
            return _RecordRow(
              record: rec,
              onTap: () => onRecordTap(recordId),
              onRemind: onRemind != null ? () => onRemind!(recordId) : null,
            );
          }),
        ],
      ),
    );
  }
}

class _StatusBar extends StatelessWidget {
  final int paid, partial, overdue, pending, total;
  const _StatusBar({
    required this.paid,
    required this.partial,
    required this.overdue,
    required this.pending,
    required this.total,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(6),
      child: Row(
        children: [
          if (paid > 0)
            Expanded(
              flex: paid,
              child: Container(height: 8, color: const Color(0xFF2E7D32)),
            ),
          if (partial > 0)
            Expanded(
              flex: partial,
              child: Container(height: 8, color: const Color(0xFFE65100)),
            ),
          if (overdue > 0)
            Expanded(
              flex: overdue,
              child: Container(height: 8, color: const Color(0xFFC62828)),
            ),
          if (pending > 0)
            Expanded(
              flex: pending,
              child: Container(height: 8, color: AppColors.softGrey),
            ),
        ],
      ),
    );
  }
}

class _RecordRow extends StatelessWidget {
  final Map<String, dynamic> record;
  final VoidCallback onTap;
  final VoidCallback? onRemind; // null = hide remind button (student view)

  const _RecordRow({required this.record, required this.onTap, this.onRemind});

  @override
  Widget build(BuildContext context) {
    final title = record['title'] as String? ?? 'Fee';
    final status = record['status'] as String? ?? 'PENDING';
    final finalAmount = (record['finalAmount'] as num?)?.toDouble() ?? 0;
    final paidAmount = (record['paidAmount'] as num?)?.toDouble() ?? 0;
    final dueDateRaw = record['dueDate'];
    DateTime? dueDate;
    if (dueDateRaw is String) dueDate = DateTime.tryParse(dueDateRaw);
    final isPaid = status == 'PAID' || status == 'WAIVED';
    final statusColor = _statusColor(status);

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
                      Row(
                        children: [
                          _SmallChip(
                            label: _statusLabel(status),
                            color: statusColor,
                          ),
                          if (dueDate != null) ...[
                            const SizedBox(width: 4),
                            _SmallChip(
                              label: _fmtDate(dueDate),
                              color: AppColors.mutedOlive,
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
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
                if (!isPaid && onRemind != null) ...[
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

String _fmt(double v) => v.toStringAsFixed(0);
String _fmtDate(DateTime d) => DateFormat('MMM d').format(d);
String _cycleName(String c) =>
    c.substring(0, 1) + c.substring(1).toLowerCase().replaceAll('_', ' ');

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
