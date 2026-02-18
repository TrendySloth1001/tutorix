import 'dart:async';
import 'package:flutter/material.dart';
import '../../../core/services/error_logger_service.dart';
import '../../../shared/widgets/app_shimmer.dart';
import '../models/assessment_model.dart';
import '../models/assignment_model.dart';
import '../services/assessment_service.dart';
import 'create_assessment_screen.dart';
import 'take_assessment_screen.dart';
import 'assessment_result_screen.dart';
import 'create_assignment_screen.dart';
import 'submit_assignment_screen.dart';
import 'assignment_submissions_screen.dart';

/// The assessment tab shown inside the batch detail screen.
/// Displays assessments and assignments in separate sub-tabs.
class AssessmentTabScreen extends StatefulWidget {
  final String coachingId;
  final String batchId;
  final bool isTeacher;

  const AssessmentTabScreen({
    super.key,
    required this.coachingId,
    required this.batchId,
    required this.isTeacher,
  });

  @override
  State<AssessmentTabScreen> createState() => _AssessmentTabScreenState();
}

class _AssessmentTabScreenState extends State<AssessmentTabScreen> {
  final AssessmentService _service = AssessmentService();

  List<AssessmentModel> _assessments = [];
  List<AssignmentModel> _assignments = [];
  bool _loading = true;
  int _selectedSegment = 0; // 0 = Assessments, 1 = Assignments

  final List<StreamSubscription> _subs = [];

