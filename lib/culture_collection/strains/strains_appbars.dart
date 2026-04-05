// strains_appbars.dart - Toolbar and AppBar variants for StrainsPage.

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '/menu/app_nav.dart';
import '/theme/theme.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Normal toolbar (matches stocks_page style — Container row, not AppBar)
// ─────────────────────────────────────────────────────────────────────────────
Widget buildStrainsToolbar({
  required BuildContext context,
  required bool desktop,
  required dynamic filterSampleId,
  required bool showFilters,
  required int filteredCount,
  required int totalCount,
  required String search,
  required TextEditingController searchController,
  required ValueChanged<String> onSearchChanged,
  required VoidCallback onToggleFilters,
  required VoidCallback onToggleColManager,
  required VoidCallback onImport,
  required VoidCallback onExport,
  required VoidCallback onAdd,
}) {
  final title = filterSampleId != null
      ? 'Strains — Sample $filterSampleId'
      : 'Strains';

  if (MediaQuery.of(context).size.width < 700) {
    // ── Mobile layout ──────────────────────────────────────────────────────
    return Container(
      height: 56,
      decoration: BoxDecoration(
        color: context.appSurface2,
        border: Border(bottom: BorderSide(color: context.appBorder)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Row(children: [
        IconButton(
          icon: Icon(Icons.menu_rounded, color: context.appTextSecondary),
          tooltip: 'Menu',
          onPressed: openAppDrawer,
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
        ),
        const SizedBox(width: 4),
        Expanded(
          child: SizedBox(
            height: 36,
            child: _buildSearchField(context, searchController, search, onSearchChanged),
          ),
        ),
        const SizedBox(width: 4),
        PopupMenuButton<String>(
          icon: Icon(Icons.more_vert, color: context.appTextSecondary, size: 20),
          tooltip: 'More options',
          offset: const Offset(0, 36),
          color: context.appSurface2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
            side: BorderSide(color: context.appBorder2)),
          onSelected: (v) {
            switch (v) {
              case 'filter':  onToggleFilters();
              case 'columns': onToggleColManager();
              case 'import':  onImport();
              case 'export':  onExport();
              case 'add':     onAdd();
            }
          },
          itemBuilder: (_) => [
            _popupItem(context, 'filter', Icons.tune,
                showFilters ? 'Hide Filters' : 'Show Filters',
                iconColor: showFilters ? AppDS.accent : null),
            _popupItem(context, 'columns', Icons.view_column_outlined, 'Columns'),
            _popupItem(context, 'import', Icons.upload_file_rounded, 'Import'),
            _popupItem(context, 'export', Icons.file_download_outlined, 'Export'),
            PopupMenuItem(
              value: 'add',
              child: Row(children: [
                const Icon(Icons.add, size: 16, color: AppDS.accent),
                const SizedBox(width: 10),
                Text('Add Strain', style: GoogleFonts.spaceGrotesk(
                    fontSize: 13, color: AppDS.accent)),
              ])),
          ],
        ),
      ]),
    );
  }

  // ── Desktop layout ─────────────────────────────────────────────────────────
  return Container(
    height: 56,
    decoration: BoxDecoration(
      color: context.appSurface2,
      border: Border(bottom: BorderSide(color: context.appBorder)),
    ),
    padding: const EdgeInsets.symmetric(horizontal: 16),
    child: Row(children: [
      const Icon(Icons.biotech_outlined, size: 18, color: Color(0xFF0EA5E9)),
      const SizedBox(width: 8),
      Text(title, style: GoogleFonts.spaceGrotesk(
        fontSize: 16, fontWeight: FontWeight.w600,
        color: context.appTextPrimary)),
      const SizedBox(width: 16),
      Expanded(
        child: SizedBox(
          height: 36,
          child: _buildSearchField(context, searchController, search, onSearchChanged),
        ),
      ),
      const SizedBox(width: 10),
      // Count badge
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: context.appSurface3,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: context.appBorder),
        ),
        child: Text('$filteredCount / $totalCount',
            style: GoogleFonts.jetBrainsMono(
                fontSize: 11, fontWeight: FontWeight.w600, color: context.appTextMuted)),
      ),
      const SizedBox(width: 4),
      // Filter
      Tooltip(
        message: showFilters ? 'Hide filters' : 'Show filters',
        child: Stack(children: [
          IconButton(
            icon: Icon(Icons.tune,
                color: showFilters ? AppDS.accent : context.appTextSecondary,
                size: 18),
            onPressed: onToggleFilters,
          ),
        ]),
      ),
      // Columns
      Tooltip(
        message: 'Manage columns',
        child: IconButton(
          icon: Icon(Icons.view_column_outlined,
              color: context.appTextSecondary, size: 18),
          onPressed: onToggleColManager,
        ),
      ),
      // Import
      Tooltip(
        message: 'Import from Excel',
        child: IconButton(
          icon: Icon(Icons.upload_file_rounded,
              color: context.appTextSecondary, size: 18),
          onPressed: onImport,
        ),
      ),
      // Export
      Tooltip(
        message: 'Export',
        child: IconButton(
          icon: Icon(Icons.file_download_outlined,
              color: context.appTextSecondary, size: 18),
          onPressed: onExport,
        ),
      ),
      // Add Strain
      FilledButton.icon(
        style: FilledButton.styleFrom(
          backgroundColor: AppDS.accent,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
          minimumSize: const Size(0, 36),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          textStyle: GoogleFonts.spaceGrotesk(fontSize: 13),
        ),
        onPressed: onAdd,
        icon: const Icon(Icons.add, size: 16),
        label: const Text('Add Strain'),
      ),
    ]),
  );
}

PopupMenuItem<String> _popupItem(
    BuildContext context, String value, IconData icon, String label,
    {Color? iconColor}) {
  return PopupMenuItem(
    value: value,
    child: Row(children: [
      Icon(icon, size: 16, color: iconColor ?? context.appTextSecondary),
      const SizedBox(width: 10),
      Text(label, style: GoogleFonts.spaceGrotesk(
          fontSize: 13, color: context.appTextPrimary)),
    ]),
  );
}

Widget _buildSearchField(
    BuildContext context,
    TextEditingController controller,
    String search,
    ValueChanged<String> onChanged) {
  return TextField(
    controller: controller,
    style: GoogleFonts.spaceGrotesk(fontSize: 13, color: context.appTextPrimary),
    decoration: InputDecoration(
      hintText: 'Search strains…',
      hintStyle: GoogleFonts.spaceGrotesk(color: context.appTextMuted, fontSize: 13),
      prefixIcon: Icon(Icons.search_rounded, color: context.appTextMuted, size: 16),
      suffixIcon: search.isNotEmpty
          ? IconButton(
              icon: Icon(Icons.clear, size: 14, color: context.appTextMuted),
              onPressed: () {
                controller.clear();
                onChanged('');
              })
          : null,
      isDense: true,
      filled: true,
      fillColor: context.appSurface3,
      border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: context.appBorder)),
      enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: context.appBorder)),
      focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: AppDS.accent, width: 1.5)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    ),
    onChanged: onChanged,
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
