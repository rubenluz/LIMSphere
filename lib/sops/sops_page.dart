// sops_page.dart - SOP library: list with type/status/tag filters,
// file upload to Supabase storage, PDF/DOCX viewer integration.
// Widget and dialog classes extracted to sops_widgets.dart (part).

import 'dart:io';
import 'dart:typed_data';
import 'package:archive/archive_io.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '/core/data_cache.dart';
import '/core/sop_db_schema.dart';
import '/supabase/supabase_manager.dart';
import '../camera/qr_scanner/qr_code_rules.dart';
import '/theme/theme.dart';
import '../fish_facility/shared_widgets.dart';
import 'sop_model.dart';
import 'doc_viewer_page.dart';

part 'sops_widgets.dart';

// ── Design tokens ─────────────────────────────────────────────────────────────
class _DS {
  static Color typeColor(String? t) {
    switch (t) {
      case 'sop':       return const Color(0xFF06B6D4);
      case 'protocol':  return AppDS.purple;
      case 'guideline': return AppDS.green;
      case 'checklist': return AppDS.orange;
      case 'form':      return AppDS.blue;
      case 'training':  return AppDS.pink;
      default:          return AppDS.textSecondary;
    }
  }

  static Color statusColor(String? s) {
    switch (s) {
      case 'active':       return AppDS.green;
      case 'draft':        return AppDS.yellow;
      case 'under_review': return const Color(0xFF06B6D4);
      case 'archived':     return AppDS.textMuted;
      case 'superseded':   return AppDS.red;
      default:             return AppDS.textSecondary;
    }
  }
}

final _dateFmt = DateFormat('yyyy-MM-dd');

// Deterministic tag colour — same text always maps to same colour.
Color _tagColor(String tag) {
  const palette = [
    Color(0xFF06B6D4), // cyan
    Color(0xFF8B5CF6), // violet
    Color(0xFF10B981), // emerald
    Color(0xFFF59E0B), // amber
    Color(0xFFEC4899), // pink
    Color(0xFF3B82F6), // blue
    Color(0xFFF97316), // orange
    Color(0xFFEF4444), // red
    Color(0xFF14B8A6), // teal
    Color(0xFFA3E635), // lime
  ];
  final hash = tag.codeUnits.fold(0, (h, c) => (h * 31 + c) & 0x7FFFFFFF);
  return palette[hash % palette.length];
}

// ═════════════════════════════════════════════════════════════════════════════
// SopPage
// ═════════════════════════════════════════════════════════════════════════════
class SopPage extends StatefulWidget {
  /// 'fish_facility' | 'culture_collection'
  final String sopContext;
  const SopPage({super.key, required this.sopContext});

  @override
  State<SopPage> createState() => _SopPageState();
}

class _SopPageState extends State<SopPage> {
  List<FacilitySop> _sops     = [];
  List<FacilitySop> _filtered = [];
  final _search = TextEditingController();
  bool    _loading = true;
  String? _error;
  String  _filterType   = 'all';
  String  _filterStatus = 'all';
  bool    _showFilters  = false;

  @override
  void initState() {
    super.initState();
    _load();
    _search.addListener(_applyFilter);
  }

  @override
  void didUpdateWidget(SopPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.sopContext != widget.sopContext) {
      _sops     = [];
      _filtered = [];
      _filterType   = 'all';
      _filterStatus = 'all';
      _search.clear();
      _load();
    }
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  // ── Data ──────────────────────────────────────────────────────────────────
  Future<void> _load() async {
    final cacheKey = 'sops_${widget.sopContext}';
    final cached = await DataCache.read(cacheKey);
    if (cached != null && mounted) {
      _sops = cached.map((r) => FacilitySop.fromMap(Map<String, dynamic>.from(r as Map))).toList();
      _applyFilter();
      setState(() { _loading = false; _error = null; });
    } else {
      setState(() { _loading = true; _error = null; });
    }
    try {
      final rows = await Supabase.instance.client
          .from(SopSch.table)
          .select()
          .eq(SopSch.context, widget.sopContext)
          .order(SopSch.name) as List<dynamic>;
      await DataCache.write(cacheKey, rows);
      if (!mounted) return;
      _sops = rows
          .map((r) => FacilitySop.fromMap(Map<String, dynamic>.from(r as Map)))
          .toList();
      _applyFilter();
      setState(() => _loading = false);
    } catch (e) {
      if (cached == null && mounted) setState(() { _loading = false; _error = e.toString(); });
    }
  }

