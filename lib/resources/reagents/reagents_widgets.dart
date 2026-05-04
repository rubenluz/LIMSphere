// reagents_widgets.dart - Part of reagents_page.dart.
// _ReagentRow: list tile with expiry/stock/contamination indicators.
// _RowBtn, _Badge, _FilterChip: small UI atoms.
// _ReagentFormDialog: add/edit reagent form dialog.
part of 'reagents_page.dart';

// ─── Reagent Row ───────────────────────────────────────────────────────────────
class _ReagentRow extends StatelessWidget {
  final ReagentModel reagent;
  final int rowIndex;
  final String? roomName;
  final VoidCallback onViewMore;
  final VoidCallback onRequest;
  final Map<String, dynamic>? editingCell;
  final TextEditingController editController;
  final FocusNode editFocus;
  final void Function(int id, String key, String initial) onStartEdit;
  final VoidCallback onAdvance;
  final VoidCallback onAdvanceBack;
  final VoidCallback onCancel;
  final VoidCallback onAddNewRow;
  final void Function(int id, String value) onCommitStockStatus;
  final void Function(int id, String value) onCommitCategory;
  final void Function(int id, String value) onCommitSubcategory;
  final void Function(int id, String? value) onCommitStorageTemp;
  final void Function(int id, String? value) onCommitPhysicalState;
  final void Function(int id, String value) onCommitContamination;
  final void Function(int id, int? value) onCommitLocation;
  final List<Map<String, dynamic>> locations;

  const _ReagentRow({
    required this.reagent,
    required this.rowIndex,
    required this.roomName,
    required this.onViewMore,
    required this.onRequest,
    required this.editingCell,
    required this.editController,
    required this.editFocus,
    required this.onStartEdit,
    required this.onAdvance,
    required this.onAdvanceBack,
    required this.onCancel,
    required this.onAddNewRow,
    required this.onCommitStockStatus,
    required this.onCommitCategory,
    required this.onCommitSubcategory,
    required this.onCommitStorageTemp,
    required this.onCommitPhysicalState,
    required this.onCommitContamination,
    required this.onCommitLocation,
    required this.locations,
  });

  static String _unitDisplay(String? u) {
    if (u == null) return '—';
    return switch (u.trim().toLowerCase()) {
      'gr' => 'grams',
      'l' => 'liters',
      'ml' => 'mililiters',
      'kg' => 'kilograms',
      _ => u,
    };
  }

  static const _categoryAccent = {
    'chemical': Color(0xFF38BDF8),
    'biological': Color(0xFF22C55E),
    'consumable': Color(0xFFF59E0B),
    'kit': Color(0xFF8B5CF6),
  };

  static const _contamColor = {
    'none': Color(0xFF22C55E),
    'bacteria': Color(0xFFEF4444),
    'fungi': Color(0xFFA855F7),
    'both': Color(0xFFEC4899),
    'suspected': Color(0xFFEAB308),
  };

  static const _stockColor = {
    'in_stock': AppDS.green,
    'out_of_stock': AppDS.red,
  };

  // Stable per-string color generator for tags / brand / supplier chips.
  // Uses hash-derived HSL values instead of a tiny fixed palette so different
  // values collide much less often while identical values still share a color.
  static Color _tagColor(String tag) {
    final key = tag.trim().toLowerCase();
    if (key.isEmpty) return const Color(0xFF38BDF8);
    var h = 0;
    for (final c in key.codeUnits) {
      h = (h * 31 + c) & 0x7fffffff;
    }
    final hue = (h % 360).toDouble();
    final saturation = 0.60 + (((h >> 8) % 18) / 100.0);
    final lightness = 0.56 + (((h >> 13) % 12) / 100.0);
    return HSLColor.fromAHSL(
      1,
      hue,
      saturation.clamp(0.0, 1.0),
      lightness.clamp(0.0, 1.0),
    ).toColor();
  }

