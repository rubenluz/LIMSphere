// reagents_page.dart - Reagent inventory: sortable scrollable list,
// filter panel, inline editing, CSV export.
// Widget and dialog classes in reagents_widgets.dart (part).

import 'package:flutter/material.dart';
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
import '../../camera/qr_scanner/qr_code_rules.dart';
import 'reagent_model.dart';
import 'reagent_detail_page.dart';
import '../../requests/requests_page.dart';

part 'reagents_widgets.dart';

// ── Column widths ─────────────────────────────────────────────────────────────
const _colBtn   = 72.0;
const _colCode  = 90.0;
const _colName  = 210.0;
const _colSupp  = 140.0;
const _colBrand = 130.0;
const _colRef   = 120.0;
const _colType  = 110.0;
const _colLoc   = 130.0;
const _colSize  = 90.0;
const _colUnit  = 70.0;
const _colAmt   = 80.0;
const _colMin   = 80.0;
const _tableW   = _colBtn + _colCode + _colName + _colSupp + _colBrand +
                  _colRef + _colType + _colLoc + _colSize + _colUnit +
                  _colAmt + _colMin;

class ReagentsPage extends StatefulWidget {
  const ReagentsPage({super.key});

  @override
  State<ReagentsPage> createState() => _ReagentsPageState();
}

