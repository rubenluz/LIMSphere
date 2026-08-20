import 'package:supabase_flutter/supabase_flutter.dart';

import '/core/sop_db_schema.dart';
import 'qr_code_rules.dart';

class QrRecordSpec {
  final String table;
  final String idColumn;
  final String moduleId;
  final String categoryLabel;
  final String selectColumns;
  final String? notesColumn;
  final String? cacheKey;

  const QrRecordSpec({
    required this.table,
    required this.idColumn,
    required this.moduleId,
    required this.categoryLabel,
    required this.selectColumns,
    this.notesColumn,
    this.cacheKey,
  });
}

QrRecordSpec qrRecordSpecForType(String type) => switch (type) {
  'machines' => const QrRecordSpec(
    table: 'equipment',
    idColumn: 'equipment_id',
    moduleId: 'equipment',
    categoryLabel: 'Machine',
    selectColumns:
        'equipment_id,equipment_name,equipment_status,equipment_notes',
    notesColumn: 'equipment_notes',
    cacheKey: 'machines',
  ),
  'reagents' => const QrRecordSpec(
    table: 'reagents',
    idColumn: 'reagent_id',
    moduleId: 'reagents',
    categoryLabel: 'Reagent',
    selectColumns: 'reagent_id,reagent_code,reagent_name,reagent_stock_status,reagent_notes',
    notesColumn: 'reagent_notes',
    cacheKey: 'reagents',
  ),
  'locations' => const QrRecordSpec(
    table: 'storage_locations',
    idColumn: 'location_id',
    moduleId: 'locations',
    categoryLabel: 'Location',
    selectColumns:
        'location_id,location_code,location_name,location_type,location_notes',
    notesColumn: 'location_notes',
    cacheKey: 'locations',
  ),
  'strains' => const QrRecordSpec(
    table: 'strains',
    idColumn: 'strain_id',
    moduleId: 'strains',
    categoryLabel: 'Strain',
    selectColumns: 'strain_id,strain_code,strain_scientific_name,strain_status,strain_notes',
    notesColumn: 'strain_notes',
    cacheKey: 'strains',
  ),
  'samples' => const QrRecordSpec(
    table: 'samples',
    idColumn: 'sample_id',
    moduleId: 'samples',
    categoryLabel: 'Sample',
    selectColumns: 'sample_id,sample_code,sample_local,sample_observations',
    notesColumn: 'sample_observations',
    cacheKey: 'samples',
  ),
  'fish_lines' => const QrRecordSpec(
    table: 'fish_lines',
    idColumn: 'fish_line_id',
    moduleId: 'fish_lines',
    categoryLabel: 'Fish line',
    selectColumns: 'fish_line_id,fish_line_name,fish_line_alias,fish_line_status,fish_line_notes',
    notesColumn: 'fish_line_notes',
    cacheKey: 'fish_lines',
  ),
  'fish_stocks' => const QrRecordSpec(
    table: 'fish_stocks',
    idColumn: 'fish_stocks_id',
    moduleId: 'fish_stock',
    categoryLabel: 'Fish stock',
    selectColumns: 'fish_stocks_id,fish_stocks_tank_id,fish_stocks_line,fish_stocks_status,fish_stocks_health_status,fish_stocks_notes',
    notesColumn: 'fish_stocks_notes',
    cacheKey: 'fish_stocks',
  ),
  'sops' => QrRecordSpec(
    table: SopSch.table,
    idColumn: SopSch.id,
    moduleId: 'sops_fish',
    categoryLabel: 'SOP',
    selectColumns: '${SopSch.id},${SopSch.name},${SopSch.status},sop_context',
    cacheKey: 'facility_sops',
  ),
  'users' => const QrRecordSpec(
    table: 'users',
    idColumn: 'user_id',
    moduleId: 'users',
    categoryLabel: 'User',
    selectColumns: 'user_id,user_name,user_email,user_role',
    cacheKey: 'users',
  ),
  _ => throw StateError('Unhandled QR category: $type'),
};

class QrRecordSummary {
  final QrPayload payload;
  final QrRecordSpec spec;
  final String title;
  final String? subtitle;
  final String? status;
  final String? notes;

  const QrRecordSummary({
    required this.payload,
    required this.spec,
    required this.title,
    this.subtitle,
    this.status,
    this.notes,
  });

