import 'package:blue_open_lims/pages/lab_chat/lab_chat_page.dart';
import '../resources/locations/locations_page.dart';
import '../resources/reagents/reagents_page.dart';
import '../resources/machines/machines_page.dart';
import '../resources/reservations/reservations_page.dart';
import '/theme/theme.dart';
import '../admin/settings_page.dart';
import 'package:blue_open_lims/pages/fish_facility/lines/fish_lines_page.dart';
import 'package:blue_open_lims/pages/sops/sops_page.dart';
import 'package:blue_open_lims/pages/fish_facility/stocks/stocks_page.dart';
import 'package:blue_open_lims/pages/fish_facility/tanks/tanks_page.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide LocalStorage;
import '../culture_collection/samples/samples_page.dart';
import '../culture_collection/strains/strains_page.dart';
import 'user_settings_dialog.dart';
import '../dashboard/dashboard_page.dart';
import '../users/users_page.dart';
import '../../core/app_settings.dart';
import '../qr_scanner/qr_scanner_page.dart';

const _roleOrder = ['viewer', 'technician', 'researcher', 'admin', 'superadmin'];

bool _hasRole(String userRole, String required) {
  final ui = _roleOrder.indexOf(userRole);
  final ri = _roleOrder.indexOf(required);
  if (ui == -1 || ri == -1) return false;
  return ui >= ri;
}

const Map<String, String?> _moduleRequiredRole = {
  'dashboard':        'technician',
  'chat':             'technician',
  'strains':          null,
  'samples':          'technician',
  'requests':         'technician',
  'sops_inventory':   'technician',
  'fish_stock':       null,
  'fish_tankmap':     'technician',
  'fish_lines':       'technician',
  'sops_fish':        'technician',
  'locations':        'technician',
  'reagents':         'technician',
  'equipment':        'technician',
  'reservations':     'technician',
  'audit':            'admin',
  'users':            'admin',
  'settings':         'admin',
};

class _NavItem {
  final String id;
  final String label;
  final IconData icon;
  final Color accent;
  final bool comingSoon;
  final Widget Function(_MenuPageState state)? builder;

  const _NavItem({
    required this.id,
    required this.label,
    required this.icon,
    required this.accent,
    this.comingSoon = false,
    this.builder,
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
  Set<String> _visibleGroups = {'dashboard', 'chat', 'culture_collection', 'fish_facility', 'resources'};

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
      id: 'chat',
      label: 'Chat',
      icon: Icons.forum_outlined,
      accent: const Color(0xFF22D3EE),
      builder: (_) => const LabChatPage(),
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
        _NavItem(id: 'requests',       label: 'Requests',        icon: Icons.outbox_outlined,    accent: const Color(0xFF8B5CF6), comingSoon: true),
        _NavItem(id: 'sops_inventory', label: 'SOPs / Protocols', icon: Icons.menu_book_outlined, accent: const Color(0xFF06B6D4), builder: (_) => const SopPage(sopContext: 'culture_collection')),
      ],
    ),
    _NavGroup(
      key: 'fish_facility',
      label: 'Fish Facility',
      icon: Icons.water_outlined,
      children: [
        _NavItem(id: 'fish_stock',   label: 'Stock',            icon: Icons.set_meal_outlined,           accent: const Color(0xFF0EA5E9), builder: (_) => const FishStocksPage()),
        _NavItem(id: 'fish_tankmap', label: 'Tank Map',         icon: Icons.grid_view_outlined,          accent: const Color(0xFF38BDF8), builder: (_) => const FishTanksPage()),
        _NavItem(id: 'fish_lines',   label: 'Fish Lines',       icon: Icons.science_outlined,            accent: const Color(0xFF7DD3FC), builder: (_) => const FishLinesPage()),
        _NavItem(id: 'sops_fish',    label: 'SOPs / Protocols', icon: Icons.menu_book_outlined,          accent: const Color(0xFF06B6D4), builder: (_) => const SopPage(sopContext: 'fish_facility')),
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
        _NavItem(id: 'audit',    label: 'Audit Log', icon: Icons.manage_search_outlined, accent: const Color(0xFF6B7280), comingSoon: true),
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
    // Current selection still visible?
    if (_topItems.any((i) => i.id == _selectedId && _visibleGroups.contains(i.id))) return;
    if (_groups.any((g) =>
        (g.key == 'admin' || _visibleGroups.contains(g.key)) &&
        g.children.any((i) => i.id == _selectedId))) return;

    // Pick first visible item
    for (final item in _topItems) {
      if (_visibleGroups.contains(item.id)) {
        _selectedId = item.id;
        return;
      }
    }
    for (final g in _groups) {
      if (g.key == 'admin' || _visibleGroups.contains(g.key)) {
        if (g.children.isNotEmpty) {
          _selectedId = g.children.first.id;
          return;
        }
      }
    }
    _selectedId = 'settings';
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
        backgroundColor: AppDS.surface,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        duration: const Duration(seconds: 6),
        content: Row(children: [
          const Icon(Icons.lock_outline, color: AppDS.red, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: RichText(
              text: TextSpan(
                style: const TextStyle(color: Colors.white70, fontSize: 13),
                children: [
                  const TextSpan(text: 'Access restricted. Contact '),
                  TextSpan(text: adminName,
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  if (adminEmail.isNotEmpty) ...[
                    const TextSpan(text: ' · '),
                    TextSpan(text: adminEmail,
                        style: const TextStyle(color: Color(0xFF93C5FD))),
                  ],
                ],
              ),
            ),
          ),
        ]),
      ),
    );
  }

