import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../coaching/models/coaching_model.dart';
import '../services/batch_service.dart';

/// Screen to create a new notice / announcement for a batch.
/// Supports different notice types with conditional structured fields.
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
  final _locationCtrl = TextEditingController();
  String _priority = 'normal';
  String _type = 'general';
  bool _isSaving = false;

  // Structured data
  DateTime? _selectedDate;
  TimeOfDay? _selectedStartTime;
  TimeOfDay? _selectedEndTime;
  String? _selectedDay;

  late final AnimationController _animCtrl;
  late final Animation<double> _fadeAnim;

  static const _priorities = [
    ('low', 'Low', Color(0xFF9E9E9E), Icons.arrow_downward_rounded),
    ('normal', 'Normal', Color(0xFF42A5F5), Icons.remove_rounded),
    ('high', 'High', Color(0xFFFFA726), Icons.arrow_upward_rounded),
    ('urgent', 'Urgent', Color(0xFFEF5350), Icons.priority_high_rounded),
  ];

  static const _types = [
    ('general', 'General', Color(0xFF3B82F6), Icons.campaign_rounded),
    (
      'timetable_update',
      'Timetable',
      Color(0xFF8B5CF6),
      Icons.schedule_rounded,
    ),
    ('event', 'Event', Color(0xFF10B981), Icons.event_rounded),
    ('exam', 'Exam', Color(0xFFEF4444), Icons.quiz_rounded),
    ('holiday', 'Holiday', Color(0xFFF59E0B), Icons.beach_access_rounded),
    ('assignment', 'Assignment', Color(0xFF0EA5E9), Icons.assignment_rounded),
  ];

  static const _dayOptions = ['MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT', 'SUN'];

  /// Whether the selected type requires schedule fields.
  bool get _needsSchedule =>
      _type == 'timetable_update' || _type == 'event' || _type == 'exam';

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
    _locationCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? DateTime.now(),
      firstDate: DateTime.now().subtract(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) setState(() => _selectedDate = picked);
  }

  Future<void> _pickTime({required bool isStart}) async {
    final initial = isStart
        ? (_selectedStartTime ?? TimeOfDay.now())
        : (_selectedEndTime ?? _selectedStartTime ?? TimeOfDay.now());
    final picked = await showTimePicker(context: context, initialTime: initial);
    if (picked != null) {
      setState(() {
        if (isStart) {
          _selectedStartTime = picked;
        } else {
          _selectedEndTime = picked;
        }
      });
    }
  }

  String _formatTime(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

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
        type: _type,
        date: _selectedDate?.toIso8601String(),
        startTime: _selectedStartTime != null
            ? _formatTime(_selectedStartTime!)
            : null,
        endTime: _selectedEndTime != null
            ? _formatTime(_selectedEndTime!)
            : null,
        day: _selectedDay,
        location: _locationCtrl.text.trim().isNotEmpty
            ? _locationCtrl.text.trim()
            : null,
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
                // ── Notice type selector
                _FieldLabel('Type', required: true),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _types.map((t) {
                    final selected = _type == t.$1;
                    return GestureDetector(
                      onTap: () => setState(() => _type = t.$1),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: selected
                              ? t.$3.withValues(alpha: 0.12)
                              : theme.colorScheme.surfaceContainerLowest,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: selected
                                ? t.$3.withValues(alpha: 0.5)
                                : theme.colorScheme.onSurface.withValues(
                                    alpha: 0.04,
                                  ),
                            width: selected ? 1.5 : 1,
                          ),
                          boxShadow: selected
                              ? [
                                  BoxShadow(
                                    color: t.$3.withValues(alpha: 0.12),
                                    blurRadius: 6,
                                    offset: const Offset(0, 2),
                                  ),
                                ]
                              : null,
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              t.$4,
                              size: 16,
                              color: selected
                                  ? t.$3
                                  : theme.colorScheme.onSurface.withValues(
                                      alpha: 0.3,
                                    ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              t.$2,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: selected
                                    ? FontWeight.w700
                                    : FontWeight.w500,
                                color: selected
                                    ? t.$3
                                    : theme.colorScheme.onSurface.withValues(
                                        alpha: 0.5,
                                      ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 24),

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

                // ── Conditional schedule fields
                if (_needsSchedule) ...[
                  const SizedBox(height: 28),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceContainerLowest,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: theme.colorScheme.onSurface.withValues(
                          alpha: 0.06,
                        ),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.event_note_rounded,
                              size: 18,
                              color: theme.colorScheme.onSurface.withValues(
                                alpha: 0.5,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Schedule Details',
                              style: theme.textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),

                        // Date picker
                        _FieldLabel('Date'),
                        const SizedBox(height: 8),
                        GestureDetector(
                          onTap: _pickDate,
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 14,
                            ),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.surface,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: theme.colorScheme.onSurface.withValues(
                                  alpha: 0.06,
                                ),
                              ),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.calendar_today_rounded,
                                  size: 18,
                                  color: theme.colorScheme.onSurface.withValues(
                                    alpha: 0.4,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Text(
                                  _selectedDate != null
                                      ? DateFormat(
                                          'dd MMM yyyy',
                                        ).format(_selectedDate!)
                                      : 'Select date',
                                  style: TextStyle(
                                    color: _selectedDate != null
                                        ? theme.colorScheme.onSurface
                                        : theme.colorScheme.onSurface
                                              .withValues(alpha: 0.4),
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Time pickers
                        Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _FieldLabel('Start Time'),
                                  const SizedBox(height: 8),
                                  GestureDetector(
                                    onTap: () => _pickTime(isStart: true),
                                    child: _TimeBox(
                                      label: _selectedStartTime != null
                                          ? _formatTime(_selectedStartTime!)
                                          : 'Start',
                                      hasValue: _selectedStartTime != null,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _FieldLabel('End Time'),
                                  const SizedBox(height: 8),
                                  GestureDetector(
                                    onTap: () => _pickTime(isStart: false),
                                    child: _TimeBox(
                                      label: _selectedEndTime != null
                                          ? _formatTime(_selectedEndTime!)
                                          : 'End',
                                      hasValue: _selectedEndTime != null,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),

                        // Day selector
                        if (_type == 'timetable_update') ...[
                          _FieldLabel('Day'),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            children: _dayOptions.map((d) {
                              final sel = _selectedDay == d;
                              final short = _shortDay(d);
                              return GestureDetector(
                                onTap: () => setState(
                                  () => _selectedDay = sel ? null : d,
                                ),
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 150),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 8,
                                  ),
                                  decoration: BoxDecoration(
                                    color: sel
                                        ? theme.colorScheme.primary.withValues(
                                            alpha: 0.15,
                                          )
                                        : theme.colorScheme.surface,
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(
                                      color: sel
                                          ? theme.colorScheme.primary
                                                .withValues(alpha: 0.4)
                                          : theme.colorScheme.onSurface
                                                .withValues(alpha: 0.08),
                                    ),
                                  ),
                                  child: Text(
                                    short,
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: sel
                                          ? FontWeight.w700
                                          : FontWeight.w500,
                                      color: sel
                                          ? theme.colorScheme.primary
                                          : theme.colorScheme.onSurface
                                                .withValues(alpha: 0.5),
                                    ),
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                          const SizedBox(height: 16),
                        ],

                        // Location
                        _FieldLabel('Location'),
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: _locationCtrl,
                          decoration: _input(
                            'e.g. Room 201, Lab A',
                            Icons.location_on_rounded,
                          ),
                          textCapitalization: TextCapitalization.sentences,
                        ),
                      ],
                    ),
                  ),
                ],

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

  static String _shortDay(String d) {
    const map = {
      'MON': 'Mon',
      'TUE': 'Tue',
      'WED': 'Wed',
      'THU': 'Thu',
      'FRI': 'Fri',
      'SAT': 'Sat',
      'SUN': 'Sun',
    };
    return map[d] ?? d;
  }
}

class _TimeBox extends StatelessWidget {
  final String label;
  final bool hasValue;
  const _TimeBox({required this.label, required this.hasValue});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: theme.colorScheme.onSurface.withValues(alpha: 0.06),
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.access_time_rounded,
            size: 18,
            color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
          ),
          const SizedBox(width: 12),
          Text(
            label,
            style: TextStyle(
              color: hasValue
                  ? theme.colorScheme.onSurface
                  : theme.colorScheme.onSurface.withValues(alpha: 0.4),
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }
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
