import 'package:flutter/material.dart';
import '../../coaching/models/coaching_model.dart';
import '../models/batch_model.dart';
import '../services/batch_service.dart';

/// Create or edit a batch — full form with schedule picker + day selector.
class CreateBatchScreen extends StatefulWidget {
  final CoachingModel coaching;
  final BatchModel? batch; // null = create, non-null = edit

  const CreateBatchScreen({super.key, required this.coaching, this.batch});

  @override
  State<CreateBatchScreen> createState() => _CreateBatchScreenState();
}

class _CreateBatchScreenState extends State<CreateBatchScreen> {
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

  bool get _isEdit => widget.batch != null;

  static const _allDays = ['MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT', 'SUN'];
  static const _dayLabels = {
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
  }

  @override
  void dispose() {
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
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to save: $e')));
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
        title: Text(_isEdit ? 'Edit Batch' : 'New Batch'),
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
              // ── Name
              _SectionLabel('Batch Name *'),
              const SizedBox(height: 6),
              TextFormField(
                controller: _nameCtrl,
                decoration: _inputDecoration('e.g. Class 10 Maths Morning'),
                validator: (v) =>
                    v == null || v.trim().isEmpty ? 'Name is required' : null,
                textCapitalization: TextCapitalization.words,
              ),
              const SizedBox(height: 20),

              // ── Subject
              _SectionLabel('Subject'),
              const SizedBox(height: 6),
              TextFormField(
                controller: _subjectCtrl,
                decoration: _inputDecoration('e.g. Mathematics'),
                textCapitalization: TextCapitalization.words,
              ),
              const SizedBox(height: 20),

              // ── Description
              _SectionLabel('Description'),
              const SizedBox(height: 6),
              TextFormField(
                controller: _descCtrl,
                decoration: _inputDecoration('Brief description (optional)'),
                maxLines: 3,
                textCapitalization: TextCapitalization.sentences,
              ),
              const SizedBox(height: 24),

              // ── Schedule heading
              _SectionLabel('Schedule'),
              const SizedBox(height: 10),
              // Day chips
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: _allDays.map((d) {
                  final selected = _selectedDays.contains(d);
                  return FilterChip(
                    label: Text(_dayLabels[d]!),
                    selected: selected,
                    onSelected: (v) {
                      setState(() {
                        if (v) {
                          _selectedDays.add(d);
                        } else {
                          _selectedDays.remove(d);
                        }
                      });
                    },
                    selectedColor: theme.colorScheme.primary.withValues(
                      alpha: 0.15,
                    ),
                    checkmarkColor: theme.colorScheme.primary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 14),

              // Time pickers row
              Row(
                children: [
                  Expanded(
                    child: _TimeTile(
                      label: 'Start',
                      time: _startTime,
                      onTap: () => _pickTime(true),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _TimeTile(
                      label: 'End',
                      time: _endTime,
                      onTap: () => _pickTime(false),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // ── Max students
              _SectionLabel('Max Students'),
              const SizedBox(height: 6),
              TextFormField(
                controller: _maxStudentsCtrl,
                decoration: _inputDecoration('0 = unlimited'),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 36),

              // ── Save button
              SizedBox(
                width: double.infinity,
                height: 52,
                child: FilledButton(
                  onPressed: _isSaving ? null : _save,
                  style: FilledButton.styleFrom(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: _isSaving
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Text(_isEdit ? 'Save Changes' : 'Create Batch'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  InputDecoration _inputDecoration(String hint) {
    return InputDecoration(
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
}

// ── Section label ────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: Theme.of(context).textTheme.labelLarge?.copyWith(
        fontWeight: FontWeight.w600,
        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
      ),
    );
  }
}

// ── Time tile ────────────────────────────────────────────────────────────

class _TimeTile extends StatelessWidget {
  final String label;
  final TimeOfDay? time;
  final VoidCallback onTap;
  const _TimeTile({required this.label, this.time, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(
              Icons.access_time_rounded,
              size: 18,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
            ),
            const SizedBox(width: 8),
            Text(
              time != null ? time!.format(context) : label,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: time != null
                    ? theme.colorScheme.onSurface
                    : theme.colorScheme.onSurface.withValues(alpha: 0.4),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
