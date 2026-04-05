// strains_toolbar.dart - Secondary toolbar: cycle chips, sort chips, active
// filter chips.

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'strains_columns.dart';
import 'strains_design_tokens.dart';
import 'strains_grid_widgets.dart';
import '/theme/theme.dart';


// ─────────────────────────────────────────────────────────────────────────────
// Toolbar
// ─────────────────────────────────────────────────────────────────────────────
class StrainsToolbar extends StatelessWidget {
  final List<ActiveFilter> activeFilters;
  final List<String> sortKeys;
  final Map<String, bool> sortDirs;
  final List<int> periodicityOptions;
  final int? selectedPeriodicity;

  final VoidCallback onClearSort;
  final void Function(int i, String key) onRemoveSortKey;
  final void Function(int? v) onPeriodicityChanged;
  final VoidCallback onClearFilters;

  const StrainsToolbar({
    super.key,
    required this.activeFilters,
    required this.sortKeys,
    required this.sortDirs,
    required this.periodicityOptions,
    required this.selectedPeriodicity,
    required this.onClearSort,
    required this.onRemoveSortKey,
    required this.onPeriodicityChanged,
    required this.onClearFilters,
  });

  @override
  Widget build(BuildContext context) {
    final hasActive = activeFilters.any((f) => f.value.isNotEmpty) ||
        selectedPeriodicity != null;
    final hasSort = sortKeys.isNotEmpty;
    final hasCycle = periodicityOptions.isNotEmpty;

    // Hide entirely when nothing to show
    if (!hasCycle && !hasSort && !hasActive) return const SizedBox.shrink();

    return Container(
      color: context.appSurface,
      padding: const EdgeInsets.fromLTRB(12, 6, 12, 6),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // ── Cycle chips row (aligned left) ───────────────────────────────────
        if (hasCycle)
          Row(children: [
            Text('Cycle:',
                style: GoogleFonts.spaceGrotesk(
                    fontSize: 11,
                    color: context.appTextSecondary,
                    fontWeight: FontWeight.w600)),
            const SizedBox(width: 6),
            ...periodicityOptions.map((d) => Padding(
                padding: const EdgeInsets.only(right: 4),
                child: ToolbarChip(
                    label: '${d}d',
                    selected: selectedPeriodicity == d,
                    compact: true,
                    onTap: () => onPeriodicityChanged(
                        selectedPeriodicity == d ? null : d)))),
          ]),
        if (hasSort) ...[
          if (hasCycle) const SizedBox(height: 6),
          SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(children: [
                Text('Sort:',
                    style: GoogleFonts.spaceGrotesk(
                        fontSize: 11,
                        color: context.appTextSecondary,
                        fontWeight: FontWeight.w600)),
                const SizedBox(width: 6),
                ...sortKeys.asMap().entries.map((e) => Padding(
                    padding: const EdgeInsets.only(right: 4),
                    child: InputChip(
                      label: Text(
                          '${e.value} ${sortDirs[e.value] == true ? "↑" : "↓"}',
                          style: GoogleFonts.spaceGrotesk(fontSize: 11, color: context.appTextPrimary)),
                      selected: true,
                      selectedColor: context.appSurface2,
                      side: const BorderSide(color: AppDS.accent),
                      onDeleted: () => onRemoveSortKey(e.key, e.value),
                      deleteIconColor: context.appTextSecondary,
                      visualDensity: VisualDensity.compact,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(6)),
                    ))),
                TextButton.icon(
                    icon: Icon(Icons.clear, size: 13, color: context.appTextSecondary),
                    label: Text('Clear sorts',
                        style: GoogleFonts.spaceGrotesk(fontSize: 12, color: context.appTextSecondary)),
                    onPressed: onClearSort),
              ])),
        ],
        if (hasActive) ...[
          if (hasCycle || hasSort) const SizedBox(height: 6),
          SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(children: [
                ...activeFilters.map((f) => Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: InputChip(
                      label: Text(
                          '${f.label}: ${f.value.isEmpty ? "…" : f.value}',
                          style: GoogleFonts.spaceGrotesk(fontSize: 11, color: context.appTextPrimary)),
                      selected: f.value.isNotEmpty,
                      selectedColor: context.appSurface2,
                      side: const BorderSide(color: AppDS.accent),
                      onDeleted: () => onClearFilters(),
                      deleteIconColor: context.appTextSecondary,
                      visualDensity: VisualDensity.compact,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(6)),
                    ))),
                if (selectedPeriodicity != null)
                  Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: InputChip(
                        label: Text('Cycle: ${selectedPeriodicity}d',
                            style: GoogleFonts.spaceGrotesk(fontSize: 11, color: context.appTextPrimary)),
                        selected: true,
                        selectedColor: context.appSurface2,
                        side: const BorderSide(color: AppDS.accent),
                        onDeleted: () => onPeriodicityChanged(null),
                        deleteIconColor: context.appTextSecondary,
                        visualDensity: VisualDensity.compact,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(6)),
                      )),
                TextButton.icon(
                    icon: Icon(Icons.clear, size: 13, color: context.appTextSecondary),
                    label: Text('Clear all',
                        style: GoogleFonts.spaceGrotesk(fontSize: 12, color: context.appTextSecondary)),
                    onPressed: onClearFilters),
              ])),
        ],
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Filter panel
// ─────────────────────────────────────────────────────────────────────────────
class StrainsFilterPanel extends StatefulWidget {
  final List<ActiveFilter> activeFilters;
  final bool hideEmpty;
  final VoidCallback onDetectEmpty;
  final VoidCallback onShowEmpty;
  final void Function(ActiveFilter f) onAddFilter;
  final void Function(ActiveFilter f) onRemoveFilter;
  final void Function(ActiveFilter f, String v) onFilterChanged;