  String get _role => widget.isTeacher ? 'TEACHER' : 'STUDENT';

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    for (final s in _subs) {
      s.cancel();
    }
    super.dispose();
  }

  void _loadData() {
    setState(() => _loading = true);
    for (final s in _subs) {
      s.cancel();
    }
    _subs.clear();

    int done = 0;
    void check() {
      done++;
      if (done >= 2 && mounted) setState(() => _loading = false);
    }

    _subs.add(
      _service
          .watchAssessments(widget.coachingId, widget.batchId, role: _role)
          .listen(
            (list) {
              if (mounted) setState(() => _assessments = list);
              check();
            },
            onError: (e) {
              ErrorLoggerService.instance.warn(
                'watchAssessments error',
                category: LogCategory.api,
                error: e.toString(),
              );
              check();
            },
          ),
    );

    _subs.add(
      _service
          .watchAssignments(widget.coachingId, widget.batchId, role: _role)
          .listen(
            (list) {
              if (mounted) setState(() => _assignments = list);
              check();
            },
            onError: (e) {
              ErrorLoggerService.instance.warn(
                'watchAssignments error',
                category: LogCategory.api,
                error: e.toString(),
              );
              check();
            },
          ),
    );
  }

  // ── Navigation ──

  void _openCreateAssessment() async {
    final created = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => CreateAssessmentScreen(
          coachingId: widget.coachingId,
          batchId: widget.batchId,
        ),
      ),
    );
    if (created == true) _loadData();
  }

  void _openCreateAssignment() async {
    final created = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => CreateAssignmentScreen(
          coachingId: widget.coachingId,
          batchId: widget.batchId,
        ),
      ),
    );
    if (created == true) _loadData();
  }

  void _openAssessment(AssessmentModel assessment) {
    if (widget.isTeacher) {
      // Teacher — view detail / attempts
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => AssessmentResultScreen(
            coachingId: widget.coachingId,
            batchId: widget.batchId,
            assessment: assessment,
            isTeacher: true,
          ),
        ),
      );
    } else {
      // Student — take or view result
      final inProgress = assessment.myAttempts
          .where((a) => a.status == 'IN_PROGRESS')
          .toList();
      final submitted = assessment.myAttempts
          .where((a) => a.status == 'SUBMITTED')
          .toList();

      if (inProgress.isNotEmpty || assessment.canAttempt) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => TakeAssessmentScreen(
              coachingId: widget.coachingId,
              batchId: widget.batchId,
              assessment: assessment,
            ),
          ),
        ).then((_) => _loadData());
      } else if (submitted.isNotEmpty) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => AssessmentResultScreen(
              coachingId: widget.coachingId,
              batchId: widget.batchId,
              assessment: assessment,
              isTeacher: false,
              attemptId: submitted.first.assessmentId != null
                  ? null
                  : null, // will use best attempt
            ),
          ),
        );
      }
    }
  }

  void _openAssignment(AssignmentModel assignment) {
    if (widget.isTeacher) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => AssignmentSubmissionsScreen(
            coachingId: widget.coachingId,
            batchId: widget.batchId,
            assignment: assignment,
          ),
        ),
      ).then((_) => _loadData());
    } else {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => SubmitAssignmentScreen(
            coachingId: widget.coachingId,
            batchId: widget.batchId,
            assignment: assignment,
          ),
        ),
      ).then((_) => _loadData());
    }
  }

  Future<void> _deleteAssessment(AssessmentModel a) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Assessment'),
        content: Text('Delete "${a.title}"? This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    await _service.deleteAssessment(widget.coachingId, widget.batchId, a.id);
    _loadData();
  }

  Future<void> _toggleAssessmentStatus(AssessmentModel a) async {
    final newStatus = a.isPublished ? 'CLOSED' : 'PUBLISHED';
    await _service.updateAssessmentStatus(
      widget.coachingId,
      widget.batchId,
      a.id,
      newStatus,
    );
    _loadData();
  }

  Future<void> _deleteAssignment(AssignmentModel a) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Assignment'),
        content: Text('Delete "${a.title}"? This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    await _service.deleteAssignment(widget.coachingId, widget.batchId, a.id);
    _loadData();
  }

  // ── Build ──

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      children: [
        // Segment control
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: Row(
            children: [
              _SegmentButton(
                label: 'Assessments',
                count: _assessments.length,
                isSelected: _selectedSegment == 0,
                onTap: () => setState(() => _selectedSegment = 0),
              ),
              const SizedBox(width: 8),
              _SegmentButton(
                label: 'Assignments',
                count: _assignments.length,
                isSelected: _selectedSegment == 1,
                onTap: () => setState(() => _selectedSegment = 1),
              ),
            ],
          ),
        ),

        // Content
        Expanded(
          child: _loading
              ? const _ShimmerList()
              : _selectedSegment == 0
              ? _buildAssessmentList(theme)
              : _buildAssignmentList(theme),
        ),
      ],
    );
  }

  Widget _buildAssessmentList(ThemeData theme) {
    if (_assessments.isEmpty) {
      return _EmptyState(
        icon: Icons.quiz_outlined,
        title: widget.isTeacher
            ? 'No assessments yet'
            : 'No assessments available',
        subtitle: widget.isTeacher
            ? 'Create your first quiz or test'
            : 'Your teacher hasn\'t created any assessments yet',
        showAction: widget.isTeacher,
        actionLabel: 'Create Assessment',
        onAction: _openCreateAssessment,
      );
    }

    return RefreshIndicator(
      onRefresh: () async => _loadData(),
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
        itemCount: _assessments.length,
        separatorBuilder: (_, _) => const SizedBox(height: 8),
        itemBuilder: (_, i) => _AssessmentCard(
          assessment: _assessments[i],
          isTeacher: widget.isTeacher,
          onTap: () => _openAssessment(_assessments[i]),
          onDelete: widget.isTeacher
              ? () => _deleteAssessment(_assessments[i])
              : null,
          onToggleStatus: widget.isTeacher
              ? () => _toggleAssessmentStatus(_assessments[i])
              : null,
        ),
      ),
    );
  }

  Widget _buildAssignmentList(ThemeData theme) {
    if (_assignments.isEmpty) {
      return _EmptyState(
        icon: Icons.assignment_outlined,
        title: widget.isTeacher
            ? 'No assignments yet'
            : 'No assignments available',
        subtitle: widget.isTeacher
            ? 'Create your first assignment'
            : 'Your teacher hasn\'t given any assignments yet',
        showAction: widget.isTeacher,
        actionLabel: 'Create Assignment',
        onAction: _openCreateAssignment,
      );
    }

    return RefreshIndicator(
      onRefresh: () async => _loadData(),
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
        itemCount: _assignments.length,
        separatorBuilder: (_, _) => const SizedBox(height: 8),
        itemBuilder: (_, i) => _AssignmentCard(
          assignment: _assignments[i],
          isTeacher: widget.isTeacher,
          onTap: () => _openAssignment(_assignments[i]),
          onDelete: widget.isTeacher
              ? () => _deleteAssignment(_assignments[i])
              : null,
        ),
      ),
    );
  }
}

// ─── Segment Button ──────────────────────────────────────────────────

class _SegmentButton extends StatelessWidget {
  final String label;
  final int count;
  final bool isSelected;
  final VoidCallback onTap;

