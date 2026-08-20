import 'package:supabase_flutter/supabase_flutter.dart';

class LabMention {
  final String type;
  final int id;
  final String label;
  final String? detail;

  const LabMention({
    required this.type,
    required this.id,
    required this.label,
    this.detail,
  });

  String get token => '@[$type:$id $label]';
}

class _MentionSpec {
  final String type;
  final String table;
  final String idColumn;
  final String selectColumns;
  final List<String> searchColumns;
  final String? filterColumn;
  final Object? filterValue;
  final String Function(Map<String, dynamic>) label;
  final String? Function(Map<String, dynamic>) detail;

  const _MentionSpec({
    required this.type,
    required this.table,
    required this.idColumn,
    required this.selectColumns,
    required this.searchColumns,
    this.filterColumn,
    this.filterValue,
    required this.label,
    required this.detail,
  });
}

String? _value(Map<String, dynamic> row, String key) {
  final value = row[key]?.toString().trim();
  return value == null || value.isEmpty ? null : value;
}

String _first(Map<String, dynamic> row, List<String> keys, String fallback) =>
    keys.map((key) => _value(row, key)).whereType<String>().firstOrNull ??
    fallback;

String? _combine(Map<String, dynamic> row, List<String> keys) {
  final values = keys.map((key) => _value(row, key)).whereType<String>();
  final joined = values.join(' · ');
  return joined.isEmpty ? null : joined;
}

final _mentionSpecs = <_MentionSpec>[
  _MentionSpec(
    type: 'users',
    table: 'users',
    idColumn: 'user_id',
    selectColumns: 'user_id,user_name,user_email,user_institution',
    searchColumns: ['user_name', 'user_email', 'user_institution'],
    label: (row) => _first(row, ['user_name', 'user_email'], 'User'),
    detail: (row) => _combine(row, ['user_email', 'user_institution']),
  ),
  _MentionSpec(
    type: 'strains',
    table: 'strains',
    idColumn: 'strain_id',
    selectColumns: 'strain_id,strain_code,strain_scientific_name',
    searchColumns: ['strain_code', 'strain_scientific_name'],
    label: (row) => _first(row, ['strain_code'], 'Strain'),
    detail: (row) => _value(row, 'strain_scientific_name'),
  ),
  _MentionSpec(
    type: 'samples',
    table: 'samples',
    idColumn: 'sample_id',
    selectColumns: 'sample_id,sample_code,sample_local',
    searchColumns: ['sample_code', 'sample_local'],
    label: (row) => _first(row, ['sample_code'], 'Sample'),
    detail: (row) => _value(row, 'sample_local'),
  ),
  _MentionSpec(
    type: 'fish_stocks',
    table: 'fish_stocks',
    idColumn: 'fish_stocks_id',
    selectColumns: 'fish_stocks_id,fish_stocks_tank_id,fish_stocks_line',
    searchColumns: ['fish_stocks_tank_id', 'fish_stocks_line'],
    label: (row) => _first(row, ['fish_stocks_tank_id'], 'Fish stock'),
    detail: (row) => _value(row, 'fish_stocks_line'),
  ),
  _MentionSpec(
    type: 'fish_lines',
    table: 'fish_lines',
    idColumn: 'fish_line_id',
    selectColumns: 'fish_line_id,fish_line_name,fish_line_alias',
    searchColumns: ['fish_line_name', 'fish_line_alias'],
    label: (row) =>
        _first(row, ['fish_line_name', 'fish_line_alias'], 'Fish line'),
    detail: (row) => _value(row, 'fish_line_alias'),
  ),
  _MentionSpec(
    type: 'reagents',
    table: 'reagents',
    idColumn: 'reagent_id',
    selectColumns: 'reagent_id,reagent_code,reagent_name',
    searchColumns: ['reagent_code', 'reagent_name'],
    label: (row) {
      final code = _value(row, 'reagent_code');
      final name = _value(row, 'reagent_name');
      if (code != null && name != null) return '$code · $name';
      return code ?? name ?? 'Reagent #${row['reagent_id']}';
    },
    detail: (_) => null,
  ),
  _MentionSpec(
    type: 'machines',
    table: 'equipment',
    idColumn: 'equipment_id',
    selectColumns: 'equipment_id,equipment_name,equipment_patrimony_number,equipment_serial_number,equipment_room',
    searchColumns: [
      'equipment_name',
      'equipment_patrimony_number',
      'equipment_serial_number',
      'equipment_room',
    ],
    label: (row) {
      final number = _first(row, [
        'equipment_patrimony_number',
        'equipment_serial_number',
      ], '#${row['equipment_id']}');
      final name = _value(row, 'equipment_name');
      return name == null ? number : '$number · $name';
    },
    detail: (row) => _value(row, 'equipment_room'),
  ),
  _MentionSpec(
    type: 'locations',
    table: 'storage_locations',
    idColumn: 'location_id',
    selectColumns:
        'location_id,location_code,location_name,location_type,location_room',
    searchColumns: ['location_code', 'location_name', 'location_room'],
    filterColumn: 'location_type',
    filterValue: 'room',
    label: (row) {
      final number = _value(row, 'location_code') ?? '#${row['location_id']}';
      final name = _value(row, 'location_name');
      return name == null ? number : '$number · $name';
    },
    detail: (row) => _value(row, 'location_room'),
  ),
];

class LabMentionSearch {
  final SupabaseClient client;

  const LabMentionSearch(this.client);

  static String normalize(String input) => input
      .replaceAll(RegExp(r'[\x00-\x1F\x7F,()"\\*%_]'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();

  Future<List<LabMention>> search(String input, {int perType = 4}) async {
    final query = normalize(input);
    if (query.isEmpty) return const [];
    final numericId = int.tryParse(query);
    final batches = await Future.wait(
      _mentionSpecs.map(
        (spec) =>
            _searchSpec(spec, query, numericId: numericId, limit: perType),
      ),
    );
    final results = batches.expand((batch) => batch).toList();
    results.sort((a, b) {
      final aExact = a.label.toLowerCase() == query.toLowerCase();
      final bExact = b.label.toLowerCase() == query.toLowerCase();
      if (aExact != bExact) return aExact ? -1 : 1;
      return a.label.toLowerCase().compareTo(b.label.toLowerCase());
    });
    return results;
  }

  Future<List<LabMention>> _searchSpec(
    _MentionSpec spec,
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
      var request = client
          .from(spec.table)
          .select(spec.selectColumns)
          .or(filters.join(','));
      if (spec.filterColumn != null) {
        request = request.eq(spec.filterColumn!, spec.filterValue!);
      }
      final rows = await request.limit(limit);
      return (rows as List)
          .map((raw) {
            final row = Map<String, dynamic>.from(raw as Map);
            final id = int.tryParse(row[spec.idColumn]?.toString() ?? '');
            if (id == null || id < 1) return null;
            return LabMention(
              type: spec.type,
              id: id,
              label: spec.label(row),
              detail: spec.detail(row),
            );
          })
          .whereType<LabMention>()
          .toList();
    } catch (_) {
      return const [];
    }
  }
}
