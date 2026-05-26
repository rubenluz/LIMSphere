import 'package:flutter_test/flutter_test.dart';
import 'package:limsphere/theme/module_permission.dart';

void main() {
  group('module permissions', () {
    test('legacy backups see permission resolves to read-only access', () {
      final access = resolveModuleAccess(
        moduleId: 'backups',
        userRow: const {'user_role': 'researcher', 'user_table_backups': 'see'},
      );

      expect(access.pagePermission, 'read');
      expect(access.canView, isTrue);
      expect(access.canMutate, isFalse);
      expect(access.isReadOnly, isTrue);
    });

    test('page permission helper accepts see as read-only access', () {
      final access = moduleAccessFromPagePermission('backups', 'see');

      expect(access.pagePermission, 'read');
      expect(access.canView, isTrue);
      expect(access.canMutate, isFalse);
    });
  });
}
