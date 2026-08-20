// users_page.dart - User management grid: list all users, role assignment,
// simplified permission summary, status (pending/active), invite workflow.
// UserModel (public) re-exported here for use by user_detail_page.

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '/core/data_cache.dart';
import '/theme/theme.dart';
import '/theme/module_permission.dart';
import 'user_detail_page.dart';

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

// ═════════════════════════════════════════════════════════════════════════════
// Model
// ═════════════════════════════════════════════════════════════════════════════
class _User {
  final int id;
  String? name;
  String email;
  String role;
  String status;
  String? phone;
  String? orcid;
  String? institution;
  String? group;
  String? avatarUrl;
  String? bio;
  String? timezone;
  String? language;
  String permDashboard;
  String permLabels;
  String permChat;
  String permBackups;
  String permCulture;
  String permFish;
  String permResources;
  Map<String, dynamic> permissionsJson;
  bool supportsGranularPermissions;
  bool notificationsEnabled;
  DateTime? createdAt;
  DateTime? updatedAt;
  DateTime? lastLogin;
  String? authUid;

  _User({
    required this.id,
    this.name,
    required this.email,
    required this.role,
    required this.status,
    this.phone,
    this.orcid,
    this.institution,
    this.group,
    this.avatarUrl,
    this.bio,
    this.timezone,
    this.language,
    required this.permDashboard,
    required this.permLabels,
    required this.permChat,
    required this.permBackups,
    required this.permCulture,
    required this.permFish,
    required this.permResources,
    required this.permissionsJson,
    required this.supportsGranularPermissions,
    required this.notificationsEnabled,
    this.createdAt,
    this.updatedAt,
    this.lastLogin,
    this.authUid,
  });

  factory _User.fromMap(Map<String, dynamic> m) => _User(
    id: m['user_id'] as int,
    name: m['user_name'] as String?,
    email: (m['user_email'] as String?) ?? '',
    role: (m['user_role'] as String?) ?? 'researcher',
    status: (m['user_status'] as String?) ?? 'pending',
    phone: m['user_phone'] as String?,
    orcid: m['user_orcid'] as String?,
    institution: m['user_institution'] as String?,
    group: m['user_group'] as String?,
    avatarUrl: m['user_avatar_url'] as String?,
    bio: m['user_bio'] as String?,
    timezone: m['user_timezone'] as String?,
    language: m['user_language'] as String?,
    permDashboard: (m['user_table_dashboard'] as String?) ?? 'none',
    permLabels: (m['user_table_labels'] as String?) ?? 'none',
    permChat: (m['user_table_chat'] as String?) ?? 'none',
    permBackups: (m['user_table_backups'] as String?) ?? 'none',
    permCulture: (m['user_table_culture_collection'] as String?) ?? 'none',
    permFish: (m['user_table_fish_facility'] as String?) ?? 'none',
    permResources: (m['user_table_resources'] as String?) ?? 'none',
    permissionsJson: normalizeUserPermissionsJson(m['user_permissions_json']),
    supportsGranularPermissions: m.containsKey('user_permissions_json'),
    notificationsEnabled: (m['user_notifications_enabled'] as bool?) ?? true,
    createdAt: _dt(m['user_created_at']),
    updatedAt: _dt(m['user_updated_at']),
    lastLogin: _dt(m['user_last_login']),
    authUid: m['user_auth_uid'] as String?,
  );

  static DateTime? _dt(dynamic v) {
    if (v == null) return null;
    if (v is DateTime) return v;
    return DateTime.tryParse(v.toString());
  }

  Map<String, dynamic> toMap() => {
    'user_id': id,
    'user_name': name,
    'user_email': email,
    'user_role': role,
    'user_status': status,
    'user_phone': phone,
    'user_orcid': orcid,
    'user_institution': institution,
    'user_group': group,
    'user_avatar_url': avatarUrl,
    'user_bio': bio,
    'user_timezone': timezone,
    'user_language': language,
    'user_table_dashboard': permDashboard,
    'user_table_labels': permLabels,
    'user_table_chat': permChat,
    'user_table_backups': permBackups,
    'user_table_culture_collection': permCulture,
    'user_table_fish_facility': permFish,
    'user_table_resources': permResources,
    'user_permissions_json': permissionsJson,
    '__supports_granular_permissions': supportsGranularPermissions,
    'user_notifications_enabled': notificationsEnabled,
    'user_created_at': createdAt?.toIso8601String(),
    'user_updated_at': updatedAt?.toIso8601String(),
    'user_last_login': lastLogin?.toIso8601String(),
    'user_auth_uid': authUid,
  };