  const StrainsFilterPanel({
    super.key,
    required this.activeFilters,
    required this.hideEmpty,
    required this.onDetectEmpty,
    required this.onShowEmpty,
    required this.onAddFilter,
    required this.onRemoveFilter,
    required this.onFilterChanged,
  });

  @override
  State<StrainsFilterPanel> createState() => _StrainsFilterPanelState();
}

class _StrainsFilterPanelState extends State<StrainsFilterPanel> {
  String? _pickedColKey;

  @override
  Widget build(BuildContext context) {
    final filterableCols = strainAllColumns.where((c) => !c.readOnly).toList();

    return Container(
      decoration: BoxDecoration(
          color: context.appSurface2,
          border: Border(
              bottom: BorderSide(color: context.appBorder),
              top: BorderSide(color: context.appBorder))),
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Icon(Icons.tune_rounded, size: 15, color: AppDS.accent),
          const SizedBox(width: 6),
          Text('Advanced Filters',
              style: GoogleFonts.spaceGrotesk(
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                  color: AppDS.accent)),
          const Spacer(),
          Row(mainAxisSize: MainAxisSize.min, children: [
            Text('Hide empty',
                style: GoogleFonts.spaceGrotesk(fontSize: 11, color: context.appTextSecondary)),
            Transform.scale(
                scale: 0.75,
                child: Switch(
                  value: widget.hideEmpty,
                  activeThumbColor: AppDS.accent,
                  onChanged: (v) => v ? widget.onDetectEmpty() : widget.onShowEmpty(),
                )),
          ]),
        ]),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(
              child: DropdownButtonFormField<String>(
            initialValue: _pickedColKey,
            isExpanded: true,
            isDense: true,
            dropdownColor: context.appSurface2,
            style: GoogleFonts.spaceGrotesk(color: context.appTextPrimary, fontSize: 12),
            decoration: InputDecoration(
                labelText: 'Add filter by column…',
                labelStyle: GoogleFonts.spaceGrotesk(color: context.appTextSecondary, fontSize: 12),
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
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 8)),
            items: filterableCols
                .map((col) => DropdownMenuItem(
                    value: col.key,
                    child: Text(col.label,
                        style: GoogleFonts.spaceGrotesk(fontSize: 12, color: context.appTextPrimary))))
                .toList(),
            onChanged: (v) => setState(() => _pickedColKey = v),
          )),
          const SizedBox(width: 8),
          FilledButton.icon(
              icon: const Icon(Icons.add, size: 15),
              label: Text('Add', style: GoogleFonts.spaceGrotesk()),
              style: FilledButton.styleFrom(
                  backgroundColor: AppDS.accent,
                  foregroundColor: const Color(0xFF0F172A)),
              onPressed: _pickedColKey == null
                  ? null
                  : () {
                      final col = strainAllColumns
                          .firstWhere((c) => c.key == _pickedColKey);
                      if (widget.activeFilters.any((f) => f.column == _pickedColKey)) {
                        return;
                      }
                      widget.onAddFilter(ActiveFilter(col.key, col.label, ''));
                      setState(() => _pickedColKey = null);
                    }),
        ]),
        if (widget.activeFilters.isNotEmpty) ...[
          const SizedBox(height: 8),
          ...widget.activeFilters.map((f) => Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(children: [
                Expanded(
                    child: TextField(
                  controller: TextEditingController(text: f.value)
                    ..selection =
                        TextSelection.fromPosition(TextPosition(offset: f.value.length)),
                  style: GoogleFonts.spaceGrotesk(fontSize: 13, color: context.appTextPrimary),
                  decoration: InputDecoration(
                      labelText: f.label,
                      labelStyle: GoogleFonts.spaceGrotesk(color: context.appTextSecondary, fontSize: 12),
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
                      contentPadding:
                          const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      suffixIcon: f.value.isNotEmpty
                          ? IconButton(
                              icon: Icon(Icons.clear, size: 15, color: context.appTextSecondary),
                              onPressed: () => widget.onFilterChanged(f, ''))
                          : null),
                  onChanged: (v) => widget.onFilterChanged(f, v),
                )),
                IconButton(
                    icon: const Icon(Icons.delete_outline, size: 17, color: Color(0xFFEF4444)),
                    onPressed: () => widget.onRemoveFilter(f)),
              ]))),
        ],
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Column manager
// ─────────────────────────────────────────────────────────────────────────────
class StrainsColumnManager extends StatelessWidget {
  final List<String>? colOrder;
  final Map<String, double> colWidths;
  final Set<String> hiddenCols;
  final Set<String> emptyColKeys;
  final VoidCallback onClose;
  final VoidCallback onResetAll;
  final void Function(String key, int newPos) onReorder;
  final void Function(String key, double width) onWidthChanged;
  final void Function(String key, bool visible) onVisibilityChanged;

