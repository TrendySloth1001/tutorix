import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import '../models/assignment_model.dart';
import '../services/assessment_service.dart';
import 'file_viewer_screen.dart';

/// Screen for students to view assignment details and submit files (images/PDFs).
class SubmitAssignmentScreen extends StatefulWidget {
  final String coachingId;
  final String batchId;
  final AssignmentModel assignment;

  const SubmitAssignmentScreen({
    super.key,
    required this.coachingId,
    required this.batchId,
    required this.assignment,
  });

  @override
  State<SubmitAssignmentScreen> createState() => _SubmitAssignmentScreenState();
}

class _SubmitAssignmentScreenState extends State<SubmitAssignmentScreen> {
  final AssessmentService _service = AssessmentService();
  final List<String> _selectedFiles = [];
  bool _submitting = false;
  SubmissionModel? _mySubmission;
  bool _loadingSubmission = true;

  @override
  void initState() {
    super.initState();
    _loadMySubmission();
  }

  Future<void> _loadMySubmission() async {
    try {
      _mySubmission = await _service.getMySubmission(
        widget.coachingId,
        widget.batchId,
        widget.assignment.id,
      );
    } catch (_) {}
    if (mounted) setState(() => _loadingSubmission = false);
  }

  Future<void> _pickImages() async {
    final picker = ImagePicker();
    final images = await picker.pickMultiImage(imageQuality: 85);
    if (images.isNotEmpty) {
      setState(() {
        for (final img in images) {
          if (_selectedFiles.length < 10) {
            _selectedFiles.add(img.path);
          }
        }
      });
    }
  }

  Future<void> _pickPDFs() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
      allowMultiple: true,
    );
    if (result != null) {
      setState(() {
        for (final f in result.files) {
          if (f.path != null && _selectedFiles.length < 10) {
            _selectedFiles.add(f.path!);
          }
        }
      });
    }
  }

  void _removeFile(int index) {
    setState(() => _selectedFiles.removeAt(index));
  }

  Future<void> _submit() async {
    if (_selectedFiles.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Select at least one file')));
      return;
    }

    setState(() => _submitting = true);
    try {
      await _service.submitAssignment(
        widget.coachingId,
        widget.batchId,
        widget.assignment.id,
        filePaths: _selectedFiles,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Assignment submitted successfully!')),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final a = widget.assignment;

    return Scaffold(
      appBar: AppBar(title: Text(a.title)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Assignment details
          if (a.description != null && a.description!.isNotEmpty) ...[
            Text(a.description!, style: theme.textTheme.bodyMedium),
            const SizedBox(height: 12),
          ],

          // Info row
          Wrap(
            spacing: 16,
            runSpacing: 8,
            children: [
              if (a.dueDate != null)
                _DetailChip(
                  icon: Icons.event_outlined,
                  label:
                      'Due: ${a.dueDate!.day}/${a.dueDate!.month}/${a.dueDate!.year}',
                  color: a.isPastDue ? Colors.red : null,
                ),
              if (a.totalMarks != null)
                _DetailChip(
                  icon: Icons.star_outline_rounded,
                  label: '${a.totalMarks} marks',
                ),
              if (a.allowLateSubmission)
                const _DetailChip(
                  icon: Icons.schedule_rounded,
                  label: 'Late submission allowed',
                ),
            ],
          ),

          // Teacher attachments
          if (a.attachments.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text(
              'Reference Files',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            ...a.attachments.map(
              (att) => ListTile(
                leading: Icon(
                  att.fileType == 'image'
                      ? Icons.image_outlined
                      : Icons.picture_as_pdf_outlined,
                  color: theme.colorScheme.primary,
                ),
                title: Text(att.fileName, style: theme.textTheme.bodySmall),
                dense: true,
                contentPadding: EdgeInsets.zero,
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => FileViewerScreen(
                        url: att.url,
                        fileName: att.fileName,
                        isPDF: att.fileType != 'image',
                      ),
                    ),
                  );
                },
              ),
            ),
          ],

          const Divider(height: 32),

          // Previous submission
          if (_loadingSubmission)
            const Center(child: CircularProgressIndicator())
          else if (_mySubmission != null) ...[
            _SubmissionStatus(submission: _mySubmission!),
            const SizedBox(height: 16),
          ],

          // Submit section
          if (a.canSubmit) ...[
            Text(
              _mySubmission != null ? 'Resubmit' : 'Your Submission',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Upload images or PDFs (max 10 files, 15MB each)',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 12),

            // File picker buttons
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _pickImages,
                    icon: const Icon(Icons.image_outlined, size: 18),
                    label: const Text('Images'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _pickPDFs,
                    icon: const Icon(Icons.picture_as_pdf_outlined, size: 18),
                    label: const Text('PDFs'),
                  ),
                ),
              ],
            ),

            // Selected files
            if (_selectedFiles.isNotEmpty) ...[
              const SizedBox(height: 12),
              ...List.generate(_selectedFiles.length, (i) {
                final name = _selectedFiles[i].split('/').last;
                final isPDF = name.toLowerCase().endsWith('.pdf');
                return ListTile(
                  leading: Icon(
                    isPDF
                        ? Icons.picture_as_pdf_outlined
                        : Icons.image_outlined,
                    color: theme.colorScheme.primary,
                    size: 20,
                  ),
                  title: Text(
                    name,
                    style: theme.textTheme.bodySmall,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  trailing: IconButton(
                    icon: Icon(
                      Icons.close_rounded,
                      size: 18,
                      color: theme.colorScheme.error,
                    ),
                    onPressed: () => _removeFile(i),
                  ),
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                );
              }),
            ],

            const SizedBox(height: 16),

            // Submit button
            FilledButton.icon(
              onPressed: _submitting || _selectedFiles.isEmpty ? null : _submit,
              icon: _submitting
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.upload_rounded, size: 18),
              label: Text(_mySubmission != null ? 'Resubmit' : 'Submit'),
            ),
          ] else if (!a.canSubmit && !a.isClosed) ...[
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(Icons.block_rounded, size: 20, color: Colors.red),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Submission deadline has passed',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: Colors.red,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _DetailChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color? color;

  const _DetailChip({required this.icon, required this.label, this.color});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final c = color ?? theme.colorScheme.onSurfaceVariant;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: c),
        const SizedBox(width: 4),
        Text(label, style: theme.textTheme.bodySmall?.copyWith(color: c)),
      ],
    );
  }
}

