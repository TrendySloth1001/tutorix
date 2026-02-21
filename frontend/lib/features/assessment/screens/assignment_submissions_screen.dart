import 'package:flutter/material.dart';
import '../../../core/theme/design_tokens.dart';
import '../models/assignment_model.dart';
import '../services/assessment_service.dart';
import 'file_viewer_screen.dart';

/// Screen for teachers to view all submissions for an assignment and grade them.
class AssignmentSubmissionsScreen extends StatefulWidget {
  final String coachingId;
  final String batchId;
  final AssignmentModel assignment;

  const AssignmentSubmissionsScreen({
    super.key,
    required this.coachingId,
    required this.batchId,
    required this.assignment,
  });

  @override
  State<AssignmentSubmissionsScreen> createState() =>
      _AssignmentSubmissionsScreenState();
}

class _AssignmentSubmissionsScreenState
    extends State<AssignmentSubmissionsScreen> {
  final AssessmentService _service = AssessmentService();
  List<SubmissionModel>? _submissions;
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
      _submissions = await _service.getSubmissions(
        widget.coachingId,
        widget.batchId,
        widget.assignment.id,
      );
    } catch (e) {
      _error = e.toString();
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _gradeSubmission(SubmissionModel sub) async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) => _GradeDialog(
        submission: sub,
        totalMarks: widget.assignment.totalMarks?.toDouble(),
      ),
    );
    if (result == null) return;

    try {
      await _service.gradeSubmission(
        widget.coachingId,
        widget.batchId,
        sub.id,
        marks: result['marks'] as int,
        feedback: result['feedback'] as String?,
      );
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Graded successfully')));
        _load();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.assignment.title),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(36),
          child: Padding(
            padding: const EdgeInsets.only(
              left: Spacing.sp16,
              right: Spacing.sp16,
              bottom: Spacing.sp8,
            ),
            child: Row(
              children: [
                Text(
                  '${_submissions?.length ?? 0} submissions',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const Spacer(),
                if (_submissions != null)
                  Text(
                    '${_submissions!.where((s) => s.status == 'GRADED').length} graded',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.primary,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
      body: _buildBody(theme),
    );
  }

  Widget _buildBody(ThemeData theme) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Failed to load', style: theme.textTheme.bodyMedium),
            const SizedBox(height: Spacing.sp8),
            TextButton(onPressed: _load, child: const Text('Retry')),
          ],
        ),
      );
    }
    if (_submissions == null || _submissions!.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.inbox_outlined,
              size: 48,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: Spacing.sp8),
            Text(
              'No submissions yet',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.separated(
        padding: const EdgeInsets.all(Spacing.sp16),
        itemCount: _submissions!.length,
        separatorBuilder: (_, _) => const SizedBox(height: Spacing.sp10),
        itemBuilder: (_, i) => _SubmissionCard(
          submission: _submissions![i],
          onGrade: () => _gradeSubmission(_submissions![i]),
        ),
      ),
    );
  }
}

class _SubmissionCard extends StatelessWidget {
  final SubmissionModel submission;
  final VoidCallback onGrade;

