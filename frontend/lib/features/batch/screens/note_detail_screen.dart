import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/batch_note_model.dart';
import 'file_viewer_screen.dart';

/// Comprehensive note detail screen showing title, description,
/// uploader info, and tappable file attachments.
class NoteDetailScreen extends StatelessWidget {
  final BatchNoteModel note;
  final bool canDelete;
  final VoidCallback? onDelete;

  const NoteDetailScreen({
    super.key,
    required this.note,
    this.canDelete = false,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final hasFiles = note.attachments.isNotEmpty;

    return Scaffold(
      backgroundColor: colors.surface,
      body: CustomScrollView(
        slivers: [
          // ── Collapsing App Bar
          SliverAppBar(
            expandedHeight: 180,
            pinned: true,
            backgroundColor: colors.surface,
            surfaceTintColor: Colors.transparent,
            leading: _CircleBackButton(colors: colors),
            actions: [
              if (canDelete)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: _CircleActionButton(
                    icon: Icons.delete_outline_rounded,
                    color: Colors.red,
                    onTap: () => _confirmDelete(context),
                  ),
                ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              background: _HeroHeader(note: note, theme: theme),
            ),
          ),

          // ── Body
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Title
                  Text(
                    note.title,
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      letterSpacing: -0.3,
                    ),
                  ),
                  const SizedBox(height: 12),

                  // ── Meta row
                  _MetaRow(note: note, theme: theme),
                  const SizedBox(height: 20),

                  // ── Description
                  if (note.description != null &&
                      note.description!.trim().isNotEmpty) ...[
                    _SectionHeader(
                      icon: Icons.notes_rounded,
                      label: 'Description',
                      theme: theme,
                    ),
                    const SizedBox(height: 10),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: colors.surfaceContainerLowest,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: colors.onSurface.withValues(alpha: 0.05),
                        ),
                      ),
                      child: Text(
                        note.description!,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: colors.onSurface.withValues(alpha: 0.75),
                          height: 1.6,
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],

                  // ── Attachments section
                  if (hasFiles) ...[
                    _SectionHeader(
                      icon: Icons.attach_file_rounded,
                      label: 'Attachments (${note.attachments.length})',
                      theme: theme,
                      trailing: Text(
                        _formatBytes(note.totalSize),
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: colors.onSurface.withValues(alpha: 0.4),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    ...note.attachments.map(
                      (a) => _AttachmentCard(
                        attachment: a,
                        theme: theme,
                        onTap: () => _openFile(context, a),
                      ),
                    ),
                  ],

                  if (!hasFiles &&
                      (note.description == null ||
                          note.description!.trim().isEmpty))
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 60),
                        child: Column(
                          children: [
                            Icon(
                              Icons.note_outlined,
                              size: 48,
                              color: colors.onSurface.withValues(alpha: 0.15),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'This note has no content yet',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: colors.onSurface.withValues(alpha: 0.35),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _openFile(BuildContext context, NoteAttachment attachment) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => FileViewerScreen(attachment: attachment),
      ),
    );
  }

  void _confirmDelete(BuildContext context) {
    final theme = Theme.of(context);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.red.shade400),
            const SizedBox(width: 10),
            const Text('Delete Note'),
          ],
        ),
        content: Text(
          'This will permanently delete "${note.title}" and all its attachments. This action cannot be undone.',
          style: theme.textTheme.bodyMedium,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              onDelete?.call();
              Navigator.pop(context, true);
            },
            style: FilledButton.styleFrom(backgroundColor: Colors.red.shade600),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  static String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    }
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// ── HERO HEADER
// ═══════════════════════════════════════════════════════════════════════════

class _HeroHeader extends StatelessWidget {
  final BatchNoteModel note;
  final ThemeData theme;
  const _HeroHeader({required this.note, required this.theme});

  static const _typeConfig = {
    'pdf': (Icons.picture_as_pdf_rounded, Color(0xFFE53935)),
    'image': (Icons.image_rounded, Color(0xFF8E24AA)),
    'doc': (Icons.description_rounded, Color(0xFF1E88E5)),
    'link': (Icons.link_rounded, Color(0xFF00897B)),
  };

  @override
  Widget build(BuildContext context) {
    final colors = theme.colorScheme;
    final primaryColor = note.attachments.isNotEmpty
        ? (_typeConfig[note.attachments.first.fileType]?.$2 ?? colors.primary)
        : colors.primary;

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [primaryColor.withValues(alpha: 0.15), colors.surface],
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 56, 20, 20),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              // Large file type icon
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: primaryColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: primaryColor.withValues(alpha: 0.15),
                  ),
                ),
                child: Icon(
                  note.attachments.isNotEmpty
                      ? (_typeConfig[note.attachments.first.fileType]?.$1 ??
                            Icons.note_outlined)
                      : Icons.note_outlined,
                  size: 32,
                  color: primaryColor,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (note.attachments.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: primaryColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          '${note.attachments.length} file${note.attachments.length == 1 ? '' : 's'}',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: primaryColor,
                          ),
                        ),
                      ),
                    const SizedBox(height: 6),
                    Text(
                      note.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        letterSpacing: -0.3,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// ── META ROW
// ═══════════════════════════════════════════════════════════════════════════

class _MetaRow extends StatelessWidget {
  final BatchNoteModel note;
  final ThemeData theme;
  const _MetaRow({required this.note, required this.theme});

  @override
  Widget build(BuildContext context) {
    final colors = theme.colorScheme;

    return Wrap(
      spacing: 12,
      runSpacing: 8,
      children: [
        if (note.uploadedBy != null)
          _MetaChip(
            icon: Icons.person_outline_rounded,
            label: note.uploadedBy!.name ?? 'Unknown',
            color: colors.primary,
            theme: theme,
          ),
        if (note.createdAt != null)
          _MetaChip(
            icon: Icons.access_time_rounded,
            label: _formatDate(note.createdAt!),
            color: colors.onSurface.withValues(alpha: 0.5),
            theme: theme,
          ),
        if (note.attachments.isNotEmpty)
          _MetaChip(
            icon: Icons.folder_outlined,
            label: NoteDetailScreen._formatBytes(note.totalSize),
            color: colors.onSurface.withValues(alpha: 0.5),
            theme: theme,
          ),
      ],
    );
  }

  String _formatDate(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return DateFormat('MMM d, yyyy').format(dt);
  }
}

class _MetaChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final ThemeData theme;
  const _MetaChip({
    required this.icon,
    required this.label,
    required this.color,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 5),
        Text(
          label,
          style: theme.textTheme.bodySmall?.copyWith(
            color: color,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// ── SECTION HEADER
// ═══════════════════════════════════════════════════════════════════════════

class _SectionHeader extends StatelessWidget {
  final IconData icon;
  final String label;
  final ThemeData theme;
  final Widget? trailing;
  const _SectionHeader({
    required this.icon,
    required this.label,
    required this.theme,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final colors = theme.colorScheme;
    return Row(
      children: [
        Icon(icon, size: 16, color: colors.onSurface.withValues(alpha: 0.4)),
        const SizedBox(width: 8),
        Text(
          label,
          style: theme.textTheme.labelLarge?.copyWith(
            fontWeight: FontWeight.w700,
            color: colors.onSurface.withValues(alpha: 0.6),
            letterSpacing: 0.2,
          ),
        ),
        if (trailing != null) ...[const Spacer(), trailing!],
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// ── ATTACHMENT CARD
// ═══════════════════════════════════════════════════════════════════════════

class _AttachmentCard extends StatelessWidget {
  final NoteAttachment attachment;
  final ThemeData theme;
  final VoidCallback onTap;
  const _AttachmentCard({
    required this.attachment,
    required this.theme,
    required this.onTap,
  });

  static const _typeConfig = {
    'pdf': (Icons.picture_as_pdf_rounded, Color(0xFFE53935), 'PDF'),
    'image': (Icons.image_rounded, Color(0xFF8E24AA), 'Image'),
    'doc': (Icons.description_rounded, Color(0xFF1E88E5), 'Document'),
    'link': (Icons.link_rounded, Color(0xFF00897B), 'Link'),
  };

  @override
  Widget build(BuildContext context) {
    final colors = theme.colorScheme;
    final config =
        _typeConfig[attachment.fileType] ??
        (Icons.attach_file_rounded, colors.primary, 'File');
    final (icon, color, typeLabel) = config;
    final isImage = attachment.fileType == 'image';

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: colors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: color.withValues(alpha: 0.1)),
            ),
            child: Row(
              children: [
                // ── Thumbnail / Icon
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: color.withValues(alpha: 0.12)),
                  ),
                  child: isImage && attachment.url.isNotEmpty
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(13),
                          child: Image.network(
                            attachment.url,
                            fit: BoxFit.cover,
                            errorBuilder: (_, _, _) =>
                                Icon(icon, color: color, size: 24),
                          ),
                        )
                      : Icon(icon, color: color, size: 24),
                ),
                const SizedBox(width: 14),

                // ── File info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        attachment.fileName ?? 'Unnamed file',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: color.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              typeLabel,
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: color,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            attachment.formattedSize,
                            style: theme.textTheme.bodySmall?.copyWith(
                              fontSize: 11,
                              color: colors.onSurface.withValues(alpha: 0.4),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // ── Open icon
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.06),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    isImage ? Icons.zoom_in_rounded : Icons.open_in_new_rounded,
                    size: 18,
                    color: color,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// ── CIRCLE BUTTONS
// ═══════════════════════════════════════════════════════════════════════════

class _CircleBackButton extends StatelessWidget {
  final ColorScheme colors;
  const _CircleBackButton({required this.colors});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(8),
      child: Material(
        color: colors.surface.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(12),
        elevation: 1,
        child: InkWell(
          onTap: () => Navigator.pop(context),
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: Icon(
              Icons.arrow_back_rounded,
              size: 20,
              color: colors.onSurface,
            ),
          ),
        ),
      ),
    );
  }
}

class _CircleActionButton extends StatelessWidget {
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  const _CircleActionButton({
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.9),
      borderRadius: BorderRadius.circular(12),
      elevation: 1,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Icon(icon, size: 20, color: color),
        ),
      ),
    );
  }
}
