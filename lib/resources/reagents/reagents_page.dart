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
import 'reagent_detail_page.dart';
import 'reagent_excel_import_page.dart';
import '../../requests/requests_page.dart';

part 'reagents_widgets.dart';

// ── Column widths ─────────────────────────────────────────────────────────────
const _colBtn       = 60.0;
const _colCode      = 90.0;
const _colCategory  = 140.0;
const _colSubcat    = 130.0;
const _colName      = 190.0;
const _colState     = 80.0;
const _colFormula   = 130.0;
const _colOpened    = 100.0;
const _colLoc       = 130.0;
const _colPackSize  = 90.0;
const _colCount     = 70.0;
const _colMin       = 60.0;
const _colRemaining = 100.0;
const _colUnit      = 60.0;
const _colConc      = 100.0;
const _colContam    = 110.0;
const _colBrand     = 110.0;
const _colSupp      = 120.0;
const _colTags      = 160.0;
const _tableW = _colBtn + _colCode + _colCategory + _colSubcat + _colName +
    _colState + _colFormula + _colOpened + _colLoc + _colPackSize +
    _colCount + _colMin + _colRemaining + _colUnit + _colConc +
    _colContam + _colBrand + _colSupp + _colTags;

// Tab-navigable columns — matches visual column order left-to-right.
// 'category', 'subcategory', 'physicalState', 'contamination' are dropdowns;
// the rest are text fields.
const _tabCols = [
  'category', 'subcategory', 'tags', 'name', 'physicalState', 'formula',
  'packageSize', 'remainingAmount', 'unit', 'containerCount', 'containerMin',
  'concentration', 'contamination', 'brand', 'supplier',
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

  final _horizCtrl = ScrollController();
  final _vertCtrl  = ScrollController();
  final _hOffset   = ValueNotifier<double>(0);
  final _vOffset   = ValueNotifier<double>(0);

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
        final locName = locData is Map ? locData['location_name'] as String? : null;
        return ReagentModel.fromMap(
            {...Map<String, dynamic>.from(r), 'location_name': locName});
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
      if (cached == null && mounted) {
        setState(() => _loading = false);
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Failed to load: $e')));
      }
    }
    _locations = await _loadLocations();
  }

  void _applyFilters() {
    final q = _search.toLowerCase();
    var result = _all.where((r) {
      if (_categoryFilter != 'all' && r.category != _categoryFilter) return false;
      if (_statusFilter == 'expired' && !r.isExpired) return false;
      if (_statusFilter == 'expiring' && !r.isExpiringSoon) return false;
      if (_statusFilter == 'low' && !r.isLowStock) return false;
      if (_statusFilter == 'contaminated' && !r.isContaminated) return false;
      if (q.isEmpty) return true;
      return (r.name?.toLowerCase().contains(q) ?? false) ||
          (r.code?.toLowerCase().contains(q) ?? false) ||
          (r.brand?.toLowerCase().contains(q) ?? false) ||
          (r.reference?.toLowerCase().contains(q) ?? false) ||
          (r.casNumber?.toLowerCase().contains(q) ?? false) ||
          (r.subcategory?.toLowerCase().contains(q) ?? false) ||
          (r.supplier?.toLowerCase().contains(q) ?? false);
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
          if (a.code == null && b.code == null) { c = 0; break; }
          if (a.code == null) { c = 1; break; }
          if (b.code == null) { c = -1; break; }
          c = naturalCode(a.code!, b.code!);
        case 'name':            c = (a.name ?? '').compareTo(b.name ?? '');
        case 'supplier':        c = (a.supplier ?? '').compareTo(b.supplier ?? '');
        case 'brand':           c = (a.brand ?? '').compareTo(b.brand ?? '');
        case 'category':        c = a.category.compareTo(b.category);
        case 'subcategory':     c = (a.subcategory ?? '').compareTo(b.subcategory ?? '');
        case 'location':        c = (a.locationName ?? '').compareTo(b.locationName ?? '');
        case 'concentration':   c = (a.concentration ?? '').compareTo(b.concentration ?? '');
        case 'unit':            c = (a.unit ?? '').compareTo(b.unit ?? '');
        case 'packageSize':     c = (a.packageSize ?? -1.0).compareTo(b.packageSize ?? -1.0);
        case 'containerCount':  c = (a.containerCount ?? -1).compareTo(b.containerCount ?? -1);
        case 'containerMin':    c = (a.containerMin ?? -1).compareTo(b.containerMin ?? -1);
        case 'remainingAmount': c = (a.remainingAmount ?? -1.0).compareTo(b.remainingAmount ?? -1.0);
        case 'physicalState':   c = (a.physicalState ?? '').compareTo(b.physicalState ?? '');
        case 'contamination':   c = a.contamination.compareTo(b.contamination);
        case 'openedDate':      c = (a.openedDate ?? DateTime(0)).compareTo(b.openedDate ?? DateTime(0));
        case 'formula':         c = (a.formula ?? '').compareTo(b.formula ?? '');
        case 'tags':            c = (a.tags ?? '').compareTo(b.tags ?? '');
        default:                c = (a.name ?? '').compareTo(b.name ?? '');
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
    final re = RegExp(r'^BR(\d+)$', caseSensitive: false);
    int highest = 0;
    for (final r in _all) {
      final m = re.firstMatch(r.code ?? '');
      if (m != null) {
        final n = int.tryParse(m.group(1)!) ?? 0;
        if (n > highest) highest = n;
      }
    }
    return 'BR${(highest + 1).toString().padLeft(4, '0')}';
  }

  Future<void> _showAddEditDialog([ReagentModel? existing]) async {
    if (!context.canEditModule) { context.warnReadOnly(); return; }
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
          .select('location_id, location_name')
          .order('location_name');
      return List<Map<String, dynamic>>.from(rows);
    } catch (_) {
      return [];
    }
  }

  // ── Inline editing ──────────────────────────────────────────────────────────

  void _startEdit(int id, String key, String initial) {
    if (!context.canEditModule) { context.warnReadOnly(); return; }
    _editFocus.unfocus();
    _editController.text = initial;
    _editController.selection =
        TextSelection(baseOffset: 0, extentOffset: initial.length);
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
        code:             dbPatch.containsKey('reagent_code')              ? dbPatch['reagent_code'] as String?              : old.code,
        name:             dbPatch.containsKey('reagent_name')              ? dbPatch['reagent_name'] as String?              : old.name,
        category:         dbPatch.containsKey('reagent_category')          ? dbPatch['reagent_category'] as String           : old.category,
        subcategory:      dbPatch.containsKey('reagent_subcategory')       ? dbPatch['reagent_subcategory'] as String?       : old.subcategory,
        brand:            dbPatch.containsKey('reagent_brand')             ? dbPatch['reagent_brand'] as String?             : old.brand,
        reference:        dbPatch.containsKey('reagent_reference')         ? dbPatch['reagent_reference'] as String?         : old.reference,
        casNumber:        dbPatch.containsKey('reagent_cas_number')        ? dbPatch['reagent_cas_number'] as String?        : old.casNumber,
        unit:             dbPatch.containsKey('reagent_unit')              ? dbPatch['reagent_unit'] as String?              : old.unit,
        packageSize:      dbPatch.containsKey('reagent_package_size')      ? (dbPatch['reagent_package_size'] as num?)?.toDouble()      : old.packageSize,
        containerCount:   dbPatch.containsKey('reagent_container_count')   ? (dbPatch['reagent_container_count'] as num?)?.toInt()      : old.containerCount,
        containerMin:     dbPatch.containsKey('reagent_container_min')     ? (dbPatch['reagent_container_min'] as num?)?.toInt()        : old.containerMin,
        remainingAmount:  dbPatch.containsKey('reagent_remaining_amount')  ? (dbPatch['reagent_remaining_amount'] as num?)?.toDouble()  : old.remainingAmount,
        concentration:    dbPatch.containsKey('reagent_concentration')     ? dbPatch['reagent_concentration'] as String?     : old.concentration,
        storageTemp:      dbPatch.containsKey('reagent_storage_temp')      ? dbPatch['reagent_storage_temp'] as String?      : old.storageTemp,
        locationId:       dbPatch.containsKey('reagent_location_id')       ? (dbPatch['reagent_location_id'] as num?)?.toInt() : old.locationId,
        locationName:     dbPatch.containsKey('_location_name')            ? dbPatch['_location_name'] as String?            : old.locationName,
        position:         dbPatch.containsKey('reagent_position')          ? dbPatch['reagent_position'] as String?          : old.position,
        lotNumber:        dbPatch.containsKey('reagent_lot_number')        ? dbPatch['reagent_lot_number'] as String?        : old.lotNumber,
        expiryDate:       old.expiryDate,
        receivedDate:     old.receivedDate,
        openedDate:       dbPatch.containsKey('reagent_opened_date')       ? DateTime.tryParse(dbPatch['reagent_opened_date']?.toString() ?? '') : old.openedDate,
        supplier:         dbPatch.containsKey('reagent_supplier')          ? dbPatch['reagent_supplier'] as String?          : old.supplier,
        hazard:           dbPatch.containsKey('reagent_hazard')            ? dbPatch['reagent_hazard'] as String?            : old.hazard,
        responsible:      dbPatch.containsKey('reagent_responsible')       ? dbPatch['reagent_responsible'] as String?       : old.responsible,
        formula:          dbPatch.containsKey('reagent_formula')           ? dbPatch['reagent_formula'] as String?           : old.formula,
        physicalState:    dbPatch.containsKey('reagent_physical_state')    ? dbPatch['reagent_physical_state'] as String?    : old.physicalState,
        contamination:    dbPatch.containsKey('reagent_contamination')     ? dbPatch['reagent_contamination'] as String      : old.contamination,
        contaminationNotes: dbPatch.containsKey('reagent_contamination_notes') ? dbPatch['reagent_contamination_notes'] as String? : old.contaminationNotes,
        contaminationDate:  dbPatch.containsKey('reagent_contamination_date')  ? DateTime.tryParse(dbPatch['reagent_contamination_date']?.toString() ?? '') : old.contaminationDate,
        notes:            old.notes,
        qrcode:           old.qrcode,
        createdAt:        old.createdAt,
        updatedAt:        old.updatedAt,
      );
    }
  }

  void _saveAndPatch(int id, Map<String, dynamic> dbPatch) {
    _patchLocal(id, dbPatch);
    setState(() {});
    final netPatch = Map<String, dynamic>.from(dbPatch)
      ..removeWhere((k, _) => k.startsWith('_'));
    Supabase.instance.client
        .from('reagents')
        .update({...netPatch, 'reagent_updated_at': DateTime.now().toUtc().toIso8601String()})
        .eq('reagent_id', id)
        .then((_) { unawaited(BackupService.instance.notifyCrudChange('reagents')); })
        .catchError((_) { if (mounted) _load(); });
  }

  void _commitCurrentEdit() {
    final cell = _editingCell;
    if (cell == null) return;
    final id  = cell['id'] as int;
    final key = cell['key'] as String;
    final raw = _editController.text.trim();

    String? dbCol;
    dynamic dbVal;
    switch (key) {
      case 'name':            dbCol = 'reagent_name';             dbVal = raw.isEmpty ? null : raw;
      case 'code':            dbCol = 'reagent_code';             dbVal = raw.isEmpty ? null : raw;
      case 'supplier':        dbCol = 'reagent_supplier';         dbVal = raw.isEmpty ? null : raw;
      case 'brand':           dbCol = 'reagent_brand';            dbVal = raw.isEmpty ? null : raw;
      case 'reference':       dbCol = 'reagent_reference';        dbVal = raw.isEmpty ? null : raw;
      case 'concentration':   dbCol = 'reagent_concentration';    dbVal = raw.isEmpty ? null : raw;
      case 'unit':            dbCol = 'reagent_unit';             dbVal = raw.isEmpty ? null : raw;
      case 'packageSize':     dbCol = 'reagent_package_size';     dbVal = raw.isEmpty ? null : double.tryParse(raw);
      case 'containerCount':  dbCol = 'reagent_container_count';  dbVal = raw.isEmpty ? null : int.tryParse(raw);
      case 'containerMin':    dbCol = 'reagent_container_min';    dbVal = raw.isEmpty ? null : int.tryParse(raw);
      case 'remainingAmount': dbCol = 'reagent_remaining_amount'; dbVal = raw.isEmpty ? null : double.tryParse(raw);
      case 'formula':         dbCol = 'reagent_formula';          dbVal = raw.isEmpty ? null : raw;
      case 'tags':            dbCol = 'reagent_tags';             dbVal = raw.isEmpty
                                ? null
                                : ReagentModel.joinTags(raw.split(';'));
      case 'subcategory':     dbCol = 'reagent_subcategory';      dbVal = raw.isEmpty ? null : raw;
      case 'category':        dbCol = 'reagent_category';         dbVal = raw;
      default: return;
    }

    _saveAndPatch(id, {dbCol: dbVal});
  }

  static const _dropdownCols = {'category', 'subcategory', 'physicalState', 'contamination'};

  void _commitCategoryEdit(int id, String value) {
    _saveAndPatch(id, {'reagent_category': value, 'reagent_subcategory': null});
    _advanceFromDropdown(id);
  }

  void _commitSubcategoryEdit(int id, String value) {
    _saveAndPatch(id, {'reagent_subcategory': value});
    _advanceFromDropdown(id);
  }

  void _commitPhysicalStateEdit(int id, String? value) {
    _saveAndPatch(id, {'reagent_physical_state': value});
    _advanceFromDropdown(id);
  }

  void _commitContaminationEdit(int id, String value) {
    _saveAndPatch(id, {'reagent_contamination': value});
    _advanceFromDropdown(id);
  }

  void _commitLocationEdit(int id, int? locationId) {
    final locName = locationId != null
        ? (_locations.firstWhere(
            (l) => (l['location_id'] as num).toInt() == locationId,
            orElse: () => {'location_name': null},
          )['location_name'] as String?)
        : null;
    _saveAndPatch(id, {'reagent_location_id': locationId, '_location_name': locName});
    // Remove the internal-only key before sending to DB
    setState(() => _editingCell = null);
  }

  void _advanceFromDropdown(int id) {
    final cell = _editingCell;
    if (cell == null) return;
    final key = cell['key'] as String;
    final ci = _tabCols.indexOf(key);
    if (ci >= 0 && ci < _tabCols.length - 1) {
      final nextKey = _tabCols[ci + 1];
      final r = _filtered.firstWhere((r) => r.id == id);
      _startEdit(id, nextKey, _fieldValue(r, nextKey));
    } else {
      setState(() => _editingCell = null);
    }
  }

  Future<void> _pickOpenedDate(int id, DateTime? current) async {
    if (!context.canEditModule) { context.warnReadOnly(); return; }
    final picked = await showDatePicker(
      context: context,
      initialDate: current ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked == null || !mounted) return;
    final ds = picked.toIso8601String().substring(0, 10);
    _saveAndPatch(id, {'reagent_opened_date': ds});
  }

  void _cancelEdit() {
    setState(() => _editingCell = null);
    _editFocus.unfocus();
  }

  void _advanceCell({bool forward = true}) {
    final cell = _editingCell;
    if (cell == null) return;

    final id  = cell['id'] as int;
    final key = cell['key'] as String;
    final ci  = _tabCols.indexOf(key);

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
    'code'             => r.code ?? '',
    'name'             => r.name ?? '',
    'brand'            => r.brand ?? '',
    'supplier'         => r.supplier ?? '',
    'concentration'    => r.concentration ?? '',
    'unit'             => r.unit ?? '',
    'packageSize'      => r.packageSize?.toString() ?? '',
    'containerCount'   => r.containerCount?.toString() ?? '',
    'containerMin'     => r.containerMin?.toString() ?? '',
    'remainingAmount'  => r.remainingAmount?.toString() ?? '',
    'formula'          => r.formula ?? '',
    'tags'             => r.tags ?? '',
    'subcategory'      => r.subcategory ?? '',
    'category'         => r.category,
    'contamination'    => r.contamination,
    _                  => '',
  };

  Future<void> _addNewRow() async {
    if (!context.canEditModule) { context.warnReadOnly(); return; }
    final code = _nextCode();
    try {
      final row = await Supabase.instance.client
          .from('reagents')
          .insert({
            'reagent_code': code,
            'reagent_category': 'chemical',
            'reagent_contamination': 'none',
            'reagent_container_count': 1,
            'reagent_updated_at': DateTime.now().toUtc().toIso8601String(),
          })
          .select('reagent_id')
          .single();
      final newId = row['reagent_id'] as int;
      await Supabase.instance.client
          .from('reagents')
          .update({'reagent_qrcode': QrRules.build(
              SupabaseManager.projectRef ?? 'local', 'reagents', newId)})
          .eq('reagent_id', newId);
      unawaited(BackupService.instance.notifyCrudChange('reagents'));
      if (!mounted) return;
      await _load();
      if (!mounted) return;
      // Scroll to the new row and start editing
      final ri = _filtered.indexWhere((r) => r.id == newId);
      if (ri >= 0 && _vertCtrl.hasClients) {
        final target = (ri + 1) * AppDS.tableRowH; // +1 for the add-row at index 0
        _vertCtrl.jumpTo(target.clamp(0.0, _vertCtrl.position.maxScrollExtent));
      }
      _startEdit(newId, 'category', 'chemical');
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Failed to add: $e'),
        backgroundColor: AppDS.red,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ));
    }
  }

  Widget _sortHdr(BuildContext context, String label, String key) {
    final active = _sortKey == key;
    return GestureDetector(
      onTap: () => _sort(key),
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: Row(children: [
          Text(label,
              style: GoogleFonts.spaceGrotesk(
                  color: active ? AppDS.accent : context.appTextMuted,
                  fontSize: 10,
                  letterSpacing: 0.8,
                  fontWeight: FontWeight.w600)),
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
        ]),
      ),
    );
  }

  Future<void> _exportCsv() async {
    final buf = StringBuffer();
    buf.writeln(
        'ID,Code,Name,Supplier,Brand,Reference,CAS,Category,Subcategory,'
        'PackageSize,Containers,ContainerMin,Remaining,Unit,Concentration,'
        'Contamination,Storage,Location,Lot,Expiry,Responsible');
    for (final r in _filtered) {
      buf.writeln(
          '${r.id},"${r.code ?? ''}","${r.name ?? ''}","${r.supplier ?? ''}","${r.brand ?? ''}","${r.reference ?? ''}","${r.casNumber ?? ''}","${r.category}","${r.subcategory ?? ''}","${r.packageSize ?? ''}","${r.containerCount ?? ''}","${r.containerMin ?? ''}","${r.remainingAmount ?? ''}","${r.unit ?? ''}","${r.concentration ?? ''}","${r.contamination}","${r.storageTemp ?? ''}","${r.locationName ?? ''}","${r.lotNumber ?? ''}","${r.expiryDate != null ? r.expiryDate!.toIso8601String().substring(0, 10) : ''}","${r.responsible ?? ''}"');
    }
    try {
      final dir = await getDownloadsDirectory() ?? await getApplicationDocumentsDirectory();
      final file =
          File('${dir.path}/reagents_${DateTime.now().millisecondsSinceEpoch}.csv');
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
          border: Border(bottom: BorderSide(
              color: accent.withValues(alpha: 0.25), width: 1)),
        ),
        child: Row(children: [
          const SizedBox(
            width: _colBtn,
            child: Center(
              child: Icon(Icons.add_circle_outline, size: 16, color: accent),
            ),
          ),
          Text(code,
              style: GoogleFonts.jetBrainsMono(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: accent)),
          const SizedBox(width: 8),
          Text('— click or Ctrl+Enter to add',
              style: GoogleFonts.spaceGrotesk(
                  fontSize: 10, color: accent.withValues(alpha: 0.6))),
        ]),
      ),
    );
  }

  int get _expiredCount => _all.where((r) => r.isExpired).length;
  bool get _hasActiveFilter => _categoryFilter != 'all' || _statusFilter != 'all';

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      // ── Toolbar ──────────────────────────────────────────────────────────────
      Container(
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
          const Icon(Icons.water_drop_outlined,
              color: Color(0xFFF59E0B), size: 18),
          const SizedBox(width: 8),
          Text('Reagents',
              style: GoogleFonts.spaceGrotesk(
                  color: context.appTextPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.w600)),
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
                    color: context.appTextPrimary, fontSize: 13),
                decoration: InputDecoration(
                  hintText: 'Search reagents...',
                  hintStyle: GoogleFonts.spaceGrotesk(
                      color: context.appTextMuted, fontSize: 13),
                  prefixIcon: Icon(Icons.search,
                      color: context.appTextMuted, size: 16),
                  suffixIcon: _search.isNotEmpty
                      ? IconButton(
                          icon: Icon(Icons.clear,
                              size: 14, color: context.appTextMuted),
                          onPressed: () {
                            _searchCtrl.clear();
                            _search = '';
                            _applyFilters();
                          })
                      : null,
                  filled: true,
                  fillColor: context.appSurface3,
                  contentPadding: EdgeInsets.zero,
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: context.appBorder)),
                  enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: context.appBorder)),
                  focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: AppDS.accent)),
                ),
              ),
            ),
          ),
          const SizedBox(width: 4),
          Tooltip(
            message: _showFilters ? 'Hide filters' : 'Show filters',
            child: Stack(children: [
              IconButton(
                icon: Icon(Icons.tune,
                    color: _showFilters
                        ? AppDS.accent
                        : context.appTextSecondary,
                    size: 18),
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
                        color: AppDS.accent, shape: BoxShape.circle),
                  ),
                ),
            ]),
          ),
          Tooltip(
            message: 'Import from Excel',
            child: IconButton(
              icon: Icon(Icons.upload_file_outlined,
                  color: context.appTextSecondary, size: 18),
              onPressed: () async {
                if (!context.canEditModule) { context.warnReadOnly(); return; }
                final imported = await Navigator.push<bool>(
                  context,
                  MaterialPageRoute(
                      builder: (_) => const ReagentExcelImportPage()),
                );
                if (imported == true) _load();
              },
            ),
          ),
          Tooltip(
            message: 'Export CSV',
            child: IconButton(
              icon: Icon(Icons.download_outlined,
                  color: context.appTextSecondary, size: 18),
              onPressed: _exportCsv,
            ),
          ),
          const SizedBox(width: 4),
          FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFF59E0B),
              foregroundColor: Colors.black,
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
              minimumSize: const Size(0, 36),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () => _showAddEditDialog(),
            icon: const Icon(Icons.add, size: 16),
            label: Text('Add',
                style: GoogleFonts.spaceGrotesk(fontSize: 13)),
          ),
        ]),
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
              Row(children: [
                Text('Category',
                    style: GoogleFonts.spaceGrotesk(
                        color: context.appTextMuted,
                        fontSize: 11,
                        fontWeight: FontWeight.w600)),
                const SizedBox(width: 12),
                Expanded(
                  child: Wrap(spacing: 6, runSpacing: 6, children: [
                    _FilterChip(
                      label: 'All',
                      selected: _categoryFilter == 'all',
                      onTap: () { _categoryFilter = 'all'; _applyFilters(); },
                    ),
                    ...ReagentModel.categoryOptions.map((t) => _FilterChip(
                          label: ReagentModel.categoryLabel(t),
                          selected: _categoryFilter == t,
                          onTap: () { _categoryFilter = t; _applyFilters(); },
                        )),
                  ]),
                ),
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
                  selected: _statusFilter == 'all',
                  onTap: () { _statusFilter = 'all'; _applyFilters(); },
                ),
                const SizedBox(width: 6),
                _FilterChip(
                  label:
                      'Expiring (${_all.where((r) => r.isExpiringSoon).length})',
                  selected: _statusFilter == 'expiring',
                  color: AppDS.yellow,
                  onTap: () { _statusFilter = 'expiring'; _applyFilters(); },
                ),
                const SizedBox(width: 6),
                _FilterChip(
                  label: 'Expired ($_expiredCount)',
                  selected: _statusFilter == 'expired',
                  color: AppDS.red,
                  onTap: () { _statusFilter = 'expired'; _applyFilters(); },
                ),
                const SizedBox(width: 6),
                _FilterChip(
                  label:
                      'Low Stock (${_all.where((r) => r.isLowStock).length})',
                  selected: _statusFilter == 'low',
                  color: AppDS.orange,
                  onTap: () { _statusFilter = 'low'; _applyFilters(); },
                ),
                const SizedBox(width: 6),
                _FilterChip(
                  label:
                      'Contaminated (${_all.where((r) => r.isContaminated).length})',
                  selected: _statusFilter == 'contaminated',
                  color: AppDS.purple,
                  onTap: () { _statusFilter = 'contaminated'; _applyFilters(); },
                ),
              ]),
            ],
          ),
        ),

      // ── Expired alert banner ──────────────────────────────────────────────────
      if (_expiredCount > 0 && _statusFilter == 'all')
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          color: AppDS.red.withValues(alpha: 0.12),
          child: Row(children: [
            const Icon(Icons.warning_amber_outlined,
                color: AppDS.red, size: 16),
            const SizedBox(width: 8),
            Text(
              '$_expiredCount reagent${_expiredCount > 1 ? 's' : ''} expired — please review.',
              style:
                  GoogleFonts.spaceGrotesk(color: AppDS.red, fontSize: 12),
            ),
          ]),
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
                        const Icon(Icons.water_drop_outlined,
                            size: 48, color: AppDS.textMuted),
                        const SizedBox(height: 12),
                        Text('No reagents found',
                            style: GoogleFonts.spaceGrotesk(
                                color: AppDS.textMuted, fontSize: 15)),
                      ],
                    ),
                  )
                : Padding(
                  padding: const EdgeInsets.fromLTRB(8, 8, 8, 4),
                  child: Column(children: [
                    Expanded(
                      child: Row(children: [
                        Expanded(
                          child: Container(
                            decoration: BoxDecoration(
                              color: context.appSurface,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: context.appBorder),
                              boxShadow: [BoxShadow(
                                color: Colors.black.withValues(alpha: 0.04),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              )],
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
                                child: Column(children: [
                                  // ── Header ─────────────────────────────
                                  Container(
                                    height: AppDS.tableHeaderH,
                                    color: context.appHeaderBg,
                                    child: Row(children: [
                                      const SizedBox(width: _colBtn),
                                      SizedBox(width: _colCode,      child: Padding(padding: const EdgeInsets.symmetric(horizontal: 6), child: _sortHdr(context, 'CODE',      'code'))),
                                      SizedBox(width: _colCategory,  child: Padding(padding: const EdgeInsets.symmetric(horizontal: 6), child: _sortHdr(context, 'CATEGORY',  'category'))),
                                      SizedBox(width: _colSubcat,    child: Padding(padding: const EdgeInsets.symmetric(horizontal: 6), child: _sortHdr(context, 'SUBCAT',    'subcategory'))),
                                      SizedBox(width: _colTags,      child: Padding(padding: const EdgeInsets.symmetric(horizontal: 6), child: _sortHdr(context, 'TAGS',      'tags'))),
                                      SizedBox(width: _colName,      child: Padding(padding: const EdgeInsets.symmetric(horizontal: 6), child: _sortHdr(context, 'NAME',      'name'))),
                                      SizedBox(width: _colState,     child: Padding(padding: const EdgeInsets.symmetric(horizontal: 6), child: _sortHdr(context, 'STATE',     'physicalState'))),
                                      SizedBox(width: _colFormula,   child: Padding(padding: const EdgeInsets.symmetric(horizontal: 6), child: _sortHdr(context, 'FORMULA',   'formula'))),
                                      SizedBox(width: _colOpened,    child: Padding(padding: const EdgeInsets.symmetric(horizontal: 6), child: _sortHdr(context, 'OPENED',    'openedDate'))),
                                      SizedBox(width: _colLoc,       child: Padding(padding: const EdgeInsets.symmetric(horizontal: 6), child: _sortHdr(context, 'LOCATION',  'location'))),
                                      SizedBox(width: _colPackSize,  child: Padding(padding: const EdgeInsets.symmetric(horizontal: 6), child: _sortHdr(context, 'SIZE',      'packageSize'))),
                                      SizedBox(width: _colRemaining, child: Padding(padding: const EdgeInsets.symmetric(horizontal: 6), child: _sortHdr(context, 'REMAINING', 'remainingAmount'))),
                                      SizedBox(width: _colUnit,      child: Padding(padding: const EdgeInsets.symmetric(horizontal: 6), child: _sortHdr(context, 'UNIT',      'unit'))),
                                      SizedBox(width: _colCount,     child: Padding(padding: const EdgeInsets.symmetric(horizontal: 6), child: _sortHdr(context, 'COUNT',     'containerCount'))),
                                      SizedBox(width: _colMin,       child: Padding(padding: const EdgeInsets.symmetric(horizontal: 6), child: _sortHdr(context, 'MIN',       'containerMin'))),
                                      SizedBox(width: _colConc,      child: Padding(padding: const EdgeInsets.symmetric(horizontal: 6), child: _sortHdr(context, 'CONC.',     'concentration'))),
                                      SizedBox(width: _colContam,    child: Padding(padding: const EdgeInsets.symmetric(horizontal: 6), child: _sortHdr(context, 'CONTAM',    'contamination'))),
                                      SizedBox(width: _colBrand,     child: Padding(padding: const EdgeInsets.symmetric(horizontal: 6), child: _sortHdr(context, 'BRAND',     'brand'))),
                                      SizedBox(width: _colSupp,      child: Padding(padding: const EdgeInsets.symmetric(horizontal: 6), child: _sortHdr(context, 'SUPPLIER',  'supplier'))),
                                    ]),
                                  ),
                                  Container(height: 1, color: context.appBorder),
                                  // ── Rows ───────────────────────────────
                                  Expanded(
                                    child: ListView.builder(
                                      controller: _vertCtrl,
                                      padding: EdgeInsets.zero,
                                      itemCount: _filtered.length + 1,
                                      itemExtent: AppDS.tableRowH,
                                      itemBuilder: (ctx, i) {
                                        if (i == 0) return _buildAddRow();
                                        final r = _filtered[i - 1];
                                        return _ReagentRow(
                                          reagent: r,
                                          rowIndex: i - 1,
                                          onViewMore: () => Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                              builder: (_) => ReagentDetailPage(
                                                  reagentId: r.id),
                                            )).then((_) => _load()),
                                          onRequest: () =>
                                              showQuickRequestDialog(
                                            context,
                                            type: 'reagents',
                                            prefillTitle: r.name ?? '',
                                          ),
                                          editingCell: _editingCell,
                                          editController: _editController,
                                          editFocus: _editFocus,
                                          onStartEdit: _startEdit,
                                          onAdvance: () => _advanceCell(),
                                          onAdvanceBack: () => _advanceCell(forward: false),
                                          onCancel: _cancelEdit,
                                          onAddNewRow: () {
                                            _commitCurrentEdit();
                                            setState(() => _editingCell = null);
                                            _addNewRow();
                                          },
                                          onCommitCategory: _commitCategoryEdit,
                                          onCommitSubcategory: _commitSubcategoryEdit,
                                          onCommitPhysicalState: _commitPhysicalStateEdit,
                                          onCommitContamination: _commitContaminationEdit,
                                          onCommitLocation: _commitLocationEdit,
                                          onPickOpenedDate: _pickOpenedDate,
                                          locations: _locations,
                                        );
                                      },
                                    ),
                                  ),
                                ]),
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
                      ]),
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
                  ]),
                ),
      ),
    ]);
  }
}
