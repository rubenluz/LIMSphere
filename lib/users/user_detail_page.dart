// user_detail_page.dart - User editor: email, display name, role selector,
// per-module permission dropdowns, last-login display, role-upgrade workflow.
// Pushed via Navigator with its own Scaffold + AppBar.

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '/theme/module_permission.dart';
import '/theme/theme.dart';
import '../theme/theme_controller.dart';

TextStyle _spaceGrotesk({
  TextStyle? textStyle,
  Color? color,
  Color? backgroundColor,
  double? fontSize,
  FontWeight? fontWeight,
  FontStyle? fontStyle,
  double? letterSpacing,
  double? wordSpacing,
  TextBaseline? textBaseline,
  double? height,
  Locale? locale,
  Paint? foreground,
  Paint? background,
  List<Shadow>? shadows,
  List<FontFeature>? fontFeatures,
  TextDecoration? decoration,
  Color? decorationColor,
  TextDecorationStyle? decorationStyle,
  double? decorationThickness,
}) {
  return (textStyle ?? const TextStyle()).copyWith(
    color: color,
    backgroundColor: backgroundColor,
    fontSize: fontSize,
    fontWeight: fontWeight,
    fontStyle: fontStyle,
    letterSpacing: letterSpacing,
    wordSpacing: wordSpacing,
    textBaseline: textBaseline,
    height: height,
    locale: locale,
    foreground: foreground,
    background: background,
    shadows: shadows,
    fontFeatures: fontFeatures,
    decoration: decoration,
    decorationColor: decorationColor,
    decorationStyle: decorationStyle,
    decorationThickness: decorationThickness,
  );
}

TextStyle _jetBrainsMono({
  TextStyle? textStyle,
  Color? color,
  Color? backgroundColor,
  double? fontSize,
  FontWeight? fontWeight,
  FontStyle? fontStyle,
  double? letterSpacing,
  double? wordSpacing,
  TextBaseline? textBaseline,
  double? height,
  Locale? locale,
  Paint? foreground,
  Paint? background,
  List<Shadow>? shadows,
  List<FontFeature>? fontFeatures,
  TextDecoration? decoration,
  Color? decorationColor,
  TextDecorationStyle? decorationStyle,
  double? decorationThickness,
}) {
  return (textStyle ?? const TextStyle()).copyWith(
    fontFamily: 'Consolas',
    fontFamilyFallback: const ['Courier New'],
    color: color,
    backgroundColor: backgroundColor,
    fontSize: fontSize,
    fontWeight: fontWeight,
    fontStyle: fontStyle,
    letterSpacing: letterSpacing,
    wordSpacing: wordSpacing,
    textBaseline: textBaseline,
    height: height,
    locale: locale,
    foreground: foreground,
    background: background,
    shadows: shadows,
    fontFeatures: fontFeatures,
    decoration: decoration,
    decorationColor: decorationColor,
    decorationStyle: decorationStyle,
    decorationThickness: decorationThickness,
  );
}

// ignore_for_file: use_build_context_synchronously

final _dtTimeFmt = DateFormat('yyyy-MM-dd HH:mm');

// ═════════════════════════════════════════════════════════════════════════════
// UserDetailPage
// ═════════════════════════════════════════════════════════════════════════════
class UserDetailPage extends StatefulWidget {
  final Map<String, dynamic> userMap;
  final VoidCallback? onSaved;

  const UserDetailPage({super.key, required this.userMap, this.onSaved});

  @override
  State<UserDetailPage> createState() => _UserDetailPageState();
}

class _UserDetailPageState extends State<UserDetailPage> {
  bool _editing = false;
  bool _saving = false;
  bool _loadingViewerAccess = true;

  // Controllers for all editable fields
  late TextEditingController _name;
  late TextEditingController _email;
  late TextEditingController _phone;
  late TextEditingController _orcid;
  late TextEditingController _institution;
  late TextEditingController _group;
  late TextEditingController _bio;
  late TextEditingController _timezone;
  late TextEditingController _language;
  late TextEditingController _avatarUrl;
  final Map<String, TextEditingController> _workflowStateCtrls = {};

  late String _role;
  late String _status;
  late String _permDashboard;
  late String _permLabels;
  late String _permChat;
  late String _permBackups;
  late String _permCulture;
  late String _permFish;
  late String _permResources;
  late bool _notificationsEnabled;
  late bool _supportsGranularPermissions;
  late Map<String, dynamic> _permissionJson;

  // Read-only info
  late int _id;
  String? _authUid;
  DateTime? _createdAt;
  DateTime? _updatedAt;
  DateTime? _lastLogin;
  int? _viewerUserId;
  String _viewerRole = '';

  static const _roleOptions = [
    'superadmin',
    'admin',
    'technician',
    'researcher',
    'viewer',
  ];
  static const _statusOptions = ['pending', 'active', 'inactive'];
  static const _permOptions = ['none', 'read', 'write'];
  static const _backupsPermOptions = ['none', 'see'];

  @override
  void initState() {
    super.initState();
    _name = TextEditingController();
    _email = TextEditingController();
    _phone = TextEditingController();
    _orcid = TextEditingController();
    _institution = TextEditingController();
    _group = TextEditingController();
    _bio = TextEditingController();
    _timezone = TextEditingController();
    _language = TextEditingController();
    _avatarUrl = TextEditingController();
    _loadFromMap(widget.userMap);
    _loadViewerAccess();
  }

