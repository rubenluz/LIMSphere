import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '/camera/qr_scanner/qr_code_rules.dart';
import '/camera/qr_scanner/qr_scanner_page.dart';
import '/supabase/supabase_manager.dart';
import '/theme/theme.dart';

class GlobalSearchResult {
  final String type;
  final int id;
  final String category;
  final String title;
  final String? subtitle;
  final String? status;

  const GlobalSearchResult({
    required this.type,
    required this.id,
    required this.category,
    required this.title,
    this.subtitle,
    this.status,
  });
}

class _GlobalSearchSpec {
  final String type;
  final String table;
  final String idColumn;
  final String category;
  final String selectColumns;
  final List<String> searchColumns;
  final String Function(Map<String, dynamic>) title;
  final String? Function(Map<String, dynamic>) subtitle;
  final String? Function(Map<String, dynamic>) status;

  const _GlobalSearchSpec({
    required this.type,
    required this.table,
    required this.idColumn,
    required this.category,
    required this.selectColumns,
    required this.searchColumns,
    required this.title,
    required this.subtitle,
    required this.status,
  });
}

String? _text(Map<String, dynamic> row, String key) {
  final value = row[key]?.toString().trim();
  return value == null || value.isEmpty ? null : value;
}

String? _joined(Map<String, dynamic> row, List<String> keys) {
  final values = keys.map((key) => _text(row, key)).whereType<String>();
  final value = values.join(' · ');
  return value.isEmpty ? null : value;
}

const _searchSpecs = <_GlobalSearchSpec>[
  _GlobalSearchSpec(
    type: 'strains',
    table: 'strains',
    idColumn: 'strain_id',
    category: 'Strain',
    selectColumns: 'strain_id,strain_code,strain_scientific_name,strain_status',
    searchColumns: [
      'strain_code',
      'strain_scientific_name',
      'strain_status',
      'strain_notes',
    ],
    title: _strainTitle,
    subtitle: _strainSubtitle,
    status: _strainStatus,
  ),
  _GlobalSearchSpec(
    type: 'samples',
    table: 'samples',
    idColumn: 'sample_id',
    category: 'Sample',
    selectColumns: 'sample_id,sample_code,sample_local,sample_country',
    searchColumns: [
      'sample_code',
      'sample_local',
      'sample_country',
      'sample_observations',
    ],
    title: _sampleTitle,
    subtitle: _sampleSubtitle,
    status: _noStatus,
  ),
  _GlobalSearchSpec(
    type: 'fish_lines',
    table: 'fish_lines',
    idColumn: 'fish_line_id',
    category: 'Fish line',
    selectColumns: 'fish_line_id,fish_line_name,fish_line_alias,fish_line_status,fish_line_genotype',
    searchColumns: [
      'fish_line_name',
      'fish_line_alias',
      'fish_line_status',
      'fish_line_genotype',
      'fish_line_affected_gene',
      'fish_line_notes',
      'fish_line_qrcode',
      'fish_line_barcode',
    ],
    title: _fishLineTitle,
    subtitle: _fishLineSubtitle,
    status: _fishLineStatus,
  ),
  _GlobalSearchSpec(
    type: 'fish_stocks',
    table: 'fish_stocks',
    idColumn: 'fish_stocks_id',
    category: 'Fish tank',
    selectColumns: 'fish_stocks_id,fish_stocks_tank_id,fish_stocks_line,fish_stocks_status,fish_stocks_health_status',
    searchColumns: [
      'fish_stocks_tank_id',
      'fish_stocks_line',
      'fish_stocks_status',
      'fish_stocks_health_status',
      'fish_stocks_responsible',
      'fish_stocks_experiment_id',
      'fish_stocks_notes',
      'fish_stocks_qrcode',
    ],
    title: _fishStockTitle,
    subtitle: _fishStockSubtitle,
    status: _fishStockStatus,
  ),
  _GlobalSearchSpec(
    type: 'reagents',
    table: 'reagents',
    idColumn: 'reagent_id',
    category: 'Reagent',
    selectColumns: 'reagent_id,reagent_code,reagent_name,reagent_category,reagent_brand,reagent_stock_status',
    searchColumns: [
      'reagent_code',
      'reagent_name',
      'reagent_category',
      'reagent_subcategory',
      'reagent_brand',
      'reagent_reference',
      'reagent_cas_number',
      'reagent_synonyms',
      'reagent_lot_number',
      'reagent_supplier',
      'reagent_formula',
      'reagent_tags',
      'reagent_notes',
      'reagent_qrcode',
    ],
    title: _reagentTitle,
    subtitle: _reagentSubtitle,
    status: _reagentStatus,
  ),
  _GlobalSearchSpec(
    type: 'machines',
    table: 'equipment',
    idColumn: 'equipment_id',
    category: 'Machine',
    selectColumns: 'equipment_id,equipment_name,equipment_type,equipment_brand,equipment_model,equipment_status',
    searchColumns: [
      'equipment_name',
      'equipment_type',
      'equipment_brand',
      'equipment_model',
      'equipment_serial_number',
      'equipment_patrimony_number',
      'equipment_status',
      'equipment_room',
      'equipment_responsible',
      'equipment_supplier',
      'equipment_notes',
      'equipment_qrcode',
    ],
    title: _machineTitle,
    subtitle: _machineSubtitle,
    status: _machineStatus,
  ),
  _GlobalSearchSpec(
    type: 'locations',
    table: 'storage_locations',
    idColumn: 'location_id',
    category: 'Location',
    selectColumns:
        'location_id,location_code,location_name,location_type,location_room',
    searchColumns: [
      'location_code',
      'location_name',
      'location_type',
      'location_room',
      'location_temperature',
      'location_responsible',
      'location_notes',
      'location_qrcode',
    ],
    title: _locationTitle,
    subtitle: _locationSubtitle,
    status: _noStatus,
  ),
  _GlobalSearchSpec(
    type: 'sops',
    table: 'facility_sops',
    idColumn: 'sop_id',
    category: 'SOP',
    selectColumns: 'sop_id,sop_code,sop_name,sop_category,sop_status',
    searchColumns: [
      'sop_code',
      'sop_name',
      'sop_type',
      'sop_category',
      'sop_status',
      'sop_description',
      'sop_tags',
      'sop_responsible',
      'sop_author',
    ],
    title: _sopTitle,
    subtitle: _sopSubtitle,
    status: _sopStatus,
  ),
  _GlobalSearchSpec(
    type: 'users',
    table: 'users',
    idColumn: 'user_id',
    category: 'User',
    selectColumns: 'user_id,user_name,user_email,user_role,user_institution',
    searchColumns: [
      'user_name',
      'user_email',
      'user_role',
      'user_institution',
      'user_phone',
    ],
    title: _userTitle,
    subtitle: _userSubtitle,
    status: _userStatus,
  ),
];

