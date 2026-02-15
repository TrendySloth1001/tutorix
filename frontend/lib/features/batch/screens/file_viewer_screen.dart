import 'dart:io';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdfx/pdfx.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/batch_note_model.dart';

/// Viewer screen for file attachments.
/// - Images: full-screen zoomable preview
/// - PDFs: downloaded & rendered in-app with flutter_pdfview
/// - Other docs: download → try open with device app → fallback to browser
class FileViewerScreen extends StatelessWidget {
  final NoteAttachment attachment;

  const FileViewerScreen({super.key, required this.attachment});

  bool get _isImage => attachment.fileType == 'image';
  bool get _isPdf =>
      attachment.fileType == 'pdf' ||
      (attachment.mimeType?.contains('pdf') ?? false) ||
      (attachment.fileName?.toLowerCase().endsWith('.pdf') ?? false);

  @override
  Widget build(BuildContext context) {
    if (_isImage) return _ImageViewer(attachment: attachment);
    if (_isPdf) return _PdfViewer(attachment: attachment);
    return _DocumentViewer(attachment: attachment);
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// ── IMAGE VIEWER — full-screen zoomable
// ═══════════════════════════════════════════════════════════════════════════

class _ImageViewer extends StatefulWidget {
  final NoteAttachment attachment;
  const _ImageViewer({required this.attachment});

  @override
  State<_ImageViewer> createState() => _ImageViewerState();
}

class _ImageViewerState extends State<_ImageViewer>
    with SingleTickerProviderStateMixin {
  late final TransformationController _transformCtrl;
  late final AnimationController _animCtrl;
  bool _showOverlay = true;

  @override
  void initState() {
    super.initState();
    _transformCtrl = TransformationController();
    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
  }

  @override
  void dispose() {
    _transformCtrl.dispose();
    _animCtrl.dispose();
    super.dispose();
  }

  void _toggleOverlay() => setState(() => _showOverlay = !_showOverlay);

  void _resetZoom() {
    final animValue = Matrix4Tween(
      begin: _transformCtrl.value,
      end: Matrix4.identity(),
    ).animate(CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut));

    void listener() {
      _transformCtrl.value = animValue.value;
    }

    animValue.addListener(listener);
    _animCtrl.forward(from: 0).then((_) => animValue.removeListener(listener));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // ── Zoomable image
          GestureDetector(
            onTap: _toggleOverlay,
            child: InteractiveViewer(
              transformationController: _transformCtrl,
              minScale: 0.5,
              maxScale: 5.0,
              child: Center(
                child: Image.network(
                  widget.attachment.url,
                  fit: BoxFit.contain,
                  loadingBuilder: (_, child, progress) {
                    if (progress == null) return child;
                    final pct = progress.expectedTotalBytes != null
                        ? progress.cumulativeBytesLoaded /
                            progress.expectedTotalBytes!
                        : null;
                    return Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          CircularProgressIndicator(
                            value: pct,
                            color: Colors.white70,
                            strokeWidth: 2.5,
                          ),
                          if (pct != null) ...[
                            const SizedBox(height: 12),
                            Text(
                              '${(pct * 100).toInt()}%',
                              style: const TextStyle(
                                color: Colors.white54,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ],
                      ),
                    );
                  },
                  errorBuilder: (_, _, _) => Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.broken_image_outlined,
                        size: 48,
                        color: Colors.white.withValues(alpha: 0.3),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Failed to load image',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.5),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // ── Top overlay
          if (_showOverlay)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withValues(alpha: 0.7),
                      Colors.transparent,
                    ],
                  ),
                ),
                child: SafeArea(
                  bottom: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(8, 4, 8, 16),
                    child: Row(
                      children: [
                        IconButton(
                          onPressed: () => Navigator.pop(context),
                          icon: const Icon(
                            Icons.arrow_back_rounded,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                widget.attachment.fileName ?? 'Image',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 15,
                                ),
                              ),
                              Text(
                                widget.attachment.formattedSize,
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.6),
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          onPressed: _resetZoom,
                          icon: const Icon(
                            Icons.fit_screen_rounded,
                            color: Colors.white,
                          ),
                          tooltip: 'Reset zoom',
                        ),
                        IconButton(
                          onPressed: () => _openExternal(context),
                          icon: const Icon(
                            Icons.open_in_new_rounded,
                            color: Colors.white,
                          ),
                          tooltip: 'Open externally',
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _openExternal(BuildContext context) async {
    final uri = Uri.parse(widget.attachment.url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open file')),
      );
    }
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// ── PDF VIEWER — download & render in-app
// ═══════════════════════════════════════════════════════════════════════════

class _PdfViewer extends StatefulWidget {
  final NoteAttachment attachment;
  const _PdfViewer({required this.attachment});

  @override
  State<_PdfViewer> createState() => _PdfViewerState();
}

class _PdfViewerState extends State<_PdfViewer> {
  String? _localPath;
  double _downloadProgress = 0;
  String? _error;
  PdfDocument? _pdfDocument;
  PdfControllerPinch? _pdfController;
  int _totalPages = 0;
  int _currentPage = 1;

  @override
  void initState() {
    super.initState();
    _downloadAndLoadPdf();
  }

  @override
  void dispose() {
    _pdfDocument?.close();
    _pdfController?.dispose();
    super.dispose();
  }

  Future<void> _downloadAndLoadPdf() async {
    try {
      final dir = await getTemporaryDirectory();
      final safeName = (widget.attachment.fileName ?? 'document.pdf')
          .replaceAll(RegExp(r'[^\w.\-]'), '_');
      final file = File('${dir.path}/$safeName');

      debugPrint('🔍 PDF download starting: ${widget.attachment.url}');
      debugPrint('📁 Target path: ${file.path}');

      // Download if not cached
      if (!file.existsSync() || file.lengthSync() == 0) {
        final request = http.Request('GET', Uri.parse(widget.attachment.url));
        final response = await http.Client().send(request);

        if (response.statusCode != 200) {
          throw Exception('Download failed (${response.statusCode})');
        }

        final totalBytes = response.contentLength ?? 0;
        final bytes = <int>[];
        int received = 0;

        await for (final chunk in response.stream) {
          bytes.addAll(chunk);
          received += chunk.length;
          if (totalBytes > 0 && mounted) {
            setState(() => _downloadProgress = received / totalBytes);
          }
        }

        if (bytes.isEmpty) {
          throw Exception('Downloaded file is empty');
        }

        await file.writeAsBytes(bytes);
        debugPrint('✅ PDF downloaded: ${file.lengthSync()} bytes');
      } else {
        debugPrint('✅ Using cached PDF (${file.lengthSync()} bytes)');
      }

      if (!mounted) return;

      // Load PDF document
      debugPrint('📚 Opening PDF document...');
      final document = await PdfDocument.openFile(file.path);
      
      if (!mounted) {
        document.close();
        return;
      }

      final pageCount = document.pagesCount;
      debugPrint('✅ PDF loaded: $pageCount pages');

      setState(() {
        _localPath = file.path;
        _pdfDocument = document;
        _totalPages = pageCount;
        _pdfController = PdfControllerPinch(
          document: PdfDocument.openFile(file.path),
        );
      });
    } catch (e) {
      debugPrint('❌ PDF error: $e');
      if (mounted) {
        setState(() => _error = 'Failed to load PDF: $e');
      }
    }
  }

  Future<void> _openExternally() async {
    if (_localPath != null) {
      final result = await OpenFilex.open(_localPath!);
      if (result.type == ResultType.done) return;
    }
    final uri = Uri.parse(widget.attachment.url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open file externally')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Scaffold(
      backgroundColor: colors.surface,
      appBar: AppBar(
        title: Text(
          widget.attachment.fileName ?? 'PDF',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          if (_pdfController != null)
            IconButton(
              onPressed: _openExternally,
              icon: const Icon(Icons.open_in_new_rounded),
              tooltip: 'Open externally',
            ),
        ],
      ),
      body: _buildBody(theme, colors),
      bottomNavigationBar: _pdfController != null && _totalPages > 0
          ? Container(
              padding: EdgeInsets.fromLTRB(
                16,
                10,
                16,
                MediaQuery.of(context).padding.bottom > 0
                    ? MediaQuery.of(context).padding.bottom
                    : 14,
              ),
              decoration: BoxDecoration(
                color: colors.surface,
                border: Border(
                  top: BorderSide(
                    color: colors.onSurface.withValues(alpha: 0.06),
                  ),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.picture_as_pdf_rounded,
                    size: 16,
                    color: const Color(0xFFE53935).withValues(alpha: 0.6),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Page $_currentPage of $_totalPages',
                    style: theme.textTheme.labelMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: colors.onSurface.withValues(alpha: 0.5),
                    ),
                  ),
                ],
              ),
            )
          : null,
    );
  }

  Widget _buildBody(ThemeData theme, ColorScheme colors) {
    // ── Error state
    if (_error != null) {
      return _ErrorView(
        error: _error!,
        onRetry: () {
          setState(() {
            _error = null;
            _downloadProgress = 0;
            _pdfDocument?.close();
            _pdfDocument = null;
            _pdfController = null;
          });
          _downloadAndLoadPdf();
        },
        onOpenExternal: _openExternally,
      );
    }

    // ── Loading state
    if (_pdfController == null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 64,
              height: 64,
              child: CircularProgressIndicator(
                value: _downloadProgress > 0 ? _downloadProgress : null,
                strokeWidth: 3,
                color: const Color(0xFFE53935),
                backgroundColor: colors.onSurface.withValues(alpha: 0.06),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              _downloadProgress > 0
                  ? 'Downloading… ${(_downloadProgress * 100).toInt()}%'
                  : 'Loading PDF…',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colors.onSurface.withValues(alpha: 0.5),
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              widget.attachment.formattedSize,
              style: theme.textTheme.bodySmall?.copyWith(
                color: colors.onSurface.withValues(alpha: 0.3),
              ),
            ),
          ],
        ),
      );
    }

    // ── PDF viewer
    return Container(
      color: Colors.grey.shade200,
      child: PdfViewPinch(
        controller: _pdfController!,
        padding: 8,
        onPageChanged: (page) {
          if (mounted) {
            setState(() => _currentPage = page);
          }
        },
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// ── DOCUMENT VIEWER — download → device app → browser fallback
// ═══════════════════════════════════════════════════════════════════════════

class _DocumentViewer extends StatefulWidget {
  final NoteAttachment attachment;
  const _DocumentViewer({required this.attachment});

  @override
  State<_DocumentViewer> createState() => _DocumentViewerState();
}

class _DocumentViewerState extends State<_DocumentViewer> {
  bool _isOpening = false;

  static const _typeConfig = {
    'pdf': (Icons.picture_as_pdf_rounded, Color(0xFFE53935), 'PDF Document'),
    'doc': (Icons.description_rounded, Color(0xFF1E88E5), 'Document'),
    'link': (Icons.link_rounded, Color(0xFF00897B), 'Link'),
  };

  Future<void> _openFile() async {
    setState(() => _isOpening = true);

    try {
      // Step 1: Download to temp directory
      final dir = await getTemporaryDirectory();
      final safeName =
          (widget.attachment.fileName ?? 'document')
              .replaceAll(RegExp(r'[^\w.\-]'), '_');
      final file = File('${dir.path}/$safeName');

      if (!file.existsSync() || file.lengthSync() == 0) {
        final response = await http.get(Uri.parse(widget.attachment.url));
        if (response.statusCode != 200) {
          throw Exception('Download failed (${response.statusCode})');
        }
        await file.writeAsBytes(response.bodyBytes);
      }

      // Step 2: Try to open with device app
      final result = await OpenFilex.open(file.path);
      if (result.type == ResultType.done) {
        if (mounted) setState(() => _isOpening = false);
        return;
      }

      // Step 3: Fallback — open URL in browser
      final uri = Uri.parse(widget.attachment.url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        _showError('No app found to open this file type');
      }
    } catch (e) {
      _showError('Failed to open file: $e');
    }

    if (mounted) setState(() => _isOpening = false);
  }

  void _showError(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final config = _typeConfig[widget.attachment.fileType] ??
        (Icons.attach_file_rounded, colors.primary, 'File');
    final (icon, color, typeLabel) = config;

    return Scaffold(
      backgroundColor: colors.surface,
      appBar: AppBar(
        title: Text(
          widget.attachment.fileName ?? 'File',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // ── Large icon
              Container(
                padding: const EdgeInsets.all(32),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.08),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: color.withValues(alpha: 0.15),
                    width: 2,
                  ),
                ),
                child: Icon(icon, size: 56, color: color),
              ),
              const SizedBox(height: 28),

              // ── File name
              Text(
                widget.attachment.fileName ?? 'Unnamed file',
                textAlign: TextAlign.center,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),

              // ── Meta chips
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      typeLabel,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: color,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: colors.onSurface.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      widget.attachment.formattedSize,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: colors.onSurface.withValues(alpha: 0.5),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 36),

              // ── Open button
              SizedBox(
                width: double.infinity,
                height: 54,
                child: FilledButton.icon(
                  onPressed: _isOpening ? null : _openFile,
                  icon: _isOpening
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.open_in_new_rounded, size: 20),
                  label: Text(
                    _isOpening ? 'Opening…' : 'Open File',
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                    ),
                  ),
                  style: FilledButton.styleFrom(
                    backgroundColor: color,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // ── Hint
              Text(
                'Downloads and opens in a compatible app',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colors.onSurface.withValues(alpha: 0.35),
                  fontSize: 12,
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
// ── ERROR VIEW (shared by PDF viewer)
// ═══════════════════════════════════════════════════════════════════════════

class _ErrorView extends StatelessWidget {
  final String error;
  final VoidCallback onRetry;
  final VoidCallback onOpenExternal;

  const _ErrorView({
    required this.error,
    required this.onRetry,
    required this.onOpenExternal,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.error_outline_rounded,
              size: 48,
              color: Colors.red.withValues(alpha: 0.4),
            ),
            const SizedBox(height: 16),
            Text(
              'Unable to display PDF',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              error,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(
                color: colors.onSurface.withValues(alpha: 0.5),
              ),
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                OutlinedButton.icon(
                  onPressed: onRetry,
                  icon: const Icon(Icons.refresh_rounded, size: 18),
                  label: const Text('Retry'),
                  style: OutlinedButton.styleFrom(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                FilledButton.icon(
                  onPressed: onOpenExternal,
                  icon: const Icon(Icons.open_in_new_rounded, size: 18),
                  label: const Text('Open externally'),
                  style: FilledButton.styleFrom(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
