import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'samples/samples_page.dart';
import 'strains/strains_page.dart';
import 'dashboard_page.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Module registry — add / remove pages here; no other file needs touching.
// Set [enabled] to false to hide a module without deleting it.
// Set [comingSoon] to true to show it greyed-out in the sidebar.
// ─────────────────────────────────────────────────────────────────────────────
class _Module {
  final String id;
  final String label;
  final IconData icon;
  final Color accent;
  final bool comingSoon;
  final bool enabled;

  const _Module({
    required this.id,
    required this.label,
    required this.icon,
    required this.accent,
    this.comingSoon = false,
    this.enabled = true,
  });
}

const List<_Module> _modules = [
  _Module(id: 'dashboard',  label: 'Dashboard',          icon: Icons.space_dashboard_outlined,  accent: Color(0xFF6366F1)),
  _Module(id: 'strains',    label: 'Strains',             icon: Icons.biotech_outlined,           accent: Color(0xFF10B981)),
  _Module(id: 'samples',    label: 'Samples',             icon: Icons.colorize_outlined,          accent: Color(0xFF3B82F6)),
  _Module(id: 'reagents',   label: 'Reagents',            icon: Icons.water_drop_outlined,        accent: Color(0xFFF59E0B), comingSoon: true),
  _Module(id: 'zebrafish',  label: 'Zebrafish Facility',  icon: Icons.set_meal_outlined,          accent: Color(0xFF8B5CF6), comingSoon: true),
  _Module(id: 'reservations',label: 'Reservations',       icon: Icons.event_outlined,             accent: Color(0xFFEC4899), comingSoon: true),
  _Module(id: 'equipment',  label: 'Equipment',           icon: Icons.precision_manufacturing_outlined, accent: Color(0xFF14B8A6), comingSoon: true),
  _Module(id: 'orders',     label: 'Orders',              icon: Icons.shopping_bag_outlined,      accent: Color(0xFFF97316), comingSoon: true),
  _Module(id: 'protocols',  label: 'Protocols',           icon: Icons.menu_book_outlined,         accent: Color(0xFF06B6D4), comingSoon: true),
  _Module(id: 'audit',      label: 'Audit Log',           icon: Icons.manage_search_outlined,     accent: Color(0xFF6B7280), comingSoon: true),
];

