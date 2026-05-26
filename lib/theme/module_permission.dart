// module_permission.dart - Module access resolution and inherited permission
// helpers. Supports the legacy module-level none/read/write columns plus a
// newer JSON-based granular permission layer for per-page actions and scopes.

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const kModulePermissionColumns = <String, String>{
  'dashboard': 'user_table_dashboard',
  'labels': 'user_table_labels',
  'chat': 'user_table_chat',
  'backups': 'user_table_backups',
  'strains': 'user_table_culture_collection',
  'samples': 'user_table_culture_collection',
  'sops_inventory': 'user_table_culture_collection',
  'fish_stock': 'user_table_fish_facility',
  'fish_tankmap': 'user_table_fish_facility',
  'fish_lines': 'user_table_fish_facility',
  'fish_water_qc': 'user_table_fish_facility',
  'sops_fish': 'user_table_fish_facility',
  'lab': 'user_table_resources',
  'locations': 'user_table_resources',
  'reagents': 'user_table_resources',
  'equipment': 'user_table_resources',
  'reservations': 'user_table_resources',
};

const kModuleRequiredRoles = <String, String?>{
  'dashboard': 'technician',
  'labels': 'technician',
  'chat': 'technician',
  'requests': null,
  'tools': null,
  'strains': null,
  'samples': 'technician',
  'sops_inventory': 'technician',
  'fish_stock': null,
  'fish_tankmap': 'technician',
  'fish_lines': 'technician',
  'fish_water_qc': 'technician',
  'sops_fish': 'technician',
  'lab': 'technician',
  'locations': 'technician',
  'reagents': 'technician',
  'equipment': 'technician',
  'reservations': 'technician',
  'audit': 'admin',
  'users': 'admin',
  'backups': null,
  'settings': 'admin',
};

const kPermissionModuleLabels = <String, String>{
  'dashboard': 'Dashboard',
  'labels': 'Labels',
  'chat': 'Chat',
  'backups': 'Backups',
  'requests': 'Requests',
  'tools': 'Tools',
  'strains': 'Strains',
  'samples': 'Samples',
  'sops_inventory': 'Culture SOPs',
  'fish_stock': 'Fish Stock',
  'fish_tankmap': 'Tank Map',
  'fish_lines': 'Fish Lines',
  'fish_water_qc': 'Water QC',
  'sops_fish': 'Fish SOPs',
  'lab': 'Lab Map',
  'locations': 'Locations',
  'reagents': 'Reagents',
  'equipment': 'Machines',
  'reservations': 'Reservations',
  'audit': 'Audit Log',
  'users': 'Users',
  'settings': 'Settings',
};

const kPermissionModuleGroups = <String, List<String>>{
  'Overview': ['dashboard', 'labels', 'chat', 'backups', 'requests', 'tools'],
  'Culture Collection': ['strains', 'samples', 'sops_inventory'],
  'Fish Facility': [
    'fish_stock',
    'fish_tankmap',
    'fish_lines',
    'fish_water_qc',
    'sops_fish',
  ],
  'Resources': ['lab', 'locations', 'reagents', 'equipment', 'reservations'],
  'Admin': ['audit', 'users', 'settings'],
};

const kPermissionActionKeys = <String>[
  'view',
  'insert',
  'edit',
  'delete',
  'approve',
  'export',
  'print',
  'bulk_update',
];

const kPermissionActionLabels = <String, String>{
  'view': 'View',
  'insert': 'Insert',
  'edit': 'Edit',
  'delete': 'Delete',
  'approve': 'Approve',
  'export': 'Export',
  'print': 'Print',
  'bulk_update': 'Bulk Update',
};

const kPermissionPageAccessOptions = <String>[
  'inherit',
  'none',
  'read',
  'write',
];

const kPermissionScopeOptions = <String>['own', 'team', 'institution', 'all'];

const kPermissionPublicationOptions = <String>[
  'inherit',
  'none',
  'internal',
  'external',
  'public',
];

const kPermissionResponsibilityOptions = <String>[
  'inherit',
  'own',
  'team',
  'institution',
  'collection',
  'all',
];

