import 'package:flutter/material.dart';
import '../../../core/theme/design_tokens.dart';
import '../services/assessment_service.dart';

/// Screen for teachers to create an assessment with questions.
class CreateAssessmentScreen extends StatefulWidget {
  final String coachingId;
  final String batchId;

  const CreateAssessmentScreen({
    super.key,
    required this.coachingId,
    required this.batchId,
  });

  @override
  State<CreateAssessmentScreen> createState() => _CreateAssessmentScreenState();
}

class _CreateAssessmentScreenState extends State<CreateAssessmentScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _durationCtrl = TextEditingController();
  final _passingCtrl = TextEditingController();
  final _attemptsCtrl = TextEditingController(text: '1');
  final _negativeCtrl = TextEditingController(text: '0');

  String _type = 'QUIZ';
  String _showResultAfter = 'SUBMIT';
  bool _shuffleQuestions = false;
  bool _shuffleOptions = false;
  bool _saving = false;

  final List<_QuestionDraft> _questions = [];

  final AssessmentService _service = AssessmentService();

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    _durationCtrl.dispose();
    _passingCtrl.dispose();
    _attemptsCtrl.dispose();
    _negativeCtrl.dispose();
    super.dispose();
  }

  void _addQuestion() {
    setState(() {
      _questions.add(_QuestionDraft());
    });
  }

  void _removeQuestion(int index) {
    setState(() {
      _questions.removeAt(index);
    });
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_questions.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Add at least one question')),
      );
      return;
    }

    // Validate each question
    for (int i = 0; i < _questions.length; i++) {
      final q = _questions[i];
      if (q.questionCtrl.text.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Question ${i + 1} text is empty')),
        );
        return;
      }
      if (q.type == 'MCQ' || q.type == 'MSQ') {
        final validOptions = q.options
            .where((o) => o.text.trim().isNotEmpty)
            .toList();
        if (validOptions.length < 2) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Question ${i + 1} needs at least 2 options'),
            ),
          );
          return;
        }
        if (q.type == 'MCQ' && q.selectedOptions.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Question ${i + 1}: select the correct answer'),
            ),
          );
          return;
        }
        if (q.type == 'MSQ' && q.selectedOptions.length < 2) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Question ${i + 1}: select at least 2 correct answers',
              ),
            ),
          );
          return;
        }
      }
      if (q.type == 'NAT' && q.natAnswerCtrl.text.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Question ${i + 1}: enter the numerical answer'),
          ),
        );
        return;
      }
    }

    setState(() => _saving = true);

    try {
      final questions = _questions.asMap().entries.map((e) {
        final i = e.key;
        final q = e.value;
        final qMap = <String, dynamic>{
          'type': q.type,
          'question': q.questionCtrl.text.trim(),
          'marks': int.tryParse(q.marksCtrl.text) ?? 1,
          'orderIndex': i,
        };
        if (q.explanationCtrl.text.trim().isNotEmpty) {
          qMap['explanation'] = q.explanationCtrl.text.trim();
        }

        if (q.type == 'MCQ' || q.type == 'MSQ') {
          final options = <Map<String, dynamic>>[];
          for (int j = 0; j < q.options.length; j++) {
            if (q.options[j].text.trim().isEmpty) continue;
            options.add({'id': 'opt_$j', 'text': q.options[j].text.trim()});
          }
          qMap['options'] = options;

          if (q.type == 'MCQ') {
            qMap['correctAnswer'] = q.selectedOptions.first;
          } else {
            qMap['correctAnswer'] = q.selectedOptions.toList();
          }
        } else {
          // NAT
          final natMap = <String, dynamic>{
            'value': double.tryParse(q.natAnswerCtrl.text) ?? 0,
          };
          if (q.natToleranceCtrl.text.trim().isNotEmpty) {
            natMap['tolerance'] = double.tryParse(q.natToleranceCtrl.text) ?? 0;
          }
          qMap['correctAnswer'] = natMap;
        }

        return qMap;
      }).toList();

      await _service.createAssessment(
        widget.coachingId,
        widget.batchId,
        title: _titleCtrl.text.trim(),
        description: _descCtrl.text.trim().isEmpty
            ? null
            : _descCtrl.text.trim(),
        type: _type,
        durationMinutes: int.tryParse(_durationCtrl.text),
        passingMarks: int.tryParse(_passingCtrl.text),
        maxAttempts: int.tryParse(_attemptsCtrl.text) ?? 1,
        negativeMarking: double.tryParse(_negativeCtrl.text) ?? 0,
        shuffleQuestions: _shuffleQuestions,
        shuffleOptions: _shuffleOptions,
        showResultAfter: _showResultAfter,
        questions: questions,
      );

      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Create Assessment'),
        actions: [
          TextButton.icon(
            onPressed: _saving ? null : _save,
            icon: _saving
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.check_rounded, size: 18),
            label: const Text('Save'),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(Spacing.sp16),
          children: [
            // ── Details Section ──
            _SectionLabel('Details'),
            const SizedBox(height: Spacing.sp8),
            TextFormField(
              controller: _titleCtrl,
              decoration: const InputDecoration(
                labelText: 'Title *',
                border: OutlineInputBorder(),
              ),
              validator: (v) =>
                  v == null || v.trim().isEmpty ? 'Required' : null,
            ),
            const SizedBox(height: Spacing.sp12),
            TextFormField(
              controller: _descCtrl,
              decoration: const InputDecoration(
                labelText: 'Description',
                border: OutlineInputBorder(),
              ),
              maxLines: 2,
            ),
            const SizedBox(height: Spacing.sp12),
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    initialValue: _type,
                    decoration: const InputDecoration(
                      labelText: 'Type',
                      border: OutlineInputBorder(),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'QUIZ', child: Text('Quiz')),
                      DropdownMenuItem(value: 'TEST', child: Text('Test')),
                      DropdownMenuItem(
                        value: 'PRACTICE',
                        child: Text('Practice'),
                      ),
                    ],
                    onChanged: (v) => setState(() => _type = v ?? 'QUIZ'),
                  ),
                ),
                const SizedBox(width: Spacing.sp12),
                Expanded(
                  child: TextFormField(
                    controller: _durationCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Duration (min)',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.number,
                  ),
                ),
              ],
            ),
            const SizedBox(height: Spacing.sp12),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _passingCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Passing marks',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.number,
                  ),
                ),
                const SizedBox(width: Spacing.sp12),
                Expanded(
                  child: TextFormField(
                    controller: _attemptsCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Max attempts',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.number,
                  ),
                ),
              ],
            ),
            const SizedBox(height: Spacing.sp12),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _negativeCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Negative (%)',
                      border: OutlineInputBorder(),
                      hintText: '0 = none',
                    ),
                    keyboardType: TextInputType.number,
                  ),
                ),
                const SizedBox(width: Spacing.sp12),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    initialValue: _showResultAfter,
                    decoration: const InputDecoration(
                      labelText: 'Show result',
                      border: OutlineInputBorder(),
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: 'SUBMIT',
                        child: Text('After submit'),
                      ),
                      DropdownMenuItem(
                        value: 'MANUAL',
                        child: Text('Manually'),
                      ),
                    ],
                    onChanged: (v) =>
                        setState(() => _showResultAfter = v ?? 'SUBMIT'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: Spacing.sp8),
            Row(
              children: [
                Expanded(
                  child: CheckboxListTile(
                    value: _shuffleQuestions,
                    onChanged: (v) =>
                        setState(() => _shuffleQuestions = v ?? false),
                    title: Text(
                      'Shuffle questions',
                      style: theme.textTheme.bodySmall,
                    ),
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    controlAffinity: ListTileControlAffinity.leading,
                  ),
                ),
                Expanded(
                  child: CheckboxListTile(
                    value: _shuffleOptions,
                    onChanged: (v) =>
                        setState(() => _shuffleOptions = v ?? false),
                    title: Text(
                      'Shuffle options',
                      style: theme.textTheme.bodySmall,
                    ),
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    controlAffinity: ListTileControlAffinity.leading,
                  ),
                ),
              ],
            ),

            const Divider(height: 32),

            // ── Questions Section ──
            Row(
              children: [
                _SectionLabel('Questions (${_questions.length})'),
                const Spacer(),
                TextButton.icon(
                  onPressed: _addQuestion,
                  icon: const Icon(Icons.add_rounded, size: 18),
                  label: const Text('Add'),
                ),
              ],
            ),
            const SizedBox(height: Spacing.sp8),

            ...List.generate(_questions.length, (i) {
              return _QuestionEditor(
                key: ValueKey(_questions[i]),
                index: i,
                draft: _questions[i],
                onRemove: () => _removeQuestion(i),
                onTypeChanged: () => setState(() {}),
              );
            }),

            if (_questions.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: Spacing.sp32),
                child: Center(
                  child: Column(
                    children: [
                      Icon(
                        Icons.help_outline_rounded,
                        size: 48,
                        color: theme.colorScheme.outlineVariant,
                      ),
                      const SizedBox(height: Spacing.sp8),
                      Text(
                        'No questions added yet',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

            const SizedBox(height: Spacing.sp80),
          ],
        ),
      ),
      floatingActionButton: _questions.isNotEmpty
          ? FloatingActionButton(
              onPressed: _addQuestion,
              child: const Icon(Icons.add_rounded),
            )
          : null,
    );
  }
}

