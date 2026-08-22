// reagent_detail_page.dart - Reagent editor: inline fields for all reagent
// properties, date pickers, location & category dropdowns, QR code display.
// Pushed via Navigator with its own Scaffold + AppBar.
// Light and dark theme

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide LocalStorage;

import '../../backups/backup_service.dart';
import '../../supabase/supabase_manager.dart';
import '/theme/theme.dart';
import '/theme/module_permission.dart';
import 'reagent_model.dart';
import '../../requests/requests_page.dart';
import '../../camera/qr_scanner/qr_code_rules.dart';

class ReagentDetailPage extends StatefulWidget {
  final int reagentId;
  const ReagentDetailPage({super.key, required this.reagentId});

  @override
  State<ReagentDetailPage> createState() => _ReagentDetailPageState();
}

class _ReagentDetailPageState extends State<ReagentDetailPage> {
  ReagentModel? _reagent;
  List<Map<String, dynamic>> _allLocations = [];
  bool _loading = true;
  bool _saving = false;
  bool _editMode = false;
  final Set<int> _expanded = {0, 1, 2, 3, 4, 5};

  // Controllers
  late final TextEditingController _codeCtrl;
  late final TextEditingController _nameCtrl;
  late final TextEditingController _brandCtrl;
  late final TextEditingController _supplierCtrl;
  late final TextEditingController _referenceCtrl;
  late final TextEditingController _casCtrl;
  late final TextEditingController _synonymsCtrl;
  late final TextEditingController _lotCtrl;
  late final TextEditingController _concentrationCtrl;
  late final TextEditingController _formulaCtrl;
  late final TextEditingController _hazardCtrl;
  late final TextEditingController _packSizeCtrl;
  late final TextEditingController _containerCountCtrl;
  late final TextEditingController _containerMinCtrl;
  late final TextEditingController _priceEurCtrl;
  late final TextEditingController _unitCtrl;
  late final TextEditingController _positionCtrl;
  late final TextEditingController _notesCtrl;
  late final TextEditingController _contamNotesCtrl;
  late final TextEditingController _tagsCtrl;

  // Dropdown / date state
  String _category = 'chemical';
  String? _subcategory;
  String _stockStatus = 'in_stock';
  String _contamination = 'none';
  String? _physicalState;
  String? _storageTemp;
  int? _roomId;
  int? _locationId;
  DateTime? _expiryDate;
  DateTime? _receivedDate;
  DateTime? _openedDate;
  DateTime? _contaminationDate;

  @override
  void initState() {
    super.initState();
    _codeCtrl = TextEditingController();
    _nameCtrl = TextEditingController();
    _brandCtrl = TextEditingController();
    _supplierCtrl = TextEditingController();
    _referenceCtrl = TextEditingController();
    _casCtrl = TextEditingController();
    _synonymsCtrl = TextEditingController();
    _lotCtrl = TextEditingController();
    _concentrationCtrl = TextEditingController();
    _formulaCtrl = TextEditingController();
    _hazardCtrl = TextEditingController();
    _packSizeCtrl = TextEditingController();
    _containerCountCtrl = TextEditingController();
    _containerMinCtrl = TextEditingController();
    _priceEurCtrl = TextEditingController();
    _unitCtrl = TextEditingController();
    _positionCtrl = TextEditingController();
    _notesCtrl = TextEditingController();
    _contamNotesCtrl = TextEditingController();
    _tagsCtrl = TextEditingController();
    _load();
  }