const _roleOrder = [
  'viewer',
  'technician',
  'researcher',
  'admin',
  'superadmin',
];
const _mutatingActionKeys = <String>{
  'insert',
  'edit',
  'delete',
  'approve',
  'bulk_update',
};

bool _hasRole(String userRole, String requiredRole) {
  final ui = _roleOrder.indexOf(userRole.toLowerCase());
  final ri = _roleOrder.indexOf(requiredRole.toLowerCase());
  if (ui == -1 || ri == -1) return false;
  return ui >= ri;
}

String _normalizeOption(String? value, List<String> options, String fallback) {
  if (value == null) return fallback;
  return options.contains(value) ? value : fallback;
}

String _normalizeLegacyPermissionValue(String? value) {
  switch (value?.trim().toLowerCase()) {
    case 'write':
      return 'write';
    case 'read':
    case 'see':
    case 'view':
      return 'read';
    default:
      return 'none';
  }
}

bool _asBool(dynamic value) {
  if (value is bool) return value;
  if (value is num) return value != 0;
  if (value is String) {
    final normalized = value.trim().toLowerCase();
    return normalized == 'true' || normalized == '1' || normalized == 'yes';
  }
  return false;
}

List<String> _stringList(dynamic value) {
  if (value is! List) return const [];
  return value
      .map((entry) => entry?.toString().trim() ?? '')
      .where((entry) => entry.isNotEmpty)
      .toList();
}

String resolveLegacyModulePermission({
  required String moduleId,
  required Map<String, dynamic> userRow,
}) {
  final userRole = userRow['user_role']?.toString() ?? '';
  if (_hasRole(userRole, 'admin')) return 'write';

  final requiredRole = kModuleRequiredRoles[moduleId];
  if (requiredRole != null && !_hasRole(userRole, requiredRole)) return 'none';

  final col = kModulePermissionColumns[moduleId];
  if (col == null) return 'write';
  return _normalizeLegacyPermissionValue(userRow[col]?.toString());
}

Map<String, dynamic> normalizeUserPermissionsJson(dynamic raw) {
  final normalized = <String, dynamic>{
    'version': 1,
    'pages': <String, dynamic>{},
  };
  if (raw is! Map) return normalized;

  final result = Map<String, dynamic>.from(raw);
  final pagesRaw = result['pages'];
  final pages = <String, dynamic>{};
  if (pagesRaw is Map) {
    for (final entry in pagesRaw.entries) {
      if (entry.key is String && entry.value is Map) {
        pages[entry.key as String] = Map<String, dynamic>.from(
          entry.value as Map,
        );
      }
    }
  }

  normalized['version'] = result['version'] ?? 1;
  normalized['pages'] = pages;
  return normalized;
}

Set<String> _defaultActionsForPagePermission(String permission) {
  switch (permission) {
    case 'write':
      return Set<String>.from(kPermissionActionKeys);
    case 'read':
      return <String>{'view'};
    default:
      return <String>{};
  }
}

ModuleAccess moduleAccessFromPagePermission(
  String moduleId,
  String permission,
) {
  final normalized = _normalizeLegacyPermissionValue(permission);
  return ModuleAccess(
    moduleId: moduleId,
    pagePermission: normalized,
    actions: _defaultActionsForPagePermission(normalized),
    scope: 'all',
    publicationAccess: 'inherit',
    responsibilityScope: 'inherit',
    recordLockBypass: false,
    workflowEditStates: const [],
    hasGranularRules: false,
  );
}