String _fallback(Map<String, dynamic> row, String key, String label) =>
    _text(row, key) ?? '$label #${row.values.first}';
String _strainTitle(Map<String, dynamic> row) =>
    _fallback(row, 'strain_code', 'Strain');
String? _strainSubtitle(Map<String, dynamic> row) =>
    _text(row, 'strain_scientific_name');
String? _strainStatus(Map<String, dynamic> row) => _text(row, 'strain_status');
String _sampleTitle(Map<String, dynamic> row) =>
    _fallback(row, 'sample_code', 'Sample');
String? _sampleSubtitle(Map<String, dynamic> row) =>
    _joined(row, ['sample_local', 'sample_country']);
String _fishLineTitle(Map<String, dynamic> row) =>
    _fallback(row, 'fish_line_name', 'Fish line');
String? _fishLineSubtitle(Map<String, dynamic> row) =>
    _joined(row, ['fish_line_alias', 'fish_line_genotype']);
String? _fishLineStatus(Map<String, dynamic> row) =>
    _text(row, 'fish_line_status');
String _fishStockTitle(Map<String, dynamic> row) =>
    _text(row, 'fish_stocks_tank_id') == null
    ? 'Fish stock #${row['fish_stocks_id']}'
    : 'Tank ${row['fish_stocks_tank_id']}';
String? _fishStockSubtitle(Map<String, dynamic> row) =>
    _text(row, 'fish_stocks_line');
String? _fishStockStatus(Map<String, dynamic> row) =>
    _text(row, 'fish_stocks_health_status') ?? _text(row, 'fish_stocks_status');