class _SubmissionStatus extends StatelessWidget {
  final SubmissionModel submission;
  const _SubmissionStatus({required this.submission});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final s = submission;
    final color = switch (s.status) {
      'GRADED' => Colors.green,
      'RETURNED' => Colors.orange,
      _ => Colors.blue,
    };

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                s.status == 'GRADED'
                    ? Icons.check_circle_rounded
                    : s.status == 'RETURNED'
                    ? Icons.undo_rounded
                    : Icons.upload_file_rounded,
                size: 18,
                color: color,
              ),
              const SizedBox(width: 8),
              Text(
                switch (s.status) {
                  'GRADED' => 'Graded',
                  'RETURNED' => 'Returned',
                  _ => 'Submitted',
                },
                style: theme.textTheme.titleSmall?.copyWith(
                  color: color,
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (s.isLate) ...[
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.orange.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    'Late',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: Colors.orange,
                    ),
                  ),
                ),
              ],
            ],
          ),
          if (s.marks != null) ...[
            const SizedBox(height: 6),
            Text(
              'Marks: ${s.marks}',
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
          if (s.feedback != null && s.feedback!.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text('Feedback: ${s.feedback}', style: theme.textTheme.bodySmall),
          ],
          if (s.files.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              'Submitted Files',
              style: theme.textTheme.labelSmall?.copyWith(
                fontWeight: FontWeight.w600,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: s.files.map((f) {
                final isPDF = f.fileName.toLowerCase().endsWith('.pdf');
                return InkWell(
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => FileViewerScreen(
                          url: f.url,
                          fileName: f.fileName,
                          isPDF: isPDF,
                        ),
                      ),
                    );
                  },
                  child: Chip(
                    avatar: Icon(
                      isPDF ? Icons.picture_as_pdf_outlined : Icons.image_outlined,
                      size: 14,
                    ),
                    label: Text(f.fileName, style: theme.textTheme.labelSmall),
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    visualDensity: VisualDensity.compact,
                  ),
                );
              }).toList(),
            ),
          ],
        ],
      ),
    );
  }
}
