// doc_viewer_page.dart - Document viewer router: detects file type (PDF/DOCX)
// and either shows it as PDF (native or converted) or as plain text.

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';
import '/theme/theme.dart';
import 'docx_to_pdf_converter.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Public enum — callers choose the rendering mode
// ─────────────────────────────────────────────────────────────────────────────
enum DocViewMode { pdf, txt, doc }

// ─────────────────────────────────────────────────────────────────────────────
// DocViewerPage
//   pdf → SfPdfViewer in-app
//   txt → scrollable plain-text view
//   doc → DOCX → PDF via docx_to_pdf_converter (LibreOffice or xml→pdf),
//         then displayed in SfPdfViewer. "Open Externally" always opens the
//         original DOCX file via the system app.
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
  int  _page       = 1;
  int  _totalPages = 0;
  bool _downloading = false;

  // DOCX conversion state
  Uint8List? _convertedPdf;
  bool       _converting = false;
  bool       _convertFailed = false;

  @override
  void initState() {
    super.initState();
    if (widget.viewMode == DocViewMode.doc) _convertDocx();
  }

  @override
  void dispose() {
    _txtScroll.dispose();
    super.dispose();
  }

  Future<void> _convertDocx() async {
    setState(() => _converting = true);
    try {
      final pdf = await convertDocxToPdf(widget.bytes, widget.fileName);
      if (!mounted) return;
      if (pdf != null) {
        setState(() { _convertedPdf = pdf; _converting = false; });
      } else {
        setState(() { _convertFailed = true; _converting = false; });
      }
    } catch (_) {
      if (mounted) setState(() { _convertFailed = true; _converting = false; });
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
            if (widget.viewMode != DocViewMode.txt && _totalPages > 0)
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

  // ── DOC (DOCX → PDF conversion) ──────────────────────────────────────────────
  Widget _buildDoc() {
    if (_converting) {
      return const Center(child: CircularProgressIndicator(color: AppDS.accent));
    }
    if (_convertFailed || _convertedPdf == null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.description_outlined, color: AppDS.textMuted, size: 40),
            const SizedBox(height: 16),
            Text(
              'No DOCX converter found',
              style: GoogleFonts.spaceGrotesk(
                  fontSize: 15, fontWeight: FontWeight.w600,
                  color: context.appTextPrimary),
            ),
            const SizedBox(height: 8),
            Text(
              'Install LibreOffice or Microsoft Office to enable\n'
              'in-app DOCX preview with full formatting.',
              textAlign: TextAlign.center,
              style: GoogleFonts.spaceGrotesk(
                  fontSize: 13, color: context.appTextMuted, height: 1.6),
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: _openExternally,
              style: FilledButton.styleFrom(
                backgroundColor: AppDS.accent,
                foregroundColor: Colors.black,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
              ),
              icon: const Icon(Icons.open_in_new, size: 16),
              label: Text('Open externally',
                  style: GoogleFonts.spaceGrotesk(fontWeight: FontWeight.w600)),
            ),
          ],
        ),
      );
    }
    return SfPdfViewer.memory(
      _convertedPdf!,
      controller: _pdfController,
      onPageChanged:    (d) => setState(() => _page       = d.newPageNumber),
      onDocumentLoaded: (d) => setState(() => _totalPages = d.document.pages.count),
    );
  }
}