// ─── Question Draft (mutable) ────────────────────────────────────────

class _QuestionDraft {
  String type = 'MCQ';
  final questionCtrl = TextEditingController();
  final marksCtrl = TextEditingController(text: '1');
  final explanationCtrl = TextEditingController();
  final natAnswerCtrl = TextEditingController();
  final natToleranceCtrl = TextEditingController();
  List<_OptionDraft> options = [
    _OptionDraft(),
    _OptionDraft(),
    _OptionDraft(),
    _OptionDraft(),
  ];
  Set<String> selectedOptions = {}; // option IDs (indices as strings)
}

class _OptionDraft {
  final ctrl = TextEditingController();
  String get text => ctrl.text;
}

// ─── Question Editor Widget ──────────────────────────────────────────

class _QuestionEditor extends StatefulWidget {
  final int index;
  final _QuestionDraft draft;
  final VoidCallback onRemove;
  final VoidCallback onTypeChanged;

  const _QuestionEditor({
    super.key,
    required this.index,
    required this.draft,
    required this.onRemove,
    required this.onTypeChanged,
  });

  @override
  State<_QuestionEditor> createState() => _QuestionEditorState();
}

class _QuestionEditorState extends State<_QuestionEditor> {
  _QuestionDraft get q => widget.draft;