class _ReagentsPageState extends State<ReagentsPage> {
  List<ReagentModel> _all = [];
  List<ReagentModel> _filtered = [];
  bool _loading = true;
  String _search = '';
  String _typeFilter = 'all';
  String _statusFilter = 'all';
  bool _showFilters = false;
  String _sortKey = 'name';
  bool _sortAsc = true;
  final _searchCtrl = TextEditingController();
  Map<String, dynamic>? _editingCell;
  final _editController = TextEditingController();

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
  }

  void _applyFilters() {
    final q = _search.toLowerCase();
    var result = _all.where((r) {
      if (_typeFilter != 'all' && r.type != _typeFilter) return false;
      if (_statusFilter == 'expired' && !r.isExpired) return false;
      if (_statusFilter == 'expiring' && !r.isExpiringSoon) return false;
      if (_statusFilter == 'low' && !r.isLowStock) return false;
      if (q.isEmpty) return true;
      return r.name.toLowerCase().contains(q) ||
          (r.code?.toLowerCase().contains(q) ?? false) ||
          (r.brand?.toLowerCase().contains(q) ?? false) ||
          (r.reference?.toLowerCase().contains(q) ?? false) ||
          (r.casNumber?.toLowerCase().contains(q) ?? false) ||
          (r.supplier?.toLowerCase().contains(q) ?? false);
    }).toList();

    result.sort((a, b) {
      dynamic av, bv;
      switch (_sortKey) {
        case 'code':          av = a.code ?? '';          bv = b.code ?? '';          break;
        case 'name':          av = a.name;                bv = b.name;                break;
        case 'supplier':      av = a.supplier ?? '';      bv = b.supplier ?? '';      break;
        case 'brand':         av = a.brand ?? '';         bv = b.brand ?? '';         break;
        case 'reference':     av = a.reference ?? '';     bv = b.reference ?? '';     break;
        case 'type':          av = a.type;                bv = b.type;                break;
        case 'location':      av = a.locationName ?? '';  bv = b.locationName ?? '';  break;
        case 'concentration': av = a.concentration ?? ''; bv = b.concentration ?? ''; break;
        case 'unit':          av = a.unit ?? '';          bv = b.unit ?? '';          break;
        case 'quantity':      av = a.quantity ?? -1.0;    bv = b.quantity ?? -1.0;    break;
        case 'quantityMin':   av = a.quantityMin ?? -1.0; bv = b.quantityMin ?? -1.0; break;
        default:              av = a.name;                bv = b.name;
      }
      final c = (av is num && bv is num)
          ? av.compareTo(bv)
          : av.toString().compareTo(bv.toString());
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

  Future<void> _showAddEditDialog([ReagentModel? existing]) async {
    if (!context.canEditModule) { context.warnReadOnly(); return; }
    final locations = await _loadLocations();
    if (!mounted) return;
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) =>
          _ReagentFormDialog(existing: existing, locations: locations),
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

  void _startEdit(int id, String key, String initial) {
    if (!context.canEditModule) { context.warnReadOnly(); return; }
    setState(() {
      _editingCell = {'id': id, 'key': key};
      _editController.text = initial;
    });
  }

  Future<void> _commitEdit(ReagentModel r, String key, String raw) async {
    final v = raw.trim();
    setState(() => _editingCell = null);
    String? dbCol;
    dynamic dbVal;
    switch (key) {
      case 'name':          dbCol = 'reagent_name';          dbVal = v.isEmpty ? r.name : v; break;
      case 'code':          dbCol = 'reagent_code';          dbVal = v.isEmpty ? null : v; break;
      case 'supplier':      dbCol = 'reagent_supplier';      dbVal = v.isEmpty ? null : v; break;
      case 'brand':         dbCol = 'reagent_brand';         dbVal = v.isEmpty ? null : v; break;
      case 'reference':     dbCol = 'reagent_reference';     dbVal = v.isEmpty ? null : v; break;
      case 'concentration': dbCol = 'reagent_concentration'; dbVal = v.isEmpty ? null : v; break;
      case 'unit':          dbCol = 'reagent_unit';          dbVal = v.isEmpty ? null : v; break;
      case 'quantity':      dbCol = 'reagent_quantity';      dbVal = v.isEmpty ? null : double.tryParse(v); break;
      case 'quantityMin':   dbCol = 'reagent_quantity_min';  dbVal = v.isEmpty ? null : double.tryParse(v); break;
      case 'type':          dbCol = 'reagent_type';          dbVal = v; break;
      default: return;
    }
    try {
      await Supabase.instance.client
          .from('reagents')
          .update({dbCol: dbVal, 'reagent_updated_at': DateTime.now().toUtc().toIso8601String()})
          .eq('reagent_id', r.id);
      if (mounted) _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Save failed: $e'),
          backgroundColor: AppDS.red,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ));
      }
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
        'ID,Code,Name,Supplier,Brand,Reference,CAS,Type,Quantity,Unit,Storage,Location,Lot,Expiry,Responsible');
    for (final r in _filtered) {
      buf.writeln(
          '${r.id},"${r.code ?? ''}","${r.name}","${r.supplier ?? ''}","${r.brand ?? ''}","${r.reference ?? ''}","${r.casNumber ?? ''}","${r.type}","${r.quantity ?? ''}","${r.unit ?? ''}","${r.storageTemp ?? ''}","${r.locationName ?? ''}","${r.lotNumber ?? ''}","${r.expiryDate != null ? r.expiryDate!.toIso8601String().substring(0, 10) : ''}","${r.responsible ?? ''}"');
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

  int get _expiredCount => _all.where((r) => r.isExpired).length;
  bool get _hasActiveFilter => _typeFilter != 'all' || _statusFilter != 'all';

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
            label: Text('Add Reagent',
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
                Text('Type',
                    style: GoogleFonts.spaceGrotesk(
                        color: context.appTextMuted,
                        fontSize: 11,
                        fontWeight: FontWeight.w600)),
                const SizedBox(width: 12),
                _FilterChip(
                  label: 'All',
                  selected: _typeFilter == 'all',
                  onTap: () { _typeFilter = 'all'; _applyFilters(); },
                ),
                ...ReagentModel.typeOptions.map((t) => Padding(
                      padding: const EdgeInsets.only(left: 6),
                      child: _FilterChip(
                        label: ReagentModel.typeLabel(t),
                        selected: _typeFilter == t,
                        onTap: () { _typeFilter = t; _applyFilters(); },
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
                : Column(children: [
                    Expanded(
                      child: Row(children: [
                        Expanded(
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
                                    decoration: BoxDecoration(
                                      color: context.appHeaderBg,
                                      border: Border(
                                          bottom: BorderSide(
                                              color: context.appBorder)),
                                    ),
                                    child: Row(children: [
                                      const SizedBox(width: _colBtn),
                                      SizedBox(width: _colCode,  child: Padding(padding: const EdgeInsets.symmetric(horizontal: 6), child: _sortHdr(context, 'CODE', 'code'))),
                                      SizedBox(width: _colName,  child: Padding(padding: const EdgeInsets.symmetric(horizontal: 6), child: _sortHdr(context, 'NAME', 'name'))),
                                      SizedBox(width: _colSupp,  child: Padding(padding: const EdgeInsets.symmetric(horizontal: 6), child: _sortHdr(context, 'SUPPLIER', 'supplier'))),
                                      SizedBox(width: _colBrand, child: Padding(padding: const EdgeInsets.symmetric(horizontal: 6), child: _sortHdr(context, 'BRAND', 'brand'))),
                                      SizedBox(width: _colRef,   child: Padding(padding: const EdgeInsets.symmetric(horizontal: 6), child: _sortHdr(context, 'REFERENCE', 'reference'))),
                                      SizedBox(width: _colType,  child: Padding(padding: const EdgeInsets.symmetric(horizontal: 6), child: _sortHdr(context, 'TYPE', 'type'))),
                                      SizedBox(width: _colLoc,   child: Padding(padding: const EdgeInsets.symmetric(horizontal: 6), child: _sortHdr(context, 'LOCATION', 'location'))),
                                      SizedBox(width: _colSize,  child: Padding(padding: const EdgeInsets.symmetric(horizontal: 6), child: _sortHdr(context, 'SIZE', 'concentration'))),
                                      SizedBox(width: _colUnit,  child: Padding(padding: const EdgeInsets.symmetric(horizontal: 6), child: _sortHdr(context, 'UNIT', 'unit'))),
                                      SizedBox(width: _colAmt,   child: Padding(padding: const EdgeInsets.symmetric(horizontal: 6), child: _sortHdr(context, 'AMOUNT', 'quantity'))),
                                      SizedBox(width: _colMin,   child: Padding(padding: const EdgeInsets.symmetric(horizontal: 6), child: _sortHdr(context, 'MIN QTY', 'quantityMin'))),
                                    ]),
                                  ),
                                  // ── Rows ───────────────────────────────
                                  Expanded(
                                    child: ListView.builder(
                                      controller: _vertCtrl,
                                      padding: EdgeInsets.zero,
                                      itemCount: _filtered.length,
                                      itemExtent: AppDS.tableRowH,
                                      itemBuilder: (ctx, i) {
                                        final r = _filtered[i];
                                        return _ReagentRow(
                                          reagent: r,
                                          rowIndex: i,
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
                                            prefillTitle: r.name,
                                          ),
                                          editingCell: _editingCell,
                                          editController: _editController,
                                          onStartEdit: _startEdit,
                                          onCommitEdit: _commitEdit,
                                        );
                                      },
                                    ),
                                  ),
                                ]),
                              ),
                            ),
                          ),
                        ),
                        // ── Vertical thumb ──────────────────────────────
                        AppVerticalThumb(
                          contentLength:
                              _filtered.length * AppDS.tableRowH,
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
    ]);
  }
}