String _reagentTitle(Map<String, dynamic> row) =>
    _joined(row, ['reagent_code', 'reagent_name']) ??
    'Reagent #${row['reagent_id']}';
String? _reagentSubtitle(Map<String, dynamic> row) =>
    _joined(row, ['reagent_category', 'reagent_brand']);
String? _reagentStatus(Map<String, dynamic> row) =>
    _text(row, 'reagent_stock_status');
String _machineTitle(Map<String, dynamic> row) =>
    _fallback(row, 'equipment_name', 'Machine');
String? _machineSubtitle(Map<String, dynamic> row) =>
    _joined(row, ['equipment_type', 'equipment_brand', 'equipment_model']);
String? _machineStatus(Map<String, dynamic> row) =>
    _text(row, 'equipment_status');
String _locationTitle(Map<String, dynamic> row) =>
    _joined(row, ['location_code', 'location_name']) ??
    'Location #${row['location_id']}';
String? _locationSubtitle(Map<String, dynamic> row) =>
    _joined(row, ['location_type', 'location_room']);
String _sopTitle(Map<String, dynamic> row) =>
    _joined(row, ['sop_code', 'sop_name']) ?? 'SOP #${row['sop_id']}';
String? _sopSubtitle(Map<String, dynamic> row) => _text(row, 'sop_category');
String? _sopStatus(Map<String, dynamic> row) => _text(row, 'sop_status');
String _userTitle(Map<String, dynamic> row) =>
    _text(row, 'user_name') ??
    _text(row, 'user_email') ??
    'User #${row['user_id']}';
String? _userSubtitle(Map<String, dynamic> row) =>
    _joined(row, ['user_email', 'user_institution']);
String? _userStatus(Map<String, dynamic> row) => _text(row, 'user_role');
String? _noStatus(Map<String, dynamic> _) => null;

class GlobalSearchService {
  final SupabaseClient client;

  const GlobalSearchService(this.client);

