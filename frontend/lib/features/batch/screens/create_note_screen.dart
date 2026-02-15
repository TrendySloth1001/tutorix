import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import '../../coaching/models/coaching_model.dart';
import '../services/batch_service.dart';

/// Screen to create a new note with multiple file attachments.
class CreateNoteScreen extends StatefulWidget {
  final CoachingModel coaching;
  final String batchId;

  const CreateNoteScreen({
    super.key,
    required this.coaching,
    required this.batchId,
  });

  @override
  State<CreateNoteScreen> createState() => _CreateNoteScreenState();
}

class _CreateNoteScreenState extends State<CreateNoteScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final BatchService _batchService = BatchService();

  final _titleCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  bool _isSaving = false;

  // Multi-file state with descriptions
  final List<_FileWithDescription> _pickedFiles = [];

  // Storage
  int _storageUsed = 0;
  int _storageLimit = 524288000; // 500 MB default
  bool _storageLoaded = false;

  late AnimationController _animCtrl;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _fadeAnim = CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut);
    _animCtrl.forward();
    _loadStorage();
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    _titleCtrl.dispose();
    _descCtrl.dispose();
    for (final f in _pickedFiles) {
      f.descriptionController.dispose();
    }
    super.dispose();
  }

  Future<void> _loadStorage() async {
    try {
      final data = await _batchService.getStorageUsage(widget.coaching.id);
      if (!mounted) return;
      setState(() {
        _storageUsed = (data['used'] as num?)?.toInt() ?? 0;
        _storageLimit = (data['limit'] as num?)?.toInt() ?? 524288000;
        _storageLoaded = true;
      });
    } catch (_) {
      if (mounted) setState(() => _storageLoaded = true);
    }
  }

  Future<void> _pickFiles() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowMultiple: true,
      allowedExtensions: [
        'pdf',
        'doc',
        'docx',
        'xls',
        'xlsx',
        'ppt',
        'pptx',
        'txt',
        'png',
        'jpg',
        'jpeg',
        'gif',
        'webp',
      ],
      withData: false,
    );
    if (result != null && result.files.isNotEmpty) {
      setState(() {
        for (final f in result.files) {
          if (!_pickedFiles.any((e) => e.file.path == f.path)) {
            _pickedFiles.add(_FileWithDescription(
              file: f,
              descriptionController: TextEditingController(),
            ));
          }
        }
      });
    }
  }

  void _removeFile(int index) {
    setState(() {
      _pickedFiles[index].descriptionController.dispose();
      _pickedFiles.removeAt(index);
    });
  }

  int get _totalPickedSize =>
      _pickedFiles.fold(0, (sum, f) => sum + f.file.size);

  bool get _exceedsStorage => (_storageUsed + _totalPickedSize) > _storageLimit;

  String _fileTypeFromExtension(String name) {
    final ext = name.split('.').last.toLowerCase();
    if (ext == 'pdf') return 'pdf';
    if (['png', 'jpg', 'jpeg', 'gif', 'webp'].contains(ext)) return 'image';
    if (['doc', 'docx', 'txt', 'ppt', 'pptx', 'xls', 'xlsx'].contains(ext)) {
      return 'doc';
    }
    return 'pdf';
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_exceedsStorage) {
      _showError(
        'Not enough storage space. Remove some files or free up space.',
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      List<Map<String, dynamic>>? attachments;

      if (_pickedFiles.isNotEmpty) {
        final paths = _pickedFiles
            .where((f) => f.file.path != null)
            .map((f) => f.file.path!)
            .toList();

        if (paths.isNotEmpty) {
          final uploadResult = await _batchService.uploadNoteFiles(paths);
          final files = uploadResult['files'] as List<dynamic>;
          attachments = List.generate(files.length, (i) {
            final m = files[i] as Map<String, dynamic>;
            final description = _pickedFiles[i].descriptionController.text.trim();
            return {
              'url': m['url'],
              'fileName': m['fileName'],
              'description': description.isEmpty ? null : description,
              'fileSize': m['size'] ?? 0,
              'mimeType': m['mimeType'],
              'fileType': _fileTypeFromExtension(
                (m['fileName'] as String?) ?? 'file.pdf',
              ),
            };
          });
        }
      }

      await _batchService.createNote(
        widget.coaching.id,
        widget.batchId,
        title: _titleCtrl.text.trim(),
        description: _descCtrl.text.trim().isEmpty
            ? null
            : _descCtrl.text.trim(),
        attachments: attachments,
      );
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      _showError('$e');
    }
    if (mounted) setState(() => _isSaving = false);
  }

  void _showError(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: Colors.red.shade700,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: AppBar(
        title: const Text('Share Note'),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.transparent,
      ),
      body: FadeTransition(
        opacity: _fadeAnim,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Storage indicator
                if (_storageLoaded) ...[
                  _buildStorageBar(theme),
                  const SizedBox(height: 22),
                ],

                // ── Title
                _FieldLabel('Title', isRequired: true),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _titleCtrl,
                  decoration: _inputDeco(
                    'e.g. Chapter 5 — Quadratic Equations',
                    Icons.title_rounded,
                  ),
                  validator: (v) => v == null || v.trim().isEmpty
                      ? 'Title is required'
                      : null,
                  textCapitalization: TextCapitalization.sentences,
                ),
                const SizedBox(height: 22),

                // ── Description
                _FieldLabel('Description'),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _descCtrl,
                  decoration: _inputDeco(
                    'Brief description (optional)',
                    Icons.notes_rounded,
                  ),
                  maxLines: 2,
                  textCapitalization: TextCapitalization.sentences,
                ),
                const SizedBox(height: 24),

                // ── Attachments area
                _FieldLabel('Attachments'),
                const SizedBox(height: 10),
                _buildAttachmentsArea(theme),
                const SizedBox(height: 36),

                // ── Save button
                SizedBox(
                  width: double.infinity,
                  height: 54,
                  child: FilledButton(
                    onPressed: _isSaving ? null : _save,
                    style: FilledButton.styleFrom(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      elevation: 0,
                    ),
                    child: _isSaving
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              color: Colors.white,
                            ),
                          )
                        : Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.send_rounded, size: 18),
                              const SizedBox(width: 8),
                              Text(
                                _pickedFiles.isEmpty
                                    ? 'Share Note'
                                    : 'Share with ${_pickedFiles.length} file${_pickedFiles.length == 1 ? '' : 's'}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 15,
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
      ),
    );
  }

  // ── Storage bar ────────────────────────────────────────────────────

  Widget _buildStorageBar(ThemeData theme) {
    final usedAfter = _storageUsed + _totalPickedSize;
    final ratio = _storageLimit > 0
        ? (usedAfter / _storageLimit).clamp(0.0, 1.0)
        : 0.0;
    final exceeds = _exceedsStorage;

    final barColor = exceeds
        ? Colors.red.shade400
        : ratio > 0.8
        ? Colors.orange.shade400
        : theme.colorScheme.primary;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: exceeds
              ? Colors.red.withValues(alpha: 0.2)
              : theme.colorScheme.onSurface.withValues(alpha: 0.06),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.cloud_outlined, size: 16, color: barColor),
              const SizedBox(width: 6),
              Text(
                'Storage',
                style: theme.textTheme.labelMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                ),
              ),
              const Spacer(),
              Text(
                '${_formatBytes(usedAfter)} / ${_formatBytes(_storageLimit)}',
                style: theme.textTheme.labelSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: barColor,
                  fontSize: 11,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: ratio,
              minHeight: 6,
              backgroundColor: theme.colorScheme.onSurface.withValues(
                alpha: 0.06,
              ),
              valueColor: AlwaysStoppedAnimation(barColor),
            ),
          ),
          if (_totalPickedSize > 0) ...[
            const SizedBox(height: 6),
            Text(
              '${_formatBytes(_totalPickedSize)} will be used by new files',
              style: theme.textTheme.bodySmall?.copyWith(
                fontSize: 11,
                color: exceeds
                    ? Colors.red.shade600
                    : theme.colorScheme.onSurface.withValues(alpha: 0.4),
              ),
            ),
          ],
          if (exceeds)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                'Not enough space — remove some files',
                style: theme.textTheme.bodySmall?.copyWith(
                  fontSize: 11,
                  color: Colors.red.shade600,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ── Attachments area ───────────────────────────────────────────────

  Widget _buildAttachmentsArea(ThemeData theme) {
    return Column(
      children: [
        if (_pickedFiles.isNotEmpty) ...[
          ...List.generate(_pickedFiles.length, (i) {
            final fileWithDesc = _pickedFiles[i];
            return _FileCardWithDescription(
              name: fileWithDesc.file.name,
              size: fileWithDesc.file.size,
              fileType: _fileTypeFromExtension(fileWithDesc.file.name),
              descriptionController: fileWithDesc.descriptionController,
              onRemove: () => _removeFile(i),
            );
          }),
          const SizedBox(height: 12),
        ],

        GestureDetector(
          onTap: _pickFiles,
          child: Container(
            width: double.infinity,
            padding: EdgeInsets.symmetric(
              vertical: _pickedFiles.isEmpty ? 36 : 16,
              horizontal: 24,
            ),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerLowest,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.1),
                width: 1.5,
                strokeAlign: BorderSide.strokeAlignInside,
              ),
            ),
            child: _pickedFiles.isEmpty
                ? Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primary.withValues(
                            alpha: 0.08,
                          ),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.attach_file_rounded,
                          size: 28,
                          color: theme.colorScheme.primary.withValues(
                            alpha: 0.6,
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      Text(
                        'Tap to add files',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: theme.colorScheme.onSurface.withValues(
                            alpha: 0.7,
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'PDF, DOC, XLS, PPT, Images — up to 15 MB each',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurface.withValues(
                            alpha: 0.35,
                          ),
                          fontSize: 11,
                        ),
                      ),
                    ],
                  )
                : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.add_rounded,
                        size: 18,
                        color: theme.colorScheme.primary,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Add more files',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ],
    );
  }

  InputDecoration _inputDeco(String hint, IconData icon) {
    final theme = Theme.of(context);
    return InputDecoration(
      hintText: hint,
      prefixIcon: Icon(
        icon,
        size: 20,
        color: theme.colorScheme.onSurface.withValues(alpha: 0.3),
      ),
      filled: true,
      fillColor: theme.colorScheme.surfaceContainerLowest,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(
          color: theme.colorScheme.onSurface.withValues(alpha: 0.06),
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(
          color: theme.colorScheme.primary.withValues(alpha: 0.4),
          width: 1.5,
        ),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    );
  }
}