  @override
  void dispose() {
    for (final c in [
      _codeCtrl,
      _nameCtrl,
      _brandCtrl,
      _supplierCtrl,
      _referenceCtrl,
      _casCtrl,
      _synonymsCtrl,
      _lotCtrl,
      _concentrationCtrl,
      _formulaCtrl,
      _hazardCtrl,
      _packSizeCtrl,
      _containerCountCtrl,
      _containerMinCtrl,
      _priceEurCtrl,
      _unitCtrl,
      _positionCtrl,
      _notesCtrl,
      _contamNotesCtrl,
      _tagsCtrl,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  // ── Data ───────────────────────────────────────────────────────────────────

  Future<void> _load() async {
    if (!mounted) return;
    setState(() => _loading = true);
    try {
      final results = await Future.wait([
        Supabase.instance.client
            .from('reagents')
            .select('*, location:reagent_location_id(location_name)')
            .eq('reagent_id', widget.reagentId)
            .limit(1),
        Supabase.instance.client
            .from('storage_locations')
            .select(
              'location_id, location_name, location_type, '
              'location_code, location_parent_id, location_sort_order',
            )
            .order('location_name'),
      ]);

      final rows = results[0] as List<dynamic>;
      final locRows = results[1] as List<dynamic>;

      if (rows.isEmpty) {
        if (mounted) setState(() => _loading = false);
        return;
      }

      final r = rows[0] as Map<String, dynamic>;
      final locData = r['location'];
      final reagent = ReagentModel.fromMap({
        ...r,
        'location_name': locData is Map
            ? locData['location_name'] as String?
            : null,
      });

      if (mounted) {
        _codeCtrl.text = reagent.code ?? '';
        _nameCtrl.text = reagent.name ?? '';
        _brandCtrl.text = reagent.brand ?? '';
        _supplierCtrl.text = reagent.supplier ?? '';
        _referenceCtrl.text = reagent.reference ?? '';
        _casCtrl.text = reagent.casNumber ?? '';
        _synonymsCtrl.text = reagent.synonyms ?? '';
        _lotCtrl.text = reagent.lotNumber ?? '';
        _concentrationCtrl.text = reagent.concentration ?? '';
        _formulaCtrl.text = reagent.formula ?? '';
        _hazardCtrl.text = reagent.hazard ?? '';
        _packSizeCtrl.text = reagent.packageSize?.toString() ?? '';
        _containerCountCtrl.text = reagent.containerCount?.toString() ?? '';
        _containerMinCtrl.text = reagent.containerMin?.toString() ?? '';
        _priceEurCtrl.text = reagent.priceEur?.toString() ?? '';
        _unitCtrl.text = reagent.unit ?? '';
        _positionCtrl.text = reagent.position ?? '';
        _notesCtrl.text = reagent.notes ?? '';
        _contamNotesCtrl.text = reagent.contaminationNotes ?? '';
        _tagsCtrl.text = reagent.tagList.join('; ');
        _category = reagent.category;
        _subcategory = reagent.subcategory;
        _stockStatus = reagent.stockStatus;
        _contamination = reagent.contamination;
        _physicalState = reagent.physicalState;
        _storageTemp = reagent.storageTemp;
        final orderedLocations = _orderLocationsHierarchically(
          List<Map<String, dynamic>>.from(locRows),
        );
        Map<String, dynamic>? selectedLocation;
        for (final location in orderedLocations) {
          if ((location['location_id'] as num).toInt() == reagent.locationId) {
            selectedLocation = location;
            break;
          }
        }
        if ((selectedLocation?['location_type'] as String?) == null ||
            (selectedLocation?['location_type'] as String?) == 'room') {
          _roomId = reagent.locationId;
          _locationId = null;
        } else {
          _roomId = (selectedLocation?['location_parent_id'] as num?)?.toInt();
          _locationId = reagent.locationId;
        }
        _expiryDate = reagent.expiryDate;
        _receivedDate = reagent.receivedDate;
        _openedDate = reagent.openedDate;
        _contaminationDate = reagent.contaminationDate;

        setState(() {
          _reagent = reagent;
          _allLocations = orderedLocations;
          _loading = false;
        });
      }
    } catch (e) {
      debugPrint('ReagentDetailPage load error: $e');
      if (mounted) {
        setState(() => _loading = false);
        _snack('Failed to load: $e');
      }
    }
  }

  // Orders locations as R1, L1.1, L1.2, R2, L2.1, ... and stamps each entry
  // with a `_display` string matching the Locations page hierarchy.
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
        final locationCode =
            kids[j]['location_code']?.toString() ?? 'L${i + 1}.${j + 1}';
        out.add({
          ...kids[j],
          '_display': '$locationCode — ${kids[j]['location_name']}',
        });
      }
    }
    for (final o in orphans) {
      out.add({...o, '_display': o['location_name'] as String});
    }
    return out;
  }

  List<Map<String, dynamic>> get _rooms => _allLocations
      .where(
        (location) =>
            location['location_type'] == null ||
            location['location_type'] == 'room',
      )
      .toList();

  List<Map<String, dynamic>> get _locationsInSelectedRoom {
    if (_roomId == null) return const [];
    return _allLocations
        .where(
          (location) =>
              location['location_type'] != null &&
              location['location_type'] != 'room' &&
              (location['location_parent_id'] as num?)?.toInt() == _roomId,
        )
        .toList();
  }