// ─────────────────────────────────────────────────────────────────────────────
// MenuPage
// ─────────────────────────────────────────────────────────────────────────────
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
  bool _sidebarCollapsed = false;

  // ── Data ──────────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _loadUserInfo();
  }

  Future<void> _loadUserInfo() async {
    try {
      final session = Supabase.instance.client.auth.currentSession;
      final email   = session?.user.email ?? '';
      final rows    = await Supabase.instance.client
          .from('users').select().eq('username', email).limit(1);
      if (rows.isNotEmpty) {
        setState(() {
          _userInfo    = Map<String, dynamic>.from(rows[0]);
          _loadingUser = false;
        });
        if (_userInfo['role'] == 'superadmin') _loadPendingUsers();
      }
    } catch (_) {
      setState(() => _loadingUser = false);
    }
  }

  Future<void> _loadPendingUsers() async {
    try {
      final res = await Supabase.instance.client
          .from('users').select().eq('status', 'pending');
      setState(() => _pendingUsers = List<Map<String, dynamic>>.from(res));
    } catch (_) {}
  }

  Future<void> _approveUser(dynamic userId) async {
    await Supabase.instance.client
        .from('users').update({'status': 'active'}).eq('id', userId);
    _loadPendingUsers();
  }

  Future<void> _logout() async {
    await Supabase.instance.client.auth.signOut();
    if (!mounted) return;
    Navigator.pushReplacementNamed(context, '/connections');
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  _Module? get _currentModule =>
      _modules.where((m) => m.id == _selectedId).firstOrNull;

  void _select(String id, [NavigatorState? nav]) {
    setState(() => _selectedId = id);
    nav?.pop();
  }

  // ── Page routing ──────────────────────────────────────────────────────────

  Widget _buildPageContent() {
    switch (_selectedId) {
      case 'dashboard':
        return DashboardPage(
          userInfo: _userInfo,
          pendingUsers: _pendingUsers,
          onGoToPendingUsers: () => setState(() => _selectedId = 'pending'),
        );
      case 'strains':  return const StrainsPage();
      case 'samples':  return const SamplesPage();
      case 'pending':  return _buildPendingUsers();
      default:
        final m = _currentModule;
        return m != null ? _buildComingSoon(m) : _buildComingSoon(null);
    }
  }

  Widget _buildPendingUsers() {
    if (_pendingUsers.isEmpty) {
      return Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.check_circle_outline, size: 56, color: Colors.green.shade300),
          const SizedBox(height: 12),
          const Text('No pending approvals', style: TextStyle(fontSize: 16)),
        ]),
      );
    }
    return ListView.builder(
      itemCount: _pendingUsers.length,
      padding: const EdgeInsets.all(24),
      itemBuilder: (context, i) {
        final user = _pendingUsers[i];
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: const Color(0xFF6366F1).withOpacity(0.1),
              child: const Icon(Icons.person, color: Color(0xFF6366F1)),
            ),
            title: Text(user['username'] ?? '',
                style: const TextStyle(fontWeight: FontWeight.w600)),
            subtitle: Text('Role: ${user['role']}',
                style: TextStyle(color: Colors.grey.shade600)),
            trailing: FilledButton(
              onPressed: () => _approveUser(user['id']),
              child: const Text('Approve'),
            ),
          ),
        );
      },
    );
  }

  Widget _buildComingSoon(_Module? m) {
    return Center(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(
          width: 80, height: 80,
          decoration: BoxDecoration(
            color: (m?.accent ?? Colors.grey).withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(m?.icon ?? Icons.construction_outlined,
              size: 36, color: m?.accent ?? Colors.grey),
        ),
        const SizedBox(height: 20),
        Text(m?.label ?? 'Unknown',
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Text('This module is coming soon.',
            style: TextStyle(color: Colors.grey.shade500, fontSize: 15)),
      ]),
    );
  }

  // ── Sidebar ───────────────────────────────────────────────────────────────

  Widget _buildSidebar({bool isDrawer = false}) {
    final isSuperAdmin = _userInfo['role'] == 'superadmin';
    final collapsed    = !isDrawer && _sidebarCollapsed;
    final sidebarW     = collapsed ? 68.0 : 240.0;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeInOut,
      width: sidebarW,
      child: Material(
        color: const Color(0xFF0F172A), // deep navy
        child: Column(children: [
          // ── Logo / header ───────────────────────────────────────────────
          Container(
            height: 64,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(color: Colors.white.withOpacity(0.07)),
              ),
            ),
            child: Row(children: [
              Container(
                width: 34, height: 34,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF6366F1), Color(0xFF10B981)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.biotech, color: Colors.white, size: 18),
              ),
              if (!collapsed) ...[
                const SizedBox(width: 12),
                const Expanded(
                  child: Text('BioLab',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 17,
                      letterSpacing: 0.3,
                    ),
                  ),
                ),
              ],
              if (!isDrawer)
                IconButton(
                  icon: Icon(
                    collapsed ? Icons.chevron_right : Icons.chevron_left,
                    color: Colors.white38, size: 18,
                  ),
                  onPressed: () => setState(() => _sidebarCollapsed = !_sidebarCollapsed),
                  tooltip: collapsed ? 'Expand' : 'Collapse',
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                ),
            ]),
          ),

          // ── User pill ───────────────────────────────────────────────────
          if (!collapsed)
            Container(
              margin: const EdgeInsets.fromLTRB(12, 12, 12, 4),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.05),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(children: [
                CircleAvatar(
                  radius: 16,
                  backgroundColor: const Color(0xFF6366F1).withOpacity(0.3),
                  child: Text(
                    (_userInfo['username'] ?? 'U').substring(0, 1).toUpperCase(),
                    style: const TextStyle(
                        color: Color(0xFF6366F1), fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        (_userInfo['username'] ?? 'Loading...').split('@').first,
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w600),
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        _userInfo['role'] ?? '',
                        style: TextStyle(
                            color: Colors.white.withOpacity(0.45), fontSize: 10),
                      ),
                    ],
                  ),
                ),
              ]),
            )
          else
            Padding(
              padding: const EdgeInsets.fromLTRB(0, 12, 0, 4),
              child: Center(
                child: CircleAvatar(
                  radius: 16,
                  backgroundColor: const Color(0xFF6366F1).withOpacity(0.3),
                  child: Text(
                    (_userInfo['username'] ?? 'U').substring(0, 1).toUpperCase(),
                    style: const TextStyle(
                        color: Color(0xFF6366F1), fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ),

          const SizedBox(height: 8),

          // ── Nav items ───────────────────────────────────────────────────
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              children: [
                ..._modules.where((m) => m.enabled).map((m) =>
                    _buildNavItem(m, collapsed, isDrawer)),

                // ── Superadmin: Pending ─────────────────────────────────
                if (isSuperAdmin) ...[
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
                    child: Divider(color: Colors.white.withOpacity(0.08), height: 1),
                  ),
                  _buildNavItemRaw(
                    id: 'pending',
                    icon: Icons.how_to_reg_outlined,
                    label: 'Pending',
                    accent: const Color(0xFFEF4444),
                    collapsed: collapsed,
                    isDrawer: isDrawer,
                    badge: _pendingUsers.isNotEmpty ? '${_pendingUsers.length}' : null,
                  ),
                ],
              ],
            ),
          ),

          // ── Logout ──────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.all(8),
            child: collapsed
                ? IconButton(
                    icon: const Icon(Icons.logout, color: Colors.white38, size: 18),
                    onPressed: _logout,
                    tooltip: 'Logout',
                  )
                : ListTile(
                    dense: true,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                    leading: const Icon(Icons.logout, color: Colors.white38, size: 18),
                    title: Text('Logout',
                        style: TextStyle(
                            color: Colors.white.withOpacity(0.45), fontSize: 13)),
                    onTap: _logout,
                  ),
          ),
        ]),
      ),
    );
  }

  Widget _buildNavItem(_Module m, bool collapsed, bool isDrawer) {
    return _buildNavItemRaw(
      id: m.id,
      icon: m.icon,
      label: m.label,
      accent: m.accent,
      collapsed: collapsed,
      isDrawer: isDrawer,
      comingSoon: m.comingSoon,
    );
  }

  Widget _buildNavItemRaw({
    required String id,
    required IconData icon,
    required String label,
    required Color accent,
    required bool collapsed,
    required bool isDrawer,
    bool comingSoon = false,
    String? badge,
  }) {
    final selected = _selectedId == id;

    final tile = AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      margin: const EdgeInsets.only(bottom: 2),
      decoration: BoxDecoration(
        color: selected
            ? accent.withOpacity(0.18)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: comingSoon
              ? null
              : () => _select(id, isDrawer ? Navigator.of(context) : null),
          child: Padding(
            padding: collapsed
                ? const EdgeInsets.symmetric(vertical: 10)
                : const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
            child: Row(
              mainAxisAlignment: collapsed
                  ? MainAxisAlignment.center
                  : MainAxisAlignment.start,
              children: [
                Icon(icon,
                  size: 18,
                  color: selected
                      ? accent
                      : comingSoon
                          ? Colors.white.withOpacity(0.2)
                          : Colors.white.withOpacity(0.55),
                ),
                if (!collapsed) ...[
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(label,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: selected
                            ? FontWeight.w600 : FontWeight.w400,
                        color: selected
                            ? Colors.white
                            : comingSoon
                                ? Colors.white.withOpacity(0.25)
                                : Colors.white.withOpacity(0.7),
                      ),
                    ),
                  ),
                  if (badge != null)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: accent,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(badge,
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold)),
                    )
                  else if (comingSoon)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.06),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text('soon',
                          style: TextStyle(
                              color: Colors.white.withOpacity(0.25),
                              fontSize: 9)),
                    )
                  else if (selected)
                    Container(
                      width: 5, height: 5,
                      decoration: BoxDecoration(
                          color: accent, shape: BoxShape.circle),
                    ),
                ],
              ],
            ),
          ),
        ),
      ),
    );

    if (collapsed && !comingSoon) {
      return Tooltip(
        message: label,
        preferBelow: false,
        child: tile,
      );
    }
    return tile;
  }

  // ── AppBar ─────────────────────────────────────────────────────────────────

  PreferredSizeWidget _buildAppBar(bool isMobile) {
    final m = _currentModule;
    return AppBar(
      backgroundColor: Theme.of(context).colorScheme.surface,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 1,
      leading: isMobile
          ? Builder(builder: (ctx) => IconButton(
              icon: const Icon(Icons.menu),
              onPressed: () => Scaffold.of(ctx).openDrawer(),
            ))
          : null,
      title: Row(children: [
        if (m != null) ...[
          Container(
            width: 28, height: 28,
            decoration: BoxDecoration(
              color: m.accent.withOpacity(0.12),
              borderRadius: BorderRadius.circular(7),
            ),
            child: Icon(m.icon, size: 15, color: m.accent),
          ),
          const SizedBox(width: 10),
        ],
        Text(
          _selectedId == 'pending'
              ? 'Pending Approvals'
              : m?.label ?? _selectedId,
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 17),
        ),
      ]),
      actions: [
        // Pending badge shortcut (superadmin only)
        if (_userInfo['role'] == 'superadmin' && _pendingUsers.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(right: 4),
            child: Badge(
              label: Text('${_pendingUsers.length}'),
              child: IconButton(
                icon: const Icon(Icons.how_to_reg_outlined),
                tooltip: 'Pending approvals',
                onPressed: () => _select('pending'),
              ),
            ),
          ),
        PopupMenuButton<String>(
          tooltip: 'Account',
          icon: CircleAvatar(
            radius: 16,
            backgroundColor: const Color(0xFF6366F1).withOpacity(0.12),
            child: Text(
              (_userInfo['username'] ?? 'U').substring(0, 1).toUpperCase(),
              style: const TextStyle(
                  color: Color(0xFF6366F1),
                  fontWeight: FontWeight.bold,
                  fontSize: 13),
            ),
          ),
          itemBuilder: (_) => [
            PopupMenuItem(
              enabled: false,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(_userInfo['username'] ?? '',
                      style: const TextStyle(fontWeight: FontWeight.w600)),
                  Text(_userInfo['role'] ?? '',
                      style: TextStyle(
                          color: Colors.grey.shade500, fontSize: 12)),
                ],
              ),
            ),
            const PopupMenuDivider(),
            const PopupMenuItem(
              value: 'logout',
              child: ListTile(
                leading: Icon(Icons.logout),
                title: Text('Logout'),
                contentPadding: EdgeInsets.zero,
                dense: true,
              ),
            ),
          ],
          onSelected: (v) { if (v == 'logout') _logout(); },
        ),
        const SizedBox(width: 8),
      ],
    );
  }

  // ── BUILD ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 700;

    return Scaffold(
      resizeToAvoidBottomInset: false,
      appBar: _buildAppBar(isMobile),
      drawer: isMobile
          ? Drawer(
              backgroundColor: const Color(0xFF0F172A),
              child: _buildSidebar(isDrawer: true),
            )
          : null,
      body: _loadingUser
          ? const Center(child: CircularProgressIndicator())
          : Row(children: [
              if (!isMobile) _buildSidebar(),
              Expanded(child: _buildPageContent()),
            ]),
    );
  }
}