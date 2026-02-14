import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../../shared/models/user_model.dart';
import '../models/coaching_model.dart';
import '../services/coaching_service.dart';
import '../services/coaching_onboarding_service.dart';
import 'coaching_onboarding_screen.dart';

/// Comprehensive coaching profile with all details and edit options
class CoachingProfileScreen extends StatefulWidget {
  final CoachingModel coaching;
  final UserModel user;
  final ValueChanged<CoachingModel>? onCoachingUpdated;
  final VoidCallback? onBack;

  const CoachingProfileScreen({
    super.key,
    required this.coaching,
    required this.user,
    this.onCoachingUpdated,
    this.onBack,
  });

  @override
  State<CoachingProfileScreen> createState() => _CoachingProfileScreenState();
}

class _CoachingProfileScreenState extends State<CoachingProfileScreen> {
  final CoachingService _coachingService = CoachingService();
  final CoachingOnboardingService _onboardingService =
      CoachingOnboardingService();
  final ImagePicker _picker = ImagePicker();
  bool _isUploadingLogo = false;
  bool _isLoading = false;

  late CoachingModel _coaching;

  @override
  void initState() {
    super.initState();
    _coaching = widget.coaching;
    _refreshCoaching();
  }

  bool get _isOwner => _coaching.ownerId == widget.user.id;

  Future<void> _refreshCoaching() async {
    try {
      final updated = await _coachingService.getCoachingById(_coaching.id);
      if (updated != null && mounted) {
        setState(() => _coaching = updated);
        widget.onCoachingUpdated?.call(updated);
      }
    } catch (_) {}
  }

  // ── Edit Methods ───────────────────────────────────────────────────────

