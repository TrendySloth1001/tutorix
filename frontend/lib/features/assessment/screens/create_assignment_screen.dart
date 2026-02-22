import 'package:flutter/material.dart';
import '../../../core/constants/error_strings.dart';
import '../../../core/theme/design_tokens.dart';
import '../../../shared/widgets/app_alert.dart';
import '../services/assessment_service.dart';

/// Screen for teachers to create an assignment.
class CreateAssignmentScreen extends StatefulWidget {
  final String coachingId;
  final String batchId;

  const CreateAssignmentScreen({
    super.key,
    required this.coachingId,
    required this.batchId,
  });

  @override
  State<CreateAssignmentScreen> createState() => _CreateAssignmentScreenState();
}

class _CreateAssignmentScreenState extends State<CreateAssignmentScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _marksCtrl = TextEditingController();

  DateTime? _dueDate;
  TimeOfDay? _dueTime;
  bool _allowLate = false;
  bool _saving = false;

  final AssessmentService _service = AssessmentService();

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    _marksCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDueDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _dueDate ?? DateTime.now().add(const Duration(days: 7)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (date == null || !mounted) return;

    final time = await showTimePicker(
      context: context,
      initialTime: _dueTime ?? const TimeOfDay(hour: 23, minute: 59),
    );
    if (!mounted) return;

    setState(() {
      _dueDate = date;
      _dueTime = time ?? const TimeOfDay(hour: 23, minute: 59);
    });
  }

  DateTime? get _dueDatetime {
    if (_dueDate == null) return null;
    final t = _dueTime ?? const TimeOfDay(hour: 23, minute: 59);
    return DateTime(
      _dueDate!.year,
      _dueDate!.month,
      _dueDate!.day,
      t.hour,
      t.minute,
    );
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _saving = true);
    try {
      await _service.createAssignment(
        widget.coachingId,
        widget.batchId,
        title: _titleCtrl.text.trim(),
        description: _descCtrl.text.trim().isEmpty
            ? null
            : _descCtrl.text.trim(),
        dueDate: _dueDatetime?.toIso8601String(),
        allowLateSubmission: _allowLate,
        totalMarks: int.tryParse(_marksCtrl.text),
      );

      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        AppAlert.error(context, e, fallback: AssessmentErrors.createFailed);
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
        title: const Text('Create Assignment'),
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
            TextFormField(
              controller: _titleCtrl,
              decoration: const InputDecoration(
                labelText: 'Title *',
                border: OutlineInputBorder(),
              ),
              validator: (v) =>
                  v == null || v.trim().isEmpty ? 'Required' : null,
            ),
            const SizedBox(height: Spacing.sp16),
            TextFormField(
              controller: _descCtrl,
              decoration: const InputDecoration(
                labelText: 'Description / Instructions',
                border: OutlineInputBorder(),
              ),
              maxLines: 4,
              minLines: 2,
            ),
            const SizedBox(height: Spacing.sp16),
            TextFormField(
              controller: _marksCtrl,
              decoration: const InputDecoration(
                labelText: 'Total Marks',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: Spacing.sp16),

            // Due date
            GestureDetector(
              onTap: _pickDueDate,
              child: InputDecorator(
                decoration: const InputDecoration(
                  labelText: 'Due Date',
                  border: OutlineInputBorder(),
                  suffixIcon: Icon(Icons.calendar_today_rounded),
                ),
                child: Text(
                  _dueDatetime != null
                      ? '${_dueDatetime!.day}/${_dueDatetime!.month}/${_dueDatetime!.year} at ${_dueTime?.format(context) ?? ''}'
                      : 'No deadline',
                  style: theme.textTheme.bodyMedium,
                ),
              ),
            ),
            const SizedBox(height: Spacing.sp12),

            SwitchListTile(
              value: _allowLate,
              onChanged: (v) => setState(() => _allowLate = v),
              title: const Text('Allow late submissions'),
              subtitle: const Text('Students can submit after the due date'),
              contentPadding: EdgeInsets.zero,
            ),
          ],
        ),
      ),
    );
  }
}