  void _loadFromMap(Map<String, dynamic> m) {
    _id = m['user_id'] as int? ?? 0;
    _authUid = m['user_auth_uid'] as String?;
    _createdAt = _dt(m['user_created_at']);
    _updatedAt = _dt(m['user_updated_at']);
    _lastLogin = _dt(m['user_last_login']);
    _role = (m['user_role'] as String?) ?? 'researcher';
    _status = (m['user_status'] as String?) ?? 'pending';
    _permDashboard = (m['user_table_dashboard'] as String?) ?? 'none';
    _permLabels = (m['user_table_labels'] as String?) ?? 'none';
    _permChat = (m['user_table_chat'] as String?) ?? 'none';
    _permBackups = (m['user_table_backups'] as String?) ?? 'none';
    _permCulture = (m['user_table_culture_collection'] as String?) ?? 'none';
    _permFish = (m['user_table_fish_facility'] as String?) ?? 'none';
    _permResources = (m['user_table_resources'] as String?) ?? 'none';
    _supportsGranularPermissions =
        (m['__supports_granular_permissions'] as bool?) ??
        m.containsKey('user_permissions_json');
    _permissionJson = normalizeUserPermissionsJson(m['user_permissions_json']);
    _notificationsEnabled = (m['user_notifications_enabled'] as bool?) ?? true;
    _name.text = m['user_name'] as String? ?? '';
    _email.text = m['user_email'] as String? ?? '';
    _phone.text = m['user_phone'] as String? ?? '';
    _orcid.text = m['user_orcid'] as String? ?? '';
    _institution.text = m['user_institution'] as String? ?? '';
    _group.text = m['user_group'] as String? ?? '';
    _bio.text = m['user_bio'] as String? ?? '';
    _timezone.text = m['user_timezone'] as String? ?? '';
    _language.text = m['user_language'] as String? ?? '';
    _avatarUrl.text = m['user_avatar_url'] as String? ?? '';
    _resetWorkflowControllers();
  }

  static DateTime? _dt(dynamic v) {
    if (v == null) return null;
    if (v is DateTime) return v;
    return DateTime.tryParse(v.toString());
  }

  bool get _isSelf => _viewerUserId != null && _viewerUserId == _id;
  bool get _canManageUserAccess =>
      _viewerRole == 'admin' || _viewerRole == 'superadmin';
  bool get _canEditProfile => _canManageUserAccess || _isSelf;
  bool get _canAssignPermissions =>
      _canManageUserAccess &&
      widget.userMap['user_status']?.toString() == 'active';

  Map<String, dynamic> get _draftUserMap => {
    ...widget.userMap,
    'user_role': _role,
    'user_table_dashboard': _permDashboard,
    'user_table_labels': _permLabels,
    'user_table_chat': _permChat,
    'user_table_backups': _permBackups,
    'user_table_culture_collection': _permCulture,
    'user_table_fish_facility': _permFish,
    'user_table_resources': _permResources,
    'user_permissions_json': _permissionJson,
  };

