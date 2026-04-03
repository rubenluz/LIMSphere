// menu_page.dart - Root shell: sidebar navigation with role-based module
// visibility, per-user permission checks, connectivity poll (10 s), page routing.

import 'dart:async';
import 'dart:io';
import 'package:app_links/app_links.dart';
import '../camera/qr_scanner/qr_code_rules.dart';
import '../camera/qr_scanner/qr_scanner_page.dart';
import '../camera/camera_page.dart';
import 'app_nav.dart';
import 'package:lims_sphere/lab_chat/lab_chat_page.dart';
import 'package:lims_sphere/labels/label_page.dart';
import '../locations/locations_page.dart';
import '../resources/reagents/reagents_page.dart';
import '../resources/machines/machines_page.dart';
import '../resources/reservations/reservations_page.dart';
import '/theme/theme.dart';
import '/theme/module_permission.dart';
import '../admin/settings_page.dart';
import '../admin/backups_page.dart';
import '../admin/backup_service.dart';
import 'package:lims_sphere/fish_facility/lines/fish_lines_page.dart';
import 'package:lims_sphere/fish_facility/water_qc/water_qc_page.dart';
import 'package:lims_sphere/sops/sops_page.dart';
import 'package:lims_sphere/fish_facility/stocks/stocks_page.dart';
import 'package:lims_sphere/fish_facility/tanks/tanks_page.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide LocalStorage;
import '../culture_collection/samples/samples_page.dart';
import '../culture_collection/strains/strains_page.dart';
import '../dashboard/dashboard_page.dart';
import '../users/users_page.dart';
import '../users/user_detail_page.dart';
import '../admin/app_settings.dart';
import '../audit_log/audit_log.dart';
import '../requests/requests_page.dart';

const _roleOrder = ['viewer', 'technician', 'researcher', 'admin', 'superadmin'];

bool _hasRole(String userRole, String required) {
  final ui = _roleOrder.indexOf(userRole);
  final ri = _roleOrder.indexOf(required);
  if (ui == -1 || ri == -1) return false;
  return ui >= ri;
}

/// Maps each nav-item id to the column in the `users` table that stores the
/// per-user permission for that module.  Items not listed here are gated only
/// by role (admin panel items) and always grant 'write' to admins.
const Map<String, String> _modulePermColumn = {
  'dashboard':        'user_table_dashboard',
  'labels':           'user_table_dashboard',
  'chat':             'user_table_chat',
  'backups':          'user_table_backups',
  'strains':          'user_table_culture_collection',
  'samples':          'user_table_culture_collection',
  'sops_inventory':   'user_table_culture_collection',
  'fish_stock':       'user_table_fish_facility',
  'fish_tankmap':     'user_table_fish_facility',
  'fish_lines':       'user_table_fish_facility',
  'fish_water_qc':    'user_table_fish_facility',
  'sops_fish':        'user_table_fish_facility',
  'locations':        'user_table_resources',
  'reagents':         'user_table_resources',
  'equipment':        'user_table_resources',
  'reservations':     'user_table_resources',
};

const Map<String, String?> _moduleRequiredRole = {
  'dashboard':        'technician',
  'labels':           'technician',
  'chat':             'technician',
  'requests':         null,
  'strains':          null,
  'samples':          'technician',
  'sops_inventory':   'technician',
  'fish_stock':       null,
  'fish_tankmap':     'technician',
  'fish_lines':       'technician',
  'fish_water_qc':    'technician',
  'sops_fish':        'technician',
  'locations':        'technician',
  'reagents':         'technician',
  'equipment':        'technician',
  'reservations':     'technician',
  'audit':            'admin',
  'users':            'admin',
  'backups':          null,
  'settings':         'admin',
};

class _NavItem {
  final String id;
  final String label;
  final IconData icon;
  final Color accent;
  final Widget Function(_MenuPageState state)? builder;
  /// When true, the item is hidden in the desktop sidebar and only appears
  /// in the mobile drawer.
  final bool mobileOnly;

  const _NavItem({
    required this.id,
    required this.label,
    required this.icon,
    required this.accent,
    this.builder,
    this.mobileOnly = false,
  });
}

