// reagents_page.dart - Reagent inventory: list with type/status/expiry filters,
// stock tracking, QR codes, CSV export.
// Widget and dialog classes in reagents_widgets.dart (part).


import 'package:flutter/material.dart';
import '/theme/module_permission.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:io';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide LocalStorage;
import '/core/data_cache.dart';
import '/theme/theme.dart';
import 'reagent_model.dart';
import 'reagent_detail_page.dart';
import '../../requests/requests_page.dart';

part 'reagents_widgets.dart';

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
  String _statusFilter = 'all'; // all | expiring | expired | low
  final _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  List<ReagentModel> _reagentsFromRaw(List<dynamic> raw) => raw.map<ReagentModel>((r) {
    final locData = (r as Map)['location'];
    final locName = locData is Map ? locData['location_name'] as String? : null;
    return ReagentModel.fromMap({...Map<String, dynamic>.from(r), 'location_name': locName});
  }).toList();

  Future<void> _load() async {
    final cached = await DataCache.read('reagents');
    if (cached != null && mounted) {
      setState(() { _all = _reagentsFromRaw(cached); _loading = false; _applyFilters(); });
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
      setState(() { _all = _reagentsFromRaw(rows); _loading = false; _applyFilters(); });
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
    setState(() {
      _filtered = _all.where((r) {
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
    });
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


  Widget _hdr(BuildContext context, String t) => Text(t,
      style: GoogleFonts.spaceGrotesk(
          color: context.appTextMuted,
          fontSize: 10,
          letterSpacing: 0.8,
          fontWeight: FontWeight.w600));

  Future<void> _exportCsv() async {
    final buf = StringBuffer();
    buf.writeln(
        'ID,Code,Name,Brand,Reference,CAS,Type,Quantity,Unit,Storage,Location,Lot,Expiry,Supplier,Responsible');
    for (final r in _filtered) {
      buf.writeln(
          '${r.id},"${r.code ?? ''}","${r.name}","${r.brand ?? ''}","${r.reference ?? ''}","${r.casNumber ?? ''}","${r.type}","${r.quantity ?? ''}","${r.unit ?? ''}","${r.storageTemp ?? ''}","${r.locationName ?? ''}","${r.lotNumber ?? ''}","${r.expiryDate != null ? r.expiryDate!.toIso8601String().substring(0, 10) : ''}","${r.supplier ?? ''}","${r.responsible ?? ''}"');
    }
    try {
      final dir = await getDownloadsDirectory() ?? await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/reagents_${DateTime.now().millisecondsSinceEpoch}.csv');
      await file.writeAsString(buf.toString());
      await OpenFilex.open(file.path);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Export failed: $e')));
    }
  }

  int get _expiredCount => _all.where((r) => r.isExpired).length;

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
          const SizedBox(width: 8),
          SizedBox(
            height: 36,
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _typeFilter,
                dropdownColor: context.appSurface,
                style: GoogleFonts.spaceGrotesk(
                    color: context.appTextPrimary, fontSize: 13),
                items: [
                  DropdownMenuItem(
                      value: 'all',
                      child: Text('All Types',
                          style: GoogleFonts.spaceGrotesk(
                              color: context.appTextSecondary, fontSize: 13))),
                  ...ReagentModel.typeOptions.map((t) => DropdownMenuItem(
                        value: t,
                        child: Text(ReagentModel.typeLabel(t),
                            style: GoogleFonts.spaceGrotesk(
                                color: context.appTextPrimary, fontSize: 13)),
                      )),
                ],
                onChanged: (v) {
                  _typeFilter = v ?? 'all';
                  _applyFilters();
                },
              ),
            ),
          ),
          const SizedBox(width: 8),
          Tooltip(
            message: 'Export CSV',
            child: IconButton(
              icon: const Icon(Icons.download_outlined,
                  color: AppDS.textSecondary, size: 18),
              onPressed: _exportCsv,
            ),
          ),
          const SizedBox(width: 4),
          FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFF59E0B),
              foregroundColor: Colors.black,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
              minimumSize: const Size(0, 36),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () => _showAddEditDialog(),
            icon: const Icon(Icons.add, size: 16),
            label:
                Text('Add Reagent', style: GoogleFonts.spaceGrotesk(fontSize: 13)),
          ),
        ]),
      ),

      // ── Filter chips ─────────────────────────────────────────────────────────
      Container(
        height: 44,
        decoration: BoxDecoration(
          color: context.appBg,
          border: Border(bottom: BorderSide(color: context.appBorder)),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(children: [
          _FilterChip(
            label: 'All (${_all.length})',
            selected: _statusFilter == 'all',
            onTap: () {
              _statusFilter = 'all';
              _applyFilters();
            },
          ),
          const SizedBox(width: 8),
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
          const SizedBox(width: 8),
          _FilterChip(
            label: 'Expired ($_expiredCount)',
            selected: _statusFilter == 'expired',
            color: AppDS.red,
            onTap: () {
              _statusFilter = 'expired';
              _applyFilters();
            },
          ),
          const SizedBox(width: 8),
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
        ]),
      ),

      // ── Expired alert banner ──────────────────────────────────────────────────
      if (_expiredCount > 0 && _statusFilter == 'all')
        Container(
          width: double.infinity,
          padding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          color: AppDS.red.withValues(alpha: 0.12),
          child: Row(children: [
            const Icon(Icons.warning_amber_outlined,
                color: AppDS.red, size: 16),
            const SizedBox(width: 8),
            Text(
              '$_expiredCount reagent${_expiredCount > 1 ? 's' : ''} expired — please review.',
              style: GoogleFonts.spaceGrotesk(
                  color: AppDS.red, fontSize: 12),
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
                    // ── Header row ─────────────────────────────────────────
                    Container(
                      height: 32,
                      decoration: BoxDecoration(
                        color: context.appHeaderBg,
                        border: Border(
                          bottom: BorderSide(color: context.appBorder),
                          top: BorderSide(color: context.appBorder),
                        ),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Row(children: [
                        const SizedBox(width: 72), // view detail + quick request btns
                        Expanded(flex: 1, child: _hdr(context, 'CODE')),
                        Expanded(flex: 4, child: _hdr(context, 'NAME')),
                        Expanded(flex: 2, child: _hdr(context, 'TYPE')),
                        Expanded(flex: 2, child: _hdr(context, 'LOCATION')),
                        Expanded(flex: 2, child: _hdr(context, 'BRAND')),
                        Expanded(flex: 1, child: _hdr(context, 'SIZE')),
                        Expanded(flex: 1, child: _hdr(context, 'UNIT')),
                        Expanded(flex: 1, child: _hdr(context, 'AMOUNT')),
                      ]),
                    ),
                    // ── Rows ───────────────────────────────────────────────
                    Expanded(
                      child: ListView.builder(
                        padding: EdgeInsets.zero,
                        itemCount: _filtered.length,
                        itemBuilder: (ctx, i) {
                          final r = _filtered[i];
                          return _ReagentRow(
                            reagent: r,
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) =>
                                    ReagentDetailPage(reagentId: r.id),
                              )).then((_) => _load()),
                            onRequest: () => showQuickRequestDialog(
                              context,
                              type: 'reagents',
                              prefillTitle: r.name,
                            ),
                          );
                        },
                      ),
                    ),
                  ]),
      ),
    ]);
  }
}

