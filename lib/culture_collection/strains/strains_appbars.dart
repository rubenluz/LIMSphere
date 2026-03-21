import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '/theme/theme.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Normal AppBar
// ─────────────────────────────────────────────────────────────────────────────
PreferredSizeWidget buildStrainsNormalAppBar({
  required BuildContext context,
  required bool desktop,
  required dynamic filterSampleId,
  required bool showFilters,
  required VoidCallback onToggleFilters,
  required VoidCallback onAdd,
  required VoidCallback onRefresh,
  required VoidCallback onSelect,
  required VoidCallback onToggleColManager,
  required VoidCallback onImport,
}) {
  final btnColor = context.appTextSecondary;
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
          icon: Icon(icon, size: 16, color: btnColor),
          label: Text(label, style: GoogleFonts.spaceGrotesk(fontSize: 12, color: btnColor)),
          onPressed: onPressed,
          style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6)),
        ),
      );
    }
    return IconButton(
        icon: Icon(icon, size: 20, color: btnColor),
        tooltip: tooltip,
        onPressed: onPressed,
        padding: const EdgeInsets.all(8),
        constraints: const BoxConstraints(minWidth: 36, minHeight: 36));
  }

  return AppBar(
    backgroundColor: context.appSurface,
    foregroundColor: context.appTextPrimary,
    elevation: 0,
    titleSpacing: 12,
    title: Text(
        filterSampleId != null
            ? 'Strains — Sample $filterSampleId'
            : 'Strains',
        style: GoogleFonts.spaceGrotesk(fontWeight: FontWeight.w600, fontSize: 16)),
    actions: [
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2),
        child: TextButton.icon(
          icon: Icon(Icons.tune_rounded, size: 16,
              color: showFilters ? AppDS.accent : btnColor),
          label: Text('Filters',
              style: GoogleFonts.spaceGrotesk(
                  fontSize: 12,
                  color: showFilters ? AppDS.accent : btnColor)),
          onPressed: onToggleFilters,
          style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6)),
        ),
      ),
      btn(icon: Icons.refresh_rounded,       tooltip: 'Refresh',               label: 'Refresh',  onPressed: onRefresh),
      btn(icon: Icons.checklist_rounded,     tooltip: 'Select rows & columns', label: 'Select',   onPressed: onSelect),
      btn(icon: Icons.view_column_outlined,  tooltip: 'Manage columns',        label: 'Columns',  onPressed: onToggleColManager),
      btn(icon: Icons.upload_file_rounded,   tooltip: 'Import from Excel',     label: 'Import',   onPressed: onImport),
      const SizedBox(width: 8),
      Padding(
        padding: const EdgeInsets.only(right: 8),
        child: FilledButton.icon(
          style: FilledButton.styleFrom(
            backgroundColor: AppDS.accent,
            foregroundColor: const Color(0xFF0F172A),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
            minimumSize: const Size(0, 36),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
          onPressed: onAdd,
          icon: const Icon(Icons.add, size: 16),
          label: Text('Add Strain', style: GoogleFonts.spaceGrotesk(fontSize: 13)),
        ),
      ),
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