  static Widget _stableChip(String? value, TextStyle emptyStyle) {
    if (value == null || value.trim().isEmpty) {
      return Text('—', overflow: TextOverflow.ellipsis, style: emptyStyle);
    }
    final color = _tagColor(value);
    return _tip(
      value,
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.14),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: color.withValues(alpha: 0.32)),
        ),
        child: Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: GoogleFonts.spaceGrotesk(
            color: color,
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  // Wrap a cell's display widget so hovering with the mouse reveals the full
  // string when it was truncated with ellipsis. Skips the tooltip for empty
  // values to avoid an empty hover bubble.
  static Widget _tip(String? msg, Widget child) {
    if (msg == null || msg.trim().isEmpty) return child;
    return Tooltip(
      message: msg,
      waitDuration: const Duration(milliseconds: 400),
      textStyle: GoogleFonts.spaceGrotesk(
        color: AppDS.textPrimary,
        fontSize: 12,
      ),
      decoration: BoxDecoration(
        color: AppDS.surface3,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: AppDS.border),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      child: child,
    );
  }

  bool _isEditing(String key) =>
      editingCell != null &&
      editingCell!['id'] == reagent.id &&
      editingCell!['key'] == key;

  String? _locationDisplay(int? id) {
    if (id == null) return null;
    for (final loc in locations) {
      if ((loc['location_id'] as num).toInt() == id) {
        return (loc['_display'] as String?) ??
            (loc['location_name'] as String?);
      }
    }
    return reagent.locationName;
  }

  Widget _editField(
    BuildContext ctx,
    String key,
    TextStyle ts, {
    TextInputType? keyboardType,
  }) {
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.tab): onAdvance,
        const SingleActivator(LogicalKeyboardKey.tab, shift: true):
            onAdvanceBack,
        const SingleActivator(LogicalKeyboardKey.enter): onAdvance,
        const SingleActivator(LogicalKeyboardKey.enter, control: true):
            onAddNewRow,
        const SingleActivator(LogicalKeyboardKey.escape): onCancel,
      },
      child: TextField(
        controller: editController,
        focusNode: editFocus,
        keyboardType: keyboardType,
        style: ts,
        decoration: InputDecoration(
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 6,
            vertical: 4,
          ),
          filled: true,
          fillColor: ctx.appSurface2,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(4),
            borderSide: const BorderSide(color: AppDS.accent, width: 1.5),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(4),
            borderSide: const BorderSide(color: AppDS.accent, width: 1.5),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(4),
            borderSide: const BorderSide(color: AppDS.accent, width: 1.5),
          ),
        ),
      ),
    );
  }

  Widget _editCell(
    BuildContext ctx,
    String key,
    String initial,
    Widget display,
    TextStyle ts, {
    TextInputType? keyboardType,
  }) => GestureDetector(
    onDoubleTap: () => onStartEdit(reagent.id, key, initial),
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      child: _isEditing(key)
          ? _editField(ctx, key, ts, keyboardType: keyboardType)
          : display,
    ),
  );

  @override
  Widget build(BuildContext context) {
    final r = reagent;
    final accent = _categoryAccent[r.category] ?? const Color(0xFF94A3B8);

    final primary = context.appTextPrimary;
    final secondary = context.appTextSecondary;
    final muted = context.appTextMuted;

    final tsName = GoogleFonts.spaceGrotesk(
      fontSize: 12.5,
      color: primary,
      fontWeight: FontWeight.w500,
    );
    final tsCell = GoogleFonts.spaceGrotesk(fontSize: 12.5, color: secondary);
    final tsMono = GoogleFonts.jetBrainsMono(fontSize: 12, color: secondary);
    final tsMuted = GoogleFonts.spaceGrotesk(fontSize: 12.5, color: muted);
    final tsMonoMut = GoogleFonts.jetBrainsMono(fontSize: 12, color: muted);

    Color bg = rowIndex.isEven ? context.appSurface : context.appSurface2;
    if (r.isExpired) bg = AppDS.red.withValues(alpha: 0.08);
    if (r.isContaminated) bg = AppDS.purple.withValues(alpha: 0.06);

    return Container(
      height: AppDS.tableRowH,
      decoration: BoxDecoration(
        color: bg,
        border: Border(bottom: BorderSide(color: context.appBorder)),
      ),
      child: Row(
        children: [
          // ── Action buttons ────────────────────────────────────────────────
          SizedBox(
            width: 30,
            child: _RowBtn(
              Icons.open_in_new,
              'View detail',
              onViewMore,
              color: muted,
            ),
          ),
          SizedBox(
            width: 30,
            child: _RowBtn(
              Icons.outbox_outlined,
              'Quick Request',
              onRequest,
              color: muted,
            ),
          ),

          // ── Code ──────────────────────────────────────────────────────────
          SizedBox(
            width: _colCode,
            child: _editCell(
              context,
              'code',
              r.code ?? '',
              r.code != null && r.code!.isNotEmpty
                  ? _tip(
                      r.code,
                      Text(
                        r.code!,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.jetBrainsMono(
                          color: context.appTextPrimary,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    )
                  : const SizedBox.shrink(),
              GoogleFonts.jetBrainsMono(fontSize: 12, color: primary),
            ),
          ),

          // ── Stock Status ────────────────────────────────────────────────
          SizedBox(
            width: _colStock,
            child: GestureDetector(
              onDoubleTap: () =>
                  onStartEdit(r.id, 'stockStatus', r.stockStatus),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                child: _isEditing('stockStatus')
                    ? _ArrowDropdown<String>(
                        values: ReagentModel.stockStatusOptions,
                        current: r.stockStatus,
                        labelOf: ReagentModel.stockStatusLabel,
                        onSelect: (v) => onCommitStockStatus(r.id, v),
                        onCancel: onCancel,
                        onAddNewRow: onAddNewRow,
                        autoOpen: true,
                      )
                    : _Badge(
                        label: ReagentModel.stockStatusLabel(r.stockStatus),
                        color: _stockColor[r.stockStatus] ?? AppDS.green,
                      ),
              ),
            ),
          ),

          // ── Category ──────────────────────────────────────────────────────
          SizedBox(
            width: _colCategory,
            child: GestureDetector(
              onDoubleTap: () => onStartEdit(r.id, 'category', r.category),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                child: _isEditing('category')
                    ? _ArrowDropdown<String>(
                        values: ReagentModel.categoryOptionsSorted,
                        current: r.category,
                        labelOf: ReagentModel.categoryLabel,
                        onSelect: (v) => onCommitCategory(r.id, v),
                        onCancel: onCancel,
                        onAddNewRow: onAddNewRow,
                        autoOpen: true,
                      )
                    : _Badge(
                        label: ReagentModel.categoryLabel(r.category),
                        color: accent,
                      ),
              ),
            ),
          ),

          // ── Subcategory ───────────────────────────────────────────────────
          SizedBox(
            width: _colSubcat,
            child: GestureDetector(
              onDoubleTap: () =>
                  onStartEdit(r.id, 'subcategory', r.subcategory ?? ''),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                child: _isEditing('subcategory')
                    ? _ArrowDropdown<String>(
                        values: ReagentModel.subcategoryOptionsSorted(
                          r.category,
                        ),
                        current: r.subcategory ?? '',
                        labelOf: ReagentModel.subcategoryLabel,
                        onSelect: (v) => onCommitSubcategory(r.id, v),
                        onCancel: onCancel,
                        onAddNewRow: onAddNewRow,
                        autoOpen: true,
                      )
                    : _tip(
                        r.subcategory != null
                            ? ReagentModel.subcategoryLabel(r.subcategory!)
                            : null,
                        Text(
                          r.subcategory != null
                              ? ReagentModel.subcategoryLabel(r.subcategory!)
                              : '—',
                          overflow: TextOverflow.ellipsis,
                          style: r.subcategory != null ? tsCell : tsMuted,
                        ),
                      ),
              ),
            ),
          ),

          // ── Tags (semicolon-separated) ────────────────────────────────────
          SizedBox(
            width: _colTags,
            child: _editCell(
              context,
              'tags',
              r.tags ?? '',
              r.tagList.isEmpty
                  ? Text('—', overflow: TextOverflow.ellipsis, style: tsMuted)
                  : Wrap(
                      spacing: 4,
                      runSpacing: 2,
                      children: [
                        for (final t in r.tagList)
                          Builder(
                            builder: (_) {
                              final c = _tagColor(t);
                              return Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 1,
                                ),
                                decoration: BoxDecoration(
                                  color: c.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(3),
                                  border: Border.all(
                                    color: c.withValues(alpha: 0.4),
                                  ),
                                ),
                                child: Text(
                                  t,
                                  style: AppDS.ui(
                                    size: 10,
                                    color: c,
                                    weight: FontWeight.w600,
                                  ),
                                ),
                              );
                            },
                          ),
                      ],
                    ),
              tsCell,
            ),
          ),

          // ── Name ──────────────────────────────────────────────────────────
          SizedBox(
            width: _colName,
            child: _isEditing('name')
                ? Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 3,
                    ),
                    child: _editField(context, 'name', tsName),
                  )
                : GestureDetector(
                    onDoubleTap: () => onStartEdit(r.id, 'name', r.name ?? ''),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 3,
                      ),
                      child: Row(
                        children: [
                          Flexible(
                            child: _tip(
                              r.name,
                              Text(
                                (r.name == null || r.name!.isEmpty)
                                    ? '—'
                                    : r.name!,
                                overflow: TextOverflow.ellipsis,
                                style: (r.name == null || r.name!.isEmpty)
                                    ? tsMuted
                                    : tsName,
                              ),
                            ),
                          ),
                          if (r.isExpired) ...[
                            const SizedBox(width: 4),
                            _Badge(label: 'Expired', color: AppDS.red),
                          ] else if (r.isExpiringSoon) ...[
                            const SizedBox(width: 4),
                            _Badge(label: 'Expiring', color: AppDS.yellow),
                          ],
                          if (r.isLowStock) ...[
                            const SizedBox(width: 4),
                            _Badge(label: 'Low', color: AppDS.orange),
                          ],
                          if (r.hazard != null && r.hazard!.isNotEmpty) ...[
                            const SizedBox(width: 4),
                            Tooltip(
                              message: 'Hazard: ${r.hazard}',
                              child: const Icon(
                                Icons.warning_amber_outlined,
                                size: 13,
                                color: AppDS.yellow,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
          ),

          // ── Room / Location ──────────────────────────────────────────────
          SizedBox(
            width: _colRoom,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
              child: _tip(
                roomName,
                Text(
                  roomName ?? '—',
                  overflow: TextOverflow.ellipsis,
                  style: roomName != null ? tsCell : tsMuted,
                ),
              ),
            ),
          ),
          SizedBox(
            width: _colLoc,
            child: GestureDetector(
              onDoubleTap: () => onStartEdit(r.id, 'location', ''),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                child: _isEditing('location')
                    ? _ArrowDropdown<int?>(
                        values: [
                          null,
                          ...locations.map(
                            (l) => (l['location_id'] as num).toInt(),
                          ),
                        ],
                        current: r.locationId,
                        labelOf: (id) {
                          if (id == null) return 'None';
                          final loc = locations.firstWhere(
                            (l) => (l['location_id'] as num).toInt() == id,
                            orElse: () => <String, dynamic>{},
                          );
                          return (loc['_display'] as String?) ??
                              (loc['location_name'] as String?) ??
                              '—';
                        },
                        onSelect: (v) => onCommitLocation(r.id, v),
                        onCancel: onCancel,
                        onAddNewRow: onAddNewRow,
                        autoOpen: true,
                      )
                    : _tip(
                        _locationDisplay(r.locationId),
                        Text(
                          _locationDisplay(r.locationId) ?? '—',
                          overflow: TextOverflow.ellipsis,
                          style: _locationDisplay(r.locationId) != null
                              ? tsCell
                              : tsMuted,
                        ),
                      ),
              ),
            ),
          ),

          // ── Storage Temp ────────────────────────────────────────────────
          SizedBox(
            width: _colStorage,
            child: GestureDetector(
              onDoubleTap: () =>
                  onStartEdit(r.id, 'storageTemp', r.storageTemp ?? ''),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                child: _isEditing('storageTemp')
                    ? _ArrowDropdown<String?>(
                        values: [null, ...ReagentModel.tempOptions],
                        current: r.storageTemp,
                        labelOf: (v) => v ?? '—',
                        onSelect: (v) => onCommitStorageTemp(r.id, v),
                        onCancel: onCancel,
                        onAddNewRow: onAddNewRow,
                        autoOpen: true,
                      )
                    : r.storageTemp != null
                    ? _Badge(
                        label: r.storageTemp!,
                        color: switch (r.storageTemp!) {
                          'RT' => const Color(0xFFF59E0B),
                          '4°C' => const Color(0xFF22C55E),
                          '-20°C' => const Color(0xFF38BDF8),
                          '-80°C' => const Color(0xFF6366F1),
                          'liquid N2' => const Color(0xFFA855F7),
                          _ => const Color(0xFF64748B),
                        },
                      )
                    : Text('—', style: tsMuted),
              ),
            ),
          ),

          // ── Physical State ────────────────────────────────────────────────
          SizedBox(
            width: _colState,
            child: GestureDetector(
              onDoubleTap: () =>
                  onStartEdit(r.id, 'physicalState', r.physicalState ?? ''),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                child: _isEditing('physicalState')
                    ? _ArrowDropdown<String?>(
                        values: [null, ...ReagentModel.physicalStateOptions],
                        current: r.physicalState,
                        labelOf: (v) => v == null
                            ? '—'
                            : ReagentModel.physicalStateLabel(v),
                        onSelect: (v) => onCommitPhysicalState(r.id, v),
                        onCancel: onCancel,
                        onAddNewRow: onAddNewRow,
                        autoOpen: true,
                      )
                    : r.physicalState != null
                    ? _Badge(
                        label: ReagentModel.physicalStateLabel(
                          r.physicalState!,
                        ),
                        color: switch (r.physicalState!) {
                          'liquid' => const Color(0xFF38BDF8),
                          'solid' => const Color(0xFF94A3B8),
                          'gas' => const Color(0xFFA78BFA),
                          _ => const Color(0xFF64748B),
                        },
                      )
                    : Text('—', style: tsMuted),
              ),
            ),
          ),

          // ── CAS Number ────────────────────────────────────────────────────
          SizedBox(
            width: _colCas,
            child: _editCell(
              context,
              'casNumber',
              r.casNumber ?? '',
              _tip(
                r.casNumber,
                Text(
                  r.casNumber ?? '—',
                  overflow: TextOverflow.ellipsis,
                  style: r.casNumber != null ? tsMono : tsMonoMut,
                ),
              ),
              tsMono,
            ),
          ),

          // ── Formula ───────────────────────────────────────────────────────
          SizedBox(
            width: _colFormula,
            child: _editCell(
              context,
              'formula',
              r.formula ?? '',
              _tip(
                r.formula,
                Text(
                  r.formula ?? '—',
                  overflow: TextOverflow.ellipsis,
                  style: r.formula != null ? tsMono : tsMonoMut,
                ),
              ),
              tsMono,
            ),
          ),

          // ── Opened Date ───────────────────────────────────────────────────
          SizedBox(
            width: _colOpened,
            child: _editCell(
              context,
              'openedDate',
              r.openedDate != null
                  ? '${r.openedDate!.year}-${r.openedDate!.month.toString().padLeft(2, '0')}-${r.openedDate!.day.toString().padLeft(2, '0')}'
                  : '',
              Text(
                r.openedDate != null
                    ? '${r.openedDate!.year}-${r.openedDate!.month.toString().padLeft(2, '0')}-${r.openedDate!.day.toString().padLeft(2, '0')}'
                    : '—',
                overflow: TextOverflow.ellipsis,
                style: r.openedDate != null ? tsMono : tsMonoMut,
              ),
              tsMono,
            ),
          ),

          // ── Size (package/flask size) ─────────────────────────────────────
          SizedBox(
            width: _colPackSize,
            child: _editCell(
              context,
              'packageSize',
              r.packageSize?.toString() ?? '',
              Text(
                r.displayPackageSize,
                overflow: TextOverflow.ellipsis,
                style: r.packageSize != null ? tsMono : tsMonoMut,
              ),
              tsMono,
              keyboardType: TextInputType.number,
            ),
          ),

          // ── Unit ──────────────────────────────────────────────────────────
          SizedBox(
            width: _colUnit,
            child: _editCell(
              context,
              'unit',
              r.unit ?? '',
              Text(
                _unitDisplay(r.unit),
                overflow: TextOverflow.ellipsis,
                style: r.unit != null ? tsCell : tsMuted,
              ),
              tsCell,
            ),
          ),

          // ── Container count ───────────────────────────────────────────────
          SizedBox(
            width: _colCount,
            child: _editCell(
              context,
              'containerCount',
              r.containerCount?.toString() ?? '',
              Text(
                r.containerCount?.toString() ?? '—',
                overflow: TextOverflow.ellipsis,
                style: r.isLowStock
                    ? GoogleFonts.jetBrainsMono(
                        fontSize: 12,
                        color: AppDS.orange,
                        fontWeight: FontWeight.w600,
                      )
                    : (r.containerCount != null ? tsMono : tsMonoMut),
              ),
              tsMono,
              keyboardType: TextInputType.number,
            ),
          ),

          // ── Container min ─────────────────────────────────────────────────
          SizedBox(
            width: _colMin,
            child: _editCell(
              context,
              'containerMin',
              r.containerMin?.toString() ?? '',
              Text(
                r.containerMin?.toString() ?? '—',
                overflow: TextOverflow.ellipsis,
                style: r.containerMin != null ? tsMonoMut : tsMonoMut,
              ),
              tsMonoMut,
              keyboardType: TextInputType.number,
            ),
          ),

          // ── Contamination ─────────────────────────────────────────────────
          SizedBox(
            width: _colContam,
            child: GestureDetector(
              onDoubleTap: () =>
                  onStartEdit(r.id, 'contamination', r.contamination),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                child: _isEditing('contamination')
                    ? _ArrowDropdown<String>(
                        values: ReagentModel.contaminationOptions,
                        current: r.contamination,
                        labelOf: ReagentModel.contaminationLabel,
                        onSelect: (v) => onCommitContamination(r.id, v),
                        onCancel: onCancel,
                        onAddNewRow: onAddNewRow,
                        autoOpen: true,
                      )
                    : _Badge(
                        label: ReagentModel.contaminationLabel(r.contamination),
                        color: _contamColor[r.contamination] ?? muted,
                      ),
              ),
            ),
          ),

          // ── Brand ─────────────────────────────────────────────────────────
          SizedBox(
            width: _colBrand,
            child: _editCell(
              context,
              'brand',
              r.brand ?? '',
              _stableChip(r.brand, tsMuted),
              tsCell,
            ),
          ),

          // ── Supplier ──────────────────────────────────────────────────────
          SizedBox(
            width: _colSupp,
            child: _editCell(
              context,
              'supplier',
              r.supplier ?? '',
              _stableChip(r.supplier, tsMuted),
              tsCell,
            ),
          ),
        ],
      ),
    );
  }
}

