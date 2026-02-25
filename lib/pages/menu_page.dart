import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'samples/samples_page.dart';
import 'strains/strains_page.dart';
import 'dashboard_page.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Permission model
// Each module id maps to a required role level.
// Roles in ascending order: viewer < technician < researcher < admin < superadmin
// ─────────────────────────────────────────────────────────────────────────────
const _roleOrder = ['viewer', 'technician', 'researcher', 'admin', 'superadmin'];

bool _hasRole(String userRole, String required) {
  final ui = _roleOrder.indexOf(userRole);
  final ri = _roleOrder.indexOf(required);
  if (ui == -1 || ri == -1) return false;
  return ui >= ri;
}

// Required minimum role per module id (null = everyone)
const Map<String, String?> _moduleRequiredRole = {
  'dashboard':        'technician',
  'chat':             'technician',
  // Inventory
  'strains':          null,
  'samples':          null,
  'requests':         'technician',
  'sops_inventory':   'technician',
  // Fish Facility
  'fish_stock':       null,
  'fish_tankmap':     'technician',
  'fish_lines':       'technician',
  'sops_fish':        'technician',
  // Resources
  'reagents':         'technician',
  'equipment':        'technician',
  'reservations':     'technician',
  // Admin
  'audit':            'admin',
  'users':            'admin',
};

// ─────────────────────────────────────────────────────────────────────────────
// Data model
// ─────────────────────────────────────────────────────────────────────────────
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
  final String label;
  final IconData icon;
  final List<_NavItem> children;
  const _NavGroup({required this.label, required this.icon, required this.children});
}

// ─────────────────────────────────────────────────────────────────────────────
// Page
// ─────────────────────────────────────────────────────────────────────────────
class MenuPage extends StatefulWidget {
  const MenuPage({super.key});

  @override
  State<MenuPage> createState() => _MenuPageState();
}

class _MenuPageState extends State<MenuPage> {
  String _selectedId  = 'dashboard';
  Map<String, dynamic> _userInfo    = {};
  List<Map<String, dynamic>> _pendingUsers = [];
  bool _loadingUser   = true;
  bool _collapsed     = false;

  // Which groups are expanded (by label)
  final Set<String> _expandedGroups = {'Inventory', 'Fish Facility', 'Resources', 'Admin'};

