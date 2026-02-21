import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../../shared/models/user_model.dart';
import '../../../shared/widgets/app_alert.dart';
import '../../../shared/widgets/app_shimmer.dart';
import '../../../shared/widgets/setting_tile.dart';
import '../../academic/models/academic_masters.dart';
import '../../academic/models/academic_profile.dart';
import '../../academic/screens/academic_onboarding_screen.dart';
import '../../academic/services/academic_service.dart';
import '../../admin/screens/admin_debug_screen.dart';
import '../../settings/screens/settings_screen.dart';
import '../services/upload_service.dart';
import '../services/user_service.dart';
import 'edit_profile_screen.dart';
import 'photo_viewer_screen.dart';
import 'security_sessions_screen.dart';

class ProfileScreen extends StatefulWidget {
  final UserModel user;
  final VoidCallback onLogout;
  final ValueChanged<UserModel>? onUserUpdated;

  const ProfileScreen({
    super.key,
    required this.user,
    required this.onLogout,
    this.onUserUpdated,
  });

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final UploadService _uploadService = UploadService();
  final AcademicService _academicService = AcademicService();
  final ImagePicker _picker = ImagePicker();
  bool _isUploading = false;

  // Academic profile state
  AcademicProfile? _academicProfile;
  AcademicMasters? _academicMasters;
  bool _isStudentSomewhere = false;
  bool _loadingAcademic = true;

  @override
  void initState() {
    super.initState();
    _loadAcademicData();
  }