class _RowBtn extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;
  final Color? color;
  const _RowBtn(this.icon, this.tooltip, this.onPressed, {this.color});

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: Icon(icon, size: 15, color: color ?? context.appTextSecondary),
      tooltip: tooltip,
      onPressed: onPressed,
      visualDensity: VisualDensity.compact,
      padding: const EdgeInsets.all(6),
      constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
    );
  }
}

// Arrow-key driven inline selector: Up/Down cycle through values,
// Enter commits, Escape cancels. Autofocuses on mount.
class _ArrowDropdown<T> extends StatefulWidget {
  final List<T> values;
  final T current;
  final String Function(T) labelOf;
  final void Function(T) onSelect;
  final VoidCallback onCancel;
  final VoidCallback? onAddNewRow;
  final bool autoOpen;
  const _ArrowDropdown({
    required this.values,
    required this.current,
    required this.labelOf,
    required this.onSelect,
    required this.onCancel,
    this.onAddNewRow,
    this.autoOpen = false,
  });

  @override
  State<_ArrowDropdown<T>> createState() => _ArrowDropdownState<T>();
}

class _ArrowDropdownState<T> extends State<_ArrowDropdown<T>> {
  late int _index;
  final _focus = FocusNode();

  @override
  void initState() {
    super.initState();
    _index = widget.values.indexOf(widget.current);
    if (_index < 0) _index = 0;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (widget.autoOpen) {
        _showMenu();
      } else {
        _focus.requestFocus();
      }
    });
  }

  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }

  Future<void> _showMenu() async {
    final box = context.findRenderObject() as RenderBox;
    final pos = box.localToGlobal(Offset(0, box.size.height));
    final picked = await showMenu<int>(
      context: context,
      position: RelativeRect.fromLTRB(
        pos.dx,
        pos.dy,
        pos.dx + box.size.width,
        pos.dy,
      ),
      color: context.appSurface,
      items: [
        for (var i = 0; i < widget.values.length; i++)
          PopupMenuItem(
            value: i,
            height: 32,
            child: Text(
              widget.labelOf(widget.values[i]),
              style: GoogleFonts.spaceGrotesk(
                color: i == _index ? AppDS.accent : context.appTextPrimary,
                fontSize: 12,
                fontWeight: i == _index ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ),
      ],
    );
    if (!mounted) return;
    if (picked != null) {
      setState(() => _index = picked);
      widget.onSelect(widget.values[picked]);
    } else {
      _focus.requestFocus();
    }
  }

  @override
  Widget build(BuildContext context) {
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.arrowDown): () {
          setState(() => _index = (_index + 1) % widget.values.length);
        },
        const SingleActivator(LogicalKeyboardKey.arrowUp): () {
          setState(
            () => _index =
                (_index - 1 + widget.values.length) % widget.values.length,
          );
        },
        const SingleActivator(LogicalKeyboardKey.enter): () =>
            widget.onSelect(widget.values[_index]),
        const SingleActivator(LogicalKeyboardKey.enter, control: true): () {
          widget.onSelect(widget.values[_index]);
          widget.onAddNewRow?.call();
        },
        const SingleActivator(LogicalKeyboardKey.tab): () =>
            widget.onSelect(widget.values[_index]),
        const SingleActivator(LogicalKeyboardKey.escape): widget.onCancel,
      },
      child: Focus(
        focusNode: _focus,
        child: GestureDetector(
          onTap: _showMenu,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
            decoration: BoxDecoration(
              color: context.appSurface2,
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: AppDS.accent, width: 1.5),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    widget.labelOf(widget.values[_index]),
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.spaceGrotesk(
                      color: context.appTextPrimary,
                      fontSize: 12,
                    ),
                  ),
                ),
                Icon(Icons.unfold_more, size: 12, color: context.appTextMuted),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  final String label;
  final Color color;
  const _Badge({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: GoogleFonts.spaceGrotesk(color: color, fontSize: 11),
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final Color? color;
  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final c = color ?? AppDS.accent;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: selected ? c.withValues(alpha: 0.18) : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? c : AppDS.border,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Text(
          label,
          style: GoogleFonts.spaceGrotesk(
            color: selected ? c : AppDS.textSecondary,
            fontSize: 12,
            fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
      ),
    );
  }
}

// ─── Add/Edit Form Dialog ───────────────────────────────────────────────────────
class _ReagentFormDialog extends StatefulWidget {
  final ReagentModel? existing;
  final List<Map<String, dynamic>> locations;
  final String? nextCode;
  const _ReagentFormDialog({
    this.existing,
    required this.locations,
    this.nextCode,
  });

  @override
  State<_ReagentFormDialog> createState() => _ReagentFormDialogState();
}

class _ReagentFormDialogState extends State<_ReagentFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _codeCtrl;
  late final TextEditingController _nameCtrl;
  late final TextEditingController _brandCtrl;
  late final TextEditingController _refCtrl;
  late final TextEditingController _casCtrl;
  late final TextEditingController _synonymsCtrl;
  late final TextEditingController _unitCtrl;
  late final TextEditingController _packSizeCtrl;
  late final TextEditingController _countCtrl;
  late final TextEditingController _minCtrl;
  late final TextEditingController _priceEurCtrl;
  late final TextEditingController _concCtrl;
  late final TextEditingController _lotCtrl;
  late final TextEditingController _supplierCtrl;
  late final TextEditingController _hazardCtrl;
  late final TextEditingController _responsibleCtrl;
  late final TextEditingController _formulaCtrl;
  late final TextEditingController _notesCtrl;
  late final TextEditingController _positionCtrl;
  late final TextEditingController _contamNotesCtrl;
  late final TextEditingController _tagsCtrl;
  String? _subcategory;
  String _category = 'chemical';
  String _stockStatus = 'in_stock';
  String _contamination = 'none';
  String? _physicalState;
  String? _storageTemp;
  int? _locationId;
  DateTime? _expiryDate;
  DateTime? _receivedDate;
  DateTime? _openedDate;
  DateTime? _contamDate;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _codeCtrl = TextEditingController(text: e?.code ?? widget.nextCode ?? '');
    _nameCtrl = TextEditingController(text: e?.name ?? '');
    _brandCtrl = TextEditingController(text: e?.brand ?? '');
    _refCtrl = TextEditingController(text: e?.reference ?? '');
    _casCtrl = TextEditingController(text: e?.casNumber ?? '');
    _synonymsCtrl = TextEditingController(text: e?.synonyms ?? '');
    _unitCtrl = TextEditingController(text: e?.unit ?? '');
    _packSizeCtrl = TextEditingController(
      text: e?.packageSize != null ? e!.packageSize.toString() : '',
    );
    _countCtrl = TextEditingController(
      text: e?.containerCount != null ? e!.containerCount.toString() : '1',
    );
    _minCtrl = TextEditingController(
      text: e?.containerMin != null ? e!.containerMin.toString() : '',
    );
    _priceEurCtrl = TextEditingController(
      text: e?.priceEur != null ? e!.priceEur.toString() : '',
    );
    _concCtrl = TextEditingController(text: e?.concentration ?? '');
    _lotCtrl = TextEditingController(text: e?.lotNumber ?? '');
    _supplierCtrl = TextEditingController(text: e?.supplier ?? '');
    _hazardCtrl = TextEditingController(text: e?.hazard ?? '');
    _responsibleCtrl = TextEditingController(text: e?.responsible ?? '');
    _formulaCtrl = TextEditingController(text: e?.formula ?? '');
    _notesCtrl = TextEditingController(text: e?.notes ?? '');
    _positionCtrl = TextEditingController(text: e?.position ?? '');
    _contamNotesCtrl = TextEditingController(text: e?.contaminationNotes ?? '');
    _tagsCtrl = TextEditingController(text: e?.tags ?? '');
    _subcategory = e?.subcategory;
    _category = e?.category ?? 'chemical';
    _stockStatus = e?.stockStatus ?? 'in_stock';
    _contamination = e?.contamination ?? 'none';
    _physicalState = e?.physicalState;
    _storageTemp = e?.storageTemp;
    _locationId = e?.locationId;
    _expiryDate = e?.expiryDate;
    _receivedDate = e?.receivedDate;
    _openedDate = e?.openedDate;
    _contamDate = e?.contaminationDate;
  }

  @override
  void dispose() {
    for (final c in [
      _codeCtrl,
      _nameCtrl,
      _brandCtrl,
      _refCtrl,
      _casCtrl,
      _synonymsCtrl,
      _unitCtrl,
      _packSizeCtrl,
      _countCtrl,
      _minCtrl,
      _priceEurCtrl,
      _concCtrl,
      _lotCtrl,
      _supplierCtrl,
      _hazardCtrl,
      _responsibleCtrl,
      _formulaCtrl,
      _notesCtrl,
      _positionCtrl,
      _contamNotesCtrl,
      _tagsCtrl,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      final data = {
        'reagent_name': _nameCtrl.text.trim(),
        'reagent_category': _category,
        'reagent_stock_status': ReagentModel.normalizeStockStatus(_stockStatus),
        'reagent_contamination': _contamination,
        if (_subcategory != null) 'reagent_subcategory': _subcategory,
        'reagent_tags': ReagentModel.joinTags(_tagsCtrl.text.split(';')),
        'reagent_code': _codeCtrl.text.trim().isEmpty
            ? null
            : _codeCtrl.text.trim(),
        if (_physicalState != null) 'reagent_physical_state': _physicalState,
        if (_brandCtrl.text.isNotEmpty) 'reagent_brand': _brandCtrl.text.trim(),
        if (_refCtrl.text.isNotEmpty) 'reagent_reference': _refCtrl.text.trim(),
        if (_casCtrl.text.isNotEmpty)
          'reagent_cas_number': _casCtrl.text.trim(),
        if (_synonymsCtrl.text.isNotEmpty)
          'reagent_synonyms': _synonymsCtrl.text.trim(),
        if (_formulaCtrl.text.isNotEmpty)
          'reagent_formula': _formulaCtrl.text.trim(),
        if (_unitCtrl.text.isNotEmpty) 'reagent_unit': _unitCtrl.text.trim(),
        if (_packSizeCtrl.text.isNotEmpty)
          'reagent_package_size': double.tryParse(_packSizeCtrl.text.trim()),
        if (_countCtrl.text.isNotEmpty)
          'reagent_container_count': int.tryParse(_countCtrl.text.trim()),
        if (_minCtrl.text.isNotEmpty)
          'reagent_container_min': int.tryParse(_minCtrl.text.trim()),
        if (_priceEurCtrl.text.isNotEmpty)
          'reagent_price_eur': double.tryParse(_priceEurCtrl.text.trim()),
        if (_concCtrl.text.isNotEmpty)
          'reagent_concentration': _concCtrl.text.trim(),
        if (_storageTemp != null) 'reagent_storage_temp': _storageTemp,
        if (_locationId != null) 'reagent_location_id': _locationId,
        if (_positionCtrl.text.isNotEmpty)
          'reagent_position': _positionCtrl.text.trim(),
        if (_lotCtrl.text.isNotEmpty)
          'reagent_lot_number': _lotCtrl.text.trim(),
        if (_expiryDate != null)
          'reagent_expiry_date': _expiryDate!.toIso8601String().substring(
            0,
            10,
          ),
        if (_receivedDate != null)
          'reagent_received_date': _receivedDate!.toIso8601String().substring(
            0,
            10,
          ),
        if (_openedDate != null)
          'reagent_opened_date': _openedDate!.toIso8601String().substring(
            0,
            10,
          ),
        if (_supplierCtrl.text.isNotEmpty)
          'reagent_supplier': _supplierCtrl.text.trim(),
        if (_hazardCtrl.text.isNotEmpty)
          'reagent_hazard': _hazardCtrl.text.trim(),
        if (_responsibleCtrl.text.isNotEmpty)
          'reagent_responsible': _responsibleCtrl.text.trim(),
        if (_notesCtrl.text.isNotEmpty) 'reagent_notes': _notesCtrl.text.trim(),
        if (_contamNotesCtrl.text.isNotEmpty)
          'reagent_contamination_notes': _contamNotesCtrl.text.trim(),
        if (_contamDate != null)
          'reagent_contamination_date': _contamDate!
              .toIso8601String()
              .substring(0, 10),
        'reagent_updated_at': DateTime.now().toUtc().toIso8601String(),
      };

      if (widget.existing != null) {
        await Supabase.instance.client
            .from('reagents')
            .update(data)
            .eq('reagent_id', widget.existing!.id);
      } else {
        final row = await Supabase.instance.client
            .from('reagents')
            .insert(data)
            .select('reagent_id')
            .single();
        final newId = row['reagent_id'] as int;
        await Supabase.instance.client
            .from('reagents')
            .update({
              'reagent_qrcode': QrRules.build(
                SupabaseManager.projectRef ?? 'local',
                'reagents',
                newId,
              ),
            })
            .eq('reagent_id', newId);
      }
      unawaited(BackupService.instance.notifyCrudChange('reagents'));

      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      debugPrint('ReagentFormDialog save error: $e');
      setState(() => _saving = false);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to save: $e')));
      }
    }
  }

  Future<void> _pickDate(String which) async {
    final now = DateTime.now();
    final initial = switch (which) {
      'expiry' => _expiryDate ?? now.add(const Duration(days: 365)),
      'received' => _receivedDate ?? now,
      'opened' => _openedDate ?? now,
      'contam' => _contamDate ?? now,
      _ => now,
    };
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2000),
      lastDate: DateTime(2040),
      builder: (ctx, child) => Theme(
        data: ThemeData.dark().copyWith(
          colorScheme: const ColorScheme.dark(
            primary: AppDS.accent,
            surface: AppDS.surface,
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null) {
      setState(() {
        switch (which) {
          case 'expiry':
            _expiryDate = picked;
          case 'received':
            _receivedDate = picked;
          case 'opened':
            _openedDate = picked;
          case 'contam':
            _contamDate = picked;
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final subOptions = ReagentModel.subcategoryOptionsSorted(_category);
    // If current subcategory isn't in the list for the selected category,
    // null it out so the dropdown doesn't assert.
    if (_subcategory != null && !subOptions.contains(_subcategory)) {
      _subcategory = null;
    }
    return AlertDialog(
      backgroundColor: context.appSurface,
      insetPadding: const EdgeInsets.fromLTRB(24, 36, 24, 24),
      titlePadding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
      contentPadding: const EdgeInsets.fromLTRB(24, 16, 24, 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      title: Text(
        widget.existing != null ? 'Edit Reagent' : 'Add Reagent',
        style: GoogleFonts.spaceGrotesk(
          color: context.appTextPrimary,
          fontWeight: FontWeight.w600,
        ),
      ),
      content: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 880,
          maxHeight: MediaQuery.sizeOf(context).height * 0.78,
        ),
        child: SizedBox(
          width: 880,
          child: Form(
            key: _formKey,
            child: SingleChildScrollView(
              padding: const EdgeInsets.only(top: 4),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Expanded(
                        flex: 2,
                        child: _field(
                          context,
                          _nameCtrl,
                          'Name *',
                          validator: (v) =>
                              v == null || v.isEmpty ? 'Required' : null,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        flex: 1,
                        child: _field(context, _codeCtrl, 'Code (e.g. BR001)'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: _dropdownField<String>(
                          context,
                          label: 'Category',
                          value: _category,
                          items: ReagentModel.categoryOptionsSorted
                              .map(
                                (t) => DropdownMenuItem(
                                  value: t,
                                  child: Text(
                                    ReagentModel.categoryLabel(t),
                                    style: GoogleFonts.spaceGrotesk(
                                      color: context.appTextPrimary,
                                      fontSize: 13,
                                    ),
                                  ),
                                ),
                              )
                              .toList(),
                          onChanged: (v) => setState(() {
                            _category = v ?? 'chemical';
                            _subcategory = null;
                          }),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _dropdownField<String?>(
                          context,
                          label: 'Sub-category',
                          value: _subcategory,
                          items: [
                            DropdownMenuItem<String?>(
                              value: null,
                              child: Text(
                                '—',
                                style: GoogleFonts.spaceGrotesk(
                                  color: context.appTextMuted,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                            ...subOptions.map(
                              (s) => DropdownMenuItem<String?>(
                                value: s,
                                child: Text(
                                  ReagentModel.subcategoryLabel(s),
                                  style: GoogleFonts.spaceGrotesk(
                                    color: context.appTextPrimary,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                            ),
                          ],
                          onChanged: (v) => setState(() => _subcategory = v),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _dropdownField<String?>(
                          context,
                          label: 'Physical State',
                          value: _physicalState,
                          items: [
                            DropdownMenuItem<String?>(
                              value: null,
                              child: Text(
                                '—',
                                style: GoogleFonts.spaceGrotesk(
                                  color: context.appTextMuted,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                            ...ReagentModel.physicalStateOptions.map(
                              (s) => DropdownMenuItem<String?>(
                                value: s,
                                child: Text(
                                  ReagentModel.physicalStateLabel(s),
                                  style: GoogleFonts.spaceGrotesk(
                                    color: context.appTextPrimary,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                            ),
                          ],
                          onChanged: (v) => setState(() => _physicalState = v),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(child: _field(context, _brandCtrl, 'Brand')),
                      const SizedBox(width: 10),
                      Expanded(child: _field(context, _refCtrl, 'Reference')),
                      const SizedBox(width: 10),
                      Expanded(child: _field(context, _casCtrl, 'CAS Number')),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: _field(context, _synonymsCtrl, 'Synonyms'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(child: _field(context, _formulaCtrl, 'Formula')),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _dropdownField<String>(
                          context,
                          label: 'Stock Status',
                          value: _stockStatus,
                          items: ReagentModel.stockStatusOptions
                              .map(
                                (s) => DropdownMenuItem(
                                  value: s,
                                  child: Text(
                                    ReagentModel.stockStatusLabel(s),
                                    style: GoogleFonts.spaceGrotesk(
                                      color: context.appTextPrimary,
                                      fontSize: 13,
                                    ),
                                  ),
                                ),
                              )
                              .toList(),
                          onChanged: (v) => setState(
                            () => _stockStatus = v == null
                                ? 'in_stock'
                                : ReagentModel.normalizeStockStatus(v),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _field(
                          context,
                          _priceEurCtrl,
                          'Price (EUR)',
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  // ── Stock section ───────────────────────────────────────────
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'STOCK',
                      style: GoogleFonts.spaceGrotesk(
                        color: context.appTextMuted,
                        fontSize: 10,
                        letterSpacing: 0.8,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Expanded(
                        child: _field(
                          context,
                          _packSizeCtrl,
                          'Package / flask size',
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _field(context, _unitCtrl, 'Unit (mL / g / …)'),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _field(context, _concCtrl, 'Concentration'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: _field(
                          context,
                          _countCtrl,
                          '# Containers',
                          keyboardType: TextInputType.number,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _field(
                          context,
                          _minCtrl,
                          'Min containers (reorder)',
                          keyboardType: TextInputType.number,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  // ── Storage section ─────────────────────────────────────────
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'STORAGE',
                      style: GoogleFonts.spaceGrotesk(
                        color: context.appTextMuted,
                        fontSize: 10,
                        letterSpacing: 0.8,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Expanded(
                        child: _dropdownField<String?>(
                          context,
                          label: 'Storage Temp',
                          value: _storageTemp,
                          items: [
                            DropdownMenuItem<String?>(
                              value: null,
                              child: Text(
                                '—',
                                style: GoogleFonts.spaceGrotesk(
                                  color: context.appTextMuted,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                            ...ReagentModel.tempOptions.map(
                              (t) => DropdownMenuItem(
                                value: t,
                                child: Text(
                                  t,
                                  style: GoogleFonts.spaceGrotesk(
                                    color: context.appTextPrimary,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                            ),
                          ],
                          onChanged: (v) => setState(() => _storageTemp = v),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _dropdownField<int?>(
                          context,
                          label: 'Location',
                          value: _locationId,
                          items: [
                            DropdownMenuItem<int?>(
                              value: null,
                              child: Text(
                                'None',
                                style: GoogleFonts.spaceGrotesk(
                                  color: context.appTextMuted,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                            ...widget.locations.map(
                              (l) => DropdownMenuItem<int?>(
                                value: (l['location_id'] as num).toInt(),
                                child: Text(
                                  (l['_display'] as String?) ??
                                      (l['location_name'] as String),
                                  style: GoogleFonts.spaceGrotesk(
                                    color: context.appTextPrimary,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                            ),
                          ],
                          onChanged: (v) => setState(() => _locationId = v),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _field(context, _positionCtrl, 'Position'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: _datePicker(
                          context,
                          'Received Date',
                          _receivedDate,
                          () => _pickDate('received'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _datePicker(
                          context,
                          'Opened Date',
                          _openedDate,
                          () => _pickDate('opened'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _datePicker(
                          context,
                          'Expiry Date',
                          _expiryDate,
                          () => _pickDate('expiry'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(child: _field(context, _lotCtrl, 'Lot Number')),
                    ],
                  ),
                  const SizedBox(height: 16),
                  // ── Contamination section ───────────────────────────────────
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'CONTAMINATION',
                      style: GoogleFonts.spaceGrotesk(
                        color: context.appTextMuted,
                        fontSize: 10,
                        letterSpacing: 0.8,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Expanded(
                        child: _dropdownField<String>(
                          context,
                          label: 'Status',
                          value: _contamination,
                          items: ReagentModel.contaminationOptions
                              .map(
                                (c) => DropdownMenuItem(
                                  value: c,
                                  child: Text(
                                    ReagentModel.contaminationLabel(c),
                                    style: GoogleFonts.spaceGrotesk(
                                      color: context.appTextPrimary,
                                      fontSize: 13,
                                    ),
                                  ),
                                ),
                              )
                              .toList(),
                          onChanged: (v) => setState(() {
                            _contamination = v ?? 'none';
                            if (_contamination != 'none' &&
                                _contamDate == null) {
                              _contamDate = DateTime.now();
                            }
                          }),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _datePicker(
                          context,
                          'Detected on',
                          _contamDate,
                          () => _pickDate('contam'),
                        ),
                      ),
                    ],
                  ),
                  if (_contamination != 'none') ...[
                    const SizedBox(height: 10),
                    _field(
                      context,
                      _contamNotesCtrl,
                      'Contamination notes',
                      maxLines: 2,
                    ),
                  ],
                  const SizedBox(height: 16),
                  // ── Other ───────────────────────────────────────────────────
                  Row(
                    children: [
                      Expanded(
                        child: _field(context, _supplierCtrl, 'Supplier'),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _field(context, _responsibleCtrl, 'Responsible'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  _field(context, _hazardCtrl, 'Hazard codes (e.g. H225 H302)'),
                  const SizedBox(height: 10),
                  _field(
                    context,
                    _tagsCtrl,
                    'Tags (separated by ";", e.g. "in-house; sterile")',
                  ),
                  const SizedBox(height: 10),
                  _field(context, _notesCtrl, 'Notes', maxLines: 3),
                ],
              ),
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.pop(context, false),
          child: Text(
            'Cancel',
            style: GoogleFonts.spaceGrotesk(color: context.appTextSecondary),
          ),
        ),
        FilledButton(
          onPressed: _saving ? null : _save,
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFFF59E0B),
            foregroundColor: Colors.black,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          child: _saving
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(
                  widget.existing != null ? 'Save' : 'Create',
                  style: GoogleFonts.spaceGrotesk(),
                ),
        ),
      ],
    );
  }

  Widget _field(
    BuildContext context,
    TextEditingController ctrl,
    String label, {
    int maxLines = 1,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: ctrl,
      maxLines: maxLines,
      keyboardType: keyboardType,
      validator: validator,
      style: GoogleFonts.spaceGrotesk(
        color: context.appTextPrimary,
        fontSize: 13,
      ),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: GoogleFonts.spaceGrotesk(
          color: context.appTextSecondary,
          fontSize: 12,
        ),
        filled: true,
        fillColor: context.appSurface3,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: context.appBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: context.appBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: AppDS.accent),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 10,
        ),
      ),
    );
  }

  Widget _dropdownField<T>(
    BuildContext context, {
    required String label,
    required T value,
    required List<DropdownMenuItem<T>> items,
    required void Function(T?) onChanged,
  }) {
    return InputDecorator(
      decoration: InputDecoration(
        labelText: label,
        labelStyle: GoogleFonts.spaceGrotesk(
          color: context.appTextSecondary,
          fontSize: 12,
        ),
        filled: true,
        fillColor: context.appSurface3,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: context.appBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: context.appBorder),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          value: value,
          isExpanded: true,
          dropdownColor: context.appSurface,
          style: GoogleFonts.spaceGrotesk(
            color: context.appTextPrimary,
            fontSize: 13,
          ),
          items: items,
          onChanged: onChanged,
        ),
      ),
    );
  }

  Widget _datePicker(
    BuildContext context,
    String label,
    DateTime? date,
    VoidCallback onTap,
  ) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: context.appSurface3,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: context.appBorder),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: GoogleFonts.spaceGrotesk(
                color: context.appTextSecondary,
                fontSize: 11,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              date != null
                  ? date.toIso8601String().substring(0, 10)
                  : 'Select date',
              style: GoogleFonts.spaceGrotesk(
                color: date != null
                    ? context.appTextPrimary
                    : context.appTextMuted,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
