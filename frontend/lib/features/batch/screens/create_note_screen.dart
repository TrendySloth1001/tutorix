import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import '../../coaching/models/coaching_model.dart';
import '../services/batch_service.dart';

/// Screen to create a new note (file upload or link) in a batch.
/// No video option. URL is optional — user can upload a file instead.
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
  final _urlCtrl = TextEditingController();
  String _fileType = 'pdf';
  bool _isSaving = false;
  bool _isUploading = false;

  // File picker state
  PlatformFile? _pickedFile;
  String? _uploadedUrl;
  String? _uploadedFileName;

  late AnimationController _animCtrl;
  late Animation<double> _fadeAnim;

  static const _fileTypes = [
    ('pdf', 'PDF', Icons.picture_as_pdf_rounded, Color(0xFFE53935)),
    ('doc', 'Document', Icons.description_rounded, Color(0xFF1E88E5)),
    ('image', 'Image', Icons.image_rounded, Color(0xFF8E24AA)),
    ('link', 'Link', Icons.link_rounded, Color(0xFF00897B)),
  ];

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _fadeAnim = CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut);
    _animCtrl.forward();
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    _titleCtrl.dispose();
    _descCtrl.dispose();
    _urlCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
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
        _pickedFile = result.files.first;
        _uploadedUrl = null;
      });
    }
  }

  Future<void> _uploadFile() async {
    if (_pickedFile?.path == null) return;
    setState(() => _isUploading = true);
    try {
      final result = await _batchService.uploadNoteFile(_pickedFile!.path!);
      setState(() {
        _uploadedUrl = result['url'] as String?;
        _uploadedFileName = result['fileName'] as String? ?? _pickedFile!.name;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Upload failed: $e'),
            backgroundColor: Colors.red.shade700,
          ),
        );
      }
    }
    if (mounted) setState(() => _isUploading = false);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    // Determine the URL: uploaded file URL or manual URL
    String? finalUrl = _uploadedUrl;
    if (finalUrl == null || finalUrl.isEmpty) {
      finalUrl = _urlCtrl.text.trim().isEmpty ? null : _urlCtrl.text.trim();
    }

    setState(() => _isSaving = true);

    try {
      await _batchService.createNote(
        widget.coaching.id,
        widget.batchId,
        title: _titleCtrl.text.trim(),
        description: _descCtrl.text.trim().isEmpty
            ? null
            : _descCtrl.text.trim(),
        fileUrl: finalUrl,
        fileType: _fileType,
        fileName: _uploadedFileName ?? _pickedFile?.name,
      );
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed: $e')));
      }
    }
    if (mounted) setState(() => _isSaving = false);
  }

  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: AppBar(
        title: const Text('Upload Note'),
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

                // ── File type selector
                _FieldLabel('File Type'),
                const SizedBox(height: 10),
                Row(
                  children: _fileTypes.map((t) {
                    final selected = _fileType == t.$1;
                    return Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 3),
                        child: GestureDetector(
                          onTap: () => setState(() => _fileType = t.$1),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            curve: Curves.easeOut,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            decoration: BoxDecoration(
                              color: selected
                                  ? t.$4.withValues(alpha: 0.12)
                                  : theme.colorScheme.surfaceContainerLowest,
                              borderRadius: BorderRadius.circular(14),
                              border: selected
                                  ? Border.all(
                                      color: t.$4.withValues(alpha: 0.4),
                                      width: 1.5,
                                    )
                                  : Border.all(
                                      color: theme.colorScheme.onSurface
                                          .withValues(alpha: 0.06),
                                    ),
                              boxShadow: selected
                                  ? [
                                      BoxShadow(
                                        color: t.$4.withValues(alpha: 0.15),
                                        blurRadius: 8,
                                        offset: const Offset(0, 2),
                                      ),
                                    ]
                                  : null,
                            ),
                            child: Column(
                              children: [
                                Icon(
                                  t.$3,
                                  size: 20,
                                  color: selected
                                      ? t.$4
                                      : theme.colorScheme.onSurface.withValues(
                                          alpha: 0.35,
                                        ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  t.$2,
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: selected
                                        ? FontWeight.w600
                                        : FontWeight.w400,
                                    color: selected
                                        ? t.$4
                                        : theme.colorScheme.onSurface
                                              .withValues(alpha: 0.5),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 28),

                // ── File upload section (only for non-link types)
                if (_fileType != 'link') ...[
                  _FieldLabel('Upload File'),
                  const SizedBox(height: 10),
                  _buildFileUploadArea(theme),
                  const SizedBox(height: 16),
                  // Divider with "or"
                  Row(
                    children: [
                      Expanded(
                        child: Divider(
                          color: theme.colorScheme.onSurface.withValues(
                            alpha: 0.1,
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Text(
                          'or paste a link',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurface.withValues(
                              alpha: 0.35,
                            ),
                          ),
                        ),
                      ),
                      Expanded(
                        child: Divider(
                          color: theme.colorScheme.onSurface.withValues(
                            alpha: 0.1,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                ],

                // ── URL field (always shown, never required)
                _FieldLabel(_fileType == 'link' ? 'URL' : 'File URL'),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _urlCtrl,
                  decoration: _inputDeco(
                    'https://... (optional)',
                    Icons.link_rounded,
                  ),
                  keyboardType: TextInputType.url,
                ),
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
                        : const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.upload_rounded, size: 20),
                              SizedBox(width: 8),
                              Text(
                                'Upload Note',
                                style: TextStyle(
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

  Widget _buildFileUploadArea(ThemeData theme) {
    if (_pickedFile != null) {
      // ── File selected / uploaded state
      final isUploaded = _uploadedUrl != null;
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isUploaded
              ? Colors.green.withValues(alpha: 0.06)
              : theme.colorScheme.primary.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isUploaded
                ? Colors.green.withValues(alpha: 0.25)
                : theme.colorScheme.primary.withValues(alpha: 0.15),
          ),
        ),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: isUploaded
                        ? Colors.green.withValues(alpha: 0.1)
                        : theme.colorScheme.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    isUploaded
                        ? Icons.check_circle_rounded
                        : Icons.insert_drive_file_rounded,
                    size: 24,
                    color: isUploaded
                        ? Colors.green
                        : theme.colorScheme.primary,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _pickedFile!.name,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        isUploaded
                            ? 'Uploaded successfully'
                            : _formatFileSize(_pickedFile!.size),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: isUploaded
                              ? Colors.green.shade700
                              : theme.colorScheme.onSurface.withValues(
                                  alpha: 0.5,
                                ),
                          fontWeight: isUploaded
                              ? FontWeight.w500
                              : FontWeight.w400,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () {
                    setState(() {
                      _pickedFile = null;
                      _uploadedUrl = null;
                      _uploadedFileName = null;
                    });
                  },
                  icon: Icon(
                    Icons.close_rounded,
                    size: 20,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
                  ),
                ),
              ],
            ),
            if (!isUploaded) ...[
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: _isUploading
                    ? const Center(
                        child: Padding(
                          padding: EdgeInsets.all(8),
                          child: SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(strokeWidth: 2.5),
                          ),
                        ),
                      )
                    : OutlinedButton.icon(
                        onPressed: _uploadFile,
                        icon: const Icon(Icons.cloud_upload_rounded, size: 18),
                        label: const Text('Upload to Server'),
                        style: OutlinedButton.styleFrom(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
              ),
            ],
          ],
        ),
      );
    }

    // ── Dropzone-style empty state
    return GestureDetector(
      onTap: _pickFile,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 24),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: theme.colorScheme.onSurface.withValues(alpha: 0.1),
            width: 1.5,
            strokeAlign: BorderSide.strokeAlignInside,
          ),
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.cloud_upload_outlined,
                size: 28,
                color: theme.colorScheme.primary.withValues(alpha: 0.6),
              ),
            ),
            const SizedBox(height: 14),
            Text(
              'Tap to choose a file',
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'PDF, DOC, XLS, PPT, Images — up to 15 MB',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.35),
                fontSize: 11,
              ),
            ),
          ],
        ),
      ),
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
