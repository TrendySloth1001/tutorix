import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import '../../../core/theme/design_tokens.dart';
import '../../../shared/widgets/app_alert.dart';
import '../../../shared/widgets/app_shimmer.dart';
import '../models/coaching_address.dart';
import '../models/coaching_masters.dart';
import '../models/coaching_model.dart';
import '../services/coaching_onboarding_service.dart';

/// Multi-step coaching onboarding flow
/// Creates a coaching with all details: profile, address, branches
class CoachingOnboardingScreen extends StatefulWidget {
  final VoidCallback onComplete;
  final CoachingModel? existingCoaching;
  final int initialStep;

  const CoachingOnboardingScreen({
    super.key,
    required this.onComplete,
    this.existingCoaching,
    this.initialStep = 0,
  });

  /// Determine the resume step based on coaching data
  static int getResumeStep(CoachingModel coaching) {
    // Step 0: Basic info (name, category) - always done if coaching exists
    // Step 1: Details (tagline, contact, etc.)
    // Step 2: Address
    // Step 3: Review

    // If no category, start from step 0
    if (coaching.category == null || coaching.category!.isEmpty) {
      return 0;
    }

    // If no contact info, start from step 1
    if (coaching.contactPhone == null || coaching.contactPhone!.isEmpty) {
      return 1;
    }

    // If no address, start from step 2
    if (coaching.address == null) {
      return 2;
    }

    // Otherwise go to review
    return 3;
  }

  @override
  State<CoachingOnboardingScreen> createState() =>
      _CoachingOnboardingScreenState();
}

class _CoachingOnboardingScreenState extends State<CoachingOnboardingScreen> {
  final _service = CoachingOnboardingService();
  late final PageController _pageController;

  // Controllers
  final _nameController = TextEditingController();
  final _taglineController = TextEditingController();
  final _aboutController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _whatsappController = TextEditingController();
  final _websiteController = TextEditingController();
  final _addressLine1Controller = TextEditingController();
  final _addressLine2Controller = TextEditingController();
  final _landmarkController = TextEditingController();
  final _cityController = TextEditingController();
  final _pincodeController = TextEditingController();

  CoachingMasters? _masters;
  CoachingModel? _coaching;
  bool _isLoading = true;
  bool _isSaving = false;
  late int _currentStep;

  // Form data
  String? _selectedCategory;
  String? _selectedState;
  final Set<String> _selectedSubjects = {};
  final Set<String> _selectedWorkingDays = {};
  String? _openingTime;
  String? _closingTime;
  double? _latitude;
  double? _longitude;
  bool _fetchingLocation = false;
  int? _foundedYear;

  // Branches
  final List<CoachingBranch> _branches = [];

  @override
  void initState() {
    super.initState();
    _currentStep = widget.initialStep;
    _pageController = PageController(initialPage: widget.initialStep);
    _loadMasters();
    _initFromExisting();
  }