// ── File card with description ──────────────────────────────────────

class _FileCardWithDescription extends StatefulWidget {
  final String name;
  final int size;
  final String fileType;
  final TextEditingController descriptionController;
  final VoidCallback onRemove;

  const _FileCardWithDescription({
    required this.name,
    required this.size,
    required this.fileType,
    required this.descriptionController,
    required this.onRemove,
  });

  @override
  State<_FileCardWithDescription> createState() =>
      _FileCardWithDescriptionState();
}

class _FileCardWithDescriptionState extends State<_FileCardWithDescription> {
  bool _isExpanded = false;

  static const _typeConfig = {
    'pdf': (Icons.picture_as_pdf_rounded, Color(0xFFE53935)),
    'image': (Icons.image_rounded, Color(0xFF8E24AA)),
    'doc': (Icons.description_rounded, Color(0xFF1E88E5)),
  };

  String get _formattedSize {
    if (widget.size < 1024) return '${widget.size} B';
    if (widget.size < 1024 * 1024) {
      return '${(widget.size / 1024).toStringAsFixed(1)} KB';
    }
    return '${(widget.size / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final config = _typeConfig[widget.fileType] ??
        (Icons.attach_file_rounded, theme.colorScheme.primary);
    final color = config.$2;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: color.withValues(alpha: 0.15),
          width: 1.5,
        ),
      ),
      child: Column(
        children: [
          // File header
          InkWell(
            onTap: () => setState(() => _isExpanded = !_isExpanded),
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(config.$1, size: 22, color: color),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _formattedSize,
                          style: theme.textTheme.bodySmall?.copyWith(
                            fontSize: 12,
                            color: theme.colorScheme.onSurface
                                .withValues(alpha: 0.5),
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Expand/collapse button
                  IconButton(
                    onPressed: () => setState(() => _isExpanded = !_isExpanded),
                    icon: Icon(
                      _isExpanded
                          ? Icons.expand_less_rounded
                          : Icons.expand_more_rounded,
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                    ),
                    constraints: const BoxConstraints(
                      minWidth: 40,
                      minHeight: 40,
                    ),
                    padding: EdgeInsets.zero,
                  ),
                  // Remove button
                  GestureDetector(
                    onTap: widget.onRemove,
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.red.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        Icons.close_rounded,
                        size: 18,
                        color: Colors.red.shade600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Description field (expandable)
          if (_isExpanded)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Divider(
                    color: color.withValues(alpha: 0.15),
                    height: 1,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Description (optional)',
                    style: theme.textTheme.labelSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                      color:
                          theme.colorScheme.onSurface.withValues(alpha: 0.6),
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: widget.descriptionController,
                    decoration: InputDecoration(
                      hintText: 'e.g., Solutions for exercises 1-10',
                      hintStyle: TextStyle(
                        fontSize: 13,
                        color:
                            theme.colorScheme.onSurface.withValues(alpha: 0.3),
                      ),
                      filled: true,
                      fillColor: theme.colorScheme.surface,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                          color: color.withValues(alpha: 0.2),
                        ),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                          color: color.withValues(alpha: 0.2),
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                          color: color.withValues(alpha: 0.5),
                          width: 1.5,
                        ),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 12,
                      ),
                    ),
                    maxLines: 2,
                    style: theme.textTheme.bodySmall?.copyWith(fontSize: 13),
                    textCapitalization: TextCapitalization.sentences,
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

// ── File with description wrapper ────────────────────────────────────

class _FileWithDescription {
  final PlatformFile file;
  final TextEditingController descriptionController;

  _FileWithDescription({
    required this.file,
    required this.descriptionController,
  });
}

// ── Field label ──────────────────────────────────────────────────────

class _FieldLabel extends StatelessWidget {
  final String text;
  final bool isRequired;
  const _FieldLabel(this.text, {this.isRequired = false});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Text(
          text,
          style: theme.textTheme.labelLarge?.copyWith(
            fontWeight: FontWeight.w600,
            color: theme.colorScheme.onSurface.withValues(alpha: 0.75),
            letterSpacing: 0.2,
          ),
        ),
        if (isRequired)
          Text(
            ' *',
            style: TextStyle(
              color: Colors.red.shade400,
              fontWeight: FontWeight.w600,
            ),
          ),
      ],
    );
  }
}