class _NavGroup {
  final String key;
  final String label;
  final IconData icon;
  final List<_NavItem> children;
  const _NavGroup({required this.key, required this.label, required this.icon, required this.children});
}

class MenuPage extends StatefulWidget {
  const MenuPage({super.key});

  @override
  State<MenuPage> createState() => _MenuPageState();
}

class _MenuPageState extends State<MenuPage> {
  String _selectedId = 'dashboard';
  Map<String, dynamic> _userInfo = {};
  List<Map<String, dynamic>> _pendingUsers = [];
  bool _loadingUser = true;
  bool _collapsed = false;
  Set<String> _visibleGroups = {'dashboard', 'labels', 'chat', 'requests', 'culture_collection', 'fish_facility', 'resources', 'reservations'};

  // Items within a group that have their own individual visibility toggle in settings.
  static const _perItemVisibilityKeys = {'reservations'};
  Timer? _connectivityTimer;
  bool _wasOffline = false;
  StreamSubscription<Uri>? _deepLinkSub;

  final Set<String> _expandedGroups = {'Culture Collection', 'Fish Facility', 'Resources', 'Admin'};

  late final List<_NavItem> _topItems = [
    _NavItem(
      id: 'dashboard',
      label: 'Dashboard',
      icon: Icons.space_dashboard_outlined,
      accent: const Color(0xFF6366F1),
      builder: (s) => DashboardPage(
        userInfo: s._userInfo,
        pendingUsers: s._pendingUsers,
        onGoToPendingUsers: () => s._select('users'),
      ),
    ),
    _NavItem(
      id: 'labels',
      label: 'Labels',
      icon: Icons.label_outline_rounded,
      accent: const Color(0xFFF97316),
      builder: (_) => const PrintStrainsPage(),
    ),
    _NavItem(
      id: 'chat',
      label: 'Chat',
      icon: Icons.forum_outlined,
      accent: const Color(0xFF22D3EE),
      builder: (_) => const LabChatPage(),
    ),
    _NavItem(
      id: 'backups',
      label: 'Backups',
      icon: Icons.backup_outlined,
      accent: const Color(0xFF10B981),
      builder: (_) => const BackupsPage(),
    ),
    _NavItem(
      id: 'requests',
      label: 'Requests',
      icon: Icons.outbox_outlined,
      accent: const Color(0xFF8B5CF6),
      builder: (_) => const RequestsPage(),
    ),
    _NavItem(
      id: 'camera',
      label: 'Camera',
      icon: Icons.camera_alt_outlined,
      accent: const Color(0xFF38BDF8),
      mobileOnly: true,
      builder: (_) => const CameraPage(),
    ),
  ];