  void _initFromExisting() {
    if (widget.existingCoaching != null) {
      final c = widget.existingCoaching!;
      _coaching = c;
      _nameController.text = c.name;
      _taglineController.text = c.tagline ?? '';
      _aboutController.text = c.aboutUs ?? '';
      _emailController.text = c.contactEmail ?? '';
      _phoneController.text = c.contactPhone ?? '';
      _whatsappController.text = c.whatsappPhone ?? '';
      _websiteController.text = c.websiteUrl ?? '';
      _selectedCategory = c.category;
      _selectedSubjects.addAll(c.subjects);
      _foundedYear = c.foundedYear;

      if (c.address != null) {
        _addressLine1Controller.text = c.address!.addressLine1;
        _addressLine2Controller.text = c.address!.addressLine2 ?? '';
        _landmarkController.text = c.address!.landmark ?? '';
        _cityController.text = c.address!.city;
        _selectedState = c.address!.state;
        _pincodeController.text = c.address!.pincode;
        _latitude = c.address!.latitude;
        _longitude = c.address!.longitude;
        _openingTime = c.address!.openingTime;
        _closingTime = c.address!.closingTime;
        _selectedWorkingDays.addAll(c.address!.workingDays);
      }

      _branches.addAll(c.branches);
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    _nameController.dispose();
    _taglineController.dispose();
    _aboutController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _whatsappController.dispose();
    _websiteController.dispose();
    _addressLine1Controller.dispose();
    _addressLine2Controller.dispose();
    _landmarkController.dispose();
    _cityController.dispose();
    _pincodeController.dispose();
    super.dispose();
  }

  Future<void> _loadMasters() async {
    try {
      final masters = await _service.getMasters();
      setState(() {
        _masters = masters;
        _isLoading = false;
        // Default working days
        _selectedWorkingDays.addAll(['MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT']);
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  int get _totalSteps => 4; // Basic Info, Details, Address, Review

  void _nextStep() async {
    // Validate current step and save if needed
    if (_currentStep == 0) {
      if (_nameController.text.trim().isEmpty) {
        _showError('Please enter your coaching name');
        return;
      }
      if (_selectedCategory == null) {
        _showError('Please select a category');
        return;
      }
      // Create coaching if not exists
      if (_coaching == null) {
        setState(() => _isSaving = true);
        try {
          final coaching = await _service.createCoaching(
            name: _nameController.text.trim(),
          );
          setState(() => _coaching = coaching);
        } catch (e) {
          _showError('Failed to create coaching');
          setState(() => _isSaving = false);
          return;
        }
        setState(() => _isSaving = false);
      }
    }

    if (_currentStep == 1) {
      // Save profile details
      setState(() => _isSaving = true);
      try {
        await _service.updateProfile(
          coachingId: _coaching!.id,
          tagline: _taglineController.text.trim().isEmpty
              ? null
              : _taglineController.text.trim(),
          aboutUs: _aboutController.text.trim().isEmpty
              ? null
              : _aboutController.text.trim(),
          contactEmail: _emailController.text.trim().isEmpty
              ? null
              : _emailController.text.trim(),
          contactPhone: _phoneController.text.trim().isEmpty
              ? null
              : _phoneController.text.trim(),
          whatsappPhone: _whatsappController.text.trim().isEmpty
              ? null
              : _whatsappController.text.trim(),
          websiteUrl: _websiteController.text.trim().isEmpty
              ? null
              : _websiteController.text.trim(),
          category: _selectedCategory,
          subjects: _selectedSubjects.toList(),
          foundedYear: _foundedYear,
        );
      } catch (e) {
        _showError('Failed to save details');
        setState(() => _isSaving = false);
        return;
      }
      setState(() => _isSaving = false);
    }

    if (_currentStep == 2) {
      // Validate address
      if (_addressLine1Controller.text.trim().isEmpty) {
        _showError('Please enter your address');
        return;
      }
      if (_cityController.text.trim().isEmpty) {
        _showError('Please enter your city');
        return;
      }
      if (_selectedState == null) {
        _showError('Please select your state');
        return;
      }
      if (_pincodeController.text.trim().isEmpty) {
        _showError('Please enter your pincode');
        return;
      }

      // Save address
      setState(() => _isSaving = true);
      try {
        await _service.setAddress(
          coachingId: _coaching!.id,
          addressLine1: _addressLine1Controller.text.trim(),
          addressLine2: _addressLine2Controller.text.trim().isEmpty
              ? null
              : _addressLine2Controller.text.trim(),
          landmark: _landmarkController.text.trim().isEmpty
              ? null
              : _landmarkController.text.trim(),
          city: _cityController.text.trim(),
          state: _selectedState!,
          pincode: _pincodeController.text.trim(),
          latitude: _latitude,
          longitude: _longitude,
          openingTime: _openingTime,
          closingTime: _closingTime,
          workingDays: _selectedWorkingDays.toList(),
        );
      } catch (e) {
        _showError('Failed to save address');
        setState(() => _isSaving = false);
        return;
      }
      setState(() => _isSaving = false);
    }

    if (_currentStep < _totalSteps - 1) {
      setState(() => _currentStep++);
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      _completeOnboarding();
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

  Future<void> _completeOnboarding() async {
    setState(() => _isSaving = true);
    try {
      await _service.completeOnboarding(_coaching!.id);
      widget.onComplete();
    } catch (e) {
      _showError('Failed to complete setup');
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    AppAlert.error(context, message);
  }

  Future<void> _fetchCurrentLocation() async {
    setState(() => _fetchingLocation = true);

    try {
      // First check if location services are enabled
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (mounted) {
          _showLocationServiceDialog();
        }
        setState(() => _fetchingLocation = false);
        return;
      }

      // Check permissions
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          _showError('Location permission denied. Please try again.');
          setState(() => _fetchingLocation = false);
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        if (mounted) {
          _showLocationSettingsDialog();
        }
        setState(() => _fetchingLocation = false);
        return;
      }

      // Get position
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 15),
        ),
      );

      setState(() {
        _latitude = position.latitude;
        _longitude = position.longitude;
        _fetchingLocation = false;
      });

      if (mounted) {
        AppAlert.success(context, 'Location captured successfully!');
      }
    } catch (e) {
      if (mounted) {
        _showError('Failed to get location. Please try again.');
      }
      setState(() => _fetchingLocation = false);
    }
  }

  void _showLocationSettingsDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Location Permission Required'),
        content: const Text(
          'Location permission is permanently denied. Please enable it in your device settings to capture your coaching location.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(context);
              Geolocator.openAppSettings();
            },
            child: const Text('Open Settings'),
          ),
        ],
      ),
    );
  }

  void _showLocationServiceDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Enable Location'),
        content: const Text(
          'Location services are turned off. Please enable GPS/Location to capture your coaching\'s exact location.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(context);
              Geolocator.openLocationSettings();
            },
            child: const Text('Enable Location'),
          ),
        ],
      ),
    );
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
                children: [
                  _buildBasicInfoStep(),
                  _buildDetailsStep(),
                  _buildAddressStep(),
                  _buildReviewStep(),
                ],
              ),
            ),
            _buildBottomButtons(theme, colorScheme),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(ThemeData theme) {
    final titles = [
      "Let's set up your coaching",
      'Add more details',
      'Where are you located?',
      'All set! Review your info',
    ];
    final subtitles = [
      'Start with the basics to get your coaching online',
      'Help students find and connect with you',
      'Students can find you on the map',
      'Make sure everything looks perfect',
    ];

    return Padding(
      padding: const EdgeInsets.all(Spacing.sp24),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(Spacing.sp12),
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(Radii.md),
            ),
            child: Icon(
              _currentStep == 0
                  ? Icons.rocket_launch_outlined
                  : _currentStep == 1
                  ? Icons.edit_note_outlined
                  : _currentStep == 2
                  ? Icons.location_on_outlined
                  : Icons.check_circle_outline,
              color: theme.colorScheme.primary,
              size: 28,
            ),
          ),
          const SizedBox(width: Spacing.sp16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  titles[_currentStep],
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: Spacing.sp4),
                Text(
                  subtitles[_currentStep],
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProgressIndicator(ColorScheme colorScheme) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: Spacing.sp24),
      child: Row(
        children: List.generate(_totalSteps, (index) {
          final isActive = index <= _currentStep;
          return Expanded(
            child: Container(
              height: 4,
              margin: EdgeInsets.only(
                right: index < _totalSteps - 1 ? Spacing.sp4 : 0,
              ),
              decoration: BoxDecoration(
                color: isActive
                    ? colorScheme.primary
                    : colorScheme.primary.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(Radii.sm),
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildBasicInfoStep() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(Spacing.sp24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionTitle('Coaching Name', Icons.school_outlined),
          const SizedBox(height: Spacing.sp12),
          TextField(
            controller: _nameController,
            decoration: InputDecoration(
              hintText: 'e.g., Excel Coaching Classes',
              prefixIcon: const Icon(Icons.business_outlined),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(Radii.md),
              ),
            ),
            textCapitalization: TextCapitalization.words,
          ),
          const SizedBox(height: Spacing.sp8),
          Text(
            'Choose a name that represents your institution',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(
                context,
              ).colorScheme.onSurface.withValues(alpha: 0.6),
            ),
          ),
          const SizedBox(height: Spacing.sp32),
          _buildSectionTitle(
            'What type of institution?',
            Icons.category_outlined,
          ),
          const SizedBox(height: Spacing.sp12),
          _buildCategorySelector(),
          const SizedBox(height: Spacing.sp32),
          _buildSectionTitle('Subjects You Teach', Icons.book_outlined),
          const SizedBox(height: Spacing.sp8),
          Text(
            'Select all that apply',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(
                context,
              ).colorScheme.onSurface.withValues(alpha: 0.6),
            ),
          ),
          const SizedBox(height: Spacing.sp12),
          _buildSubjectsSelector(),
        ],
      ),
    );
  }

  Widget _buildCategorySelector() {
    if (_masters == null) return const SizedBox();

    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: _masters!.categories.map((category) {
        final isSelected = _selectedCategory == category.id;
        return _CategoryChip(
          label: category.name,
          description: category.description,
          isSelected: isSelected,
          onTap: () => setState(() => _selectedCategory = category.id),
        );
      }).toList(),
    );
  }

  Widget _buildSubjectsSelector() {
    if (_masters == null) return const SizedBox();

    final grouped = _masters!.subjectsByCategory;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: grouped.entries.map((entry) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(
                top: Spacing.sp8,
                bottom: Spacing.sp8,
              ),
              child: Text(
                entry.key,
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: Theme.of(
                    context,
                  ).colorScheme.onSurface.withValues(alpha: 0.6),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: entry.value.map((subject) {
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
        );
      }).toList(),
    );
  }

  Widget _buildDetailsStep() {
    final currentYear = DateTime.now().year;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(Spacing.sp24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionTitle('Tagline', Icons.format_quote_outlined),
          const SizedBox(height: Spacing.sp12),
          TextField(
            controller: _taglineController,
            decoration: InputDecoration(
              hintText: 'e.g., Where Dreams Meet Success',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(Radii.md),
              ),
            ),
            maxLength: 100,
          ),
          const SizedBox(height: Spacing.sp24),
          _buildSectionTitle('About Your Coaching', Icons.info_outline),
          const SizedBox(height: Spacing.sp12),
          TextField(
            controller: _aboutController,
            decoration: InputDecoration(
              hintText: 'Tell students what makes your coaching special...',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(Radii.md),
              ),
            ),
            maxLines: 4,
            maxLength: 500,
          ),
          const SizedBox(height: Spacing.sp24),
          _buildSectionTitle('Founded Year', Icons.calendar_today_outlined),
          const SizedBox(height: Spacing.sp12),
          DropdownButtonFormField<int>(
            initialValue: _foundedYear,
            decoration: InputDecoration(
              hintText: 'Select year',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(Radii.md),
              ),
            ),
            items: List.generate(50, (i) => currentYear - i)
                .map(
                  (year) => DropdownMenuItem(
                    value: year,
                    child: Text(year.toString()),
                  ),
                )
                .toList(),
            onChanged: (value) => setState(() => _foundedYear = value),
          ),
          const SizedBox(height: Spacing.sp24),
          _buildSectionTitle('Contact Details', Icons.contact_phone_outlined),
          const SizedBox(height: Spacing.sp12),
          TextField(
            controller: _emailController,
            decoration: InputDecoration(
              hintText: 'Contact email',
              prefixIcon: const Icon(Icons.email_outlined),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(Radii.md),
              ),
            ),
            keyboardType: TextInputType.emailAddress,
          ),
          const SizedBox(height: Spacing.sp12),
          TextField(
            controller: _phoneController,
            decoration: InputDecoration(
              hintText: 'Phone number',
              prefixIcon: const Icon(Icons.phone_outlined),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(Radii.md),
              ),
            ),
            keyboardType: TextInputType.phone,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          ),
          const SizedBox(height: Spacing.sp12),
          TextField(
            controller: _whatsappController,
            decoration: InputDecoration(
              hintText: 'WhatsApp number',
              prefixIcon: const Icon(Icons.chat_outlined),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(Radii.md),
              ),
            ),
            keyboardType: TextInputType.phone,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          ),
          const SizedBox(height: Spacing.sp12),
          TextField(
            controller: _websiteController,
            decoration: InputDecoration(
              hintText: 'Website (optional)',
              prefixIcon: const Icon(Icons.language_outlined),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(Radii.md),
              ),
            ),
            keyboardType: TextInputType.url,
          ),
        ],
      ),
    );
  }

  Widget _buildAddressStep() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(Spacing.sp24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Location button
          Container(
            padding: const EdgeInsets.all(Spacing.sp16),
            decoration: BoxDecoration(
              color: _latitude != null
                  ? Colors.green.withValues(alpha: 0.1)
                  : Theme.of(
                      context,
                    ).colorScheme.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(Radii.md),
              border: Border.all(
                color: _latitude != null
                    ? Colors.green.withValues(alpha: 0.3)
                    : Theme.of(
                        context,
                      ).colorScheme.primary.withValues(alpha: 0.3),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  _latitude != null
                      ? Icons.check_circle_outlined
                      : Icons.my_location_outlined,
                  color: _latitude != null
                      ? Colors.green
                      : Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: Spacing.sp12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _latitude != null
                            ? 'Location captured'
                            : 'Capture your exact location',
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (_latitude != null)
                        Text(
                          '${_latitude!.toStringAsFixed(6)}, ${_longitude!.toStringAsFixed(6)}',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                    ],
                  ),
                ),
                FilledButton.icon(
                  onPressed: _fetchingLocation ? null : _fetchCurrentLocation,
                  icon: _fetchingLocation
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Icon(
                          _latitude != null ? Icons.refresh : Icons.gps_fixed,
                          size: 18,
                        ),
                  label: Text(_latitude != null ? 'Update' : 'Get Location'),
                ),
              ],
            ),
          ),
          const SizedBox(height: Spacing.sp24),
          _buildSectionTitle('Address', Icons.location_on_outlined),
          const SizedBox(height: Spacing.sp12),
          TextField(
            controller: _addressLine1Controller,
            decoration: InputDecoration(
              hintText: 'Building/Street address',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(Radii.md),
              ),
            ),
          ),
          const SizedBox(height: Spacing.sp12),
          TextField(
            controller: _addressLine2Controller,
            decoration: InputDecoration(
              hintText: 'Area/Locality (optional)',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(Radii.md),
              ),
            ),
          ),
          const SizedBox(height: Spacing.sp12),
          TextField(
            controller: _landmarkController,
            decoration: InputDecoration(
              hintText: 'Landmark (optional)',
              prefixIcon: const Icon(Icons.place_outlined),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(Radii.md),
              ),
            ),
          ),
          const SizedBox(height: Spacing.sp12),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _cityController,
                  decoration: InputDecoration(
                    hintText: 'City',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(Radii.md),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: Spacing.sp12),
              Expanded(
                child: TextField(
                  controller: _pincodeController,
                  decoration: InputDecoration(
                    hintText: 'Pincode',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(Radii.md),
                    ),
                  ),
                  keyboardType: TextInputType.number,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(6),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: Spacing.sp12),
          _buildStateSelector(),
          const SizedBox(height: Spacing.sp24),
          _buildSectionTitle('Working Days', Icons.calendar_month_outlined),
          const SizedBox(height: Spacing.sp12),
          _buildWorkingDaysSelector(),
          const SizedBox(height: Spacing.sp24),
          _buildSectionTitle('Timings', Icons.access_time_outlined),
          const SizedBox(height: Spacing.sp12),
          _buildTimingsPicker(),
          const SizedBox(height: Spacing.sp24),
          // Add branch section
          _buildAddBranchSection(),
        ],
      ),
    );
  }

  Widget _buildStateSelector() {
    if (_masters == null) return const SizedBox();

    return DropdownButtonFormField<String>(
      initialValue: _selectedState,
      decoration: InputDecoration(
        hintText: 'Select State',
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(Radii.md),
        ),
      ),
      items: _masters!.states
          .map(
            (state) =>
                DropdownMenuItem(value: state.id, child: Text(state.name)),
          )
          .toList(),
      onChanged: (value) => setState(() => _selectedState = value),
    );
  }

  Widget _buildWorkingDaysSelector() {
    if (_masters == null) return const SizedBox();

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: _masters!.workingDays.map((day) {
        final isSelected = _selectedWorkingDays.contains(day.id);
        return GestureDetector(
          onTap: () {
            setState(() {
              if (isSelected) {
                _selectedWorkingDays.remove(day.id);
              } else {
                _selectedWorkingDays.add(day.id);
              }
            });
          },
          child: Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: isSelected
                  ? Theme.of(context).colorScheme.primary
                  : Theme.of(context).colorScheme.surface,
              shape: BoxShape.circle,
              border: Border.all(
                color: isSelected
                    ? Theme.of(context).colorScheme.primary
                    : Theme.of(
                        context,
                      ).colorScheme.onSurface.withValues(alpha: 0.3),
              ),
            ),
            alignment: Alignment.center,
            child: Text(
              day.short,
              style: TextStyle(
                color: isSelected
                    ? Theme.of(context).colorScheme.onPrimary
                    : Theme.of(context).colorScheme.onSurface,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildTimingsPicker() {
    return Row(
      children: [
        Expanded(
          child: _TimePickerField(
            label: 'Opening',
            value: _openingTime,
            onChanged: (time) => setState(() => _openingTime = time),
          ),
        ),
        const SizedBox(width: Spacing.sp12),
        Expanded(
          child: _TimePickerField(
            label: 'Closing',
            value: _closingTime,
            onChanged: (time) => setState(() => _closingTime = time),
          ),
        ),
      ],
    );
  }

  Widget _buildAddBranchSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            _buildSectionTitle('Branches', Icons.business_outlined),
            const Spacer(),
            TextButton.icon(
              onPressed: _showAddBranchDialog,
              icon: const Icon(Icons.add),
              label: const Text('Add Branch'),
            ),
          ],
        ),
        if (_branches.isEmpty)
          Container(
            padding: const EdgeInsets.all(Spacing.sp16),
            decoration: BoxDecoration(
              color: Theme.of(
                context,
              ).colorScheme.tertiary.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(Radii.md),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.info_outline,
                  color: Theme.of(context).colorScheme.primary,
                  size: 20,
                ),
                const SizedBox(width: Spacing.sp12),
                Expanded(
                  child: Text(
                    'Have multiple locations? Add branches to let students find you everywhere.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
              ],
            ),
          )
        else
          ...(_branches.map(
            (branch) => _BranchCard(
              branch: branch,
              onDelete: () {
                setState(() => _branches.remove(branch));
                // Delete from server if it has ID
                if (_coaching != null) {
                  _service.deleteBranch(_coaching!.id, branch.id);
                }
              },
            ),
          )),
      ],
    );
  }

  void _showAddBranchDialog() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _AddBranchSheet(
        masters: _masters!,
        onAdd: (branch) async {
          if (_coaching != null) {
            try {
              final newBranch = await _service.addBranch(
                coachingId: _coaching!.id,
                name: branch['name'],
                addressLine1: branch['addressLine1'],
                addressLine2: branch['addressLine2'],
                landmark: branch['landmark'],
                city: branch['city'],
                state: branch['state'],
                pincode: branch['pincode'],
                contactPhone: branch['contactPhone'],
              );
              setState(() => _branches.add(newBranch));
            } catch (e) {
              _showError('Failed to add branch');
            }
          }
        },
      ),
    );
  }

  Widget _buildReviewStep() {
    final stateName = _masters?.states
        .where((s) => s.id == _selectedState)
        .firstOrNull
        ?.name;
    final categoryName = _masters?.categories
        .where((c) => c.id == _selectedCategory)
        .firstOrNull
        ?.name;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(Spacing.sp24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(Spacing.sp20),
            decoration: BoxDecoration(
              color: Theme.of(
                context,
              ).colorScheme.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(Radii.lg),
            ),
            child: Column(
              children: [
                Icon(
                  Icons.celebration_outlined,
                  size: 48,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(height: Spacing.sp12),
                Text(
                  _nameController.text,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                if (_taglineController.text.isNotEmpty) ...[
                  const SizedBox(height: Spacing.sp4),
                  Text(
                    _taglineController.text,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontStyle: FontStyle.italic,
                      color: Theme.of(
                        context,
                      ).colorScheme.onSurface.withValues(alpha: 0.7),
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: Spacing.sp24),
          _ReviewItem(
            icon: Icons.category_outlined,
            label: 'Type',
            value: categoryName ?? 'Not specified',
          ),
          if (_selectedSubjects.isNotEmpty)
            _ReviewItem(
              icon: Icons.book_outlined,
              label: 'Subjects',
              value: _selectedSubjects
                  .map(
                    (id) =>
                        _masters?.subjects
                            .where((s) => s.id == id)
                            .firstOrNull
                            ?.name ??
                        id,
                  )
                  .join(', '),
            ),
          _ReviewItem(
            icon: Icons.location_on_outlined,
            label: 'Address',
            value:
                '${_addressLine1Controller.text}, ${_cityController.text}, ${stateName ?? ''} - ${_pincodeController.text}',
          ),
          if (_latitude != null)
            _ReviewItem(
              icon: Icons.gps_fixed,
              label: 'GPS Location',
              value: 'Captured',
            ),
          if (_phoneController.text.isNotEmpty)
            _ReviewItem(
              icon: Icons.phone_outlined,
              label: 'Phone',
              value: _phoneController.text,
            ),
          if (_branches.isNotEmpty)
            _ReviewItem(
              icon: Icons.business_outlined,
              label: 'Branches',
              value: '${_branches.length} additional location(s)',
            ),
          const SizedBox(height: Spacing.sp24),
          Container(
            padding: const EdgeInsets.all(Spacing.sp16),
            decoration: BoxDecoration(
              color: Colors.green.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(Radii.md),
            ),
            child: Row(
              children: [
                const Icon(Icons.verified_outlined, color: Colors.green),
                const SizedBox(width: Spacing.sp12),
                Expanded(
                  child: Text(
                    "You're all set! Click 'Launch' to make your coaching live.",
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 20, color: Theme.of(context).colorScheme.primary),
        const SizedBox(width: Spacing.sp8),
        Text(
          title,
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
        ),
      ],
    );
  }

  Widget _buildBottomButtons(ThemeData theme, ColorScheme colorScheme) {
    final isLastStep = _currentStep == _totalSteps - 1;

    return Container(
      padding: const EdgeInsets.all(Spacing.sp24),
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
          if (_currentStep > 0)
            TextButton.icon(
              onPressed: _prevStep,
              icon: const Icon(Icons.arrow_back),
              label: const Text('Back'),
            )
          else
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
          const Spacer(),
          FilledButton(
            onPressed: _isSaving ? null : _nextStep,
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
                      Text(isLastStep ? 'Launch Coaching' : 'Continue'),
                      if (!isLastStep) ...[
                        const SizedBox(width: Spacing.sp8),
                        const Icon(Icons.arrow_forward, size: 18),
                      ] else ...[
                        const SizedBox(width: Spacing.sp8),
                        const Icon(Icons.rocket_launch, size: 18),
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
        padding: const EdgeInsets.symmetric(
          horizontal: Spacing.sp14,
          vertical: Spacing.sp8,
        ),
        decoration: BoxDecoration(
          color: isSelected ? colorScheme.primary : colorScheme.surface,
          borderRadius: BorderRadius.circular(Radii.lg),
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
            fontSize: FontSize.body,
          ),
        ),
      ),
    );
  }
}

class _CategoryChip extends StatelessWidget {
  final String label;
  final String description;
  final bool isSelected;
  final VoidCallback onTap;

  const _CategoryChip({
    required this.label,
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
        padding: const EdgeInsets.symmetric(
          horizontal: Spacing.sp16,
          vertical: Spacing.sp12,
        ),
        decoration: BoxDecoration(
          color: isSelected
              ? colorScheme.primary.withValues(alpha: 0.1)
              : colorScheme.surface,
          borderRadius: BorderRadius.circular(Radii.md),
          border: Border.all(
            color: isSelected
                ? colorScheme.primary
                : colorScheme.onSurface.withValues(alpha: 0.2),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isSelected)
              Padding(
                padding: const EdgeInsets.only(right: Spacing.sp8),
                child: Icon(
                  Icons.check_circle,
                  color: colorScheme.primary,
                  size: 18,
                ),
              ),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? colorScheme.primary : colorScheme.onSurface,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TimePickerField extends StatelessWidget {
  final String label;
  final String? value;
  final ValueChanged<String> onChanged;

  const _TimePickerField({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () async {
        final time = await showTimePicker(
          context: context,
          initialTime: TimeOfDay.now(),
        );
        if (time != null) {
          final formatted =
              '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
          onChanged(formatted);
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: Spacing.sp16,
          vertical: Spacing.sp16,
        ),
        decoration: BoxDecoration(
          border: Border.all(
            color: Theme.of(
              context,
            ).colorScheme.onSurface.withValues(alpha: 0.3),
          ),
          borderRadius: BorderRadius.circular(Radii.md),
        ),
        child: Row(
          children: [
            Icon(
              Icons.access_time,
              size: 20,
              color: Theme.of(
                context,
              ).colorScheme.onSurface.withValues(alpha: 0.6),
            ),
            const SizedBox(width: Spacing.sp12),
            Text(
              value ?? label,
              style: TextStyle(
                color: value != null
                    ? Theme.of(context).colorScheme.onSurface
                    : Theme.of(
                        context,
                      ).colorScheme.onSurface.withValues(alpha: 0.5),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BranchCard extends StatelessWidget {
  final CoachingBranch branch;
  final VoidCallback onDelete;

  const _BranchCard({required this.branch, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: Spacing.sp8),
      padding: const EdgeInsets.all(Spacing.sp12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.tertiary.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(Radii.md),
      ),
      child: Row(
        children: [
          Icon(
            Icons.location_on_outlined,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(width: Spacing.sp12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  branch.name,
                  style: Theme.of(
                    context,
                  ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
                ),
                Text(
                  branch.fullAddress,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, size: 20),
            onPressed: onDelete,
            color: Theme.of(context).colorScheme.error,
          ),
        ],
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
      padding: const EdgeInsets.only(bottom: Spacing.sp16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: Spacing.sp12),
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
                const SizedBox(height: Spacing.sp2),
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

class _AddBranchSheet extends StatefulWidget {
  final CoachingMasters masters;
  final Function(Map<String, dynamic>) onAdd;

  const _AddBranchSheet({required this.masters, required this.onAdd});

  @override
  State<_AddBranchSheet> createState() => _AddBranchSheetState();
}

class _AddBranchSheetState extends State<_AddBranchSheet> {
  final _nameController = TextEditingController();
  final _addressController = TextEditingController();
  final _cityController = TextEditingController();
  final _pincodeController = TextEditingController();
  final _phoneController = TextEditingController();
  String? _selectedState;

  @override
  void dispose() {
    _nameController.dispose();
    _addressController.dispose();
    _cityController.dispose();
    _pincodeController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(Radii.lg),
        ),
      ),
      padding: EdgeInsets.only(
        bottom:
            MediaQuery.of(context).viewInsets.bottom +
            MediaQuery.of(context).viewPadding.bottom,
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(Spacing.sp24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Theme.of(
                    context,
                  ).colorScheme.onSurface.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(Radii.sm),
                ),
              ),
            ),
            const SizedBox(height: Spacing.sp20),
            Text(
              'Add Branch',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: Spacing.sp20),
            TextField(
              controller: _nameController,
              decoration: InputDecoration(
                labelText: 'Branch Name',
                hintText: 'e.g., South Campus',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(Radii.md),
                ),
              ),
            ),
            const SizedBox(height: Spacing.sp12),
            TextField(
              controller: _addressController,
              decoration: InputDecoration(
                labelText: 'Address',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(Radii.md),
                ),
              ),
            ),
            const SizedBox(height: Spacing.sp12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _cityController,
                    decoration: InputDecoration(
                      labelText: 'City',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(Radii.md),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: Spacing.sp12),
                Expanded(
                  child: TextField(
                    controller: _pincodeController,
                    decoration: InputDecoration(
                      labelText: 'Pincode',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(Radii.md),
                      ),
                    ),
                    keyboardType: TextInputType.number,
                  ),
                ),
              ],
            ),
            const SizedBox(height: Spacing.sp12),
            DropdownButtonFormField<String>(
              initialValue: _selectedState,
              decoration: InputDecoration(
                labelText: 'State',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(Radii.md),
                ),
              ),
              items: widget.masters.states
                  .map(
                    (state) => DropdownMenuItem(
                      value: state.id,
                      child: Text(state.name),
                    ),
                  )
                  .toList(),
              onChanged: (value) => setState(() => _selectedState = value),
            ),
            const SizedBox(height: Spacing.sp12),
            TextField(
              controller: _phoneController,
              decoration: InputDecoration(
                labelText: 'Branch Phone (optional)',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(Radii.md),
                ),
              ),
              keyboardType: TextInputType.phone,
            ),
            const SizedBox(height: Spacing.sp24),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () {
                  if (_nameController.text.isEmpty ||
                      _addressController.text.isEmpty ||
                      _cityController.text.isEmpty ||
                      _selectedState == null ||
                      _pincodeController.text.isEmpty) {
                    AppAlert.warning(
                      context,
                      'Please fill all required fields',
                    );
                    return;
                  }

                  widget.onAdd({
                    'name': _nameController.text,
                    'addressLine1': _addressController.text,
                    'city': _cityController.text,
                    'state': _selectedState,
                    'pincode': _pincodeController.text,
                    'contactPhone': _phoneController.text.isEmpty
                        ? null
                        : _phoneController.text,
                  });
                  Navigator.pop(context);
                },
                child: const Text('Add Branch'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