  Future<void> _loadViewerAccess() async {
    try {
      final email =
          Supabase.instance.client.auth.currentSession?.user.email ??
          Supabase.instance.client.auth.currentUser?.email ??
          '';
      if (email.isEmpty) return;
      final row = await Supabase.instance.client
          .from('users')
          .select('user_id, user_role')
          .eq('user_email', email)
          .maybeSingle();
      if (!mounted) return;
      setState(() {
        _viewerUserId = row?['user_id'] as int?;
        _viewerRole = row?['user_role'] as String? ?? '';
        _loadingViewerAccess = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loadingViewerAccess = false);
    }
  }

  void _resetWorkflowControllers() {
    for (final c in _workflowStateCtrls.values) {
      c.dispose();
    }
    _workflowStateCtrls.clear();
    for (final moduleId in kPermissionModuleLabels.keys) {
      _workflowStateCtrls[moduleId] = TextEditingController(
        text: _workflowStatesText(moduleId),
      );
    }
  }

  Map<String, dynamic> _pageRule(String moduleId) {
    final pages = Map<String, dynamic>.from(
      _permissionJson['pages'] as Map? ?? const {},
    );
    final raw = pages[moduleId];
    return raw is Map ? Map<String, dynamic>.from(raw) : <String, dynamic>{};
  }

  bool _hasPageRule(String moduleId) => _pageRule(moduleId).isNotEmpty;

  String _pageAccessValue(String moduleId) {
    final raw = _pageRule(moduleId)['page_access']?.toString();
    return kPermissionPageAccessOptions.contains(raw) ? raw! : 'inherit';
  }

  String _pageScopeValue(String moduleId) {
    final raw = _pageRule(moduleId)['scope']?.toString();
    return kPermissionScopeOptions.contains(raw) ? raw! : 'all';
  }

  String _pagePublicationValue(String moduleId) {
    final raw = _pageRule(moduleId)['publication_access']?.toString();
    return kPermissionPublicationOptions.contains(raw) ? raw! : 'inherit';
  }

  String _pageResponsibilityValue(String moduleId) {
    final raw = _pageRule(moduleId)['responsibility_scope']?.toString();
    return kPermissionResponsibilityOptions.contains(raw) ? raw! : 'inherit';
  }

  bool _pageRecordLockBypass(String moduleId) =>
      _pageRule(moduleId)['record_lock_bypass'] == true;

  String _workflowStatesText(String moduleId) {
    final states = _workflowStatesFor(moduleId);
    return states.isEmpty ? '' : states.join(', ');
  }

  List<String> _workflowStatesFor(String moduleId) {
    final value = _pageRule(moduleId)['workflow_edit_states'];
    if (value is! List) return const [];
    return value
        .map((entry) => entry?.toString().trim() ?? '')
        .where((entry) => entry.isNotEmpty)
        .toList();
  }

  ModuleAccess _moduleAccess(
    String moduleId, {
    bool ignoreActionOverrides = false,
  }) {
    final row = Map<String, dynamic>.from(_draftUserMap);
    if (!ignoreActionOverrides) {
      return resolveModuleAccess(moduleId: moduleId, userRow: row);
    }

    final normalized = normalizeUserPermissionsJson(_permissionJson);
    final pages = Map<String, dynamic>.from(
      normalized['pages'] as Map? ?? const {},
    );
    final rule = _pageRule(moduleId);
    if (rule.isNotEmpty) {
      final sanitized = Map<String, dynamic>.from(rule)..remove('actions');
      if (_isDefaultRule(sanitized)) {
        pages.remove(moduleId);
      } else {
        pages[moduleId] = sanitized;
      }
    }
    row['user_permissions_json'] = {
      'version': normalized['version'] ?? 1,
      'pages': pages,
    };
    return resolveModuleAccess(moduleId: moduleId, userRow: row);
  }

  bool _isDefaultRule(Map<String, dynamic> rule) {
    final pageAccess = rule['page_access']?.toString() ?? 'inherit';
    final scope = rule['scope']?.toString() ?? 'all';
    final publication = rule['publication_access']?.toString() ?? 'inherit';
    final responsibility =
        rule['responsibility_scope']?.toString() ?? 'inherit';
    final recordLockBypass = rule['record_lock_bypass'] == true;
    final workflowStates = rule['workflow_edit_states'];
    final hasWorkflowStates =
        workflowStates is List && workflowStates.isNotEmpty;
    final actions = rule['actions'];
    final hasActions = actions is Map && actions.isNotEmpty;
    return pageAccess == 'inherit' &&
        scope == 'all' &&
        publication == 'inherit' &&
        responsibility == 'inherit' &&
        !recordLockBypass &&
        !hasWorkflowStates &&
        !hasActions;
  }

  void _updatePageRule(
    String moduleId,
    Map<String, dynamic> Function(Map<String, dynamic> rule) mutate,
  ) {
    setState(() {
      final pages = Map<String, dynamic>.from(
        _permissionJson['pages'] as Map? ?? const {},
      );
      final next = mutate(_pageRule(moduleId));

      if (next['page_access'] == 'inherit') next.remove('page_access');
      if (next['scope'] == 'all') next.remove('scope');
      if (next['publication_access'] == 'inherit')
        next.remove('publication_access');
      if (next['responsibility_scope'] == 'inherit')
        next.remove('responsibility_scope');
      if (next['record_lock_bypass'] != true) next.remove('record_lock_bypass');

      final workflowStates = next['workflow_edit_states'];
      if (workflowStates is List) {
        final cleaned = workflowStates
            .map((entry) => entry?.toString().trim() ?? '')
            .where((entry) => entry.isNotEmpty)
            .toList();
        if (cleaned.isEmpty) {
          next.remove('workflow_edit_states');
        } else {
          next['workflow_edit_states'] = cleaned;
        }
      }

      final actions = next['actions'];
      if (actions is Map) {
        final cleaned = <String, dynamic>{};
        for (final entry in actions.entries) {
          if (kPermissionActionKeys.contains(entry.key)) {
            cleaned[entry.key.toString()] = entry.value == true;
          }
        }
        if (cleaned.isEmpty) {
          next.remove('actions');
        } else {
          next['actions'] = cleaned;
        }
      }

      if (_isDefaultRule(next)) {
        pages.remove(moduleId);
      } else {
        pages[moduleId] = next;
      }

      _permissionJson = {
        'version': _permissionJson['version'] ?? 1,
        'pages': pages,
      };
    });
  }

  void _setPageAccess(String moduleId, String value) {
    _updatePageRule(moduleId, (rule) {
      if (value == 'inherit') {
        rule.remove('page_access');
      } else {
        rule['page_access'] = value;
      }
      return rule;
    });
  }

  void _setPageScope(String moduleId, String value) {
    _updatePageRule(moduleId, (rule) {
      if (value == 'all') {
        rule.remove('scope');
      } else {
        rule['scope'] = value;
      }
      return rule;
    });
  }

  void _setPagePublicationAccess(String moduleId, String value) {
    _updatePageRule(moduleId, (rule) {
      if (value == 'inherit') {
        rule.remove('publication_access');
      } else {
        rule['publication_access'] = value;
      }
      return rule;
    });
  }

  void _setPageResponsibilityScope(String moduleId, String value) {
    _updatePageRule(moduleId, (rule) {
      if (value == 'inherit') {
        rule.remove('responsibility_scope');
      } else {
        rule['responsibility_scope'] = value;
      }
      return rule;
    });
  }

  void _setPageRecordLockBypass(String moduleId, bool value) {
    _updatePageRule(moduleId, (rule) {
      if (value) {
        rule['record_lock_bypass'] = true;
      } else {
        rule.remove('record_lock_bypass');
      }
      return rule;
    });
  }

  void _setWorkflowStates(String moduleId, String raw) {
    final values = raw
        .split(',')
        .map((entry) => entry.trim())
        .where((entry) => entry.isNotEmpty)
        .toList();
    _updatePageRule(moduleId, (rule) {
      if (values.isEmpty) {
        rule.remove('workflow_edit_states');
      } else {
        rule['workflow_edit_states'] = values;
      }
      return rule;
    });
  }

  void _togglePageAction(String moduleId, String action) {
    final effective = _moduleAccess(moduleId).allows(action);
    final base = _moduleAccess(
      moduleId,
      ignoreActionOverrides: true,
    ).allows(action);
    final desired = !effective;
    _updatePageRule(moduleId, (rule) {
      final actions = Map<String, dynamic>.from(
        rule['actions'] as Map? ?? const {},
      );
      if (desired == base) {
        actions.remove(action);
      } else {
        actions[action] = desired;
      }
      if (actions.isEmpty) {
        rule.remove('actions');
      } else {
        rule['actions'] = actions;
      }
      return rule;
    });
  }

  void _resetPageRule(String moduleId) {
    _updatePageRule(moduleId, (_) => <String, dynamic>{});
    _workflowStateCtrls[moduleId]?.text = '';
  }

  @override
  void dispose() {
    for (final c in [
      _name,
      _email,
      _phone,
      _orcid,
      _institution,
      _group,
      _bio,
      _timezone,
      _language,
      _avatarUrl,
      ..._workflowStateCtrls.values,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  // ── Helpers ───────────────────────────────────────────────────────────────
  void _snack(String msg, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: isError ? AppDS.red : null),
    );
  }

  String get _displayName {
    final n = _name.text.trim();
    return n.isNotEmpty ? n : _email.text.trim();
  }

  String get _initials {
    final n = _name.text.trim();
    if (n.isNotEmpty) {
      final parts = n.split(' ');
      if (parts.length >= 2)
        return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
      return n[0].toUpperCase();
    }
    final e = _email.text.trim();
    return e.isNotEmpty ? e[0].toUpperCase() : '?';
  }

  Color get _roleColor {
    switch (_role) {
      case 'superadmin':
        return AppDS.red;
      case 'admin':
        return AppDS.orange;
      case 'technician':
        return AppDS.accent;
      case 'researcher':
        return AppDS.green;
      case 'viewer':
        return AppDS.textMuted;
      default:
        return AppDS.textSecondary;
    }
  }

  Color get _statusColor {
    switch (_status) {
      case 'active':
        return AppDS.green;
      case 'pending':
        return AppDS.orange;
      case 'inactive':
        return AppDS.textMuted;
      default:
        return AppDS.textSecondary;
    }
  }

  // ── Save ──────────────────────────────────────────────────────────────────
  Future<void> _save() async {
    if (!_canEditProfile) return;
    final previousStatus = widget.userMap['user_status']?.toString();
    final action = previousStatus == 'pending' && _status == 'active'
        ? ModuleAction.approve
        : ModuleAction.edit;
    if (!_isSelf && !context.requireModuleAction(action)) return;
    setState(() => _saving = true);
    try {
      final data = <String, dynamic>{
        'user_name': _name.text.trim().isEmpty ? null : _name.text.trim(),
        'user_phone': _phone.text.trim().isEmpty ? null : _phone.text.trim(),
        'user_orcid': _orcid.text.trim().isEmpty ? null : _orcid.text.trim(),
        'user_institution': _institution.text.trim().isEmpty
            ? null
            : _institution.text.trim(),
        'user_group': _group.text.trim().isEmpty ? null : _group.text.trim(),
        'user_bio': _bio.text.trim().isEmpty ? null : _bio.text.trim(),
        'user_timezone': _timezone.text.trim().isEmpty
            ? null
            : _timezone.text.trim(),
        'user_language': _language.text.trim().isEmpty
            ? null
            : _language.text.trim(),
        'user_avatar_url': _avatarUrl.text.trim().isEmpty
            ? null
            : _avatarUrl.text.trim(),
        'user_notifications_enabled': _notificationsEnabled,
        'user_updated_at': DateTime.now().toIso8601String(),
      };
      if (_canManageUserAccess) {
        data.addAll({
          'user_email': _email.text.trim(),
          'user_status': _status,
          if (previousStatus == 'active') ...{
            'user_role': _role,
            'user_table_dashboard': _permDashboard,
            'user_table_labels': _permLabels,
            'user_table_chat': _permChat,
            'user_table_backups': _permBackups,
            'user_table_culture_collection': _permCulture,
            'user_table_fish_facility': _permFish,
            'user_table_resources': _permResources,
            if (_supportsGranularPermissions)
              'user_permissions_json': _permissionJson,
          },
        });
      }
      await Supabase.instance.client
          .from('users')
          .update(data)
          .eq('user_id', _id);
      if (!mounted) return;
      widget.userMap.addAll(data);
      if (_supportsGranularPermissions && _canManageUserAccess) {
        widget.userMap['user_permissions_json'] = _permissionJson;
      }
      setState(() {
        _editing = false;
        _updatedAt = DateTime.now();
      });
      widget.onSaved?.call();
      _snack('Saved');
    } catch (e) {
      _snack('Save failed: $e', isError: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _cancelEdit() {
    setState(() {
      _editing = false;
    });
    _loadFromMap(widget.userMap); // restore original values
  }

  // ── Build ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.appBg,
      appBar: AppBar(
        backgroundColor: context.appSurface,
        foregroundColor: context.appTextPrimary,
        elevation: 0,
        title: Text(
          _displayName,
          style: _spaceGrotesk(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: context.appTextPrimary,
          ),
        ),
        actions: [
          if (_editing) ...[
            TextButton(
              onPressed: _cancelEdit,
              child: Text(
                'Cancel',
                style: _spaceGrotesk(
                  color: context.appTextSecondary,
                  fontSize: 13,
                ),
              ),
            ),
            const SizedBox(width: 4),
            ElevatedButton(
              onPressed: _saving ? null : _save,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppDS.accent,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: _saving
                  ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Text(
                      'Save',
                      style: _spaceGrotesk(
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
            ),
            const SizedBox(width: 12),
          ] else if (!_loadingViewerAccess && _canEditProfile) ...[
            TextButton.icon(
              onPressed: () => setState(() => _editing = true),
              icon: const Icon(
                Icons.edit_outlined,
                size: 15,
                color: AppDS.accent,
              ),
              label: Text(
                'Edit',
                style: _spaceGrotesk(color: AppDS.accent, fontSize: 13),
              ),
            ),
            const SizedBox(width: 12),
          ],
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: context.appBorder),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 800),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildProfileHeader(),
                const SizedBox(height: 24),
                _buildSection('Contact & Identity', [
                  _row2(
                    _field(
                      'Full Name',
                      _name,
                      enabled: _editing && _canEditProfile,
                    ),
                    _field(
                      'Email',
                      _email,
                      enabled: _editing && _canManageUserAccess,
                    ),
                  ),
                  _row2(
                    _field(
                      'Phone',
                      _phone,
                      enabled: _editing && _canEditProfile,
                      hint: '+351 912 345 678',
                    ),
                    _field(
                      'ORCID',
                      _orcid,
                      enabled: _editing && _canEditProfile,
                      hint: '0000-0000-0000-0000',
                      mono: true,
                    ),
                  ),
                ]),
                const SizedBox(height: 16),
                _buildSection('Organization', [
                  _row2(
                    _field(
                      'Institution',
                      _institution,
                      enabled: _editing && _canEditProfile,
                    ),
                    _field(
                      'Group / Lab',
                      _group,
                      enabled: _editing && _canEditProfile,
                    ),
                  ),
                ]),
                const SizedBox(height: 16),
                _buildSection('Profile', [
                  _field(
                    'Bio',
                    _bio,
                    enabled: _editing && _canEditProfile,
                    maxLines: 4,
                    hint: 'Short description…',
                  ),
                  const SizedBox(height: 10),
                  _row2(
                    _field(
                      'Timezone',
                      _timezone,
                      enabled: _editing && _canEditProfile,
                      hint: 'Europe/Lisbon',
                    ),
                    _field(
                      'Language',
                      _language,
                      enabled: _editing && _canEditProfile,
                      hint: 'en, pt, de…',
                    ),
                  ),
                  const SizedBox(height: 10),
                  _field(
                    'Avatar URL',
                    _avatarUrl,
                    enabled: _editing && _canEditProfile,
                    hint: 'https://…',
                    mono: true,
                  ),
                ]),
                const SizedBox(height: 16),
                _buildSection('Access & Role', [
                  if (!_canManageUserAccess)
                    _infoBanner(
                      'Only admins can change roles, status, and permission assignments.',
                    ),
                  if (!_canManageUserAccess) const SizedBox(height: 12),
                  _row2(
                    _dropDown(
                      'Role',
                      _role,
                      _roleOptions,
                      (v) => setState(() => _role = v ?? _role),
                      enabled: _editing && _canAssignPermissions,
                    ),
                    _dropDown(
                      'Status',
                      _status,
                      _statusOptions,
                      (v) => setState(() => _status = v ?? _status),
                      enabled: _editing && _canManageUserAccess,
                    ),
                  ),
                ]),
                const SizedBox(height: 16),
                _buildSection('Module Permissions', [
                  if (_canManageUserAccess && !_canAssignPermissions)
                    _infoBanner(
                      'Activate and save this account first. Permissions can be assigned only after validation.',
                    ),
                  if (_canManageUserAccess && !_canAssignPermissions)
                    const SizedBox(height: 12),
                  if (!_canManageUserAccess)
                    _infoBanner(
                      'Granular access is visible here, but only administrators can modify it.',
                    ),
                  if (!_canManageUserAccess) const SizedBox(height: 12),
                  _permTable(),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      _editing && _canEditProfile
                          ? Switch(
                              value: _notificationsEnabled,
                              onChanged: (v) =>
                                  setState(() => _notificationsEnabled = v),
                              activeThumbColor: AppDS.accent,
                            )
                          : Icon(
                              _notificationsEnabled
                                  ? Icons.notifications_active_outlined
                                  : Icons.notifications_off_outlined,
                              size: 16,
                              color: _notificationsEnabled
                                  ? AppDS.accent
                                  : AppDS.textMuted,
                            ),
                      const SizedBox(width: 8),
                      Text(
                        'Notifications ${_notificationsEnabled ? 'enabled' : 'disabled'}',
                        style: _spaceGrotesk(
                          fontSize: 12,
                          color: _notificationsEnabled
                              ? AppDS.textPrimary
                              : AppDS.textMuted,
                        ),
                      ),
                    ],
                  ),
                ]),
                const SizedBox(height: 16),
                _buildSection('Granular Page Permissions', [
                  _granularPermissionsEditor(),
                ]),
                const SizedBox(height: 16),
                _buildSection('Metadata', [
                  _metaRow('User ID', '$_id'),
                  if (_authUid != null) _metaRow('Auth UID', _authUid!),
                  _metaRow(
                    'Created',
                    _createdAt != null
                        ? _dtTimeFmt.format(_createdAt!.toLocal())
                        : '—',
                  ),
                  _metaRow(
                    'Last Updated',
                    _updatedAt != null
                        ? _dtTimeFmt.format(_updatedAt!.toLocal())
                        : '—',
                  ),
                  _metaRow(
                    'Last Login',
                    _lastLogin != null
                        ? _dtTimeFmt.format(_lastLogin!.toLocal())
                        : '—',
                  ),
                ]),
                const SizedBox(height: 16),
                _buildSection('Appearance', [
                  AnimatedBuilder(
                    animation: appThemeCtrl,
                    builder: (_, x) => Row(
                      children: [
                        _themeBtn(
                          context,
                          'Light',
                          ThemeMode.light,
                          Icons.light_mode_outlined,
                        ),
                        const SizedBox(width: 8),
                        _themeBtn(
                          context,
                          'Dark',
                          ThemeMode.dark,
                          Icons.dark_mode_outlined,
                        ),
                        const SizedBox(width: 8),
                        _themeBtn(
                          context,
                          'System',
                          ThemeMode.system,
                          Icons.brightness_auto_outlined,
                        ),
                      ],
                    ),
                  ),
                ]),
                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── Profile header ────────────────────────────────────────────────────────
  Widget _buildProfileHeader() {
    final url = _avatarUrl.text.trim();
    return Row(
      children: [
        // Avatar
        CircleAvatar(
          radius: 40,
          backgroundColor: _roleColor.withValues(alpha: 0.18),
          backgroundImage: url.isNotEmpty ? NetworkImage(url) : null,
          child: url.isEmpty
              ? Text(
                  _initials,
                  style: _spaceGrotesk(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: _roleColor,
                  ),
                )
              : null,
        ),
        const SizedBox(width: 20),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _displayName,
                style: _spaceGrotesk(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: context.appTextPrimary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                _email.text,
                style: _jetBrainsMono(
                  fontSize: 12,
                  color: context.appTextSecondary,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: [
                  _badge(_role, _roleColor),
                  _badge(_status, _statusColor),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ── Permission table ──────────────────────────────────────────────────────
  Widget _permTable() {
    final modules = [
      (
        'Dashboard',
        _permDashboard,
        (String v) => setState(() => _permDashboard = v),
        _permOptions,
      ),
      (
        'Labels',
        _permLabels,
        (String v) => setState(() => _permLabels = v),
        _permOptions,
      ),
      (
        'Chat',
        _permChat,
        (String v) => setState(() => _permChat = v),
        _permOptions,
      ),
      (
        'Backups',
        _permBackups,
        (String v) => setState(() => _permBackups = v),
        _backupsPermOptions,
      ),
      (
        'Culture Collection',
        _permCulture,
        (String v) => setState(() => _permCulture = v),
        _permOptions,
      ),
      (
        'Fish Facility',
        _permFish,
        (String v) => setState(() => _permFish = v),
        _permOptions,
      ),
      (
        'Resources',
        _permResources,
        (String v) => setState(() => _permResources = v),
        _permOptions,
      ),
    ];

    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: context.appBorder),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: modules.asMap().entries.map((e) {
          final i = e.key;
          final m = e.value;
          final isLast = i == modules.length - 1;
          return Container(
            decoration: BoxDecoration(
              border: isLast
                  ? null
                  : Border(bottom: BorderSide(color: context.appBorder)),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Row(
              children: [
                SizedBox(
                  width: 160,
                  child: Text(
                    m.$1,
                    style: _spaceGrotesk(
                      fontSize: 13,
                      color: context.appTextPrimary,
                    ),
                  ),
                ),
                if (_editing && _canAssignPermissions)
                  Wrap(
                    spacing: 6,
                    children: m.$4.map((opt) {
                      final selected = m.$2 == opt;
                      final c = _permColor(opt);
                      return GestureDetector(
                        onTap: () => m.$3(opt),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: selected
                                ? c.withValues(alpha: 0.18)
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(
                              color: selected ? c : context.appBorder,
                            ),
                          ),
                          child: Text(
                            opt,
                            style: _spaceGrotesk(
                              fontSize: 11,
                              fontWeight: selected
                                  ? FontWeight.w700
                                  : FontWeight.normal,
                              color: selected ? c : context.appTextMuted,
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  )
                else
                  _permBadge(m.$2),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _granularPermissionsEditor() {
    if (!_supportsGranularPermissions) {
      return _infoBanner(
        'Granular permissions are unavailable for this connection because the connected users table does not have the user_permissions_json column yet. Run Setup again to apply the latest users-table migration.',
      );
    }

    final canEditRules = _editing && _canAssignPermissions;
    final groups = kPermissionModuleGroups.entries.toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _infoBanner(
          'Edit access is enforced across existing pages now. The other action toggles are saved and available for page-by-page rollout.',
        ),
        const SizedBox(height: 12),
        if (!_canManageUserAccess)
          _infoBanner(
            'These per-page rules are shown read-only. Administrators can tune page access, actions, scopes, and workflow restrictions here.',
          ),
        if (!_canManageUserAccess) const SizedBox(height: 12),
        ...groups.expand((group) {
          final widgets = <Widget>[
            Text(
              group.key.toUpperCase(),
              style: _spaceGrotesk(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: context.appTextMuted,
                letterSpacing: 0.9,
              ),
            ),
            const SizedBox(height: 8),
          ];

          for (final moduleId in group.value) {
            widgets.add(
              _granularPageCard(moduleId, canEditRules: canEditRules),
            );
            widgets.add(const SizedBox(height: 10));
          }
          return widgets;
        }),
      ],
    );
  }

  Widget _granularPageCard(String moduleId, {required bool canEditRules}) {
    final label = kPermissionModuleLabels[moduleId] ?? moduleId;
    final access = _moduleAccess(moduleId);
    final actionChips = kPermissionActionKeys.map((action) {
      final enabled = access.allows(action);
      final actionLabel = kPermissionActionLabels[action] ?? action;
      return GestureDetector(
        onTap: canEditRules ? () => _togglePageAction(moduleId, action) : null,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: enabled
                ? AppDS.accent.withValues(alpha: 0.14)
                : context.appSurface2,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: enabled ? AppDS.accent : context.appBorder2,
            ),
          ),
          child: Text(
            actionLabel,
            style: _spaceGrotesk(
              fontSize: 11,
              fontWeight: enabled ? FontWeight.w700 : FontWeight.w500,
              color: enabled ? AppDS.accent : context.appTextMuted,
            ),
          ),
        ),
      );
    }).toList();

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: context.appSurface2,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: context.appBorder2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: _spaceGrotesk(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: context.appTextPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _accessSummary(access),
                      style: _spaceGrotesk(
                        fontSize: 12,
                        color: context.appTextSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              if (_hasPageRule(moduleId))
                TextButton(
                  onPressed: canEditRules
                      ? () => _resetPageRule(moduleId)
                      : null,
                  child: Text('Reset', style: _spaceGrotesk(fontSize: 12)),
                ),
            ],
          ),
          const SizedBox(height: 12),
          if (canEditRules) ...[
            _row2(
              _ruleDropdownField(
                'Page Access',
                _pageAccessValue(moduleId),
                kPermissionPageAccessOptions,
                (value) => _setPageAccess(moduleId, value),
              ),
              _ruleDropdownField(
                'Record Scope',
                _pageScopeValue(moduleId),
                kPermissionScopeOptions,
                (value) => _setPageScope(moduleId, value),
              ),
            ),
            _row2(
              _ruleDropdownField(
                'Publication Access',
                _pagePublicationValue(moduleId),
                kPermissionPublicationOptions,
                (value) => _setPagePublicationAccess(moduleId, value),
              ),
              _ruleDropdownField(
                'Responsibility Scope',
                _pageResponsibilityValue(moduleId),
                kPermissionResponsibilityOptions,
                (value) => _setPageResponsibilityScope(moduleId, value),
              ),
            ),
            Row(
              children: [
                Switch(
                  value: _pageRecordLockBypass(moduleId),
                  onChanged: (value) =>
                      _setPageRecordLockBypass(moduleId, value),
                  activeThumbColor: AppDS.accent,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Allow this page to bypass record locks.',
                    style: _spaceGrotesk(
                      fontSize: 12,
                      color: context.appTextPrimary,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
          ] else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _miniBadge(
                  access.pagePermission.toUpperCase(),
                  access.canMutate ? AppDS.green : AppDS.accent,
                ),
                _miniBadge('Scope: ${access.scope}', context.appTextSecondary),
                _miniBadge(
                  'Publication: ${access.publicationAccess}',
                  context.appTextSecondary,
                ),
                _miniBadge(
                  'Responsibility: ${access.responsibilityScope}',
                  context.appTextSecondary,
                ),
                if (access.recordLockBypass)
                  _miniBadge('Bypass Locks', AppDS.orange),
              ],
            ),
          Text(
            'Actions',
            style: _spaceGrotesk(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: context.appTextMuted,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(spacing: 6, runSpacing: 6, children: actionChips),
          const SizedBox(height: 12),
          Text(
            'Workflow Edit States',
            style: _spaceGrotesk(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: context.appTextMuted,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 6),
          if (canEditRules)
            TextField(
              controller: _workflowStateCtrls[moduleId],
              onChanged: (value) => _setWorkflowStates(moduleId, value),
              style: _spaceGrotesk(fontSize: 12, color: context.appTextPrimary),
              decoration: InputDecoration(
                hintText: 'draft, active, approved',
                hintStyle: _spaceGrotesk(
                  fontSize: 12,
                  color: context.appTextMuted,
                ),
                filled: true,
                fillColor: context.appSurface,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 8,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: context.appBorder2),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: context.appBorder2),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: AppDS.accent),
                ),
              ),
            )
          else
            Text(
              access.workflowEditStates.isEmpty
                  ? 'Any workflow state'
                  : access.workflowEditStates.join(', '),
              style: _spaceGrotesk(
                fontSize: 12,
                color: access.workflowEditStates.isEmpty
                    ? context.appTextMuted
                    : context.appTextPrimary,
              ),
            ),
        ],
      ),
    );
  }

  String _accessSummary(ModuleAccess access) {
    if (!access.canView) return 'No page access';
    if (access.isReadOnly) return 'View only access';
    return 'Editable with ${access.scope} scope';
  }

  // ── Section / field helpers ───────────────────────────────────────────────
  Widget _buildSection(String title, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title.toUpperCase(),
          style: _spaceGrotesk(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            color: context.appTextMuted,
            letterSpacing: 1.0,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: context.appSurface,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: context.appBorder),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: children,
          ),
        ),
      ],
    );
  }

  Widget _row2(Widget a, Widget b) => Row(
    children: [
      Expanded(child: a),
      const SizedBox(width: 16),
      Expanded(child: b),
    ],
  );

  Widget _field(
    String label,
    TextEditingController ctrl, {
    bool enabled = false,
    String? hint,
    bool mono = false,
    int maxLines = 1,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: _spaceGrotesk(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            color: context.appTextMuted,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 4),
        enabled
            ? TextFormField(
                controller: ctrl,
                maxLines: maxLines,
                style:
                    (mono
                            ? _jetBrainsMono(fontSize: 12)
                            : _spaceGrotesk(fontSize: 13))
                        .copyWith(color: context.appTextPrimary),
                decoration: InputDecoration(
                  hintText: hint,
                  hintStyle: _spaceGrotesk(
                    fontSize: 12,
                    color: context.appTextMuted,
                  ),
                  filled: true,
                  fillColor: context.appSurface2,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 8,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(6),
                    borderSide: BorderSide(color: context.appBorder2),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(6),
                    borderSide: BorderSide(color: context.appBorder2),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(6),
                    borderSide: const BorderSide(color: AppDS.accent),
                  ),
                ),
              )
            : Text(
                ctrl.text.isEmpty ? (hint ?? '—') : ctrl.text,
                style:
                    (mono
                            ? _jetBrainsMono(fontSize: 12)
                            : _spaceGrotesk(fontSize: 13))
                        .copyWith(
                          color: ctrl.text.isEmpty
                              ? context.appTextMuted
                              : context.appTextPrimary,
                        ),
              ),
        const SizedBox(height: 10),
      ],
    );
  }

  Widget _dropDown(
    String label,
    String value,
    List<String> options,
    ValueChanged<String?> onChanged, {
    required bool enabled,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: _spaceGrotesk(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            color: context.appTextMuted,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 4),
        enabled
            ? Container(
                height: 40,
                padding: const EdgeInsets.symmetric(horizontal: 10),
                decoration: BoxDecoration(
                  color: context.appSurface2,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: context.appBorder2),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: value,
                    isExpanded: true,
                    dropdownColor: context.appSurface2,
                    style: _spaceGrotesk(
                      fontSize: 13,
                      color: context.appTextPrimary,
                    ),
                    items: options
                        .map((o) => DropdownMenuItem(value: o, child: Text(o)))
                        .toList(),
                    onChanged: onChanged,
                    icon: Icon(
                      Icons.expand_more,
                      size: 16,
                      color: context.appTextMuted,
                    ),
                  ),
                ),
              )
            : Text(
                value,
                style: _spaceGrotesk(
                  fontSize: 13,
                  color: context.appTextPrimary,
                ),
              ),
        const SizedBox(height: 10),
      ],
    );
  }

  Widget _ruleDropdownField(
    String label,
    String value,
    List<String> options,
    ValueChanged<String> onChanged,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: _spaceGrotesk(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            color: context.appTextMuted,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 4),
        Container(
          height: 40,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            color: context.appSurface,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: context.appBorder2),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: value,
              isExpanded: true,
              dropdownColor: context.appSurface,
              style: _spaceGrotesk(fontSize: 13, color: context.appTextPrimary),
              items: options
                  .map(
                    (o) => DropdownMenuItem<String>(value: o, child: Text(o)),
                  )
                  .toList(),
              onChanged: (next) {
                if (next != null) onChanged(next);
              },
              icon: Icon(
                Icons.expand_more,
                size: 16,
                color: context.appTextMuted,
              ),
            ),
          ),
        ),
        const SizedBox(height: 10),
      ],
    );
  }

