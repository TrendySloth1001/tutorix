import 'package:flutter/material.dart';
import '../../../core/theme/design_tokens.dart';
import '../models/assessment_model.dart';
import '../services/assessment_service.dart';

/// Displays assessment results.
/// - Student: shows their score, question-wise breakdown with correct answers.
/// - Teacher: shows leaderboard of all student attempts.
class AssessmentResultScreen extends StatefulWidget {
  final String coachingId;
  final String batchId;
  final AssessmentModel assessment;
  final bool isTeacher;
  final String? attemptId;

  const AssessmentResultScreen({
    super.key,
    required this.coachingId,
    required this.batchId,
    required this.assessment,
    required this.isTeacher,
    this.attemptId,
  });

  @override
  State<AssessmentResultScreen> createState() => _AssessmentResultScreenState();
}

class _AssessmentResultScreenState extends State<AssessmentResultScreen> {
  final AssessmentService _service = AssessmentService();
  bool _loading = true;

  // Student view
  AttemptResultModel? _result;

  // Teacher view
  List<AttemptLeaderboardEntry> _attempts = [];
  AssessmentModel? _detail;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      if (widget.isTeacher) {
        final results = await Future.wait([
          _service.getAssessmentAttempts(
            widget.coachingId,
            widget.batchId,
            widget.assessment.id,
          ),
          _service.getAssessment(
            widget.coachingId,
            widget.batchId,
            widget.assessment.id,
          ),
        ]);
        _attempts = results[0] as List<AttemptLeaderboardEntry>;
        _detail = results[1] as AssessmentModel;
      } else {
        final attemptId = widget.attemptId ?? widget.assessment.bestAttempt?.id;
        if (attemptId != null) {
          _result = await _service.getAttemptResult(
            widget.coachingId,
            widget.batchId,
            attemptId,
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error loading results: $e')));
      }
    }
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.assessment.title)),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : widget.isTeacher
          ? _buildTeacherView()
          : _buildStudentView(),
    );
  }

  // ── Student Result View ──

  Widget _buildStudentView() {
    final theme = Theme.of(context);

    if (_result == null) {
      return const Center(child: Text('No result available'));
    }

    final r = _result!;
    final passed =
        widget.assessment.passingMarks != null &&
        r.totalScore >= widget.assessment.passingMarks!;

    return ListView(
      padding: const EdgeInsets.all(Spacing.sp16),
      children: [
        // Simplified Score Section
        const SizedBox(height: Spacing.sp24),
        Center(
          child: Column(
            children: [
              Text(
                'YOUR SCORE',
                style: theme.textTheme.labelMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  letterSpacing: 1.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: Spacing.sp12),
              Text(
                '${r.percentage.toStringAsFixed(1)}%',
                style: theme.textTheme.displayLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: passed
                      ? theme.colorScheme.primary
                      : theme.colorScheme.onSurface,
                  height: 1.0,
                  letterSpacing: -1.0,
                ),
              ),
              const SizedBox(height: Spacing.sp8),
              if (widget.assessment.passingMarks != null)
                Container(
                  margin: const EdgeInsets.only(bottom: Spacing.sp12),
                  padding: const EdgeInsets.symmetric(
                    horizontal: Spacing.sp16,
                    vertical: Spacing.sp6,
                  ),
                  decoration: BoxDecoration(
                    color:
                        (passed
                                ? theme.colorScheme.primary
                                : theme.colorScheme.error)
                            .withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(Radii.full),
                  ),
                  child: Text(
                    passed ? 'PASSED' : 'FAILED',
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: passed
                          ? theme.colorScheme.primary
                          : theme.colorScheme.error,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.0,
                    ),
                  ),
                ),
              Text(
                '${r.totalScore.toStringAsFixed(1)} / ${r.maxScore.toStringAsFixed(1)} Marks',
                style: theme.textTheme.titleMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: Spacing.sp48),

        // Simplified Stats Row
        Container(
          padding: const EdgeInsets.symmetric(
            vertical: Spacing.sp24,
            horizontal: Spacing.sp16,
          ),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerLowest,
            borderRadius: BorderRadius.circular(Radii.lg),
            border: Border.all(
              color: theme.colorScheme.outlineVariant.withValues(alpha: 0.4),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildStatItem(
                theme,
                'Correct',
                '${r.correctCount}',
                theme.colorScheme.primary,
              ),
              Container(
                width: 1,
                height: 40,
                color: theme.colorScheme.outlineVariant.withValues(alpha: 0.3),
              ),
              _buildStatItem(
                theme,
                'Wrong',
                '${r.wrongCount}',
                theme.colorScheme.error,
              ),
              Container(
                width: 1,
                height: 40,
                color: theme.colorScheme.outlineVariant.withValues(alpha: 0.3),
              ),
              _buildStatItem(
                theme,
                'Skipped',
                '${r.skippedCount}',
                Colors.grey,
              ),
            ],
          ),
        ),

        const SizedBox(height: Spacing.sp20),

        // Question breakdown
        if (r.assessment != null &&
            r.assessment!.showResultAfter == 'SUBMIT') ...[
          Text(
            'Question Breakdown',
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: Spacing.sp10),
          ...List.generate(r.assessment!.questions.length, (i) {
            final q = r.assessment!.questions[i];
            final ans = r.answers.where((a) => a.questionId == q.id);
            final studentAnswer = ans.isNotEmpty ? ans.first : null;

            return _QuestionResult(
              index: i,
              question: q,
              answer: studentAnswer,
            );
          }),
        ] else
          Center(
            child: Padding(
              padding: const EdgeInsets.all(Spacing.sp32),
              child: Text(
                'Detailed results will be available after the teacher releases them.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
      ],
    );
  }

  void _viewStudentResult(AttemptLeaderboardEntry entry) async {
    try {
      final result = await _service.getAttemptResult(
        widget.coachingId,
        widget.batchId,
        entry.id,
      );
      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => _StudentResponseSheet(
            studentName: entry.user?.name ?? 'Unknown',
            result: result,
            assessment: widget.assessment,
          ),
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error loading response: $e')));
      }
    }
  }

  // ── Teacher Leaderboard View ──

  Widget _buildTeacherView() {
    final theme = Theme.of(context);

    return Column(
      children: [
        // Assessment info header
        Container(
          padding: const EdgeInsets.all(Spacing.sp16),
          color: theme.colorScheme.surfaceContainerHighest.withValues(
            alpha: 0.3,
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${_detail?.questionCount ?? widget.assessment.questionCount} Questions • ${_detail?.totalMarks ?? widget.assessment.totalMarks} Marks',
                      style: theme.textTheme.bodySmall,
                    ),
                    const SizedBox(height: Spacing.sp2),
                    Text(
                      '${_attempts.length} submissions',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              if (widget.assessment.isPublished)
                TextButton(
                  onPressed: () async {
                    await _service.updateAssessmentStatus(
                      widget.coachingId,
                      widget.batchId,
                      widget.assessment.id,
                      'CLOSED',
                    );
                    if (mounted) _load();
                  },
                  child: const Text('Close'),
                ),
            ],
          ),
        ),

        // Leaderboard
        Expanded(
          child: _attempts.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.leaderboard_outlined,
                        size: 56,
                        color: theme.colorScheme.outlineVariant,
                      ),
                      const SizedBox(height: Spacing.sp8),
                      Text(
                        'No submissions yet',
                        style: theme.textTheme.bodyMedium,
                      ),
                    ],
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.all(Spacing.sp16),
                  itemCount: _attempts.length,
                  separatorBuilder: (_, _) =>
                      const SizedBox(height: Spacing.sp8),
                  itemBuilder: (_, i) => _LeaderboardTile(
                    rank: i + 1,
                    entry: _attempts[i],
                    onTap: () => _viewStudentResult(_attempts[i]),
                  ),
                ),
        ),
      ],
    );
  }
}