  const StrainsColumnManager({
    super.key,
    required this.colOrder,
    required this.colWidths,
    required this.hiddenCols,
    required this.emptyColKeys,
    required this.onClose,
    required this.onResetAll,
    required this.onReorder,
    required this.onWidthChanged,
    required this.onVisibilityChanged,
  });

  @override
  Widget build(BuildContext context) {
    final orderedKeys = colOrder ?? strainAllColumns.map((c) => c.key).toList();
    final displayKeys = [
      ...orderedKeys,
      ...strainAllColumns.map((c) => c.key).where((k) => !orderedKeys.contains(k)),
    ];

    return Container(
      constraints: const BoxConstraints(maxHeight: 420),
      decoration: BoxDecoration(
        color: context.appSurface,
        border: Border(bottom: BorderSide(color: context.appBorder)),
        boxShadow: const [
          BoxShadow(
              color: Color(0x28000000),
              blurRadius: 6,
              offset: Offset(0, 3))
        ],
      ),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        // Header
        Container(
          padding: const EdgeInsets.fromLTRB(14, 10, 10, 8),
          decoration: BoxDecoration(
            color: context.appSurface2,
            border: Border(bottom: BorderSide(color: context.appBorder)),
          ),
          child: Row(children: [
            const Icon(Icons.view_column_outlined, size: 16, color: AppDS.accent),
            const SizedBox(width: 8),
            Text('Column Manager',
                style: GoogleFonts.spaceGrotesk(
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                    color: context.appTextPrimary)),
            const Spacer(),
            TextButton.icon(
              icon: const Icon(Icons.restart_alt_rounded, size: 14),
              label: Text('Reset all',
                  style: GoogleFonts.spaceGrotesk(fontSize: 12)),
              style: TextButton.styleFrom(
                  foregroundColor: const Color(0xFFEF4444),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6)),
              onPressed: onResetAll,
            ),
            const SizedBox(width: 4),
            IconButton(
              icon: Icon(Icons.close, size: 17, color: context.appTextSecondary),
              onPressed: onClose,
              tooltip: 'Close',
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 30, minHeight: 30),
            ),
          ]),
        ),
        // Column header labels
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
          color: context.appSurface2,
          child: Row(children: [
            SizedBox(width: 36, child: Text('#', style: GoogleFonts.spaceGrotesk(fontSize: 10, fontWeight: FontWeight.w700, color: context.appTextSecondary))),
            const SizedBox(width: 8),
            Expanded(child: Text('Column', style: GoogleFonts.spaceGrotesk(fontSize: 10, fontWeight: FontWeight.w700, color: context.appTextSecondary))),
            SizedBox(width: 80, child: Text('Width', style: GoogleFonts.spaceGrotesk(fontSize: 10, fontWeight: FontWeight.w700, color: context.appTextSecondary))),
            SizedBox(width: 44, child: Center(child: Text('Show', style: GoogleFonts.spaceGrotesk(fontSize: 10, fontWeight: FontWeight.w700, color: context.appTextSecondary)))),
          ]),
        ),
        // Scrollable list
        Flexible(
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(vertical: 4),
            itemCount: displayKeys.length,
            separatorBuilder: (ctx, idx) =>
                Divider(height: 1, color: context.appBorder),
            itemBuilder: (ctx, i) {
              final key = displayKeys[i];
              StrainColDef? colDef;
              try {
                colDef = strainAllColumns.firstWhere((c) => c.key == key);
              } catch (_) {
                return const SizedBox.shrink();
              }
              final isHidden = hiddenCols.contains(key) || emptyColKeys.contains(key);
              final currentWidth = colWidths[key] ?? colDef.defaultWidth;

              return Container(
                color: isHidden ? context.appSurface2 : context.appSurface,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                child: Row(children: [
                  SizedBox(
                    width: 36,
                    child: ColPositionField(
                      position: i + 1,
                      total: displayKeys.length,
                      onSubmit: (newPos) => onReorder(key, newPos),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Row(children: [
                      if (colDef.readOnly)
                        Padding(
                          padding: const EdgeInsets.only(right: 4),
                          child: Icon(Icons.lock_outline_rounded,
                              size: 10, color: context.appTextMuted),
                        ),
                      Flexible(
                        child: Text(colDef.label,
                            style: GoogleFonts.spaceGrotesk(
                              fontSize: 12,
                              color: isHidden ? context.appTextMuted : context.appTextPrimary,
                              fontWeight: FontWeight.w500,
                            ),
                            overflow: TextOverflow.ellipsis),
                      ),
                    ]),
                  ),
                  SizedBox(
                    width: 80,
                    child: isHidden
                        ? Center(
                            child: Text('—',
                                style: GoogleFonts.spaceGrotesk(
                                    color: context.appTextMuted, fontSize: 12)))
                        : SliderTheme(
                            data: SliderThemeData(
                              trackHeight: 2,
                              thumbShape:
                                  const RoundSliderThumbShape(enabledThumbRadius: 6),
                              overlayShape:
                                  const RoundSliderOverlayShape(overlayRadius: 10),
                              activeTrackColor: AppDS.accent,
                              inactiveTrackColor: context.appBorder,
                              thumbColor: AppDS.accent,
                            ),
                            child: Slider(
                              value: currentWidth.clamp(40.0, 400.0),
                              min: 40,
                              max: 400,
                              onChanged: (v) => onWidthChanged(key, v),
                              onChangeEnd: (v) => onWidthChanged(key, v),
                            ),
                          ),
                  ),
                  SizedBox(
                    width: 44,
                    child: emptyColKeys.contains(key)
                        ? Center(
                            child: Tooltip(
                                message: 'No data in this column',
                                child: Icon(Icons.remove_circle_outline,
                                    size: 14, color: context.appTextMuted)))
                        : Transform.scale(
                            scale: 0.8,
                            child: Switch(
                              value: !hiddenCols.contains(key),
                              onChanged: (v) => onVisibilityChanged(key, v),
                              activeThumbColor: AppDS.accent,
                            ),
                          ),
                  ),
                ]),
              );
            },
          ),
        ),
      ]),
    );
  }
}
