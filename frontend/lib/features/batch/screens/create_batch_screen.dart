import 'package:flutter/material.dart';
import '../../../shared/widgets/app_alert.dart';
import '../../coaching/models/coaching_model.dart';
import '../models/batch_model.dart';
import '../services/batch_service.dart';
import '../../../core/theme/design_tokens.dart';

/// Create or edit a batch — premium form with schedule picker + day selector.
class CreateBatchScreen extends StatefulWidget {
  final CoachingModel coaching;
  final BatchModel? batch; // null = create, non-null = edit

  const CreateBatchScreen({super.key, required this.coaching, this.batch});

  @override
  State<CreateBatchScreen> createState() => _CreateBatchScreenState();
}

class _CreateBatchScreenState extends State<CreateBatchScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final BatchService _batchService = BatchService();

  late TextEditingController _nameCtrl;
  late TextEditingController _subjectCtrl;
  late TextEditingController _descCtrl;
  late TextEditingController _maxStudentsCtrl;

  TimeOfDay? _startTime;
  TimeOfDay? _endTime;
  final Set<String> _selectedDays = {};
  bool _isSaving = false;

  late AnimationController _animCtrl;
  late Animation<double> _fadeAnim;

  bool get _isEdit => widget.batch != null;

  static const _allDays = ['MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT', 'SUN'];
  static const _dayLabels = {
    'MON': 'M',
    'TUE': 'T',
    'WED': 'W',
    'THU': 'T',
    'FRI': 'F',
    'SAT': 'S',
    'SUN': 'S',
  };
  static const _dayFull = {
    'MON': 'Mon',
    'TUE': 'Tue',
    'WED': 'Wed',
    'THU': 'Thu',
    'FRI': 'Fri',
    'SAT': 'Sat',
    'SUN': 'Sun',
  };

  @override
  void initState() {
    super.initState();
    final b = widget.batch;
    _nameCtrl = TextEditingController(text: b?.name ?? '');
    _subjectCtrl = TextEditingController(text: b?.subject ?? '');
    _descCtrl = TextEditingController(text: b?.description ?? '');
    _maxStudentsCtrl = TextEditingController(
      text: b != null && b.maxStudents > 0 ? '${b.maxStudents}' : '',
    );
    if (b != null) {
      _selectedDays.addAll(b.days);
      _startTime = _parseTime(b.startTime);
      _endTime = _parseTime(b.endTime);
    }

    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _fadeAnim = CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut);
    _animCtrl.forward();
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    _nameCtrl.dispose();
    _subjectCtrl.dispose();
    _descCtrl.dispose();
    _maxStudentsCtrl.dispose();
    super.dispose();
  }

  TimeOfDay? _parseTime(String? t) {
    if (t == null || !t.contains(':')) return null;
    final parts = t.split(':');
    return TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
  }

  String? _formatTime(TimeOfDay? t) {
    if (t == null) return null;
    return '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
  }

  Future<void> _pickTime(bool isStart) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: isStart
          ? (_startTime ?? const TimeOfDay(hour: 9, minute: 0))
          : (_endTime ?? const TimeOfDay(hour: 10, minute: 30)),
    );
    if (picked != null) {
      setState(() {
        if (isStart) {
          _startTime = picked;
        } else {
          _endTime = picked;
        }
      });
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);

    try {
      final maxStudents = int.tryParse(_maxStudentsCtrl.text.trim()) ?? 0;
      if (_isEdit) {
        await _batchService.updateBatch(
          widget.coaching.id,
          widget.batch!.id,
          name: _nameCtrl.text.trim(),
          subject: _subjectCtrl.text.trim().isEmpty
              ? null
              : _subjectCtrl.text.trim(),
          description: _descCtrl.text.trim().isEmpty
              ? null
              : _descCtrl.text.trim(),
          startTime: _formatTime(_startTime),
          endTime: _formatTime(_endTime),
          days: _selectedDays.toList(),
          maxStudents: maxStudents,
        );
      } else {
        await _batchService.createBatch(
          widget.coaching.id,
          name: _nameCtrl.text.trim(),
          subject: _subjectCtrl.text.trim().isEmpty
              ? null
              : _subjectCtrl.text.trim(),
          description: _descCtrl.text.trim().isEmpty
              ? null
              : _descCtrl.text.trim(),
          startTime: _formatTime(_startTime),
          endTime: _formatTime(_endTime),
          days: _selectedDays.toList(),
          maxStudents: maxStudents,
        );
      }
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        AppAlert.error(context, e, fallback: 'Failed to save batch');
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
        title: Text(
          _isEdit ? 'Edit Batch' : 'New Batch',
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.transparent,
      ),
      body: FadeTransition(
        opacity: _fadeAnim,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(
            Spacing.sp20,
            Spacing.sp8,
            Spacing.sp20,
            Spacing.sp40,
          ),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Name
                _FieldLabel('Batch Name', isRequired: true),
                const SizedBox(height: Spacing.sp8),
                TextFormField(
                  controller: _nameCtrl,
                  decoration: _inputDeco(
                    'e.g. Class 10 Maths Morning',
                    Icons.layers_rounded,
                  ),
                  validator: (v) =>
                      v == null || v.trim().isEmpty ? 'Name is required' : null,
                  textCapitalization: TextCapitalization.words,
                ),
                const SizedBox(height: Spacing.sp24),

                // ── Subject
                _FieldLabel('Subject'),
                const SizedBox(height: Spacing.sp8),
                TextFormField(
                  controller: _subjectCtrl,
                  decoration: _inputDeco(
                    'e.g. Mathematics',
                    Icons.menu_book_rounded,
                  ),
                  textCapitalization: TextCapitalization.words,
                ),
                const SizedBox(height: Spacing.sp24),

                // ── Description
                _FieldLabel('Description'),
                const SizedBox(height: Spacing.sp8),
                TextFormField(
                  controller: _descCtrl,
                  decoration: _inputDeco(
                    'Brief description (optional)',
                    Icons.notes_rounded,
                  ),
                  maxLines: 3,
                  textCapitalization: TextCapitalization.sentences,
                ),
                const SizedBox(height: Spacing.sp28),

                // ── Schedule
                _FieldLabel('Schedule'),
                const SizedBox(height: Spacing.sp12),

                // Day circle selectors
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: _allDays.map((d) {
                    final selected = _selectedDays.contains(d);
                    return GestureDetector(
                      onTap: () {
                        setState(() {
                          if (selected) {
                            _selectedDays.remove(d);
                          } else {
                            _selectedDays.add(d);
                          }
                        });
                      },
                      child: Tooltip(
                        message: _dayFull[d]!,
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          curve: Curves.easeOut,
                          width: 42,
                          height: 42,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: selected
                                ? theme.colorScheme.primary
                                : theme.colorScheme.surfaceContainerLowest,
                            border: selected
                                ? null
                                : Border.all(
                                    color: theme.colorScheme.onSurface
                                        .withValues(alpha: 0.08),
                                  ),
                            boxShadow: selected
                                ? [
                                    BoxShadow(
                                      color: theme.colorScheme.primary
                                          .withValues(alpha: 0.25),
                                      blurRadius: 6,
                                      offset: const Offset(0, 2),
                                    ),
                                  ]
                                : null,
                          ),
                          child: Center(
                            child: Text(
                              _dayLabels[d]!,
                              style: TextStyle(
                                fontWeight: selected
                                    ? FontWeight.w700
                                    : FontWeight.w500,
                                fontSize: FontSize.body,
                                color: selected
                                    ? theme.colorScheme.onPrimary
                                    : theme.colorScheme.onSurface.withValues(
                                        alpha: 0.45,
                                      ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: Spacing.sp20),

                // Time pickers row
                Row(
                  children: [
                    Expanded(
                      child: _TimeTile(
                        label: 'Start Time',
                        time: _startTime,
                        icon: Icons.play_circle_outline_rounded,
                        onTap: () => _pickTime(true),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: Spacing.sp8,
                      ),
                      child: Icon(
                        Icons.arrow_forward_rounded,
                        size: 18,
                        color: theme.colorScheme.onSurface.withValues(
                          alpha: 0.2,
                        ),
                      ),
                    ),
                    Expanded(
                      child: _TimeTile(
                        label: 'End Time',
                        time: _endTime,
                        icon: Icons.stop_circle_outlined,
                        onTap: () => _pickTime(false),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: Spacing.sp28),

                // ── Max students
                _FieldLabel('Max Students'),
                const SizedBox(height: Spacing.sp8),
                TextFormField(
                  controller: _maxStudentsCtrl,
                  decoration: _inputDeco(
                    '0 = unlimited',
                    Icons.people_outline_rounded,
                  ),
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: Spacing.sp40),

                // ── Save button
                SizedBox(
                  width: double.infinity,
                  height: 54,
                  child: FilledButton(
                    onPressed: _isSaving ? null : _save,
                    style: FilledButton.styleFrom(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(Radii.lg),
                      ),
                      elevation: 0,
                    ),
                    child: _isSaving
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              color: Colors.white,
                            ),
                          )
                        : Text(
                            _isEdit ? 'Save Changes' : 'Create Batch',
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: FontSize.body,
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

  InputDecoration _inputDeco(String hint, IconData icon) {
    final theme = Theme.of(context);
    return InputDecoration(
      hintText: hint,
      prefixIcon: Icon(
        icon,
        size: 20,
        color: theme.colorScheme.onSurface.withValues(alpha: 0.3),
      ),
      filled: true,
      fillColor: theme.colorScheme.surfaceContainerLowest,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(Radii.md),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(Radii.md),
        borderSide: BorderSide(
          color: theme.colorScheme.onSurface.withValues(alpha: 0.06),
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(Radii.md),
        borderSide: BorderSide(
          color: theme.colorScheme.primary.withValues(alpha: 0.4),
          width: 1.5,
        ),
      ),
      contentPadding: const EdgeInsets.symmetric(
        horizontal: Spacing.sp16,
        vertical: Spacing.sp14,
      ),
    );
  }
}

// ── Field label ──────────────────────────────────────────────────────

class _FieldLabel extends StatelessWidget {
  final String text;
  final bool isRequired;
  const _FieldLabel(this.text, {this.isRequired = false});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Text(
          text,
          style: theme.textTheme.labelLarge?.copyWith(
            fontWeight: FontWeight.w600,
            color: theme.colorScheme.onSurface.withValues(alpha: 0.75),
            letterSpacing: 0.2,
          ),
        ),
        if (isRequired)
          Text(
            ' *',
            style: TextStyle(
              color: theme.colorScheme.error,
              fontWeight: FontWeight.w600,
            ),
          ),
      ],
    );
  }
}

// ── Time tile ────────────────────────────────────────────────────────────

class _TimeTile extends StatelessWidget {
  final String label;
  final TimeOfDay? time;
  final IconData icon;
  final VoidCallback onTap;
  const _TimeTile({
    required this.label,
    this.time,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasTime = time != null;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(Radii.md),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: Spacing.sp14,
          vertical: Spacing.sp14,
        ),
        decoration: BoxDecoration(
          color: hasTime
              ? theme.colorScheme.primary.withValues(alpha: 0.06)
              : theme.colorScheme.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(Radii.md),
          border: Border.all(
            color: hasTime
                ? theme.colorScheme.primary.withValues(alpha: 0.15)
                : theme.colorScheme.onSurface.withValues(alpha: 0.06),
          ),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 18,
              color: hasTime
                  ? theme.colorScheme.primary
                  : theme.colorScheme.onSurface.withValues(alpha: 0.3),
            ),
            const SizedBox(width: Spacing.sp10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
                    fontSize: FontSize.nano,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: Spacing.sp2),
                Text(
                  hasTime ? time!.format(context) : '—',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: hasTime
                        ? theme.colorScheme.onSurface
                        : theme.colorScheme.onSurface.withValues(alpha: 0.3),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