  late final List<_NavGroup> _groups = [
    _NavGroup(
      key: 'culture_collection',
      label: 'Culture Collection',
      icon: Icons.inventory_2_outlined,
      children: [
        _NavItem(
          id: 'strains',
          label: 'Strains',
          icon: Icons.biotech_outlined,
          accent: const Color(0xFF10B981),
          builder: (_) => const StrainsPage(),
        ),
        _NavItem(
          id: 'samples',
          label: 'Samples',
          icon: Icons.colorize_outlined,
          accent: const Color(0xFF3B82F6),
          builder: (_) => const SamplesPage(),
        ),
        _NavItem(id: 'sops_inventory', label: 'SOPs', icon: Icons.menu_book_outlined, accent: const Color(0xFF06B6D4), builder: (_) => const SopPage(sopContext: 'culture_collection')),
      ],
    ),
    _NavGroup(
      key: 'fish_facility',
      label: 'Fish Facility',
      icon: Icons.water_outlined,
      children: [
        _NavItem(id: 'fish_stock',   label: 'Stock',            icon: Icons.set_meal_outlined,           accent: const Color(0xFF0EA5E9), builder: (_) => const FishStocksPage()),
        _NavItem(id: 'fish_tankmap', label: 'Tank Map',         icon: Icons.grid_view_outlined,          accent: const Color(0xFF38BDF8), builder: (_) => const FishTanksPage()),
        _NavItem(id: 'fish_lines',    label: 'Fish Lines',       icon: Icons.science_outlined,            accent: const Color(0xFF7DD3FC), builder: (_) => const FishLinesPage()),
        _NavItem(id: 'fish_water_qc', label: 'Water QC',        icon: Icons.water_drop_outlined,         accent: const Color(0xFF22D3EE), builder: (_) => const WaterQcPage()),
        _NavItem(id: 'sops_fish',    label: 'SOPs', icon: Icons.menu_book_outlined,          accent: const Color(0xFF06B6D4), builder: (_) => const SopPage(sopContext: 'fish_facility')),
      ],
    ),
    _NavGroup(
      key: 'resources',
      label: 'Resources',
      icon: Icons.category_outlined,
      children: [
        _NavItem(id: 'locations',    label: 'Locations',    icon: Icons.place_outlined,                   accent: const Color(0xFF6366F1), builder: (_) => const LocationsPage()),
        _NavItem(id: 'reagents',     label: 'Reagents',     icon: Icons.water_drop_outlined,              accent: const Color(0xFFF59E0B), builder: (_) => const ReagentsPage()),
        _NavItem(id: 'equipment',    label: 'Machines',     icon: Icons.precision_manufacturing_outlined, accent: const Color(0xFF14B8A6), builder: (_) => const MachinesPage()),
        _NavItem(id: 'reservations', label: 'Reservations', icon: Icons.event_outlined,                   accent: const Color(0xFFEC4899), builder: (_) => const ReservationsPage()),
      ],
    ),
        _NavGroup(
          key: 'admin',
          label: 'Admin',
          icon: Icons.admin_panel_settings_outlined,
          children: [
        _NavItem(id: 'audit',    label: 'Audit Log', icon: Icons.manage_search_outlined, accent: const Color(0xFF6B7280), builder: (_) => const AuditLogPage()),
        _NavItem(id: 'users',    label: 'Users',     icon: Icons.people_outlined,        accent: const Color(0xFF6366F1), builder: (_) => const UsersPage()),
        _NavItem(id: 'settings', label: 'Settings',  icon: Icons.settings_outlined,      accent: const Color(0xFF38BDF8), builder: (s) => SettingsPage(onSettingsChanged: s._reloadSettings)),
      ],
    ),
  ];

  @override
  void initState() {
    super.initState();
    _loadUserInfo();
    _loadVisibleGroups();
    LabChatPage.startBackgroundListener();
    RequestsPage.startBackgroundListener();
    unawaited(BackupService.instance.startForSession());
    _startConnectivityTimer();
    if (Platform.isAndroid || Platform.isIOS) _initDeepLinks();
  }

  @override
  void dispose() {
    _connectivityTimer?.cancel();
    _deepLinkSub?.cancel();
    unawaited(BackupService.instance.stop());
    super.dispose();
  }

  Future<void> _initDeepLinks() async {
    final appLinks = AppLinks();
    // Cold-start link
    try {
      final initial = await appLinks.getInitialLink();
      if (initial != null && mounted) _handleDeepLink(initial);
    } catch (_) {}
    // Warm-start links
    _deepLinkSub = appLinks.uriLinkStream.listen((uri) {
      if (mounted) _handleDeepLink(uri);
    });
  }