  String get displayName => name?.isNotEmpty == true ? name! : email;
  Map<String, dynamic> get granularPages =>
      Map<String, dynamic>.from(permissionsJson['pages'] as Map? ?? const {});
  int get granularPageCount => granularPages.length;
  String get initials {
    if (name != null && name!.isNotEmpty) {
      final parts = name!.trim().split(' ');
      if (parts.length >= 2) {
        return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
      }
      return parts.first[0].toUpperCase();
    }
    return email.isNotEmpty ? email[0].toUpperCase() : '?';
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// Columns definition
// ═════════════════════════════════════════════════════════════════════════════
// (key, label, width)
const _cols = [
  ('user_name', 'Name', 160.0),
  ('user_email', 'Email', 200.0),
  ('user_role', 'Role', 105.0),
  ('user_status', 'Status', 90.0),
  ('permissions_summary', 'Permissions', 240.0),
  ('user_institution', 'Institution', 150.0),
  ('user_group', 'Group', 110.0),
  ('user_phone', 'Phone', 110.0),
  ('user_last_login', 'Last Login', 130.0),
  ('user_created_at', 'Created', 110.0),
];

const _roleOptions = [
  'superadmin',
  'admin',
  'technician',
  'researcher',
  'viewer',
];
const _statusOptions = ['pending', 'active', 'inactive'];
final _dtFmt = DateFormat('yyyy-MM-dd');
final _dtTimeFmt = DateFormat('yyyy-MM-dd HH:mm');

// ═════════════════════════════════════════════════════════════════════════════
// Page
// ═════════════════════════════════════════════════════════════════════════════
class UsersPage extends StatefulWidget {
  const UsersPage({super.key});

  @override
  State<UsersPage> createState() => _UsersPageState();
}

class _UsersPageState extends State<UsersPage> {
  List<_User> _users = [];
  List<_User> _filtered = [];
  bool _loading = true;
  String? _error;
  String? _filterRole;
  String? _filterStatus;
  String _sortKey = 'user_name';
  bool _sortAsc = true;
  final Set<int> _deletingUserIds = {};

  final _searchCtrl = TextEditingController();
  final _listCtrl = ScrollController();

  @override
  void initState() {
    super.initState();
    _load();
    _searchCtrl.addListener(_applyFilter);
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _listCtrl.dispose();
    super.dispose();
  }

  // ── Data ──────────────────────────────────────────────────────────────────
  Future<void> _load() async {
    final cached = await DataCache.read('users');
    if (cached != null && mounted) {
      _users = cached
          .map((r) => _User.fromMap(Map<String, dynamic>.from(r as Map)))
          .toList();
      _applyFilter();
      setState(() {
        _loading = false;
        _error = null;
      });
    } else {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final rows =
          await Supabase.instance.client
                  .from('users')
                  .select()
                  .order('user_name')
              as List<dynamic>;
      await DataCache.write('users', rows);
      if (!mounted) return;
      _users = rows
          .map((r) => _User.fromMap(Map<String, dynamic>.from(r as Map)))
          .toList();
      _applyFilter();
      setState(() => _loading = false);
    } catch (e) {
      if (cached == null && mounted) {
        setState(() {
          _loading = false;
          _error = e.toString();
        });
      }
    }
  }

  void _applyFilter() {
    var d = _users.toList();
    final q = _searchCtrl.text.toLowerCase();
    if (q.isNotEmpty) {
      d = d
          .where(
            (u) =>
                u.displayName.toLowerCase().contains(q) ||
                u.email.toLowerCase().contains(q) ||
                (u.institution?.toLowerCase().contains(q) ?? false) ||
                (u.group?.toLowerCase().contains(q) ?? false),
          )
          .toList();
    }
    if (_filterRole != null) {
      d = d.where((u) => u.role == _filterRole).toList();
    }
    if (_filterStatus != null) {
      d = d.where((u) => u.status == _filterStatus).toList();
    }

    d.sort((a, b) {
      final av = _sortValue(a, _sortKey);
      final bv = _sortValue(b, _sortKey);
      final c = av.compareTo(bv);
      return _sortAsc ? c : -c;
    });
    setState(() => _filtered = d);
  }

  String _sortValue(_User u, String key) {
    switch (key) {
      case 'user_name':
        return u.displayName.toLowerCase();
      case 'user_email':
        return u.email.toLowerCase();
      case 'user_role':
        return u.role;
      case 'user_status':
        return u.status;
      case 'permissions_summary':
        return _permissionSortKey(u);
      case 'user_institution':
        return u.institution?.toLowerCase() ?? '';
      case 'user_group':
        return u.group?.toLowerCase() ?? '';
      case 'user_last_login':
        return u.lastLogin?.toIso8601String() ?? '';
      case 'user_created_at':
        return u.createdAt?.toIso8601String() ?? '';
      default:
        return '';
    }
  }

  String _permissionSortKey(_User u) {
    final parts = [
      _permissionRank(_overviewPermission(u)).toString(),
      _permissionRank(_effectivePermission(u.permCulture, u)).toString(),
      _permissionRank(_effectivePermission(u.permFish, u)).toString(),
      _permissionRank(_effectivePermission(u.permResources, u)).toString(),
      (u.supportsGranularPermissions ? 1 : 0).toString(),
      u.granularPageCount.toString().padLeft(4, '0'),
    ];
    return parts.join('_');
  }

  void _sort(String key) {
    setState(() {
      if (_sortKey == key) {
        _sortAsc = !_sortAsc;
      } else {
        _sortKey = key;
        _sortAsc = true;
      }
    });
    _applyFilter();
  }

  // ── Commit helpers ────────────────────────────────────────────────────────
  void _snack(String msg, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: isError ? AppDS.red : context.appSurface3,
      ),
    );
  }

