import 'package:flutter/material.dart';
import '../../../shared/widgets/app_alert.dart';
import '../../../shared/widgets/app_shimmer.dart';
import '../models/academic_masters.dart';
import '../services/academic_service.dart';

/// Multi-step academic onboarding flow
/// Shows after user accepts a STUDENT invitation
class AcademicOnboardingScreen extends StatefulWidget {
  final VoidCallback onComplete;
  final VoidCallback onRemindLater;

  const AcademicOnboardingScreen({
    super.key,
    required this.onComplete,
    required this.onRemindLater,
  });

  @override
  State<AcademicOnboardingScreen> createState() =>
      _AcademicOnboardingScreenState();
}

class _AcademicOnboardingScreenState extends State<AcademicOnboardingScreen> {
  final _service = AcademicService();
  final _pageController = PageController();
  final _schoolController = TextEditingController();

  AcademicMasters? _masters;
  bool _isLoading = true;
  bool _isSaving = false;
  int _currentStep = 0;

  // Form data
  String? _selectedBoard;
  String? _selectedClass;
  String? _selectedStream;
  final Set<String> _selectedSubjects = {};
  final Set<String> _selectedExams = {};
  int? _targetYear;

  @override
  void initState() {
    super.initState();
    _loadMasters();
  }

  @override
  void dispose() {
    _pageController.dispose();
    _schoolController.dispose();
    super.dispose();
  }

