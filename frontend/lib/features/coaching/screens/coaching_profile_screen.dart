import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../../shared/models/user_model.dart';
import '../models/coaching_model.dart';
import '../services/coaching_service.dart';

/// Coaching profile — clean, premium design.
/// Uses bottom sheets (no AlertDialog). Logo upload via image_picker.
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
  final ImagePicker _picker = ImagePicker();
  bool _isUploadingLogo = false;

  late CoachingModel _coaching;

  @override
  void initState() {
    super.initState();
    _coaching = widget.coaching;
  }

  bool get _isOwner => _coaching.ownerId == widget.user.id;

  // ── Bottom sheets ──────────────────────────────────────────────────────

  Future<void> _editName() async {
    final c = TextEditingController(text: _coaching.name);
    final r = await _showEditSheet(
      title: 'Edit Name',
      hint: 'Coaching name',
      controller: c,
    );
    if (r != null && r.isNotEmpty && r != _coaching.name)
      await _updateCoaching(name: r);
  }

  Future<void> _editDescription() async {
    final c = TextEditingController(text: _coaching.description ?? '');
    final r = await _showEditSheet(
      title: 'Edit Description',
      hint: 'Add a description…',
      controller: c,
      maxLines: 4,
    );
    if (r != null && r != (_coaching.description ?? ''))
      await _updateCoaching(description: r);
  }

  Future<String?> _showEditSheet({
    required String title,
    required String hint,
    required TextEditingController controller,
    int maxLines = 1,
  }) {
    return showModalBottomSheet<String>(
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
            MediaQuery.of(ctx).viewInsets.bottom + 16,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _grabHandle(theme),
              const SizedBox(height: 14),
              Text(
                title,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: controller,
                autofocus: true,
                maxLines: maxLines,
                decoration: InputDecoration(
                  hintText: hint,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: 10),
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
  }

  // ── Logo upload ────────────────────────────────────────────────────────

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
      await _updateCoaching(logo: url);
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Upload failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
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
              _grabHandle(theme),
              const SizedBox(height: 14),
              Text(
                'Change Logo',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 10),
              _SourceOption(
                icon: Icons.camera_alt_rounded,
                label: 'Camera',
                onTap: () => Navigator.pop(ctx, ImageSource.camera),
              ),
              _SourceOption(
                icon: Icons.photo_library_rounded,
                label: 'Gallery',
                onTap: () => Navigator.pop(ctx, ImageSource.gallery),
              ),
              const SizedBox(height: 4),
            ],
          ),
        ),
      ),
    );
  }

  // ── Update helper ──────────────────────────────────────────────────────

  Future<void> _updateCoaching({
    String? name,
    String? description,
    String? logo,
  }) async {
    try {
      final updated = await _coachingService.updateCoaching(
        id: _coaching.id,
        name: name,
        description: description,
        logo: logo,
      );
      if (updated != null && mounted) {
        setState(() => _coaching = updated);
        widget.onCoachingUpdated?.call(updated);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Updated'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Update failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
    }
  }

  // ── Build ──────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      body: ListView(
        padding: EdgeInsets.fromLTRB(
          20,
          MediaQuery.of(context).padding.top + 12,
          20,
          100,
        ),
        children: [
          // ── Back button ──
          if (widget.onBack != null)
            Align(
              alignment: Alignment.centerRight,
              child: GestureDetector(
                onTap: widget.onBack,
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    Icons.close_rounded,
                    size: 20,
                    color: theme.colorScheme.primary,
                  ),
                ),
              ),
            ),

          const SizedBox(height: 16),

          // ── Logo ──
          Center(
            child: GestureDetector(
              onTap: _isOwner && !_isUploadingLogo ? _changeLogo : null,
              child: Stack(
                children: [
                  Container(
                    width: 88,
                    height: 88,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary.withValues(alpha: 0.06),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: theme.colorScheme.primary.withValues(
                          alpha: 0.06,
                        ),
                        width: 2,
                      ),
                    ),
                    child: _coaching.logo != null
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(18),
                            child: Image.network(
                              _coaching.logo!,
                              fit: BoxFit.cover,
                            ),
                          )
                        : Icon(
                            Icons.school_rounded,
                            size: 38,
                            color: theme.colorScheme.primary.withValues(
                              alpha: 0.2,
                            ),
                          ),
                  ),
                  if (_isUploadingLogo)
                    Positioned.fill(
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.3),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Center(
                          child: SizedBox(
                            width: 22,
                            height: 22,
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
                      bottom: -2,
                      right: -2,
                      child: Container(
                        padding: const EdgeInsets.all(5),
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
                          size: 12,
                          color: theme.colorScheme.onPrimary,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 14),

          // ── Name + slug ──
          Center(
            child: Text(
              _coaching.name,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
                letterSpacing: -0.3,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 2),
          Center(
            child: Text(
              _coaching.slug,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.secondary.withValues(alpha: 0.4),
              ),
            ),
          ),

          if (_coaching.description != null &&
              _coaching.description!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Center(
              child: Text(
                _coaching.description!,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.secondary.withValues(alpha: 0.6),
                  height: 1.4,
                ),
              ),
            ),
          ],

          const SizedBox(height: 16),

          // ── Status badge ──
          Center(child: _StatusBadge(status: _coaching.status)),

          const SizedBox(height: 24),

          // ── Settings section ──
          if (_isOwner) ...[
            _SectionLabel(text: 'Settings'),
            const SizedBox(height: 8),
            _SettingRow(
              icon: Icons.edit_rounded,
              label: 'Name',
              value: _coaching.name,
              onTap: _editName,
            ),
            _SettingRow(
              icon: Icons.description_outlined,
              label: 'Description',
              value: _coaching.description ?? 'Add a description…',
              onTap: _editDescription,
            ),
            _SettingRow(
              icon: Icons.image_outlined,
              label: 'Logo',
              value: 'Update coaching logo',
              onTap: _changeLogo,
            ),
          ],

          const SizedBox(height: 20),

          // ── Info section ──
          _SectionLabel(text: 'Info'),
          const SizedBox(height: 8),
          _InfoRow(
            label: 'Created',
            value: _coaching.createdAt != null
                ? _formatDate(_coaching.createdAt!)
                : 'Recently',
          ),
          _InfoRow(
            label: 'Status',
            value: _coaching.status == 'active' ? 'Active' : 'Suspended',
          ),
          _InfoRow(label: 'Slug', value: _coaching.slug),
        ],
      ),
    );
  }

  String _formatDate(DateTime dt) {
    const m = [
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
    return '${m[dt.month - 1]} ${dt.day}, ${dt.year}';
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// Private widgets
// ═══════════════════════════════════════════════════════════════════════════

Widget _grabHandle(ThemeData theme) => Center(
  child: Container(
    width: 36,
    height: 4,
    decoration: BoxDecoration(
      color: theme.colorScheme.secondary.withValues(alpha: 0.2),
      borderRadius: BorderRadius.circular(2),
    ),
  ),
);

class _SourceOption extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _SourceOption({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListTile(
      dense: true,
      leading: Icon(icon, size: 20, color: theme.colorScheme.primary),
      title: Text(
        label,
        style: theme.textTheme.bodyMedium?.copyWith(
          fontWeight: FontWeight.w600,
        ),
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      onTap: onTap,
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel({required this.text});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Text(
      text.toUpperCase(),
      style: theme.textTheme.labelSmall?.copyWith(
        color: theme.colorScheme.secondary.withValues(alpha: 0.4),
        fontWeight: FontWeight.bold,
        letterSpacing: 1.2,
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final String status;
  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    final active = status == 'active';
    final color = active ? const Color(0xFF5B8C5A) : Colors.red;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            active ? Icons.check_circle_rounded : Icons.pause_circle_rounded,
            size: 14,
            color: color,
          ),
          const SizedBox(width: 5),
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

class _SettingRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final VoidCallback onTap;
  const _SettingRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 12),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, size: 18, color: theme.colorScheme.primary),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        label,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        value,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.secondary.withValues(
                            alpha: 0.5,
                          ),
                          fontSize: 11,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.chevron_right_rounded,
                  size: 18,
                  color: theme.colorScheme.primary.withValues(alpha: 0.2),
                ),
              ],
            ),
          ),
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
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
      child: Row(
        children: [
          SizedBox(
            width: 80,
            child: Text(
              label,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.secondary.withValues(alpha: 0.45),
                fontWeight: FontWeight.w500,
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