  static String normalizeQuery(String input) => input
      .replaceAll(RegExp(r'[\x00-\x1F\x7F,()"\\*%_]'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();

  Future<List<GlobalSearchResult>> search(
    String input, {
    bool includeUsers = false,
    int perCategory = 6,
  }) async {
    final query = normalizeQuery(input);
    if (query.length < 2) return const [];
    final numericId = int.tryParse(query);
    final specs = _searchSpecs.where(
      (spec) => includeUsers || spec.type != 'users',
    );
    final batches = await Future.wait(
      specs.map(
        (spec) =>
            _searchSpec(spec, query, numericId: numericId, limit: perCategory),
      ),
    );
    final results = batches.expand((batch) => batch).toList();
    results.sort((a, b) {
      final aExact = a.title.toLowerCase() == query.toLowerCase();
      final bExact = b.title.toLowerCase() == query.toLowerCase();
      if (aExact != bExact) return aExact ? -1 : 1;
      final byCategory = a.category.compareTo(b.category);
      return byCategory != 0 ? byCategory : a.title.compareTo(b.title);
    });
    return results;
  }

  Future<List<GlobalSearchResult>> _searchSpec(
    _GlobalSearchSpec spec,
    String query, {
    required int? numericId,
    required int limit,
  }) async {
    try {
      final filters = <String>[
        for (final column in spec.searchColumns) '$column.ilike.*$query*',
        if (numericId != null && numericId > 0)
          '${spec.idColumn}.eq.$numericId',
      ];
      final rows = await client
          .from(spec.table)
          .select(spec.selectColumns)
          .or(filters.join(','))
          .limit(limit);
      return (rows as List)
          .map((raw) {
            final row = Map<String, dynamic>.from(raw as Map);
            final id = int.tryParse(row[spec.idColumn]?.toString() ?? '');
            if (id == null || id < 1) return null;
            return GlobalSearchResult(
              type: spec.type,
              id: id,
              category: spec.category,
              title: spec.title(row),
              subtitle: spec.subtitle(row),
              status: spec.status(row),
            );
          })
          .whereType<GlobalSearchResult>()
          .toList();
    } catch (error) {
      debugPrint('Global search skipped ${spec.table}: $error');
      return const [];
    }
  }
}

class DashboardGlobalSearch extends StatefulWidget {
  final bool includeUsers;
  final bool compact;
  final Future<List<GlobalSearchResult>> Function(String query)? searchOverride;
  final Future<void> Function(GlobalSearchResult result)? openOverride;

  const DashboardGlobalSearch({
    super.key,
    this.includeUsers = false,
    this.compact = false,
    this.searchOverride,
    this.openOverride,
  });

  @override
  State<DashboardGlobalSearch> createState() => _DashboardGlobalSearchState();
}

class _DashboardGlobalSearchState extends State<DashboardGlobalSearch> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();
  final _fieldKey = GlobalKey();
  OverlayEntry? _overlayEntry;
  Timer? _debounce;
  List<GlobalSearchResult> _results = const [];
  bool _loading = false;
  bool _opening = false;
  int _searchGeneration = 0;

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(_syncOverlay);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _focusNode.removeListener(_syncOverlay);
    _hideOverlay();
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onChanged(String value) {
    _debounce?.cancel();
    final query = GlobalSearchService.normalizeQuery(value);
    if (query.length < 2) {
      _searchGeneration++;
      setState(() {
        _loading = false;
        _results = const [];
      });
      _syncOverlay();
      return;
    }
    setState(() {});
    _syncOverlay();
    _debounce = Timer(const Duration(milliseconds: 350), () => _search(value));
  }

  Future<void> _search(String value) async {
    final generation = ++_searchGeneration;
    setState(() => _loading = true);
    _syncOverlay();
    final results = widget.searchOverride != null
        ? await widget.searchOverride!(value)
        : await GlobalSearchService(SupabaseManager.client)
              .search(value, includeUsers: widget.includeUsers);
    if (!mounted || generation != _searchGeneration) return;
    setState(() {
      _loading = false;
      _results = results;
    });
    _syncOverlay();
  }

  void _syncOverlay() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final hasQuery =
          GlobalSearchService.normalizeQuery(_controller.text).length >= 2;
      final shouldShow =
          _focusNode.hasFocus && hasQuery && (!_loading || _results.isNotEmpty);
      if (shouldShow) {
        _showOverlay();
      } else {
        _hideOverlay();
      }
    });
  }

  void _showOverlay() {
    if (_overlayEntry != null) {
      _overlayEntry!.markNeedsBuild();
      return;
    }
    _overlayEntry = OverlayEntry(builder: _buildOverlayEntry);
    Overlay.of(context).insert(_overlayEntry!);
  }

  void _hideOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  Widget _buildOverlayEntry(BuildContext overlayContext) {
    final fieldContext = _fieldKey.currentContext;
    final fieldBox = fieldContext?.findRenderObject() as RenderBox?;
    if (fieldBox == null || !fieldBox.hasSize) {
      return const SizedBox.shrink();
    }
    final offset = fieldBox.localToGlobal(Offset.zero);
    return Stack(
      children: [
        Positioned.fill(
          child: GestureDetector(
            behavior: HitTestBehavior.translucent,
            onTap: _focusNode.unfocus,
          ),
        ),
        Positioned(
          left: offset.dx,
          top: offset.dy + fieldBox.size.height + 6,
          width: fieldBox.size.width,
          child: _buildResultsOverlay(),
        ),
      ],
    );
  }

  Future<void> _open(GlobalSearchResult result) async {
    if (_opening) return;
    final navigator = Navigator.of(context);
    _focusNode.unfocus();
    _hideOverlay();
    setState(() => _opening = true);
    try {
      if (widget.openOverride != null) {
        await widget.openOverride!(result);
        return;
      }
      final page = await resolveQrRoute(
        QrPayload(
          projectCode: SupabaseManager.projectRef ?? 'local',
          type: result.type,
          id: result.id,
        ),
      );
      if (!mounted) return;
      await navigator.push(MaterialPageRoute(builder: (_) => page));
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not open record: $error')),
        );
      }
    } finally {
      if (mounted) setState(() => _opening = false);
    }
  }

  IconData _iconFor(String type) => switch (type) {
    'strains' => Icons.biotech_outlined,
    'samples' => Icons.science_outlined,
    'fish_lines' => Icons.science_outlined,
    'fish_stocks' => Icons.set_meal_outlined,
    'reagents' => Icons.inventory_2_outlined,
    'machines' => Icons.precision_manufacturing_outlined,
    'locations' => Icons.place_outlined,
    'sops' => Icons.description_outlined,
    'users' => Icons.person_outline,
    _ => Icons.search,
  };

  Widget _buildResultsOverlay() {
    final hasQuery =
        GlobalSearchService.normalizeQuery(_controller.text).length >= 2;
    return Material(
      color: context.appSurface,
      elevation: 10,
      shadowColor: Colors.black26,
      borderRadius: BorderRadius.circular(10),
      clipBehavior: Clip.antiAlias,
      child: Container(
        constraints: const BoxConstraints(maxHeight: 320),
        decoration: BoxDecoration(
          border: Border.all(color: context.appBorder),
          borderRadius: BorderRadius.circular(10),
        ),
        child: _results.isEmpty && !_loading && hasQuery
            ? Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  'No accessible records found.',
                  style: TextStyle(color: context.appTextMuted, fontSize: 12),
                ),
              )
            : ListView.separated(
                shrinkWrap: true,
                padding: EdgeInsets.zero,
                itemCount: _results.length,
                separatorBuilder: (_, _) =>
                    Divider(height: 1, color: context.appBorder),
                itemBuilder: (context, index) {
                  final result = _results[index];
                  return Listener(
                    behavior: HitTestBehavior.opaque,
                    // Desktop text fields may process an outside click before
                    // ListTile.onTap. Start opening on pointer-down so removing
                    // the overlay cannot cancel the selected result.
                    onPointerDown: _opening
                        ? null
                        : (_) => unawaited(_open(result)),
                    child: ListTile(
                      dense: true,
                      leading: CircleAvatar(
                        radius: 17,
                        backgroundColor: AppDS.accent.withValues(alpha: 0.10),
                        child: Icon(
                          _iconFor(result.type),
                          size: 17,
                          color: AppDS.accent,
                        ),
                      ),
                      title: Text(
                        result.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Text(
                        [
                          result.category,
                          if (result.subtitle != null) result.subtitle!,
                          if (result.status != null)
                            result.status!.replaceAll('_', ' '),
                        ].join(' · '),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      trailing: const Icon(Icons.chevron_right_rounded),
                      // Retained for keyboard and accessibility activation.
                      onTap: _opening ? null : () => _open(result),
                    ),
                  );
                },
              ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      key: _fieldKey,
      child: TextField(
        controller: _controller,
        focusNode: _focusNode,
        // The overlay handles outside clicks itself. Prevent EditableText from
        // dismissing a result between pointer-down and pointer-up on desktop.
        onTapOutside: (_) {},
        onChanged: _onChanged,
        onSubmitted: (value) {
          _debounce?.cancel();
          if (GlobalSearchService.normalizeQuery(value).length >= 2) {
            _search(value);
          }
        },
        textInputAction: TextInputAction.search,
        style: TextStyle(fontSize: widget.compact ? 13 : null),
        decoration: InputDecoration(
          hintText: widget.compact ? 'Search database…' : 'Search strains, samples, fish, reagents, machines, locations, SOPs…',
          hintStyle: TextStyle(fontSize: widget.compact ? 13 : null),
          prefixIcon: const Icon(Icons.search_rounded, size: 20),
          prefixIconConstraints: const BoxConstraints(minWidth: 38),
          suffixIconConstraints: const BoxConstraints(minWidth: 38),
          suffixIcon: _loading
              ? const Padding(
                  padding: EdgeInsets.all(10),
                  child: SizedBox.square(
                    dimension: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                )
              : _controller.text.isEmpty
              ? null
              : IconButton(
                  tooltip: 'Clear search',
                  icon: const Icon(Icons.close_rounded, size: 18),
                  onPressed: () {
                    _controller.clear();
                    _onChanged('');
                    _focusNode.requestFocus();
                  },
                ),
          filled: true,
          fillColor: context.appSurface,
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(vertical: 9),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(9),
            borderSide: BorderSide(color: context.appBorder),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(9),
            borderSide: BorderSide(color: context.appBorder),
          ),
        ),
      ),
    );
  }
}
