// label_print_records.dart — Part of label_page.dart.
// Record list UI for the print page: _RecordList, _EmptyRecordsPanel.

part of '../label_page.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Record list — shows filtered records with select checkboxes
// ─────────────────────────────────────────────────────────────────────────────
class _RecordList extends StatelessWidget {
  final List<Map<String, dynamic>> records;
  final Set<dynamic> selectedIds;
  final String idCol;
  final int previewIndex;
  final String entityType;
  final void Function(Map<String, dynamic>) onToggle;
  final VoidCallback onToggleAll;
  final void Function(int) onTapRow;

  const _RecordList({
    required this.records,
    required this.selectedIds,
    required this.idCol,
    required this.previewIndex,
    required this.entityType,
    required this.onToggle,
    required this.onToggleAll,
    required this.onTapRow,
  });

  // Top line: scientific name for strains, code/id otherwise
  String _recordLabel(Map<String, dynamic> r) {
    if (entityType == 'Strains') {
      final sci = r['strain_scientific_name'];
      if (sci != null && sci.toString().isNotEmpty) return sci.toString();
    }
    for (final k in [
      'strain_code', 'reagent_code', 'eq_code', 'sample_code',
      'fish_stocks_tank_id', 'code', 'name', 'id',
    ]) {
      final v = r[k];
      if (v != null && v.toString().isNotEmpty) return v.toString();
    }
    return r.values.firstOrNull?.toString() ?? '—';
  }

  // Bottom line: "code · medium" for strains, otherwise name/type
  String _recordSubLabel(Map<String, dynamic> r) {
    if (entityType == 'Strains') {
      final code   = r['strain_code']?.toString() ?? '';
      final medium = r['strain_medium']?.toString() ?? '';
      if (code.isNotEmpty && medium.isNotEmpty) return '$code · $medium';
      if (code.isNotEmpty) return code;
    }
    for (final k in [
      'reagent_name', 'eq_name', 'sample_type',
      'fish_stocks_line', 'name', 'type',
    ]) {
      final v = r[k];
      if (v != null && v.toString().isNotEmpty) return v.toString();
    }
    return '';
  }

  Widget _scientificNameWidget(String name, TextStyle base) =>
      _scientificNameText(name, base, overflow: TextOverflow.ellipsis);

  @override
  Widget build(BuildContext context) {
    final allSelected = records.every((r) => selectedIds.contains(r[idCol]));
    final selCount = records.where((r) => selectedIds.contains(r[idCol])).length;
    return Column(children: [
      InkWell(
        onTap: onToggleAll,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          color: context.appSurface,
          child: Row(children: [
            Icon(
              allSelected
                  ? Icons.check_box_rounded
                  : Icons.check_box_outline_blank_rounded,
              size: 17,
              color: allSelected ? AppDS.accent : context.appTextSecondary,
            ),
            const SizedBox(width: 10),
            Text(allSelected ? 'Deselect all' : 'Select all',
                style: TextStyle(
                    fontSize: 12, color: context.appTextSecondary)),
            const Spacer(),
            Text('$selCount/${records.length}',
                style: TextStyle(
                    fontSize: 11, color: context.appTextSecondary)),
          ]),
        ),
      ),
      Divider(height: 1, color: context.appBorder),
      Expanded(
        child: ListView.builder(
          itemCount: records.length,
          itemBuilder: (ctx, i) {
            final r = records[i];
            final id = r[idCol];
            final isSel = selectedIds.contains(id);
            final isPreview = i == previewIndex;
            return InkWell(
              onTap: () => onTapRow(i),
              child: Container(
                color: isPreview
                    ? AppDS.accent.withValues(alpha: 0.08)
                    : Colors.transparent,
                padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 8),
                child: Row(children: [
                  GestureDetector(
                    onTap: () => onToggle(r),
                    child: Icon(
                      isSel
                          ? Icons.check_box_rounded
                          : Icons.check_box_outline_blank_rounded,
                      size: 16,
                      color:
                          isSel ? AppDS.accent : ctx.appTextSecondary,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                      if (entityType == 'Strains')
                        _scientificNameWidget(
                          _recordLabel(r),
                          TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: isPreview ? AppDS.accent : ctx.appTextPrimary),
                        )
                      else
                        Text(
                          _recordLabel(r),
                          style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: isPreview ? AppDS.accent : ctx.appTextPrimary),
                          overflow: TextOverflow.ellipsis,
                        ),
                      if (_recordSubLabel(r).isNotEmpty)
                        Text(
                          _recordSubLabel(r),
                          style: TextStyle(
                              fontSize: 10,
                              color: ctx.appTextSecondary),
                          overflow: TextOverflow.ellipsis,
                        ),
                    ]),
                  ),
                  if (isPreview)
                    const Icon(Icons.visibility_rounded,
                        size: 13, color: AppDS.accent),
                ]),
              ),
            );
          },
        ),
      ),
    ]);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Empty records state
// ─────────────────────────────────────────────────────────────────────────────
class _EmptyRecordsPanel extends StatelessWidget {
  final String entityType;
  final VoidCallback onLoad;
  const _EmptyRecordsPanel({required this.entityType, required this.onLoad});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.table_rows_outlined,
              size: 40, color: context.appTextSecondary),
          const SizedBox(height: 14),
          Text('No records loaded',
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: context.appTextPrimary)),
          const SizedBox(height: 6),
          Text(
            'Load $entityType from the database to print with real data,\nor print now using sample placeholder values.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 11, color: context.appTextSecondary),
          ),
          const SizedBox(height: 20),
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
                foregroundColor: AppDS.accent,
                side: const BorderSide(color: AppDS.accent)),
            icon: const Icon(Icons.download_rounded, size: 15),
            label: Text('Load all $entityType',
                style: const TextStyle(fontSize: 12)),
            onPressed: onLoad,
          ),
        ]),
      ),
    );
  }
}
