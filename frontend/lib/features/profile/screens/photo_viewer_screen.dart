import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../../shared/models/user_model.dart';
import '../services/upload_service.dart';
import '../services/user_service.dart';

class PhotoViewerScreen extends StatefulWidget {
  final UserModel user;
  final ValueChanged<UserModel>? onUserUpdated;

  const PhotoViewerScreen({
    super.key,
    required this.user,
    this.onUserUpdated,
  });

  @override
  State<PhotoViewerScreen> createState() => _PhotoViewerScreenState();
}

class _PhotoViewerScreenState extends State<PhotoViewerScreen> {
  final UploadService _uploadService = UploadService();
  final UserService _userService = UserService();
  final ImagePicker _picker = ImagePicker();
  bool _isUploading = false;
  late UserModel _currentUser;

  @override
  void initState() {
    super.initState();
    _currentUser = widget.user;
  }

  // ── Actions ────────────────────────────────────────────────────────────

  Future<void> _updateAvatar() async {
    try {
      final image = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );
      if (image == null) return;

      setState(() => _isUploading = true);

      final updated = await _uploadService.uploadAvatar(File(image.path));
      if (updated != null && mounted) {
        setState(() => _currentUser = updated);
        widget.onUserUpdated?.call(updated);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profile picture updated')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update avatar: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  Future<void> _removeAvatar() async {
    try {
      setState(() => _isUploading = true);
      final updated = await _userService.updateProfile(picture: null);
      if (updated != null && mounted) {
        setState(() => _currentUser = updated);
        widget.onUserUpdated?.call(updated);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profile picture removed')),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to remove avatar: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  void _showOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _PhotoOptionsSheet(
        hasPhoto: _currentUser.picture != null,
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
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black.withValues(alpha: 0.5),
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text(
          _currentUser.name ?? 'Profile Photo',
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_rounded),
            onPressed: _isUploading ? null : _showOptions,
          ),
        ],
      ),
      body: Center(
        child: Hero(
          tag: 'user_avatar',
          child: InteractiveViewer(
            minScale: 1.0,
            maxScale: 4.0,
            child: _isUploading
                ? const CircularProgressIndicator(color: Colors.white)
                : _currentUser.picture != null
                    ? Image.network(
                        _currentUser.picture!,
                        fit: BoxFit.contain,
                        width: double.infinity,
                        height: double.infinity,
                        loadingBuilder: (_, child, progress) =>
                            progress == null
                                ? child
                                : const Center(
                                    child: CircularProgressIndicator(
                                        color: Colors.white),
                                  ),
                      )
                    : const Icon(
                        Icons.person_rounded,
                        size: 200,
                        color: Colors.white24,
                      ),
          ),
        ),
      ),
    );
  }
}

// ── Private bottom-sheet extracted for readability ────────────────────────

class _PhotoOptionsSheet extends StatelessWidget {
  final bool hasPhoto;
  final VoidCallback onChangeTap;
  final VoidCallback onRemoveTap;

  const _PhotoOptionsSheet({
    required this.hasPhoto,
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
          Text(
            'Profile Photo',
            style: theme.textTheme.titleLarge
                ?.copyWith(fontWeight: FontWeight.bold),
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
            title: Text(hasPhoto ? 'Change Photo' : 'Add Photo'),
            onTap: onChangeTap,
          ),
          if (hasPhoto) ...[
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