ModuleAccess resolveModuleAccess({
  required String moduleId,
  required Map<String, dynamic> userRow,
}) {
  final userRole = userRow['user_role']?.toString() ?? '';
  if (_hasRole(userRole, 'superadmin')) {
    return ModuleAccess.full(moduleId: moduleId);
  }

  final legacyPermission = resolveLegacyModulePermission(
    moduleId: moduleId,
    userRow: userRow,
  );

  final permissionJson = normalizeUserPermissionsJson(
    userRow['user_permissions_json'],
  );
  final pages = Map<String, dynamic>.from(
    permissionJson['pages'] as Map? ?? const {},
  );
  final rawRule = pages[moduleId];
  final rule = rawRule is Map
      ? Map<String, dynamic>.from(rawRule)
      : <String, dynamic>{};
  final hasGranularRules = rule.isNotEmpty;

  final pageAccess = _normalizeOption(
    rule['page_access']?.toString(),
    kPermissionPageAccessOptions,
    'inherit',
  );
  final basePermission = pageAccess == 'inherit'
      ? legacyPermission
      : pageAccess;

  final actions = _defaultActionsForPagePermission(basePermission);
  final rawActions = rule['actions'];
  if (rawActions is Map) {
    for (final action in kPermissionActionKeys) {
      if (!rawActions.containsKey(action)) continue;
      if (_asBool(rawActions[action])) {
        actions.add(action);
      } else {
        actions.remove(action);
      }
    }
  }

  final hasMutatingAction = actions.any(_mutatingActionKeys.contains);
  if (hasMutatingAction) actions.add('view');

  final effectivePermission = actions.contains('view')
      ? (hasMutatingAction ? 'write' : 'read')
      : 'none';

  return ModuleAccess(
    moduleId: moduleId,
    pagePermission: effectivePermission,
    actions: actions,
    scope: _normalizeOption(
      rule['scope']?.toString(),
      kPermissionScopeOptions,
      'all',
    ),
    publicationAccess: _normalizeOption(
      rule['publication_access']?.toString(),
      kPermissionPublicationOptions,
      'inherit',
    ),
    responsibilityScope: _normalizeOption(
      rule['responsibility_scope']?.toString(),
      kPermissionResponsibilityOptions,
      'inherit',
    ),
    recordLockBypass: _asBool(rule['record_lock_bypass']),
    workflowEditStates: _stringList(rule['workflow_edit_states']),
    hasGranularRules: hasGranularRules,
  );
}

class ModuleAccess {
  final String moduleId;
  final String pagePermission;
  final Set<String> actions;
  final String scope;
  final String publicationAccess;
  final String responsibilityScope;
  final bool recordLockBypass;
  final List<String> workflowEditStates;
  final bool hasGranularRules;

  const ModuleAccess({
    required this.moduleId,
    required this.pagePermission,
    required this.actions,
    required this.scope,
    required this.publicationAccess,
    required this.responsibilityScope,
    required this.recordLockBypass,
    required this.workflowEditStates,
    required this.hasGranularRules,
  });

  const ModuleAccess.full({this.moduleId = ''})
    : pagePermission = 'write',
      actions = const {
        'view',
        'insert',
        'edit',
        'delete',
        'approve',
        'export',
        'print',
        'bulk_update',
      },
      scope = 'all',
      publicationAccess = 'public',
      responsibilityScope = 'all',
      recordLockBypass = true,
      workflowEditStates = const [],
      hasGranularRules = false;

  const ModuleAccess.none({this.moduleId = ''})
    : pagePermission = 'none',
      actions = const {},
      scope = 'own',
      publicationAccess = 'none',
      responsibilityScope = 'inherit',
      recordLockBypass = false,
      workflowEditStates = const [],
      hasGranularRules = false;

  bool allows(String action) => actions.contains(action);
  bool get canView => allows('view');
  bool get canInsert => allows('insert');
  bool get canEdit => allows('edit');
  bool get canDelete => allows('delete');
  bool get canApprove => allows('approve');
  bool get canExport => allows('export');
  bool get canPrint => allows('print');
  bool get canBulkUpdate => allows('bulk_update');

  bool get canMutate =>
      canInsert || canEdit || canDelete || canApprove || canBulkUpdate;

  bool get isReadOnly => canView && !canMutate;
}

/// Carries the current module's access down the widget tree so any page can
/// check its effective actions without needing the full user-info map.
class ModulePermission extends InheritedWidget {
  final ModuleAccess access;

  const ModulePermission({
    super.key,
    required this.access,
    required super.child,
  });

