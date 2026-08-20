// reagents_page.dart - Reagent inventory: sortable scrollable list,
// filter panel, inline editing, CSV export.
// Widget and dialog classes in reagents_widgets.dart (part).

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show LogicalKeyboardKey;

import '/theme/module_permission.dart';
import '/theme/grid_widgets.dart';

import 'package:google_fonts/google_fonts.dart';

import 'dart:io';

import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide LocalStorage;

import '/core/data_cache.dart';
import '/supabase/supabase_manager.dart';
import '/theme/theme.dart';
import '../../backups/backup_service.dart';
import '../../camera/qr_scanner/qr_code_rules.dart';
import 'reagent_model.dart';
import 'reagent_code_allocator.dart';
import 'reagent_detail_page.dart';
import 'reagent_excel_import_page.dart';
import '../../requests/requests_page.dart';

part 'reagents_widgets.dart';

// ── Column widths ─────────────────────────────────────────────────────────────
const _colBtn = 60.0;
const _colCode = 90.0;
const _colStock = 110.0;
const _colCategory = 140.0;
const _colSubcat = 130.0;
const _colName = 190.0;
const _colState = 80.0;
const _colCas = 110.0;
const _colFormula = 130.0;
const _colOpened = 100.0;
const _colRoom = 210.0;
const _colLoc = 190.0;
const _colStorage = 100.0;
const _colPackSize = 90.0;
const _colCount = 70.0;
const _colMin = 60.0;
const _colUnit = 60.0;
const _colContam = 110.0;
const _colBrand = 110.0;
const _colSupp = 120.0;
const _colTags = 160.0;
const _tableW =
    _colBtn +
    _colCode +
    _colStock +
    _colCategory +
    _colSubcat +
    _colName +
    _colState +
    _colCas +
    _colFormula +
    _colOpened +
    _colRoom +
    _colLoc +
    _colStorage +
    _colPackSize +
    _colCount +
    _colMin +
    _colUnit +
    _colContam +
    _colBrand +
    _colSupp +
    _colTags;

// Tab-navigable columns — matches visual column order left-to-right.
// 'stockStatus', 'category', 'subcategory', 'storageTemp',
// 'physicalState', 'contamination', 'room' and 'location' are dropdowns;
// the rest are text fields.
const _tabCols = [
  'code',
  'stockStatus',
  'category',
  'subcategory',
  'tags',
  'name',
  'room',
  'location',
  'storageTemp',
  'physicalState',
  'casNumber',
  'formula',
  'openedDate',
  'packageSize',
  'unit',
  'containerCount',
  'containerMin',
  'contamination',
  'brand',
  'supplier',
];

class ReagentsPage extends StatefulWidget {
  const ReagentsPage({super.key});

  @override
  State<ReagentsPage> createState() => _ReagentsPageState();
}

class _ReagentsPageState extends State<ReagentsPage> {
  List<ReagentModel> _all = [];
  List<ReagentModel> _filtered = [];
  List<Map<String, dynamic>> _locations = [];
  bool _loading = true;
  String _search = '';
  String _categoryFilter = 'all';
  String _statusFilter = 'all';
  bool _showFilters = false;
  String _sortKey = 'code';
  bool _sortAsc = true;
  final _searchCtrl = TextEditingController();
  Map<String, dynamic>? _editingCell;
  final _editController = TextEditingController();
  final _editFocus = FocusNode();
  bool _selectionMode = false;
  bool _deletingSelected = false;
  final Set<int> _selectedIds = {};