  QrRecordSummary withNotes(String? value) => QrRecordSummary(
    payload: payload,
    spec: spec,
    title: title,
    subtitle: subtitle,
    status: status,
    notes: value,
  );
}

class QrRecordNotFoundException implements Exception {
  final QrPayload payload;

  const QrRecordNotFoundException(this.payload);

  @override
  String toString() =>
      'No ${payload.type.replaceAll('_', ' ')} record exists with ID ${payload.id}.';
}

Future<QrRecordSummary> lookupQrRecord(QrPayload payload) async {
  var spec = qrRecordSpecForType(payload.type);
  final row = await Supabase.instance.client
      .from(spec.table)
      .select(spec.selectColumns)
      .eq(spec.idColumn, payload.id)
      .maybeSingle();
  if (row == null) throw QrRecordNotFoundException(payload);

  if (payload.type == 'users') await _ensureUserMayOpen(payload.id);
  if (payload.type == 'sops' && row['sop_context'] == 'culture_collection') {
    spec = QrRecordSpec(
      table: spec.table,
      idColumn: spec.idColumn,
      moduleId: 'sops_inventory',
      categoryLabel: spec.categoryLabel,
      selectColumns: spec.selectColumns,
      cacheKey: spec.cacheKey,
    );
  }

  String text(String key) => row[key]?.toString().trim() ?? '';
  String? optional(String key) {
    final value = text(key);
    return value.isEmpty ? null : value;
  }

  late String title;
  String? subtitle;
  String? status;
  switch (payload.type) {
    case 'machines':
      title = optional('equipment_name') ?? 'Machine #${payload.id}';
      status = optional('equipment_status');
    case 'reagents':
      final code = optional('reagent_code');
      final name = optional('reagent_name');
      title = [code, name].whereType<String>().join(' — ');
      if (title.isEmpty) title = 'Reagent #${payload.id}';
      status = optional('reagent_stock_status');
    case 'locations':
      final code = optional('location_code');
      final name = optional('location_name');
      title = [code, name].whereType<String>().join(' — ');
      if (title.isEmpty) title = 'Location #${payload.id}';
      subtitle = optional('location_type');
    case 'strains':
      title = optional('strain_code') ?? 'Strain #${payload.id}';
      subtitle = optional('strain_scientific_name');
      status = optional('strain_status');
    case 'samples':
      final code = optional('sample_code');
      title = code == null ? 'Sample #${payload.id}' : 'Sample $code';
      subtitle = optional('sample_local');
    case 'fish_lines':
      title = optional('fish_line_name') ?? 'Fish line #${payload.id}';
      subtitle = optional('fish_line_alias');
      status = optional('fish_line_status');
    case 'fish_stocks':
      final tank = optional('fish_stocks_tank_id');
      title = tank == null ? 'Fish stock #${payload.id}' : 'Tank $tank';
      subtitle = optional('fish_stocks_line');
      status =
          optional('fish_stocks_health_status') ??
          optional('fish_stocks_status');
    case 'sops':
      title = optional(SopSch.name) ?? 'SOP #${payload.id}';
      status = optional(SopSch.status);
    case 'users':
      title =
          optional('user_name') ??
          optional('user_email') ??
          'User #${payload.id}';
      subtitle = optional('user_email');
      status = optional('user_role');
  }

  return QrRecordSummary(
    payload: payload,
    spec: spec,
    title: title,
    subtitle: subtitle,
    status: status,
    notes: spec.notesColumn == null ? null : optional(spec.notesColumn!),
  );
}

Future<void> _ensureUserMayOpen(int targetUserId) async {
  final viewerEmail =
      Supabase.instance.client.auth.currentSession?.user.email ??
      Supabase.instance.client.auth.currentUser?.email ??
      '';
  if (viewerEmail.isEmpty) throw Exception('Access denied.');

  final viewer = await Supabase.instance.client
      .from('users')
      .select('user_id,user_role')
      .eq('user_email', viewerEmail)
      .maybeSingle();
  final viewerId = int.tryParse(viewer?['user_id']?.toString() ?? '');
  final viewerRole = viewer?['user_role']?.toString() ?? '';
  if (viewerId != targetUserId &&
      viewerRole != 'admin' &&
      viewerRole != 'superadmin') {
    throw Exception('Access denied.');
  }
}