  Future<void> _loadMasters() async {
    try {
      final masters = await _service.getMasters();
      setState(() {
        _masters = masters;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  int get _totalSteps {
    if (_masters == null) return 3;

    // Step 1: School, Board, Class (always)
    // Step 2: Stream (only for 11-12 / Dropper)
    // Step 3: Subjects
    // Step 4: Competitive exams (only for Science)

    int steps = 3; // Basic: School+Board+Class, Subjects, Review

    if (_needsStreamSelection) steps++;
    if (_showCompetitiveExams) steps++;

    return steps;
  }

  bool get _needsStreamSelection {
    if (_selectedClass == null || _masters == null) return false;
    final cls = _masters!.classes
        .where((c) => c.id == _selectedClass)
        .firstOrNull;
    return cls?.requiresStream ?? false;
  }

  bool get _showCompetitiveExams {
    if (_selectedStream == null) return false;
    return _selectedStream!.startsWith('SCIENCE');
  }

  void _nextStep() {
    if (_currentStep < _totalSteps - 1) {
      setState(() => _currentStep++);
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      _saveProfile();
    }
  }

  void _prevStep() {
    if (_currentStep > 0) {
      setState(() => _currentStep--);
      _pageController.previousPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  Future<void> _saveProfile() async {
    setState(() => _isSaving = true);
    try {
      await _service.saveProfile(
        schoolName: _schoolController.text.trim().isEmpty
            ? null
            : _schoolController.text.trim(),
        board: _selectedBoard,
        classId: _selectedClass,
        stream: _selectedStream,
        subjects: _selectedSubjects.toList(),
        competitiveExams: _selectedExams.toList(),
        targetYear: _targetYear,
      );
      widget.onComplete();
    } catch (e) {
      if (mounted) {
        AppAlert.error(context, e, fallback: 'Failed to save profile');
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _handleRemindLater() async {
    try {
      await _service.remindLater();
      widget.onRemindLater();
    } catch (e) {
      if (mounted) {
        AppAlert.error(context, e, fallback: 'Something went wrong');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    if (_isLoading) {
      return Scaffold(
        backgroundColor: colorScheme.surface,
        body: const GenericListShimmer(),
      );
    }

    if (_masters == null) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Failed to load data'),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () {
                  setState(() => _isLoading = true);
                  _loadMasters();
                },
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: colorScheme.surface,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(theme),
            _buildProgressIndicator(colorScheme),
            Expanded(
              child: PageView(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(),
                children: _buildSteps(),
              ),
            ),
            _buildBottomButtons(theme, colorScheme),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.school_outlined,
                  color: theme.colorScheme.primary,
                  size: 28,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Let's personalize your learning",
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Help your teachers create the perfect learning path for you',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurface.withValues(
                          alpha: 0.7,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildProgressIndicator(ColorScheme colorScheme) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Row(
        children: List.generate(_totalSteps, (index) {
          final isActive = index <= _currentStep;
          final isCurrent = index == _currentStep;
          return Expanded(
            child: Container(
              height: 4,
              margin: EdgeInsets.only(right: index < _totalSteps - 1 ? 4 : 0),
              decoration: BoxDecoration(
                color: isActive
                    ? colorScheme.primary
                    : colorScheme.primary.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(2),
              ),
              child: isCurrent
                  ? TweenAnimationBuilder<double>(
                      tween: Tween(begin: 0, end: 1),
                      duration: const Duration(milliseconds: 300),
                      builder: (_, value, _) => FractionallySizedBox(
                        alignment: Alignment.centerLeft,
                        widthFactor: value,
                        child: Container(
                          decoration: BoxDecoration(
                            color: colorScheme.primary,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                    )
                  : null,
            ),
          );
        }),
      ),
    );
  }

  List<Widget> _buildSteps() {
    final steps = <Widget>[_buildSchoolBoardClassStep()];

    if (_needsStreamSelection) {
      steps.add(_buildStreamStep());
    }

    steps.add(_buildSubjectsStep());

    if (_showCompetitiveExams) {
      steps.add(_buildCompetitiveExamsStep());
    }

    steps.add(_buildReviewStep());

    return steps;
  }

  Widget _buildSchoolBoardClassStep() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionTitle('Your School', Icons.apartment_outlined),
          const SizedBox(height: 12),
          TextField(
            controller: _schoolController,
            decoration: InputDecoration(
              hintText: 'Enter your school name (optional)',
              prefixIcon: const Icon(Icons.school_outlined),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
          const SizedBox(height: 32),
          _buildSectionTitle('Your Board', Icons.menu_book_outlined),
          const SizedBox(height: 12),
          _buildBoardSelector(),
          const SizedBox(height: 32),
          _buildSectionTitle('Current Class', Icons.class_outlined),
          const SizedBox(height: 12),
          _buildClassSelector(),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 20, color: Theme.of(context).colorScheme.primary),
        const SizedBox(width: 8),
        Text(
          title,
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
        ),
      ],
    );
  }

  Widget _buildBoardSelector() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: _masters!.boards.map((board) {
        final isSelected = _selectedBoard == board.id;
        return _SelectableChip(
          label: board.name,
          isSelected: isSelected,
          onTap: () => setState(() => _selectedBoard = board.id),
        );
      }).toList(),
    );
  }

  Widget _buildClassSelector() {
    final grouped = _masters!.classesGrouped;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: grouped.entries.map((entry) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 8, bottom: 8),
              child: Text(
                entry.key,
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: Theme.of(
                    context,
                  ).colorScheme.onSurface.withValues(alpha: 0.6),
                ),
              ),
            ),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: entry.value.map((cls) {
                final isSelected = _selectedClass == cls.id;
                return _SelectableChip(
                  label: cls.name,
                  isSelected: isSelected,
                  onTap: () {
                    setState(() {
                      _selectedClass = cls.id;
                      // Reset stream if class changes
                      if (!cls.requiresStream) {
                        _selectedStream = null;
                      }
                      _selectedSubjects.clear();
                    });
                  },
                );
              }).toList(),
            ),
          ],
        );
      }).toList(),
    );
  }