  static ModulePermission? maybeOfWidget(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<ModulePermission>();

  static ModuleAccess? maybeAccessOf(BuildContext context) =>
      maybeOfWidget(context)?.access;

  static String? maybeOf(BuildContext context) =>
      maybeAccessOf(context)?.pagePermission;

  static ModuleAccess accessOf(BuildContext context) =>
      maybeAccessOf(context) ?? const ModuleAccess.full();

  static String of(BuildContext context) => accessOf(context).pagePermission;

  static Widget inherit(BuildContext context, Widget child) =>
      ModulePermission(access: accessOf(context), child: child);

  @override
  bool updateShouldNotify(ModulePermission old) => access != old.access;
}

class ResolvedModulePermission extends StatefulWidget {
  final String moduleId;
  final Widget child;
  final String? permission;

  const ResolvedModulePermission({
    super.key,
    required this.moduleId,
    required this.child,
    this.permission,
  });

  @override
  State<ResolvedModulePermission> createState() =>
      _ResolvedModulePermissionState();
}

class _ResolvedModulePermissionState extends State<ResolvedModulePermission> {
  ModuleAccess _access = const ModuleAccess.none();
  bool _resolved = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_resolved) return;

    final inherited = ModulePermission.maybeAccessOf(context);
    if (inherited != null) {
      _access = inherited;
      _resolved = true;
      return;
    }

    if (widget.permission != null) {
      _access = moduleAccessFromPagePermission(
        widget.moduleId,
        widget.permission!,
      );
      _resolved = true;
      return;
    }

    _resolved = true;
    _resolvePermission();
  }

  Future<void> _resolvePermission() async {
    final email =
        Supabase.instance.client.auth.currentUser?.email ??
        Supabase.instance.client.auth.currentSession?.user.email ??
        '';
    if (email.isEmpty) return;

    try {
      final row = await Supabase.instance.client
          .from('users')
          .select()
          .eq('user_email', email)
          .maybeSingle();
      if (!mounted || row == null) return;

      final access = resolveModuleAccess(
        moduleId: widget.moduleId,
        userRow: Map<String, dynamic>.from(row),
      );
      setState(() => _access = access);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) =>
      ModulePermission(access: _access, child: widget.child);
}

MaterialPageRoute<T> modulePageRoute<T>({
  required BuildContext context,
  required Widget child,
  String? moduleId,
  String? permission,
}) {
  return MaterialPageRoute(
    builder: (_) => moduleId == null
        ? ModulePermission.inherit(context, child)
        : ResolvedModulePermission(
            moduleId: moduleId,
            permission: permission,
            child: child,
          ),
  );
}

extension ModulePermissionContext on BuildContext {
  ModuleAccess get moduleAccess => ModulePermission.accessOf(this);

  bool get canViewModule => moduleAccess.canView;
  bool get canInsertModule => moduleAccess.canInsert;
  bool get canEditModule => moduleAccess.canEdit;
  bool get canDeleteModule => moduleAccess.canDelete;
  bool get canApproveModule => moduleAccess.canApprove;
  bool get canExportModule => moduleAccess.canExport;
  bool get canPrintModule => moduleAccess.canPrint;
  bool get canBulkUpdateModule => moduleAccess.canBulkUpdate;
  bool get canBypassRecordLocks => moduleAccess.recordLockBypass;

  bool canEditWorkflowState(String? state) {
    final allowed = moduleAccess.workflowEditStates;
    if (state == null || state.trim().isEmpty || allowed.isEmpty) return true;
    return allowed.contains(state.trim());
  }

  bool canEditLockedRecord({bool isLocked = false, String? workflowState}) {
    if (!canEditModule) return false;
    if (isLocked && !canBypassRecordLocks) return false;
    return canEditWorkflowState(workflowState);
  }

  /// Shows a read-only snackbar for blocked edit attempts.
  void warnReadOnly() {
    ScaffoldMessenger.of(this).showSnackBar(
      const SnackBar(
        duration: Duration(seconds: 3),
        content: Row(
          children: [
            Icon(Icons.visibility_outlined, color: Color(0xFFD97706), size: 16),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                'View only — contact an admin to request edit access.',
                style: TextStyle(color: Color(0xFF334155), fontSize: 13),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
