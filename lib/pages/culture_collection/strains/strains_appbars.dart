import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '/theme/theme.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Normal AppBar
// ─────────────────────────────────────────────────────────────────────────────
PreferredSizeWidget buildStrainsNormalAppBar({
  required bool desktop,
  required dynamic filterSampleId,
  required VoidCallback onRefresh,
  required VoidCallback onSelect,
  required VoidCallback onPrint,
  required VoidCallback onToggleColManager,
  required VoidCallback onImport,
}) {
  Widget btn({
    required IconData icon,
    required String tooltip,
    required String label,
    required VoidCallback onPressed,
  }) {
    if (desktop) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2),
        child: TextButton.icon(
          icon: Icon(icon, size: 16, color: Colors.white70),
          label: Text(label, style: GoogleFonts.spaceGrotesk(fontSize: 12, color: Colors.white70)),
          onPressed: onPressed,
          style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6)),
        ),
      );
    }
    return IconButton(
        icon: Icon(icon, size: 20, color: Colors.white70),
        tooltip: tooltip,
        onPressed: onPressed,
        padding: const EdgeInsets.all(8),
        constraints: const BoxConstraints(minWidth: 36, minHeight: 36));
  }

  return AppBar(
    backgroundColor: AppDS.surface,
    foregroundColor: Colors.white,
    elevation: 0,
    title: Text(
        filterSampleId != null
            ? 'Strains — Sample $filterSampleId'
            : 'Strains',
        style: GoogleFonts.spaceGrotesk(fontWeight: FontWeight.w600, fontSize: 16)),
    actions: [
      btn(icon: Icons.refresh_rounded,       tooltip: 'Refresh',          label: 'Refresh',  onPressed: onRefresh),
      btn(icon: Icons.checklist_rounded,     tooltip: 'Select rows & columns', label: 'Select', onPressed: onSelect),
      btn(icon: Icons.print_outlined,        tooltip: 'Print',            label: 'Print',    onPressed: onPrint),
      btn(icon: Icons.view_column_outlined,  tooltip: 'Manage columns',   label: 'Columns',  onPressed: onToggleColManager),
      btn(icon: Icons.upload_file_rounded,   tooltip: 'Import from Excel', label: 'Import',  onPressed: onImport),
      const SizedBox(width: 4),
    ],
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// Selection AppBar
// ─────────────────────────────────────────────────────────────────────────────
PreferredSizeWidget buildStrainsSelectionAppBar({
  required bool desktop,
  required int rowCount,
  required int colCount,
  required bool allRowsSel,
  required bool allColsSel,
  required VoidCallback onExit,
  required VoidCallback onToggleAllRows,
  required VoidCallback onToggleAllCols,
  required VoidCallback onCopy,
  required VoidCallback onExport,
}) {
  Widget selBtn({
    required IconData icon,
    required String tooltip,
    required String label,
    required VoidCallback fn,
  }) {
    if (desktop) {
      return TextButton.icon(
        icon: Icon(icon, size: 16),
        label: Text(label, style: GoogleFonts.spaceGrotesk(fontSize: 12)),
        onPressed: fn,
        style: TextButton.styleFrom(
            foregroundColor: Colors.white70,
            padding: const EdgeInsets.symmetric(horizontal: 8)),
      );
    }
    return IconButton(
        icon: Icon(icon, size: 20),
        tooltip: tooltip,
        onPressed: fn,
        color: Colors.white70);
  }

  return AppBar(
    backgroundColor: const Color(0xFF1E3A5F),
    foregroundColor: Colors.white,
    elevation: 0,
    leading: IconButton(
        icon: const Icon(Icons.close),
        tooltip: 'Exit selection',
        onPressed: onExit),
    title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
              '$rowCount row${rowCount != 1 ? 's' : ''} · $colCount col${colCount != 1 ? 's' : ''}',
              style: GoogleFonts.spaceGrotesk(fontWeight: FontWeight.w600, fontSize: 15)),
          Text('Tap rows to select · tap column headers to pick columns',
              style: GoogleFonts.spaceGrotesk(fontSize: 10, color: Colors.white.withValues(alpha: 0.55))),
        ]),
    actions: [
      selBtn(
          icon: allRowsSel ? Icons.deselect : Icons.select_all,
          tooltip: allRowsSel ? 'Deselect all rows' : 'Select all rows',
          label: allRowsSel ? 'All rows ✓' : 'All rows',
          fn: onToggleAllRows),
      selBtn(
          icon: allColsSel ? Icons.view_column : Icons.view_column_outlined,
          tooltip: allColsSel ? 'Deselect all cols' : 'Select all cols',
          label: allColsSel ? 'All cols ✓' : 'All cols',
          fn: onToggleAllCols),
      Center(
          child: Container(
              width: 1,
              height: 22,
              margin: const EdgeInsets.symmetric(horizontal: 4),
              color: Colors.white24)),
      selBtn(
          icon: Icons.copy_rounded,
          tooltip: 'Copy to Clipboard',
          label: 'Copy to Clipboard',
          fn: onCopy),
      selBtn(
          icon: Icons.grid_on_rounded,
          tooltip: 'Export to Excel',
          label: 'Export to Excel',
          fn: onExport),
      const SizedBox(width: 4),
    ],
  );
}