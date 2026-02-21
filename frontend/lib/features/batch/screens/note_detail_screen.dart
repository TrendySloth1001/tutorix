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
                    color: colors.error,
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
                    // Each attachment followed by its description (reading flow)
                    ...note.attachments.expand(
                      (a) => [
                        _AttachmentCard(
                          attachment: a,
                          theme: theme,
                          onTap: () => _openFile(context, a),
                        ),
                        // Description directly below if exists
                        if (a.description != null && a.description!.isNotEmpty)
                          _DescriptionTrailCard(
                            description: a.description!,
                            fileName: a.fileName ?? 'Unnamed file',
                            theme: theme,
                          ),
                      ],
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
            Icon(Icons.warning_amber_rounded, color: theme.colorScheme.error),
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
            style: FilledButton.styleFrom(
              backgroundColor: theme.colorScheme.error,
            ),
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

  static Map<String, (IconData, Color)> _typeConfig(ColorScheme colors) => {
    'pdf': (Icons.picture_as_pdf_rounded, colors.onSurface),
    'image': (Icons.image_rounded, colors.secondary),
    'doc': (Icons.description_rounded, colors.primary),
    'link': (Icons.link_rounded, colors.onSurfaceVariant),
  };

  @override
  Widget build(BuildContext context) {
    final colors = theme.colorScheme;
    final primaryColor = note.attachments.isNotEmpty
        ? (_typeConfig(colors)[note.attachments.first.fileType]?.$2 ??
              colors.primary)
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
              // Large note icon
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
                  Icons.sticky_note_2_outlined,
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

  static Map<String, (IconData, Color, String)> _typeConfig(
    ColorScheme colors,
  ) => {
    'pdf': (Icons.picture_as_pdf_rounded, colors.onSurface, 'PDF'),
    'image': (Icons.image_rounded, colors.secondary, 'Image'),
    'doc': (Icons.description_rounded, colors.primary, 'Document'),
    'link': (Icons.link_rounded, colors.onSurfaceVariant, 'Link'),
  };

  @override
  Widget build(BuildContext context) {
    final colors = theme.colorScheme;
    final config =
        _typeConfig(colors)[attachment.fileType] ??
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

// ═══════════════════════════════════════════════════════════════════════════
// ── DESCRIPTION TRAIL CARD
// ═══════════════════════════════════════════════════════════════════════════

class _DescriptionTrailCard extends StatefulWidget {
  final String description;
  final String fileName;
  final ThemeData theme;

  const _DescriptionTrailCard({
    required this.description,
    required this.fileName,
    required this.theme,
  });

  @override
  State<_DescriptionTrailCard> createState() => _DescriptionTrailCardState();
}

class _DescriptionTrailCardState extends State<_DescriptionTrailCard> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    final colors = widget.theme.colorScheme;
    final needsExpansion =
        widget.description.length > 100 ||
        widget.description.split('\n').length > 2;

    return Padding(
      padding: const EdgeInsets.only(top: 6, bottom: 4),
      child: GestureDetector(
        onTap: needsExpansion
            ? () => setState(() => _isExpanded = !_isExpanded)
            : null,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: colors.surfaceContainerHighest.withValues(alpha: 0.4),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: colors.outline.withValues(alpha: 0.2)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // File reference with trail indicator
              Row(
                children: [
                  Container(
                    width: 3,
                    height: 20,
                    decoration: BoxDecoration(
                      color: colors.primary.withValues(alpha: 0.4),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(
                    Icons.description_outlined,
                    size: 14,
                    color: colors.primary.withValues(alpha: 0.7),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      widget.fileName,
                      style: widget.theme.textTheme.bodySmall?.copyWith(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: colors.onSurface.withValues(alpha: 0.6),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (needsExpansion)
                    Icon(
                      _isExpanded
                          ? Icons.keyboard_arrow_up_rounded
                          : Icons.keyboard_arrow_down_rounded,
                      size: 18,
                      color: colors.primary,
                    ),
                ],
              ),
              const SizedBox(height: 8),
              // Description text
              Text(
                widget.description,
                style: widget.theme.textTheme.bodySmall?.copyWith(
                  fontSize: 13,
                  color: colors.onSurface.withValues(alpha: 0.75),
                  fontStyle: FontStyle.italic,
                  height: 1.5,
                ),
                maxLines: _isExpanded ? null : 2,
                overflow: _isExpanded ? null : TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
