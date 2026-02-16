import 'dart:async';
import 'package:flutter/material.dart';
import '../models/assessment_model.dart';
import '../services/assessment_service.dart';
import 'assessment_result_screen.dart';

/// Screen for students to take an assessment.
/// Features: question navigation, auto-save, timer, submit.
class TakeAssessmentScreen extends StatefulWidget {
  final String coachingId;
  final String batchId;
  final AssessmentModel assessment;

  const TakeAssessmentScreen({
    super.key,
    required this.coachingId,
    required this.batchId,
    required this.assessment,
  });

  @override
  State<TakeAssessmentScreen> createState() => _TakeAssessmentScreenState();
}

class _TakeAssessmentScreenState extends State<TakeAssessmentScreen> {
  final AssessmentService _service = AssessmentService();

  bool _loading = true;
  String? _attemptId;
  List<QuestionModel> _questions = [];
  int _currentIndex = 0;

  // Answers: questionId → answer value
  final Map<String, dynamic> _answers = {};
  final Set<String> _markedForReview = {};

  // Timer
  Timer? _timer;
  int _remainingSeconds = 0;

  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _start();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _start() async {
    try {
      // Start or resume attempt
      final result = await _service.startAttempt(
        widget.coachingId,
        widget.batchId,
        widget.assessment.id,
      );
      _attemptId = result['attemptId'] as String;

      // Load questions (without correct answers)
      final detail = await _service.getAssessment(
        widget.coachingId,
        widget.batchId,
        widget.assessment.id,
        role: 'STUDENT',
      );
      _questions = detail.questions;

      // Load saved answers if resuming
      if (result['resumed'] == true) {
        final saved = await _service.getAttemptAnswers(
          widget.coachingId,
          widget.batchId,
          _attemptId!,
        );
        for (final a in saved) {
          _answers[a['questionId'] as String] = a['answer'];
        }
      }

      // Start timer if applicable
      if (widget.assessment.hasTimeLimit) {
        _remainingSeconds = widget.assessment.durationMinutes! * 60;
        _startTimer();
      }

      setState(() => _loading = false);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
        Navigator.pop(context);
      }
    }
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_remainingSeconds <= 0) {
        _timer?.cancel();
        _submitAttempt(timedOut: true);
        return;
      }
      setState(() => _remainingSeconds--);
    });
  }

  String get _timerText {
    final h = _remainingSeconds ~/ 3600;
    final m = (_remainingSeconds % 3600) ~/ 60;
    final s = _remainingSeconds % 60;
    if (h > 0) {
      return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
    }
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  // ── Answer handling ──

  void _selectAnswer(String questionId, dynamic value) {
    setState(() => _answers[questionId] = value);
    _autoSave(questionId, value);
  }

  void _toggleMSQOption(String questionId, String optionId) {
    final current = List<String>.from(
      (_answers[questionId] as List<dynamic>?) ?? [],
    );
    if (current.contains(optionId)) {
      current.remove(optionId);
    } else {
      current.add(optionId);
    }
    setState(() => _answers[questionId] = current);
    _autoSave(questionId, current);
  }

  Future<void> _autoSave(String questionId, dynamic value) async {
    if (_attemptId == null) return;
    try {
      await _service.saveAnswer(
        widget.coachingId,
        widget.batchId,
        _attemptId!,
        questionId: questionId,
        answer: value,
      );
    } catch (_) {
      // Silent fail — will be saved on next interaction
    }
  }

  void _clearAnswer(String questionId) {
    setState(() => _answers.remove(questionId));
  }

  void _toggleReview(String questionId) {
    setState(() {
      if (_markedForReview.contains(questionId)) {
        _markedForReview.remove(questionId);
      } else {
        _markedForReview.add(questionId);
      }
    });
  }

  // ── Navigation ──

  void _goToQuestion(int index) {
    setState(() => _currentIndex = index);
  }

  void _next() {
    if (_currentIndex < _questions.length - 1) {
      setState(() => _currentIndex++);
    }
  }

  void _previous() {
    if (_currentIndex > 0) {
      setState(() => _currentIndex--);
    }
  }

  // ── Submit ──

  Future<void> _submitAttempt({bool timedOut = false}) async {
    if (_attemptId == null) return;

    if (!timedOut) {
      final unanswered = _questions
          .where((q) => !_answers.containsKey(q.id))
          .length;
      final confirm = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Submit Assessment'),
          content: Text(
            unanswered > 0
                ? 'You have $unanswered unanswered questions. Submit anyway?'
                : 'Are you sure you want to submit?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Submit'),
            ),
          ],
        ),
      );
      if (confirm != true) return;
    }

    setState(() => _submitting = true);
    _timer?.cancel();

    try {
      await _service.submitAttempt(
        widget.coachingId,
        widget.batchId,
        _attemptId!,
      );

      if (!mounted) return;

      // Navigate to result screen
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => AssessmentResultScreen(
            coachingId: widget.coachingId,
            batchId: widget.batchId,
            assessment: widget.assessment,
            isTeacher: false,
            attemptId: _attemptId,
          ),
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
        setState(() => _submitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        appBar: AppBar(title: Text(widget.assessment.title)),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_questions.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: Text(widget.assessment.title)),
        body: const Center(child: Text('No questions found')),
      );
    }

    final theme = Theme.of(context);
    final question = _questions[_currentIndex];

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final exit = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Leave Assessment?'),
            content: const Text(
              'Your progress is saved. You can resume later if time permits.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Stay'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Leave'),
              ),
            ],
          ),
        );
        if (exit == true && context.mounted) Navigator.pop(context);
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            widget.assessment.title,
            style: theme.textTheme.titleMedium,
          ),
          centerTitle: true,
          actions: [
            if (widget.assessment.hasTimeLimit)
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: _remainingSeconds < 300
                          ? Colors.red.withValues(alpha: 0.15)
                          : theme.colorScheme.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.timer_outlined,
                          size: 16,
                          color: _remainingSeconds < 300
                              ? Colors.red
                              : theme.colorScheme.primary,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          _timerText,
                          style: theme.textTheme.labelMedium?.copyWith(
                            color: _remainingSeconds < 300
                                ? Colors.red
                                : theme.colorScheme.primary,
                            fontWeight: FontWeight.w700,
                            fontFeatures: [const FontFeature.tabularFigures()],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            TextButton(
              onPressed: _submitting ? null : () => _submitAttempt(),
              child: _submitting
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Submit'),
            ),
          ],
        ),
        body: Column(
          children: [
            // Question navigator
            _QuestionNavigator(
              total: _questions.length,
              current: _currentIndex,
              answers: _answers,
              questions: _questions,
              markedForReview: _markedForReview,
              onSelect: _goToQuestion,
            ),

            // Question content
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: _QuestionWidget(
                  question: question,
                  index: _currentIndex,
                  total: _questions.length,
                  answer: _answers[question.id],
                  isMarked: _markedForReview.contains(question.id),
                  onSelectAnswer: (value) => _selectAnswer(question.id, value),
                  onToggleMSQ: (optId) => _toggleMSQOption(question.id, optId),
                  onClear: () => _clearAnswer(question.id),
                  onToggleReview: () => _toggleReview(question.id),
                  onNATChanged: (value) =>
                      _selectAnswer(question.id, {'value': value}),
                ),
              ),
            ),

            // Bottom navigation
            _BottomNav(
              onPrevious: _currentIndex > 0 ? _previous : null,
              onNext: _currentIndex < _questions.length - 1 ? _next : null,
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Question Navigator (horizontal strip) ──────────────────────────

class _QuestionNavigator extends StatelessWidget {
  final int total;
  final int current;
  final Map<String, dynamic> answers;
  final List<QuestionModel> questions;
  final Set<String> markedForReview;
  final ValueChanged<int> onSelect;

  const _QuestionNavigator({
    required this.total,
    required this.current,
    required this.answers,
    required this.questions,
    required this.markedForReview,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      height: 44,
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
        border: Border(
          bottom: BorderSide(
            color: theme.colorScheme.outlineVariant.withValues(alpha: 0.3),
          ),
        ),
      ),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        itemCount: total,
        itemBuilder: (_, i) {
          final q = questions[i];
          final answered = answers.containsKey(q.id);
          final isCurrent = i == current;
          final isMarked = markedForReview.contains(q.id);

          Color bgColor;
          if (isCurrent) {
            bgColor = theme.colorScheme.primary;
          } else if (isMarked) {
            bgColor = Colors.orange;
          } else if (answered) {
            bgColor = Colors.green;
          } else {
            bgColor = theme.colorScheme.surfaceContainerHighest;
          }

          return GestureDetector(
            onTap: () => onSelect(i),
            child: Container(
              width: 32,
              height: 32,
              margin: const EdgeInsets.only(right: 6),
              decoration: BoxDecoration(
                color: bgColor,
                borderRadius: BorderRadius.circular(8),
              ),
              alignment: Alignment.center,
              child: Text(
                '${i + 1}',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: (isCurrent || answered || isMarked)
                      ? Colors.white
                      : theme.colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

// ─── Question Widget ─────────────────────────────────────────────────

class _QuestionWidget extends StatelessWidget {
  final QuestionModel question;
  final int index;
  final int total;
  final dynamic answer;
  final bool isMarked;
  final ValueChanged<dynamic> onSelectAnswer;
  final ValueChanged<String> onToggleMSQ;
  final VoidCallback onClear;
  final VoidCallback onToggleReview;
  final ValueChanged<double> onNATChanged;

  const _QuestionWidget({
    required this.question,
    required this.index,
    required this.total,
    required this.answer,
    required this.isMarked,
    required this.onSelectAnswer,
    required this.onToggleMSQ,
    required this.onClear,
    required this.onToggleReview,
    required this.onNATChanged,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Question header
        Row(
          children: [
            Text(
              'Question ${index + 1} of $total',
              style: theme.textTheme.labelMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                question.type,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const Spacer(),
            Text(
              '${question.marks} mark${question.marks > 1 ? 's' : ''}',
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // Question text
        Text(
          question.question,
          style: theme.textTheme.bodyLarge?.copyWith(
            fontWeight: FontWeight.w500,
          ),
        ),

        if (question.imageUrl != null) ...[
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.network(
              question.imageUrl!,
              fit: BoxFit.contain,
              height: 200,
              errorBuilder: (_, __, ___) => const SizedBox.shrink(),
            ),
          ),
        ],

        const SizedBox(height: 16),

        // Answer area
        if (question.isMCQ)
          _buildMCQOptions(theme)
        else if (question.isMSQ)
          _buildMSQOptions(theme)
        else
          _buildNATInput(theme),

        const SizedBox(height: 16),

        // Action row
        Row(
          children: [
            TextButton.icon(
              onPressed: onClear,
              icon: const Icon(Icons.clear_rounded, size: 16),
              label: const Text('Clear'),
              style: TextButton.styleFrom(
                foregroundColor: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(width: 8),
            TextButton.icon(
              onPressed: onToggleReview,
              icon: Icon(
                isMarked
                    ? Icons.bookmark_rounded
                    : Icons.bookmark_outline_rounded,
                size: 16,
              ),
              label: Text(isMarked ? 'Remove review' : 'Mark for review'),
              style: TextButton.styleFrom(
                foregroundColor: isMarked
                    ? Colors.orange
                    : theme.colorScheme.primary,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildMCQOptions(ThemeData theme) {
    return Column(
      children: question.options.map((opt) {
        final selected = answer == opt.id;
        return GestureDetector(
          onTap: () => onSelectAnswer(opt.id),
          child: Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: selected
                  ? theme.colorScheme.primary.withValues(alpha: 0.08)
                  : theme.colorScheme.surface,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: selected
                    ? theme.colorScheme.primary
                    : theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
                width: selected ? 1.5 : 1,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  selected
                      ? Icons.radio_button_checked_rounded
                      : Icons.radio_button_off_rounded,
                  size: 20,
                  color: selected
                      ? theme.colorScheme.primary
                      : theme.colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    opt.text,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: selected
                          ? FontWeight.w500
                          : FontWeight.normal,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildMSQOptions(ThemeData theme) {
    final selectedList = List<String>.from((answer as List<dynamic>?) ?? []);
    return Column(
      children: question.options.map((opt) {
        final selected = selectedList.contains(opt.id);
        return GestureDetector(
          onTap: () => onToggleMSQ(opt.id),
          child: Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: selected
                  ? theme.colorScheme.primary.withValues(alpha: 0.08)
                  : theme.colorScheme.surface,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: selected
                    ? theme.colorScheme.primary
                    : theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
                width: selected ? 1.5 : 1,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  selected
                      ? Icons.check_box_rounded
                      : Icons.check_box_outline_blank_rounded,
                  size: 20,
                  color: selected
                      ? theme.colorScheme.primary
                      : theme.colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    opt.text,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: selected
                          ? FontWeight.w500
                          : FontWeight.normal,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildNATInput(ThemeData theme) {
    final current = answer is Map ? answer['value'] : null;
    return TextField(
      decoration: const InputDecoration(
        labelText: 'Enter your answer',
        border: OutlineInputBorder(),
        hintText: 'Numerical value',
      ),
      keyboardType: const TextInputType.numberWithOptions(
        decimal: true,
        signed: true,
      ),
      controller: TextEditingController(
        text: current != null ? current.toString() : '',
      ),
      onChanged: (v) {
        final parsed = double.tryParse(v);
        if (parsed != null) onNATChanged(parsed);
      },
    );
  }
}

// ─── Bottom Navigation ──────────────────────────────────────────────

class _BottomNav extends StatelessWidget {
  final VoidCallback? onPrevious;
  final VoidCallback? onNext;

  const _BottomNav({this.onPrevious, this.onNext});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(
          top: BorderSide(
            color: theme.colorScheme.outlineVariant.withValues(alpha: 0.3),
          ),
        ),
      ),
      child: SafeArea(
        child: Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: onPrevious,
                icon: const Icon(Icons.arrow_back_rounded, size: 18),
                label: const Text('Previous'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: FilledButton.icon(
                onPressed: onNext,
                icon: const Icon(Icons.arrow_forward_rounded, size: 18),
                label: const Text('Next'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
