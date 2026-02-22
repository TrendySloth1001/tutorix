import 'dart:io';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/constants/error_strings.dart';
import '../../../shared/widgets/app_alert.dart';
import '../../../core/theme/design_tokens.dart';
import '../models/batch_note_model.dart';

/// Enhanced file viewer for documents and images.
/// - Images: full-screen zoomable preview
/// - PDFs: rich in-app viewer with search, text selection, bookmarks
/// - Office docs (DOCX, PPTX, XLSX): Download and open with device apps
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
    if (_isPdf) return _EnhancedPdfViewer(attachment: attachment);
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
                            const SizedBox(height: Spacing.sp12),
                            Text(
                              '${(pct * 100).toInt()}%',
                              style: const TextStyle(
                                color: Colors.white54,
                                fontSize: FontSize.body,
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
                      const SizedBox(height: Spacing.sp12),
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
                    padding: const EdgeInsets.fromLTRB(
                      Spacing.sp8,
                      Spacing.sp4,
                      Spacing.sp8,
                      Spacing.sp16,
                    ),
                    child: Row(
                      children: [
                        IconButton(
                          onPressed: () => Navigator.pop(context),
                          icon: const Icon(
                            Icons.arrow_back_rounded,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(width: Spacing.sp4),
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
                                  fontSize: FontSize.body,
                                ),
                              ),
                              Text(
                                widget.attachment.formattedSize,
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.6),
                                  fontSize: FontSize.caption,
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
      AppAlert.error(context, Errors.openFileFailed);
    }
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// ── ENHANCED PDF VIEWER — Syncfusion with search, bookmarks, text selection
// ═══════════════════════════════════════════════════════════════════════════

class _EnhancedPdfViewer extends StatefulWidget {
  final NoteAttachment attachment;
  const _EnhancedPdfViewer({required this.attachment});

  @override
  State<_EnhancedPdfViewer> createState() => _EnhancedPdfViewerState();
}

class _EnhancedPdfViewerState extends State<_EnhancedPdfViewer> {
  final PdfViewerController _pdfController = PdfViewerController();
  final TextEditingController _searchCtrl = TextEditingController();
  bool _showSearch = false;
  PdfTextSearchResult? _searchResult;
  int _currentPage = 1;
  int _totalPages = 0;

  @override
  void dispose() {
    _pdfController.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  void _toggleSearch() {
    setState(() {
      _showSearch = !_showSearch;
      if (!_showSearch) {
        _searchResult?.clear();
        _searchCtrl.clear();
      }
    });
  }

  void _performSearch(String query) {
    if (query.isEmpty) {
      _searchResult?.clear();
      return;
    }
    _searchResult = _pdfController.searchText(query);
    _searchResult?.addListener(() {
      if (mounted) setState(() {});
    });
  }

  Future<void> _sharePdf() async {
    try {
      final dir = await getTemporaryDirectory();
      final safeName = (widget.attachment.fileName ?? 'document.pdf')
          .replaceAll(RegExp(r'[^\w.\-]'), '_');
      final file = File('${dir.path}/$safeName');

      if (!file.existsSync()) {
        final response = await http.get(Uri.parse(widget.attachment.url));
        await file.writeAsBytes(response.bodyBytes);
      }

      // ignore: deprecated_member_use
      await Share.shareXFiles([XFile(file.path)]);
    } catch (e) {
      // ignore
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(
          widget.attachment.fileName ?? 'PDF',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        centerTitle: true,
        backgroundColor: colors.surface,
        elevation: 0,
        actions: [
          IconButton(
            onPressed: _toggleSearch,
            icon: Icon(_showSearch ? Icons.search_off : Icons.search),
            tooltip: 'Search',
          ),
          if (_totalPages > 0)
            IconButton(
              onPressed: () {
                showDialog<void>(
                  context: context,
                  builder: (context) => _PageJumpDialog(
                    controller: _pdfController,
                    currentPage: _currentPage,
                    totalPages: _totalPages,
                  ),
                );
              },
              icon: const Icon(Icons.grid_view_rounded),
              tooltip: 'Jump to page',
            ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert_rounded),
            onSelected: (value) async {
              switch (value) {
                case 'share':
                  await _sharePdf();
                  break;
                case 'open':
                  final uri = Uri.parse(widget.attachment.url);
                  if (await canLaunchUrl(uri)) {
                    await launchUrl(uri, mode: LaunchMode.externalApplication);
                  }
                  break;
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'share',
                child: Row(
                  children: [
                    Icon(Icons.share_rounded, size: 20),
                    SizedBox(width: Spacing.sp12),
                    Text('Share'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'open',
                child: Row(
                  children: [
                    Icon(Icons.open_in_new_rounded, size: 20),
                    SizedBox(width: Spacing.sp12),
                    Text('Open externally'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: Stack(
        children: [
          // PDF Viewer
          SfPdfViewer.network(
            widget.attachment.url,
            controller: _pdfController,
            canShowScrollHead: true,
            canShowScrollStatus: true,
            canShowPaginationDialog: true,
            enableDoubleTapZooming: true,
            enableTextSelection: true,
            onDocumentLoaded: (details) {
              setState(() => _totalPages = details.document.pages.count);
            },
            onPageChanged: (details) {
              setState(() => _currentPage = details.newPageNumber);
            },
          ),

          // Search overlay
          if (_showSearch)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: _SearchBar(
                controller: _searchCtrl,
                searchResult: _searchResult,
                onSearch: _performSearch,
                onClose: _toggleSearch,
                onNext: () => _searchResult?.nextInstance(),
                onPrevious: () => _searchResult?.previousInstance(),
              ),
            ),
        ],
      ),
      // Page counter
      bottomNavigationBar: Container(
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
            top: BorderSide(color: colors.onSurface.withValues(alpha: 0.06)),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.picture_as_pdf_rounded,
                  size: 16,
                  color: colors.onSurface.withValues(alpha: 0.6),
                ),
                const SizedBox(width: Spacing.sp8),
                Text(
                  'Page $_currentPage${_totalPages > 0 ? ' of $_totalPages' : ''}',
                  style: theme.textTheme.labelMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: colors.onSurface.withValues(alpha: 0.5),
                  ),
                ),
              ],
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  onPressed: _currentPage > 1
                      ? () => _pdfController.previousPage()
                      : null,
                  icon: const Icon(Icons.chevron_left_rounded),
                  iconSize: 20,
                  visualDensity: VisualDensity.compact,
                ),
                IconButton(
                  onPressed: _currentPage < _totalPages
                      ? () => _pdfController.nextPage()
                      : null,
                  icon: const Icon(Icons.chevron_right_rounded),
                  iconSize: 20,
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
          ],
        ),
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

  static Map<String, (IconData, Color, String)> _typeConfig(
    ColorScheme colors,
  ) => {
    'pdf': (Icons.picture_as_pdf_rounded, colors.onSurface, 'PDF Document'),
    'doc': (Icons.description_rounded, colors.primary, 'Document'),
    'link': (Icons.link_rounded, colors.onSurfaceVariant, 'Link'),
  };

  Future<void> _openFile() async {
    setState(() => _isOpening = true);

    try {
      // Step 1: Download to temp directory
      final dir = await getTemporaryDirectory();
      final safeName = (widget.attachment.fileName ?? 'document').replaceAll(
        RegExp(r'[^\w.\-]'),
        '_',
      );
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
        _showError(Errors.noAppForFile);
      }
    } catch (e) {
      if (mounted) AppAlert.error(context, e, fallback: Errors.openFileFailed);
      if (mounted) setState(() => _isOpening = false);
      return;
    }

    if (mounted) setState(() => _isOpening = false);
  }

  void _showError(String msg) {
    if (!mounted) return;
    AppAlert.error(context, msg);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final config =
        _typeConfig(colors)[widget.attachment.fileType] ??
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
          padding: const EdgeInsets.all(Spacing.sp32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // ── Large icon
              Container(
                padding: const EdgeInsets.all(Spacing.sp32),
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
              const SizedBox(height: Spacing.sp28),

              // ── File name
              Text(
                widget.attachment.fileName ?? 'Unnamed file',
                textAlign: TextAlign.center,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: Spacing.sp8),

              // ── Meta chips
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: Spacing.sp10,
                      vertical: Spacing.sp4,
                    ),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(Radii.sm),
                    ),
                    child: Text(
                      typeLabel,
                      style: TextStyle(
                        fontSize: FontSize.caption,
                        fontWeight: FontWeight.w700,
                        color: color,
                      ),
                    ),
                  ),
                  const SizedBox(width: Spacing.sp10),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: Spacing.sp10,
                      vertical: Spacing.sp4,
                    ),
                    decoration: BoxDecoration(
                      color: colors.onSurface.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(Radii.sm),
                    ),
                    child: Text(
                      widget.attachment.formattedSize,
                      style: TextStyle(
                        fontSize: FontSize.caption,
                        fontWeight: FontWeight.w600,
                        color: colors.onSurface.withValues(alpha: 0.5),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: Spacing.sp40),

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
                      fontSize: FontSize.body,
                    ),
                  ),
                  style: FilledButton.styleFrom(
                    backgroundColor: color,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(Radii.lg),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: Spacing.sp12),

              // ── Hint
              Text(
                'Downloads and opens in a compatible app',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colors.onSurface.withValues(alpha: 0.35),
                  fontSize: FontSize.caption,
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
// ── PDF SEARCH BAR
// ═══════════════════════════════════════════════════════════════════════════

class _SearchBar extends StatelessWidget {
  final TextEditingController controller;
  final PdfTextSearchResult? searchResult;
  final Function(String) onSearch;
  final VoidCallback onClose;
  final VoidCallback onNext;
  final VoidCallback onPrevious;

  const _SearchBar({
    required this.controller,
    required this.searchResult,
    required this.onSearch,
    required this.onClose,
    required this.onNext,
    required this.onPrevious,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final hasResults = searchResult?.hasResult ?? false;

    return Container(
      padding: const EdgeInsets.all(Spacing.sp12),
      decoration: BoxDecoration(
        color: colors.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: SafeArea(
        bottom: false,
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: controller,
                autofocus: true,
                decoration: InputDecoration(
                  hintText: 'Search in PDF',
                  prefixIcon: const Icon(Icons.search, size: 20),
                  suffixIcon: controller.text.isNotEmpty
                      ? IconButton(
                          onPressed: () {
                            controller.clear();
                            onSearch('');
                          },
                          icon: const Icon(Icons.clear, size: 20),
                        )
                      : null,
                  filled: true,
                  fillColor: colors.surfaceContainerLowest,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(Radii.md),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: Spacing.sp16,
                    vertical: Spacing.sp12,
                  ),
                ),
                onChanged: onSearch,
              ),
            ),
            if (hasResults) ...[
              const SizedBox(width: Spacing.sp8),
              Text(
                '${searchResult!.currentInstanceIndex}/${searchResult!.totalInstanceCount}',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: colors.onSurface.withValues(alpha: 0.5),
                ),
              ),
              IconButton(
                onPressed: onPrevious,
                icon: const Icon(Icons.keyboard_arrow_up_rounded),
                visualDensity: VisualDensity.compact,
              ),
              IconButton(
                onPressed: onNext,
                icon: const Icon(Icons.keyboard_arrow_down_rounded),
                visualDensity: VisualDensity.compact,
              ),
            ],
            IconButton(
              onPressed: onClose,
              icon: const Icon(Icons.close_rounded),
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// ── PAGE JUMP DIALOG
// ═══════════════════════════════════════════════════════════════════════════

class _PageJumpDialog extends StatelessWidget {
  final PdfViewerController controller;
  final int currentPage;
  final int totalPages;

  const _PageJumpDialog({
    required this.controller,
    required this.currentPage,
    required this.totalPages,
  });

  @override
  Widget build(BuildContext context) {
    final textCtrl = TextEditingController(text: currentPage.toString());

    return AlertDialog(
      title: const Text('Jump to Page'),
      content: TextField(
        controller: textCtrl,
        keyboardType: TextInputType.number,
        decoration: InputDecoration(
          hintText: 'Page number (1-$totalPages)',
          filled: true,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(Radii.md),
          ),
        ),
        autofocus: true,
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () {
            final page = int.tryParse(textCtrl.text);
            if (page != null && page >= 1 && page <= totalPages) {
              controller.jumpToPage(page);
              Navigator.pop(context);
            }
          },
          child: const Text('Go'),
        ),
      ],
    );
  }
}
