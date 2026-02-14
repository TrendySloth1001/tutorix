import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../../shared/models/user_model.dart';
import '../models/coaching_model.dart';
import '../services/coaching_service.dart';
import '../services/coaching_onboarding_service.dart';
import 'coaching_onboarding_screen.dart';

/// Simplified coaching profile with dividers instead of cards
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

  // ─────────────────────────────────────────────────────────────────────
  // Edit Helpers
  // ─────────────────────────────────────────────────────────────────────

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
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        final theme = Theme.of(ctx);
        return Padding(
          padding: EdgeInsets.fromLTRB(
            20,
            12,
            20,
            MediaQuery.of(ctx).viewInsets.bottom + 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                title,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
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
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      onPressed: () =>
                          Navigator.pop(ctx, controller.text.trim()),
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
              content: Text('Updated'),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 1),
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed: $e'), backgroundColor: Colors.red),
          );
        }
      } finally {
        if (mounted) setState(() => _isLoading = false);
      }
    }
  }

  void _editName() => _editField(
    title: 'Coaching Name',
    currentValue: _coaching.name,
    hint: 'Enter name',
    onSave: (v) => _coachingService.updateCoaching(id: _coaching.id, name: v),
  );

  void _editTagline() => _editField(
    title: 'Tagline',
    currentValue: _coaching.tagline ?? '',
    hint: 'A short tagline...',
    maxLength: 100,
    onSave: (v) => _onboardingService.updateProfile(
      coachingId: _coaching.id,
      tagline: v.isEmpty ? null : v,
    ),
  );

  void _editAbout() => _editField(
    title: 'About',
    currentValue: _coaching.aboutUs ?? '',
    hint: 'Tell about your coaching...',
    maxLines: 4,
    maxLength: 500,
    onSave: (v) => _onboardingService.updateProfile(
      coachingId: _coaching.id,
      aboutUs: v.isEmpty ? null : v,
    ),
  );

  void _editEmail() => _editField(
    title: 'Contact Email',
    currentValue: _coaching.contactEmail ?? '',
    hint: 'email@example.com',
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
    title: 'WhatsApp',
    currentValue: _coaching.whatsappPhone ?? '',
    hint: '9876543210',
    keyboardType: TextInputType.phone,
    onSave: (v) => _onboardingService.updateProfile(
      coachingId: _coaching.id,
      whatsappPhone: v.isEmpty ? null : v,
    ),
  );

  void _editWebsite() => _editField(
    title: 'Website',
    currentValue: _coaching.websiteUrl ?? '',
    hint: 'https://...',
    keyboardType: TextInputType.url,
    onSave: (v) => _onboardingService.updateProfile(
      coachingId: _coaching.id,
      websiteUrl: v.isEmpty ? null : v,
    ),
  );

  Future<void> _changeLogo() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt_outlined),
              title: const Text('Take Photo'),
              onTap: () => Navigator.pop(ctx, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Choose from Gallery'),
              onTap: () => Navigator.pop(ctx, ImageSource.gallery),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
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
          SnackBar(content: Text('Upload failed: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isUploadingLogo = false);
    }
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
          initialStep: 2,
          onComplete: () {
            Navigator.pop(context);
            _refreshCoaching();
          },
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────
  // Build
  // ─────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Scaffold(
      backgroundColor: colors.surface,
      body: Stack(
        children: [
          RefreshIndicator(
            onRefresh: _refreshCoaching,
            child: ListView(
              padding: EdgeInsets.fromLTRB(
                0,
                MediaQuery.of(context).padding.top,
                0,
                100,
              ),
              children: [
                // Header
                _buildHeader(theme),

                // Hero
                _buildHero(theme),

                // Incomplete onboarding banner
                if (_isOwner && !_coaching.onboardingComplete)
                  _buildOnboardingBanner(theme),

                const Divider(height: 1),

                // About
                if (_coaching.aboutUs != null || _isOwner)
                  _buildAboutSection(theme),

                // Contact
                _buildContactSection(theme),

                // Address
                if (_coaching.address != null || _isOwner)
                  _buildAddressSection(theme),

                // Timings
                if (_coaching.address != null) _buildTimingsSection(theme),

                // Branches
                if (_coaching.branches.isNotEmpty) _buildBranchesSection(theme),

                // General info
                _buildGeneralSection(theme),
              ],
            ),
          ),
          if (_isLoading)
            Container(
              color: Colors.black26,
              child: const Center(child: CircularProgressIndicator()),
            ),
        ],
      ),
    );
  }

  Widget _buildHeader(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          if (widget.onBack != null)
            IconButton(
              onPressed: widget.onBack,
              icon: const Icon(Icons.arrow_back),
            ),
          const Spacer(),
          if (_coaching.isVerified)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.blue.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.verified, size: 14, color: Colors.blue),
                  SizedBox(width: 4),
                  Text(
                    'Verified',
                    style: TextStyle(
                      color: Colors.blue,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildHero(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Column(
        children: [
          // Logo
          GestureDetector(
            onTap: _isOwner && !_isUploadingLogo ? _changeLogo : null,
            child: Stack(
              children: [
                CircleAvatar(
                  radius: 48,
                  backgroundColor: theme.colorScheme.primary.withValues(alpha: 0.1),
                  backgroundImage:
                      _coaching.logo != null ? NetworkImage(_coaching.logo!) : null,
                  child: _coaching.logo == null
                      ? Icon(
                          Icons.school_rounded,
                          size: 40,
                          color: theme.colorScheme.primary.withValues(alpha: 0.4),
                        )
                      : null,
                ),
                if (_isUploadingLogo)
                  Positioned.fill(
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.black45,
                        shape: BoxShape.circle,
                      ),
                      child: const Center(
                        child: SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
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
                      ),
                      child: Icon(
                        Icons.camera_alt,
                        size: 12,
                        color: theme.colorScheme.onPrimary,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // Name
          GestureDetector(
            onTap: _isOwner ? _editName : null,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Flexible(
                  child: Text(
                    _coaching.name,
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                if (_isOwner) ...[
                  const SizedBox(width: 6),
                  Icon(
                    Icons.edit,
                    size: 14,
                    color: theme.colorScheme.primary.withValues(alpha: 0.5),
                  ),
                ],
              ],
            ),
          ),

          // Tagline
          if (_coaching.tagline != null && _coaching.tagline!.isNotEmpty) ...[
            const SizedBox(height: 4),
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
            const SizedBox(height: 4),
            GestureDetector(
              onTap: _editTagline,
              child: Text(
                '+ Add tagline',
                style: TextStyle(
                  color: theme.colorScheme.primary,
                  fontSize: 13,
                ),
              ),
            ),
          ],

          const SizedBox(height: 10),

          // Category & Slug
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_coaching.category != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    _coaching.category!,
                    style: TextStyle(
                      color: theme.colorScheme.primary,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              const SizedBox(width: 8),
              Text(
                '@${_coaching.slug}',
                style: TextStyle(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
                  fontSize: 12,
                ),
              ),
            ],
          ),

          const SizedBox(height: 10),

          // Status
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
            decoration: BoxDecoration(
              color: _coaching.status == 'active'
                  ? Colors.green.withValues(alpha: 0.1)
                  : Colors.red.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  _coaching.status == 'active'
                      ? Icons.check_circle
                      : Icons.pause_circle,
                  size: 14,
                  color: _coaching.status == 'active' ? Colors.green : Colors.red,
                ),
                const SizedBox(width: 4),
                Text(
                  _coaching.status == 'active' ? 'Active' : 'Suspended',
                  style: TextStyle(
                    color:
                        _coaching.status == 'active' ? Colors.green : Colors.red,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOnboardingBanner(ThemeData theme) {
    final stepName = _getStepName();
    return InkWell(
      onTap: _continueOnboarding,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Icon(Icons.rocket_launch, size: 20, color: Colors.orange),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Complete your setup',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                      color: Colors.orange.shade800,
                    ),
                  ),
                  Text(
                    'Continue from: $stepName',
                    style: TextStyle(
                      color: Colors.orange.shade600,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.arrow_forward_ios,
              size: 14,
              color: Colors.orange.shade400,
            ),
          ],
        ),
      ),
    );
  }

  String _getStepName() {
    final step = CoachingOnboardingScreen.getResumeStep(_coaching);
    switch (step) {
      case 0:
        return 'Basic Info';
      case 1:
        return 'Details';
      case 2:
        return 'Address';
      case 3:
        return 'Review';
      default:
        return 'Setup';
    }
  }

  Widget _buildAboutSection(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader(theme, 'About', onEdit: _isOwner ? _editAbout : null),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: _coaching.aboutUs != null && _coaching.aboutUs!.isNotEmpty
              ? Text(
                  _coaching.aboutUs!,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    height: 1.5,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.8),
                  ),
                )
              : Text(
                  'No description added',
                  style: TextStyle(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
                    fontStyle: FontStyle.italic,
                  ),
                ),
        ),
        const Divider(height: 1),
      ],
    );
  }

  Widget _buildContactSection(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader(theme, 'Contact'),
        _buildInfoRow(
          theme,
          Icons.email_outlined,
          'Email',
          _coaching.contactEmail,
          onTap: _isOwner ? _editEmail : null,
        ),
        _buildInfoRow(
          theme,
          Icons.phone_outlined,
          'Phone',
          _coaching.contactPhone,
          onTap: _isOwner ? _editPhone : null,
        ),
        _buildInfoRow(
          theme,
          Icons.chat_outlined,
          'WhatsApp',
          _coaching.whatsappPhone,
          onTap: _isOwner ? _editWhatsApp : null,
        ),
        _buildInfoRow(
          theme,
          Icons.language_outlined,
          'Website',
          _coaching.websiteUrl,
          onTap: _isOwner ? _editWebsite : null,
        ),
        const Divider(height: 1),
      ],
    );
  }

  Widget _buildAddressSection(ThemeData theme) {
    final addr = _coaching.address;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader(theme, 'Location', onEdit: _isOwner ? _editAddress : null),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
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
                    if (addr.addressLine2 != null && addr.addressLine2!.isNotEmpty)
                      Text(addr.addressLine2!, style: theme.textTheme.bodyMedium),
                    if (addr.landmark != null && addr.landmark!.isNotEmpty)
                      Text(
                        'Near: ${addr.landmark}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                        ),
                      ),
                    const SizedBox(height: 4),
                    Text(
                      '${addr.city}, ${addr.state} - ${addr.pincode}',
                      style: theme.textTheme.bodyMedium,
                    ),
                    if (addr.latitude != null && addr.longitude != null) ...[
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          const Icon(Icons.gps_fixed, size: 14, color: Colors.green),
                          const SizedBox(width: 4),
                          Text(
                            'GPS location saved',
                            style: TextStyle(
                              color: Colors.green,
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                )
              : Text(
                  'No address added',
                  style: TextStyle(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
                    fontStyle: FontStyle.italic,
                  ),
                ),
        ),
        const Divider(height: 1),
      ],
    );
  }

  Widget _buildTimingsSection(ThemeData theme) {
    final addr = _coaching.address!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader(theme, 'Timings'),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (addr.openingTime != null || addr.closingTime != null)
                Row(
                  children: [
                    Icon(Icons.schedule, size: 16, color: theme.colorScheme.primary),
                    const SizedBox(width: 8),
                    Text(
                      '${addr.openingTime ?? '--:--'} - ${addr.closingTime ?? '--:--'}',
                      style: theme.textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              if (addr.workingDays.isNotEmpty) ...[
                const SizedBox(height: 12),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: ['MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT', 'SUN'].map((day) {
                    final isActive = addr.workingDays.contains(day);
                    return Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: isActive
                            ? theme.colorScheme.primary
                            : theme.colorScheme.onSurface.withValues(alpha: 0.06),
                        shape: BoxShape.circle,
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        day.substring(0, 1),
                        style: TextStyle(
                          color: isActive
                              ? theme.colorScheme.onPrimary
                              : theme.colorScheme.onSurface.withValues(alpha: 0.35),
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ],
          ),
        ),
        const Divider(height: 1),
      ],
    );
  }

  Widget _buildBranchesSection(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader(theme, 'Branches (${_coaching.branches.length})'),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Column(
            children: _coaching.branches.map((branch) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.location_on_outlined,
                      size: 18,
                      color: theme.colorScheme.primary,
                    ),
                    const SizedBox(width: 10),
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
                              color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
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
        ),
        const Divider(height: 1),
      ],
    );
  }

  Widget _buildGeneralSection(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader(theme, 'General'),
        _buildSimpleInfoRow(theme, 'Founded', _coaching.foundedYear?.toString() ?? 'Not specified'),
        _buildSimpleInfoRow(
          theme,
          'Created',
          _coaching.createdAt != null
              ? _formatDate(_coaching.createdAt!)
              : 'Recently',
        ),
        if (_coaching.subjects.isNotEmpty)
          _buildSimpleInfoRow(theme, 'Subjects', _coaching.subjects.join(', ')),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildSectionHeader(ThemeData theme, String title, {VoidCallback? onEdit}) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
      child: Row(
        children: [
          Text(
            title,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
            ),
          ),
          const Spacer(),
          if (onEdit != null)
            GestureDetector(
              onTap: onEdit,
              child: Text(
                'Edit',
                style: TextStyle(
                  color: theme.colorScheme.primary,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(
    ThemeData theme,
    IconData icon,
    String label,
    String? value, {
    VoidCallback? onTap,
  }) {
    final hasValue = value != null && value.isNotEmpty;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Icon(icon, size: 20, color: theme.colorScheme.primary.withValues(alpha: 0.7)),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 11,
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                    ),
                  ),
                  Text(
                    hasValue ? value : 'Not added',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: hasValue ? FontWeight.w500 : FontWeight.normal,
                      color: hasValue
                          ? theme.colorScheme.onSurface
                          : theme.colorScheme.onSurface.withValues(alpha: 0.35),
                      fontStyle: hasValue ? FontStyle.normal : FontStyle.italic,
                    ),
                  ),
                ],
              ),
            ),
            if (onTap != null)
              Icon(
                Icons.chevron_right,
                size: 20,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.25),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildSimpleInfoRow(ThemeData theme, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Row(
        children: [
          SizedBox(
            width: 80,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime dt) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${months[dt.month - 1]} ${dt.day}, ${dt.year}';
  }
}