  Future<void> _editField({
    required String title,
    required String currentValue,
    required String hint,
    int maxLines = 1,
    int? maxLength,
    TextInputType? keyboardType,
    required Future<void> Function(String value) onSave,
  }) async {
    final controller = TextEditingController(text: currentValue);
    final result = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        final theme = Theme.of(ctx);
        return Padding(
          padding: EdgeInsets.fromLTRB(
            20,
            14,
            20,
            MediaQuery.of(ctx).viewInsets.bottom + 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildGrabHandle(theme),
              const SizedBox(height: 16),
              Text(
                title,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: controller,
                autofocus: true,
                maxLines: maxLines,
                maxLength: maxLength,
                keyboardType: keyboardType,
                decoration: InputDecoration(
                  hintText: hint,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(ctx),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      onPressed: () =>
                          Navigator.pop(ctx, controller.text.trim()),
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: const Text('Save'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );

    if (result != null && result != currentValue) {
      setState(() => _isLoading = true);
      try {
        await onSave(result);
        await _refreshCoaching();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Updated successfully'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Update failed: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      } finally {
        if (mounted) setState(() => _isLoading = false);
      }
    }
  }

  void _editName() => _editField(
        title: 'Edit Name',
        currentValue: _coaching.name,
        hint: 'Coaching name',
        onSave: (v) => _coachingService.updateCoaching(
          id: _coaching.id,
          name: v,
        ),
      );

  void _editTagline() => _editField(
        title: 'Edit Tagline',
        currentValue: _coaching.tagline ?? '',
        hint: 'A short catchy tagline...',
        maxLength: 100,
        onSave: (v) => _onboardingService.updateProfile(
          coachingId: _coaching.id,
          tagline: v.isEmpty ? null : v,
        ),
      );

  void _editAbout() => _editField(
        title: 'About Your Coaching',
        currentValue: _coaching.aboutUs ?? '',
        hint: 'Tell students what makes you special...',
        maxLines: 5,
        maxLength: 500,
        onSave: (v) => _onboardingService.updateProfile(
          coachingId: _coaching.id,
          aboutUs: v.isEmpty ? null : v,
        ),
      );

  void _editEmail() => _editField(
        title: 'Contact Email',
        currentValue: _coaching.contactEmail ?? '',
        hint: 'coaching@example.com',
        keyboardType: TextInputType.emailAddress,
        onSave: (v) => _onboardingService.updateProfile(
          coachingId: _coaching.id,
          contactEmail: v.isEmpty ? null : v,
        ),
      );

  void _editPhone() => _editField(
        title: 'Contact Phone',
        currentValue: _coaching.contactPhone ?? '',
        hint: '9876543210',
        keyboardType: TextInputType.phone,
        onSave: (v) => _onboardingService.updateProfile(
          coachingId: _coaching.id,
          contactPhone: v.isEmpty ? null : v,
        ),
      );

  void _editWhatsApp() => _editField(
        title: 'WhatsApp Number',
        currentValue: _coaching.whatsappPhone ?? '',
        hint: '9876543210',
        keyboardType: TextInputType.phone,
        onSave: (v) => _onboardingService.updateProfile(
          coachingId: _coaching.id,
          whatsappPhone: v.isEmpty ? null : v,
        ),
      );

  void _editWebsite() => _editField(
        title: 'Website URL',
        currentValue: _coaching.websiteUrl ?? '',
        hint: 'https://yourcoaching.com',
        keyboardType: TextInputType.url,
        onSave: (v) => _onboardingService.updateProfile(
          coachingId: _coaching.id,
          websiteUrl: v.isEmpty ? null : v,
        ),
      );

  Future<void> _changeLogo() async {
    final source = await _showImageSourceSheet();
    if (source == null) return;
    final picked = await _picker.pickImage(
      source: source,
      maxWidth: 512,
      maxHeight: 512,
      imageQuality: 85,
    );
    if (picked == null) return;

    setState(() => _isUploadingLogo = true);
    try {
      final url = await _coachingService.uploadLogo(picked.path);
      await _coachingService.updateCoaching(id: _coaching.id, logo: url);
      await _refreshCoaching();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Upload failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isUploadingLogo = false);
    }
  }

  Future<ImageSource?> _showImageSourceSheet() {
    final theme = Theme.of(context);
    return showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: theme.colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildGrabHandle(theme),
              const SizedBox(height: 16),
              Text(
                'Change Logo',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              ListTile(
                leading: Icon(Icons.camera_alt_rounded,
                    color: theme.colorScheme.primary),
                title: const Text('Take Photo'),
                onTap: () => Navigator.pop(ctx, ImageSource.camera),
              ),
              ListTile(
                leading: Icon(Icons.photo_library_rounded,
                    color: theme.colorScheme.primary),
                title: const Text('Choose from Gallery'),
                onTap: () => Navigator.pop(ctx, ImageSource.gallery),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  void _continueOnboarding() async {
    final resumeStep = CoachingOnboardingScreen.getResumeStep(_coaching);
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CoachingOnboardingScreen(
          existingCoaching: _coaching,
          initialStep: resumeStep,
          onComplete: () {
            Navigator.pop(context);
            _refreshCoaching();
          },
        ),
      ),
    );
  }

  void _editAddress() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CoachingOnboardingScreen(
          existingCoaching: _coaching,
          initialStep: 2, // Address step
          onComplete: () {
            Navigator.pop(context);
            _refreshCoaching();
          },
        ),
      ),
    );
  }

  // ── Build ──────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      body: Stack(
        children: [
          RefreshIndicator(
            onRefresh: _refreshCoaching,
            child: ListView(
              padding: EdgeInsets.fromLTRB(
                20,
                MediaQuery.of(context).padding.top + 12,
                20,
                100,
              ),
              children: [
                // ── Header ──
                _buildHeader(theme),

                const SizedBox(height: 24),

                // ── Hero Section ──
                _buildHeroSection(theme),

                // ── Incomplete Onboarding Banner ──
                if (_isOwner && !_coaching.onboardingComplete) ...[
                  const SizedBox(height: 20),
                  _buildOnboardingBanner(theme),
                ],

                const SizedBox(height: 28),

                // ── Quick Stats ──
                _buildQuickStats(theme),

                const SizedBox(height: 28),

                // ── About Section ──
                if (_coaching.aboutUs != null ||
                    _coaching.onboardingComplete ||
                    _isOwner) ...[
                  _buildAboutSection(theme),
                  const SizedBox(height: 24),
                ],

                // ── Contact Section ──
                _buildContactSection(theme),

                const SizedBox(height: 24),

                // ── Address Section ──
                if (_coaching.address != null || _isOwner) ...[
                  _buildAddressSection(theme),
                  const SizedBox(height: 24),
                ],

                // ── Timing Section ──
                if (_coaching.address != null) ...[
                  _buildTimingSection(theme),
                  const SizedBox(height: 24),
                ],

                // ── Branches Section ──
                if (_coaching.branches.isNotEmpty) ...[
                  _buildBranchesSection(theme),
                  const SizedBox(height: 24),
                ],

                // ── General Info ──
                _buildGeneralInfo(theme),

                const SizedBox(height: 40),
              ],
            ),
          ),
          if (_isLoading)
            Container(
              color: Colors.black.withValues(alpha: 0.3),
              child: const Center(child: CircularProgressIndicator()),
            ),
        ],
      ),
    );
  }

  Widget _buildHeader(ThemeData theme) {
    return Row(
      children: [
        if (widget.onBack != null)
          GestureDetector(
            onTap: widget.onBack,
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                Icons.arrow_back_rounded,
                size: 20,
                color: theme.colorScheme.primary,
              ),
            ),
          ),
        const Spacer(),
        if (_coaching.isVerified)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.blue.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.verified, size: 16, color: Colors.blue),
                SizedBox(width: 4),
                Text(
                  'Verified',
                  style: TextStyle(
                    color: Colors.blue,
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildHeroSection(ThemeData theme) {
    return Column(
      children: [
        // Logo
        GestureDetector(
          onTap: _isOwner && !_isUploadingLogo ? _changeLogo : null,
          child: Stack(
            children: [
              Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: theme.colorScheme.primary.withValues(alpha: 0.1),
                    width: 2,
                  ),
                ),
                child: _coaching.logo != null
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(22),
                        child: Image.network(
                          _coaching.logo!,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Icon(
                            Icons.school_rounded,
                            size: 44,
                            color:
                                theme.colorScheme.primary.withValues(alpha: 0.3),
                          ),
                        ),
                      )
                    : Icon(
                        Icons.school_rounded,
                        size: 44,
                        color: theme.colorScheme.primary.withValues(alpha: 0.3),
                      ),
              ),
              if (_isUploadingLogo)
                Positioned.fill(
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.4),
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: const Center(
                      child: SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2.5,
                        ),
                      ),
                    ),
                  ),
                ),
              if (_isOwner && !_isUploadingLogo)
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: theme.colorScheme.surface,
                        width: 2,
                      ),
                    ),
                    child: Icon(
                      Icons.camera_alt_rounded,
                      size: 14,
                      color: theme.colorScheme.onPrimary,
                    ),
                  ),
                ),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // Name
        GestureDetector(
          onTap: _isOwner ? _editName : null,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: Text(
                  _coaching.name,
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    letterSpacing: -0.5,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              if (_isOwner) ...[
                const SizedBox(width: 8),
                Icon(
                  Icons.edit_rounded,
                  size: 16,
                  color: theme.colorScheme.primary.withValues(alpha: 0.5),
                ),
              ],
            ],
          ),
        ),

        // Tagline
        if (_coaching.tagline != null && _coaching.tagline!.isNotEmpty) ...[
          const SizedBox(height: 6),
          GestureDetector(
            onTap: _isOwner ? _editTagline : null,
            child: Text(
              _coaching.tagline!,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                fontStyle: FontStyle.italic,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ] else if (_isOwner) ...[
          const SizedBox(height: 6),
          GestureDetector(
            onTap: _editTagline,
            child: Text(
              '+ Add tagline',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.primary,
              ),
            ),
          ),
        ],

        // Category & Slug
        const SizedBox(height: 10),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_coaching.category != null)
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  _coaching.category!,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            const SizedBox(width: 8),
            Text(
              '@${_coaching.slug}',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
              ),
            ),
          ],
        ),

        // Status Badge
        const SizedBox(height: 12),
        _StatusBadge(status: _coaching.status),
      ],
    );
  }

  Widget _buildOnboardingBanner(ThemeData theme) {
    final stepName = _getOnboardingStepName();
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.orange.withValues(alpha: 0.12),
            Colors.amber.withValues(alpha: 0.08),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.orange.withValues(alpha: 0.25)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.orange.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.rocket_launch_rounded,
                  color: Colors.orange,
                  size: 22,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Almost there!',
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Continue from: $stepName',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: Colors.orange.shade700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _continueOnboarding,
              icon: const Icon(Icons.arrow_forward, size: 18),
              label: const Text('Complete Setup'),
              style: FilledButton.styleFrom(
                backgroundColor: Colors.orange,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _getOnboardingStepName() {
    final step = CoachingOnboardingScreen.getResumeStep(_coaching);
    switch (step) {
      case 0:
        return 'Basic Info';
      case 1:
        return 'Details & Contact';
      case 2:
        return 'Address & Location';
      case 3:
        return 'Review';
      default:
        return 'Setup';
    }
  }

  Widget _buildQuickStats(ThemeData theme) {
    return Row(
      children: [
        _StatCard(
          icon: Icons.people_outline,
          value: _coaching.memberCount.toString(),
          label: 'Members',
          color: theme.colorScheme.primary,
        ),
        const SizedBox(width: 12),
        _StatCard(
          icon: Icons.school_outlined,
          value: _coaching.teacherCount.toString(),
          label: 'Teachers',
          color: Colors.blue,
        ),
        const SizedBox(width: 12),
        _StatCard(
          icon: Icons.person_outline,
          value: _coaching.studentCount.toString(),
          label: 'Students',
          color: Colors.green,
        ),
      ],
    );
  }

  Widget _buildAboutSection(ThemeData theme) {
    return _SectionCard(
      title: 'About',
      icon: Icons.info_outline,
      onEdit: _isOwner ? _editAbout : null,
      child: _coaching.aboutUs != null && _coaching.aboutUs!.isNotEmpty
          ? Text(
              _coaching.aboutUs!,
              style: theme.textTheme.bodyMedium?.copyWith(
                height: 1.5,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.8),
              ),
            )
          : Text(
              'No description yet',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
                fontStyle: FontStyle.italic,
              ),
            ),
    );
  }

  Widget _buildContactSection(ThemeData theme) {
    return _SectionCard(
      title: 'Contact',
      icon: Icons.contact_phone_outlined,
      child: Column(
        children: [
          _ContactRow(
            icon: Icons.email_outlined,
            label: 'Email',
            value: _coaching.contactEmail,
            onTap: _isOwner ? _editEmail : null,
          ),
          _ContactRow(
            icon: Icons.phone_outlined,
            label: 'Phone',
            value: _coaching.contactPhone,
            onTap: _isOwner ? _editPhone : null,
          ),
          _ContactRow(
            icon: Icons.chat_outlined,
            label: 'WhatsApp',
            value: _coaching.whatsappPhone,
            onTap: _isOwner ? _editWhatsApp : null,
          ),
          _ContactRow(
            icon: Icons.language_outlined,
            label: 'Website',
            value: _coaching.websiteUrl,
            onTap: _isOwner ? _editWebsite : null,
          ),
        ],
      ),
    );
  }

  Widget _buildAddressSection(ThemeData theme) {
    final addr = _coaching.address;
    return _SectionCard(
      title: 'Location',
      icon: Icons.location_on_outlined,
      onEdit: _isOwner ? _editAddress : null,
      child: addr != null
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  addr.addressLine1,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
                ),
                if (addr.addressLine2 != null &&
                    addr.addressLine2!.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    addr.addressLine2!,
                    style: theme.textTheme.bodyMedium,
                  ),
                ],
                if (addr.landmark != null && addr.landmark!.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    'Near: ${addr.landmark}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                    ),
                  ),
                ],
                const SizedBox(height: 4),
                Text(
                  '${addr.city}, ${addr.state} - ${addr.pincode}',
                  style: theme.textTheme.bodyMedium,
                ),
                if (addr.latitude != null && addr.longitude != null) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(
                        Icons.gps_fixed,
                        size: 14,
                        color: Colors.green,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'GPS location available',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: Colors.green,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            )
          : Text(
              'No address added yet',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
                fontStyle: FontStyle.italic,
              ),
            ),
    );
  }

  Widget _buildTimingSection(ThemeData theme) {
    final addr = _coaching.address!;
    return _SectionCard(
      title: 'Timings',
      icon: Icons.access_time_outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (addr.openingTime != null || addr.closingTime != null) ...[
            Row(
              children: [
                Icon(
                  Icons.schedule,
                  size: 18,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  '${addr.openingTime ?? '--:--'} - ${addr.closingTime ?? '--:--'}',
                  style: theme.textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
          ],
          if (addr.workingDays.isNotEmpty)
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: ['MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT', 'SUN']
                  .map((day) {
                final isActive = addr.workingDays.contains(day);
                return Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: isActive
                        ? theme.colorScheme.primary
                        : theme.colorScheme.onSurface.withValues(alpha: 0.08),
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    day.substring(0, 1),
                    style: TextStyle(
                      color: isActive
                          ? theme.colorScheme.onPrimary
                          : theme.colorScheme.onSurface.withValues(alpha: 0.4),
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                  ),
                );
              }).toList(),
            ),
        ],
      ),
    );
  }

  Widget _buildBranchesSection(ThemeData theme) {
    return _SectionCard(
      title: 'Branches (${_coaching.branches.length})',
      icon: Icons.business_outlined,
      child: Column(
        children: _coaching.branches.map((branch) {
          return Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.04),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.location_on_outlined,
                    size: 18,
                    color: theme.colorScheme.primary,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        branch.name,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        branch.fullAddress,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color:
                              theme.colorScheme.onSurface.withValues(alpha: 0.6),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildGeneralInfo(ThemeData theme) {
    return _SectionCard(
      title: 'General Information',
      icon: Icons.info_outline,
      child: Column(
        children: [
          _InfoTile(
            label: 'Founded',
            value: _coaching.foundedYear?.toString() ?? 'Not specified',
          ),
          _InfoTile(
            label: 'Created',
            value: _coaching.createdAt != null
                ? _formatDate(_coaching.createdAt!)
                : 'Recently',
          ),
          _InfoTile(
            label: 'Status',
            value: _coaching.status == 'active' ? 'Active' : 'Suspended',
          ),
          if (_coaching.subjects.isNotEmpty)
            _InfoTile(
              label: 'Subjects',
              value: _coaching.subjects.join(', '),
            ),
        ],
      ),
    );
  }

  Widget _buildGrabHandle(ThemeData theme) {
    return Center(
      child: Container(
        width: 40,
        height: 4,
        decoration: BoxDecoration(
          color: theme.colorScheme.onSurface.withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    );
  }

  String _formatDate(DateTime dt) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec'
    ];
    return '${months[dt.month - 1]} ${dt.day}, ${dt.year}';
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// Helper Widgets
// ═══════════════════════════════════════════════════════════════════════════

class _StatusBadge extends StatelessWidget {
  final String status;
  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    final active = status == 'active';
    final color = active ? const Color(0xFF5B8C5A) : Colors.red;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            active ? Icons.check_circle_rounded : Icons.pause_circle_rounded,
            size: 14,
            color: color,
          ),
          const SizedBox(width: 6),
          Text(
            active ? 'Active' : 'Suspended',
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w600,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  final Color color;

  const _StatCard({
    required this.icon,
    required this.value,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 8),
            Text(
              value,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Widget child;
  final VoidCallback? onEdit;

  const _SectionCard({
    required this.title,
    required this.icon,
    required this.child,
    this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.onSurface.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: theme.colorScheme.onSurface.withValues(alpha: 0.06),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                icon,
                size: 18,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(width: 8),
              Text(
                title,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              if (onEdit != null)
                GestureDetector(
                  onTap: onEdit,
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      Icons.edit_outlined,
                      size: 16,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }
}

class _ContactRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? value;
  final VoidCallback? onTap;

  const _ContactRow({
    required this.icon,
    required this.label,
    this.value,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasValue = value != null && value!.isNotEmpty;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, size: 18, color: theme.colorScheme.primary),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                    ),
                  ),
                  Text(
                    hasValue ? value! : 'Not added',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: hasValue ? FontWeight.w500 : FontWeight.normal,
                      color: hasValue
                          ? theme.colorScheme.onSurface
                          : theme.colorScheme.onSurface.withValues(alpha: 0.4),
                      fontStyle: hasValue ? FontStyle.normal : FontStyle.italic,
                    ),
                  ),
                ],
              ),
            ),
            if (onTap != null)
              Icon(
                Icons.chevron_right_rounded,
                size: 20,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.3),
              ),
          ],
        ),
      ),
    );
  }
}

class _InfoTile extends StatelessWidget {
  final String label;
  final String value;

  const _InfoTile({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 90,
            child: Text(
              label,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
