import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../coaching/services/member_service.dart';
import '../services/fee_service.dart';
import 'fee_record_detail_screen.dart';
import '../../../core/theme/design_tokens.dart';

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
              backgroundColor: cs.surfaceContainerHighest,
              child: picture == null
                  ? Text(
                      displayName[0].toUpperCase(),
                      style: TextStyle(fontSize: FontSize.caption, color: cs.onSurface),
                    )
                  : null,
            ),
            const SizedBox(width: Spacing.sp10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  displayName,
                  style: TextStyle(
                    color: cs.onSurface,
                    fontWeight: FontWeight.w700,
                    fontSize: FontSize.sub,
                  ),
                ),
                Text(
                  'Student Profile',
                  style: TextStyle(color: cs.onSurfaceVariant, fontSize: FontSize.caption),
                ),
              ],
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh_rounded, color: cs.onSurface),
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
              labelColor: cs.primary,
              unselectedLabelColor: cs.onSurfaceVariant,
              indicatorColor: cs.primary,
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
    final theme = Theme.of(context);
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
      padding: const EdgeInsets.all(Spacing.sp16),
      children: [
        _LedgerBanner(ledger: ledger),
        const SizedBox(height: Spacing.sp20),
        if (filteredAssignments.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: Spacing.sp40),
            child: Center(
              child: Text(
                'No active fee assignments',
                style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
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
    final theme = Theme.of(context);
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null)
      return _ErrorRetry(error: _error!, onRetry: _loadResults);
    if (_results.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.school_outlined,
              size: 48,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: Spacing.sp16),
            Text(
              'No academic records found',
              style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(Spacing.sp16),
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
          margin: const EdgeInsets.only(bottom: Spacing.sp12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(Radii.md),
            side: BorderSide(color: theme.colorScheme.outlineVariant),
          ),
          child: Padding(
            padding: const EdgeInsets.all(Spacing.sp16),
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
                      fontSize: FontSize.body,
                    ),
                  ),
                ),
                const SizedBox(width: Spacing.sp16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: FontSize.body,
                          color: theme.colorScheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: Spacing.sp4),
                      Text(
                        '${type.toUpperCase()} • ${date != null ? DateFormat('MMM d, y').format(date) : ''}',
                        style: TextStyle(
                          fontSize: FontSize.caption,
                          color: theme.colorScheme.onSurfaceVariant,
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
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: FontSize.body,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                    Text(
                      'Score',
                      style: TextStyle(
                        fontSize: FontSize.micro,
                        color: theme.colorScheme.onSurfaceVariant,
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
    final cs = Theme.of(context).colorScheme;
    if (percent >= 80) return cs.primary;
    if (percent >= 60) return cs.secondary;
    if (percent >= 40) return cs.secondary;
    return cs.error;
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
      padding: const EdgeInsets.all(Spacing.sp16),
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
          const SizedBox(height: Spacing.sp16),
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
    final theme = Theme.of(context);
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(Radii.md),
        side: BorderSide(color: theme.colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(Spacing.sp16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: FontSize.body,
                color: theme.colorScheme.onSurfaceVariant,
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
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: Spacing.sp12),
      child: Row(
        children: [
          Icon(icon, size: 18, color: theme.colorScheme.onSurfaceVariant),
          const SizedBox(width: Spacing.sp12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: FontSize.micro,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              Text(
                value,
                style: TextStyle(
                  fontSize: FontSize.body,
                  fontWeight: FontWeight.w500,
                  color: theme.colorScheme.onSurface,
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
    final theme = Theme.of(context);
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
        color: theme.colorScheme.primary,
        borderRadius: BorderRadius.circular(Radii.lg),
      ),
      padding: const EdgeInsets.all(Spacing.sp20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Total Fees',
            style: TextStyle(
              color: Colors.white70,
              fontSize: FontSize.caption,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: Spacing.sp4),
          Text(
            '₹${_fmt(totalFee)}',
            style: const TextStyle(
              color: Colors.white,
              fontSize: FontSize.hero,
              fontWeight: FontWeight.w800,
              height: 1.0,
            ),
          ),
          const SizedBox(height: Spacing.sp16),
          ClipRRect(
            borderRadius: BorderRadius.circular(Radii.sm),
            child: LinearProgressIndicator(
              value: paidFraction,
              minHeight: 8,
              backgroundColor: Colors.white24,
              valueColor: AlwaysStoppedAnimation<Color>(
                theme.colorScheme.onPrimary.withValues(alpha: 0.9),
              ),
            ),
          ),
          const SizedBox(height: Spacing.sp16),
          Row(
            children: [
              Expanded(
                child: _BannerStat(
                  label: 'Paid',
                  value: '₹${_fmt(totalPaid)}',
                  color: totalPaid > 0
                      ? theme.colorScheme.onPrimary
                      : Colors.white54,
                ),
              ),
              Expanded(
                child: _BannerStat(
                  label: 'Balance',
                  value: '₹${_fmt(balance > 0 ? balance : 0)}',
                  color: balance > 0
                      ? theme.colorScheme.onPrimary
                      : Colors.white54,
                ),
              ),
              Expanded(
                child: _BannerStat(
                  label: 'Overdue',
                  value: '₹${_fmt(totalOverdue)}',
                  color: totalOverdue > 0
                      ? theme.colorScheme.onPrimary
                      : Colors.white54,
                ),
              ),
            ],
          ),
          if (balance < 0) ...[
            const SizedBox(height: Spacing.sp12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Available Credits',
                  style: TextStyle(
                    color: theme.colorScheme.onPrimary.withValues(alpha: 0.8),
                    fontSize: FontSize.caption,
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
                    backgroundColor: theme.colorScheme.onPrimary.withValues(
                      alpha: 0.15,
                    ),
                    foregroundColor: theme.colorScheme.onPrimary,
                    padding: const EdgeInsets.symmetric(horizontal: Spacing.sp10),
                    minimumSize: const Size(0, 28),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    elevation: 0,
                  ),
                ),
              ],
            ),
          ],
          if (totalRefunded > 0) ...[
            const SizedBox(height: Spacing.sp12),
            Row(
              children: [
                const Icon(
                  Icons.keyboard_return_rounded,
                  size: 14,
                  color: Colors.white54,
                ),
                const SizedBox(width: Spacing.sp4),
                Text(
                  'Refunded: ₹${_fmt(totalRefunded)}',
                  style: const TextStyle(color: Colors.white54, fontSize: FontSize.caption),
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
          style: const TextStyle(color: Colors.white54, fontSize: FontSize.micro),
        ),
        const SizedBox(height: Spacing.sp2),
        Text(
          value,
          style: TextStyle(
            color: color,
            fontSize: FontSize.body,
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
    final theme = Theme.of(context);
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
      padding: const EdgeInsets.only(bottom: Spacing.sp20),
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
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: FontSize.body,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: Spacing.sp2),
                    _SmallChip(
                      label: _cycleName(cycle),
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ],
                ),
              ),
              Text(
                '$paidCount/$total',
                style: TextStyle(
                  color: theme.colorScheme.onSurfaceVariant,
                  fontSize: FontSize.caption,
                ),
              ),
            ],
          ),
          const SizedBox(height: Spacing.sp8),
          if (total > 0)
            _StatusBar(
              paid: paidCount,
              partial: partialCount,
              overdue: overdueCount,
              pending: pendingCount,
              total: total,
            ),
          const SizedBox(height: Spacing.sp10),
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
    final theme = Theme.of(context);
    return ClipRRect(
      borderRadius: BorderRadius.circular(Radii.sm),
      child: Row(
        children: [
          if (paid > 0)
            Expanded(
              flex: paid,
              child: Container(height: 8, color: theme.colorScheme.primary),
            ),
          if (partial > 0)
            Expanded(
              flex: partial,
              child: Container(height: 8, color: theme.colorScheme.secondary),
            ),
          if (overdue > 0)
            Expanded(
              flex: overdue,
              child: Container(height: 8, color: theme.colorScheme.error),
            ),
          if (pending > 0)
            Expanded(
              flex: pending,
              child: Container(
                height: 8,
                color: theme.colorScheme.outlineVariant,
              ),
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
    final theme = Theme.of(context);
    final title = record['title'] as String? ?? 'Fee';
    final status = record['status'] as String? ?? 'PENDING';
    final finalAmount = (record['finalAmount'] as num?)?.toDouble() ?? 0;
    final paidAmount = (record['paidAmount'] as num?)?.toDouble() ?? 0;
    final dueDateRaw = record['dueDate'];
    DateTime? dueDate;
    if (dueDateRaw is String) dueDate = DateTime.tryParse(dueDateRaw);
    final isPaid = status == 'PAID' || status == 'WAIVED';
    final statusColor = _statusColor(status, theme.colorScheme);

    return Padding(
      padding: const EdgeInsets.only(bottom: Spacing.sp8),
      child: Material(
        color: theme.colorScheme.outlineVariant.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(Radii.md),
        child: InkWell(
          borderRadius: BorderRadius.circular(Radii.md),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: Spacing.sp12, vertical: Spacing.sp10),
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
                const SizedBox(width: Spacing.sp10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: FontSize.body,
                          color: theme.colorScheme.onSurface,
                        ),
                      ),
                      Row(
                        children: [
                          _SmallChip(
                            label: _statusLabel(status),
                            color: statusColor,
                          ),
                          if (dueDate != null) ...[
                            const SizedBox(width: Spacing.sp4),
                            _SmallChip(
                              label: _fmtDate(dueDate),
                              color: theme.colorScheme.onSurfaceVariant,
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
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        color: theme.colorScheme.onSurface,
                        fontSize: FontSize.body,
                      ),
                    ),
                    if (paidAmount > 0 && !isPaid)
                      Text(
                        'Paid ₹${_fmt(paidAmount)}',
                        style: TextStyle(
                          color: theme.colorScheme.primary,
                          fontSize: FontSize.micro,
                        ),
                      ),
                  ],
                ),
                if (!isPaid && onRemind != null) ...[
                  const SizedBox(width: Spacing.sp8),
                  GestureDetector(
                    onTap: onRemind,
                    child: Container(
                      padding: const EdgeInsets.all(Spacing.sp6),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.onSurfaceVariant.withValues(
                          alpha: 0.1,
                        ),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.notifications_active_outlined,
                        size: 16,
                        color: theme.colorScheme.onSurfaceVariant,
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
      padding: const EdgeInsets.symmetric(horizontal: Spacing.sp6, vertical: Spacing.sp2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(Radii.sm),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: FontSize.nano,
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
          Icon(
            Icons.error_outline_rounded,
            color: Theme.of(context).colorScheme.error,
            size: 40,
          ),
          const SizedBox(height: Spacing.sp10),
          Text(
            error,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              fontSize: FontSize.body,
            ),
          ),
          const SizedBox(height: Spacing.sp16),
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

Color _statusColor(String s, ColorScheme cs) {
  switch (s) {
    case 'PAID':
      return cs.primary;
    case 'PENDING':
      return cs.secondary;
    case 'OVERDUE':
      return cs.error;
    case 'PARTIALLY_PAID':
      return cs.secondary;
    default:
      return cs.onSurfaceVariant;
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
