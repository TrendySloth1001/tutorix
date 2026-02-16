import 'package:flutter/material.dart';
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
      padding: const EdgeInsets.all(16),
      children: [
        // Score card
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: passed
                  ? [Colors.green.shade50, Colors.green.shade100]
                  : [Colors.blue.shade50, Colors.blue.shade100],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            children: [
              Text(
                '${r.percentage.toStringAsFixed(1)}%',
                style: theme.textTheme.displaySmall?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: passed ? Colors.green.shade700 : Colors.blue.shade700,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '${r.totalScore.toStringAsFixed(1)} / ${r.maxScore.toStringAsFixed(1)}',
                style: theme.textTheme.titleMedium?.copyWith(
                  color: passed ? Colors.green.shade600 : Colors.blue.shade600,
                ),
              ),
              if (widget.assessment.passingMarks != null) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: (passed ? Colors.green : Colors.red).withValues(
                      alpha: 0.15,
                    ),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    passed ? 'PASSED' : 'FAILED',
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: passed ? Colors.green.shade700 : Colors.red,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),

        const SizedBox(height: 16),

        // Stats row
        Row(
          children: [
            _StatBox(
              label: 'Correct',
              value: '${r.correctCount}',
              color: Colors.green,
            ),
            const SizedBox(width: 8),
            _StatBox(
              label: 'Wrong',
              value: '${r.wrongCount}',
              color: Colors.red,
            ),
            const SizedBox(width: 8),
            _StatBox(
              label: 'Skipped',
              value: '${r.skippedCount}',
              color: Colors.grey,
            ),
          ],
        ),

        const SizedBox(height: 20),

        // Question breakdown
        if (r.assessment != null &&
            r.assessment!.showResultAfter == 'SUBMIT') ...[
          Text(
            'Question Breakdown',
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 10),
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
              padding: const EdgeInsets.all(32),
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

  // ── Teacher Leaderboard View ──

  Widget _buildTeacherView() {
    final theme = Theme.of(context);

    return Column(
      children: [
        // Assessment info header
        Container(
          padding: const EdgeInsets.all(16),
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
                    const SizedBox(height: 2),
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
                      const SizedBox(height: 8),
                      Text(
                        'No submissions yet',
                        style: theme.textTheme.bodyMedium,
                      ),
                    ],
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: _attempts.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (_, i) =>
                      _LeaderboardTile(rank: i + 1, entry: _attempts[i]),
                ),
        ),
      ],
    );
  }
}

// ─── Helper Widgets ──────────────────────────────────────────────────

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
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(10),
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
            const SizedBox(height: 2),
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
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isSkipped
              ? Colors.grey.withValues(alpha: 0.3)
              : isCorrect
              ? Colors.green.withValues(alpha: 0.4)
              : Colors.red.withValues(alpha: 0.4),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                  color:
                      (isSkipped
                              ? Colors.grey
                              : isCorrect
                              ? Colors.green
                              : Colors.red)
                          .withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  'Q${index + 1}',
                  style: theme.textTheme.labelSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: isSkipped
                        ? Colors.grey
                        : isCorrect
                        ? Colors.green
                        : Colors.red,
                  ),
                ),
              ),
              const SizedBox(width: 8),
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
                  color: isCorrect ? Colors.green : Colors.red,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),

          // Show correct answer for MCQ/MSQ
          if (question.isMCQ || question.isMSQ) ...[
            const SizedBox(height: 8),
            ...question.options.map((opt) {
              final isCorrectOpt = _isCorrectOption(opt.id);
              final isStudentOpt = _isStudentOption(opt.id);
              return Padding(
                padding: const EdgeInsets.only(bottom: 4),
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
                          ? Colors.green
                          : isStudentOpt
                          ? Colors.red
                          : theme.colorScheme.outlineVariant,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        opt.text,
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontWeight: isCorrectOpt
                              ? FontWeight.w600
                              : FontWeight.normal,
                          color: isCorrectOpt ? Colors.green.shade700 : null,
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
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.blue.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.lightbulb_outline_rounded,
                    size: 14,
                    color: Colors.blue,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      question.explanation!,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: Colors.blue.shade700,
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

  const _LeaderboardTile({required this.rank, required this.entry});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final medalColor = switch (rank) {
      1 => Colors.amber,
      2 => Colors.grey.shade400,
      3 => Colors.brown.shade300,
      _ => null,
    };

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
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
          const SizedBox(width: 10),

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
          const SizedBox(width: 10),

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

          // Score
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
        ],
      ),
    );
  }
}