  Future<void> _handleDeepLink(Uri uri) async {
    final payload = QrRules.parse(uri.toString());
    if (payload == null) return;
    Widget page;
    try {
      page = await resolveQrRoute(payload);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Could not open record: $e'),
        backgroundColor: const Color(0xFFEF4444),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ));
      return;
    }
    if (!mounted) return;
    Navigator.push(context, MaterialPageRoute(builder: (_) => page));
  }

  void _startConnectivityTimer() {
    _connectivityTimer = Timer.periodic(const Duration(seconds: 10), (_) async {
      bool online;
      try {
        final result = await InternetAddress.lookup('connectivitycheck.gstatic.com')
            .timeout(const Duration(seconds: 4));
        online = result.isNotEmpty && result[0].rawAddress.isNotEmpty;
      } catch (_) {
        online = false;
      }
      if (!mounted) return;
      if (!online && !_wasOffline) {
        _wasOffline = true;
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Row(children: [
            Icon(Icons.wifi_off_rounded, color: Color(0xFFD97706), size: 18),
            SizedBox(width: 8),
            Text('No internet connection'),
          ]),
          duration: Duration(seconds: 5),
        ));
      } else if (online && _wasOffline) {
        _wasOffline = false;
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Row(children: [
            Icon(Icons.wifi_rounded, color: Color(0xFF10B981), size: 18),
            SizedBox(width: 8),
            Text('Back online'),
          ]),
          duration: Duration(seconds: 3),
        ));
      }
    });
  }

  Future<void> _loadVisibleGroups() async {
    await AppSettings.load();
    if (mounted) {
      setState(() {
        _visibleGroups = AppSettings.visibleGroups;
        _ensureValidSelection();
      });
    }
  }

  void _reloadSettings() {
    setState(() {
      _visibleGroups = AppSettings.visibleGroups;
      _ensureValidSelection();
    });
  }

  /// If the currently-selected item is in a now-hidden group, reset to first visible item.
  void _ensureValidSelection() {
    final userRole = _userInfo['user_role']?.toString() ?? '';

    bool canAccess(String id) {
      final req = _moduleRequiredRole[id];
      if (req != null && !_hasRole(userRole, req)) return false;
      return _getModulePerm(id) != 'none';
    }

    // Current selection still visible and accessible?
    if (_topItems.any((i) =>
        i.id == _selectedId && _visibleGroups.contains(i.id) && canAccess(i.id))) {
      return;
    }
    if (_groups.any((g) =>
        (g.key == 'admin' ? _hasRole(userRole, 'admin') : _visibleGroups.contains(g.key)) &&
        g.children.any((i) => i.id == _selectedId && canAccess(i.id)))) {
      return;
    }

    // Pick first visible + accessible item
    for (final item in _topItems) {
      if (_visibleGroups.contains(item.id) && canAccess(item.id)) {
        _selectedId = item.id;
        return;
      }
    }
    for (final g in _groups) {
      if (g.key == 'admin' ? _hasRole(userRole, 'admin') : _visibleGroups.contains(g.key)) {
        for (final item in g.children) {
          if (canAccess(item.id)) {
            _selectedId = item.id;
            return;
          }
        }
      }
    }
    _selectedId = 'settings';
  }

  /// Returns the effective permission for [id] for the current user.
  /// Admins/superadmins always get 'write'. Items without a perm column
  /// (admin panel items) also return 'write' (gated by role instead).
  String _getModulePerm(String id) {
    final userRole = _userInfo['user_role']?.toString() ?? '';
    if (_hasRole(userRole, 'admin')) return 'write';
    final col = _modulePermColumn[id];
    if (col == null) return 'write';
    return _userInfo[col]?.toString() ?? 'none';
  }

  Future<void> _loadUserInfo() async {
    try {
      final email = Supabase.instance.client.auth.currentSession?.user.email ?? '';
      final rows = await Supabase.instance.client
          .from('users').select().eq('user_email', email).limit(1);
      if (rows.isNotEmpty) {
        setState(() {
          _userInfo = Map<String, dynamic>.from(rows[0]);
          _loadingUser = false;
        });
        if (_hasRole(_userInfo['user_role'] ?? '', 'admin')) _loadPendingUsers();
      } else {
        setState(() => _loadingUser = false);
      }
    } catch (_) {
      setState(() => _loadingUser = false);
    }
  }

  Future<void> _loadPendingUsers() async {
    try {
      final res = await Supabase.instance.client
          .from('users').select().eq('user_status', 'pending');
      setState(() => _pendingUsers = List<Map<String, dynamic>>.from(res));
    } catch (_) {}
  }

  Future<void> _logout() async {
    await Supabase.instance.client.auth.signOut();
    if (!mounted) return;
    Navigator.pushReplacementNamed(context, '/connections');
  }

  void _select(String id, [NavigatorState? nav]) {
    final userRole = _userInfo['user_role']?.toString() ?? '';
    final required = _moduleRequiredRole[id];
    if (required != null && !_hasRole(userRole, required)) {
      _showAccessDenied(id);
      nav?.pop();
      return;
    }
    if (_getModulePerm(id) == 'none') {
      _showAccessDenied(id);
      nav?.pop();
      return;
    }
    setState(() => _selectedId = id);
    nav?.pop();
  }

  void _showAccessDenied(String moduleId) async {
    String adminName = 'the administrator';
    String adminEmail = '';
    try {
      final admins = await Supabase.instance.client
          .from('users')
          .select('user_name, user_email, user_role')
          .inFilter('user_role', ['admin', 'superadmin'])
          .eq('user_status', 'active')
          .limit(1);
      if (admins.isNotEmpty) {
        adminName  = admins[0]['user_name']?.toString() ?? adminName;
        adminEmail = admins[0]['user_email']?.toString()     ?? '';
      }
    } catch (_) {}
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        duration: const Duration(seconds: 6),
        content: Row(children: [
          const Icon(Icons.lock_outline, color: AppDS.red, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: RichText(
              text: TextSpan(
                style: const TextStyle(color: Color(0xFF334155), fontSize: 13),
                children: [
                  const TextSpan(text: 'Access restricted. Contact '),
                  TextSpan(text: adminName,
                      style: const TextStyle(color: Color(0xFF0F172A), fontWeight: FontWeight.bold)),
                  if (adminEmail.isNotEmpty) ...[
                    const TextSpan(text: ' · '),
                    TextSpan(text: adminEmail,
                        style: const TextStyle(color: Color(0xFF0284C7))),
                  ],
                ],
              ),
            ),
          ),
        ]),
      ),
    );
  }

  void _goToUserDetail() {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => UserDetailPage(
        userMap: _userInfo,
        onSaved: _loadUserInfo,
      ),
    ));
  }

  // ── Content ────────────────────────────────────────────────────────────────
  Widget _buildContent(bool isMobile) {
    final content = _getContentWidget();

    // On mobile, wrap in a Scaffold so each page can have its own AppBar
    // with the drawer hamburger already embedded — no floating button needed.
    if (isMobile) {
      return content;
    }
    return content;
  }

  Widget _getContentWidget() {
    final userRole = _userInfo['user_role']?.toString() ?? '';
    for (final item in _topItems) {
      final visible = item.id == 'backups'
          ? _getModulePerm('backups') != 'none'
          : _visibleGroups.contains(item.id);
      if (!visible) continue;
      if (item.id == _selectedId && item.builder != null) {
        return _maybeWrapReadOnly(item.id, item.builder!(this));
      }
    }
    for (final g in _groups) {
      if (g.key == 'admin' ? !_hasRole(userRole, 'admin') : !_visibleGroups.contains(g.key)) continue;
      for (final item in g.children) {
        if (item.id == _selectedId && item.builder != null) {
          return _maybeWrapReadOnly(item.id, item.builder!(this));
        }
        if (item.id == _selectedId && item.builder == null) return _buildComingSoon(item);
      }
    }
    return _buildComingSoon(null);
  }

  Widget _maybeWrapReadOnly(String id, Widget content) {
    final perm = _getModulePerm(id);
    final permWidget = ModulePermission(permission: perm, child: content);
    if (perm != 'read') return permWidget;
    return Column(
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          color: const Color(0xFF92400E).withValues(alpha: 0.18),
          child: Row(children: [
            const Icon(Icons.visibility_outlined, size: 14, color: Color(0xFFFBBF24)),
            const SizedBox(width: 8),
            const Text(
              'View only — contact an admin to request edit access.',
              style: TextStyle(fontSize: 12, color: Color(0xFFFBBF24)),
            ),
          ]),
        ),
        Expanded(child: permWidget),
      ],
    );
  }

  Widget _buildComingSoon(_NavItem? item) => Center(
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      Icon(item?.icon ?? Icons.construction_outlined,
          size: 56, color: item?.accent.withValues(alpha: 0.5) ?? AppDS.textSecondary),
      const SizedBox(height: 16),
      Text(item?.label ?? 'Coming soon',
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600)),
      const SizedBox(height: 8),
      Text('This module is under development.',
          style: TextStyle(color: AppDS.textMuted)),
    ]),
  );

  // ── Sidebar ────────────────────────────────────────────────────────────────
  Widget _buildSidebar({bool isDrawer = false}) {
    final bool collapsed = !isDrawer && _collapsed;
    final double w = collapsed ? 64.0 : 240.0;
    final userRole = _userInfo['user_role']?.toString() ?? '';
    final userName = _userInfo['user_name']?.toString() ?? '';
    final pendingCount = _pendingUsers.length;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeInOut,
      width: w,
      clipBehavior: Clip.hardEdge,
      decoration: const BoxDecoration(color: AppDS.bg),
      child: SizedBox(
        width: 240,
        child: Material(
          color: AppDS.bg,
          child: Column(children: [

            // ── Logo ──────────────────────────────────────────────────────
            SizedBox(
              height: 60,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Row(children: [
                  Image.asset(
                    'assets/icon/logo.png',
                    width: 32, height: 32,
                    fit: BoxFit.contain,
                  ),
                  // Hide title when collapsed
                  if (!collapsed) ...[
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Text('LIMS Sphere',
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold,
                            fontSize: 14, overflow: TextOverflow.ellipsis)),
                    ),
                  ],
                ]),
              ),
            ),

            const Divider(color: Colors.white10, height: 1),

            // ── Nav ───────────────────────────────────────────────────────
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
                children: [
                  ..._topItems
                    .where((item) {
                      if (item.mobileOnly) return isDrawer;
                      if (item.id == 'backups') {
                        return _getModulePerm('backups') != 'none';
                      }
                      if (!_visibleGroups.contains(item.id)) return false;
                      final req = _moduleRequiredRole[item.id];
                      return req == null || _hasRole(userRole, req);
                    })
                    .map((item) => _buildLeafTile(
                      item: item,
                      collapsed: collapsed,
                      isDrawer: isDrawer,
                      userRole: userRole,
                      indented: false,
                    )),
                  const SizedBox(height: 4),
                  ..._groups.where((g) => g.key == 'admin' ? _hasRole(userRole, 'admin') : _visibleGroups.contains(g.key)).map((group) {
                    final isExpanded = _expandedGroups.contains(group.label);
                    final anyAccessible = group.children.any((c) {
                      if (_perItemVisibilityKeys.contains(c.id) && !_visibleGroups.contains(c.id)) return false;
                      final req = _moduleRequiredRole[c.id];
                      final roleOk = req == null || _hasRole(userRole, req);
                      return roleOk && _getModulePerm(c.id) != 'none';
                    });

                    // Hide groups the user has no access to (admin group always shown to admins)
                    if (!anyAccessible) return const SizedBox.shrink();

                    if (collapsed) {
                      return Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            child: Divider(color: Colors.white10, height: 1),
                          ),
                          ...group.children.where((item) => !_perItemVisibilityKeys.contains(item.id) || _visibleGroups.contains(item.id)).map((item) => _buildLeafTile(
                            item: item,
                            collapsed: true,
                            isDrawer: isDrawer,
                            userRole: userRole,
                            indented: false,
                          )),
                        ],
                      );
                    }

                    return Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        InkWell(
                          borderRadius: BorderRadius.circular(8),
                          onTap: () => setState(() {
                            isExpanded
                                ? _expandedGroups.remove(group.label)
                                : _expandedGroups.add(group.label);
                          }),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                            child: Row(children: [
                              Icon(group.icon, size: 15,
                                  color: anyAccessible ? Colors.white38 : Colors.white24),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(group.label.toUpperCase(),
                                  style: TextStyle(
                                    fontSize: 10, fontWeight: FontWeight.w700,
                                    letterSpacing: 1.1,
                                    color: anyAccessible ? Colors.white38 : Colors.white24,
                                  ),
                                ),
                              ),
                              Icon(isExpanded ? Icons.expand_less : Icons.expand_more,
                                  size: 14, color: Colors.white24),
                            ]),
                          ),
                        ),
                        AnimatedCrossFade(
                          duration: const Duration(milliseconds: 180),
                          firstCurve: Curves.easeOut,
                          secondCurve: Curves.easeIn,
                          crossFadeState: isExpanded
                              ? CrossFadeState.showFirst
                              : CrossFadeState.showSecond,
                          firstChild: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: group.children.where((item) => !_perItemVisibilityKeys.contains(item.id) || _visibleGroups.contains(item.id)).map((item) => _buildLeafTile(
                              item: item,
                              collapsed: false,
                              isDrawer: isDrawer,
                              userRole: userRole,
                              indented: true,
                            )).toList(),
                          ),
                          secondChild: const SizedBox.shrink(),
                        ),
                        const SizedBox(height: 4),
                      ],
                    );
                  }),
                ],
              ),
            ),

            const Divider(color: Colors.white10, height: 1),

            // ── User strip — hidden when collapsed, only avatar icon shown ──
            if (!collapsed)
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 6, 4),
                child: Row(children: [
                  const Icon(Icons.person, size: 16, color: Colors.white54),
                  const SizedBox(width: 6),
                  Expanded(child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(userName, style: const TextStyle(color: Colors.white,
                          fontSize: 12, fontWeight: FontWeight.w600),
                          overflow: TextOverflow.ellipsis),
                      Text(userRole, style: const TextStyle(
                          color: Colors.white38, fontSize: 10),
                          overflow: TextOverflow.ellipsis),
                    ],
                  )),
                  if (pendingCount > 0)
                    Tooltip(
                      message: '$pendingCount pending user(s)',
                      child: InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: () => _select('users', isDrawer ? Navigator.of(context) : null),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.red.shade700,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text('$pendingCount',
                              style: const TextStyle(color: Colors.white, fontSize: 10)),
                        ),
                      ),
                    ),
                  const SizedBox(width: 2),
                  Tooltip(
                    message: 'Edit profile',
                    child: InkWell(
                      borderRadius: BorderRadius.circular(16),
                      onTap: _goToUserDetail,
                      child: const Padding(
                        padding: EdgeInsets.all(6),
                        child: Icon(Icons.edit, size: 14, color: Colors.white38),
                      ),
                    ),
                  ),
                ]),
              )
            else
              // Collapsed: person icon centered
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: Tooltip(
                  message: '$userName ($userRole)',
                  child: InkWell(
                    borderRadius: BorderRadius.circular(20),
                    onTap: _goToUserDetail,
                    child: const Icon(Icons.person, size: 20, color: Colors.white54),
                  ),
                ),
              ),

            // ── Collapse + Logout ──────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(6, 4, 6, 8),
              child: Row(children: [
                if (!isDrawer)
                  Tooltip(
                    message: collapsed ? 'Expand sidebar' : 'Collapse sidebar',
                    child: IconButton(
                      icon: Icon(
                        collapsed ? Icons.chevron_right : Icons.chevron_left,
                        color: Colors.white38, size: 18,
                      ),
                      onPressed: () => setState(() => _collapsed = !_collapsed),
                    ),
                  ),
                if (!collapsed) ...[
                  const Spacer(),
                  TextButton.icon(
                    onPressed: _logout,
                    icon: const Icon(Icons.logout, size: 15, color: Colors.white38),
                    label: const Text('Logout',
                        style: TextStyle(color: Colors.white38, fontSize: 12)),
                  ),
                ],
              ]),
            ),

          ]),
        ),
      ),
    );
  }

  // ── Leaf tile ──────────────────────────────────────────────────────────────
  Widget _buildLeafTile({
    required _NavItem item,
    required bool collapsed,
    required bool isDrawer,
    required String userRole,
    required bool indented,
  }) {
    final required   = _moduleRequiredRole[item.id];
    final roleOk     = required == null || _hasRole(userRole, required);
    final perm       = _getModulePerm(item.id);
    final selected   = _selectedId == item.id;
    final blocked    = !roleOk || perm == 'none';
    final isReadOnly = !blocked && perm == 'read';

    Color iconColor;
    Color textColor;
    if (selected)             { iconColor = item.accent;    textColor = Colors.white; }
    else if (blocked)         { iconColor = Colors.white12; textColor = Colors.white24; }
    else if (item.builder == null) { iconColor = Colors.white24; textColor = Colors.white38; }
    else if (isReadOnly)      { iconColor = Colors.white38; textColor = Colors.white54; }
    else                      { iconColor = Colors.white54; textColor = Colors.white70; }

    final tile = Padding(
      padding: EdgeInsets.only(left: indented && !collapsed ? 8.0 : 0, bottom: 1),
      child: Tooltip(
        message: collapsed ? (blocked ? '${item.label} (No access)' : item.label) : '',
        child: Material(
          color: selected ? item.accent.withValues(alpha: 0.18) : Colors.transparent,
          borderRadius: BorderRadius.circular(7),
          child: InkWell(
            borderRadius: BorderRadius.circular(7),
            onTap: blocked
                ? () => _showAccessDenied(item.id)
                : item.builder == null
                    ? null
                    : () => _select(item.id, isDrawer ? Navigator.of(context) : null),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
              child: Row(children: [
                if (!collapsed && indented)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: Container(
                      width: 4, height: 4,
                      decoration: BoxDecoration(
                        color: selected ? item.accent : Colors.white12,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                item.id == 'chat'
                    ? ValueListenableBuilder<int>(
                        valueListenable: LabChatPage.unreadNotifier,
                        builder: (_, unread, _) => Stack(
                          clipBehavior: Clip.none,
                          children: [
                            Icon(item.icon, size: 17, color: iconColor),
                            if (unread > 0)
                              Positioned(
                                top: -3, right: -3,
                                child: Container(
                                  width: 7, height: 7,
                                  decoration: const BoxDecoration(
                                    color: Color(0xFFEF4444),
                                    shape: BoxShape.circle,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      )
                    : item.id == 'requests'
                        ? ValueListenableBuilder<int>(
                            valueListenable: RequestsPage.pendingNotifier,
                            builder: (_, pending, _) => Stack(
                              clipBehavior: Clip.none,
                              children: [
                                Icon(blocked ? Icons.lock_outline : item.icon, size: 17, color: iconColor),
                                if (pending > 0)
                                  Positioned(
                                    top: -4, right: -6,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF8B5CF6),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text(
                                        pending > 99 ? '99+' : '$pending',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 8,
                                          fontWeight: FontWeight.w700,
                                          height: 1.2,
                                        ),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          )
                        : Icon(blocked ? Icons.lock_outline : item.icon, size: 17, color: iconColor),
                if (!collapsed) ...[
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(item.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 13, color: textColor,
                          fontWeight: selected ? FontWeight.w600 : FontWeight.normal),
                    ),
                  ),
                  if (item.builder == null && !blocked)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                      decoration: BoxDecoration(
                        color: Colors.white10,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text('soon',
                          style: TextStyle(color: Colors.white30, fontSize: 9)),
                    ),
                  if (isReadOnly)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                      decoration: BoxDecoration(
                        color: Colors.white10,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text('view',
                          style: TextStyle(color: Colors.white30, fontSize: 9)),
                    ),
                  if (blocked)
                    const Icon(Icons.lock_outline, size: 12, color: Colors.white12),
                ],
              ]),
            ),
          ),
        ),
      ),
    );

    return selected
        ? Stack(children: [
            tile,
            Positioned(
              left: 0, top: 4, bottom: 4,
              child: Container(
                width: 3,
                decoration: BoxDecoration(
                  color: item.accent,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
          ])
        : tile;
  }

  // ── BUILD ──────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 700;

    if (_loadingUser) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    // ── Mobile: Scaffold with drawer only — each page toolbar handles its own
    //    header and embeds a hamburger to open this drawer.
    if (isMobile) {
      return Scaffold(
        key: menuScaffoldKey,
        drawer: Drawer(child: _buildSidebar(isDrawer: true)),
        body: SafeArea(child: _buildContent(true)),
      );
    }

    // ── Desktop: sidebar + content, no Scaffold AppBar
    return Scaffold(
      body: SafeArea(
        child: Row(children: [
          _buildSidebar(),
          Expanded(child: _buildContent(false)),
        ]),
      ),
    );
  }
}