  Future<void> _loadAcademicData() async {
    try {
      final results = await Future.wait([
        _academicService.getOnboardingStatus(),
        _academicService.getMasters(),
        _academicService.getProfile(),
      ]);

      if (mounted) {
        final status = results[0] as dynamic;
        setState(() {
          _isStudentSomewhere = status.reason != 'not_a_student';
          _academicMasters = results[1] as AcademicMasters?;
          _academicProfile = results[2] as AcademicProfile?;
          _loadingAcademic = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loadingAcademic = false);
      }
    }
  }

  // ── Avatar actions ─────────────────────────────────────────────────────

  Future<void> _updateAvatar() async {
    try {
      final image = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 512,
        maxHeight: 512,
        imageQuality: 75,
      );
      if (image == null) return;

      setState(() => _isUploading = true);
      final updated = await _uploadService.uploadAvatar(File(image.path));
      if (updated != null && mounted) {
        widget.onUserUpdated?.call(updated);
        AppAlert.success(context, 'Profile picture updated successfully');
      }
    } catch (e) {
      if (mounted) {
        AppAlert.error(context, e, fallback: 'Failed to update avatar');
      }
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  Future<void> _removeAvatar() async {
    try {
      final userService = UserService();
      setState(() => _isUploading = true);
      final updated = await userService.updateProfile(picture: null);
      if (updated != null && mounted) {
        widget.onUserUpdated?.call(updated);
        AppAlert.success(context, 'Profile picture removed');
      }
    } catch (e) {
      if (mounted) {
        AppAlert.error(context, e, fallback: 'Failed to remove avatar');
      }
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  void _showPhotoOptions() {
    final user = widget.user;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _PhotoOptionsSheet(
        user: user,
        onChangeTap: () {
          Navigator.pop(context);
          _updateAvatar();
        },
        onRemoveTap: () {
          Navigator.pop(context);
          _removeAvatar();
        },
      ),
    );
  }

  // ── Build ──────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final user = widget.user;

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: AppBar(
        title: Text(
          'Profile',
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout_rounded),
            onPressed: widget.onLogout,
            color: theme.colorScheme.primary,
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            children: [
              const SizedBox(height: 40),

              // Avatar with edit/camera buttons
              _AvatarSection(
                user: user,
                isUploading: _isUploading,
                onPhotoTap: () => _navigateTo(
                  PhotoViewerScreen(
                    user: user,
                    onUserUpdated: widget.onUserUpdated,
                  ),
                ),
                onEditTap: () => _navigateTo(
                  EditProfileScreen(
                    user: user,
                    onUserUpdated: (u) => widget.onUserUpdated?.call(u),
                  ),
                ),
                onCameraTap: _showPhotoOptions,
              ),

              const SizedBox(height: 32),

              // Name & email
              Text(
                user.name ?? 'New Tutorix User',
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                user.email,
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: theme.colorScheme.secondary.withValues(alpha: 0.7),
                ),
              ),

              const SizedBox(height: 80),

              // Settings
              SettingTile(
                icon: Icons.shield_outlined,
                title: 'Security history',
                subtitle: 'Login history and sessions',
                onTap: () => _navigateTo(const SecuritySessionsScreen()),
              ),
              SettingTile(
                icon: Icons.notifications_none_rounded,
                title: 'Notifications',
                subtitle: 'Configure your alert preferences',
                onTap: () {},
              ),
              SettingTile(
                icon: Icons.help_outline_rounded,
                title: 'Help & Support',
                subtitle: 'Documentation and direct help',
                onTap: () {},
              ),
              SettingTile(
                icon: Icons.settings_outlined,
                title: 'Settings',
                subtitle: 'Privacy and offline storage',
                onTap: () => _navigateTo(
                  SettingsScreen(
                    user: user,
                    onUserUpdated: widget.onUserUpdated,
                  ),
                ),
              ),

              // ── Admin Debug (only for admins) ─────────────────────────
              if (user.isAdmin) ...[
                SettingTile(
                  icon: Icons.bug_report_outlined,
                  title: 'Admin Debug Console',
                  subtitle: 'System logs and diagnostics',
                  onTap: () => _navigateTo(const AdminDebugScreen()),
                ),
              ],

              // ── Academic Information (only for students) ───────────────
              if (_isStudentSomewhere) ...[
                const SizedBox(height: 28),
                _buildAcademicSection(theme),
              ],

              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAcademicSection(ThemeData theme) {
    if (_loadingAcademic) {
      return const ShimmerWrap(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ShimmerBox(width: 160, height: 14),
            SizedBox(height: 12),
            ShimmerBox(height: 48),
            SizedBox(height: 8),
            ShimmerBox(height: 48),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'Academic Information',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
                letterSpacing: -0.3,
              ),
            ),
            const Spacer(),
            if (_academicProfile != null)
              TextButton.icon(
                onPressed: _editAcademicProfile,
                icon: const Icon(Icons.edit_outlined, size: 16),
                label: const Text('Edit'),
              ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          'Help your teachers understand your learning needs',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.secondary.withValues(alpha: 0.6),
          ),
        ),
        const SizedBox(height: 12),

        if (_academicProfile == null)
          _buildSetupAcademicCard(theme)
        else
          _buildAcademicDetails(theme),
      ],
    );
  }

  Widget _buildSetupAcademicCard(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.primary.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: theme.colorScheme.primary.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              Icons.school_outlined,
              color: theme.colorScheme.primary,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Complete your academic profile',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  'Add your class, board, and subjects',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                  ),
                ),
              ],
            ),
          ),
          FilledButton(
            onPressed: _editAcademicProfile,
            child: const Text('Setup'),
          ),
        ],
      ),
    );
  }

  Widget _buildAcademicDetails(ThemeData theme) {
    final profile = _academicProfile!;
    final masters = _academicMasters;

    // Get display names from masters
    final boardName =
        masters?.boards.where((b) => b.id == profile.board).firstOrNull?.name ??
        profile.board;
    final className =
        masters?.classes
            .where((c) => c.id == profile.classId)
            .firstOrNull
            ?.name ??
        profile.classId;
    final streamName = masters?.streams
        .where((s) => s.id == profile.stream)
        .firstOrNull
        ?.name;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.tertiary.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (profile.schoolName != null && profile.schoolName!.isNotEmpty)
            _AcademicDetailRow(
              icon: Icons.apartment_outlined,
              label: 'School',
              value: profile.schoolName!,
            ),
          if (boardName != null)
            _AcademicDetailRow(
              icon: Icons.menu_book_outlined,
              label: 'Board',
              value: boardName,
            ),
          if (className != null)
            _AcademicDetailRow(
              icon: Icons.class_outlined,
              label: 'Class',
              value: className,
            ),
          if (streamName != null)
            _AcademicDetailRow(
              icon: Icons.category_outlined,
              label: 'Stream',
              value: streamName,
            ),
          if (profile.subjects.isNotEmpty)
            _AcademicDetailRow(
              icon: Icons.book_outlined,
              label: 'Subjects',
              value: profile.subjects
                  .map(
                    (id) =>
                        masters?.subjects
                            .where((s) => s.id == id)
                            .firstOrNull
                            ?.name ??
                        id,
                  )
                  .join(', '),
            ),
          if (profile.competitiveExams.isNotEmpty)
            _AcademicDetailRow(
              icon: Icons.emoji_events_outlined,
              label: 'Preparing for',
              value: profile.competitiveExams
                  .map(
                    (id) =>
                        masters?.competitiveExams
                            .where((e) => e.id == id)
                            .firstOrNull
                            ?.name ??
                        id,
                  )
                  .join(', '),
            ),
        ],
      ),
    );
  }

  void _editAcademicProfile() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AcademicOnboardingScreen(
          onComplete: () {
            Navigator.pop(context);
            _loadAcademicData();
          },
          onRemindLater: () => Navigator.pop(context),
        ),
      ),
    );
  }

  void _navigateTo(Widget screen) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => screen));
  }
}