  // ── Top-level solo items ────────────────────────────────────────────────────
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
      comingSoon: true,
    ),
  ];

  // ── Grouped items ───────────────────────────────────────────────────────────
  late final List<_NavGroup> _groups = [
    _NavGroup(
      label: 'Inventory',
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
        _NavItem(id: 'requests',      label: 'Requests',       icon: Icons.outbox_outlined,    accent: const Color(0xFF8B5CF6), comingSoon: true),
        _NavItem(id: 'sops_inventory',label: 'SOPs / Protocols',icon: Icons.menu_book_outlined, accent: const Color(0xFF06B6D4), comingSoon: true),
      ],
    ),
    _NavGroup(
      label: 'Fish Facility',
      icon: Icons.water_outlined,
      children: [
        _NavItem(id: 'fish_stock',  label: 'Stock',           icon: Icons.set_meal_outlined,           accent: const Color(0xFF0EA5E9), comingSoon: true),
        _NavItem(id: 'fish_tankmap',label: 'Tank Map',        icon: Icons.grid_view_outlined,          accent: const Color(0xFF38BDF8), comingSoon: true),
        _NavItem(id: 'fish_lines',  label: 'Fish Lines',      icon: Icons.science_outlined,            accent: const Color(0xFF7DD3FC), comingSoon: true),
        _NavItem(id: 'sops_fish',   label: 'SOPs / Protocols',icon: Icons.menu_book_outlined,          accent: const Color(0xFF06B6D4), comingSoon: true),
      ],
    ),
    _NavGroup(
      label: 'Resources',
      icon: Icons.category_outlined,
      children: [
        _NavItem(id: 'reagents',    label: 'Reagents',    icon: Icons.water_drop_outlined,              accent: const Color(0xFFF59E0B), comingSoon: true),
        _NavItem(id: 'equipment',   label: 'Equipment',   icon: Icons.precision_manufacturing_outlined, accent: const Color(0xFF14B8A6), comingSoon: true),
        _NavItem(id: 'reservations',label: 'Reservations',icon: Icons.event_outlined,                   accent: const Color(0xFFEC4899), comingSoon: true),
      ],
    ),
    _NavGroup(
      label: 'Admin',
      icon: Icons.admin_panel_settings_outlined,
      children: [
        _NavItem(id: 'audit', label: 'Audit Log', icon: Icons.manage_search_outlined, accent: const Color(0xFF6B7280), comingSoon: true),
        _NavItem(id: 'users', label: 'Users',     icon: Icons.people_outlined,         accent: const Color(0xFF6366F1), comingSoon: true),
      ],
    ),
  ];

  // ─────────────────────────────────────────────────────────────────────────
  @override
  void initState() {
    super.initState();
    _loadUserInfo();
  }

  Future<void> _loadUserInfo() async {
    try {
      final email = Supabase.instance.client.auth.currentSession?.user.email ?? '';
      final rows = await Supabase.instance.client
          .from('users').select().eq('user_username', email).limit(1);
      if (rows.isNotEmpty) {
        setState(() {
          _userInfo    = Map<String, dynamic>.from(rows[0]);
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
    final userRole   = _userInfo['user_role']?.toString() ?? '';
    final required   = _moduleRequiredRole[id];

    if (required != null && !_hasRole(userRole, required)) {
      // Find admin info for snackbar
      _showAccessDenied(id);
      nav?.pop();
      return;
    }
    setState(() => _selectedId = id);
    nav?.pop();
  }

  void _showAccessDenied(String moduleId) async {
    String adminName  = 'the administrator';
    String adminEmail = '';

    try {
      final admins = await Supabase.instance.client
          .from('users')
          .select('user_full_name, user_email')
          .inFilter('user_role', ['admin', 'superadmin'])
          .eq('user_status', 'active')
          .limit(1);
      if (admins.isNotEmpty) {
        adminName  = admins[0]['user_full_name']?.toString() ?? adminName;
        adminEmail = admins[0]['user_email']?.toString()     ?? '';
      }
    } catch (_) {}

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: const Color(0xFF1E293B),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        duration: const Duration(seconds: 6),
        content: Row(children: [
          const Icon(Icons.lock_outline, color: Color(0xFFEF4444), size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: RichText(
              text: TextSpan(
                style: const TextStyle(color: Colors.white70, fontSize: 13),
                children: [
                  const TextSpan(text: 'Access restricted. If you think you should have access, please contact '),
                  TextSpan(text: adminName, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  if (adminEmail.isNotEmpty) ...[
                    const TextSpan(text: ' · '),
                    TextSpan(text: adminEmail, style: const TextStyle(color: Color(0xFF93C5FD))),
                  ],
                ],
              ),
            ),
          ),
        ]),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Content area
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildContent() {
    // Find in top items
    for (final item in _topItems) {
      if (item.id == _selectedId && item.builder != null) return item.builder!(this);
    }
    // Find in groups
    for (final g in _groups) {
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
          size: 56, color: item?.accent.withOpacity(0.5) ?? Colors.grey.shade400),
      const SizedBox(height: 16),
      Text(item?.label ?? 'Coming soon',
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600)),
      const SizedBox(height: 8),
      Text('This module is under development.',
          style: TextStyle(color: Colors.grey.shade500)),
    ]),
  );

  // ─────────────────────────────────────────────────────────────────────────
  // Sidebar
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildSidebar({bool isDrawer = false}) {
    final bool collapsed = !isDrawer && _collapsed;
    final double w       = collapsed ? 64.0 : 240.0;
    final userRole       = _userInfo['user_role']?.toString() ?? '';
    final userName       = _userInfo['user_full_name']?.toString()
                        ?? _userInfo['user_username']?.toString()
                        ?? '';
    final pendingCount   = _pendingUsers.length;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeInOut,
      width: w,
      child: Material(
        color: const Color(0xFF0F172A),
        child: Column(children: [
          // ── Logo ──────────────────────────────────────────────────────────
          SizedBox(
            height: 60,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(children: [
                Container(
                  width: 32, height: 32,
                  decoration: BoxDecoration(
                    color: const Color(0xFF6366F1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.biotech, color: Colors.white, size: 18),
                ),
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

          // ── Nav ───────────────────────────────────────────────────────────
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
              children: [
                // Top-level solo items
                ..._topItems.map((item) => _buildLeafTile(
                  item: item,
                  collapsed: collapsed,
                  isDrawer: isDrawer,
                  userRole: userRole,
                  indented: false,
                )),

                const SizedBox(height: 4),

                // Groups
                ..._groups.map((group) {
                  final isExpanded = _expandedGroups.contains(group.label);
                  // Check if any child is accessible
                  final anyAccessible = group.children.any((c) {
                    final req = _moduleRequiredRole[c.id];
                    return req == null || _hasRole(userRole, req);
                  });

                  if (collapsed) {
                    // In collapsed mode just show child icons with a subtle separator
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
                      // Group header
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
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 1.1,
                                  color: anyAccessible ? Colors.white38 : Colors.white24,
                                ),
                              ),
                            ),
                            Icon(
                              isExpanded ? Icons.expand_less : Icons.expand_more,
                              size: 14, color: Colors.white24,
                            ),
                          ]),
                        ),
                      ),

                      // Children (animated)
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

          // ── User strip ────────────────────────────────────────────────────
          if (!collapsed)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
              child: Row(children: [
                CircleAvatar(
                  radius: 14,
                  backgroundColor: const Color(0xFF6366F1).withOpacity(0.3),
                  child: Text(
                    userName.isNotEmpty ? userName[0].toUpperCase() : '?',
                    style: const TextStyle(color: Colors.white, fontSize: 12),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(userName, style: const TextStyle(color: Colors.white,
                        fontSize: 12, fontWeight: FontWeight.w600),
                        overflow: TextOverflow.ellipsis),
                    Text(userRole, style: TextStyle(color: Colors.white38, fontSize: 10),
                        overflow: TextOverflow.ellipsis),
                  ],
                )),
                // Pending badge (admin only)
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
            ),

          // ── Collapse + Logout row ─────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(6, 4, 6, 8),
            child: Row(children: [
              if (!isDrawer)
                Tooltip(
                  message: collapsed ? 'Expand sidebar' : 'Collapse sidebar',
                  child: IconButton(
                    icon: Icon(collapsed ? Icons.chevron_right : Icons.chevron_left,
                        color: Colors.white38, size: 18),
                    onPressed: () => setState(() => _collapsed = !_collapsed),
                  ),
                ),
              if (!collapsed || isDrawer) ...[
                const Spacer(),
                TextButton.icon(
                  onPressed: _logout,
                  icon: const Icon(Icons.logout, size: 15, color: Colors.white38),
                  label: const Text('Logout',
                      style: TextStyle(color: Colors.white38, fontSize: 12)),
                ),
              ] else ...[
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.logout, size: 16, color: Colors.white38),
                  tooltip: 'Logout',
                  onPressed: _logout,
                ),
              ],
            ]),
          ),
        ]),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Leaf tile (individual nav item)
  // ─────────────────────────────────────────────────────────────────────────
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
    if (selected)      { iconColor = item.accent;          textColor = Colors.white; }
    else if (blocked)  { iconColor = Colors.white15;       textColor = Colors.white24; }
    else if (item.comingSoon) { iconColor = Colors.white24; textColor = Colors.white38; }
    else               { iconColor = Colors.white54;       textColor = Colors.white70; }

    final tile = Padding(
      padding: EdgeInsets.only(left: indented && !collapsed ? 8.0 : 0, bottom: 1),
      child: Tooltip(
        message: collapsed ? (blocked ? '${item.label} (No access)' : item.label) : '',
        child: Material(
          color: selected
              ? item.accent.withOpacity(0.18)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(7),
          child: InkWell(
            borderRadius: BorderRadius.circular(7),
            onTap: blocked
                ? () => _showAccessDenied(item.id)
                : item.comingSoon
                    ? null
                    : () => _select(item.id, isDrawer ? Navigator.of(context) : null),
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: collapsed ? 0 : 8,
                vertical: 7,
              ),
              child: Row(children: [
                // Indentation dot + icon
                if (!collapsed && indented)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: Container(
                      width: 4, height: 4,
                      decoration: BoxDecoration(
                        color: selected ? item.accent : Colors.white15,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),

                // Icon
                SizedBox(
                  width: collapsed ? double.infinity : 24,
                  child: Center(
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Icon(
                          blocked ? Icons.lock_outline : item.icon,
                          size: 17,
                          color: iconColor,
                        ),
                      ],
                    ),
                  ),
                ),

                // Label + badges
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
                    const Icon(Icons.lock_outline, size: 12, color: Colors.white15),
                ],
              ]),
            ),
          ),
        ),
      ),
    );

    // Active left bar indicator
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

  // ─────────────────────────────────────────────────────────────────────────
  // BUILD
  // ─────────────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 700;

    return Scaffold(
      drawer: isMobile ? Drawer(child: _buildSidebar(isDrawer: true)) : null,
      body: _loadingUser
          ? const Center(child: CircularProgressIndicator())
          : SafeArea(
              child: Row(children: [
                if (!isMobile) _buildSidebar(),
                Expanded(
                  child: Stack(children: [
                    _buildContent(),
                    if (isMobile)
                      Positioned(
                        top: 8, left: 8,
                        child: Builder(builder: (ctx) => IconButton(
                          icon: const Icon(Icons.menu),
                          onPressed: () => Scaffold.of(ctx).openDrawer(),
                        )),
                      ),
                  ]),
                ),
              ]),
            ),
    );
  }
}