  Future<void> _save() async {
    if (!context.requireModuleAction(ModuleAction.edit)) return;
    if (_codeCtrl.text.trim().isEmpty) {
      _snack('Code is required');
      return;
    }
    setState(() => _saving = true);
    try {
      final data = <String, dynamic>{
        'reagent_code': _codeCtrl.text.trim(),
        'reagent_name': _nameCtrl.text.trim().isEmpty
            ? null
            : _nameCtrl.text.trim(),
        'reagent_category': _category,
        'reagent_subcategory': _subcategory,
        'reagent_stock_status': ReagentModel.normalizeStockStatus(_stockStatus),
        'reagent_physical_state': _physicalState,
        'reagent_brand': _brandCtrl.text.trim().isEmpty
            ? null
            : _brandCtrl.text.trim(),
        'reagent_supplier': _supplierCtrl.text.trim().isEmpty
            ? null
            : _supplierCtrl.text.trim(),
        'reagent_reference': _referenceCtrl.text.trim().isEmpty
            ? null
            : _referenceCtrl.text.trim(),
        'reagent_cas_number': _casCtrl.text.trim().isEmpty
            ? null
            : _casCtrl.text.trim(),
        'reagent_synonyms': _synonymsCtrl.text.trim().isEmpty
            ? null
            : _synonymsCtrl.text.trim(),
        'reagent_lot_number': _lotCtrl.text.trim().isEmpty
            ? null
            : _lotCtrl.text.trim(),
        'reagent_concentration': _concentrationCtrl.text.trim().isEmpty
            ? null
            : _concentrationCtrl.text.trim(),
        'reagent_formula': _formulaCtrl.text.trim().isEmpty
            ? null
            : _formulaCtrl.text.trim(),
        'reagent_hazard': _hazardCtrl.text.trim().isEmpty
            ? null
            : _hazardCtrl.text.trim(),
        'reagent_package_size': double.tryParse(_packSizeCtrl.text.trim()),
        'reagent_container_count': int.tryParse(
          _containerCountCtrl.text.trim(),
        ),
        'reagent_container_min': int.tryParse(_containerMinCtrl.text.trim()),
        'reagent_price_eur': double.tryParse(_priceEurCtrl.text.trim()),
        'reagent_unit': _unitCtrl.text.trim().isEmpty
            ? null
            : _unitCtrl.text.trim(),
        'reagent_storage_temp': _storageTemp,
        'reagent_location_id': _locationId ?? _roomId,
        'reagent_position': _positionCtrl.text.trim().isEmpty
            ? null
            : _positionCtrl.text.trim(),
        'reagent_expiry_date': _expiryDate?.toIso8601String().substring(0, 10),
        'reagent_received_date': _receivedDate?.toIso8601String().substring(
          0,
          10,
        ),
        'reagent_opened_date': _openedDate?.toIso8601String().substring(0, 10),
        'reagent_notes': _notesCtrl.text.trim().isEmpty
            ? null
            : _notesCtrl.text.trim(),
        'reagent_contamination': _contamination,
        'reagent_contamination_notes': _contamNotesCtrl.text.trim().isEmpty
            ? null
            : _contamNotesCtrl.text.trim(),
        'reagent_contamination_date': _contaminationDate
            ?.toIso8601String()
            .substring(0, 10),
        'reagent_tags': ReagentModel.joinTags(_tagsCtrl.text.split(';')),
        'reagent_qrcode': QrRules.build(
          SupabaseManager.projectRef ?? 'local',
          'reagents',
          widget.reagentId,
        ),
      };
      await Supabase.instance.client
          .from('reagents')
          .update(data)
          .eq('reagent_id', widget.reagentId);
      unawaited(BackupService.instance.notifyCrudChange('reagents'));
      await _load();
      if (mounted) setState(() => _editMode = false);
      _snack('Saved');
    } catch (e) {
      debugPrint('ReagentDetailPage save error: $e');
      _snack('Save failed: $e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _pickDate(
    DateTime? current,
    void Function(DateTime?) onPicked,
  ) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: current ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) onPicked(picked);
  }

