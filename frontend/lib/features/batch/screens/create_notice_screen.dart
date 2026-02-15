import 'package:flutter/material.dart';
import '../../coaching/models/coaching_model.dart';
import '../services/batch_service.dart';

/// Screen to create a new notice / announcement for a batch.
/// Premium design with polished priority selector and form.
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

class _CreateNoticeScreenState extends State<CreateNoticeScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final BatchService _batchService = BatchService();

  final _titleCtrl = TextEditingController();
  final _messageCtrl = TextEditingController();
  String _priority = 'normal';
  bool _isSaving = false;

  late final AnimationController _animCtrl;
  late final Animation<double> _fadeAnim;

  static const _priorities = [
    ('low', 'Low', Color(0xFF9E9E9E), Icons.arrow_downward_rounded),
    ('normal', 'Normal', Color(0xFF42A5F5), Icons.remove_rounded),
    ('high', 'High', Color(0xFFFFA726), Icons.arrow_upward_rounded),
    ('urgent', 'Urgent', Color(0xFFEF5350), Icons.priority_high_rounded),
  ];

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _fadeAnim = CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut);
    _animCtrl.forward();
  }

  @override
  void dispose() {
    _animCtrl.dispose();
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
        title: const Text(
          'Send Notice',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.transparent,
      ),
      body: FadeTransition(
        opacity: _fadeAnim,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Priority selector
                _FieldLabel('Priority', required: true),
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
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            decoration: BoxDecoration(
                              color: selected
                                  ? p.$3.withValues(alpha: 0.12)
                                  : theme.colorScheme.surfaceContainerLowest,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: selected
                                    ? p.$3.withValues(alpha: 0.5)
                                    : theme.colorScheme.onSurface.withValues(
                                        alpha: 0.04,
                                      ),
                                width: selected ? 1.5 : 1,
                              ),
                              boxShadow: selected
                                  ? [
                                      BoxShadow(
                                        color: p.$3.withValues(alpha: 0.15),
                                        blurRadius: 8,
                                        offset: const Offset(0, 2),
                                      ),
                                    ]
                                  : null,
                            ),
                            child: Column(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: BoxDecoration(
                                    color: selected
                                        ? p.$3.withValues(alpha: 0.15)
                                        : theme.colorScheme.onSurface
                                              .withValues(alpha: 0.04),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    p.$4,
                                    size: 16,
                                    color: selected
                                        ? p.$3
                                        : theme.colorScheme.onSurface
                                              .withValues(alpha: 0.25),
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  p.$2,
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: selected
                                        ? FontWeight.w700
                                        : FontWeight.w400,
                                    letterSpacing: selected ? 0.3 : 0,
                                    color: selected
                                        ? p.$3
                                        : theme.colorScheme.onSurface
                                              .withValues(alpha: 0.45),
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
                const SizedBox(height: 28),

                // ── Title
                _FieldLabel('Title', required: true),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _titleCtrl,
                  decoration: _input(
                    'e.g. Exam Schedule Change',
                    Icons.title_rounded,
                  ),
                  validator: (v) => v == null || v.trim().isEmpty
                      ? 'Title is required'
                      : null,
                  textCapitalization: TextCapitalization.sentences,
                ),
                const SizedBox(height: 24),

                // ── Message
                _FieldLabel('Message', required: true),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _messageCtrl,
                  decoration: _input(
                    'Type your announcement...',
                    Icons.message_rounded,
                  ),
                  validator: (v) => v == null || v.trim().isEmpty
                      ? 'Message is required'
                      : null,
                  maxLines: 6,
                  textCapitalization: TextCapitalization.sentences,
                ),
                const SizedBox(height: 40),

                // ── Send button
                Container(
                  width: double.infinity,
                  height: 54,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        theme.colorScheme.primary,
                        theme.colorScheme.primary.withValues(alpha: 0.85),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: theme.colorScheme.primary.withValues(
                          alpha: 0.25,
                        ),
                        blurRadius: 10,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: _isSaving ? null : _save,
                      borderRadius: BorderRadius.circular(16),
                      child: Center(
                        child: _isSaving
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.5,
                                  color: Colors.white,
                                ),
                              )
                            : Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.send_rounded,
                                    size: 18,
                                    color: theme.colorScheme.onPrimary,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Send Notice',
                                    style: TextStyle(
                                      color: theme.colorScheme.onPrimary,
                                      fontWeight: FontWeight.w700,
                                      fontSize: 15,
                                    ),
                                  ),
                                ],
                              ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  InputDecoration _input(String hint, IconData icon) => InputDecoration(
    hintText: hint,
    prefixIcon: Icon(icon, size: 20),
    filled: true,
    fillColor: Theme.of(context).colorScheme.surfaceContainerLowest,
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: BorderSide.none,
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: BorderSide(
        color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.3),
      ),
    ),
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
  );
}

class _FieldLabel extends StatelessWidget {
  final String text;
  final bool required;
  const _FieldLabel(this.text, {this.required = false});
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Text(
          text,
          style: theme.textTheme.labelLarge?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        if (required) ...[
          const SizedBox(width: 4),
          Text('*', style: TextStyle(color: Colors.red.shade300, fontSize: 14)),
        ],
      ],
    );
  }
}
