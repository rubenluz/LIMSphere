import 'package:flutter_test/flutter_test.dart';
import 'package:limsphere/camera/qr_scanner/qr_code_rules.dart';
import 'package:limsphere/camera/qr_scanner/qr_record_lookup.dart';

void main() {
  test('every valid QR category has a record lookup specification', () {
    for (final type in QrRules.validTypes) {
      final spec = qrRecordSpecForType(type);
      expect(spec.table, isNotEmpty, reason: type);
      expect(spec.idColumn, isNotEmpty, reason: type);
      expect(spec.moduleId, isNotEmpty, reason: type);
      expect(spec.selectColumns.split(','), contains(spec.idColumn));
    }
  });

  test('safe quick notes are disabled for users and SOPs', () {
    expect(qrRecordSpecForType('users').notesColumn, isNull);
    expect(qrRecordSpecForType('sops').notesColumn, isNull);
  });

  test('record categories with ordinary notes expose their correct field', () {
    expect(qrRecordSpecForType('samples').notesColumn, 'sample_observations');
    expect(qrRecordSpecForType('reagents').notesColumn, 'reagent_notes');
    expect(qrRecordSpecForType('machines').notesColumn, 'equipment_notes');
    expect(qrRecordSpecForType('locations').notesColumn, 'location_notes');
  });
}