  Future<void> _commit(_User u, String dbCol, dynamic value) async {
    final action = dbCol == 'user_status' && value == 'active'
        ? ModuleAction.approve
        : ModuleAction.edit;
    if (!context.requireModuleAction(action)) return;
    try {
      await Supabase.instance.client
          .from('users')
          .update({
            dbCol: value,
            'user_updated_at': DateTime.now().toIso8601String(),
          })
          .eq('user_id', u.id);
    } catch (e) {
      _snack('Save failed: $e', isError: true);
    }
  }

  Future<void> _commitDropdown(_User u, String key, String val) async {
    final action = key == 'user_status' && val == 'active'
        ? ModuleAction.approve
        : ModuleAction.edit;
    if (!context.requireModuleAction(action)) return;
    setState(() {
      _applyLocalDrop(u, key, val);
    });
    await _commit(u, key, val);
  }

  void _applyLocalDrop(_User u, String key, String v) {
    switch (key) {
      case 'user_role':
        u.role = v;
        break;
      case 'user_status':
        u.status = v;
        break;
      case 'user_table_dashboard':
        u.permDashboard = v;
        break;
      case 'user_table_chat':
        u.permChat = v;
        break;
      case 'user_table_backups':
        u.permBackups = v;
        break;
      case 'user_table_culture_collection':
        u.permCulture = v;
        break;
      case 'user_table_fish_facility':
        u.permFish = v;
        break;
      case 'user_table_resources':
        u.permResources = v;
        break;
    }
  }

  Future<void> _quickAccept(_User u) async {
    if (!context.requireModuleAction(ModuleAction.approve)) return;
    setState(() => u.status = 'active');
    await _commit(u, 'user_status', 'active');
    _snack('${u.displayName} activated');
  }

  bool _isCurrentUser(_User u) {
    final authUser = Supabase.instance.client.auth.currentUser;
    if (authUser == null) return false;
    if (u.authUid?.isNotEmpty == true && u.authUid == authUser.id) return true;
    return u.email.trim().toLowerCase() ==
        (authUser.email ?? '').trim().toLowerCase();
  }

