import 'package:flutter/material.dart';
import '../../coaching/models/coaching_model.dart';
import '../services/batch_service.dart';

/// Screen to create a new note (file link) in a batch.
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

class _CreateNoteScreenState extends State<CreateNoteScreen> {
  final _formKey = GlobalKey<FormState>();
  final BatchService _batchService = BatchService();

  final _titleCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _urlCtrl = TextEditingController();
  final _fileNameCtrl = TextEditingController();
  String _fileType = 'pdf';
  bool _isSaving = false;

  static const _fileTypes = [
    ('pdf', 'PDF', Icons.picture_as_pdf_rounded),
    ('doc', 'Document', Icons.description_rounded),
    ('image', 'Image', Icons.image_rounded),
    ('video', 'Video', Icons.movie_rounded),
    ('link', 'Link', Icons.link_rounded),
  ];

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    _urlCtrl.dispose();
    _fileNameCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);

    try {
      await _batchService.createNote(
        widget.coaching.id,
        widget.batchId,
        title: _titleCtrl.text.trim(),
        description:
            _descCtrl.text.trim().isEmpty ? null : _descCtrl.text.trim(),
        fileUrl: _urlCtrl.text.trim(),
        fileType: _fileType,
        fileName: _fileNameCtrl.text.trim().isEmpty
            ? null
            : _fileNameCtrl.text.trim(),
      );
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed: $e')),
        );
      }
    }
    if (mounted) setState(() => _isSaving = false);
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
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Title
              Text('Title *',
                  style: theme.textTheme.labelLarge
                      ?.copyWith(fontWeight: FontWeight.w600)),
              const SizedBox(height: 6),
              TextFormField(
                controller: _titleCtrl,
                decoration: _input('e.g. Chapter 5 — Quadratic Equations'),
                validator: (v) =>
                    v == null || v.trim().isEmpty ? 'Title is required' : null,
                textCapitalization: TextCapitalization.sentences,
              ),
              const SizedBox(height: 20),

              // ── Description
              Text('Description',
                  style: theme.textTheme.labelLarge
                      ?.copyWith(fontWeight: FontWeight.w600)),
              const SizedBox(height: 6),
              TextFormField(
                controller: _descCtrl,
                decoration: _input('Brief description (optional)'),
                maxLines: 2,
                textCapitalization: TextCapitalization.sentences,
              ),
              const SizedBox(height: 20),

              // ── File type
              Text('File Type',
                  style: theme.textTheme.labelLarge
                      ?.copyWith(fontWeight: FontWeight.w600)),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: _fileTypes.map((t) {
                  final selected = _fileType == t.$1;
                  return ChoiceChip(
                    avatar: Icon(t.$3, size: 16),
                    label: Text(t.$2),
                    selected: selected,
                    onSelected: (_) => setState(() => _fileType = t.$1),
                    selectedColor: theme.colorScheme.primary
                        .withValues(alpha: 0.15),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 20),

              // ── File URL
              Text('File URL *',
                  style: theme.textTheme.labelLarge
                      ?.copyWith(fontWeight: FontWeight.w600)),
              const SizedBox(height: 6),
              TextFormField(
                controller: _urlCtrl,
                decoration: _input('https://...'),
                validator: (v) =>
                    v == null || v.trim().isEmpty ? 'URL is required' : null,
                keyboardType: TextInputType.url,
              ),
              const SizedBox(height: 20),

              // ── File name
              Text('File Name',
                  style: theme.textTheme.labelLarge
                      ?.copyWith(fontWeight: FontWeight.w600)),
              const SizedBox(height: 6),
              TextFormField(
                controller: _fileNameCtrl,
                decoration: _input('chapter5.pdf (optional)'),
              ),
              const SizedBox(height: 36),

              // ── Save
              SizedBox(
                width: double.infinity,
                height: 52,
                child: FilledButton(
                  onPressed: _isSaving ? null : _save,
                  style: FilledButton.styleFrom(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: _isSaving
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white),
                        )
                      : const Text('Upload Note'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  InputDecoration _input(String hint) => InputDecoration(
        hintText: hint,
        filled: true,
        fillColor: Theme.of(context).colorScheme.surfaceContainerLowest,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      );
}