  Future<void> _showEditUserDialog() async {
    final result = await showDialog<Map<String, dynamic>?>(
      context: context,
      builder: (ctx) => UserSettingsDialog(userInfo: _userInfo),
    );

    if (result == null) return; // cancelled

    // merge and persist returned updates
    final updates = Map<String, dynamic>.from(result);
    updates['user_updated_at'] = DateTime.now().toUtc().toIso8601String();

    try {
      if (_userInfo['user_id'] != null) {
        await Supabase.instance.client.from('users').update(updates).eq('user_id', _userInfo['user_id']);
      } else {
        await Supabase.instance.client.from('users').update(updates).eq('user_email', _userInfo['user_email']);
      }
      await _loadUserInfo();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Profile updated')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to update profile: $e')));
    }
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
    for (final item in _topItems) {
      if (!_visibleGroups.contains(item.id)) continue;
      if (item.id == _selectedId && item.builder != null) return item.builder!(this);
    }
    for (final g in _groups) {
      if (g.key != 'admin' && !_visibleGroups.contains(g.key)) continue;
      for (final item in g.children) {
        if (item.id == _selectedId && item.builder != null) return item.builder!(this);
        if (item.id == _selectedId && item.comingSoon)      return _buildComingSoon(item);
      }
    }
    return _buildComingSoon(null);
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
                  Container(
                    width: 32, height: 32,
                    decoration: BoxDecoration(
                      color: AppDS.indigo,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.biotech, color: Colors.white, size: 18),
                  ),
                  // Hide title when collapsed
                  if (!collapsed) ...[
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Text('BlueOpenLIMS',
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
                    .where((item) => _visibleGroups.contains(item.id))
                    .map((item) => _buildLeafTile(
                      item: item,
                      collapsed: collapsed,
                      isDrawer: isDrawer,
                      userRole: userRole,
                      indented: false,
                    )),
                  const SizedBox(height: 4),
                  ..._groups.where((g) => g.key == 'admin' || _visibleGroups.contains(g.key)).map((group) {
                    final isExpanded = _expandedGroups.contains(group.label);
                    final anyAccessible = group.children.any((c) {
                      final req = _moduleRequiredRole[c.id];
                      return req == null || _hasRole(userRole, req);
                    });

                    if (collapsed) {
                      return Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            child: Divider(color: Colors.white10, height: 1),
                          ),
                          ...group.children.map((item) => _buildLeafTile(
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
                            children: group.children.map((item) => _buildLeafTile(
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
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
                child: Row(children: [
                  InkWell(
                    borderRadius: BorderRadius.circular(20),
                    onTap: _showEditUserDialog,
                    child: CircleAvatar(
                      radius: 14,
                      backgroundColor: AppDS.indigo.withValues(alpha: 0.3),
                      child: Text(
                        userName.isNotEmpty ? userName[0].toUpperCase() : '?',
                        style: const TextStyle(color: Colors.white, fontSize: 12),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(child: InkWell(
                    onTap: _showEditUserDialog,
                    child: Column(
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
                    ),
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
                ]),
              )
            else
              // Collapsed: just the avatar icon centered
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: Tooltip(
                  message: '$userName ($userRole)',
                  child: InkWell(
                    borderRadius: BorderRadius.circular(20),
                    onTap: _showEditUserDialog,
                    child: CircleAvatar(
                      radius: 14,
                      backgroundColor: AppDS.indigo.withValues(alpha: 0.3),
                      child: Text(
                        userName.isNotEmpty ? userName[0].toUpperCase() : '?',
                        style: const TextStyle(color: Colors.white, fontSize: 12),
                      ),
                    ),
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
    final accessible = required == null || _hasRole(userRole, required);
    final selected   = _selectedId == item.id;
    final blocked    = !accessible;

    Color iconColor;
    Color textColor;
    if (selected)           { iconColor = item.accent;   textColor = Colors.white; }
    else if (blocked)       { iconColor = Colors.white12; textColor = Colors.white24; }
    else if (item.comingSoon) { iconColor = Colors.white24; textColor = Colors.white38; }
    else                    { iconColor = Colors.white54; textColor = Colors.white70; }

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
                : item.comingSoon
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
                Icon(blocked ? Icons.lock_outline : item.icon, size: 17, color: iconColor),
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
                  if (item.comingSoon && !blocked)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                      decoration: BoxDecoration(
                        color: Colors.white10,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text('soon',
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

    // ── Mobile: use a proper Scaffold with AppBar so the drawer hamburger
    //    is in the AppBar and never overlaps page content.
    if (isMobile) {
      return Scaffold(
        appBar: AppBar(
          backgroundColor: AppDS.bg,
          iconTheme: const IconThemeData(color: Colors.white),
          title: Text(
            _currentLabel(),
            style: const TextStyle(color: Colors.white, fontSize: 16,
                fontWeight: FontWeight.w600),
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.qr_code_scanner, color: Colors.white70),
              tooltip: 'Scan QR Code',
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const QrScannerPage()),
              ),
            ),
          ],
        ),
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

  /// Returns the label of the currently selected nav item for the mobile AppBar.
  String _currentLabel() {
    for (final item in _topItems) {
      if (!_visibleGroups.contains(item.id)) continue;
      if (item.id == _selectedId) return item.label;
    }
    for (final g in _groups) {
      if (g.key != 'admin' && !_visibleGroups.contains(g.key)) continue;
      for (final item in g.children) {
        if (item.id == _selectedId) return item.label;
      }
    }
    return 'Menu';
  }
}