// ─── Helper Widgets ──────────────────────────────────────────────────

Widget _buildStatItem(
  ThemeData theme,
  String label,
  String value,
  Color color,
) {
  return Column(
    children: [
      Text(
        value,
        style: theme.textTheme.headlineMedium?.copyWith(
          fontWeight: FontWeight.w700,
          color: color,
          height: 1.0,
        ),
      ),
      const SizedBox(height: Spacing.sp4),
      Text(
        label,
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
          fontWeight: FontWeight.w600,
        ),
      ),
    ],
  );
}

class _StatBox extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _StatBox({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: Spacing.sp12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(Radii.md),
        ),
        child: Column(
          children: [
            Text(
              value,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
            const SizedBox(height: Spacing.sp2),
            Text(
              label,
              style: theme.textTheme.labelSmall?.copyWith(
                color: color.withValues(alpha: 0.8),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _QuestionResult extends StatelessWidget {
  final int index;
  final QuestionModel question;
  final AnswerModel? answer;

  const _QuestionResult({
    required this.index,
    required this.question,
    this.answer,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isCorrect = answer?.isCorrect ?? false;
    final isSkipped = answer == null;

    return Container(
      margin: const EdgeInsets.only(bottom: Spacing.sp12),
      padding: const EdgeInsets.all(Spacing.sp12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(Radii.md),
        border: Border.all(
          color: isSkipped
              ? Colors.grey.withValues(alpha: 0.3)
              : isCorrect
              ? theme.colorScheme.primary.withValues(alpha: 0.4)
              : theme.colorScheme.error.withValues(alpha: 0.4),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: Spacing.sp8,
                  vertical: Spacing.sp4,
                ),
                decoration: BoxDecoration(
                  color:
                      (isSkipped
                              ? Colors.grey
                              : isCorrect
                              ? theme.colorScheme.primary
                              : theme.colorScheme.error)
                          .withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(Radii.sm),
                ),
                child: Text(
                  'Q${index + 1}',
                  style: theme.textTheme.labelSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: isSkipped
                        ? Colors.grey
                        : isCorrect
                        ? theme.colorScheme.primary
                        : theme.colorScheme.error,
                  ),
                ),
              ),
              const SizedBox(width: Spacing.sp8),
              Expanded(
                child: Text(
                  question.question,
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Text(
                '${answer?.marksAwarded.toStringAsFixed(1) ?? '0'} / ${question.marks}',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: isCorrect
                      ? theme.colorScheme.primary
                      : theme.colorScheme.error,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),

          // Show NAT answer
          if (question.isNAT) ...[
            const SizedBox(height: Spacing.sp8),
            _buildNATAnswer(theme),
          ],

          // Show correct answer for MCQ/MSQ
          if (question.isMCQ || question.isMSQ) ...[
            const SizedBox(height: Spacing.sp8),
            ...question.options.map((opt) {
              final isCorrectOpt = _isCorrectOption(opt.id);
              final isStudentOpt = _isStudentOption(opt.id);
              return Padding(
                padding: const EdgeInsets.only(bottom: Spacing.sp4),
                child: Row(
                  children: [
                    Icon(
                      isCorrectOpt
                          ? Icons.check_circle_rounded
                          : isStudentOpt
                          ? Icons.cancel_rounded
                          : Icons.circle_outlined,
                      size: 16,
                      color: isCorrectOpt
                          ? theme.colorScheme.primary
                          : isStudentOpt
                          ? theme.colorScheme.error
                          : theme.colorScheme.outlineVariant,
                    ),
                    const SizedBox(width: Spacing.sp6),
                    Expanded(
                      child: Text(
                        opt.text,
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontWeight: isCorrectOpt
                              ? FontWeight.w600
                              : FontWeight.normal,
                          color: isCorrectOpt
                              ? theme.colorScheme.primary
                              : null,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],

          if (question.explanation != null &&
              question.explanation!.isNotEmpty) ...[
            const SizedBox(height: Spacing.sp8),
            Container(
              padding: const EdgeInsets.all(Spacing.sp8),
              decoration: BoxDecoration(
                color: theme.colorScheme.secondary.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(Radii.sm),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.lightbulb_outline_rounded,
                    size: 14,
                    color: theme.colorScheme.secondary,
                  ),
                  const SizedBox(width: Spacing.sp6),
                  Expanded(
                    child: Text(
                      question.explanation!,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.secondary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildNATAnswer(ThemeData theme) {
    final correct = question.correctAnswer;
    final studentAns = answer?.answer;

    String correctText = '';
    String studentText = 'Skipped';
    String toleranceText = '';

    if (correct is Map) {
      correctText = '${correct['value']}';
      if (correct['tolerance'] != null && (correct['tolerance'] as num) > 0) {
        toleranceText = ' (±${correct['tolerance']})';
      }
    } else {
      correctText = '$correct';
    }

    if (studentAns != null) {
      if (studentAns is Map) {
        studentText = '${studentAns['value']}';
      } else if (studentAns is num) {
        studentText = '$studentAns';
      } else {
        studentText = '$studentAns';
      }
    }

    final isCorrect = answer?.isCorrect ?? false;
    final isSkipped = answer == null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Student's answer
        Row(
          children: [
            Icon(
              isSkipped
                  ? Icons.remove_circle_outline
                  : isCorrect
                  ? Icons.check_circle_rounded
                  : Icons.cancel_rounded,
              size: 16,
              color: isSkipped
                  ? Colors.grey
                  : isCorrect
                  ? theme.colorScheme.primary
                  : theme.colorScheme.error,
            ),
            const SizedBox(width: Spacing.sp6),
            Text(
              'Your answer: ',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            Text(
              studentText,
              style: theme.textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.w600,
                color: isSkipped
                    ? Colors.grey
                    : isCorrect
                    ? theme.colorScheme.primary
                    : theme.colorScheme.error,
              ),
            ),
          ],
        ),
        const SizedBox(height: Spacing.sp4),
        // Correct answer
        Row(
          children: [
            Icon(
              Icons.check_circle_rounded,
              size: 16,
              color: theme.colorScheme.primary,
            ),
            const SizedBox(width: Spacing.sp6),
            Text(
              'Correct answer: ',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            Text(
              '$correctText$toleranceText',
              style: theme.textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.w600,
                color: theme.colorScheme.primary,
              ),
            ),
          ],
        ),
      ],
    );
  }

  bool _isCorrectOption(String optId) {
    final correct = question.correctAnswer;
    if (correct is String) return correct == optId;
    if (correct is List) return correct.contains(optId);
    return false;
  }

  bool _isStudentOption(String optId) {
    if (answer == null) return false;
    final sa = answer!.answer;
    if (sa is String) return sa == optId;
    if (sa is List) return sa.contains(optId);
    return false;
  }
}

class _LeaderboardTile extends StatelessWidget {
  final int rank;
  final AttemptLeaderboardEntry entry;
  final VoidCallback? onTap;

  const _LeaderboardTile({required this.rank, required this.entry, this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final medalColor = switch (rank) {
      1 => Colors.amber,
      2 => Colors.grey.shade400,
      3 => Colors.brown.shade300,
      _ => null,
    };

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(Radii.md),
      child: Container(
        padding: const EdgeInsets.all(Spacing.sp12),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(Radii.md),
          border: Border.all(
            color: theme.colorScheme.outlineVariant.withValues(alpha: 0.4),
          ),
        ),
        child: Row(
          children: [
            // Rank
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color:
                    medalColor?.withValues(alpha: 0.15) ??
                    theme.colorScheme.surfaceContainerHighest,
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: Text(
                '#$rank',
                style: theme.textTheme.labelSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: medalColor ?? theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            const SizedBox(width: Spacing.sp10),

            // Avatar
            CircleAvatar(
              radius: 16,
              backgroundImage: entry.user?.picture != null
                  ? NetworkImage(entry.user!.picture!)
                  : null,
              child: entry.user?.picture == null
                  ? Text(
                      entry.user?.name?.substring(0, 1).toUpperCase() ?? '?',
                      style: theme.textTheme.labelSmall,
                    )
                  : null,
            ),
            const SizedBox(width: Spacing.sp10),

            // Name
            Expanded(
              child: Text(
                entry.user?.name ?? 'Unknown',
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w500,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),

            // Score + chevron
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '${entry.percentage.toStringAsFixed(1)}%',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: theme.colorScheme.primary,
                  ),
                ),
                Text(
                  '${entry.totalScore.toStringAsFixed(1)} / ${entry.maxScore.toStringAsFixed(1)}',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
            const SizedBox(width: Spacing.sp4),
            Icon(
              Icons.chevron_right_rounded,
              size: 20,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Student Response Sheet (Teacher viewing a student's answers) ───

class _StudentResponseSheet extends StatelessWidget {
  final String studentName;
  final AttemptResultModel result;
  final AssessmentModel assessment;

  const _StudentResponseSheet({
    required this.studentName,
    required this.result,
    required this.assessment,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final r = result;
    final passed =
        assessment.passingMarks != null &&
        r.totalScore >= assessment.passingMarks!;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          studentName,
          style: const TextStyle(fontSize: FontSize.sub),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(Spacing.sp16),
        children: [
          // Score summary card
          Container(
            padding: const EdgeInsets.all(Spacing.sp16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: passed
                    ? [
                        theme.colorScheme.primary.withValues(alpha: 0.08),
                        theme.colorScheme.primary.withValues(alpha: 0.08),
                      ]
                    : [
                        theme.colorScheme.secondary.withValues(alpha: 0.08),
                        theme.colorScheme.secondary.withValues(alpha: 0.08),
                      ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(Radii.md),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${r.percentage.toStringAsFixed(1)}%',
                        style: theme.textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: passed
                              ? theme.colorScheme.primary
                              : theme.colorScheme.secondary,
                        ),
                      ),
                      Text(
                        '${r.totalScore.toStringAsFixed(1)} / ${r.maxScore.toStringAsFixed(1)} marks',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: passed
                              ? theme.colorScheme.primary
                              : theme.colorScheme.secondary,
                        ),
                      ),
                    ],
                  ),
                ),
                if (assessment.passingMarks != null)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: Spacing.sp10,
                      vertical: Spacing.sp4,
                    ),
                    decoration: BoxDecoration(
                      color:
                          (passed
                                  ? theme.colorScheme.primary
                                  : theme.colorScheme.error)
                              .withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(Radii.sm),
                    ),
                    child: Text(
                      passed ? 'PASSED' : 'FAILED',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: passed
                            ? theme.colorScheme.primary
                            : theme.colorScheme.error,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
              ],
            ),
          ),

          const SizedBox(height: Spacing.sp12),

          // Stats row
          Row(
            children: [
              _StatBox(
                label: 'Correct',
                value: '${r.correctCount}',
                color: theme.colorScheme.primary,
              ),
              const SizedBox(width: Spacing.sp8),
              _StatBox(
                label: 'Wrong',
                value: '${r.wrongCount}',
                color: theme.colorScheme.error,
              ),
              const SizedBox(width: Spacing.sp8),
              _StatBox(
                label: 'Skipped',
                value: '${r.skippedCount}',
                color: Colors.grey,
              ),
            ],
          ),

          const SizedBox(height: Spacing.sp20),

          // Question-by-question breakdown
          Text(
            'Response Sheet',
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: Spacing.sp10),
          if (r.assessment != null)
            ...List.generate(r.assessment!.questions.length, (i) {
              final q = r.assessment!.questions[i];
              final ans = r.answers.where((a) => a.questionId == q.id);
              final studentAnswer = ans.isNotEmpty ? ans.first : null;
              return _QuestionResult(
                index: i,
                question: q,
                answer: studentAnswer,
              );
            }),
        ],
      ),
    );
  }
}
