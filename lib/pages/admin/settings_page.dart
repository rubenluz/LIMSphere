import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/app_settings.dart';

class SettingsPage extends StatefulWidget {
  final VoidCallback onSettingsChanged;
  const SettingsPage({super.key, required this.onSettingsChanged});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  static const _bg       = Color(0xFF0F172A);
  static const _surface  = Color(0xFF1E293B);
  static const _surface2 = Color(0xFF1A2438);
  static const _border   = Color(0xFF334155);
  static const _accent   = Color(0xFF38BDF8);
  static const _textPrimary = Color(0xFFF1F5F9);
  static const _textMuted   = Color(0xFF64748B);

  static const _allGroups = [
    _GroupDef('dashboard',          'Dashboard',          Icons.space_dashboard_outlined,   'Overview panels and summary widgets'),
    _GroupDef('chat',               'Chat',               Icons.forum_outlined,              'Lab team messaging'),
    _GroupDef('culture_collection', 'Culture Collection', Icons.inventory_2_outlined,        'Strains, samples, requests and SOPs'),
    _GroupDef('fish_facility',      'Fish Facility',      Icons.water_outlined,              'Fish stock, tank map, lines and SOPs'),
    _GroupDef('resources',          'Resources',          Icons.category_outlined,           'Reagents, equipment and reservations'),
  ];

  Set<String> _enabled = {};
  bool _loading = true;
  bool _saving  = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    await AppSettings.load();
    if (mounted) {
      setState(() {
        _enabled = AppSettings.visibleGroups;
        _loading = false;
      });
    }
  }

  Future<void> _toggle(String key, bool value) async {
    final updated = Set<String>.from(_enabled);
    if (value) { updated.add(key); } else { updated.remove(key); }
    setState(() { _enabled = updated; _saving = true; });
    await AppSettings.setVisibleGroups(updated);
    if (mounted) setState(() => _saving = false);
    widget.onSettingsChanged();
  }

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: _bg,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Toolbar ──────────────────────────────────────────────────────
          Container(
            height: 56,
            decoration: const BoxDecoration(
              color: _surface2,
              border: Border(bottom: BorderSide(color: _border)),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(children: [
              const Icon(Icons.settings_outlined, color: _accent, size: 20),
              const SizedBox(width: 10),
              Text('App Settings',
                style: GoogleFonts.spaceGrotesk(
                  color: _textPrimary, fontSize: 16, fontWeight: FontWeight.w600)),
              const Spacer(),
              if (_saving)
                const SizedBox(
                  width: 16, height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF38BDF8)),
                ),
            ]),
          ),

          // ── Body ─────────────────────────────────────────────────────────
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
                      Text('Menu Visibility',
                        style: GoogleFonts.spaceGrotesk(
                          color: _textPrimary, fontSize: 15, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 4),
                      Text('Choose which sections appear in the sidebar. Changes apply immediately for all users.',
                        style: GoogleFonts.spaceGrotesk(color: _textMuted, fontSize: 13)),
                      const SizedBox(height: 16),

                      // Toggle cards
                      Container(
                        decoration: BoxDecoration(
                          color: _surface,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: _border),
                        ),
                        child: Column(children: [
                          for (int i = 0; i < _allGroups.length; i++) ...[
                            if (i > 0) const Divider(color: _border, height: 1),
                            _GroupToggleRow(
                              def: _allGroups[i],
                              enabled: _enabled.contains(_allGroups[i].key),
                              onChanged: (v) => _toggle(_allGroups[i].key, v),
                            ),
                          ],
                          // Admin — always visible, informational
                          const Divider(color: _border, height: 1),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                            child: Row(children: [
                              Container(
                                width: 36, height: 36,
                                decoration: BoxDecoration(
                                  color: const Color(0xFF6366F1).withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Icon(Icons.admin_panel_settings_outlined,
                                  color: Color(0xFF6366F1), size: 18),
                              ),
                              const SizedBox(width: 14),
                              Expanded(child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Admin', style: GoogleFonts.spaceGrotesk(
                                    color: _textPrimary, fontSize: 14, fontWeight: FontWeight.w500)),
                                  Text('Users, audit log, settings — always visible to admins',
                                    style: GoogleFonts.spaceGrotesk(color: _textMuted, fontSize: 12)),
                                ],
                              )),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF6366F1).withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text('Always on',
                                  style: GoogleFonts.spaceGrotesk(
                                    color: const Color(0xFF6366F1), fontSize: 11)),
                              ),
                            ]),
                          ),
                        ]),
                      ),

                      const SizedBox(height: 16),
                      Row(children: [
                        const Icon(Icons.cloud_done_outlined, color: _textMuted, size: 14),
                        const SizedBox(width: 6),
                        Expanded(child: Text(
                          'Settings are stored in the database and apply to all users immediately.',
                          style: GoogleFonts.spaceGrotesk(color: _textMuted, fontSize: 12),
                        )),
                      ]),
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

// ── Data ─────────────────────────────────────────────────────────────────────

class _GroupDef {
  final String key;
  final String label;
  final IconData icon;
  final String description;
  const _GroupDef(this.key, this.label, this.icon, this.description);
}

// ── Toggle row ───────────────────────────────────────────────────────────────

class _GroupToggleRow extends StatelessWidget {
  final _GroupDef def;
  final bool enabled;
  final ValueChanged<bool> onChanged;

  const _GroupToggleRow({
    required this.def,
    required this.enabled,
    required this.onChanged,
  });

  static const _textPrimary = Color(0xFFF1F5F9);
  static const _textMuted   = Color(0xFF64748B);

  static Color _accentFor(String key) => switch (key) {
    'dashboard'          => const Color(0xFF6366F1),
    'chat'               => const Color(0xFF22D3EE),
    'culture_collection' => const Color(0xFF10B981),
    'fish_facility'      => const Color(0xFF0EA5E9),
    'resources'          => const Color(0xFFF59E0B),
    _                    => const Color(0xFF38BDF8),
  };

  @override
  Widget build(BuildContext context) {
    final accent = _accentFor(def.key);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(children: [
        Container(
          width: 36, height: 36,
          decoration: BoxDecoration(
            color: (enabled ? accent : const Color(0xFF334155)).withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(def.icon, color: enabled ? accent : _textMuted, size: 18),
        ),
        const SizedBox(width: 14),
        Expanded(child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(def.label, style: GoogleFonts.spaceGrotesk(
              color: enabled ? _textPrimary : _textMuted,
              fontSize: 14, fontWeight: FontWeight.w500)),
            Text(def.description, style: GoogleFonts.spaceGrotesk(
              color: _textMuted, fontSize: 12)),
          ],
        )),
        const SizedBox(width: 8),
        Switch(
          value: enabled,
          onChanged: onChanged,
          activeTrackColor: accent,
          activeThumbColor: Colors.white,
        ),
      ]),
    );
  }
}