  Widget _buildStreamStep() {
    final streams = _masters!.getStreamsFor(_selectedClass!);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionTitle('Choose Your Stream', Icons.category_outlined),
          const SizedBox(height: 8),
          Text(
            'Select the stream you are studying in',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(
                context,
              ).colorScheme.onSurface.withValues(alpha: 0.7),
            ),
          ),
          const SizedBox(height: 24),
          ...streams.map((stream) {
            final isSelected = _selectedStream == stream.id;
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _StreamCard(
                title: stream.name,
                description: stream.description,
                isSelected: isSelected,
                onTap: () {
                  setState(() {
                    _selectedStream = stream.id;
                    _selectedSubjects.clear();
                  });
                },
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildSubjectsStep() {
    final subjects = _masters!.getSubjectsFor(
      _selectedClass ?? 'CLASS_10',
      _selectedStream,
    );

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionTitle('Select Your Subjects', Icons.book_outlined),
          const SizedBox(height: 8),
          Text(
            'Choose the subjects you are currently studying',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(
                context,
              ).colorScheme.onSurface.withValues(alpha: 0.7),
            ),
          ),
          const SizedBox(height: 24),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: subjects.map((subject) {
              final isSelected = _selectedSubjects.contains(subject.id);
              return _SelectableChip(
                label: subject.name,
                isSelected: isSelected,
                onTap: () {
                  setState(() {
                    if (isSelected) {
                      _selectedSubjects.remove(subject.id);
                    } else {
                      _selectedSubjects.add(subject.id);
                    }
                  });
                },
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildCompetitiveExamsStep() {
    final examsByCategory = _masters!.examsByCategory;
    final currentYear = DateTime.now().year;
    final yearOptions = List.generate(5, (i) => currentYear + i);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionTitle(
            'Competitive Exam Preparation',
            Icons.emoji_events_outlined,
          ),
          const SizedBox(height: 8),
          Text(
            'Are you preparing for any competitive exams?',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(
                context,
              ).colorScheme.onSurface.withValues(alpha: 0.7),
            ),
          ),
          const SizedBox(height: 24),

          // Target year
          Row(
            children: [
              const Text('Target Year: '),
              const SizedBox(width: 12),
              DropdownButton<int>(
                value: _targetYear,
                hint: const Text('Select year'),
                items: yearOptions
                    .map(
                      (year) => DropdownMenuItem(
                        value: year,
                        child: Text(year.toString()),
                      ),
                    )
                    .toList(),
                onChanged: (value) => setState(() => _targetYear = value),
              ),
            ],
          ),

          const SizedBox(height: 24),

          // Exams by category
          ...examsByCategory.entries
              .where(
                (e) => ['Engineering', 'Medical', 'Olympiad'].contains(e.key),
              )
              .map((entry) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(top: 8, bottom: 12),
                      child: Text(
                        entry.key,
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: entry.value.map((exam) {
                        final isSelected = _selectedExams.contains(exam.id);
                        return _SelectableChip(
                          label: exam.name,
                          isSelected: isSelected,
                          onTap: () {
                            setState(() {
                              if (isSelected) {
                                _selectedExams.remove(exam.id);
                              } else {
                                _selectedExams.add(exam.id);
                              }
                            });
                          },
                        );
                      }).toList(),
                    ),
                  ],
                );
              }),

          const SizedBox(height: 16),
          TextButton(
            onPressed: () => setState(() => _selectedExams.clear()),
            child: const Text('Skip - Not preparing for any exam'),
          ),
        ],
      ),
    );
  }

  Widget _buildReviewStep() {
    final board = _masters!.boards
        .where((b) => b.id == _selectedBoard)
        .firstOrNull;
    final cls = _masters!.classes
        .where((c) => c.id == _selectedClass)
        .firstOrNull;
    final stream = _masters!.streams
        .where((s) => s.id == _selectedStream)
        .firstOrNull;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionTitle('Review Your Profile', Icons.check_circle_outline),
          const SizedBox(height: 8),
          Text(
            "Make sure everything looks right before we save",
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(
                context,
              ).colorScheme.onSurface.withValues(alpha: 0.7),
            ),
          ),
          const SizedBox(height: 24),

          _ReviewItem(
            icon: Icons.apartment_outlined,
            label: 'School',
            value: _schoolController.text.isEmpty
                ? 'Not specified'
                : _schoolController.text,
          ),
          _ReviewItem(
            icon: Icons.menu_book_outlined,
            label: 'Board',
            value: board?.name ?? 'Not selected',
          ),
          _ReviewItem(
            icon: Icons.class_outlined,
            label: 'Class',
            value: cls?.name ?? 'Not selected',
          ),
          if (stream != null)
            _ReviewItem(
              icon: Icons.category_outlined,
              label: 'Stream',
              value: stream.name,
            ),
          if (_selectedSubjects.isNotEmpty)
            _ReviewItem(
              icon: Icons.book_outlined,
              label: 'Subjects',
              value: _selectedSubjects
                  .map(
                    (id) =>
                        _masters!.subjects
                            .where((s) => s.id == id)
                            .firstOrNull
                            ?.name ??
                        id,
                  )
                  .join(', '),
            ),
          if (_selectedExams.isNotEmpty)
            _ReviewItem(
              icon: Icons.emoji_events_outlined,
              label: 'Competitive Exams',
              value: _selectedExams
                  .map(
                    (id) =>
                        _masters!.competitiveExams
                            .where((e) => e.id == id)
                            .firstOrNull
                            ?.name ??
                        id,
                  )
                  .join(', '),
            ),
          if (_targetYear != null)
            _ReviewItem(
              icon: Icons.calendar_today_outlined,
              label: 'Target Year',
              value: _targetYear.toString(),
            ),

          const SizedBox(height: 32),

          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(
                context,
              ).colorScheme.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.info_outline,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'You can always update this information from your profile settings.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomButtons(ThemeData theme, ColorScheme colorScheme) {
    final isFirstStep = _currentStep == 0;
    final isLastStep = _currentStep == _totalSteps - 1;

    // Validation for next button
    bool canProceed = true;
    if (_currentStep == 0) {
      canProceed = _selectedBoard != null && _selectedClass != null;
    } else if (_needsStreamSelection &&
        _currentStep == 1 &&
        _selectedStream == null) {
      canProceed = false;
    }

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        children: [
          if (isFirstStep)
            TextButton(
              onPressed: _handleRemindLater,
              child: const Text('Remind me later'),
            )
          else
            TextButton.icon(
              onPressed: _prevStep,
              icon: const Icon(Icons.arrow_back),
              label: const Text('Back'),
            ),
          const Spacer(),
          FilledButton(
            onPressed: canProceed ? _nextStep : null,
            child: _isSaving
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(isLastStep ? 'Save Profile' : 'Continue'),
                      if (!isLastStep) ...[
                        const SizedBox(width: 8),
                        const Icon(Icons.arrow_forward, size: 18),
                      ],
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Helper Widgets
// ─────────────────────────────────────────────────────────────────────────────

class _SelectableChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _SelectableChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? colorScheme.primary : colorScheme.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected
                ? colorScheme.primary
                : colorScheme.onSurface.withValues(alpha: 0.2),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? colorScheme.onPrimary : colorScheme.onSurface,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
      ),
    );
  }
}

class _StreamCard extends StatelessWidget {
  final String title;
  final String description;
  final bool isSelected;
  final VoidCallback onTap;

  const _StreamCard({
    required this.title,
    required this.description,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected
              ? colorScheme.primary.withValues(alpha: 0.1)
              : colorScheme.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected
                ? colorScheme.primary
                : colorScheme.onSurface.withValues(alpha: 0.2),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: isSelected
                          ? colorScheme.primary
                          : colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    description,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurface.withValues(alpha: 0.7),
                    ),
                  ),
                ],
              ),
            ),
            if (isSelected)
              Icon(Icons.check_circle, color: colorScheme.primary),
          ],
        ),
      ),
    );
  }
}

class _ReviewItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _ReviewItem({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: Theme.of(
                      context,
                    ).colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w500),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
