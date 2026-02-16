import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import '../../../shared/models/user_model.dart';
import '../../../shared/widgets/app_alert.dart';
import '../models/coaching_model.dart';
import '../services/coaching_service.dart';
import '../services/coaching_onboarding_service.dart';
import 'coaching_onboarding_screen.dart';

/// Premium coaching profile with clean, minimal design
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
  bool _isUploadingCover = false;
  bool _isLoading = false;

  late CoachingModel _coaching;
  StreamSubscription? _sub;

  @override
  void initState() {
    super.initState();
    _coaching = widget.coaching;
    _refreshCoaching();
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  bool get _isOwner => _coaching.ownerId == widget.user.id;

  void _refreshCoaching() {
    _sub?.cancel();
    _sub = _coachingService.watchCoachingById(_coaching.id).listen(
      (updated) {
        if (updated != null && mounted) {
          setState(() => _coaching = updated);
          widget.onCoachingUpdated?.call(updated);
        }
      },
      onError: (_) {},
    );
  }

  // ═══════════════════════════════════════════════════════════════════════
  // Edit Methods
  // ═══════════════════════════════════════════════════════════════════════

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
            12,
            20,
            MediaQuery.of(ctx).viewInsets.bottom + 24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Text(
                title,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: controller,
                autofocus: true,
                maxLines: maxLines,
                maxLength: maxLength,
                keyboardType: keyboardType,
                decoration: InputDecoration(
                  hintText: hint,
                  filled: true,
                  fillColor: theme.colorScheme.onSurface.withValues(
                    alpha: 0.04,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                      color: theme.colorScheme.primary,
                      width: 1.5,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: FilledButton(
                      onPressed: () =>
                          Navigator.pop(ctx, controller.text.trim()),
                      child: const Text('Save Changes'),
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
        _refreshCoaching();
        if (mounted) AppAlert.success(context, 'Updated successfully');
      } catch (e) {
        if (mounted) AppAlert.error(context, e, fallback: 'Update failed');
      } finally {
        if (mounted) setState(() => _isLoading = false);
      }
    }
  }

  void _showSuccess(String msg) {
    AppAlert.success(context, msg);
  }

  void _showError(String msg) {
    AppAlert.error(context, msg);
  }

  void _editTagline() => _editField(
    title: 'Tagline',
    currentValue: _coaching.tagline ?? '',
    hint: 'A catchy tagline for your coaching...',
    maxLength: 100,
    onSave: (v) => _onboardingService.updateProfile(
      coachingId: _coaching.id,
      tagline: v.isEmpty ? null : v,
    ),
  );

  void _editAbout() => _editField(
    title: 'About',
    currentValue: _coaching.aboutUs ?? '',
    hint: 'Tell students about your coaching...',
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
    hint: 'https://yourcoaching.com',
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
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'Update Logo',
                style: Theme.of(
                  ctx,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: _OptionTile(
                      icon: Icons.camera_alt_rounded,
                      label: 'Camera',
                      onTap: () => Navigator.pop(ctx, ImageSource.camera),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _OptionTile(
                      icon: Icons.photo_library_rounded,
                      label: 'Gallery',
                      onTap: () => Navigator.pop(ctx, ImageSource.gallery),
                    ),
                  ),
                ],
              ),
            ],
          ),
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
      _refreshCoaching();
      if (mounted) _showSuccess('Logo updated');
    } catch (e) {
      if (mounted) _showError('Upload failed');
    } finally {
      if (mounted) setState(() => _isUploadingLogo = false);
    }
  }

  Future<void> _changeCover() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'Update Cover Image',
                style: Theme.of(
                  ctx,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: _OptionTile(
                      icon: Icons.camera_alt_rounded,
                      label: 'Camera',
                      onTap: () => Navigator.pop(ctx, ImageSource.camera),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _OptionTile(
                      icon: Icons.photo_library_rounded,
                      label: 'Gallery',
                      onTap: () => Navigator.pop(ctx, ImageSource.gallery),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
    if (source == null) return;

    final picked = await _picker.pickImage(
      source: source,
      maxWidth: 1920,
      maxHeight: 1080,
      imageQuality: 85,
    );
    if (picked == null) return;

    setState(() => _isUploadingCover = true);
    try {
      final url = await _coachingService.uploadCover(picked.path);
      await _coachingService.updateCoaching(id: _coaching.id, coverImage: url);
      _refreshCoaching();
      if (mounted) _showSuccess('Cover updated');
    } catch (e) {
      if (mounted) _showError('Upload failed');
    } finally {
      if (mounted) setState(() => _isUploadingCover = false);
    }
  }

  void _openUpdateScreen({int step = 0}) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CoachingOnboardingScreen(
          existingCoaching: _coaching,
          initialStep: step,
          onComplete: () {
            Navigator.pop(context);
            _refreshCoaching();
          },
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════
  // Build
  // ═══════════════════════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final topPadding = MediaQuery.of(context).padding.top;
    final colors = theme.colorScheme;

    // Cover extends all the way to About section
    const double expandedHeight = 480.0;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      // Light icons (white) for status bar on dark/image backgrounds
      value: SystemUiOverlayStyle.light.copyWith(
        statusBarColor: Colors.transparent,
      ),
      child: Scaffold(
        backgroundColor: theme.colorScheme.surface,
        body: Stack(
          children: [
            RefreshIndicator(
              onRefresh: () async {
                _refreshCoaching();
                await Future.delayed(const Duration(milliseconds: 500));
              },
              edgeOffset: expandedHeight,
              child: CustomScrollView(
                slivers: [
                  // ─── SCROLLING COVER with all profile info inside ───
                  SliverAppBar(
                    expandedHeight: expandedHeight,
                    pinned: false,
                    floating: false,
                    stretch: true,
                    backgroundColor: Colors.transparent,
                    automaticallyImplyLeading: false,
                    flexibleSpace: FlexibleSpaceBar(
                      stretchModes: const [StretchMode.zoomBackground],
                      background: Stack(
                        fit: StackFit.expand,
                        children: [
                          // Cover image or placeholder
                          if (_coaching.coverImage != null)
                            Image.network(
                              _coaching.coverImage!,
                              fit: BoxFit.cover,
                              errorBuilder: (_, _, _) =>
                                  _buildCoverPlaceholder(colors),
                            )
                          else
                            _buildCoverPlaceholder(colors),

                          // Gradient overlay for text readability
                          Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  Colors.black.withValues(alpha: 0.35),
                                  Colors.black.withValues(alpha: 0.1),
                                  Colors.transparent,
                                  Colors.black.withValues(alpha: 0.25),
                                  colors.surface.withValues(alpha: 0.9),
                                  colors.surface,
                                ],
                                stops: const [0.0, 0.12, 0.3, 0.55, 0.88, 1.0],
                              ),
                            ),
                          ),

                          // Upload indicator
                          if (_isUploadingCover)
                            Container(
                              color: Colors.black45,
                              child: const Center(
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                ),
                              ),
                            ),

                          // ─── PROFILE INFO INSIDE COVER ───
                          Positioned(
                            left: 0,
                            right: 0,
                            bottom: 0,
                            child: _buildProfileInfoOverlay(theme),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // ─── CONTENT SECTIONS (About starts here) ───
                  SliverPadding(
                    padding: const EdgeInsets.only(bottom: 100),
                    sliver: SliverList(
                      delegate: SliverChildListDelegate([
                        if (_isOwner && !_coaching.onboardingComplete)
                          _buildSetupPrompt(theme),
                        _buildSection(
                          theme,
                          title: 'About',
                          onEdit: _isOwner ? _editAbout : null,
                          child: _buildAboutContent(theme),
                        ),
                        _buildSection(
                          theme,
                          title: 'Contact Information',
                          child: _buildContactContent(theme),
                        ),
                        if (_coaching.address != null || _isOwner)
                          _buildSection(
                            theme,
                            title: 'Location',
                            onEdit: _isOwner
                                ? () => _openUpdateScreen(step: 2)
                                : null,
                            child: _buildLocationContent(theme),
                          ),
                        if (_coaching.address != null &&
                            (_coaching.address!.workingDays.isNotEmpty ||
                                _coaching.address!.openingTime != null))
                          _buildSection(
                            theme,
                            title: 'Working Hours',
                            child: _buildTimingContent(theme),
                          ),
                        if (_coaching.branches.isNotEmpty)
                          _buildSection(
                            theme,
                            title: 'Branches',
                            child: _buildBranchesContent(theme),
                          ),
                        _buildSection(
                          theme,
                          title: 'Information',
                          child: _buildInfoContent(theme),
                        ),
                      ]),
                    ),
                  ),
                ],
              ),
            ),

            // ─── FIXED CAMERA BUTTON (always visible) ───
            if (_isOwner)
              Positioned(
                top: topPadding + 8,
                right: 16,
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.35),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.25),
                      width: 1,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.2),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: _changeCover,
                      borderRadius: BorderRadius.circular(12),
                      child: const Padding(
                        padding: EdgeInsets.all(10),
                        child: Icon(
                          Icons.camera_alt_rounded,
                          color: Colors.white,
                          size: 22,
                        ),
                      ),
                    ),
                  ),
                ),
              ),

            if (_isLoading)
              Container(
                color: Colors.black26,
                child: const Center(child: CircularProgressIndicator()),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileInfoOverlay(ThemeData theme) {
    final colors = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Logo
          GestureDetector(
            onTap: _isOwner && !_isUploadingLogo ? _changeLogo : null,
            child: Container(
              width: 96,
              height: 96,
              decoration: BoxDecoration(
                color: colors.surface,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: colors.surface, width: 4),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.2),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Stack(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: _coaching.logo != null
                        ? Image.network(
                            _coaching.logo!,
                            width: 88,
                            height: 88,
                            fit: BoxFit.cover,
                            errorBuilder: (_, _, _) =>
                                _buildLogoPlaceholder(colors),
                          )
                        : _buildLogoPlaceholder(colors),
                  ),
                  if (_isUploadingLogo)
                    Positioned.fill(
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.black45,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: const Center(
                          child: SizedBox(
                            width: 18,
                            height: 18,
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
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: colors.primary,
                          shape: BoxShape.circle,
                          border: Border.all(color: colors.surface, width: 2),
                        ),
                        child: Icon(
                          Icons.camera_alt_rounded,
                          size: 11,
                          color: colors.onPrimary,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 12),

          // Name with Edit Button - on frosted glass container
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: colors.surface.withValues(alpha: 0.85),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: colors.onSurface.withValues(alpha: 0.08),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Flexible(
                  child: Text(
                    _coaching.name,
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      letterSpacing: -0.3,
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (_isOwner) ...[
                  const SizedBox(width: 8),
                  Material(
                    color: colors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                    child: InkWell(
                      onTap: () => _openUpdateScreen(step: 0),
                      borderRadius: BorderRadius.circular(8),
                      child: Padding(
                        padding: const EdgeInsets.all(5),
                        child: Icon(
                          Icons.edit_rounded,
                          size: 16,
                          color: colors.primary,
                        ),
                      ),
                    ),
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
                  color: colors.onSurface.withValues(alpha: 0.7),
                  fontStyle: FontStyle.italic,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ] else if (_isOwner) ...[
            const SizedBox(height: 6),
            GestureDetector(
              onTap: _editTagline,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.add, size: 14, color: colors.primary),
                  const SizedBox(width: 4),
                  Text(
                    'Add tagline',
                    style: TextStyle(
                      color: colors.primary,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ],

          // Category & Status Badges
          const SizedBox(height: 10),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 6,
            runSpacing: 6,
            children: [
              if (_coaching.category != null)
                _buildBadge(
                  _coaching.category!,
                  colors.primary.withValues(alpha: 0.12),
                  colors.primary,
                ),
              _buildBadge(
                '@${_coaching.slug}',
                colors.onSurface.withValues(alpha: 0.08),
                colors.onSurface.withValues(alpha: 0.6),
              ),
              _buildStatusBadge(),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBadge(String text, Color bgColor, Color textColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: textColor,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildStatusBadge() {
    final isActive = _coaching.status == 'active';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: isActive
            ? Colors.green.withValues(alpha: 0.12)
            : Colors.red.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 5,
            height: 5,
            decoration: BoxDecoration(
              color: isActive ? Colors.green : Colors.red,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 5),
          Text(
            isActive ? 'Active' : 'Inactive',
            style: TextStyle(
              color: isActive ? Colors.green : Colors.red,
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCoverPlaceholder(ColorScheme colors) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            colors.primary.withValues(alpha: 0.3),
            colors.primary.withValues(alpha: 0.1),
          ],
        ),
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.image_rounded,
              size: 48,
              color: colors.primary.withValues(alpha: 0.4),
            ),
            if (_isOwner)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  'Add Cover Image',
                  style: TextStyle(
                    color: colors.primary.withValues(alpha: 0.6),
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildLogoPlaceholder(ColorScheme colors) {
    return Container(
      color: colors.primary.withValues(alpha: 0.05),
      child: Icon(
        Icons.school_rounded,
        size: 36,
        color: colors.primary.withValues(alpha: 0.3),
      ),
    );
  }

  Widget _buildSetupPrompt(ThemeData theme) {
    final step = CoachingOnboardingScreen.getResumeStep(_coaching);
    final stepNames = ['Basic Info', 'Details', 'Address', 'Review'];

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Material(
        color: Colors.orange.shade50,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: () => _openUpdateScreen(step: step),
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.orange.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    Icons.rocket_launch_rounded,
                    color: Colors.orange.shade700,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Complete your profile',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: Colors.orange.shade900,
                          fontSize: 14,
                        ),
                      ),
                      Text(
                        'Continue from ${stepNames[step]}',
                        style: TextStyle(
                          color: Colors.orange.shade700,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: 16,
                  color: Colors.orange.shade600,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSection(
    ThemeData theme, {
    required String title,
    required Widget child,
    VoidCallback? onEdit,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
          child: Row(
            children: [
              Text(
                title.toUpperCase(),
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
                ),
              ),
              const Spacer(),
              if (onEdit != null)
                GestureDetector(
                  onTap: onEdit,
                  child: Text(
                    'Edit',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: child,
        ),
        const SizedBox(height: 8),
        Divider(
          height: 1,
          color: theme.colorScheme.onSurface.withValues(alpha: 0.06),
        ),
      ],
    );
  }

  Widget _buildAboutContent(ThemeData theme) {
    if (_coaching.aboutUs != null && _coaching.aboutUs!.isNotEmpty) {
      return Text(
        _coaching.aboutUs!,
        style: theme.textTheme.bodyMedium?.copyWith(
          height: 1.6,
          color: theme.colorScheme.onSurface.withValues(alpha: 0.8),
        ),
      );
    }
    return Text(
      'No description added yet',
      style: TextStyle(
        color: theme.colorScheme.onSurface.withValues(alpha: 0.35),
        fontStyle: FontStyle.italic,
      ),
    );
  }

  Widget _buildContactContent(ThemeData theme) {
    return Column(
      children: [
        _ContactItem(
          icon: Icons.email_outlined,
          label: 'Email',
          value: _coaching.contactEmail,
          onTap: _isOwner ? _editEmail : null,
        ),
        _ContactItem(
          icon: Icons.phone_outlined,
          label: 'Phone',
          value: _coaching.contactPhone,
          onTap: _isOwner ? _editPhone : null,
        ),
        _ContactItem(
          icon: Icons.chat_outlined,
          label: 'WhatsApp',
          value: _coaching.whatsappPhone,
          onTap: _isOwner ? _editWhatsApp : null,
        ),
        _ContactItem(
          icon: Icons.language_outlined,
          label: 'Website',
          value: _coaching.websiteUrl,
          onTap: _isOwner ? _editWebsite : null,
        ),
      ],
    );
  }

  Widget _buildLocationContent(ThemeData theme) {
    final addr = _coaching.address;
    if (addr == null) {
      return Text(
        'No address added yet',
        style: TextStyle(
          color: theme.colorScheme.onSurface.withValues(alpha: 0.35),
          fontStyle: FontStyle.italic,
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          addr.fullAddress,
          style: theme.textTheme.bodyMedium?.copyWith(
            height: 1.5,
            color: theme.colorScheme.onSurface.withValues(alpha: 0.8),
          ),
        ),
        if (addr.latitude != null && addr.longitude != null) ...[
          const SizedBox(height: 10),
          Row(
            children: [
              Icon(Icons.gps_fixed_rounded, size: 16, color: Colors.green),
              const SizedBox(width: 6),
              Text(
                'GPS location saved',
                style: TextStyle(
                  color: Colors.green,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _buildTimingContent(ThemeData theme) {
    final addr = _coaching.address!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (addr.openingTime != null || addr.closingTime != null)
          Row(
            children: [
              Icon(
                Icons.access_time_rounded,
                size: 18,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(width: 10),
              Text(
                '${addr.openingTime ?? '--:--'} - ${addr.closingTime ?? '--:--'}',
                style: theme.textTheme.bodyLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        if (addr.workingDays.isNotEmpty) ...[
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: ['MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT', 'SUN'].map((
              day,
            ) {
              final isActive = addr.workingDays.contains(day);
              return Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: isActive
                      ? theme.colorScheme.primary
                      : theme.colorScheme.onSurface.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(10),
                ),
                alignment: Alignment.center,
                child: Text(
                  day.substring(0, 2),
                  style: TextStyle(
                    color: isActive
                        ? theme.colorScheme.onPrimary
                        : theme.colorScheme.onSurface.withValues(alpha: 0.3),
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ],
    );
  }

  Widget _buildBranchesContent(ThemeData theme) {
    return Column(
      children: _coaching.branches.map((branch) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withValues(alpha: 0.08),
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
                    const SizedBox(height: 2),
                    Text(
                      branch.fullAddress,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurface.withValues(
                          alpha: 0.6,
                        ),
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildInfoContent(ThemeData theme) {
    return Column(
      children: [
        _InfoRow(
          label: 'Founded',
          value: _coaching.foundedYear?.toString() ?? 'Not specified',
        ),
        _InfoRow(
          label: 'Created',
          value: _coaching.createdAt != null
              ? _formatDate(_coaching.createdAt!)
              : 'Recently',
        ),
        if (_coaching.subjects.isNotEmpty)
          _InfoRow(label: 'Subjects', value: _coaching.subjects.join(', ')),
      ],
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
      'Dec',
    ];
    return '${months[dt.month - 1]} ${dt.day}, ${dt.year}';
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// Helper Widgets
// ═══════════════════════════════════════════════════════════════════════════

class _OptionTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _OptionTile({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: theme.colorScheme.onSurface.withValues(alpha: 0.04),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 20),
          child: Column(
            children: [
              Icon(icon, size: 28, color: theme.colorScheme.primary),
              const SizedBox(height: 8),
              Text(
                label,
                style: TextStyle(
                  fontWeight: FontWeight.w500,
                  color: theme.colorScheme.onSurface,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ContactItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? value;
  final VoidCallback? onTap;

  const _ContactItem({
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
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          children: [
            Icon(
              icon,
              size: 20,
              color: theme.colorScheme.primary.withValues(alpha: 0.7),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 11,
                      color: theme.colorScheme.onSurface.withValues(
                        alpha: 0.45,
                      ),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    hasValue ? value! : 'Not added',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: hasValue
                          ? FontWeight.w500
                          : FontWeight.normal,
                      color: hasValue
                          ? theme.colorScheme.onSurface
                          : theme.colorScheme.onSurface.withValues(alpha: 0.3),
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
                color: theme.colorScheme.onSurface.withValues(alpha: 0.2),
              ),
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;

  const _InfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.45),
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.85),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
