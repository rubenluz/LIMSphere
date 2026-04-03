// settings_page.dart - Settings UI: visible module groups and per-user
// module permission overrides.

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'app_settings.dart';
import '/theme/theme.dart';

const _roleOrder = ['viewer', 'technician', 'researcher', 'admin', 'superadmin'];

bool _hasRole(String userRole, String required) {
  final ui = _roleOrder.indexOf(userRole);
  final ri = _roleOrder.indexOf(required);
  return ui >= 0 && ri >= 0 && ui >= ri;
}

class SettingsPage extends StatefulWidget {
  final VoidCallback onSettingsChanged;

  const SettingsPage({super.key, required this.onSettingsChanged});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  static const _accent = Color(0xFF38BDF8);

  static const _allGroups = [
    _GroupDef(
      'dashboard',
      'Dashboard',
      Icons.space_dashboard_outlined,
      'Overview panels and summary widgets',
    ),
    _GroupDef(
      'labels',
      'Labels',
      Icons.label_outline_rounded,
      'Label template builder and printer',
    ),
    _GroupDef(
      'chat',
      'Chat',
      Icons.forum_outlined,
      'Lab team messaging',
    ),
    _GroupDef(
      'requests',
      'Requests',
      Icons.outbox_outlined,
      'Lab supply and strain requests',
    ),
    _GroupDef(
      'culture_collection',
      'Culture Collection',
      Icons.inventory_2_outlined,
      'Strains, samples, requests and SOPs',
    ),
    _GroupDef(
      'fish_facility',
      'Fish Facility',
      Icons.water_outlined,
      'Fish stock, tank map, lines and SOPs',
    ),
    _GroupDef(
      'resources',
      'Resources',
      Icons.category_outlined,
      'Reagents, equipment and reservations',
    ),
    _GroupDef(
      'reservations',
      'Reservations',
      Icons.event_outlined,
      'Equipment reservation calendar',
    ),
  ];