  const _SegmentButton({
    required this.label,
    required this.count,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSelected
                ? theme.colorScheme.primary.withValues(alpha: 0.1)
                : theme.colorScheme.surfaceContainerHighest.withValues(
                    alpha: 0.5,
                  ),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected
                  ? theme.colorScheme.primary.withValues(alpha: 0.3)
                  : Colors.transparent,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                label,
                style: theme.textTheme.labelLarge?.copyWith(
                  color: isSelected
                      ? theme.colorScheme.primary
                      : theme.colorScheme.onSurfaceVariant,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                ),
              ),
              if (count > 0) ...[
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? theme.colorScheme.primary.withValues(alpha: 0.15)
                        : theme.colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '$count',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: isSelected
                          ? theme.colorScheme.primary
                          : theme.colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Assessment Card ─────────────────────────────────────────────────

class _AssessmentCard extends StatelessWidget {
  final AssessmentModel assessment;
  final bool isTeacher;
  final VoidCallback onTap;
  final VoidCallback? onDelete;
  final VoidCallback? onToggleStatus;

  const _AssessmentCard({
    required this.assessment,
    required this.isTeacher,
    required this.onTap,
    this.onDelete,
    this.onToggleStatus,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final a = assessment;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header row
            Row(
              children: [
                _TypeBadge(type: a.type),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    a.title,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                _StatusChip(status: a.status),
                if (isTeacher) ...[
                  const SizedBox(width: 4),
                  _PopupMenu(
                    onDelete: onDelete,
                    onToggleStatus: onToggleStatus,
                    statusLabel: a.isPublished ? 'Close' : 'Publish',
                  ),
                ],
              ],
            ),

            if (a.description != null && a.description!.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                a.description!,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],

            const SizedBox(height: 10),

            // Info chips row
            Wrap(
              spacing: 12,
              runSpacing: 4,
              children: [
                _InfoItem(
                  icon: Icons.help_outline_rounded,
                  label: '${a.questionCount} Qs',
                ),
                _InfoItem(
                  icon: Icons.star_outline_rounded,
                  label: '${a.totalMarks} marks',
                ),
                if (a.hasTimeLimit)
                  _InfoItem(
                    icon: Icons.timer_outlined,
                    label: '${a.durationMinutes} min',
                  ),
                if (a.maxAttempts > 1)
                  _InfoItem(
                    icon: Icons.replay_rounded,
                    label: '${a.maxAttempts} attempts',
                  ),
                if (isTeacher)
                  _InfoItem(
                    icon: Icons.people_outline_rounded,
                    label: '${a.attemptCount} submitted',
                  ),
              ],
            ),

            // Student attempt status
            if (!isTeacher && a.myAttempts.isNotEmpty) ...[
              const SizedBox(height: 8),
              _StudentAttemptBanner(assessment: a),
            ],
          ],
        ),
      ),
    );
  }
}

// ─── Assignment Card ─────────────────────────────────────────────────

class _AssignmentCard extends StatelessWidget {
  final AssignmentModel assignment;
  final bool isTeacher;
  final VoidCallback onTap;
  final VoidCallback? onDelete;

  const _AssignmentCard({
    required this.assignment,
    required this.isTeacher,
    required this.onTap,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final a = assignment;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.assignment_rounded,
                  size: 20,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    a.title,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (a.isClosed)
                  _StatusChip(status: 'CLOSED')
                else if (a.isPastDue)
                  _StatusChip(status: 'OVERDUE'),
                if (isTeacher && onDelete != null) ...[
                  const SizedBox(width: 4),
                  GestureDetector(
                    onTap: onDelete,
                    child: Icon(
                      Icons.delete_outline_rounded,
                      size: 18,
                      color: theme.colorScheme.error.withValues(alpha: 0.7),
                    ),
                  ),
                ],
              ],
            ),

            if (a.description != null && a.description!.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                a.description!,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],

            const SizedBox(height: 10),

            Wrap(
              spacing: 12,
              runSpacing: 4,
              children: [
                if (a.dueDate != null)
                  _InfoItem(
                    icon: Icons.event_outlined,
                    label: _formatDate(a.dueDate!),
                  ),
                if (a.totalMarks != null)
                  _InfoItem(
                    icon: Icons.star_outline_rounded,
                    label: '${a.totalMarks} marks',
                  ),
                if (a.attachments.isNotEmpty)
                  _InfoItem(
                    icon: Icons.attach_file_rounded,
                    label: '${a.attachments.length} files',
                  ),
                if (isTeacher)
                  _InfoItem(
                    icon: Icons.people_outline_rounded,
                    label: '${a.submissionCount} submitted',
                  ),
                if (a.allowLateSubmission)
                  _InfoItem(icon: Icons.schedule_rounded, label: 'Late OK'),
              ],
            ),

