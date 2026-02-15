import 'package:flutter/material.dart';
import '../../coaching/models/coaching_model.dart';
import '../services/batch_service.dart';

/// Screen to create a new notice / announcement for a batch.
class CreateNoticeScreen extends StatefulWidget {
  final CoachingModel coaching;
  final String batchId;

  const CreateNoticeScreen({
    super.key,
    required this.coaching,
    required this.batchId,
  });

  @override
  State<CreateNoticeScreen> createState() => _CreateNoticeScreenState();
}

class _CreateNoticeScreenState extends State<CreateNoticeScreen> {
  final _formKey = GlobalKey<FormState>();
  final BatchService _batchService = BatchService();

  final _titleCtrl = TextEditingController();
  final _messageCtrl = TextEditingController();
  String _priority = 'normal';
  bool _isSaving = false;

  static const _priorities = [
    ('low', 'Low', Colors.grey, Icons.arrow_downward_rounded),
    ('normal', 'Normal', Colors.blue, Icons.remove_rounded),
    ('high', 'High', Colors.orange, Icons.arrow_upward_rounded),
    ('urgent', 'Urgent', Colors.red, Icons.priority_high_rounded),
  ];

  @override
  void dispose() {
    _titleCtrl.dispose();
    _messageCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);

    try {
      await _batchService.createNotice(
        widget.coaching.id,
        widget.batchId,
        title: _titleCtrl.text.trim(),
        message: _messageCtrl.text.trim(),
        priority: _priority,
      );
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed: $e')));
      }
    }
    if (mounted) setState(() => _isSaving = false);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: AppBar(
        title: const Text('Send Notice'),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.transparent,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Priority
              Text(
                'Priority',
                style: theme.textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: _priorities.map((p) {
                  final selected = _priority == p.$1;
                  return Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 3),
                      child: GestureDetector(
                        onTap: () => setState(() => _priority = p.$1),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          decoration: BoxDecoration(
                            color: selected
                                ? p.$3.withValues(alpha: 0.15)
                                : theme.colorScheme.surfaceContainerLowest,
                            borderRadius: BorderRadius.circular(12),
                            border: selected
                                ? Border.all(
                                    color: p.$3.withValues(alpha: 0.5),
                                    width: 1.5,
                                  )
                                : null,
                          ),
                          child: Column(
                            children: [
                              Icon(
                                p.$4,
                                size: 18,
                                color: selected
                                    ? p.$3
                                    : theme.colorScheme.onSurface.withValues(
                                        alpha: 0.3,
                                      ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                p.$2,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: selected
                                      ? FontWeight.w600
                                      : FontWeight.w400,
                                  color: selected
                                      ? p.$3
                                      : theme.colorScheme.onSurface.withValues(
                                          alpha: 0.5,
                                        ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 24),

              // ── Title
              Text(
                'Title *',
                style: theme.textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 6),
              TextFormField(
                controller: _titleCtrl,
                decoration: _input('e.g. Exam Schedule Change'),
                validator: (v) =>
                    v == null || v.trim().isEmpty ? 'Title is required' : null,
                textCapitalization: TextCapitalization.sentences,
              ),
              const SizedBox(height: 20),

              // ── Message
              Text(
                'Message *',
                style: theme.textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 6),
              TextFormField(
                controller: _messageCtrl,
                decoration: _input('Type your announcement...'),
                validator: (v) => v == null || v.trim().isEmpty
                    ? 'Message is required'
                    : null,
                maxLines: 5,
                textCapitalization: TextCapitalization.sentences,
              ),
              const SizedBox(height: 36),

              // ── Send
              SizedBox(
                width: double.infinity,
                height: 52,
                child: FilledButton.icon(
                  onPressed: _isSaving ? null : _save,
                  icon: _isSaving
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.send_rounded),
                  label: const Text('Send Notice'),
                  style: FilledButton.styleFrom(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  InputDecoration _input(String hint) => InputDecoration(
    hintText: hint,
    filled: true,
    fillColor: Theme.of(context).colorScheme.surfaceContainerLowest,
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide.none,
    ),
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
  );
}