  Set<String> _enabled = {};
  String _userRole = '';
  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final email = Supabase.instance.client.auth.currentSession?.user.email ?? '';
    final results = await Future.wait([
      AppSettings.load(),
      Supabase.instance.client
          .from('users')
          .select('user_role')
          .eq('user_email', email)
          .limit(1),
    ]);
    if (mounted) {
      final rows = results[1] as List<dynamic>;
      setState(() {
        _enabled = AppSettings.visibleGroups;
        _userRole = rows.isNotEmpty ? (rows[0]['user_role'] ?? '') : '';
        _loading = false;
      });
    }
  }

  Future<void> _toggle(String key, bool value) async {
    final updated = Set<String>.from(_enabled);
    if (value) {
      updated.add(key);
    } else {
      updated.remove(key);
    }
    setState(() {
      _enabled = updated;
      _saving = true;
    });
    await AppSettings.setVisibleGroups(updated);
    if (mounted) {
      setState(() => _saving = false);
    }
    widget.onSettingsChanged();
  }

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: context.appBg,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: 56,
            decoration: BoxDecoration(
              color: context.appSurface2,
              border: Border(bottom: BorderSide(color: context.appBorder)),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                if (MediaQuery.of(context).size.width < 700) ...[
                  IconButton(
                    icon: const Icon(Icons.menu_rounded, size: 20),
                    color: context.appTextSecondary,
                    tooltip: 'Menu',
                    onPressed: () => Scaffold.of(context).openDrawer(),
                  ),
                ],
                const Icon(Icons.settings_outlined, color: _accent, size: 20),
                const SizedBox(width: 10),
                Text(
                  'App Settings',
                  style: TextStyle(
                    color: context.appTextPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                if (_saving)
                  const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Color(0xFF38BDF8),
                    ),
                  ),
              ],
            ),
          ),
          if (_loading)
            const Expanded(child: Center(child: CircularProgressIndicator()))
          else
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 600),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Menu Visibility',
                        style: TextStyle(
                          color: context.appTextPrimary,
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Choose which sections appear in the sidebar. Changes apply immediately for all users.',
                        style: TextStyle(
                          color: context.appTextMuted,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Builder(
                        builder: (context) {
                          final visible = _allGroups
                              .where((_) => _hasRole(_userRole, 'admin'))
                              .toList();
                          return Container(
                            decoration: BoxDecoration(
                              color: context.appSurface,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: context.appBorder),
                            ),
                            child: Column(
                              children: [
                                for (int i = 0; i < visible.length; i++) ...[
                                  if (i > 0)
                                    Divider(
                                      color: context.appBorder,
                                      height: 1,
                                    ),
                                  _GroupToggleRow(
                                    def: visible[i],
                                    enabled: _enabled.contains(visible[i].key),
                                    onChanged: (v) => _toggle(visible[i].key, v),
                                  ),
                                ],
                                Divider(color: context.appBorder, height: 1),
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 14,
                                  ),
                                  child: Row(
                                    children: [
                                      Container(
                                        width: 36,
                                        height: 36,
                                        decoration: BoxDecoration(
                                          color: const Color(0xFF6366F1)
                                              .withValues(alpha: 0.15),
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: const Icon(
                                          Icons.admin_panel_settings_outlined,
                                          color: Color(0xFF6366F1),
                                          size: 18,
                                        ),
                                      ),
                                      const SizedBox(width: 14),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              'Admin',
                                              style: TextStyle(
                                                color: context.appTextPrimary,
                                                fontSize: 14,
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                            Text(
                                              'Users, audit log and settings are always visible to admins.',
                                              style: TextStyle(
                                                color: context.appTextMuted,
                                                fontSize: 12,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 3,
                                        ),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFF6366F1)
                                              .withValues(alpha: 0.15),
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: const Text(
                                          'Always on',
                                          style: TextStyle(
                                            color: Color(0xFF6366F1),
                                            fontSize: 11,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              Divider(color: context.appBorder, height: 1),
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 14),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 36,
                                      height: 36,
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF10B981)
                                            .withValues(alpha: 0.15),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: const Icon(
                                        Icons.backup_outlined,
                                        color: Color(0xFF10B981),
                                        size: 18,
                                      ),
                                    ),
                                    const SizedBox(width: 14),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'Backups',
                                            style: TextStyle(
                                              color: context.appTextPrimary,
                                              fontSize: 14,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                          Text(
                                            'Visible to admins always. Grant per-user in Users page (None / See).',
                                            style: TextStyle(
                                              color: context.appTextMuted,
                                              fontSize: 12,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 8, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF10B981)
                                            .withValues(alpha: 0.15),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: const Text(
                                        'Per-user',
                                        style: TextStyle(
                                          color: Color(0xFF10B981),
                                          fontSize: 11,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              ],
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Icon(
                            Icons.cloud_done_outlined,
                            color: context.appTextMuted,
                            size: 14,
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              'Settings are stored in the database and apply to all users immediately.',
                              style: TextStyle(
                                color: context.appTextMuted,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _GroupDef {
  final String key;
  final String label;
  final IconData icon;
  final String description;

  const _GroupDef(this.key, this.label, this.icon, this.description);
}

class _GroupToggleRow extends StatelessWidget {
  final _GroupDef def;
  final bool enabled;
  final ValueChanged<bool> onChanged;

  const _GroupToggleRow({
    required this.def,
    required this.enabled,
    required this.onChanged,
  });

  static Color _accentFor(String key) => switch (key) {
        'dashboard' => const Color(0xFF6366F1),
        'labels' => const Color(0xFFF97316),
        'chat' => const Color(0xFF22D3EE),
        'culture_collection' => const Color(0xFF10B981),
        'fish_facility' => const Color(0xFF0EA5E9),
        'resources' => const Color(0xFFF59E0B),
        _ => const Color(0xFF38BDF8),
      };

  @override
  Widget build(BuildContext context) {
    final accent = _accentFor(def.key);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: (enabled ? accent : const Color(0xFF334155))
                  .withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              def.icon,
              color: enabled ? accent : context.appTextMuted,
              size: 18,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  def.label,
                  style: TextStyle(
                    color: enabled
                        ? context.appTextPrimary
                        : context.appTextMuted,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  def.description,
                  style: TextStyle(
                    color: context.appTextMuted,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Switch(
            value: enabled,
            onChanged: onChanged,
            activeTrackColor: accent,
            activeThumbColor: Colors.white,
          ),
        ],
      ),
    );
  }
}