  final _horizCtrl = ScrollController();
  final _vertCtrl = ScrollController();
  final _hOffset = ValueNotifier<double>(0);
  final _vOffset = ValueNotifier<double>(0);

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _editController.dispose();
    _editFocus.dispose();
    _horizCtrl.dispose();
    _vertCtrl.dispose();
    _hOffset.dispose();
    _vOffset.dispose();
    super.dispose();
  }

  List<ReagentModel> _reagentsFromRaw(List<dynamic> raw) =>
      raw.map<ReagentModel>((r) {
        final locData = (r as Map)['location'];
        final locName = locData is Map
            ? locData['location_name'] as String?
            : null;
        return ReagentModel.fromMap({
          ...Map<String, dynamic>.from(r),
          'location_name': locName,
        });
      }).toList();

  Future<void> _load() async {
    final cached = await DataCache.read('reagents');
    if (cached != null && mounted) {
      setState(() {
        _all = _reagentsFromRaw(cached);
        _loading = false;
        _applyFilters();
      });
    } else {
      setState(() => _loading = true);
    }
    try {
      final rows = await Supabase.instance.client
          .from('reagents')
          .select('*, location:reagent_location_id(location_name)')
          .order('reagent_name');
      await DataCache.write('reagents', rows as List<dynamic>);
      if (!mounted) return;
      setState(() {
        _all = _reagentsFromRaw(rows);
        _loading = false;
        _applyFilters();
      });
    } catch (e) {
      debugPrint('Reagents load error: $e');
      if (cached == null && mounted) {
        setState(() => _loading = false);
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Failed to load: $e')));
      }
    }
    final locations = await _loadLocations();
    if (!mounted) return;
    setState(() => _locations = locations);
    _applyFilters();
  }

  Map<String, dynamic>? _locationMetaById(int? id) {
    if (id == null) return null;
    for (final loc in _locations) {
      if ((loc['location_id'] as num).toInt() == id) return loc;
    }
    return null;
  }

  String? _roomDisplayForLocationId(int? locationId) {
    final loc = _locationMetaById(locationId);
    if (loc == null) return null;
    if ((loc['location_type'] as String?) == null ||
        (loc['location_type'] as String?) == 'room') {
      return (loc['_display'] as String?) ?? (loc['location_name'] as String?);
    }
    final parentId = (loc['location_parent_id'] as num?)?.toInt();
    final parent = _locationMetaById(parentId);
    return (parent?['_display'] as String?) ??
        (parent?['location_name'] as String?);
  }

  String? _locationDisplayForLocationId(int? locationId) {
    final loc = _locationMetaById(locationId);
    if (loc == null) return null;
    if ((loc['location_type'] as String?) == null ||
        (loc['location_type'] as String?) == 'room') {
      return '/';
    }
    return (loc['_display'] as String?) ?? (loc['location_name'] as String?);
  }

  void _applyFilters() {
    final q = _search.toLowerCase();
    var result = _all.where((r) {
      if (_categoryFilter != 'all' && r.category != _categoryFilter) {
        return false;
      }
      if (_statusFilter == 'expired' && !r.isExpired) return false;
      if (_statusFilter == 'expiring' && !r.isExpiringSoon) return false;
      if (_statusFilter == 'low' && !r.isLowStock) return false;
      if (_statusFilter == 'contaminated' && !r.isContaminated) return false;
      if (q.isEmpty) return true;
      final haystack = <String?>[
        r.code,
        r.stockStatus,
        ReagentModel.stockStatusLabel(r.stockStatus),
        r.name,
        r.brand,
        r.reference,
        r.casNumber,
        r.synonyms,
        r.category,
        ReagentModel.categoryLabel(r.category),
        r.subcategory,
        if (r.subcategory != null)
          ReagentModel.subcategoryLabel(r.subcategory!),
        r.unit,
        r.packageSize?.toString(),
        r.containerCount?.toString(),
        r.containerMin?.toString(),
        r.remainingAmount?.toString(),
        r.concentration,
        r.storageTemp,
        _roomDisplayForLocationId(r.locationId),
        _locationDisplayForLocationId(r.locationId),
        r.locationName,
        r.position,
        r.lotNumber,
        r.expiryDate?.toIso8601String().substring(0, 10),
        r.receivedDate?.toIso8601String().substring(0, 10),
        r.openedDate?.toIso8601String().substring(0, 10),
        r.supplier,
        r.hazard,
        r.responsible,
        r.formula,
        r.notes,
        r.physicalState,
        if (r.physicalState != null)
          ReagentModel.physicalStateLabel(r.physicalState!),
        r.contamination,
        ReagentModel.contaminationLabel(r.contamination),
        r.contaminationNotes,
        r.contaminationDate?.toIso8601String().substring(0, 10),
        r.tags,
      ];
      for (final s in haystack) {
        if (s != null && s.toLowerCase().contains(q)) return true;
      }
      return false;
    }).toList();

    // Natural sort for code: splits "BR0001" into prefix "BR" + number 1,
    // so BR0002 < BR0010 instead of lexicographic BR0010 < BR0002.
    int naturalCode(String a, String b) {
      final re = RegExp(r'^([A-Za-z]*)(\d*)(.*)$');
      final ma = re.firstMatch(a);
      final mb = re.firstMatch(b);
      final prefixCmp = (ma?.group(1) ?? '').compareTo(mb?.group(1) ?? '');
      if (prefixCmp != 0) return prefixCmp;
      final na = int.tryParse(ma?.group(2) ?? '') ?? 0;
      final nb = int.tryParse(mb?.group(2) ?? '') ?? 0;
      if (na != nb) return na.compareTo(nb);
      return (ma?.group(3) ?? '').compareTo(mb?.group(3) ?? '');
    }

    result.sort((a, b) {
      int c;
      switch (_sortKey) {
        case 'code':
          // Rows without a code sort to the end.
          if (a.code == null && b.code == null) {
            c = 0;
            break;
          }
          if (a.code == null) {
            c = 1;
            break;
          }
          if (b.code == null) {
            c = -1;
            break;
          }
          c = naturalCode(a.code!, b.code!);
        case 'name':
          c = (a.name ?? '').compareTo(b.name ?? '');
        case 'supplier':
          c = (a.supplier ?? '').compareTo(b.supplier ?? '');
        case 'brand':
          c = (a.brand ?? '').compareTo(b.brand ?? '');
        case 'stockStatus':
          c = a.stockStatus.compareTo(b.stockStatus);
        case 'category':
          c = a.category.compareTo(b.category);
        case 'subcategory':
          c = (a.subcategory ?? '').compareTo(b.subcategory ?? '');
        case 'room':
          c = (_roomDisplayForLocationId(a.locationId) ?? '').compareTo(
            _roomDisplayForLocationId(b.locationId) ?? '',
          );
        case 'location':
          c = (_locationDisplayForLocationId(a.locationId) ?? '').compareTo(
            _locationDisplayForLocationId(b.locationId) ?? '',
          );
        case 'storageTemp':
          c = (a.storageTemp ?? '').compareTo(b.storageTemp ?? '');
        case 'unit':
          c = (a.unit ?? '').compareTo(b.unit ?? '');
        case 'packageSize':
          c = (a.packageSize ?? -1.0).compareTo(b.packageSize ?? -1.0);
        case 'containerCount':
          c = (a.containerCount ?? -1).compareTo(b.containerCount ?? -1);
        case 'containerMin':
          c = (a.containerMin ?? -1).compareTo(b.containerMin ?? -1);
        case 'physicalState':
          c = (a.physicalState ?? '').compareTo(b.physicalState ?? '');
        case 'contamination':
          c = a.contamination.compareTo(b.contamination);
        case 'openedDate':
          c = (a.openedDate ?? DateTime(0)).compareTo(
            b.openedDate ?? DateTime(0),
          );
        case 'casNumber':
          c = (a.casNumber ?? '').compareTo(b.casNumber ?? '');
        case 'formula':
          c = (a.formula ?? '').compareTo(b.formula ?? '');
        case 'tags':
          c = (a.tags ?? '').compareTo(b.tags ?? '');
        default:
          c = (a.name ?? '').compareTo(b.name ?? '');
      }
      return _sortAsc ? c : -c;
    });

    setState(() => _filtered = result);
  }

  void _sort(String key) {
    setState(() {
      if (_sortKey == key) {
        _sortAsc = !_sortAsc;
      } else {
        _sortKey = key;
        _sortAsc = true;
      }
    });
    _applyFilters();
  }

  String _nextCode() {
    return ReagentCodeAllocator(_all.map((r) => r.code)).next();
  }

  void _enterSelectionMode() {
    if (!context.requireModuleAction(ModuleAction.delete)) return;
    _cancelEdit();
    setState(() {
      _selectionMode = true;
      _selectedIds.clear();
    });
  }

  void _exitSelectionMode() {
    setState(() {
      _selectionMode = false;
      _selectedIds.clear();
    });
  }

  void _toggleSelected(int id) {
    setState(() {
      if (!_selectedIds.add(id)) _selectedIds.remove(id);
    });
  }

  void _toggleAllVisible() {
    final visibleIds = _filtered.map((r) => r.id).toSet();
    setState(() {
      if (visibleIds.isNotEmpty && visibleIds.every(_selectedIds.contains)) {
        _selectedIds.removeAll(visibleIds);
      } else {
        _selectedIds.addAll(visibleIds);
      }
    });
  }

  bool? get _allVisibleSelectionState {
    if (_filtered.isEmpty) return false;
    final selectedVisible = _filtered.where((r) => _selectedIds.contains(r.id));
    if (selectedVisible.isEmpty) return false;
    if (selectedVisible.length == _filtered.length) return true;
    return null;
  }

  Future<void> _deleteSelected() async {
    if (_selectedIds.isEmpty || _deletingSelected) return;
    if (!context.requireModuleAction(ModuleAction.delete)) return;
    final ids = _selectedIds.toList()..sort();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: ctx.appSurface,
        title: Text(
          'Delete ${ids.length} reagents?',
          style: GoogleFonts.spaceGrotesk(color: ctx.appTextPrimary),
        ),
        content: Text(
          'The selected reagents will be permanently deleted. This cannot be undone.',
          style: GoogleFonts.spaceGrotesk(
            color: ctx.appTextSecondary,
            fontSize: 13,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton.icon(
            style: FilledButton.styleFrom(backgroundColor: AppDS.red),
            onPressed: () => Navigator.pop(ctx, true),
            icon: const Icon(Icons.delete_forever_outlined, size: 17),
            label: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _deletingSelected = true);
    try {
      final deletedRows = await Supabase.instance.client
          .from('reagents')
          .delete()
          .inFilter('reagent_id', ids)
          .select('reagent_id');
      final deletedCount = (deletedRows as List).length;
      if (deletedCount > 0) {
        await DataCache.clear('reagents');
        await BackupService.instance.notifyCrudChange('reagents');
      }
      if (!mounted) return;
      _selectionMode = false;
      _selectedIds.clear();
      await _load();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            deletedCount == ids.length
                ? '$deletedCount reagents deleted.'
                : '$deletedCount of ${ids.length} reagents deleted.',
          ),
        ),
      );
    } catch (e) {
      debugPrint('Bulk reagent delete error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Delete failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _deletingSelected = false);
    }
  }

  Widget _buildSelectionToolbar(BuildContext context) {
    return Row(
      children: [
        IconButton(
          tooltip: 'Cancel selection',
          onPressed: _deletingSelected ? null : _exitSelectionMode,
          icon: const Icon(Icons.close_rounded),
        ),
        const SizedBox(width: 4),
        Text(
          '${_selectedIds.length} selected',
          style: GoogleFonts.spaceGrotesk(
            color: context.appTextPrimary,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(width: 12),
        TextButton(
          onPressed: _deletingSelected ? null : _toggleAllVisible,
          child: Text(
            _allVisibleSelectionState == true
                ? 'Clear visible'
                : 'Select all visible',
          ),
        ),
        const Spacer(),
        FilledButton.icon(
          style: FilledButton.styleFrom(backgroundColor: AppDS.red),
          onPressed: _selectedIds.isEmpty || _deletingSelected
              ? null
              : _deleteSelected,
          icon: _deletingSelected
              ? const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.delete_outline, size: 17),
          label: Text('Delete (${_selectedIds.length})'),
        ),
      ],
    );
  }

  Future<void> _showAddEditDialog([ReagentModel? existing]) async {
    final action = existing == null ? ModuleAction.create : ModuleAction.edit;
    if (!context.requireModuleAction(action)) return;
    final locations = await _loadLocations();
    if (!mounted) return;
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => _ReagentFormDialog(
        existing: existing,
        locations: locations,
        nextCode: existing == null ? _nextCode() : null,
      ),
    );
    if (result == true) _load();
  }

  Future<List<Map<String, dynamic>>> _loadLocations() async {
    try {
      final rows = await Supabase.instance.client
          .from('storage_locations')
          .select(
            'location_id, location_name, location_type, '
            'location_code, location_parent_id, location_sort_order',
          )
          .order('location_name');
      return _orderLocationsHierarchically(
        List<Map<String, dynamic>>.from(rows),
      );
    } catch (e) {
      debugPrint('Reagents _loadLocations error: $e');
      return [];
    }
  }

  // Sorts locations into the same R1 / L1.1 / L1.2 / R2 / L2.1 order used by
  // the Locations page, and stamps each entry with a `_display` string
  // ("R1 — Lab A", "L1.1 — Freezer").
  List<Map<String, dynamic>> _orderLocationsHierarchically(
    List<Map<String, dynamic>> rows,
  ) {
    int cmp(Map a, Map b) {
      final ao = a['location_sort_order'] as num?;
      final bo = b['location_sort_order'] as num?;
      if (ao != null && bo != null) return ao.compareTo(bo);
      if (ao != null) return -1;
      if (bo != null) return 1;
      return (a['location_name'] as String).compareTo(
        b['location_name'] as String,
      );
    }

    final rooms =
        rows
            .where(
              (r) =>
                  (r['location_type'] as String?) == null ||
                  (r['location_type'] as String?) == 'room',
            )
            .toList()
          ..sort(cmp);
    final roomIds = {for (final r in rooms) (r['location_id'] as num).toInt()};
    final childrenByRoom = <int, List<Map<String, dynamic>>>{};
    final orphans = <Map<String, dynamic>>[];
    for (final r in rows) {
      if ((r['location_type'] as String?) == null ||
          (r['location_type'] as String?) == 'room') {
        continue;
      }
      final pid = r['location_parent_id'] != null
          ? (r['location_parent_id'] as num).toInt()
          : null;
      if (pid != null && roomIds.contains(pid)) {
        childrenByRoom.putIfAbsent(pid, () => []).add(r);
      } else {
        orphans.add(r);
      }
    }
    for (final list in childrenByRoom.values) {
      list.sort(cmp);
    }
    orphans.sort(cmp);

    final out = <Map<String, dynamic>>[];
    for (var i = 0; i < rooms.length; i++) {
      final room = rooms[i];
      final roomCode = room['location_code']?.toString() ?? 'R${i + 1}';
      out.add({...room, '_display': '$roomCode — ${room['location_name']}'});
      final kids =
          childrenByRoom[(room['location_id'] as num).toInt()] ?? const [];
      for (var j = 0; j < kids.length; j++) {
        out.add({
          ...kids[j],
          '_display':
              '${kids[j]['location_code'] ?? 'L${i + 1}.${j + 1}'} — ${kids[j]['location_name']}',
        });
      }
    }
    for (final o in orphans) {
      out.add({...o, '_display': o['location_name'] as String});
    }
    return out;
  }

  // ── Inline editing ──────────────────────────────────────────────────────────

  void _startEdit(int id, String key, String initial) {
    if (!context.canEditModule) {
      context.warnReadOnly();
      return;
    }
    _editFocus.unfocus();
    _editController.text = initial;
    _editController.selection = TextSelection(
      baseOffset: 0,
      extentOffset: initial.length,
    );
    setState(() => _editingCell = {'id': id, 'key': key});
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _editFocus.requestFocus();
    });
  }

  // Optimistic local patch — updates _all and _filtered immediately so the UI
  // reflects changes without waiting for a network round-trip.
  void _patchLocal(int id, Map<String, dynamic> dbPatch) {
    for (final list in [_all, _filtered]) {
      final i = list.indexWhere((r) => r.id == id);
      if (i < 0) continue;
      final old = list[i];
      list[i] = ReagentModel(
        id: old.id,
        code: dbPatch.containsKey('reagent_code')
            ? dbPatch['reagent_code'] as String?
            : old.code,
        stockStatus: dbPatch.containsKey('reagent_stock_status')
            ? ReagentModel.normalizeStockStatus(
                dbPatch['reagent_stock_status'] as String?,
              )
            : old.stockStatus,
        name: dbPatch.containsKey('reagent_name')
            ? dbPatch['reagent_name'] as String?
            : old.name,
        category: dbPatch.containsKey('reagent_category')
            ? dbPatch['reagent_category'] as String
            : old.category,
        subcategory: dbPatch.containsKey('reagent_subcategory')
            ? dbPatch['reagent_subcategory'] as String?
            : old.subcategory,
        brand: dbPatch.containsKey('reagent_brand')
            ? dbPatch['reagent_brand'] as String?
            : old.brand,
        reference: dbPatch.containsKey('reagent_reference')
            ? dbPatch['reagent_reference'] as String?
            : old.reference,
        casNumber: dbPatch.containsKey('reagent_cas_number')
            ? dbPatch['reagent_cas_number'] as String?
            : old.casNumber,
        synonyms: dbPatch.containsKey('reagent_synonyms')
            ? dbPatch['reagent_synonyms'] as String?
            : old.synonyms,
        unit: dbPatch.containsKey('reagent_unit')
            ? dbPatch['reagent_unit'] as String?
            : old.unit,
        packageSize: dbPatch.containsKey('reagent_package_size')
            ? (dbPatch['reagent_package_size'] as num?)?.toDouble()
            : old.packageSize,
        containerCount: dbPatch.containsKey('reagent_container_count')
            ? (dbPatch['reagent_container_count'] as num?)?.toInt()
            : old.containerCount,
        containerMin: dbPatch.containsKey('reagent_container_min')
            ? (dbPatch['reagent_container_min'] as num?)?.toInt()
            : old.containerMin,
        remainingAmount: dbPatch.containsKey('reagent_remaining_amount')
            ? (dbPatch['reagent_remaining_amount'] as num?)?.toDouble()
            : old.remainingAmount,
        concentration: dbPatch.containsKey('reagent_concentration')
            ? dbPatch['reagent_concentration'] as String?
            : old.concentration,
        storageTemp: dbPatch.containsKey('reagent_storage_temp')
            ? dbPatch['reagent_storage_temp'] as String?
            : old.storageTemp,
        locationId: dbPatch.containsKey('reagent_location_id')
            ? (dbPatch['reagent_location_id'] as num?)?.toInt()
            : old.locationId,
        locationName: dbPatch.containsKey('_location_name')
            ? dbPatch['_location_name'] as String?
            : old.locationName,
        position: dbPatch.containsKey('reagent_position')
            ? dbPatch['reagent_position'] as String?
            : old.position,
        lotNumber: dbPatch.containsKey('reagent_lot_number')
            ? dbPatch['reagent_lot_number'] as String?
            : old.lotNumber,
        priceEur: dbPatch.containsKey('reagent_price_eur')
            ? (dbPatch['reagent_price_eur'] as num?)?.toDouble()
            : old.priceEur,
        expiryDate: old.expiryDate,
        receivedDate: old.receivedDate,
        openedDate: dbPatch.containsKey('reagent_opened_date')
            ? DateTime.tryParse(
                dbPatch['reagent_opened_date']?.toString() ?? '',
              )
            : old.openedDate,
        supplier: dbPatch.containsKey('reagent_supplier')
            ? dbPatch['reagent_supplier'] as String?
            : old.supplier,
        hazard: dbPatch.containsKey('reagent_hazard')
            ? dbPatch['reagent_hazard'] as String?
            : old.hazard,
        responsible: dbPatch.containsKey('reagent_responsible')
            ? dbPatch['reagent_responsible'] as String?
            : old.responsible,
        formula: dbPatch.containsKey('reagent_formula')
            ? dbPatch['reagent_formula'] as String?
            : old.formula,
        physicalState: dbPatch.containsKey('reagent_physical_state')
            ? dbPatch['reagent_physical_state'] as String?
            : old.physicalState,
        contamination: dbPatch.containsKey('reagent_contamination')
            ? dbPatch['reagent_contamination'] as String
            : old.contamination,
        contaminationNotes: dbPatch.containsKey('reagent_contamination_notes')
            ? dbPatch['reagent_contamination_notes'] as String?
            : old.contaminationNotes,
        contaminationDate: dbPatch.containsKey('reagent_contamination_date')
            ? DateTime.tryParse(
                dbPatch['reagent_contamination_date']?.toString() ?? '',
              )
            : old.contaminationDate,
        notes: old.notes,
        tags: dbPatch.containsKey('reagent_tags')
            ? dbPatch['reagent_tags'] as String?
            : old.tags,
        qrcode: old.qrcode,
        createdAt: old.createdAt,
        updatedAt: old.updatedAt,
      );
    }
  }

  void _saveAndPatch(int id, Map<String, dynamic> dbPatch) {
    if (!context.requireModuleAction(ModuleAction.edit)) return;
    _patchLocal(id, dbPatch);
    setState(() {});
    final netPatch = Map<String, dynamic>.from(dbPatch)
      ..removeWhere((k, _) => k.startsWith('_'));
    Supabase.instance.client
        .from('reagents')
        .update({
          ...netPatch,
          'reagent_updated_at': DateTime.now().toUtc().toIso8601String(),
        })
        .eq('reagent_id', id)
        .then((_) {
          unawaited(BackupService.instance.notifyCrudChange('reagents'));
        })
        .catchError((e) {
          debugPrint('Reagent save error (id=$id, patch=$netPatch): $e');
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Save failed: $e'),
              backgroundColor: AppDS.red,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          );
          _load();
        });
  }

  void _commitCurrentEdit() {
    final cell = _editingCell;
    if (cell == null) return;
    final id = cell['id'] as int;
    final key = cell['key'] as String;
    final raw = _editController.text.trim();

    String? dbCol;
    dynamic dbVal;
    switch (key) {
      case 'name':
        dbCol = 'reagent_name';
        dbVal = raw.isEmpty ? null : raw;
      case 'code':
        dbCol = 'reagent_code';
        dbVal = raw.isEmpty ? null : raw;
      case 'supplier':
        dbCol = 'reagent_supplier';
        dbVal = raw.isEmpty ? null : raw;
      case 'brand':
        dbCol = 'reagent_brand';
        dbVal = raw.isEmpty ? null : raw;
      case 'reference':
        dbCol = 'reagent_reference';
        dbVal = raw.isEmpty ? null : raw;
      case 'concentration':
        dbCol = 'reagent_concentration';
        dbVal = raw.isEmpty ? null : raw;
      case 'unit':
        dbCol = 'reagent_unit';
        dbVal = raw.isEmpty ? null : raw;
      case 'packageSize':
        dbCol = 'reagent_package_size';
        dbVal = raw.isEmpty ? null : double.tryParse(raw);
      case 'containerCount':
        dbCol = 'reagent_container_count';
        dbVal = raw.isEmpty ? null : int.tryParse(raw);
      case 'containerMin':
        dbCol = 'reagent_container_min';
        dbVal = raw.isEmpty ? null : int.tryParse(raw);
      case 'remainingAmount':
        dbCol = 'reagent_remaining_amount';
        dbVal = raw.isEmpty ? null : double.tryParse(raw);
      case 'casNumber':
        dbCol = 'reagent_cas_number';
        dbVal = raw.isEmpty ? null : raw;
      case 'formula':
        dbCol = 'reagent_formula';
        dbVal = raw.isEmpty ? null : raw;
      case 'tags':
        dbCol = 'reagent_tags';
        dbVal = raw.isEmpty ? null : ReagentModel.joinTags(raw.split(';'));
      case 'subcategory':
        dbCol = 'reagent_subcategory';
        dbVal = raw.isEmpty ? null : raw;
      case 'category':
        dbCol = 'reagent_category';
        dbVal = raw;
      case 'openedDate':
        dbCol = 'reagent_opened_date';
        if (raw.isEmpty) {
          dbVal = null;
        } else {
          final d = DateTime.tryParse(raw);
          // Invalid input → null (erases the field).
          dbVal = d?.toIso8601String().substring(0, 10);
        }
      default:
        return;
    }

    _saveAndPatch(id, {dbCol: dbVal});
  }

  static const _dropdownCols = {
    'stockStatus',
    'category',
    'subcategory',
    'storageTemp',
    'physicalState',
    'contamination',
    'room',
    'location',
  };

  void _commitStockStatusEdit(int id, String value) {
    _saveAndPatch(id, {
      'reagent_stock_status': ReagentModel.normalizeStockStatus(value),
    });
  }

  void _commitCategoryEdit(int id, String value) {
    _saveAndPatch(id, {'reagent_category': value, 'reagent_subcategory': null});
  }

  void _commitSubcategoryEdit(int id, String value) {
    _saveAndPatch(id, {'reagent_subcategory': value});
  }

  void _commitPhysicalStateEdit(int id, String? value) {
    _saveAndPatch(id, {'reagent_physical_state': value});
  }

  void _commitStorageTempEdit(int id, String? value) {
    _saveAndPatch(id, {'reagent_storage_temp': value});
  }

  void _commitContaminationEdit(int id, String value) {
    _saveAndPatch(id, {'reagent_contamination': value});
  }

  void _commitLocationEdit(int id, int? locationId) {
    final locName = locationId != null
        ? (_locations.firstWhere(
                (l) => (l['location_id'] as num).toInt() == locationId,
                orElse: () => {'location_name': null},
              )['location_name']
              as String?)
        : null;
    _saveAndPatch(id, {
      'reagent_location_id': locationId,
      '_location_name': locName,
    });
  }

  void _commitRoomEdit(int id, int? roomId) {
    // Saving the room itself is intentional: it represents room-only storage.
    // A subsequent Location selection replaces it with the more specific child.
    _commitLocationEdit(id, roomId);
  }

  void _cancelEdit() {
    setState(() => _editingCell = null);
    _editFocus.unfocus();
  }

  void _advanceCell({bool forward = true}) {
    final cell = _editingCell;
    if (cell == null) return;

    final id = cell['id'] as int;
    final key = cell['key'] as String;
    final ci = _tabCols.indexOf(key);

    if (!_dropdownCols.contains(key)) _commitCurrentEdit();

    if (forward) {
      if (ci >= 0 && ci < _tabCols.length - 1) {
        final nextKey = _tabCols[ci + 1];
        final r = _filtered.firstWhere((r) => r.id == id);
        _startEdit(id, nextKey, _fieldValue(r, nextKey));
      } else {
        // Move to first col of next row
        final ri = _filtered.indexWhere((r) => r.id == id);
        if (ri >= 0 && ri < _filtered.length - 1) {
          final next = _filtered[ri + 1];
          _startEdit(next.id, _tabCols[0], _fieldValue(next, _tabCols[0]));
        } else {
          setState(() => _editingCell = null);
        }
      }
    } else {
      if (ci > 0) {
        final prevKey = _tabCols[ci - 1];
        final r = _filtered.firstWhere((r) => r.id == id);
        _startEdit(id, prevKey, _fieldValue(r, prevKey));
      } else {
        final ri = _filtered.indexWhere((r) => r.id == id);
        if (ri > 0) {
          final prev = _filtered[ri - 1];
          _startEdit(prev.id, _tabCols.last, _fieldValue(prev, _tabCols.last));
        } else {
          setState(() => _editingCell = null);
        }
      }
    }
  }

  String _fieldValue(ReagentModel r, String key) => switch (key) {
    'code' => r.code ?? '',
    'stockStatus' => r.stockStatus,
    'name' => r.name ?? '',
    'brand' => r.brand ?? '',
    'supplier' => r.supplier ?? '',
    'unit' => r.unit ?? '',
    'packageSize' => r.packageSize?.toString() ?? '',
    'containerCount' => r.containerCount?.toString() ?? '',
    'containerMin' => r.containerMin?.toString() ?? '',
    'casNumber' => r.casNumber ?? '',
    'formula' => r.formula ?? '',
    'tags' => r.tags ?? '',
    'subcategory' => r.subcategory ?? '',
    'category' => r.category,
    'contamination' => r.contamination,
    'storageTemp' => r.storageTemp ?? '',
    'physicalState' => r.physicalState ?? '',
    'openedDate' =>
      r.openedDate != null
          ? r.openedDate!.toIso8601String().substring(0, 10)
          : '',
    'room' => _roomDisplayForLocationId(r.locationId) ?? '',
    'location' => r.locationId?.toString() ?? '',
    _ => '',
  };

  Future<void> _addNewRow() async {
    if (!context.requireModuleAction(ModuleAction.create)) return;
    final code = _nextCode();
    try {
      final row = await Supabase.instance.client
          .from('reagents')
          .insert({
            'reagent_code': code,
            'reagent_category': 'chemical',
            'reagent_stock_status': 'in_stock',
            'reagent_contamination': 'none',
            'reagent_container_count': 1,
            'reagent_updated_at': DateTime.now().toUtc().toIso8601String(),
          })
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
      unawaited(BackupService.instance.notifyCrudChange('reagents'));
      if (!mounted) return;
      await _load();
      if (!mounted) return;
      // Defer the scroll until the ListView has rebuilt with the new row —
      // otherwise maxScrollExtent is still computed for the old item count.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || !_vertCtrl.hasClients) return;
        final ri = _filtered.indexWhere((r) => r.id == newId);
        if (ri < 0) return;
        final rowOffset = (ri + 1) * AppDS.tableRowH; // +1 for the add-row
        final viewport = _vertCtrl.position.viewportDimension;
        final max = _vertCtrl.position.maxScrollExtent;
        final target = (rowOffset - viewport / 2 + AppDS.tableRowH / 2).clamp(
          0.0,
          max,
        );
        _vertCtrl.animateTo(
          target,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOutCubic,
        );
      });
      _startEdit(newId, 'category', 'chemical');
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to add: $e'),
          backgroundColor: AppDS.red,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
    }
  }

  Widget _sortHdr(BuildContext context, String label, String key) {
    final active = _sortKey == key;
    return GestureDetector(
      onTap: () => _sort(key),
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: Row(
          children: [
            Text(
              label,
              style: GoogleFonts.spaceGrotesk(
                color: active ? AppDS.accent : context.appTextMuted,
                fontSize: 10,
                letterSpacing: 0.8,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(width: 2),
            Icon(
              active
                  ? (_sortAsc
                        ? Icons.arrow_upward_rounded
                        : Icons.arrow_downward_rounded)
                  : Icons.unfold_more_rounded,
              size: 11,
              color: active
                  ? AppDS.accent
                  : context.appTextMuted.withValues(alpha: 0.4),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _exportCsv() async {
    if (!context.requireModuleAction(ModuleAction.export)) return;
    final buf = StringBuffer();
    buf.writeln(
      'ID,Code,Stock Status,Name,Supplier,Brand,Reference,CAS,Synonyms,Category,Subcategory,'
      'PackageSize,Containers,ContainerMin,Remaining,Unit,Concentration,'
      'Contamination,Storage,Location,Lot,Expiry,Responsible',
    );
    for (final r in _filtered) {
      buf.writeln(
        '${r.id},"${r.code ?? ''}","${ReagentModel.stockStatusLabel(r.stockStatus)}","${r.name ?? ''}","${r.supplier ?? ''}","${r.brand ?? ''}","${r.reference ?? ''}","${r.casNumber ?? ''}","${r.synonyms ?? ''}","${r.category}","${r.subcategory ?? ''}","${r.packageSize ?? ''}","${r.containerCount ?? ''}","${r.containerMin ?? ''}","${r.remainingAmount ?? ''}","${r.unit ?? ''}","${r.concentration ?? ''}","${r.contamination}","${r.storageTemp ?? ''}","${r.locationName ?? ''}","${r.lotNumber ?? ''}","${r.expiryDate != null ? r.expiryDate!.toIso8601String().substring(0, 10) : ''}","${r.responsible ?? ''}"',
      );
    }
    try {
      final dir =
          await getDownloadsDirectory() ??
          await getApplicationDocumentsDirectory();
      final file = File(
        '${dir.path}/reagents_${DateTime.now().millisecondsSinceEpoch}.csv',
      );
      await file.writeAsString(buf.toString());
      await OpenFilex.open(file.path);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Export failed: $e')));
      }
    }
  }

  Widget _buildAddRow() {
    const accent = Color(0xFFF59E0B);
    final code = _nextCode();
    return InkWell(
      onTap: _addNewRow,
      child: Container(
        decoration: BoxDecoration(
          color: accent.withValues(alpha: 0.06),
          border: Border(
            bottom: BorderSide(color: accent.withValues(alpha: 0.25), width: 1),
          ),
        ),
        child: Row(
          children: [
            const SizedBox(
              width: _colBtn,
              child: Center(
                child: Icon(Icons.add_circle_outline, size: 16, color: accent),
              ),
            ),
            Text(
              code,
              style: GoogleFonts.jetBrainsMono(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: accent,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              '— click or Ctrl+Enter to add',
              style: GoogleFonts.spaceGrotesk(
                fontSize: 10,
                color: accent.withValues(alpha: 0.6),
              ),
            ),
          ],
        ),
      ),
    );
  }

  int get _expiredCount => _all.where((r) => r.isExpired).length;
  bool get _hasActiveFilter =>
      _categoryFilter != 'all' || _statusFilter != 'all';

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // ── Toolbar ──────────────────────────────────────────────────────────────
        Container(
          height: 56,
          decoration: BoxDecoration(
            color: context.appSurface2,
            border: Border(bottom: BorderSide(color: context.appBorder)),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: _selectionMode
              ? _buildSelectionToolbar(context)
              : Row(
            children: [
              if (MediaQuery.of(context).size.width < 700) ...[
                IconButton(
                  icon: const Icon(Icons.menu_rounded, size: 20),
                  color: context.appTextSecondary,
                  tooltip: 'Menu',
                  onPressed: () => Scaffold.of(context).openDrawer(),
                ),
              ],
              const Icon(
                Icons.water_drop_outlined,
                color: Color(0xFFF59E0B),
                size: 18,
              ),
              const SizedBox(width: 8),
              Text(
                'Reagents',
                style: GoogleFonts.spaceGrotesk(
                  color: context.appTextPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: SizedBox(
                  height: 36,
                  child: TextField(
                    controller: _searchCtrl,
                    onChanged: (v) {
                      _search = v;
                      _applyFilters();
                    },
                    style: GoogleFonts.spaceGrotesk(
                      color: context.appTextPrimary,
                      fontSize: 13,
                    ),
                    decoration: InputDecoration(
                      hintText: 'Search reagents...',
                      hintStyle: GoogleFonts.spaceGrotesk(
                        color: context.appTextMuted,
                        fontSize: 13,
                      ),
                      prefixIcon: Icon(
                        Icons.search,
                        color: context.appTextMuted,
                        size: 16,
                      ),
                      suffixIcon: _search.isNotEmpty
                          ? IconButton(
                              icon: Icon(
                                Icons.clear,
                                size: 14,
                                color: context.appTextMuted,
                              ),
                              onPressed: () {
                                _searchCtrl.clear();
                                _search = '';
                                _applyFilters();
                              },
                            )
                          : null,
                      filled: true,
                      fillColor: context.appSurface3,
                      contentPadding: EdgeInsets.zero,
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
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 4),
              Tooltip(
                message: _showFilters ? 'Hide filters' : 'Show filters',
                child: Stack(
                  children: [
                    IconButton(
                      icon: Icon(
                        Icons.tune,
                        color: _showFilters
                            ? AppDS.accent
                            : context.appTextSecondary,
                        size: 18,
                      ),
                      onPressed: () =>
                          setState(() => _showFilters = !_showFilters),
                    ),
                    if (_hasActiveFilter)
                      Positioned(
                        right: 6,
                        top: 6,
                        child: Container(
                          width: 7,
                          height: 7,
                          decoration: const BoxDecoration(
                            color: AppDS.accent,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              Tooltip(
                message: 'Import from Excel',
                child: IconButton(
                  icon: Icon(
                    Icons.upload_file_outlined,
                    color: context.appTextSecondary,
                    size: 18,
                  ),
                  onPressed: () async {
                    if (!context.requireModuleAction(ModuleAction.create)) {
                      return;
                    }
                    if (!context.requireModuleAction(ModuleAction.bulkUpdate)) {
                      return;
                    }
                    final imported = await Navigator.push<bool>(
                      context,
                      modulePageRoute(
                        context: context,
                        child: const ReagentExcelImportPage(),
                      ),
                    );
                    if (imported == true) _load();
                  },
                ),
              ),
              Tooltip(
                message: 'Export CSV',
                child: IconButton(
                  icon: Icon(
                    Icons.download_outlined,
                    color: context.appTextSecondary,
                    size: 18,
                  ),
                  onPressed: _exportCsv,
                ),
              ),
              Tooltip(
                message: 'Select reagents',
                child: IconButton(
                  icon: Icon(
                    Icons.checklist_rounded,
                    color: context.appTextSecondary,
                    size: 19,
                  ),
                  onPressed: _enterSelectionMode,
                ),
              ),
              const SizedBox(width: 4),
              FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFFF59E0B),
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 0,
                  ),
                  minimumSize: const Size(0, 36),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                onPressed: () => _showAddEditDialog(),
                icon: const Icon(Icons.add, size: 16),
                label: Text(
                  'Add',
                  style: GoogleFonts.spaceGrotesk(fontSize: 13),
                ),
              ),
            ],
          ),
        ),

        // ── Filter panel ─────────────────────────────────────────────────────────
        if (_showFilters)
          Container(
            decoration: BoxDecoration(
              color: context.appSurface,
              border: Border(bottom: BorderSide(color: context.appBorder)),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Text(
                      'Category',
                      style: GoogleFonts.spaceGrotesk(
                        color: context.appTextMuted,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          _FilterChip(
                            label: 'All',
                            selected: _categoryFilter == 'all',
                            onTap: () {
                              _categoryFilter = 'all';
                              _applyFilters();
                            },
                          ),
                          ...ReagentModel.categoryOptionsSorted.map(
                            (t) => _FilterChip(
                              label: ReagentModel.categoryLabel(t),
                              selected: _categoryFilter == t,
                              onTap: () {
                                _categoryFilter = t;
                                _applyFilters();
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Text(
                      'Status',
                      style: GoogleFonts.spaceGrotesk(
                        color: context.appTextMuted,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(width: 12),
                    _FilterChip(
                      label: 'All',
                      selected: _statusFilter == 'all',
                      onTap: () {
                        _statusFilter = 'all';
                        _applyFilters();
                      },
                    ),
                    const SizedBox(width: 6),
                    _FilterChip(
                      label:
                          'Expiring (${_all.where((r) => r.isExpiringSoon).length})',
                      selected: _statusFilter == 'expiring',
                      color: AppDS.yellow,
                      onTap: () {
                        _statusFilter = 'expiring';
                        _applyFilters();
                      },
                    ),
                    const SizedBox(width: 6),
                    _FilterChip(
                      label: 'Expired ($_expiredCount)',
                      selected: _statusFilter == 'expired',
                      color: AppDS.red,
                      onTap: () {
                        _statusFilter = 'expired';
                        _applyFilters();
                      },
                    ),
                    const SizedBox(width: 6),
                    _FilterChip(
                      label:
                          'Low Stock (${_all.where((r) => r.isLowStock).length})',
                      selected: _statusFilter == 'low',
                      color: AppDS.orange,
                      onTap: () {
                        _statusFilter = 'low';
                        _applyFilters();
                      },
                    ),
                    const SizedBox(width: 6),
                    _FilterChip(
                      label:
                          'Contaminated (${_all.where((r) => r.isContaminated).length})',
                      selected: _statusFilter == 'contaminated',
                      color: AppDS.purple,
                      onTap: () {
                        _statusFilter = 'contaminated';
                        _applyFilters();
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),

        // ── Expired alert banner ──────────────────────────────────────────────────
        if (_expiredCount > 0 && _statusFilter == 'all')
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: AppDS.red.withValues(alpha: 0.12),
            child: Row(
              children: [
                const Icon(
                  Icons.warning_amber_outlined,
                  color: AppDS.red,
                  size: 16,
                ),
                const SizedBox(width: 8),
                Text(
                  '$_expiredCount reagent${_expiredCount > 1 ? 's' : ''} expired — please review.',
                  style: GoogleFonts.spaceGrotesk(
                    color: AppDS.red,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),

        // ── Body ─────────────────────────────────────────────────────────────────
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _filtered.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.water_drop_outlined,
                        size: 48,
                        color: AppDS.textMuted,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'No reagents found',
                        style: GoogleFonts.spaceGrotesk(
                          color: AppDS.textMuted,
                          fontSize: 15,
                        ),
                      ),
                    ],
                  ),
                )
              : Padding(
                  padding: const EdgeInsets.fromLTRB(8, 8, 8, 4),
                  child: Column(
                    children: [
                      Expanded(
                        child: Row(
                          children: [
                            Expanded(
                              child: Container(
                                decoration: BoxDecoration(
                                  color: context.appSurface,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: context.appBorder),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withValues(
                                        alpha: 0.04,
                                      ),
                                      blurRadius: 8,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                clipBehavior: Clip.antiAlias,
                                child: NotificationListener<ScrollNotification>(
                                  onNotification: (n) {
                                    if (n is ScrollUpdateNotification) {
                                      if (n.metrics.axis == Axis.horizontal) {
                                        _hOffset.value = _horizCtrl.hasClients
                                            ? _horizCtrl.offset
                                            : 0.0;
                                      } else {
                                        _vOffset.value = _vertCtrl.hasClients
                                            ? _vertCtrl.offset
                                            : 0.0;
                                      }
                                    }
                                    return false;
                                  },
                                  child: SingleChildScrollView(
                                    controller: _horizCtrl,
                                    scrollDirection: Axis.horizontal,
                                    child: SizedBox(
                                      width: _tableW,
                                      child: Column(
                                        children: [
                                          // ── Header ─────────────────────────────
                                          Container(
                                            height: AppDS.tableHeaderH,
                                            color: context.appHeaderBg,
                                            child: Row(
                                              children: [
                                                SizedBox(
                                                  width: _colBtn,
                                                  child: _selectionMode
                                                      ? Checkbox(
                                                          tristate: true,
                                                          value:
                                                              _allVisibleSelectionState,
                                                          onChanged: (_) =>
                                                              _toggleAllVisible(),
                                                        )
                                                      : null,
                                                ),
                                                SizedBox(
                                                  width: _colCode,
                                                  child: Padding(
                                                    padding:
                                                        const EdgeInsets.symmetric(
                                                          horizontal: 6,
                                                        ),
                                                    child: _sortHdr(
                                                      context,
                                                      'CODE',
                                                      'code',
                                                    ),
                                                  ),
                                                ),
                                                SizedBox(
                                                  width: _colStock,
                                                  child: Padding(
                                                    padding:
                                                        const EdgeInsets.symmetric(
                                                          horizontal: 6,
                                                        ),
                                                    child: _sortHdr(
                                                      context,
                                                      'STOCK',
                                                      'stockStatus',
                                                    ),
                                                  ),
                                                ),
                                                SizedBox(
                                                  width: _colCategory,
                                                  child: Padding(
                                                    padding:
                                                        const EdgeInsets.symmetric(
                                                          horizontal: 6,
                                                        ),
                                                    child: _sortHdr(
                                                      context,
                                                      'CATEGORY',
                                                      'category',
                                                    ),
                                                  ),
                                                ),
                                                SizedBox(
                                                  width: _colSubcat,
                                                  child: Padding(
                                                    padding:
                                                        const EdgeInsets.symmetric(
                                                          horizontal: 6,
                                                        ),
                                                    child: _sortHdr(
                                                      context,
                                                      'SUBCAT',
                                                      'subcategory',
                                                    ),
                                                  ),
                                                ),
                                                SizedBox(
                                                  width: _colTags,
                                                  child: Padding(
                                                    padding:
                                                        const EdgeInsets.symmetric(
                                                          horizontal: 6,
                                                        ),
                                                    child: _sortHdr(
                                                      context,
                                                      'TAGS',
                                                      'tags',
                                                    ),
                                                  ),
                                                ),
                                                SizedBox(
                                                  width: _colName,
                                                  child: Padding(
                                                    padding:
                                                        const EdgeInsets.symmetric(
                                                          horizontal: 6,
                                                        ),
                                                    child: _sortHdr(
                                                      context,
                                                      'NAME',
                                                      'name',
                                                    ),
                                                  ),
                                                ),
                                                SizedBox(
                                                  width: _colRoom,
                                                  child: Padding(
                                                    padding:
                                                        const EdgeInsets.symmetric(
                                                          horizontal: 6,
                                                        ),
                                                    child: _sortHdr(
                                                      context,
                                                      'ROOM',
                                                      'room',
                                                    ),
                                                  ),
                                                ),
                                                SizedBox(
                                                  width: _colLoc,
                                                  child: Padding(
                                                    padding:
                                                        const EdgeInsets.symmetric(
                                                          horizontal: 6,
                                                        ),
                                                    child: _sortHdr(
                                                      context,
                                                      'LOCATION',
                                                      'location',
                                                    ),
                                                  ),
                                                ),
                                                SizedBox(
                                                  width: _colStorage,
                                                  child: Padding(
                                                    padding:
                                                        const EdgeInsets.symmetric(
                                                          horizontal: 6,
                                                        ),
                                                    child: _sortHdr(
                                                      context,
                                                      'TEMP',
                                                      'storageTemp',
                                                    ),
                                                  ),
                                                ),
                                                SizedBox(
                                                  width: _colState,
                                                  child: Padding(
                                                    padding:
                                                        const EdgeInsets.symmetric(
                                                          horizontal: 6,
                                                        ),
                                                    child: _sortHdr(
                                                      context,
                                                      'STATE',
                                                      'physicalState',
                                                    ),
                                                  ),
                                                ),
                                                SizedBox(
                                                  width: _colCas,
                                                  child: Padding(
                                                    padding:
                                                        const EdgeInsets.symmetric(
                                                          horizontal: 6,
                                                        ),
                                                    child: _sortHdr(
                                                      context,
                                                      'CAS',
                                                      'casNumber',
                                                    ),
                                                  ),
                                                ),
                                                SizedBox(
                                                  width: _colFormula,
                                                  child: Padding(
                                                    padding:
                                                        const EdgeInsets.symmetric(
                                                          horizontal: 6,
                                                        ),
                                                    child: _sortHdr(
                                                      context,
                                                      'FORMULA',
                                                      'formula',
                                                    ),
                                                  ),
                                                ),
                                                SizedBox(
                                                  width: _colOpened,
                                                  child: Padding(
                                                    padding:
                                                        const EdgeInsets.symmetric(
                                                          horizontal: 6,
                                                        ),
                                                    child: _sortHdr(
                                                      context,
                                                      'OPENED',
                                                      'openedDate',
                                                    ),
                                                  ),
                                                ),
                                                SizedBox(
                                                  width: _colPackSize,
                                                  child: Padding(
                                                    padding:
                                                        const EdgeInsets.symmetric(
                                                          horizontal: 6,
                                                        ),
                                                    child: _sortHdr(
                                                      context,
                                                      'SIZE',
                                                      'packageSize',
                                                    ),
                                                  ),
                                                ),
                                                SizedBox(
                                                  width: _colUnit,
                                                  child: Padding(
                                                    padding:
                                                        const EdgeInsets.symmetric(
                                                          horizontal: 6,
                                                        ),
                                                    child: _sortHdr(
                                                      context,
                                                      'UNIT',
                                                      'unit',
                                                    ),
                                                  ),
                                                ),
                                                SizedBox(
                                                  width: _colCount,
                                                  child: Padding(
                                                    padding:
                                                        const EdgeInsets.symmetric(
                                                          horizontal: 6,
                                                        ),
                                                    child: _sortHdr(
                                                      context,
                                                      'COUNT',
                                                      'containerCount',
                                                    ),
                                                  ),
                                                ),
                                                SizedBox(
                                                  width: _colMin,
                                                  child: Padding(
                                                    padding:
                                                        const EdgeInsets.symmetric(
                                                          horizontal: 6,
                                                        ),
                                                    child: _sortHdr(
                                                      context,
                                                      'MIN',
                                                      'containerMin',
                                                    ),
                                                  ),
                                                ),
                                                SizedBox(
                                                  width: _colContam,
                                                  child: Padding(
                                                    padding:
                                                        const EdgeInsets.symmetric(
                                                          horizontal: 6,
                                                        ),
                                                    child: _sortHdr(
                                                      context,
                                                      'CONTAM',
                                                      'contamination',
                                                    ),
                                                  ),
                                                ),
                                                SizedBox(
                                                  width: _colBrand,
                                                  child: Padding(
                                                    padding:
                                                        const EdgeInsets.symmetric(
                                                          horizontal: 6,
                                                        ),
                                                    child: _sortHdr(
                                                      context,
                                                      'BRAND',
                                                      'brand',
                                                    ),
                                                  ),
                                                ),
                                                SizedBox(
                                                  width: _colSupp,
                                                  child: Padding(
                                                    padding:
                                                        const EdgeInsets.symmetric(
                                                          horizontal: 6,
                                                        ),
                                                    child: _sortHdr(
                                                      context,
                                                      'SUPPLIER',
                                                      'supplier',
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                          Container(
                                            height: 1,
                                            color: context.appBorder,
                                          ),
                                          // ── Rows ───────────────────────────────
                                          Expanded(
                                            child: ListView.builder(
                                              controller: _vertCtrl,
                                              padding: EdgeInsets.zero,
                                              itemCount: _filtered.length +
                                                  (_selectionMode ? 0 : 1),
                                              itemExtent: AppDS.tableRowH,
                                              itemBuilder: (ctx, i) {
                                                if (!_selectionMode && i == 0) {
                                                  return _buildAddRow();
                                                }
                                                final rowIndex =
                                                    _selectionMode ? i : i - 1;
                                                final r = _filtered[rowIndex];
                                                return _ReagentRow(
                                                  reagent: r,
                                                  rowIndex: rowIndex,
                                                  selectionMode: _selectionMode,
                                                  selected: _selectedIds.contains(
                                                    r.id,
                                                  ),
                                                  onToggleSelected: () =>
                                                      _toggleSelected(r.id),
                                                  roomName:
                                                      _roomDisplayForLocationId(
                                                        r.locationId,
                                                      ),
                                                  onViewMore: () =>
                                                      Navigator.push(
                                                        context,
                                                        modulePageRoute(
                                                          context: context,
                                                          child:
                                                              ReagentDetailPage(
                                                                reagentId: r.id,
                                                              ),
                                                        ),
                                                      ).then((_) => _load()),
                                                  onRequest: () =>
                                                      showQuickRequestDialog(
                                                        context,
                                                        type: 'reagents',
                                                        prefillTitle:
                                                            r.name ?? '',
                                                      ),
                                                  editingCell: _editingCell,
                                                  editController:
                                                      _editController,
                                                  editFocus: _editFocus,
                                                  onStartEdit: _selectionMode
                                                      ? (_, _, _) {}
                                                      : _startEdit,
                                                  onAdvance: () =>
                                                      _advanceCell(),
                                                  onAdvanceBack: () =>
                                                      _advanceCell(
                                                        forward: false,
                                                      ),
                                                  onCancel: _cancelEdit,
                                                  onAddNewRow: () {
                                                    _commitCurrentEdit();
                                                    setState(
                                                      () => _editingCell = null,
                                                    );
                                                    _addNewRow();
                                                  },
                                                  onCommitStockStatus:
                                                      _commitStockStatusEdit,
                                                  onCommitCategory:
                                                      _commitCategoryEdit,
                                                  onCommitSubcategory:
                                                      _commitSubcategoryEdit,
                                                  onCommitStorageTemp:
                                                      _commitStorageTempEdit,
                                                  onCommitPhysicalState:
                                                      _commitPhysicalStateEdit,
                                                  onCommitContamination:
                                                      _commitContaminationEdit,
                                                  onCommitRoom: _commitRoomEdit,
                                                  onCommitLocation:
                                                      _commitLocationEdit,
                                                  locations: _locations,
                                                );
                                              },
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            // ── Vertical thumb ──────────────────────────────
                            AppVerticalThumb(
                              contentLength:
                                  (_filtered.length + 1) * AppDS.tableRowH,
                              topPadding: AppDS.tableHeaderH,
                              offset: _vOffset,
                              onScrollTo: (y) {
                                final max = _vertCtrl.hasClients
                                    ? _vertCtrl.position.maxScrollExtent
                                    : 0.0;
                                final clamped = y.clamp(0.0, max);
                                _vertCtrl.jumpTo(clamped);
                                _vOffset.value = clamped;
                              },
                            ),
                          ],
                        ),
                      ),
                      // ── Horizontal thumb ──────────────────────────────────
                      AppHorizontalThumb(
                        contentWidth: _tableW,
                        offset: _hOffset,
                        onScrollTo: (x) {
                          final max = _horizCtrl.hasClients
                              ? _horizCtrl.position.maxScrollExtent
                              : 0.0;
                          final clamped = x.clamp(0.0, max);
                          _horizCtrl.jumpTo(clamped);
                          _hOffset.value = clamped;
                        },
                      ),
                    ],
                  ),
                ),
        ),
      ],
    );
  }
}