  void _addOption() {
    setState(() {
      q.options.add(_OptionDraft());
    });
  }

  void _removeOption(int i) {
    setState(() {
      q.selectedOptions.remove('opt_$i');
      q.options.removeAt(i);
      // Re-index selected options
      final newSelected = <String>{};
      for (final s in q.selectedOptions) {
        final idx = int.tryParse(s.replaceAll('opt_', ''));
        if (idx != null && idx > i) {
          newSelected.add('opt_${idx - 1}');
        } else {
          newSelected.add(s);
        }
      }
      q.selectedOptions = newSelected;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      margin: const EdgeInsets.only(bottom: Spacing.sp16),
      padding: const EdgeInsets.all(Spacing.sp12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(Radii.md),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: Spacing.sp8,
                  vertical: Spacing.sp4,
                ),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(Radii.sm),
                ),
                child: Text(
                  'Q${widget.index + 1}',
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: Spacing.sp8),
              Expanded(
                child: DropdownButton<String>(
                  value: q.type,
                  isDense: true,
                  underline: const SizedBox(),
                  items: const [
                    DropdownMenuItem(value: 'MCQ', child: Text('MCQ')),
                    DropdownMenuItem(value: 'MSQ', child: Text('MSQ')),
                    DropdownMenuItem(value: 'NAT', child: Text('NAT')),
                  ],
                  onChanged: (v) {
                    setState(() => q.type = v ?? 'MCQ');
                    widget.onTypeChanged();
                  },
                ),
              ),
              SizedBox(
                width: 60,
                child: TextFormField(
                  controller: q.marksCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Marks',
                    border: OutlineInputBorder(),
                    isDense: true,
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: Spacing.sp8,
                      vertical: Spacing.sp8,
                    ),
                  ),
                  keyboardType: TextInputType.number,
                  style: theme.textTheme.bodySmall,
                ),
              ),
              const SizedBox(width: Spacing.sp4),
              IconButton(
                onPressed: widget.onRemove,
                icon: Icon(
                  Icons.close_rounded,
                  size: 18,
                  color: theme.colorScheme.error,
                ),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ),