  Future<void> _deleteUser(_User u) async {
    if (!context.requireModuleAction(ModuleAction.delete)) return;
    if (_isCurrentUser(u)) {
      _snack('You cannot delete your own account.', isError: true);
      return;
    }
    final superadminCount = _users
        .where((user) => user.role == 'superadmin')
        .length;
    if (u.role == 'superadmin' && superadminCount <= 1) {
      _snack('The final superadmin cannot be deleted.', isError: true);
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        icon: const Icon(Icons.delete_forever_outlined, color: AppDS.red),
        title: const Text('Delete this user?'),
        content: Text(
          'Are you sure you want to delete ${u.displayName} '
          '(${u.email}) from LIMSphere?\n\n'
          'This cannot be undone. Historical records that refer to this user '
          'may prevent the deletion.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton.icon(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            icon: const Icon(Icons.delete_outline, size: 18),
            label: const Text('Delete user'),
            style: FilledButton.styleFrom(backgroundColor: AppDS.red),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _deletingUserIds.add(u.id));
    try {
      final deleted = await Supabase.instance.client
          .from('users')
          .delete()
          .eq('user_id', u.id)
          .select('user_id');
      if ((deleted as List).isEmpty) {
        throw Exception('The database did not delete the user.');
      }
      _users.removeWhere((user) => user.id == u.id);
      await DataCache.clear('users');
      if (!mounted) return;
      _applyFilter();
      _snack('${u.displayName} was deleted.');
    } catch (error) {
      _snack(
        'Could not delete ${u.displayName}. The user may still be linked to '
        'existing records. You can set their status to inactive instead.\n$error',
        isError: true,
      );
    } finally {
      if (mounted) setState(() => _deletingUserIds.remove(u.id));
    }
  }

  Future<void> _showMenuPicker(
    _User u,
    String key,
    List<String> options,
    Offset pos,
  ) async {
    final current = _fieldVal(u, key);
    final result = await showMenu<String>(
      context: context,
      position: RelativeRect.fromLTRB(pos.dx, pos.dy, pos.dx + 1, pos.dy + 1),
      color: context.appSurface2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: context.appBorder),
      ),
      items: options
          .map(
            (o) => PopupMenuItem<String>(
              value: o,
              child: Row(
                children: [
                  Text(
                    o,
                    style: _spaceGrotesk(
                      fontSize: 13,
                      color: context.appTextPrimary,
                      fontWeight: current == o
                          ? FontWeight.w700
                          : FontWeight.normal,
                    ),
                  ),
                  if (current == o) ...[
                    const Spacer(),
                    const Icon(Icons.check, size: 14, color: AppDS.accent),
                  ],
                ],
              ),
            ),
          )
          .toList(),
    );
    if (result != null && result != current) {
      await _commitDropdown(u, key, result);
    }
  }

  String? _fieldVal(_User u, String key) {
    switch (key) {
      case 'user_name':
        return u.name;
      case 'user_email':
        return u.email;
      case 'user_role':
        return u.role;
      case 'user_status':
        return u.status;
      case 'user_institution':
        return u.institution;
      case 'user_group':
        return u.group;
      case 'user_phone':
        return u.phone;
      case 'user_table_dashboard':
        return u.permDashboard;
      case 'user_table_chat':
        return u.permChat;
      case 'user_table_backups':
        return u.permBackups;
      case 'user_table_culture_collection':
        return u.permCulture;
      case 'user_table_fish_facility':
        return u.permFish;
      case 'user_table_resources':
        return u.permResources;
      case 'user_last_login':
        return u.lastLogin != null
            ? _dtTimeFmt.format(u.lastLogin!.toLocal())
            : null;
      case 'user_created_at':
        return u.createdAt != null
            ? _dtFmt.format(u.createdAt!.toLocal())
            : null;
      default:
        return null;
    }
  }

  void _openDetail(_User u) {
    Navigator.push(
      context,
      modulePageRoute(
        context: context,
        child: UserDetailPage(userMap: u.toMap(), onSaved: _load),
      ),
    );
  }

  // ── Build ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _buildToolbar(),
        Divider(height: 1, color: context.appBorder),
        Expanded(child: _buildBody()),
      ],
    );
  }

  Widget _buildToolbar() {
    final showDrawerButton = MediaQuery.of(context).size.width < 700;
    return Container(
      color: context.appBg,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          if (showDrawerButton) ...[
            IconButton(
              icon: const Icon(Icons.menu_rounded, size: 20),
              color: context.appTextSecondary,
              tooltip: 'Menu',
              onPressed: () => Scaffold.of(context).openDrawer(),
            ),
            const SizedBox(width: 6),
          ],
          Expanded(
            child: TextField(
              controller: _searchCtrl,
              style: _spaceGrotesk(fontSize: 13, color: context.appTextPrimary),
              decoration: InputDecoration(
                hintText: 'Search users…',
                hintStyle: _spaceGrotesk(
                  fontSize: 12,
                  color: context.appTextMuted,
                ),
                prefixIcon: Icon(
                  Icons.search,
                  size: 16,
                  color: context.appTextMuted,
                ),
                suffixIcon: _searchCtrl.text.isNotEmpty
                    ? IconButton(
                        icon: Icon(
                          Icons.clear,
                          size: 16,
                          color: context.appTextMuted,
                        ),
                        onPressed: () {
                          _searchCtrl.clear();
                          _applyFilter();
                        },
                      )
                    : null,
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(vertical: 9),
                filled: true,
                fillColor: context.appSurface,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: context.appBorder),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: context.appBorder),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: AppDS.accent),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          _buildRoleFilterButton(),
          const SizedBox(width: 6),
          _buildStatusFilterButton(),
          const SizedBox(width: 6),
          _buildSortButton(),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: context.appSurface2,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: context.appBorder),
            ),
            child: Text(
              '${_filtered.length} of ${_users.length}',
              style: _jetBrainsMono(fontSize: 11, color: context.appTextMuted),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(color: AppDS.accent),
      );
    }
    if (_error != null) {
      return Center(
        child: Text(
          _error!,
          style: _spaceGrotesk(color: AppDS.red, fontSize: 13),
        ),
      );
    }
    if (_filtered.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.people_outline, size: 52, color: context.appTextMuted),
            const SizedBox(height: 14),
            Text(
              _users.isEmpty ? 'No users found.' : 'No users match.',
              style: _spaceGrotesk(
                fontSize: 14,
                color: context.appTextSecondary,
              ),
            ),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
      child: Scrollbar(
        controller: _listCtrl,
        child: ListView.separated(
          controller: _listCtrl,
          itemCount: _filtered.length,
          separatorBuilder: (_, index) => const SizedBox(height: 6),
          itemBuilder: (_, i) => _buildUserCard(_filtered[i]),
        ),
      ),
    );
  }

  String get _activeSortLabel {
    final match = _cols.where((c) => c.$1 == _sortKey);
    return match.isEmpty ? 'Name' : match.first.$2;
  }

  IconData _sortIcon(String key) {
    switch (key) {
      case 'user_name':
        return Icons.person_outline;
      case 'user_email':
        return Icons.alternate_email_outlined;
      case 'user_role':
        return Icons.shield_outlined;
      case 'user_status':
        return Icons.verified_user_outlined;
      case 'permissions_summary':
        return Icons.admin_panel_settings_outlined;
      case 'user_institution':
        return Icons.apartment_outlined;
      case 'user_group':
        return Icons.groups_2_outlined;
      case 'user_phone':
        return Icons.call_outlined;
      case 'user_last_login':
        return Icons.login_outlined;
      case 'user_created_at':
        return Icons.schedule_outlined;
      default:
        return Icons.sort;
    }
  }

  Widget _toolbarIconButton({
    required IconData icon,
    required String tooltip,
    required List<PopupMenuEntry<String>> items,
    required ValueChanged<String> onSelected,
    bool active = false,
    Color? activeColor,
  }) {
    final accent = activeColor ?? AppDS.accent;
    return Tooltip(
      message: tooltip,
      child: PopupMenuButton<String>(
        tooltip: tooltip,
        color: context.appSurface2,
        onSelected: onSelected,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: context.appBorder),
        ),
        itemBuilder: (_) => items,
        child: Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: active ? accent.withValues(alpha: 0.12) : context.appSurface,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: active
                  ? accent.withValues(alpha: 0.38)
                  : context.appBorder,
            ),
          ),
          child: Icon(
            icon,
            size: 18,
            color: active ? accent : context.appTextSecondary,
          ),
        ),
      ),
    );
  }

  Widget _buildRoleFilterButton() {
    return _toolbarIconButton(
      icon: Icons.badge_outlined,
      tooltip: _filterRole == null ? 'Filter by role' : 'Role: $_filterRole',
      active: _filterRole != null,
      activeColor: _filterRole != null
          ? _roleColor(_filterRole!)
          : AppDS.accent,
      onSelected: (value) {
        setState(() => _filterRole = value.isEmpty ? null : value);
        _applyFilter();
      },
      items: [
        PopupMenuItem<String>(
          value: '',
          child: Row(
            children: [
              Icon(
                Icons.filter_alt_off_outlined,
                size: 16,
                color: context.appTextMuted,
              ),
              const SizedBox(width: 8),
              Text(
                'All Roles',
                style: _spaceGrotesk(
                  fontSize: 13,
                  color: context.appTextPrimary,
                ),
              ),
            ],
          ),
        ),
        const PopupMenuDivider(),
        ..._roleOptions.map(
          (role) => PopupMenuItem<String>(
            value: role,
            child: Row(
              children: [
                Icon(_sortIcon('user_role'), size: 16, color: _roleColor(role)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    role,
                    style: _spaceGrotesk(
                      fontSize: 13,
                      color: context.appTextPrimary,
                      fontWeight: role == _filterRole
                          ? FontWeight.w700
                          : FontWeight.w500,
                    ),
                  ),
                ),
                if (role == _filterRole)
                  const Icon(Icons.check, size: 14, color: AppDS.accent),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStatusFilterButton() {
    return _toolbarIconButton(
      icon: Icons.fact_check_outlined,
      tooltip: _filterStatus == null
          ? 'Filter by status'
          : 'Status: $_filterStatus',
      active: _filterStatus != null,
      activeColor: _filterStatus != null
          ? _statusColor(_filterStatus!)
          : AppDS.accent,
      onSelected: (value) {
        setState(() => _filterStatus = value.isEmpty ? null : value);
        _applyFilter();
      },
      items: [
        PopupMenuItem<String>(
          value: '',
          child: Row(
            children: [
              Icon(
                Icons.filter_alt_off_outlined,
                size: 16,
                color: context.appTextMuted,
              ),
              const SizedBox(width: 8),
              Text(
                'All Statuses',
                style: _spaceGrotesk(
                  fontSize: 13,
                  color: context.appTextPrimary,
                ),
              ),
            ],
          ),
        ),
        const PopupMenuDivider(),
        ..._statusOptions.map(
          (status) => PopupMenuItem<String>(
            value: status,
            child: Row(
              children: [
                Icon(
                  _sortIcon('user_status'),
                  size: 16,
                  color: _statusColor(status),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    status,
                    style: _spaceGrotesk(
                      fontSize: 13,
                      color: context.appTextPrimary,
                      fontWeight: status == _filterStatus
                          ? FontWeight.w700
                          : FontWeight.w500,
                    ),
                  ),
                ),
                if (status == _filterStatus)
                  const Icon(Icons.check, size: 14, color: AppDS.accent),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSortButton() {
    return _toolbarIconButton(
      icon: _sortAsc
          ? Icons.arrow_downward_rounded
          : Icons.arrow_upward_rounded,
      tooltip: 'Sort by $_activeSortLabel',
      active: true,
      onSelected: _sort,
      items: _cols
          .map(
            (col) => PopupMenuItem<String>(
              value: col.$1,
              child: Row(
                children: [
                  Icon(
                    _sortIcon(col.$1),
                    size: 16,
                    color: context.appTextSecondary,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      col.$2,
                      style: _spaceGrotesk(
                        fontSize: 13,
                        color: context.appTextPrimary,
                        fontWeight: col.$1 == _sortKey
                            ? FontWeight.w700
                            : FontWeight.w500,
                      ),
                    ),
                  ),
                  if (col.$1 == _sortKey)
                    Icon(
                      _sortAsc ? Icons.arrow_upward : Icons.arrow_downward,
                      size: 14,
                      color: AppDS.accent,
                    ),
                ],
              ),
            ),
          )
          .toList(),
    );
  }

  Widget _buildUserCard(_User u) {
    final roleColor = _roleColor(u.role);
    final isPending = u.status == 'pending';
    final canManage = context.canEditModule;
    final isCurrentUser = _isCurrentUser(u);
    final isDeleting = _deletingUserIds.contains(u.id);
    final borderColor = isPending
        ? AppDS.orange.withValues(alpha: 0.36)
        : context.appBorder;
    final affiliation = [
      if (u.institution?.trim().isNotEmpty == true) u.institution!.trim(),
      if (u.group?.trim().isNotEmpty == true) u.group!.trim(),
    ].join('  •  ');

    final avatar = CircleAvatar(
      radius: 19,
      backgroundColor: roleColor.withValues(alpha: 0.16),
      backgroundImage: u.avatarUrl?.trim().isNotEmpty == true
          ? NetworkImage(u.avatarUrl!.trim())
          : null,
      child: u.avatarUrl?.trim().isNotEmpty == true
          ? null
          : Text(
              u.initials,
              style: _spaceGrotesk(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: roleColor,
              ),
            ),
    );
    final identity = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          u.displayName,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: _spaceGrotesk(
            fontSize: 14,
            fontWeight: FontWeight.w800,
            color: context.appTextPrimary,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          u.email,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: _jetBrainsMono(
            fontSize: 10.5,
            color: context.appTextSecondary,
          ),
        ),
        if (affiliation.isNotEmpty) ...[
          const SizedBox(height: 2),
          Text(
            affiliation,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: _spaceGrotesk(fontSize: 10.5, color: context.appTextMuted),
          ),
        ],
      ],
    );
    final badges = Wrap(
      spacing: 6,
      runSpacing: 6,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        _headerBadge(
          u.role,
          roleColor,
          icon: Icons.shield_outlined,
          onTapDown: canManage
              ? (details) => _showMenuPicker(
                  u,
                  'user_role',
                  _roleOptions.toList(),
                  details.globalPosition,
                )
              : null,
        ),
        _headerBadge(
          u.status,
          _statusColor(u.status),
          onTapDown: canManage
              ? (details) => _showMenuPicker(
                  u,
                  'user_status',
                  _statusOptions.toList(),
                  details.globalPosition,
                )
              : null,
        ),
        Tooltip(
          message: _permissionsTooltip(u),
          child: _summaryChip('Access', _overviewPermission(u)),
        ),
        if (isPending && canManage)
          TextButton.icon(
            onPressed: () => _quickAccept(u),
            icon: const Icon(Icons.check_rounded, size: 14),
            label: const Text('Activate'),
            style: TextButton.styleFrom(
              foregroundColor: AppDS.green,
              visualDensity: VisualDensity.compact,
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              textStyle: _spaceGrotesk(
                fontSize: 10.5,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
      ],
    );
    final deleteButton = Tooltip(
      message: isCurrentUser ? 'You cannot delete yourself' : 'Delete user',
      child: IconButton(
        onPressed: isCurrentUser || isDeleting ? null : () => _deleteUser(u),
        visualDensity: VisualDensity.compact,
        icon: isDeleting
            ? const SizedBox.square(
                dimension: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.delete_outline_rounded, size: 18),
        color: AppDS.red,
      ),
    );

    return Material(
      color: context.appSurface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: borderColor),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => _openDetail(u),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: LayoutBuilder(
            builder: (_, box) {
              if (box.maxWidth < 700) {
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        avatar,
                        const SizedBox(width: 10),
                        Expanded(child: identity),
                        if (context.canDeleteModule) deleteButton,
                        Icon(
                          Icons.chevron_right_rounded,
                          color: context.appTextMuted,
                          size: 20,
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Align(alignment: Alignment.centerLeft, child: badges),
                  ],
                );
              }
              return Row(
                children: [
                  avatar,
                  const SizedBox(width: 11),
                  Expanded(flex: 3, child: identity),
                  const SizedBox(width: 16),
                  Expanded(flex: 2, child: badges),
                  const SizedBox(width: 8),
                  if (context.canDeleteModule) deleteButton,
                  Tooltip(
                    message: 'Open full user profile',
                    child: Icon(
                      Icons.chevron_right_rounded,
                      color: context.appTextMuted,
                      size: 20,
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  // Kept as the expanded profile-card implementation for potential reuse.
  // ignore: unused_element
  Widget _buildIdentityPanel(_User u) {
    final facts = <({String label, String value, bool mono})>[
      (label: 'Email', value: u.email, mono: true),
      (
        label: 'Institution',
        value: u.institution?.trim().isNotEmpty == true
            ? u.institution!.trim()
            : '—',
        mono: false,
      ),
      (
        label: 'Group / Lab',
        value: u.group?.trim().isNotEmpty == true ? u.group!.trim() : '—',
        mono: false,
      ),
      (
        label: 'Phone',
        value: u.phone?.trim().isNotEmpty == true ? u.phone!.trim() : '—',
        mono: false,
      ),
      (
        label: 'Created',
        value: u.createdAt != null
            ? _dtFmt.format(u.createdAt!.toLocal())
            : '—',
        mono: true,
      ),
      (
        label: 'Last Login',
        value: u.lastLogin != null
            ? _dtTimeFmt.format(u.lastLogin!.toLocal())
            : '—',
        mono: true,
      ),
    ];
    return _sectionPanel(
      icon: Icons.badge_outlined,
      title: 'Identification',
      child: LayoutBuilder(
        builder: (_, box) {
          final wide = box.maxWidth >= 430;
          final tileW = wide ? (box.maxWidth - 10) / 2 : box.maxWidth;
          return Wrap(
            spacing: 10,
            runSpacing: 10,
            children: facts
                .map(
                  (fact) => SizedBox(
                    width: tileW,
                    child: _factTile(fact.label, fact.value, mono: fact.mono),
                  ),
                )
                .toList(),
          );
        },
      ),
    );
  }

  // Kept with the expanded identity panel above.
  // ignore: unused_element
  Widget _buildAccessPanel(_User u) {
    final canManage = context.canEditModule;
    final isAdminLike = u.role == 'superadmin' || u.role == 'admin';
    final corePermissions = <({String label, String permission})>[
      (
        label: 'Dashboard',
        permission: _effectivePermission(u.permDashboard, u),
      ),
      (label: 'Labels', permission: _effectivePermission(u.permLabels, u)),
      (label: 'Chat', permission: _effectivePermission(u.permChat, u)),
      (label: 'Backups', permission: _effectivePermission(u.permBackups, u)),
    ];
    final labPermissions = <({String label, String permission})>[
      (
        label: 'Culture Collection',
        permission: _effectivePermission(u.permCulture, u),
      ),
      (label: 'Fish Facility', permission: _effectivePermission(u.permFish, u)),
      (
        label: 'Resources',
        permission: _effectivePermission(u.permResources, u),
      ),
    ];

    return Tooltip(
      message: _permissionsTooltip(u),
      waitDuration: const Duration(milliseconds: 250),
      child: _sectionPanel(
        icon: Icons.admin_panel_settings_outlined,
        title: 'Permissions',
        trailing: Text(
          canManage
              ? 'Tap role or status to change'
              : 'Open profile for full editor',
          style: _spaceGrotesk(fontSize: 10, color: context.appTextMuted),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _headerBadge(
                  u.role,
                  _roleColor(u.role),
                  icon: Icons.shield_outlined,
                  onTapDown: canManage
                      ? (d) => _showMenuPicker(
                          u,
                          'user_role',
                          _roleOptions.toList(),
                          d.globalPosition,
                        )
                      : null,
                ),
                _headerBadge(
                  u.status,
                  _statusColor(u.status),
                  icon: Icons.verified_user_outlined,
                  onTapDown: canManage
                      ? (d) => _showMenuPicker(
                          u,
                          'user_status',
                          _statusOptions.toList(),
                          d.globalPosition,
                        )
                      : null,
                ),
                _summaryChip('Overview', _overviewPermission(u)),
                if (u.status == 'pending' && canManage)
                  InkWell(
                    borderRadius: BorderRadius.circular(999),
                    onTap: () => _quickAccept(u),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: AppDS.green.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(
                          color: AppDS.green.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.check_circle_outline,
                            size: 14,
                            color: AppDS.green,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'Activate',
                            style: _spaceGrotesk(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: AppDS.green,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
            if (isAdminLike) ...[
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 11,
                  vertical: 9,
                ),
                decoration: BoxDecoration(
                  color: AppDS.orange.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: AppDS.orange.withValues(alpha: 0.28),
                  ),
                ),
                child: Text(
                  'Administrative role grants write access across the app.',
                  style: _spaceGrotesk(
                    fontSize: 11,
                    color: AppDS.orange,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
            const SizedBox(height: 12),
            Text(
              'General Access',
              style: _spaceGrotesk(
                fontSize: 10.5,
                fontWeight: FontWeight.w700,
                color: context.appTextMuted,
                letterSpacing: 0.3,
              ),
            ),
            const SizedBox(height: 8),
            _buildPermissionTiles(corePermissions),
            const SizedBox(height: 12),
            Text(
              'Lab Modules',
              style: _spaceGrotesk(
                fontSize: 10.5,
                fontWeight: FontWeight.w700,
                color: context.appTextMuted,
                letterSpacing: 0.3,
              ),
            ),
            const SizedBox(height: 8),
            _buildPermissionTiles(labPermissions),
          ],
        ),
      ),
    );
  }

  Widget _sectionPanel({
    required IconData icon,
    required String title,
    required Widget child,
    Widget? trailing,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: context.isDark ? context.appSurface2 : const Color(0xFFF8FBFA),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.appBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, size: 16, color: AppDS.accent),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: _spaceGrotesk(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w800,
                    color: context.appTextPrimary,
                  ),
                ),
              ),
              if (trailing != null) ...[
                const SizedBox(width: 10),
                Flexible(child: trailing),
              ],
            ],
          ),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }

  Widget _factTile(String label, String value, {bool mono = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
      decoration: BoxDecoration(
        color: context.appSurface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: context.appBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label.toUpperCase(),
            style: _spaceGrotesk(
              fontSize: 9,
              fontWeight: FontWeight.w700,
              color: context.appTextMuted,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: mono
                ? _jetBrainsMono(fontSize: 11, color: context.appTextPrimary)
                : _spaceGrotesk(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: value == '—'
                        ? context.appTextMuted
                        : context.appTextPrimary,
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildPermissionTiles(
    List<({String label, String permission})> permissions,
  ) {
    return LayoutBuilder(
      builder: (_, box) {
        final tileW = box.maxWidth >= 430
            ? (box.maxWidth - 10) / 2
            : box.maxWidth;
        return Wrap(
          spacing: 8,
          runSpacing: 8,
          children: permissions
              .map(
                (entry) => SizedBox(
                  width: tileW,
                  child: _permissionTile(entry.label, entry.permission),
                ),
              )
              .toList(),
        );
      },
    );
  }

  Widget _permissionTile(String label, String permission) {
    final color = _permColor(permission);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.28)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: _spaceGrotesk(
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
                color: context.appTextPrimary,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Text(
            _permWord(permission).toUpperCase(),
            style: _jetBrainsMono(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _headerBadge(
    String label,
    Color color, {
    IconData? icon,
    GestureTapDownCallback? onTapDown,
  }) {
    final chip = Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.26)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 13, color: color),
            const SizedBox(width: 6),
          ],
          Text(
            label,
            style: _spaceGrotesk(
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
          if (onTapDown != null) ...[
            const SizedBox(width: 6),
            Icon(Icons.expand_more, size: 14, color: color),
          ],
        ],
      ),
    );
    if (onTapDown == null) return chip;
    return GestureDetector(onTapDown: onTapDown, child: chip);
  }

  // ── Color / label helpers ─────────────────────────────────────────────────
  static Color _roleColor(String r) {
    switch (r) {
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

  static Color _statusColor(String s) {
    switch (s) {
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

  static Color _permColor(String p) {
    switch (p) {
      case 'write':
        return AppDS.green;
      case 'read':
        return AppDS.accent;
      case 'see':
        return AppDS.yellow;
      default:
        return AppDS.tableTextMute;
    }
  }

  static String _permWord(String p) {
    switch (p) {
      case 'write':
        return 'Write';
      case 'read':
        return 'Read';
      case 'see':
        return 'See';
      default:
        return 'None';
    }
  }

  String _effectivePermission(String permission, _User u) {
    if (u.role == 'superadmin' || u.role == 'admin') return 'write';
    return permission;
  }

  String _overviewPermission(_User u) {
    if (u.role == 'superadmin' || u.role == 'admin') return 'write';
    final permissions = [
      u.permDashboard,
      u.permLabels,
      u.permChat,
      u.permBackups,
    ];
    var best = 'none';
    for (final permission in permissions) {
      if (_permissionRank(permission) > _permissionRank(best)) {
        best = permission;
      }
    }
    return best;
  }

  static int _permissionRank(String permission) {
    switch (permission) {
      case 'write':
        return 3;
      case 'read':
        return 2;
      case 'see':
        return 1;
      default:
        return 0;
    }
  }

  Widget _summaryChip(String label, String permission) {
    final color = _permColor(permission);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.28)),
      ),
      child: Text(
        '$label ${_permWord(permission)}',
        style: _jetBrainsMono(
          fontSize: 9.5,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }

  String _permissionsTooltip(_User u) {
    final lines = <String>[
      'Open the full profile for the complete permission editor.',
      'Overview: ${_permWord(_overviewPermission(u))}',
      'Culture Collection: ${_permWord(_effectivePermission(u.permCulture, u))}',
      'Fish Facility: ${_permWord(_effectivePermission(u.permFish, u))}',
      'Resources: ${_permWord(_effectivePermission(u.permResources, u))}',
    ];
    if (u.supportsGranularPermissions && u.granularPageCount > 0) {
      lines.add(
        'Granular page rules exist and are available in the full profile only.',
      );
    }
    return lines.join('\n');
  }
}

// ── Public export of model and helpers for detail page ────────────────────────
class UserModel {
  static Color roleColor(String r) => _UsersPageState._roleColor(r);
  static Color statusColor(String s) => _UsersPageState._statusColor(s);
  static Color permColor(String p) => _UsersPageState._permColor(p);
}
