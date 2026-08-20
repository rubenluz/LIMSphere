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

    test('granular actions override legacy write independently', () {
      final access = resolveModuleAccess(
        moduleId: 'strains',
        userRow: const {
          'user_role': 'researcher',
          'user_table_culture_collection': 'write',
          'user_permissions_json': {
            'pages': {
              'strains': {
                'actions': {
                  'insert': false,
                  'edit': true,
                  'delete': false,
                  'approve': false,
                  'export': true,
                  'print': false,
                  'bulk_update': false,
                },
              },
            },
          },
        },
      );

      expect(access.canView, isTrue);
      expect(access.canInsert, isFalse);
      expect(access.canEdit, isTrue);
      expect(access.canDelete, isFalse);
      expect(access.canApprove, isFalse);
      expect(access.canExport, isTrue);
      expect(access.canPrint, isFalse);
      expect(access.canBulkUpdate, isFalse);
    });

    test('create and bulk aliases resolve to stored action keys', () {
      const access = ModuleAccess(
        moduleId: 'samples',
        pagePermission: 'write',
        actions: {'view', 'insert', 'bulk_update'},
        scope: 'all',
        publicationAccess: 'inherit',
        responsibilityScope: 'inherit',
        recordLockBypass: false,
        workflowEditStates: [],
        hasGranularRules: true,
      );

      expect(access.allows('create'), isTrue);
      expect(access.allows('bulk'), isTrue);
      expect(access.allows('delete'), isFalse);
    });

    test('mutating action implies view but export alone does not', () {
      final editAccess = resolveModuleAccess(
        moduleId: 'samples',
        userRow: const {
          'user_role': 'researcher',
          'user_table_culture_collection': 'none',
          'user_permissions_json': {
            'pages': {
              'samples': {
                'actions': {'edit': true},
              },
            },
          },
        },
      );
      final exportAccess = resolveModuleAccess(
        moduleId: 'samples',
        userRow: const {
          'user_role': 'researcher',
          'user_table_culture_collection': 'none',
          'user_permissions_json': {
            'pages': {
              'samples': {
                'actions': {'export': true},
              },
            },
          },
        },
      );

      expect(editAccess.canView, isTrue);
      expect(editAccess.canEdit, isTrue);
      expect(exportAccess.canExport, isTrue);
      expect(exportAccess.canView, isFalse);
    });
  });
}
