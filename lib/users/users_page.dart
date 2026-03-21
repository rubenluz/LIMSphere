import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '/core/data_cache.dart';
import '/theme/theme.dart';
import '/theme/grid_widgets.dart';
import '../fish_facility/shared_widgets.dart';
import 'user_detail_page.dart';

// ignore_for_file: use_build_context_synchronously

// ═════════════════════════════════════════════════════════════════════════════
// Model
// ═════════════════════════════════════════════════════════════════════════════
class _User {
  final int     id;
  String?  name;
  String   email;
  String   role;
  String   status;
  String?  phone;
  String?  orcid;
  String?  institution;
  String?  group;
  String?  avatarUrl;
  String?  bio;
  String?  timezone;
  String?  language;
  String   permDashboard;
  String   permChat;
  String   permCulture;
  String   permFish;
  String   permResources;
  bool     notificationsEnabled;
  DateTime? createdAt;
  DateTime? updatedAt;
  DateTime? lastLogin;
  String?  authUid;

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
    required this.permChat,
    required this.permCulture,
    required this.permFish,
    required this.permResources,
    required this.notificationsEnabled,
    this.createdAt,
    this.updatedAt,
    this.lastLogin,
    this.authUid,
  });

  factory _User.fromMap(Map<String, dynamic> m) => _User(
    id:                  m['user_id']          as int,
    name:                m['user_name']         as String?,
    email:               (m['user_email']       as String?) ?? '',
    role:                (m['user_role']        as String?) ?? 'researcher',
    status:              (m['user_status']      as String?) ?? 'pending',
    phone:               m['user_phone']        as String?,
    orcid:               m['user_orcid']        as String?,
    institution:         m['user_institution']  as String?,
    group:               m['user_group']        as String?,
    avatarUrl:           m['user_avatar_url']   as String?,
    bio:                 m['user_bio']          as String?,
    timezone:            m['user_timezone']     as String?,
    language:            m['user_language']     as String?,
    permDashboard:       (m['user_table_dashboard']         as String?) ?? 'none',
    permChat:            (m['user_table_chat']              as String?) ?? 'none',
    permCulture:         (m['user_table_culture_collection'] as String?) ?? 'none',
    permFish:            (m['user_table_fish_facility']     as String?) ?? 'none',
    permResources:       (m['user_table_resources']         as String?) ?? 'none',
    notificationsEnabled:(m['user_notifications_enabled']   as bool?) ?? true,
    createdAt:           _dt(m['user_created_at']),
    updatedAt:           _dt(m['user_updated_at']),
    lastLogin:           _dt(m['user_last_login']),
    authUid:             m['user_auth_uid']     as String?,
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
    'user_table_chat': permChat,
    'user_table_culture_collection': permCulture,
    'user_table_fish_facility': permFish,
    'user_table_resources': permResources,
    'user_notifications_enabled': notificationsEnabled,
    'user_created_at': createdAt?.toIso8601String(),
    'user_updated_at': updatedAt?.toIso8601String(),
    'user_last_login': lastLogin?.toIso8601String(),
    'user_auth_uid': authUid,
  };

  String get displayName => name?.isNotEmpty == true ? name! : email;
  String get initials {
    if (name != null && name!.isNotEmpty) {
      final parts = name!.trim().split(' ');
      if (parts.length >= 2) return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
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
  ('user_name',                    'Name',          160.0),
  ('user_email',                   'Email',         200.0),
  ('user_role',                    'Role',          105.0),
  ('user_status',                  'Status',         90.0),
  ('user_institution',             'Institution',   150.0),
  ('user_group',                   'Group',         110.0),
  ('user_phone',                   'Phone',         110.0),
  ('user_table_dashboard',         'Dashboard',      80.0),
  ('user_table_chat',              'Chat',           60.0),
  ('user_table_culture_collection','Culture',        72.0),
  ('user_table_fish_facility',     'Fish Fac.',      72.0),
  ('user_table_resources',         'Resources',      80.0),
  ('user_last_login',              'Last Login',    130.0),
  ('user_created_at',              'Created',       110.0),
];

const _roleOptions   = ['superadmin', 'admin', 'technician', 'researcher', 'viewer'];
const _statusOptions = ['pending', 'active', 'inactive'];
const _permOptions   = ['none', 'read', 'write'];

final _dtFmt     = DateFormat('yyyy-MM-dd');
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
  List<_User> _users    = [];
  List<_User> _filtered = [];
  bool    _loading = true;
  String? _error;
  String? _filterRole;
  String? _filterStatus;
  String  _sortKey = 'user_name';
  bool    _sortAsc = true;

  final _searchCtrl  = TextEditingController();
  final _editCtrl    = TextEditingController();
  final _horizCtrl   = ScrollController();
  final _vertCtrl    = ScrollController();
  final _hOffset     = ValueNotifier<double>(0);
  final _vOffset     = ValueNotifier<double>(0);
  Map<String, dynamic>? _editingCell; // {id, key}

  static double get _tableWidth =>
      36.0 + _cols.fold<double>(0.0, (s, c) => s + c.$3);

  @override
  void initState() {
    super.initState();
    _load();
    _searchCtrl.addListener(_applyFilter);
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _editCtrl.dispose();
    _horizCtrl.dispose();
    _vertCtrl.dispose();
    _hOffset.dispose();
    _vOffset.dispose();
    super.dispose();
  }

  // ── Data ──────────────────────────────────────────────────────────────────
  Future<void> _load() async {
    final cached = await DataCache.read('users');
    if (cached != null && mounted) {
      _users = cached.map((r) => _User.fromMap(Map<String, dynamic>.from(r as Map))).toList();
      _applyFilter();
      setState(() { _loading = false; _error = null; });
    } else {
      setState(() { _loading = true; _error = null; });
    }
    try {
      final rows = await Supabase.instance.client
          .from('users')
          .select()
          .order('user_name') as List<dynamic>;
      await DataCache.write('users', rows);
      if (!mounted) return;
      _users = rows
          .map((r) => _User.fromMap(Map<String, dynamic>.from(r as Map)))
          .toList();
      _applyFilter();
      setState(() => _loading = false);
    } catch (e) {
      if (cached == null && mounted) setState(() { _loading = false; _error = e.toString(); });
    }
  }

  void _applyFilter() {
    var d = _users.toList();
    final q = _searchCtrl.text.toLowerCase();
    if (q.isNotEmpty) {
      d = d.where((u) =>
        u.displayName.toLowerCase().contains(q) ||
        u.email.toLowerCase().contains(q) ||
        (u.institution?.toLowerCase().contains(q) ?? false) ||
        (u.group?.toLowerCase().contains(q) ?? false)
      ).toList();
    }
    if (_filterRole   != null) d = d.where((u) => u.role   == _filterRole).toList();
    if (_filterStatus != null) d = d.where((u) => u.status == _filterStatus).toList();

    d.sort((a, b) {
      final av = _sortValue(a, _sortKey);
      final bv = _sortValue(b, _sortKey);
      final c  = av.compareTo(bv);
      return _sortAsc ? c : -c;
    });
    setState(() => _filtered = d);
  }

  String _sortValue(_User u, String key) {
    switch (key) {
      case 'user_name':       return u.displayName.toLowerCase();
      case 'user_email':      return u.email.toLowerCase();
      case 'user_role':       return u.role;
      case 'user_status':     return u.status;
      case 'user_institution':return u.institution?.toLowerCase() ?? '';
      case 'user_group':      return u.group?.toLowerCase() ?? '';
      case 'user_last_login': return u.lastLogin?.toIso8601String() ?? '';
      case 'user_created_at': return u.createdAt?.toIso8601String() ?? '';
      default: return '';
    }
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
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: isError ? AppDS.red : context.appSurface3,
    ));
  }

  Future<void> _commit(_User u, String dbCol, dynamic value) async {
    try {
      await Supabase.instance.client
          .from('users')
          .update({dbCol: value, 'user_updated_at': DateTime.now().toIso8601String()})
          .eq('user_id', u.id);
    } catch (e) {
      _snack('Save failed: $e', isError: true);
    }
  }

  Future<void> _commitText(_User u, String key, String raw) async {
    final val = raw.trim().isEmpty ? null : raw.trim();
    setState(() { _applyLocalText(u, key, val); _editingCell = null; });
    await _commit(u, key, val);
  }

  void _applyLocalText(_User u, String key, String? v) {
    switch (key) {
      case 'user_name':        u.name        = v; break;
      case 'user_email':       if (v != null) u.email = v; break;
      case 'user_institution': u.institution = v; break;
      case 'user_group':       u.group       = v; break;
      case 'user_phone':       u.phone       = v; break;
    }
  }

  Future<void> _commitDropdown(_User u, String key, String val) async {
    setState(() { _applyLocalDrop(u, key, val); });
    await _commit(u, key, val);
  }

  void _applyLocalDrop(_User u, String key, String v) {
    switch (key) {
      case 'user_role':                     u.role          = v; break;
      case 'user_status':                   u.status        = v; break;
      case 'user_table_dashboard':          u.permDashboard = v; break;
      case 'user_table_chat':               u.permChat      = v; break;
      case 'user_table_culture_collection': u.permCulture   = v; break;
      case 'user_table_fish_facility':      u.permFish      = v; break;
      case 'user_table_resources':          u.permResources = v; break;
    }
  }

  Future<void> _quickAccept(_User u) async {
    setState(() => u.status = 'active');
    await _commit(u, 'user_status', 'active');
    _snack('${u.displayName} activated');
  }

  Future<void> _showMenuPicker(
      _User u, String key, List<String> options, Offset pos) async {
    final current = _fieldVal(u, key);
    final result = await showMenu<String>(
      context: context,
      position: RelativeRect.fromLTRB(pos.dx, pos.dy, pos.dx + 1, pos.dy + 1),
      color: context.appSurface2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: context.appBorder),
      ),
      items: options.map((o) => PopupMenuItem<String>(
        value: o,
        child: Row(children: [
          Text(o,
              style: GoogleFonts.spaceGrotesk(
                  fontSize: 13,
                  color: context.appTextPrimary,
                  fontWeight:
                      current == o ? FontWeight.w700 : FontWeight.normal)),
          if (current == o) ...[
            const Spacer(),
            const Icon(Icons.check, size: 14, color: AppDS.accent),
          ],
        ]),
      )).toList(),
    );
    if (result != null && result != current) {
      await _commitDropdown(u, key, result);
    }
  }

  String? _fieldVal(_User u, String key) {
    switch (key) {
      case 'user_name':                     return u.name;
      case 'user_email':                    return u.email;
      case 'user_role':                     return u.role;
      case 'user_status':                   return u.status;
      case 'user_institution':              return u.institution;
      case 'user_group':                    return u.group;
      case 'user_phone':                    return u.phone;
      case 'user_table_dashboard':          return u.permDashboard;
      case 'user_table_chat':               return u.permChat;
      case 'user_table_culture_collection': return u.permCulture;
      case 'user_table_fish_facility':      return u.permFish;
      case 'user_table_resources':          return u.permResources;
      case 'user_last_login':
        return u.lastLogin != null ? _dtTimeFmt.format(u.lastLogin!.toLocal()) : null;
      case 'user_created_at':
        return u.createdAt != null ? _dtFmt.format(u.createdAt!.toLocal()) : null;
      default: return null;
    }
  }

  void _openDetail(_User u) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => UserDetailPage(
          userMap: u.toMap(),
          onSaved: _load,
        ),
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
    final pendingCount = _users.where((u) => u.status == 'pending').length;
    return Container(
      color: context.appBg,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: Row(
        children: [
          SizedBox(
            width: 240,
            child: TextField(
              controller: _searchCtrl,
              style: GoogleFonts.spaceGrotesk(
                  fontSize: 13, color: context.appTextPrimary),
              decoration: InputDecoration(
                hintText: 'Search users…',
                hintStyle: GoogleFonts.spaceGrotesk(
                    fontSize: 12, color: context.appTextMuted),
                prefixIcon: Icon(Icons.search,
                    size: 16, color: context.appTextMuted),
                suffixIcon: _searchCtrl.text.isNotEmpty
                    ? IconButton(
                        icon: Icon(Icons.clear,
                            size: 14, color: context.appTextMuted),
                        onPressed: () {
                          _searchCtrl.clear();
                          _applyFilter();
                        },
                      )
                    : null,
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(vertical: 8),
                filled: true,
                fillColor: context.appSurface,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: context.appBorder),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: context.appBorder),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: AppDS.accent),
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          AppFilterChip(
            label: 'Role',
            value: _filterRole,
            options: _roleOptions.toList(),
            onChanged: (v) { setState(() => _filterRole = v); _applyFilter(); },
          ),
          const SizedBox(width: 8),
          AppFilterChip(
            label: 'Status',
            value: _filterStatus,
            options: _statusOptions.toList(),
            onChanged: (v) { setState(() => _filterStatus = v); _applyFilter(); },
          ),
          const Spacer(),
          if (pendingCount > 0)
            Container(
              margin: const EdgeInsets.only(right: 12),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: AppDS.orange.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                    color: AppDS.orange.withValues(alpha: 0.4)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.hourglass_top_outlined,
                      size: 12, color: AppDS.orange),
                  const SizedBox(width: 5),
                  Text(
                    '$pendingCount pending',
                    style: GoogleFonts.spaceGrotesk(
                        fontSize: 12,
                        color: AppDS.orange,
                        fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
          Text(
            '${_filtered.length} of ${_users.length}',
            style: GoogleFonts.jetBrainsMono(
                fontSize: 11, color: context.appTextMuted),
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(
          child: CircularProgressIndicator(color: AppDS.accent));
    }
    if (_error != null) {
      return Center(
        child: Text(_error!,
            style:
                GoogleFonts.spaceGrotesk(color: AppDS.red, fontSize: 13)),
      );
    }
    if (_filtered.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.people_outline,
                size: 52, color: context.appTextMuted),
            const SizedBox(height: 14),
            Text(
              _users.isEmpty ? 'No users found.' : 'No users match.',
              style: GoogleFonts.spaceGrotesk(
                  fontSize: 14, color: context.appTextSecondary),
            ),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.all(8),
      child: Column(
        children: [
          Expanded(
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppDS.tableBorder),
                      boxShadow: const [
                        BoxShadow(
                            color: AppDS.shadow,
                            blurRadius: 4,
                            offset: Offset(0, 2))
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: NotificationListener<ScrollNotification>(
                        onNotification: (n) {
                          if (n is ScrollUpdateNotification) {
                            if (n.metrics.axis == Axis.horizontal) {
                              _hOffset.value = _horizCtrl.hasClients
                                  ? _horizCtrl.offset
                                  : 0.0;
                            } else {
                              _vOffset.value = _vertCtrl.hasClients
                                  ? _vertCtrl.offset
                                  : 0.0;
                            }
                          }
                          return false;
                        },
                        child: SingleChildScrollView(
                          controller: _horizCtrl,
                          scrollDirection: Axis.horizontal,
                          child: SizedBox(
                            width: _tableWidth,
                            child: Column(children: [
                              _buildHeader(),
                              Container(
                                  height: 1, color: AppDS.tableBorder),
                              Expanded(
                                child: ListView.builder(
                                  controller: _vertCtrl,
                                  itemCount: _filtered.length,
                                  itemExtent: AppDS.tableRowH,
                                  itemBuilder: (_, i) =>
                                      _buildRow(_filtered[i], i),
                                ),
                              ),
                            ]),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                AppVerticalThumb(
                  contentLength: _filtered.length * AppDS.tableRowH,
                  topPadding: AppDS.tableHeaderH,
                  offset: _vOffset,
                  onScrollTo: (y) {
                    final max = _vertCtrl.hasClients
                        ? _vertCtrl.position.maxScrollExtent
                        : 0.0;
                    final c = y.clamp(0.0, max);
                    _vertCtrl.jumpTo(c);
                    _vOffset.value = c;
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 4),
          AppHorizontalThumb(
            contentWidth: _tableWidth,
            offset: _hOffset,
            onScrollTo: (x) {
              final max = _horizCtrl.hasClients
                  ? _horizCtrl.position.maxScrollExtent
                  : 0.0;
              final c = x.clamp(0.0, max);
              _horizCtrl.jumpTo(c);
              _hOffset.value = c;
            },
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      height: AppDS.tableHeaderH,
      color: context.appHeaderBg,
      child: Row(children: [
        const SizedBox(width: 36),
        ..._cols.map((c) => SizedBox(
          width: c.$3,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            child: SortHeader(
              label: c.$2,
              columnKey: c.$1,
              sortKey: _sortKey,
              sortAsc: _sortAsc,
              onSort: _sort,
            ),
          ),
        )),
      ]),
    );
  }

  Widget _buildRow(_User u, int i) {
    final isPending  = u.status == 'pending';
    final isInactive = u.status == 'inactive';
    Color rowBg;
    if (isPending) {
      rowBg = AppDS.orange.withValues(alpha: 0.06);
    } else if (isInactive) {
      rowBg = i.isEven ? AppDS.tableRowEven : AppDS.tableRowOdd;
    } else {
      rowBg = i.isEven ? AppDS.tableRowEven : AppDS.tableRowOdd;
    }
    final borderColor = isPending
        ? AppDS.orange.withValues(alpha: 0.25)
        : AppDS.tableBorder;

    return Container(
      decoration: BoxDecoration(
        color: rowBg,
        border: Border(bottom: BorderSide(color: borderColor, width: 1)),
      ),
      child: Row(
        children: [
          // Open detail icon
          SizedBox(
            width: 36,
            child: Tooltip(
              message: 'Open user profile',
              child: InkWell(
                onTap: () => _openDetail(u),
                child: Center(
                  child: Icon(Icons.launch_rounded,
                      size: 13, color: context.appTextMuted),
                ),
              ),
            ),
          ),
          _textCell(u, 'user_name',    160, bold: true),
          _textCell(u, 'user_email',   200, mono: true),
          _roleCell(u,                 105),
          _statusCell(u,                90),
          _textCell(u, 'user_institution', 150),
          _textCell(u, 'user_group',   110),
          _textCell(u, 'user_phone',   110),
          _permCell(u, 'user_table_dashboard',          80),
          _permCell(u, 'user_table_chat',               60),
          _permCell(u, 'user_table_culture_collection', 72),
          _permCell(u, 'user_table_fish_facility',      72),
          _permCell(u, 'user_table_resources',          80),
          _readOnlyCell(_fieldVal(u, 'user_last_login'),  130, mono: true),
          _readOnlyCell(_fieldVal(u, 'user_created_at'),  110, mono: true),
        ],
      ),
    );
  }

  // ── Cell builders ─────────────────────────────────────────────────────────
  static const _editDeco = InputDecoration(
    isDense: true,
    contentPadding: EdgeInsets.symmetric(horizontal: 6, vertical: 4),
    filled: true,
    fillColor: Colors.white,
    border: OutlineInputBorder(
      borderRadius: BorderRadius.all(Radius.circular(4)),
      borderSide: BorderSide(color: AppDS.accent, width: 1.5),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.all(Radius.circular(4)),
      borderSide: BorderSide(color: AppDS.accent, width: 1.5),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.all(Radius.circular(4)),
      borderSide: BorderSide(color: AppDS.accent, width: 1.5),
    ),
  );

  Widget _textCell(_User u, String key, double w,
      {bool bold = false, bool mono = false}) {
    final isEditing = _editingCell?['id'] == u.id &&
        _editingCell?['key'] == key;
    final val = _fieldVal(u, key);
    return GestureDetector(
      onDoubleTap: () => setState(() {
        _editingCell = {'id': u.id, 'key': key};
        _editCtrl.text = val ?? '';
      }),
      child: SizedBox(
        width: w,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
          child: isEditing
              ? TextField(
                  controller: _editCtrl,
                  autofocus: true,
                  style: GoogleFonts.spaceGrotesk(
                      fontSize: 12, color: AppDS.tableText),
                  decoration: _editDeco,
                  onSubmitted: (v) => _commitText(u, key, v),
                  onTapOutside: (_) =>
                      _commitText(u, key, _editCtrl.text),
                )
              : Text(
                  val ?? '—',
                  style: (mono
                          ? GoogleFonts.jetBrainsMono(fontSize: 11)
                          : GoogleFonts.spaceGrotesk(
                              fontSize: 12,
                              fontWeight: bold
                                  ? FontWeight.w600
                                  : FontWeight.normal))
                      .copyWith(
                          color: val == null
                              ? AppDS.tableTextMute
                              : AppDS.tableText),
                  overflow: TextOverflow.ellipsis,
                ),
        ),
      ),
    );
  }

  Widget _roleCell(_User u, double w) {
    final roleColor = _roleColor(u.role);
    return GestureDetector(
      onDoubleTapDown: (d) =>
          _showMenuPicker(u, 'user_role', _roleOptions.toList(), d.globalPosition),
      child: SizedBox(
        width: w,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
            decoration: BoxDecoration(
              color: roleColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: roleColor.withValues(alpha: 0.3)),
            ),
            child: Text(
              u.role,
              style: GoogleFonts.spaceGrotesk(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: roleColor,
                  letterSpacing: 0.2),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
      ),
    );
  }

  Widget _statusCell(_User u, double w) {
    final sc = _statusColor(u.status);
    return GestureDetector(
      onDoubleTapDown: (d) => _showMenuPicker(
          u, 'user_status', _statusOptions.toList(), d.globalPosition),
      child: SizedBox(
        width: w,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Status badge
              Flexible(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(
                    color: sc.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: sc.withValues(alpha: 0.3)),
                  ),
                  child: Text(
                    u.status,
                    style: GoogleFonts.spaceGrotesk(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: sc,
                        letterSpacing: 0.2),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
              // Quick accept for pending
              if (u.status == 'pending') ...[
                const SizedBox(width: 4),
                Tooltip(
                  message: 'Activate user',
                  child: InkWell(
                    onTap: () => _quickAccept(u),
                    borderRadius: BorderRadius.circular(4),
                    child: const Padding(
                      padding: EdgeInsets.all(2),
                      child: Icon(Icons.check_circle_outline,
                          size: 14, color: AppDS.green),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _permCell(_User u, String key, double w) {
    final val = _fieldVal(u, key) ?? 'none';
    final c   = _permColor(val);
    return GestureDetector(
      onDoubleTapDown: (d) =>
          _showMenuPicker(u, key, _permOptions.toList(), d.globalPosition),
      child: SizedBox(
        width: w,
        child: Center(
          child: Text(
            _permLabel(val),
            style: GoogleFonts.jetBrainsMono(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: c),
          ),
        ),
      ),
    );
  }

  Widget _readOnlyCell(String? val, double w, {bool mono = false}) {
    return SizedBox(
      width: w,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        child: Text(
          val ?? '—',
          style: (mono
                  ? GoogleFonts.jetBrainsMono(fontSize: 11)
                  : GoogleFonts.spaceGrotesk(fontSize: 12))
              .copyWith(
                  color:
                      val == null ? AppDS.tableTextMute : AppDS.tableTextMute),
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }

  // ── Color / label helpers ─────────────────────────────────────────────────
  static Color _roleColor(String r) {
    switch (r) {
      case 'superadmin':  return AppDS.red;
      case 'admin':       return AppDS.orange;
      case 'technician':  return AppDS.accent;
      case 'researcher':  return AppDS.green;
      case 'viewer':      return AppDS.textMuted;
      default:            return AppDS.textSecondary;
    }
  }

  static Color _statusColor(String s) {
    switch (s) {
      case 'active':   return AppDS.green;
      case 'pending':  return AppDS.orange;
      case 'inactive': return AppDS.textMuted;
      default:         return AppDS.textSecondary;
    }
  }

  static Color _permColor(String p) {
    switch (p) {
      case 'write': return AppDS.green;
      case 'read':  return AppDS.accent;
      default:      return AppDS.tableTextMute;
    }
  }

  static String _permLabel(String p) {
    switch (p) {
      case 'write': return 'W';
      case 'read':  return 'R';
      default:      return '—';
    }
  }
}


// ── Public export of model and helpers for detail page ────────────────────────
class UserModel {
  static Color roleColor(String r)   => _UsersPageState._roleColor(r);
  static Color statusColor(String s) => _UsersPageState._statusColor(s);
  static Color permColor(String p)   => _UsersPageState._permColor(p);
}