  Widget _themeBtn(
    BuildContext context,
    String label,
    ThemeMode mode,
    IconData icon,
  ) {
    final active = appThemeCtrl.mode == mode;
    return Expanded(
      child: OutlinedButton.icon(
        icon: Icon(icon, size: 16),
        label: Text(label),
        style: OutlinedButton.styleFrom(
          backgroundColor: active ? AppDS.accent.withValues(alpha: 0.15) : null,
          foregroundColor: active ? AppDS.accent : context.appTextSecondary,
          side: BorderSide(color: active ? AppDS.accent : context.appBorder),
          padding: const EdgeInsets.symmetric(vertical: 10),
        ),
        onPressed: () => appThemeCtrl.setMode(mode),
      ),
    );
  }

  Widget _metaRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: _spaceGrotesk(fontSize: 12, color: context.appTextMuted),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: _jetBrainsMono(
                fontSize: 11,
                color: context.appTextSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _infoBanner(String text) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: AppDS.accent.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: AppDS.accent.withValues(alpha: 0.22)),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(Icons.info_outline_rounded, size: 16, color: AppDS.accent),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: _spaceGrotesk(
              fontSize: 12,
              color: context.appTextPrimary,
              height: 1.35,
            ),
          ),
        ),
      ],
    ),
  );

  Widget _badge(String label, Color color) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: color.withValues(alpha: 0.35)),
    ),
    child: Text(
      label,
      style: _spaceGrotesk(
        fontSize: 11,
        fontWeight: FontWeight.w700,
        color: color,
        letterSpacing: 0.2,
      ),
    ),
  );

  Widget _permBadge(String perm) {
    final c = _permColor(perm);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: c.withValues(alpha: 0.3)),
      ),
      child: Text(
        perm,
        style: _spaceGrotesk(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: c,
        ),
      ),
    );
  }

  Widget _miniBadge(String label, Color color) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: color.withValues(alpha: 0.22)),
    ),
    child: Text(
      label,
      style: _spaceGrotesk(
        fontSize: 11,
        fontWeight: FontWeight.w600,
        color: color,
      ),
    ),
  );

  static Color _permColor(String p) {
    switch (p) {
      case 'write':
        return AppDS.green;
      case 'read':
        return AppDS.accent;
      case 'see':
        return AppDS.yellow;
      default:
        return AppDS.textMuted;
    }
  }
}
