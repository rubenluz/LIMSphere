// label_print_filters.dart — Part of label_page.dart.
// Filter/sort UI and data models for the print page:
//   _SortConfig, _ActiveFilter, _FilterBar, _FilterChip, _SortChip.

part of '../label_page.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Active filter / sort models
// ─────────────────────────────────────────────────────────────────────────────
class _SortConfig {
  final String field;
  final bool asc;
  const _SortConfig(this.field, {this.asc = true});

  _SortConfig toggled() => _SortConfig(field, asc: !asc);

  String get encoded => '$field\x00${asc ? 'asc' : 'desc'}';

  static _SortConfig? fromEncoded(String s) {
    final p = s.split('\x00');
    if (p.length != 2) return null;
    return _SortConfig(p[0], asc: p[1] != 'desc');
  }
}

class _ActiveFilter {
  final String field;
  final String mode;  // eq | contains | startsWith | endsWith
  final String value;
  const _ActiveFilter(this.field, this.mode, this.value);

  String get encoded => '$field\x00$mode\x00$value';

  static _ActiveFilter? fromEncoded(String s) {
    final p = s.split('\x00');
    if (p.length != 3) return null;
    return _ActiveFilter(p[0], p[1], p[2]);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Filter bar — search, active-filter chips, add-filter row, quick values, sort
// ─────────────────────────────────────────────────────────────────────────────
class _FilterBar extends StatefulWidget {
  final String search;
  final TextEditingController searchCtrl;
  final String statusFilter;
  final List<String> filterOptions;
  final String filterLabel;
  final bool hasRecords;
  final List<Map<String, dynamic>> records;
  final List<String> allFields;
  final List<_ActiveFilter> activeFilters;
  final List<_SortConfig> activeSorts;
  final VoidCallback onLoad;
  final ValueChanged<String> onSearchChanged;
  final ValueChanged<String?> onStatusChanged;
  final void Function(_ActiveFilter) onAddFilter;
  final void Function(int) onRemoveFilter;
  final void Function(_SortConfig) onAddSort;
  final void Function(int) onRemoveSort;
  final void Function(int) onToggleSortDir;

  const _FilterBar({
    required this.search,
    required this.searchCtrl,
    required this.statusFilter,
    required this.filterOptions,
    required this.filterLabel,
    required this.hasRecords,
    required this.records,
    required this.allFields,
    required this.activeFilters,
    required this.activeSorts,
    required this.onLoad,
    required this.onSearchChanged,
    required this.onStatusChanged,
    required this.onAddFilter,
    required this.onRemoveFilter,
    required this.onAddSort,
    required this.onRemoveSort,
    required this.onToggleSortDir,
  });

  @override
  State<_FilterBar> createState() => _FilterBarState();
}

class _FilterBarState extends State<_FilterBar> {
  String? _field;
  String _mode = 'eq';
  final _valueCtrl = TextEditingController();
  String? _sortField;
  bool _sortAscending = true;
  int _sortAutoKey = 0;

  @override
  void dispose() {
    _valueCtrl.dispose();
    super.dispose();
  }

  List<String> get _quickValues {
    if (_field == null || widget.records.isEmpty) return [];
    return widget.records
        .map((r) => r[_field!]?.toString() ?? '')
        .where((v) => v.isNotEmpty)
        .toSet()
        .toList()
      ..sort(_naturalCompare);
  }

  void _addFilter() {
    final v = _valueCtrl.text.trim();
    if (_field == null || v.isEmpty) return;
    widget.onAddFilter(_ActiveFilter(_field!, _mode, v));
    _valueCtrl.clear();
  }

  void _addQuick(String value) {
    if (_field == null) return;
    widget.onAddFilter(_ActiveFilter(_field!, _mode, value));
  }

  void _addSort() {
    if (_sortField == null) return;
    widget.onAddSort(_SortConfig(_sortField!, asc: _sortAscending));
    setState(() { _sortField = null; _sortAutoKey++; });
  }

  Widget _modeBtn(BuildContext ctx, String m) {
    final active = _mode == m;
    final label = switch (m) {
      'notEq'      => 'is not',
      'contains'   => 'contains',
      'startsWith' => 'starts',
      'endsWith'   => 'ends',
      _            => 'is',
    };
    return GestureDetector(
      onTap: () => setState(() => _mode = m),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
        decoration: BoxDecoration(
          color: active ? AppDS.accent.withValues(alpha: 0.2) : ctx.appBg,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: active ? AppDS.accent : ctx.appBorder),
        ),
        child: Text(label,
            style: TextStyle(fontSize: 10,
                color: active ? AppDS.accent : ctx.appTextSecondary,
                fontWeight: FontWeight.bold)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final qv = _quickValues;
    return Container(
      color: context.appSurface,
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 6),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Row 1: search + status + load ──────────────────────────────
          Row(children: [
            Expanded(
              child: TextField(
                controller: widget.searchCtrl,
                style: TextStyle(fontSize: 13, color: context.appTextPrimary),
                decoration: InputDecoration(
                  hintText: 'Search…',
                  hintStyle: TextStyle(color: context.appTextMuted, fontSize: 13),
                  prefixIcon: Icon(Icons.search_rounded, size: 16, color: context.appTextMuted),
                  suffixIcon: widget.search.isNotEmpty
                      ? IconButton(
                          icon: Icon(Icons.clear_rounded, size: 14, color: context.appTextSecondary),
                          onPressed: () { widget.searchCtrl.clear(); widget.onSearchChanged(''); })
                      : null,
                  isDense: true, filled: true, fillColor: context.appSurface2,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: context.appBorder)),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: context.appBorder)),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: AppDS.accent, width: 1.5)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                ),
                onChanged: widget.onSearchChanged,
              ),
            ),
            if (widget.filterLabel.isNotEmpty && widget.filterOptions.isNotEmpty) ...[
              const SizedBox(width: 8),
              DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: widget.statusFilter.isEmpty ? null : widget.statusFilter,
                  hint: Text(widget.filterLabel,
                      style: TextStyle(color: context.appTextMuted, fontSize: 12)),
                  dropdownColor: context.appSurface2,
                  style: TextStyle(color: context.appTextPrimary, fontSize: 12),
                  items: [
                    DropdownMenuItem<String>(value: '',
                        child: Text('All ${widget.filterLabel}',
                            style: TextStyle(color: context.appTextSecondary, fontSize: 12))),
                    ...widget.filterOptions.map((v) =>
                        DropdownMenuItem<String>(value: v, child: Text(v))),
                  ],
                  onChanged: widget.onStatusChanged,
                ),
              ),
            ],
            const SizedBox(width: 8),
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                  foregroundColor: AppDS.accent,
                  side: const BorderSide(color: AppDS.accent),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6)),
              icon: const Icon(Icons.refresh_rounded, size: 14),
              label: Text(widget.hasRecords ? 'Reload' : 'Load',
                  style: const TextStyle(fontSize: 12)),
              onPressed: widget.onLoad,
            ),
          ]),

          if (widget.allFields.isNotEmpty) ...[
            // ── Active filter chips ─────────────────────────────────────
            if (widget.activeFilters.isNotEmpty) ...[
              const SizedBox(height: 6),
              Wrap(spacing: 6, runSpacing: 4, children: [
                for (var i = 0; i < widget.activeFilters.length; i++)
                  _FilterChip(filter: widget.activeFilters[i], onRemove: () => widget.onRemoveFilter(i)),
              ]),
            ],

            // ── Add filter row: field | mode | value | + ────────────────
            const SizedBox(height: 6),
            Row(children: [
              Text('Filter by:', style: TextStyle(fontSize: 10,
                  color: context.appTextSecondary, fontWeight: FontWeight.w600)),
              const SizedBox(width: 6),
              SizedBox(
                width: 160,
                child: Autocomplete<String>(
                  optionsBuilder: (v) {
                    final q = v.text.toLowerCase();
                    return q.isEmpty
                        ? widget.allFields
                        : widget.allFields.where((c) =>
                            _colLabel(c).toLowerCase().contains(q) ||
                            c.toLowerCase().contains(q));
                  },
                  displayStringForOption: _colLabel,
                  onSelected: (col) => setState(() => _field = col),
                  optionsViewBuilder: (ctx, onSel, opts) => Align(
                    alignment: Alignment.topLeft,
                    child: Material(
                      color: Colors.transparent,
                      child: Container(
                        width: 200,
                        constraints: const BoxConstraints(maxHeight: 220),
                        decoration: BoxDecoration(
                          color: AppDS.surface2,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppDS.border),
                          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.3), blurRadius: 8)],
                        ),
                        child: ListView(shrinkWrap: true, children: opts.map((col) =>
                          InkWell(
                            onTap: () => onSel(col),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              child: Text(_colLabel(col),
                                  style: const TextStyle(fontSize: 11, color: AppDS.textPrimary)),
                            ),
                          ),
                        ).toList()),
                      ),
                    ),
                  ),
                  fieldViewBuilder: (ctx, ctrl, focus, _) => TextField(
                    controller: ctrl,
                    focusNode: focus,
                    style: TextStyle(fontSize: 11, color: ctx.appTextPrimary),
                    decoration: InputDecoration(
                      hintText: 'Filter field…',
                      hintStyle: TextStyle(color: ctx.appTextMuted, fontSize: 11),
                      isDense: true, filled: true, fillColor: ctx.appBg,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(6),
                          borderSide: BorderSide(color: ctx.appBorder)),
                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(6),
                          borderSide: BorderSide(color: ctx.appBorder)),
                      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(6),
                          borderSide: const BorderSide(color: AppDS.accent)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                      suffixIcon: _field != null
                          ? GestureDetector(
                              onTap: () { ctrl.clear(); setState(() => _field = null); },
                              child: Icon(Icons.clear_rounded, size: 12, color: ctx.appTextSecondary))
                          : null,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 6),
              _modeBtn(context, 'eq'),
              const SizedBox(width: 2),
              _modeBtn(context, 'notEq'),
              const SizedBox(width: 2),
              _modeBtn(context, 'contains'),
              const SizedBox(width: 2),
              _modeBtn(context, 'startsWith'),
              const SizedBox(width: 2),
              _modeBtn(context, 'endsWith'),
              const SizedBox(width: 6),
              SizedBox(
                width: 120,
                child: TextField(
                  controller: _valueCtrl,
                  style: TextStyle(fontSize: 11, color: context.appTextPrimary),
                  decoration: InputDecoration(
                    hintText: 'Value…',
                    hintStyle: TextStyle(color: context.appTextMuted, fontSize: 11),
                    isDense: true, filled: true, fillColor: context.appBg,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(6),
                        borderSide: BorderSide(color: context.appBorder)),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(6),
                        borderSide: BorderSide(color: context.appBorder)),
                    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(6),
                        borderSide: const BorderSide(color: AppDS.accent)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                  ),
                  onSubmitted: (_) => _addFilter(),
                ),
              ),
              const SizedBox(width: 4),
              GestureDetector(
                onTap: _addFilter,
                child: Container(
                  width: 26, height: 26,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: AppDS.accent.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: AppDS.accent),
                  ),
                  child: const Icon(Icons.add_rounded, size: 16, color: AppDS.accent),
                ),
              ),
            ]),

            // ── Quick values + Sort ─────────────────────────────────────
            const SizedBox(height: 6),
            Row(children: [
              if (qv.isNotEmpty) ...[
                Text('Quick:', style: TextStyle(fontSize: 10,
                    color: context.appTextSecondary, fontWeight: FontWeight.w600)),
                const SizedBox(width: 4),
                Flexible(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(children: qv.take(25).map((v) =>
                      GestureDetector(
                        onTap: () => _addQuick(v),
                        child: Container(
                          margin: const EdgeInsets.only(right: 4),
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppDS.surface3,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppDS.border),
                          ),
                          child: Text(v, style: const TextStyle(fontSize: 10, color: AppDS.textPrimary)),
                        ),
                      ),
                    ).toList()),
                  ),
                ),
                SizedBox(height: 16, child: VerticalDivider(color: context.appBorder, indent: 0, endIndent: 0)),
                const SizedBox(width: 8),
              ],
            ]),

            // sort chips
            if (widget.activeSorts.isNotEmpty) ...[
              const SizedBox(height: 6),
              Wrap(spacing: 6, runSpacing: 4, children: [
                for (var i = 0; i < widget.activeSorts.length; i++)
                  _SortChip(
                    sort: widget.activeSorts[i],
                    onRemove: () => widget.onRemoveSort(i),
                    onToggleDir: () => widget.onToggleSortDir(i),
                  ),
              ]),
            ],

            // add sort row
            const SizedBox(height: 6),
            Row(children: [
              Text('Sort by:', style: TextStyle(fontSize: 10,
                  color: context.appTextSecondary, fontWeight: FontWeight.w600)),
              const SizedBox(width: 4),
              SizedBox(
                width: 160,
                child: Autocomplete<String>(
                  key: ValueKey(_sortAutoKey),
                  optionsBuilder: (v) {
                    final q = v.text.toLowerCase();
                    final used = widget.activeSorts.map((s) => s.field).toSet();
                    final available = widget.allFields.where((c) => !used.contains(c));
                    return q.isEmpty
                        ? available
                        : available.where((c) =>
                            _colLabel(c).toLowerCase().contains(q) ||
                            c.toLowerCase().contains(q));
                  },
                  displayStringForOption: _colLabel,
                  onSelected: (col) => setState(() => _sortField = col),
                  optionsViewBuilder: (ctx, onSel, opts) => Align(
                    alignment: Alignment.topLeft,
                    child: Material(
                      color: Colors.transparent,
                      child: Container(
                        width: 200,
                        constraints: const BoxConstraints(maxHeight: 200),
                        decoration: BoxDecoration(
                          color: AppDS.surface2,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppDS.border),
                          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.3), blurRadius: 8)],
                        ),
                        child: ListView(shrinkWrap: true, children: opts.map((col) =>
                          InkWell(
                            onTap: () => onSel(col),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              child: Text(_colLabel(col),
                                  style: const TextStyle(fontSize: 11, color: AppDS.textPrimary)),
                            ),
                          ),
                        ).toList()),
                      ),
                    ),
                  ),
                  fieldViewBuilder: (ctx, ctrl, focus, _) => TextField(
                    controller: ctrl,
                    focusNode: focus,
                    style: TextStyle(fontSize: 11, color: ctx.appTextPrimary),
                    decoration: InputDecoration(
                      hintText: 'Sort field…',
                      hintStyle: TextStyle(color: ctx.appTextMuted, fontSize: 11),
                      isDense: true, filled: true, fillColor: ctx.appBg,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(6),
                          borderSide: BorderSide(color: ctx.appBorder)),
                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(6),
                          borderSide: BorderSide(color: ctx.appBorder)),
                      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(6),
                          borderSide: const BorderSide(color: AppDS.purple)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                      suffixIcon: _sortField != null
                          ? GestureDetector(
                              onTap: () { ctrl.clear(); setState(() => _sortField = null); },
                              child: Icon(Icons.clear_rounded, size: 12, color: ctx.appTextSecondary))
                          : null,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 6),
              GestureDetector(
                onTap: () => setState(() => _sortAscending = !_sortAscending),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                  decoration: BoxDecoration(
                    color: context.appBg,
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: context.appBorder),
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(_sortAscending ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded,
                        size: 12, color: context.appTextSecondary),
                    const SizedBox(width: 3),
                    Text(_sortAscending ? 'A→Z' : 'Z→A',
                        style: TextStyle(fontSize: 10, color: context.appTextSecondary)),
                  ]),
                ),
              ),
              const SizedBox(width: 4),
              GestureDetector(
                onTap: _addSort,
                child: Container(
                  width: 26, height: 26,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: AppDS.purple.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: AppDS.purple),
                  ),
                  child: const Icon(Icons.add_rounded, size: 16, color: AppDS.purple),
                ),
              ),
            ]),
          ],
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final _ActiveFilter filter;
  final VoidCallback onRemove;
  const _FilterChip({required this.filter, required this.onRemove});

  String get _modeLabel => switch (filter.mode) {
    'notEq'      => 'is not',
    'contains'   => 'contains',
    'startsWith' => 'starts',
    'endsWith'   => 'ends',
    _            => 'is',
  };

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(8, 3, 4, 3),
      decoration: BoxDecoration(
        color: AppDS.accent.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppDS.accent.withValues(alpha: 0.4)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Text('${_colLabel(filter.field)} $_modeLabel ${filter.value}',
            style: const TextStyle(fontSize: 10, color: AppDS.accent)),
        const SizedBox(width: 4),
        GestureDetector(
          onTap: onRemove,
          child: const Icon(Icons.close_rounded, size: 12, color: AppDS.accent),
        ),
      ]),
    );
  }
}

class _SortChip extends StatelessWidget {
  final _SortConfig sort;
  final VoidCallback onRemove;
  final VoidCallback onToggleDir;
  const _SortChip({required this.sort, required this.onRemove, required this.onToggleDir});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(8, 3, 4, 3),
      decoration: BoxDecoration(
        color: AppDS.purple.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppDS.purple.withValues(alpha: 0.4)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Text(_colLabel(sort.field),
            style: const TextStyle(fontSize: 10, color: AppDS.purple)),
        const SizedBox(width: 4),
        GestureDetector(
          onTap: onToggleDir,
          child: Icon(
            sort.asc ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded,
            size: 12, color: AppDS.purple,
          ),
        ),
        const SizedBox(width: 2),
        GestureDetector(
          onTap: onRemove,
          child: const Icon(Icons.close_rounded, size: 12, color: AppDS.purple),
        ),
      ]),
    );
  }
}
