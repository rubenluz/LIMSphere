import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:limsphere/theme/module_permission.dart';

void main() {
  group('module permissions', () {
    test('laboratory SOP subcategories inherit Resources access', () {
      final access = resolveModuleAccess(
        moduleId: 'sops_resources',
        userRow: const {
          'user_status': 'active',
          'user_role': 'technician',
          'user_table_resources': 'read',
        },
      );

      expect(access.canView, isTrue);
      expect(access.canMutate, isFalse);
    });

    test(
      'pending account gets no access even when permissions are assigned',
      () {
        final access = resolveModuleAccess(
          moduleId: 'strains',
          userRow: const {
            'user_status': 'pending',
            'user_role': 'admin',
            'user_table_culture_collection': 'write',
            'user_permissions_json': {
              'pages': {
                'strains': {
                  'page_access': 'write',
                  'actions': {'approve': true},
                },
              },
            },
          },
        );

        expect(access.canView, isFalse);
        expect(access.canMutate, isFalse);
        expect(access.canApprove, isFalse);
      },
    );

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

    test('active superadmin has reagent insert and edit access', () {
      final access = resolveModuleAccess(
        moduleId: 'reagents',
        userRow: const {
          'user_status': 'active',
          'user_role': 'superadmin',
          'user_table_resources': 'none',
        },
      );

      expect(access.canView, isTrue);
      expect(access.canInsert, isTrue);
      expect(access.canEdit, isTrue);
    });

    test('active users always have Tools access without permissions', () {
      final access = resolveModuleAccess(
        moduleId: 'tools',
        userRow: const {
          'user_status': 'active',
          'user_role': 'viewer',
          'user_permissions_json': {
            'pages': {
              'tools': {
                'page_access': 'none',
                'actions': {'view': false, 'export': false},
              },
            },
          },
        },
      );

      expect(access.canView, isTrue);
      expect(access.canExport, isTrue);
    });

    test('active technician with Resources write can create reagents', () {
      final access = resolveModuleAccess(
        moduleId: 'reagents',
        userRow: const {
          'user_status': 'active',
          'user_role': 'technician',
          'user_table_resources': 'write',
        },
      );

      expect(access.canView, isTrue);
      expect(access.canInsert, isTrue);
    });

    test('granular reagent insert permission allows creation', () {
      final access = resolveModuleAccess(
        moduleId: 'reagents',
        userRow: const {
          'user_status': 'active',
          'user_role': 'technician',
          'user_table_resources': 'read',
          'user_permissions_json': {
            'pages': {
              'reagents': {
                'page_access': 'read',
                'actions': {'insert': true, 'edit': false},
              },
            },
          },
        },
      );

      expect(access.canView, isTrue);
      expect(access.canInsert, isTrue);
      expect(access.canEdit, isFalse);
    });

    testWidgets('dialog can inherit reagent insert access', (tester) async {
      const access = ModuleAccess.full(moduleId: 'reagents');

      await tester.pumpWidget(
        MaterialApp(
          home: ModulePermission(
            access: access,
            child: Builder(
              builder: (pageContext) => TextButton(
                onPressed: () => showDialog<void>(
                  context: pageContext,
                  builder: (_) => ModulePermission.inherit(
                    pageContext,
                    Builder(
                      builder: (dialogContext) => Text(
                        dialogContext.canInsertModule
                            ? 'insert allowed'
                            : 'insert denied',
                      ),
                    ),
                  ),
                ),
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      expect(find.text('insert allowed'), findsOneWidget);
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
