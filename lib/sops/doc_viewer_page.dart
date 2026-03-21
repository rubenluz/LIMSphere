import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:archive/archive.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';
import '/theme/theme.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Public enum — callers choose the rendering mode
// ─────────────────────────────────────────────────────────────────────────────
enum DocViewMode { pdf, txt, doc }

// ─────────────────────────────────────────────────────────────────────────────
// DocViewerPage
//   pdf → SfPdfViewer in-app
//   txt → scrollable plain-text view
//   doc → DOCX text extracted from ZIP/XML, shown with a "converted" banner
//         "Open Externally" always opens the original file via system app
// ─────────────────────────────────────────────────────────────────────────────
class DocViewerPage extends StatefulWidget {
  final Uint8List   bytes;
  final String      title;
  final String      fileName;
  final DocViewMode viewMode;

  const DocViewerPage({
    super.key,
    required this.bytes,
    required this.title,
    required this.fileName,
    required this.viewMode,
  });

  @override
  State<DocViewerPage> createState() => _DocViewerPageState();
}

class _DocViewerPageState extends State<DocViewerPage> {
  final _pdfController = PdfViewerController();
  final _txtScroll     = ScrollController();
  final _docScroll     = ScrollController();
  int  _page       = 1;
  int  _totalPages = 0;
  bool _downloading = false;

  // DOCX text state
  String? _docText;
  bool    _docExtracting = false;

  @override
  void initState() {
    super.initState();
    if (widget.viewMode == DocViewMode.doc) _extractDocxText();
  }

  @override
  void dispose() {
    _txtScroll.dispose();
    _docScroll.dispose();
    super.dispose();
  }

  void _extractDocxText() {
    setState(() => _docExtracting = true);
    try {
      final archive = ZipDecoder().decodeBytes(widget.bytes.toList());
      final xmlFile = archive.findFile('word/document.xml');
      if (xmlFile == null) {
        setState(() { _docText = '[word/document.xml not found in archive]'; _docExtracting = false; });
        return;
      }
      final xml = utf8.decode(xmlFile.content as List<int>);
      final paragraphs = <String>[];
      final paraRe = RegExp(r'<w:p[ >].*?</w:p>', dotAll: true);
      final textRe = RegExp(r'<w:t[^>]*>(.*?)</w:t>',  dotAll: true);
      for (final p in paraRe.allMatches(xml)) {
        final text = textRe
            .allMatches(p.group(0)!)
            .map((m) => m.group(1) ?? '')
            .join('');
        if (text.trim().isNotEmpty) paragraphs.add(text.trim());
      }
      setState(() {
        _docText       = paragraphs.isEmpty ? '[No text content found]' : paragraphs.join('\n\n');
        _docExtracting = false;
      });
    } catch (e) {
      setState(() { _docText = '[Extraction failed: $e]'; _docExtracting = false; });
    }
  }

  void _snack(String msg, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: TextStyle(color: context.appTextPrimary)),
      backgroundColor: isError ? AppDS.red : context.appSurface3,
    ));
  }

  Future<void> _openExternally() async {
    try {
      final dir  = await getTemporaryDirectory();
      final file = File('${dir.path}/${widget.fileName}');
      await file.writeAsBytes(widget.bytes);
      await OpenFilex.open(file.path);
    } catch (e) {
      if (mounted) _snack('Could not open: $e', isError: true);
    }
  }

  Future<void> _download() async {
    setState(() => _downloading = true);
    try {
      Directory dir;
      try {
        dir = await getDownloadsDirectory() ?? await getApplicationDocumentsDirectory();
      } catch (_) {
        dir = await getTemporaryDirectory();
      }
      final file = File('${dir.path}/${widget.fileName}');
      await file.writeAsBytes(widget.bytes);
      if (mounted) _snack('Saved to ${file.path}');
    } catch (e) {
      if (mounted) _snack('Download failed: $e', isError: true);
    } finally {
      if (mounted) setState(() => _downloading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.appBg,
      appBar: AppBar(
        backgroundColor: context.appSurface,
        foregroundColor: context.appTextPrimary,
        elevation: 0,
        titleSpacing: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.title,
              style: GoogleFonts.spaceGrotesk(
                  fontSize: 14, fontWeight: FontWeight.w600, color: context.appTextPrimary),
              maxLines: 1, overflow: TextOverflow.ellipsis,
            ),
            if (widget.viewMode == DocViewMode.pdf && _totalPages > 0)
              Text('Page $_page of $_totalPages',
                  style: GoogleFonts.jetBrainsMono(fontSize: 10, color: context.appTextMuted)),
          ],
        ),
        actions: [
          TextButton.icon(
            onPressed: _openExternally,
            icon: Icon(Icons.open_in_new, size: 15, color: context.appTextSecondary),
            label: Text('Open externally',
                style: GoogleFonts.spaceGrotesk(fontSize: 12, color: context.appTextSecondary)),
          ),
          const SizedBox(width: 4),
          _downloading
              ? const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  child: SizedBox(width: 18, height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: AppDS.accent)),
                )
              : TextButton.icon(
                  onPressed: _download,
                  icon: const Icon(Icons.download_outlined, size: 15, color: AppDS.accent),
                  label: Text('Download',
                      style: GoogleFonts.spaceGrotesk(fontSize: 12, color: AppDS.accent)),
                ),
          const SizedBox(width: 8),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: context.appBorder),
        ),
      ),
      body: switch (widget.viewMode) {
        DocViewMode.pdf => _buildPdf(),
        DocViewMode.txt => _buildTxt(),
        DocViewMode.doc => _buildDoc(),
      },
    );
  }

  // ── PDF ──────────────────────────────────────────────────────────────────────
  Widget _buildPdf() => SfPdfViewer.memory(
    widget.bytes,
    controller: _pdfController,
    onPageChanged:    (d) => setState(() => _page       = d.newPageNumber),
    onDocumentLoaded: (d) => setState(() => _totalPages = d.document.pages.count),
  );

  // ── TXT ──────────────────────────────────────────────────────────────────────
  Widget _buildTxt() {
    final text = utf8.decode(widget.bytes, allowMalformed: true);
    return Scrollbar(
      controller: _txtScroll,
      child: SingleChildScrollView(
        controller: _txtScroll,
        padding: const EdgeInsets.all(24),
        child: SelectableText(
          text,
          style: GoogleFonts.jetBrainsMono(fontSize: 13, color: context.appTextPrimary, height: 1.6),
        ),
      ),
    );
  }

  // ── DOC (text extraction) ────────────────────────────────────────────────────
  Widget _buildDoc() {
    if (_docExtracting) {
      return const Center(child: CircularProgressIndicator(color: AppDS.accent));
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Converted-file banner
        Container(
          color: const Color(0xFF2B5EB8).withValues(alpha: 0.12),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          child: Row(children: [
            const Icon(Icons.info_outline, size: 15, color: Color(0xFF7AA8F0)),
            const SizedBox(width: 8),
            Expanded(child: Text(
              'Converted view — original formatting may differ. '
              'Use "Open externally" to view the original DOCX file.',
              style: GoogleFonts.spaceGrotesk(fontSize: 12, color: const Color(0xFF7AA8F0)),
            )),
          ]),
        ),
        Expanded(
          child: Scrollbar(
            controller: _docScroll,
            child: SingleChildScrollView(
              controller: _docScroll,
              padding: const EdgeInsets.all(24),
              child: SelectableText(
                _docText ?? '',
                style: GoogleFonts.spaceGrotesk(
                    fontSize: 13, color: context.appTextPrimary, height: 1.7),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