  Future<void> _delete() async {
    if (!context.requireModuleAction(ModuleAction.delete)) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: ctx.appSurface,
        title: Text(
          'Delete reagent?',
          style: GoogleFonts.spaceGrotesk(color: ctx.appTextPrimary),
        ),
        content: Text(
          'This will permanently delete "${_reagent?.name}". This cannot be undone.',
          style: GoogleFonts.spaceGrotesk(
            color: ctx.appTextSecondary,
            fontSize: 13,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(
              'Cancel',
              style: GoogleFonts.spaceGrotesk(color: ctx.appTextSecondary),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              'Delete',
              style: GoogleFonts.spaceGrotesk(color: AppDS.red),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await Supabase.instance.client
          .from('reagents')
          .delete()
          .eq('reagent_id', widget.reagentId);
      unawaited(BackupService.instance.notifyCrudChange('reagents'));
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      debugPrint('ReagentDetailPage delete error: $e');
      _snack('Delete failed: $e');
    }
  }

  static const _categoryAccent = <String, Color>{
    'chemical': Color(0xFF38BDF8),
    'biological': Color(0xFF22C55E),
    'consumable': Color(0xFFF59E0B),
    'kit': Color(0xFF8B5CF6),
  };

  static const _contamColor = <String, Color>{
    'none': Color(0xFF22C55E),
    'bacteria': Color(0xFFEF4444),
    'fungi': Color(0xFFA855F7),
    'both': Color(0xFFEC4899),
    'suspected': Color(0xFFEAB308),
  };

  Color _physicalStateColor(String s) => switch (s) {
    'liquid' => const Color(0xFF38BDF8),
    'solid' => const Color(0xFF94A3B8),
    'gas' => const Color(0xFFA78BFA),
    _ => const Color(0xFF64748B),
  };

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: const TextStyle(color: Colors.white)),
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppDS.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final r = _reagent;
    return Scaffold(
      backgroundColor: context.appBg,
      appBar: AppBar(
        backgroundColor: context.appSurface2,
        foregroundColor: context.appTextPrimary,
        elevation: 0,
        title: Text(
          r?.name ?? 'Reagent',
          style: GoogleFonts.spaceGrotesk(
            color: context.appTextPrimary,
            fontWeight: FontWeight.w600,
          ),
        ),
        actions: [
          if (r != null) ...[
            IconButton(
              icon: const Icon(Icons.outbox_outlined, size: 20),
              tooltip: 'Quick Request',
              onPressed: () => showQuickRequestDialog(
                context,
                type: 'reagents',
                prefillTitle: r.name ?? '',
              ),
            ),
            if (_editMode)
              IconButton(
                icon: const Icon(
                  Icons.delete_outline,
                  size: 20,
                  color: AppDS.red,
                ),
                tooltip: 'Delete',
                onPressed: _delete,
              ),
            if (_editMode && !_saving)
              IconButton(
                icon: Icon(
                  Icons.close,
                  size: 20,
                  color: context.appTextSecondary,
                ),
                tooltip: 'Cancel',
                onPressed: () {
                  setState(() => _editMode = false);
                  _load();
                },
              ),
            _saving
                ? const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16),
                    child: SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppDS.accent,
                      ),
                    ),
                  )
                : _editMode
                ? TextButton.icon(
                    onPressed: _save,
                    icon: const Icon(
                      Icons.save_outlined,
                      size: 16,
                      color: AppDS.accent,
                    ),
                    label: Text(
                      'Save',
                      style: GoogleFonts.spaceGrotesk(color: AppDS.accent),
                    ),
                  )
                : TextButton.icon(
                    onPressed: () {
                      if (!context.canEditModule) {
                        context.warnReadOnly();
                        return;
                      }
                      setState(() => _editMode = true);
                    },
                    icon: const Icon(
                      Icons.edit_outlined,
                      size: 16,
                      color: AppDS.accent,
                    ),
                    label: Text(
                      'Edit',
                      style: GoogleFonts.spaceGrotesk(color: AppDS.accent),
                    ),
                  ),
          ],
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : r == null
          ? Center(
              child: Text(
                'Reagent not found',
                style: GoogleFonts.spaceGrotesk(color: context.appTextMuted),
              ),
            )
          : _buildBody(context, r),
    );
  }

  Widget _buildBody(BuildContext context, ReagentModel r) {
    final accent = _categoryAccent[r.category] ?? AppDS.accent;
    final qrData = QrRules.build(
      SupabaseManager.projectRef ?? 'local',
      'reagents',
      r.id,
    );

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildHeader(context, r, accent, qrData),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                _Section(
                  index: 0,
                  title: 'REAGENT DETAILS',
                  icon: Icons.science_outlined,
                  expanded: _expanded.contains(0),
                  onToggle: () => setState(
                    () => _expanded.contains(0)
                        ? _expanded.remove(0)
                        : _expanded.add(0),
                  ),
                  child: _buildDetailsSection(context),
                ),
                _Section(
                  index: 1,
                  title: 'IDENTIFICATION',
                  icon: Icons.fingerprint_outlined,
                  expanded: _expanded.contains(1),
                  onToggle: () => setState(
                    () => _expanded.contains(1)
                        ? _expanded.remove(1)
                        : _expanded.add(1),
                  ),
                  child: _buildIdentificationSection(context),
                ),
                _Section(
                  index: 2,
                  title: 'STOCK & STORAGE',
                  icon: Icons.inventory_2_outlined,
                  expanded: _expanded.contains(2),
                  onToggle: () => setState(
                    () => _expanded.contains(2)
                        ? _expanded.remove(2)
                        : _expanded.add(2),
                  ),
                  child: _buildStockSection(context, r),
                ),
                _Section(
                  index: 3,
                  title: 'CONTAMINATION',
                  icon: Icons.biotech_outlined,
                  expanded: _expanded.contains(3),
                  onToggle: () => setState(
                    () => _expanded.contains(3)
                        ? _expanded.remove(3)
                        : _expanded.add(3),
                  ),
                  child: _buildContaminationSection(context),
                ),
                _Section(
                  index: 4,
                  title: 'DATES',
                  icon: Icons.calendar_today_outlined,
                  expanded: _expanded.contains(4),
                  onToggle: () => setState(
                    () => _expanded.contains(4)
                        ? _expanded.remove(4)
                        : _expanded.add(4),
                  ),
                  child: _buildDatesSection(context),
                ),
                _Section(
                  index: 5,
                  title: 'NOTES',
                  icon: Icons.notes_rounded,
                  expanded: _expanded.contains(5),
                  onToggle: () => setState(
                    () => _expanded.contains(5)
                        ? _expanded.remove(5)
                        : _expanded.add(5),
                  ),
                  child: _InlineField(
                    label: 'Notes',
                    controller: _notesCtrl,
                    maxLines: 4,
                    readOnly: !_editMode,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Header ─────────────────────────────────────────────────────────────────

  Widget _buildHeader(
    BuildContext context,
    ReagentModel r,
    Color accent,
    String qrData,
  ) {
    return Container(
      color: context.appSurface2,
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 20),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GestureDetector(
            onTap: () => _showQr(r),
            child: Container(
              color: Colors.white,
              padding: const EdgeInsets.all(10),
              child: QrImageView(data: qrData, size: 110),
            ),
          ),
          const SizedBox(width: 24),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  r.name ?? '—',
                  style: GoogleFonts.spaceGrotesk(
                    color: context.appTextPrimary,
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (r.brand != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    r.brand!,
                    style: GoogleFonts.spaceGrotesk(
                      color: context.appTextSecondary,
                      fontSize: 13,
                    ),
                  ),
                ],
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: [
                    _Badge(
                      label: ReagentModel.categoryLabel(r.category),
                      color: accent,
                    ),
                    if (r.subcategory != null)
                      _Badge(
                        label: ReagentModel.subcategoryLabel(r.subcategory!),
                        color: accent.withValues(alpha: 0.7),
                      ),
                    if (r.physicalState != null)
                      _Badge(
                        label: ReagentModel.physicalStateLabel(
                          r.physicalState!,
                        ),
                        color: _physicalStateColor(r.physicalState!),
                      ),
                    if (r.isContaminated)
                      _Badge(
                        label: ReagentModel.contaminationLabel(r.contamination),
                        color: _contamColor[r.contamination] ?? AppDS.red,
                      ),
                    if (r.isOutOfStock)
                      const _Badge(label: 'Out of stock', color: AppDS.red),
                    if (r.isExpired) _Badge(label: 'Expired', color: AppDS.red),
                    if (r.isExpiringSoon && !r.isExpired)
                      _Badge(label: 'Expiring soon', color: AppDS.yellow),
                    if (r.isLowStock)
                      _Badge(label: 'Low stock', color: AppDS.orange),
                    if (r.hazard != null && r.hazard!.isNotEmpty)
                      _Badge(label: r.hazard!, color: AppDS.yellow),
                  ],
                ),
                if (r.totalStock != null) ...[
                  const SizedBox(height: 6),
                  Text(
                    'Total stock: ${r.displayTotalStock}'
                    '${r.containerCount != null ? " • ${r.containerCount} × ${r.displayPackageSize}" : ""}',
                    style: GoogleFonts.jetBrainsMono(
                      color: context.appTextSecondary,
                      fontSize: 11,
                    ),
                  ),
                ],
                const SizedBox(height: 6),
                GestureDetector(
                  onTap: () async {
                    await Clipboard.setData(ClipboardData(text: qrData));
                    _snack('Link copied');
                  },
                  child: Text(
                    qrData,
                    style: GoogleFonts.jetBrainsMono(
                      color: context.appTextMuted,
                      fontSize: 10,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Section bodies ─────────────────────────────────────────────────────────

  Widget _buildDetailsSection(BuildContext context) {
    final subOptions = ReagentModel.subcategoryOptionsSorted(_category);
    if (_subcategory != null && !subOptions.contains(_subcategory)) {
      _subcategory = null;
    }
    final ro = !_editMode;
    return Column(
      children: [
        _FieldRow(
          children: [
            _InlineField(label: 'Name', controller: _nameCtrl, readOnly: ro),
            _InlineDropdown<String>(
              label: 'Category',
              value: _category,
              readOnly: ro,
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
          ],
        ),
        const SizedBox(height: 10),
        _FieldRow(
          children: [
            _InlineDropdown<String?>(
              label: 'Subcategory',
              value: _subcategory,
              readOnly: ro,
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
            _InlineDropdown<String?>(
              label: 'Physical State',
              value: _physicalState,
              readOnly: ro,
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
          ],
        ),
        const SizedBox(height: 10),
        _FieldRow(
          children: [
            _InlineField(label: 'Brand', controller: _brandCtrl, readOnly: ro),
            _InlineField(
              label: 'Supplier',
              controller: _supplierCtrl,
              readOnly: ro,
            ),
          ],
        ),
        const SizedBox(height: 10),
        _InlineField(
          label: 'Tags (separated by ";")',
          controller: _tagsCtrl,
          readOnly: ro,
        ),
      ],
    );
  }

  Widget _buildIdentificationSection(BuildContext context) {
    final ro = !_editMode;
    return Column(
      children: [
        _FieldRow(
          children: [
            _InlineField(
              label: 'Code * (e.g. BR001)',
              controller: _codeCtrl,
              readOnly: ro,
            ),
            _InlineField(
              label: 'Reference',
              controller: _referenceCtrl,
              readOnly: ro,
            ),
            _InlineField(
              label: 'CAS Number',
              controller: _casCtrl,
              readOnly: ro,
            ),
          ],
        ),
        const SizedBox(height: 10),
        _FieldRow(
          children: [
            _InlineField(
              label: 'Lot Number',
              controller: _lotCtrl,
              readOnly: ro,
            ),
            _InlineField(
              label: 'Synonyms',
              controller: _synonymsCtrl,
              readOnly: ro,
            ),
          ],
        ),
        const SizedBox(height: 10),
        _FieldRow(
          children: [
            _InlineField(
              label: 'Formula',
              controller: _formulaCtrl,
              readOnly: ro,
            ),
            _InlineField(
              label: 'Hazard',
              controller: _hazardCtrl,
              readOnly: ro,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStockSection(BuildContext context, ReagentModel r) {
    final ro = !_editMode;
    return Column(
      children: [
        _FieldRow(
          children: [
            _InlineField(
              label: 'Package / flask size',
              controller: _packSizeCtrl,
              readOnly: ro,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
            ),
            _InlineField(
              label: 'Unit (mL / g / …)',
              controller: _unitCtrl,
              readOnly: ro,
            ),
            _InlineField(
              label: 'Price (EUR)',
              controller: _priceEurCtrl,
              readOnly: ro,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
            ),
            _InlineField(
              label: 'Concentration',
              controller: _concentrationCtrl,
              readOnly: ro,
            ),
          ],
        ),
        const SizedBox(height: 10),
        _FieldRow(
          children: [
            _InlineDropdown<String>(
              label: 'Stock Status',
              value: _stockStatus,
              readOnly: ro,
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
              onChanged: (v) => setState(() => _stockStatus = v ?? 'in_stock'),
            ),
            _InlineField(
              label: '# Containers on hand',
              controller: _containerCountCtrl,
              readOnly: ro,
              keyboardType: TextInputType.number,
            ),
            _InlineField(
              label: 'Min containers (reorder)',
              controller: _containerMinCtrl,
              readOnly: ro,
              keyboardType: TextInputType.number,
            ),
          ],
        ),
        const SizedBox(height: 10),
        _FieldRow(
          children: [
            _InlineDropdown<String?>(
              label: 'Storage Temp',
              value: _storageTemp,
              readOnly: ro,
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
                  (t) => DropdownMenuItem<String?>(
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
            _InlineDropdown<int?>(
              label: 'Room',
              value: _roomId,
              readOnly: ro,
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
                ..._rooms.map(
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
              onChanged: (v) => setState(() {
                _roomId = v;
                _locationId = null;
                _positionCtrl.clear();
              }),
            ),
          ],
        ),
        const SizedBox(height: 10),
        _FieldRow(
          children: [
            _InlineDropdown<int?>(
              label: 'Location',
              value: _locationId,
              readOnly: ro || _roomId == null,
              items: [
                DropdownMenuItem<int?>(
                  value: null,
                  child: Text(
                    _roomId == null ? 'Select a room first' : '/',
                    style: GoogleFonts.spaceGrotesk(
                      color: context.appTextMuted,
                      fontSize: 13,
                    ),
                  ),
                ),
                ..._locationsInSelectedRoom.map(
                  (location) => DropdownMenuItem<int?>(
                    value: (location['location_id'] as num).toInt(),
                    child: Text(
                      (location['_display'] as String?) ??
                          (location['location_name'] as String),
                      style: GoogleFonts.spaceGrotesk(
                        color: context.appTextPrimary,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ),
              ],
              onChanged: (value) => setState(() {
                _locationId = value;
                _positionCtrl.clear();
              }),
            ),
            _InlineField(
              label: 'Exact position',
              controller: _positionCtrl,
              readOnly: ro || _roomId == null,
            ),
          ],
        ),
        if (r.totalStock != null) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: context.appSurface2,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: context.appBorder),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.calculate_outlined,
                  size: 14,
                  color: context.appTextMuted,
                ),
                const SizedBox(width: 8),
                Text(
                  'Effective total stock: ',
                  style: GoogleFonts.spaceGrotesk(
                    color: context.appTextSecondary,
                    fontSize: 12,
                  ),
                ),
                Text(
                  r.displayTotalStock,
                  style: GoogleFonts.jetBrainsMono(
                    color: context.appTextPrimary,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildContaminationSection(BuildContext context) {
    final ro = !_editMode;
    return Column(
      children: [
        _FieldRow(
          children: [
            _InlineDropdown<String>(
              label: 'Status',
              value: _contamination,
              readOnly: ro,
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
                if (_contamination != 'none' && _contaminationDate == null) {
                  _contaminationDate = DateTime.now();
                }
              }),
            ),
            _DateField(
              label: 'Detected on',
              date: _contaminationDate,
              readOnly: ro,
              onTap: () => _pickDate(
                _contaminationDate,
                (d) => setState(() => _contaminationDate = d),
              ),
              onClear: () => setState(() => _contaminationDate = null),
            ),
          ],
        ),
        if (_contamination != 'none') ...[
          const SizedBox(height: 10),
          _InlineField(
            label: 'Contamination notes',
            controller: _contamNotesCtrl,
            readOnly: ro,
            maxLines: 2,
          ),
        ],
      ],
    );
  }

  Widget _buildDatesSection(BuildContext context) {
    final ro = !_editMode;
    return Column(
      children: [
        _FieldRow(
          children: [
            _DateField(
              label: 'Received Date',
              date: _receivedDate,
              readOnly: ro,
              onTap: () => _pickDate(
                _receivedDate,
                (d) => setState(() => _receivedDate = d),
              ),
              onClear: () => setState(() => _receivedDate = null),
            ),
            _DateField(
              label: 'Opened Date',
              date: _openedDate,
              readOnly: ro,
              onTap: () => _pickDate(
                _openedDate,
                (d) => setState(() => _openedDate = d),
              ),
              onClear: () => setState(() => _openedDate = null),
            ),
            _DateField(
              label: 'Expiry Date',
              date: _expiryDate,
              readOnly: ro,
              onTap: () => _pickDate(
                _expiryDate,
                (d) => setState(() => _expiryDate = d),
              ),
              onClear: () => setState(() => _expiryDate = null),
              danger: _reagent?.isExpired == true,
              warning:
                  _reagent?.isExpiringSoon == true &&
                  _reagent?.isExpired == false,
            ),
          ],
        ),
      ],
    );
  }

  // ── QR dialog ──────────────────────────────────────────────────────────────

  void _showQr(ReagentModel r) {
    final ref = SupabaseManager.projectRef ?? 'local';
    final data = QrRules.build(ref, 'reagents', r.id);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: ctx.appSurface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Text(
          'QR — ${r.name}',
          style: GoogleFonts.spaceGrotesk(color: ctx.appTextPrimary),
        ),
        content: SizedBox(
          width: 260,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                color: Colors.white,
                padding: const EdgeInsets.all(12),
                child: QrImageView(data: data, size: 200),
              ),
              const SizedBox(height: 10),
              Text(
                data,
                style: GoogleFonts.spaceGrotesk(
                  color: ctx.appTextMuted,
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: data));
              if (context.mounted) Navigator.pop(ctx);
              _snack('Link copied');
            },
            child: Text(
              'Copy Link',
              style: GoogleFonts.spaceGrotesk(color: AppDS.accent),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              'Close',
              style: GoogleFonts.spaceGrotesk(color: ctx.appTextSecondary),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Collapsible Section ─────────────────────────────────────────────────────
class _Section extends StatelessWidget {
  final int index;
  final String title;
  final IconData icon;
  final bool expanded;
  final VoidCallback onToggle;
  final Widget child;

  const _Section({
    required this.index,
    required this.title,
    required this.icon,
    required this.expanded,
    required this.onToggle,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: context.appSurface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: context.appBorder),
      ),
      child: Column(
        children: [
          InkWell(
            onTap: onToggle,
            borderRadius: BorderRadius.vertical(
              top: const Radius.circular(10),
              bottom: Radius.circular(expanded ? 0 : 10),
            ),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
              decoration: BoxDecoration(
                color: context.appSurface2,
                borderRadius: BorderRadius.vertical(
                  top: const Radius.circular(10),
                  bottom: Radius.circular(expanded ? 0 : 10),
                ),
              ),
              child: Row(
                children: [
                  Icon(icon, size: 14, color: AppDS.accent),
                  const SizedBox(width: 8),
                  Text(
                    title,
                    style: GoogleFonts.spaceGrotesk(
                      color: context.appTextSecondary,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.8,
                    ),
                  ),
                  const Spacer(),
                  Icon(
                    expanded ? Icons.expand_less : Icons.expand_more,
                    size: 18,
                    color: context.appTextMuted,
                  ),
                ],
              ),
            ),
          ),
          if (expanded) ...[
            Divider(height: 1, color: context.appBorder),
            Padding(padding: const EdgeInsets.all(14), child: child),
          ],
        ],
      ),
    );
  }
}

// ─── Layout helpers ──────────────────────────────────────────────────────────
class _FieldRow extends StatelessWidget {
  final List<Widget> children;
  const _FieldRow({required this.children});

  @override
  Widget build(BuildContext context) {
    return Row(
      children:
          children
              .expand((w) => [Expanded(child: w), const SizedBox(width: 10)])
              .toList()
            ..removeLast(),
    );
  }
}

class _InlineField extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final int maxLines;
  final TextInputType? keyboardType;
  final bool readOnly;

  const _InlineField({
    required this.label,
    required this.controller,
    this.maxLines = 1,
    this.keyboardType,
    this.readOnly = false,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      keyboardType: keyboardType,
      readOnly: readOnly,
      style: GoogleFonts.spaceGrotesk(
        color: readOnly ? context.appTextSecondary : context.appTextPrimary,
        fontSize: 13,
      ),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: GoogleFonts.spaceGrotesk(
          color: context.appTextSecondary,
          fontSize: 11,
        ),
        filled: true,
        fillColor: readOnly ? context.appSurface2 : context.appSurface3,
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
          borderSide: BorderSide(
            color: readOnly ? context.appBorder : AppDS.accent,
          ),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 10,
        ),
      ),
    );
  }
}

class _InlineDropdown<T> extends StatelessWidget {
  final String label;
  final T value;
  final List<DropdownMenuItem<T>> items;
  final void Function(T?) onChanged;
  final bool readOnly;

  const _InlineDropdown({
    required this.label,
    required this.value,
    required this.items,
    required this.onChanged,
    this.readOnly = false,
  });

  @override
  Widget build(BuildContext context) {
    return InputDecorator(
      decoration: InputDecoration(
        labelText: label,
        labelStyle: GoogleFonts.spaceGrotesk(
          color: context.appTextSecondary,
          fontSize: 11,
        ),
        filled: true,
        fillColor: readOnly ? context.appSurface2 : context.appSurface3,
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
            color: readOnly ? context.appTextSecondary : context.appTextPrimary,
            fontSize: 13,
          ),
          items: items,
          onChanged: readOnly
              ? null
              : (value) {
                  onChanged(value);
                  FocusManager.instance.primaryFocus?.unfocus();
                },
          disabledHint: _disabledHint(context),
          icon: readOnly
              ? const SizedBox.shrink()
              : const Icon(Icons.arrow_drop_down),
        ),
      ),
    );
  }

  Widget? _disabledHint(BuildContext context) {
    final match = items.where((i) => i.value == value).toList();
    if (match.isEmpty) return null;
    return DefaultTextStyle.merge(
      style: GoogleFonts.spaceGrotesk(
        color: context.appTextSecondary,
        fontSize: 13,
      ),
      child: match.first.child,
    );
  }
}

class _DateField extends StatelessWidget {
  final String label;
  final DateTime? date;
  final VoidCallback onTap;
  final VoidCallback onClear;
  final bool danger;
  final bool warning;
  final bool readOnly;

  const _DateField({
    required this.label,
    required this.date,
    required this.onTap,
    required this.onClear,
    this.danger = false,
    this.warning = false,
    this.readOnly = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = danger
        ? AppDS.red
        : warning
        ? AppDS.yellow
        : AppDS.accent;
    return GestureDetector(
      onTap: readOnly ? null : onTap,
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          labelStyle: GoogleFonts.spaceGrotesk(
            color: context.appTextSecondary,
            fontSize: 11,
          ),
          filled: true,
          fillColor: readOnly ? context.appSurface2 : context.appSurface3,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(
              color: (danger || warning)
                  ? color.withValues(alpha: 0.5)
                  : context.appBorder,
            ),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(
              color: (danger || warning)
                  ? color.withValues(alpha: 0.5)
                  : context.appBorder,
            ),
          ),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 10,
          ),
          suffixIcon: readOnly
              ? null
              : date != null
              ? GestureDetector(
                  onTap: onClear,
                  child: Icon(
                    Icons.clear,
                    size: 16,
                    color: context.appTextMuted,
                  ),
                )
              : const Icon(Icons.calendar_today_outlined, size: 14),
        ),
        child: Text(
          date != null
              ? '${date!.year}-${date!.month.toString().padLeft(2, '0')}-${date!.day.toString().padLeft(2, '0')}'
              : '—',
          style: GoogleFonts.spaceGrotesk(
            color: date != null
                ? (danger || warning ? color : context.appTextPrimary)
                : context.appTextMuted,
            fontSize: 13,
          ),
        ),
      ),
    );
  }
}

// ─── Badges ──────────────────────────────────────────────────────────────────
class _Badge extends StatelessWidget {
  final String label;
  final Color color;
  const _Badge({required this.label, required this.color});

  @override
  Widget build(BuildContext context) => Container(
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