          const SizedBox(height: Spacing.sp10),

          // Question text
          TextFormField(
            controller: q.questionCtrl,
            decoration: const InputDecoration(
              labelText: 'Question text *',
              border: OutlineInputBorder(),
            ),
            maxLines: 3,
            minLines: 1,
          ),

          const SizedBox(height: Spacing.sp10),

          // Options (MCQ/MSQ) or NAT input
          if (q.type == 'MCQ' || q.type == 'MSQ')
            _buildOptions(theme)
          else
            _buildNATInput(theme),

          const SizedBox(height: Spacing.sp8),

          // Explanation
          TextFormField(
            controller: q.explanationCtrl,
            decoration: const InputDecoration(
              labelText: 'Explanation (optional)',
              border: OutlineInputBorder(),
              isDense: true,
            ),
            maxLines: 2,
            minLines: 1,
            style: theme.textTheme.bodySmall,
          ),
        ],
      ),
    );
  }

  Widget _buildOptions(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          q.type == 'MCQ'
              ? 'Select the correct answer:'
              : 'Select all correct answers:',
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: Spacing.sp6),
        ...List.generate(q.options.length, (i) {
          final optId = 'opt_$i';
          final isSelected = q.selectedOptions.contains(optId);
          return Padding(
            padding: const EdgeInsets.only(bottom: Spacing.sp6),
            child: Row(
              children: [
                if (q.type == 'MCQ')
                  // ignore: deprecated_member_use
                  Radio<String>(
                    value: optId,
                    // ignore: deprecated_member_use
                    groupValue: q.selectedOptions.isEmpty
                        ? null
                        : q.selectedOptions.first,
                    // ignore: deprecated_member_use
                    onChanged: (v) {
                      setState(() {
                        q.selectedOptions = {v!};
                      });
                    },
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    visualDensity: VisualDensity.compact,
                  )
                else
                  Checkbox(
                    value: isSelected,
                    onChanged: (v) {
                      setState(() {
                        if (v == true) {
                          q.selectedOptions.add(optId);
                        } else {
                          q.selectedOptions.remove(optId);
                        }
                      });
                    },
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    visualDensity: VisualDensity.compact,
                  ),
                const SizedBox(width: Spacing.sp4),
                Expanded(
                  child: TextFormField(
                    controller: q.options[i].ctrl,
                    decoration: InputDecoration(
                      hintText: 'Option ${String.fromCharCode(65 + i)}',
                      border: const OutlineInputBorder(),
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: Spacing.sp10,
                        vertical: Spacing.sp8,
                      ),
                    ),
                    style: theme.textTheme.bodySmall,
                  ),
                ),
                if (q.options.length > 2) ...[
                  const SizedBox(width: Spacing.sp4),
                  GestureDetector(
                    onTap: () => _removeOption(i),
                    child: Icon(
                      Icons.remove_circle_outline_rounded,
                      size: 16,
                      color: theme.colorScheme.error.withValues(alpha: 0.6),
                    ),
                  ),
                ],
              ],
            ),
          );
        }),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: _addOption,
            icon: const Icon(Icons.add_rounded, size: 16),
            label: const Text('Add option'),
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(
                horizontal: Spacing.sp8,
                vertical: Spacing.sp4,
              ),
              textStyle: theme.textTheme.labelSmall,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildNATInput(ThemeData theme) {
    return Row(
      children: [
        Expanded(
          flex: 2,
          child: TextFormField(
            controller: q.natAnswerCtrl,
            decoration: const InputDecoration(
              labelText: 'Correct answer *',
              border: OutlineInputBorder(),
            ),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
          ),
        ),
        const SizedBox(width: Spacing.sp12),
        Expanded(
          child: TextFormField(
            controller: q.natToleranceCtrl,
            decoration: const InputDecoration(
              labelText: 'Tolerance',
              border: OutlineInputBorder(),
              hintText: '0',
            ),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
          ),
        ),
      ],
    );
  }
}

// ─── Section Label ───────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: Theme.of(context).textTheme.titleSmall?.copyWith(
        fontWeight: FontWeight.w700,
        color: Theme.of(context).colorScheme.primary,
      ),
    );
  }
}
