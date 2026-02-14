import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../../shared/models/user_model.dart';
import '../../../shared/widgets/setting_tile.dart';
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
  final ImagePicker _picker = ImagePicker();
  bool _isUploading = false;

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
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profile picture updated successfully')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to update avatar: $e')));
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
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profile picture removed')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to remove avatar: $e')));
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

              const SizedBox(height: 40),
            ],
          ),
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
                  color: Colors.redAccent.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.delete_outline_rounded,
                  color: Colors.redAccent,
                ),
              ),
              title: const Text(
                'Remove Photo',
                style: TextStyle(color: Colors.redAccent),
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