  const _SubmissionCard({required this.submission, required this.onGrade});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final s = submission;
    final statusColor = switch (s.status) {
      'GRADED' => theme.colorScheme.primary,
      'RETURNED' => theme.colorScheme.secondary,
      _ => theme.colorScheme.secondary,
    };

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(Radii.md),
        side: BorderSide(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(Spacing.sp14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header: student name + status
            Row(
              children: [
                CircleAvatar(
                  radius: 16,
                  backgroundColor: theme.colorScheme.primaryContainer,
                  child: Text(
                    (s.user?.name ?? '?')[0].toUpperCase(),
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: theme.colorScheme.onPrimaryContainer,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(width: Spacing.sp10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        s.user?.name ?? 'Unknown',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (s.submittedAt != null)
                        Text(
                          '${s.submittedAt!.day}/${s.submittedAt!.month}/${s.submittedAt!.year}',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: Spacing.sp8,
                    vertical: Spacing.sp4,
                  ),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(Radii.sm),
                  ),
                  child: Text(
                    s.status,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: statusColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),

            // Late badge
            if (s.isLate) ...[
              const SizedBox(height: Spacing.sp6),
              Row(
                children: [
                  Icon(
                    Icons.warning_amber_rounded,
                    size: 14,
                    color: theme.colorScheme.secondary,
                  ),
                  const SizedBox(width: Spacing.sp4),
                  Text(
                    'Submitted late',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.secondary,
                    ),
                  ),
                ],
              ),
            ],

            // Files
            if (s.files.isNotEmpty) ...[
              const SizedBox(height: Spacing.sp8),
              Wrap(
                spacing: 6,
                runSpacing: 4,
                children: s.files.map((f) {
                  final isPDF = f.fileName.toLowerCase().endsWith('.pdf');
                  return InkWell(
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => FileViewerScreen(
                            url: f.url,
                            fileName: f.fileName,
                            isPDF: isPDF,
                          ),
                        ),
                      );
                    },
                    child: Chip(
                      avatar: Icon(
                        isPDF
                            ? Icons.picture_as_pdf_outlined
                            : Icons.image_outlined,
                        size: 14,
                      ),
                      label: Text(
                        f.fileName,
                        style: theme.textTheme.labelSmall,
                      ),
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      visualDensity: VisualDensity.compact,
                    ),
                  );
                }).toList(),
              ),
            ],

            // Marks & feedback
            if (s.marks != null) ...[
              const SizedBox(height: Spacing.sp8),
              Text(
                'Marks: ${s.marks}',
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: theme.colorScheme.primary,
                ),
              ),
            ],
            if (s.feedback != null && s.feedback!.isNotEmpty) ...[
              const SizedBox(height: Spacing.sp4),
              Text('Feedback: ${s.feedback}', style: theme.textTheme.bodySmall),
            ],

            // Grade button
            const SizedBox(height: Spacing.sp10),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: onGrade,
                icon: Icon(
                  s.status == 'GRADED'
                      ? Icons.edit_outlined
                      : Icons.grading_rounded,
                  size: 16,
                ),
                label: Text(s.status == 'GRADED' ? 'Update Grade' : 'Grade'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GradeDialog extends StatefulWidget {
  final SubmissionModel submission;
  final double? totalMarks;

  const _GradeDialog({required this.submission, this.totalMarks});

  @override
  State<_GradeDialog> createState() => _GradeDialogState();
}

class _GradeDialogState extends State<_GradeDialog> {
  late final TextEditingController _marksCtl;
  late final TextEditingController _feedbackCtl;

  @override
  void initState() {
    super.initState();
    _marksCtl = TextEditingController(
      text: widget.submission.marks?.toString() ?? '',
    );
    _feedbackCtl = TextEditingController(
      text: widget.submission.feedback ?? '',
    );
  }

  @override
  void dispose() {
    _marksCtl.dispose();
    _feedbackCtl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Grade – ${widget.submission.user?.name ?? 'Student'}'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _marksCtl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              labelText: 'Marks',
              hintText: widget.totalMarks != null
                  ? 'Out of ${widget.totalMarks}'
                  : null,
            ),
          ),
          const SizedBox(height: Spacing.sp12),
          TextField(
            controller: _feedbackCtl,
            maxLines: 3,
            decoration: const InputDecoration(labelText: 'Feedback (optional)'),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () {
            final marks = int.tryParse(_marksCtl.text.trim());
            if (marks == null) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Enter valid marks')),
              );
              return;
            }
            Navigator.pop(context, {
              'marks': marks,
              'feedback': _feedbackCtl.text.trim().isEmpty
                  ? null
                  : _feedbackCtl.text.trim(),
            });
          },
          child: const Text('Save'),
        ),
      ],
    );
  }
}