// ── Private helper widgets ───────────────────────────────────────────────

class _AvatarSection extends StatelessWidget {
  final UserModel user;
  final bool isUploading;
  final VoidCallback onPhotoTap;
  final VoidCallback onEditTap;
  final VoidCallback onCameraTap;

  const _AvatarSection({
    required this.user,
    required this.isUploading,
    required this.onPhotoTap,
    required this.onEditTap,
    required this.onCameraTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Stack(
        children: [
          GestureDetector(
            onTap: isUploading ? null : onPhotoTap,
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: theme.colorScheme.primary.withValues(alpha: 0.1),
                  width: 2,
                ),
              ),
              child: Hero(
                tag: 'user_avatar',
                child: CircleAvatar(
                  radius: 70,
                  backgroundColor: theme.colorScheme.tertiary.withValues(
                    alpha: 0.2,
                  ),
                  backgroundImage: user.picture != null
                      ? NetworkImage(user.picture!)
                      : null,
                  child: user.picture == null
                      ? Icon(
                          Icons.person_rounded,
                          size: 70,
                          color: theme.colorScheme.primary,
                        )
                      : null,
                ),
              ),
            ),
          ),
          if (isUploading)
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.3),
                  shape: BoxShape.circle,
                ),
                child: const Center(
                  child: CircularProgressIndicator(color: Colors.white),
                ),
              ),
            ),
          _OverlayButton(
            alignment: Alignment.topLeft,
            icon: Icons.edit_rounded,
            onTap: onEditTap,
          ),
          _OverlayButton(
            alignment: Alignment.bottomRight,
            icon: Icons.camera_alt_rounded,
            onTap: isUploading ? null : onCameraTap,
          ),
        ],
      ),
    );
  }
}

class _OverlayButton extends StatelessWidget {
  final Alignment alignment;
  final IconData icon;
  final VoidCallback? onTap;

  const _OverlayButton({
    required this.alignment,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isTop = alignment == Alignment.topLeft;
    return Positioned(
      top: isTop ? 0 : null,
      left: isTop ? 0 : null,
      bottom: isTop ? null : 0,
      right: isTop ? null : 0,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: theme.colorScheme.primary,
            shape: BoxShape.circle,
            border: Border.all(color: theme.colorScheme.surface, width: 3),
          ),
          child: Icon(icon, size: 20, color: theme.colorScheme.onPrimary),
        ),
      ),
    );
  }
}

class _PhotoOptionsSheet extends StatelessWidget {
  final UserModel user;
  final VoidCallback onChangeTap;
  final VoidCallback onRemoveTap;

  const _PhotoOptionsSheet({
    required this.user,
    required this.onChangeTap,
    required this.onRemoveTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: theme.colorScheme.primary.withValues(alpha: 0.1),
                  width: 2,
                ),
              ),
              child: CircleAvatar(
                radius: 80,
                backgroundColor: theme.colorScheme.tertiary.withValues(
                  alpha: 0.2,
                ),
                backgroundImage: user.picture != null
                    ? NetworkImage(user.picture!)
                    : null,
                child: user.picture == null
                    ? Icon(
                        Icons.person_rounded,
                        size: 80,
                        color: theme.colorScheme.primary,
                      )
                    : null,
              ),
            ),
          ),
          const SizedBox(height: 32),
          Text(
            'Profile Photo',
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 24),
          ListTile(
            leading: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.photo_library_rounded,
                color: theme.colorScheme.primary,
              ),
            ),
            title: Text(user.picture == null ? 'Add Photo' : 'Change Photo'),
            onTap: onChangeTap,
          ),
          if (user.picture != null) ...[
            const SizedBox(height: 12),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: theme.colorScheme.error.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.delete_outline_rounded,
                  color: theme.colorScheme.error,
                ),
              ),
              title: Text(
                'Remove Photo',
                style: TextStyle(color: theme.colorScheme.error),
              ),
              onTap: onRemoveTap,
            ),
          ],
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

class _AcademicDetailRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _AcademicDetailRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: theme.colorScheme.primary),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: theme.textTheme.bodyMedium?.copyWith(
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
}
