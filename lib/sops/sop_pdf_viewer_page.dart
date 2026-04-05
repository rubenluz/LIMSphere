// sop_pdf_viewer_page.dart - In-app PDF viewer for SOP documents using the
// native PDF rendering plugin; page navigation controls.

import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';
import '/theme/theme.dart';

class SopPdfViewerPage extends StatefulWidget {
  final Uint8List bytes;
  final String title;
  final String filePath;
  final String fileName;

  const SopPdfViewerPage({
    super.key,
    required this.bytes,
    required this.title,
    required this.filePath,
    required this.fileName,
  });

  @override
  State<SopPdfViewerPage> createState() => _SopPdfViewerPageState();
}

class _SopPdfViewerPageState extends State<SopPdfViewerPage> {
  final _controller = PdfViewerController();
  bool _downloading = false;
  int _page = 1;
  int _totalPages = 0;

  void _snack(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: TextStyle(color: context.appTextPrimary)),
      backgroundColor: isError ? AppDS.red : context.appSurface3,
    ));
  }

  Future<void> _openExternally() async {
    try {
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/${widget.fileName}');
      await file.writeAsBytes(widget.bytes);
      await OpenFilex.open(file.path);
    } catch (e) {
      if (mounted) _snack('Could not open externally: $e', isError: true);
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
                fontSize: 14, fontWeight: FontWeight.w600, color: context.appTextPrimary,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            if (_totalPages > 0)
              Text(
                'Page $_page of $_totalPages',
                style: GoogleFonts.jetBrainsMono(
                  fontSize: 10, color: context.appTextMuted,
                ),
              ),
          ],
        ),
        actions: [
          TextButton.icon(
            onPressed: _openExternally,
            icon: Icon(Icons.open_in_new, size: 15, color: context.appTextSecondary),
            label: Text(
              'Open externally',
              style: GoogleFonts.spaceGrotesk(fontSize: 12, color: context.appTextSecondary),
            ),
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
                  label: Text(
                    'Download',
                    style: GoogleFonts.spaceGrotesk(fontSize: 12, color: AppDS.accent),
                  ),
                ),
          const SizedBox(width: 8),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: context.appBorder),
        ),
      ),
      body: SfPdfViewer.memory(
        widget.bytes,
        controller: _controller,
        onPageChanged: (details) {
          setState(() => _page = details.newPageNumber);
        },
        onDocumentLoaded: (details) {
          setState(() => _totalPages = details.document.pages.count);
        },
      ),
    );
  }
}