  void _applyFilter() {
    var d = _sops.toList();
    final q = _search.text.toLowerCase();
    if (q.isNotEmpty) {
      d = d.where((s) =>
        s.name.toLowerCase().contains(q) ||
        (s.code?.toLowerCase().contains(q)        ?? false) ||
        (s.category?.toLowerCase().contains(q)    ?? false) ||
        (s.responsible?.toLowerCase().contains(q) ?? false) ||
        (s.description?.toLowerCase().contains(q) ?? false) ||
        (s.tags?.toLowerCase().contains(q)        ?? false)
      ).toList();
    }
    if (_filterType   != 'all') d = d.where((s) => s.type   == _filterType).toList();
    if (_filterStatus != 'all') d = d.where((s) => s.status == _filterStatus).toList();
    setState(() => _filtered = d);
  }

  // ── Actions ───────────────────────────────────────────────────────────────
  void _snack(String msg, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: TextStyle(color: context.appTextPrimary)),
      backgroundColor: isError ? AppDS.red : context.appSurface3,
    ));
  }

  Future<void> _deleteSop(FacilitySop sop) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (dlgCtx) => AlertDialog(
        backgroundColor: dlgCtx.appSurface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Text('Delete SOP',
            style: GoogleFonts.spaceGrotesk(
                color: dlgCtx.appTextPrimary, fontWeight: FontWeight.w700)),
        content: Text('Delete "${sop.name}"? This cannot be undone.',
            style: GoogleFonts.spaceGrotesk(color: dlgCtx.appTextSecondary)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel',
                style: GoogleFonts.spaceGrotesk(color: dlgCtx.appTextSecondary)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('Delete',
                style: GoogleFonts.spaceGrotesk(color: AppDS.red)),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      if (sop.hasFile) {
        await Supabase.instance.client.storage
            .from(SopSch.bucket)
            .remove([sop.filePath!]);
      }
      await Supabase.instance.client
          .from(SopSch.table)
          .delete()
          .eq(SopSch.id, sop.id!);
      _snack('Deleted "${sop.name}"');
      _load();
    } catch (e) {
      _snack('Delete failed: $e', isError: true);
    }
  }

  Future<void> _openSopFile(
      FacilitySop sop, String filePath, String fileName, DocViewMode mode) async {
    final messenger = ScaffoldMessenger.of(context);
    messenger.showSnackBar(const SnackBar(
      content: Text('Loading file…'), duration: Duration(seconds: 30),
    ));
    try {
      final bytes = await Supabase.instance.client.storage
          .from(SopSch.bucket)
          .download(filePath);
      messenger.hideCurrentSnackBar();
      if (!mounted) return;
      Navigator.push(context, MaterialPageRoute(
        builder: (_) => DocViewerPage(
          bytes: bytes, title: sop.name, fileName: fileName, viewMode: mode,
        ),
      ));
    } catch (e) {
      messenger.hideCurrentSnackBar();
      if (mounted) _snack('Failed to open: $e', isError: true);
    }
  }

  void _showDialog({FacilitySop? sop}) async {
    final saved = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _SopDialog(sop: sop, sopContext: widget.sopContext),
    );
    if (saved == true) _load();
  }

  bool get _hasActiveFilter => _filterType != 'all' || _filterStatus != 'all';

  Future<void> _exportCsv() async {
    final buf = StringBuffer();
    buf.writeln('Code,Name,Type,Status,Category,Responsible,Version,Review Date,Tags,Description');
    for (final s in _filtered) {
      buf.writeln(
        '"${s.code ?? ''}","${s.name}","${FacilitySop.typeLabel(s.type)}","${FacilitySop.statusLabel(s.status)}","${s.category ?? ''}","${s.responsible ?? ''}","${s.version ?? ''}","${s.reviewDate != null ? _dateFmt.format(s.reviewDate!) : ''}","${s.tags ?? ''}","${(s.description ?? '').replaceAll('"', "'")}"',
      );
    }
    try {
      final dir = await getDownloadsDirectory() ?? await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/sops_${DateTime.now().millisecondsSinceEpoch}.csv');
      await file.writeAsString(buf.toString());
      await OpenFilex.open(file.path);
    } catch (e) {
      _snack('Export failed: $e', isError: true);
    }
  }

  Future<void> _downloadAllFiles() async {
    final toDownload = _filtered.where((s) => s.hasAnyFile).toList();
    if (toDownload.isEmpty) {
      _snack('No files to download in the current selection.');
      return;
    }
    _snack('Preparing ${toDownload.length} file(s)…');
    try {
      final encoder = ZipEncoder();
      final archive = Archive();
      for (final sop in toDownload) {
        for (final (path, name) in [
          if (sop.hasPdfFile) (sop.filePath!,    sop.fileName    ?? 'file.pdf'),
          if (sop.hasTxtFile) (sop.txtFilePath!, sop.txtFileName ?? 'file.txt'),
          if (sop.hasDocFile) (sop.docFilePath!, sop.docFileName ?? 'file.docx'),
        ]) {
          final bytes = await Supabase.instance.client.storage
              .from(SopSch.bucket)
              .download(path);
          archive.addFile(ArchiveFile(name, bytes.length, bytes));
        }
      }
      final dir = await getDownloadsDirectory() ?? await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/sops_files_${DateTime.now().millisecondsSinceEpoch}.zip');
      final encoded = encoder.encode(archive);
      await file.writeAsBytes(encoded);
      if (!mounted) return;
      await OpenFilex.open(file.path);
    } catch (e) {
      if (mounted) _snack('Download failed: $e', isError: true);
    }
  }

  // ── Build ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildToolbar(),
        if (_showFilters) _buildFilterPanel(),
        Expanded(child: _buildBody()),
      ],
    );
  }

  Widget _buildFilterPanel() {
    return Container(
      decoration: BoxDecoration(
        color: context.appSurface,
        border: Border(bottom: BorderSide(color: context.appBorder)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(children: [
            Text('Type',
                style: GoogleFonts.spaceGrotesk(
                    color: context.appTextMuted,
                    fontSize: 11,
                    fontWeight: FontWeight.w600)),
            const SizedBox(width: 12),
            _FilterChip(
              label: 'All',
              selected: _filterType == 'all',
              onTap: () { setState(() => _filterType = 'all'); _applyFilter(); },
            ),
            ...FacilitySop.types.map((t) => Padding(
              padding: const EdgeInsets.only(left: 6),
              child: _FilterChip(
                label: FacilitySop.typeLabel(t),
                selected: _filterType == t,
                color: _DS.typeColor(t),
                onTap: () { setState(() => _filterType = t); _applyFilter(); },
              ),
            )),
          ]),
          const SizedBox(height: 8),
          Row(children: [
            Text('Status',
                style: GoogleFonts.spaceGrotesk(
                    color: context.appTextMuted,
                    fontSize: 11,
                    fontWeight: FontWeight.w600)),
            const SizedBox(width: 12),
            _FilterChip(
              label: 'All',
              selected: _filterStatus == 'all',
              onTap: () { setState(() => _filterStatus = 'all'); _applyFilter(); },
            ),
            ...FacilitySop.statuses.map((s) => Padding(
              padding: const EdgeInsets.only(left: 6),
              child: _FilterChip(
                label: FacilitySop.statusLabel(s),
                selected: _filterStatus == s,
                color: _DS.statusColor(s),
                onTap: () { setState(() => _filterStatus = s); _applyFilter(); },
              ),
            )),
          ]),
        ],
      ),
    );
  }

  Widget _buildToolbar() {
    return Container(
      height: 56,
      decoration: BoxDecoration(
        color: context.appSurface2,
        border: Border(bottom: BorderSide(color: context.appBorder)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(children: [
        if (MediaQuery.of(context).size.width < 700) ...[
          IconButton(
            icon: const Icon(Icons.menu_rounded, size: 20),
            color: context.appTextSecondary,
            tooltip: 'Menu',
            onPressed: () => Scaffold.of(context).openDrawer(),
          ),
        ],
        const Icon(Icons.menu_book_outlined, color: AppDS.accent, size: 18),
        const SizedBox(width: 8),
        Text('SOPs',
            style: GoogleFonts.spaceGrotesk(
                color: context.appTextPrimary,
                fontSize: 16,
                fontWeight: FontWeight.w600)),
        const SizedBox(width: 16),
        Expanded(
          child: SizedBox(
            height: 36,
            child: AppSearchBar(
              controller: _search,
              hint: 'Search SOPs…',
              onClear: _applyFilter,
            ),
          ),
        ),
        const SizedBox(width: 4),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Text(
            '${_filtered.length} record${_filtered.length == 1 ? '' : 's'}',
            style: GoogleFonts.spaceGrotesk(fontSize: 12, color: context.appTextMuted),
          ),
        ),
        Tooltip(
          message: _showFilters ? 'Hide filters' : 'Show filters',
          child: Stack(children: [
            IconButton(
              icon: Icon(Icons.tune,
                  color: _showFilters ? AppDS.accent : context.appTextSecondary,
                  size: 18),
              onPressed: () => setState(() => _showFilters = !_showFilters),
            ),
            if (_hasActiveFilter)
              Positioned(
                right: 6, top: 6,
                child: Container(
                  width: 7, height: 7,
                  decoration: const BoxDecoration(color: AppDS.accent, shape: BoxShape.circle),
                ),
              ),
          ]),
        ),
        Tooltip(
          message: 'Download files as ZIP',
          child: IconButton(
            icon: Icon(Icons.folder_zip_outlined, color: context.appTextSecondary, size: 18),
            onPressed: _downloadAllFiles,
          ),
        ),
        Tooltip(
          message: 'Export CSV',
          child: IconButton(
            icon: Icon(Icons.download_outlined, color: context.appTextSecondary, size: 18),
            onPressed: _exportCsv,
          ),
        ),
        FilledButton.icon(
          style: FilledButton.styleFrom(
            backgroundColor: AppDS.accent,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
            minimumSize: const Size(0, 36),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            textStyle: GoogleFonts.spaceGrotesk(fontSize: 13),
          ),
          onPressed: () => _showDialog(),
          icon: const Icon(Icons.add, size: 16),
          label: const Text('New SOP'),
        ),
      ]),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator(color: AppDS.accent));
    }
    if (_error != null) {
      return Center(child: Text(_error!, style: const TextStyle(color: AppDS.red)));
    }
    if (_filtered.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.menu_book_outlined, size: 52, color: context.appTextMuted),
            const SizedBox(height: 14),
            Text(
              _sops.isEmpty
                  ? 'No SOPs yet — add your first one!'
                  : 'No SOPs match your search.',
              style: GoogleFonts.spaceGrotesk(
                  fontSize: 14, color: context.appTextSecondary),
            ),
          ],
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      itemCount: _filtered.length,
      itemBuilder: (_, i) {
        final sop = _filtered[i];
        return _SopCard(
          sop: sop,
          onEdit:     () => _showDialog(sop: sop),
          onDelete:   () => _deleteSop(sop),
          onOpenPdf:  sop.hasPdfFile ? () => _openSopFile(sop, sop.filePath!,    sop.fileName    ?? 'document.pdf',  DocViewMode.pdf) : null,
          onOpenTxt:  sop.hasTxtFile ? () => _openSopFile(sop, sop.txtFilePath!, sop.txtFileName ?? 'document.txt',  DocViewMode.txt) : null,
          onOpenDoc:  sop.hasDocFile ? () => _openSopFile(sop, sop.docFilePath!, sop.docFileName ?? 'document.docx', DocViewMode.doc) : null,
        );
      },
    );
  }
}