            // Student submission status
            if (!isTeacher && a.mySubmission != null) ...[
              const SizedBox(height: 8),
              _SubmissionBanner(submission: a.mySubmission!),
            ],
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime dt) {
    const months = [
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
    return '${dt.day} ${months[dt.month - 1]}, ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }
}

// ─── Helper Widgets ──────────────────────────────────────────────────

class _TypeBadge extends StatelessWidget {
  final String type;
  const _TypeBadge({required this.type});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = switch (type) {
      'TEST' => Colors.orange,
      'PRACTICE' => Colors.green,
      _ => theme.colorScheme.primary,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        type,
        style: theme.textTheme.labelSmall?.copyWith(
          color: color,
          fontWeight: FontWeight.w600,
          fontSize: 10,
        ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final String status;
  const _StatusChip({required this.status});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final (color, label) = switch (status) {
      'DRAFT' => (Colors.grey, 'Draft'),
      'PUBLISHED' => (Colors.green, 'Live'),
      'CLOSED' => (Colors.red, 'Closed'),
      'OVERDUE' => (Colors.orange, 'Overdue'),
      _ => (Colors.grey, status),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: theme.textTheme.labelSmall?.copyWith(
          color: color,
          fontWeight: FontWeight.w600,
          fontSize: 10,
        ),
      ),
    );
  }
}

class _InfoItem extends StatelessWidget {
  final IconData icon;
  final String label;
  const _InfoItem({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: theme.colorScheme.onSurfaceVariant),
        const SizedBox(width: 3),
        Text(
          label,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
            fontSize: 12,
          ),
        ),
      ],
    );
  }
}

class _PopupMenu extends StatelessWidget {
  final VoidCallback? onDelete;
  final VoidCallback? onToggleStatus;
  final String statusLabel;

  const _PopupMenu({
    this.onDelete,
    this.onToggleStatus,
    this.statusLabel = 'Publish',
  });

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      icon: const Icon(Icons.more_vert_rounded, size: 18),
      iconSize: 18,
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(),
      itemBuilder: (_) => [
        PopupMenuItem(value: 'status', child: Text(statusLabel)),
        const PopupMenuItem(
          value: 'delete',
          child: Text('Delete', style: TextStyle(color: Colors.red)),
        ),
      ],
      onSelected: (v) {
        if (v == 'status') onToggleStatus?.call();
        if (v == 'delete') onDelete?.call();
      },
    );
  }
}

class _StudentAttemptBanner extends StatelessWidget {
  final AssessmentModel assessment;
  const _StudentAttemptBanner({required this.assessment});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final best = assessment.bestAttempt;
    final inProgress = assessment.myAttempts.any(
      (a) => a.status == 'IN_PROGRESS',
    );

    if (inProgress) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.orange.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            const Icon(
              Icons.play_circle_outline_rounded,
              size: 16,
              color: Colors.orange,
            ),
            const SizedBox(width: 6),
            Text(
              'In Progress — tap to continue',
              style: theme.textTheme.labelSmall?.copyWith(color: Colors.orange),
            ),
          ],
        ),
      );
    }

    if (best != null) {
      final passed =
          assessment.passingMarks != null &&
          (best.percentage ?? 0) >=
              (assessment.passingMarks! / assessment.totalMarks * 100);
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: (passed ? Colors.green : Colors.blue).withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Icon(
              passed
                  ? Icons.check_circle_outline_rounded
                  : Icons.info_outline_rounded,
              size: 16,
              color: passed ? Colors.green : Colors.blue,
            ),
            const SizedBox(width: 6),
            Text(
              'Score: ${best.percentage?.toStringAsFixed(1)}%',
              style: theme.textTheme.labelSmall?.copyWith(
                color: passed ? Colors.green : Colors.blue,
                fontWeight: FontWeight.w600,
              ),
            ),
            if (assessment.canAttempt) ...[
              const Spacer(),
              Text(
                'Retry available',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.primary,
                ),
              ),
            ],
          ],
        ),
      );
    }

    return const SizedBox.shrink();
  }
}

class _SubmissionBanner extends StatelessWidget {
  final SubmissionSummary submission;
  const _SubmissionBanner({required this.submission});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final s = submission;
    final color = switch (s.status) {
      'GRADED' => Colors.green,
      'RETURNED' => Colors.orange,
      _ => Colors.blue,
    };
    final label = switch (s.status) {
      'GRADED' => 'Graded${s.marks != null ? ' — ${s.marks} marks' : ''}',
      'RETURNED' => 'Returned for revision',
      _ => 'Submitted${s.isLate ? ' (late)' : ''}',
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(
            s.status == 'GRADED'
                ? Icons.check_circle_outline_rounded
                : Icons.upload_file_rounded,
            size: 16,
            color: color,
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool showAction;
  final String? actionLabel;
  final VoidCallback? onAction;

  const _EmptyState({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.showAction = false,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 56, color: theme.colorScheme.outlineVariant),
          const SizedBox(height: 12),
          Text(
            title,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
          if (showAction && actionLabel != null) ...[
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: onAction,
              icon: const Icon(Icons.add_rounded, size: 18),
              label: Text(actionLabel!),
            ),
          ],
        ],
      ),
    );
  }
}

class _ShimmerList extends StatelessWidget {
  const _ShimmerList();

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      itemCount: 4,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (_, _) => const ShimmerWrap(
        child: SizedBox(height: 100, width: double.infinity),
      ),
    );
  }
}
