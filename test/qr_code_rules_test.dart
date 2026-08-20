import 'package:flutter_test/flutter_test.dart';
import 'package:limsphere/camera/qr_scanner/qr_code_rules.dart';

void main() {
  group('QrRules', () {
    test('builds the canonical LIMSphere deep-link format', () {
      expect(
        QrRules.build('Project_Code', 'reagents', 42),
        'limsphere://project_code/reagents/42',
      );
    });

    test('parses every supported category', () {
      for (final category in QrRules.validTypes) {
        final payload = QrRules.parse('limsphere://project-1/$category/123');
        expect(payload, isNotNull, reason: category);
        expect(payload!.projectCode, 'project-1');
        expect(payload.type, category);
        expect(payload.id, 123);
      }
    });

    test('keeps legacy printed codes readable but not canonical', () {
      const oldCode = 'bluelims://project-1/samples/7';
      expect(QrRules.parse(oldCode), isNotNull);
      expect(QrRules.isCanonical(oldCode), isFalse);
    });

    test('rejects malformed paths, unknown categories, and invalid ids', () {
      expect(QrRules.parse('limsphere://project/reagents/1/extra'), isNull);
      expect(QrRules.parse('limsphere://project/unknown/1'), isNull);
      expect(QrRules.parse('limsphere://project/reagents/0'), isNull);
      expect(QrRules.parse('https://project/reagents/1'), isNull);
    });

    test('detects links belonging to another project', () {
      final payload = QrRules.parse('limsphere://project-a/strains/9')!;
      expect(QrRules.belongsToProject(payload, 'PROJECT-A'), isTrue);
      expect(QrRules.belongsToProject(payload, 'project-b'), isFalse);
    });
  });
}
