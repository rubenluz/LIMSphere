import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '/theme/theme.dart';
import '../theme/theme_controller.dart';

// ignore_for_file: use_build_context_synchronously

final _dtTimeFmt = DateFormat('yyyy-MM-dd HH:mm');

// ═════════════════════════════════════════════════════════════════════════════
// UserDetailPage
// ═════════════════════════════════════════════════════════════════════════════
class UserDetailPage extends StatefulWidget {
  final Map<String, dynamic> userMap;
  final VoidCallback? onSaved;

  const UserDetailPage({
    super.key,
    required this.userMap,
    this.onSaved,
  });

  @override
  State<UserDetailPage> createState() => _UserDetailPageState();
}

class _UserDetailPageState extends State<UserDetailPage> {
  bool _editing = false;
  bool _saving  = false;

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

  late String _role;
  late String _status;
  late String _permDashboard;
  late String _permLabels;
  late String _permChat;
  late String _permCulture;
  late String _permFish;
  late String _permResources;
  late bool   _notificationsEnabled;

  // Read-only info
  late int      _id;
  String? _authUid;
  DateTime? _createdAt;
  DateTime? _updatedAt;
  DateTime? _lastLogin;

  static const _roleOptions   = ['superadmin', 'admin', 'technician', 'researcher', 'viewer'];
  static const _statusOptions = ['pending', 'active', 'inactive'];
  static const _permOptions   = ['none', 'read', 'write'];

  @override
  void initState() {
    super.initState();
    _loadFromMap(widget.userMap);
  }

  void _loadFromMap(Map<String, dynamic> m) {
    _id          = m['user_id']     as int? ?? 0;
    _authUid     = m['user_auth_uid'] as String?;
    _createdAt   = _dt(m['user_created_at']);
    _updatedAt   = _dt(m['user_updated_at']);
    _lastLogin   = _dt(m['user_last_login']);
    _role        = (m['user_role']   as String?) ?? 'researcher';
    _status      = (m['user_status'] as String?) ?? 'pending';
    _permDashboard = (m['user_table_dashboard']          as String?) ?? 'none';
    _permLabels    = (m['user_table_labels']             as String?) ?? 'none';
    _permChat      = (m['user_table_chat']               as String?) ?? 'none';
    _permCulture   = (m['user_table_culture_collection'] as String?) ?? 'none';
    _permFish      = (m['user_table_fish_facility']      as String?) ?? 'none';
    _permResources = (m['user_table_resources']          as String?) ?? 'none';
    _notificationsEnabled = (m['user_notifications_enabled'] as bool?) ?? true;
    _name        = TextEditingController(text: m['user_name']        as String? ?? '');
    _email       = TextEditingController(text: m['user_email']       as String? ?? '');
    _phone       = TextEditingController(text: m['user_phone']       as String? ?? '');
    _orcid       = TextEditingController(text: m['user_orcid']       as String? ?? '');
    _institution = TextEditingController(text: m['user_institution'] as String? ?? '');
    _group       = TextEditingController(text: m['user_group']       as String? ?? '');
    _bio         = TextEditingController(text: m['user_bio']         as String? ?? '');
    _timezone    = TextEditingController(text: m['user_timezone']    as String? ?? '');
    _language    = TextEditingController(text: m['user_language']    as String? ?? '');
    _avatarUrl   = TextEditingController(text: m['user_avatar_url']  as String? ?? '');
  }

  static DateTime? _dt(dynamic v) {
    if (v == null) return null;
    if (v is DateTime) return v;
    return DateTime.tryParse(v.toString());
  }

  @override
  void dispose() {
    for (final c in [
      _name, _email, _phone, _orcid, _institution,
      _group, _bio, _timezone, _language, _avatarUrl,
    ]) { c.dispose(); }
    super.dispose();
  }

  // ── Helpers ───────────────────────────────────────────────────────────────
  void _snack(String msg, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: isError ? AppDS.red : AppDS.surface3,
    ));
  }

  String get _displayName {
    final n = _name.text.trim();
    return n.isNotEmpty ? n : _email.text.trim();
  }

  String get _initials {
    final n = _name.text.trim();
    if (n.isNotEmpty) {
      final parts = n.split(' ');
      if (parts.length >= 2) return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
      return n[0].toUpperCase();
    }
    final e = _email.text.trim();
    return e.isNotEmpty ? e[0].toUpperCase() : '?';
  }

  Color get _roleColor {
    switch (_role) {
      case 'superadmin': return AppDS.red;
      case 'admin':      return AppDS.orange;
      case 'technician': return AppDS.accent;
      case 'researcher': return AppDS.green;
      case 'viewer':     return AppDS.textMuted;
      default:           return AppDS.textSecondary;
    }
  }

  Color get _statusColor {
    switch (_status) {
      case 'active':   return AppDS.green;
      case 'pending':  return AppDS.orange;
      case 'inactive': return AppDS.textMuted;
      default:         return AppDS.textSecondary;
    }
  }

  // ── Save ──────────────────────────────────────────────────────────────────
  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      final data = <String, dynamic>{
        'user_name':        _name.text.trim().isEmpty ? null : _name.text.trim(),
        'user_email':       _email.text.trim(),
        'user_role':        _role,
        'user_status':      _status,
        'user_phone':       _phone.text.trim().isEmpty ? null : _phone.text.trim(),
        'user_orcid':       _orcid.text.trim().isEmpty ? null : _orcid.text.trim(),
        'user_institution': _institution.text.trim().isEmpty ? null : _institution.text.trim(),
        'user_group':       _group.text.trim().isEmpty ? null : _group.text.trim(),
        'user_bio':         _bio.text.trim().isEmpty ? null : _bio.text.trim(),
        'user_timezone':    _timezone.text.trim().isEmpty ? null : _timezone.text.trim(),
        'user_language':    _language.text.trim().isEmpty ? null : _language.text.trim(),
        'user_avatar_url':  _avatarUrl.text.trim().isEmpty ? null : _avatarUrl.text.trim(),
        'user_table_dashboard':          _permDashboard,
        'user_table_labels':             _permLabels,
        'user_table_chat':               _permChat,
        'user_table_culture_collection': _permCulture,
        'user_table_fish_facility':      _permFish,
        'user_table_resources':          _permResources,
        'user_notifications_enabled':    _notificationsEnabled,
        'user_updated_at': DateTime.now().toIso8601String(),
      };
      await Supabase.instance.client
          .from('users')
          .update(data)
          .eq('user_id', _id);
      setState(() { _editing = false; _updatedAt = DateTime.now(); });
      widget.onSaved?.call();
      _snack('Saved');
    } catch (e) {
      _snack('Save failed: $e', isError: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _cancelEdit() {
    setState(() { _editing = false; });
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
          style: GoogleFonts.spaceGrotesk(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: context.appTextPrimary),
        ),
        actions: [
          if (_editing) ...[
            TextButton(
              onPressed: _cancelEdit,
              child: Text('Cancel',
                  style: GoogleFonts.spaceGrotesk(
                      color: context.appTextSecondary, fontSize: 13)),
            ),
            const SizedBox(width: 4),
            ElevatedButton(
              onPressed: _saving ? null : _save,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppDS.accent,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 8),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
              ),
              child: _saving
                  ? const SizedBox(
                      width: 14, height: 14,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : Text('Save',
                      style: GoogleFonts.spaceGrotesk(
                          fontWeight: FontWeight.w600, fontSize: 13)),
            ),
            const SizedBox(width: 12),
          ] else ...[
            TextButton.icon(
              onPressed: () => setState(() => _editing = true),
              icon: const Icon(Icons.edit_outlined, size: 15,
                  color: AppDS.accent),
              label: Text('Edit',
                  style: GoogleFonts.spaceGrotesk(
                      color: AppDS.accent, fontSize: 13)),
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
                    _field('Full Name', _name, enabled: _editing),
                    _field('Email', _email, enabled: _editing),
                  ),
                  _row2(
                    _field('Phone', _phone, enabled: _editing,
                        hint: '+351 912 345 678'),
                    _field('ORCID', _orcid, enabled: _editing,
                        hint: '0000-0000-0000-0000', mono: true),
                  ),
                ]),
                const SizedBox(height: 16),
                _buildSection('Organization', [
                  _row2(
                    _field('Institution', _institution, enabled: _editing),
                    _field('Group / Lab', _group, enabled: _editing),
                  ),
                ]),
                const SizedBox(height: 16),
                _buildSection('Profile', [
                  _field('Bio', _bio, enabled: _editing, maxLines: 4,
                      hint: 'Short description…'),
                  const SizedBox(height: 10),
                  _row2(
                    _field('Timezone', _timezone, enabled: _editing,
                        hint: 'Europe/Lisbon'),
                    _field('Language', _language, enabled: _editing,
                        hint: 'en, pt, de…'),
                  ),
                  const SizedBox(height: 10),
                  _field('Avatar URL', _avatarUrl, enabled: _editing,
                      hint: 'https://…', mono: true),
                ]),
                const SizedBox(height: 16),
                _buildSection('Access & Role', [
                  _row2(
                    _dropDown('Role', _role, _roleOptions,
                        (v) => setState(() => _role = v ?? _role)),
                    _dropDown('Status', _status, _statusOptions,
                        (v) => setState(() => _status = v ?? _status)),
                  ),
                ]),
                const SizedBox(height: 16),
                _buildSection('Module Permissions', [
                  _permTable(),
                  const SizedBox(height: 10),
                  Row(children: [
                    _editing
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
                      style: GoogleFonts.spaceGrotesk(
                          fontSize: 12,
                          color: _notificationsEnabled
                              ? AppDS.textPrimary
                              : AppDS.textMuted),
                    ),
                  ]),
                ]),
                const SizedBox(height: 16),
                _buildSection('Metadata', [
                  _metaRow('User ID',     '$_id'),
                  if (_authUid != null)
                    _metaRow('Auth UID', _authUid!),
                  _metaRow('Created',
                      _createdAt != null ? _dtTimeFmt.format(_createdAt!.toLocal()) : '—'),
                  _metaRow('Last Updated',
                      _updatedAt != null ? _dtTimeFmt.format(_updatedAt!.toLocal()) : '—'),
                  _metaRow('Last Login',
                      _lastLogin != null ? _dtTimeFmt.format(_lastLogin!.toLocal()) : '—'),
                ]),
                const SizedBox(height: 16),
                _buildSection('Appearance', [
                  AnimatedBuilder(
                    animation: appThemeCtrl,
                    builder: (_, _x) => Row(
                      children: [
                        _themeBtn(context, 'Light', ThemeMode.light, Icons.light_mode_outlined),
                        const SizedBox(width: 8),
                        _themeBtn(context, 'Dark', ThemeMode.dark, Icons.dark_mode_outlined),
                        const SizedBox(width: 8),
                        _themeBtn(context, 'System', ThemeMode.system, Icons.brightness_auto_outlined),
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
          backgroundImage:
              url.isNotEmpty ? NetworkImage(url) : null,
          child: url.isEmpty
              ? Text(
                  _initials,
                  style: GoogleFonts.spaceGrotesk(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      color: _roleColor),
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
                style: GoogleFonts.spaceGrotesk(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: context.appTextPrimary),
              ),
              const SizedBox(height: 4),
              Text(
                _email.text,
                style: GoogleFonts.jetBrainsMono(
                    fontSize: 12, color: context.appTextSecondary),
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
      ('Dashboard',         _permDashboard, (String v) => setState(() => _permDashboard = v)),
      ('Labels',            _permLabels,    (String v) => setState(() => _permLabels = v)),
      ('Chat',              _permChat,      (String v) => setState(() => _permChat = v)),
      ('Culture Collection',_permCulture,   (String v) => setState(() => _permCulture = v)),
      ('Fish Facility',     _permFish,      (String v) => setState(() => _permFish = v)),
      ('Resources',         _permResources, (String v) => setState(() => _permResources = v)),
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
                  : Border(
                      bottom: BorderSide(color: context.appBorder)),
            ),
            padding: const EdgeInsets.symmetric(
                horizontal: 14, vertical: 10),
            child: Row(
              children: [
                SizedBox(
                  width: 160,
                  child: Text(m.$1,
                      style: GoogleFonts.spaceGrotesk(
                          fontSize: 13, color: context.appTextPrimary)),
                ),
                if (_editing)
                  Wrap(
                    spacing: 6,
                    children: _permOptions.map((opt) {
                      final selected = m.$2 == opt;
                      final c = _permColor(opt);
                      return GestureDetector(
                        onTap: () => m.$3(opt),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 3),
                          decoration: BoxDecoration(
                            color: selected
                                ? c.withValues(alpha: 0.18)
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(
                              color: selected
                                  ? c
                                  : context.appBorder,
                            ),
                          ),
                          child: Text(opt,
                              style: GoogleFonts.spaceGrotesk(
                                  fontSize: 11,
                                  fontWeight: selected
                                      ? FontWeight.w700
                                      : FontWeight.normal,
                                  color: selected
                                      ? c
                                      : context.appTextMuted)),
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

  // ── Section / field helpers ───────────────────────────────────────────────
  Widget _buildSection(String title, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title.toUpperCase(),
          style: GoogleFonts.spaceGrotesk(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: context.appTextMuted,
              letterSpacing: 1.0),
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
        Text(label,
            style: GoogleFonts.spaceGrotesk(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: context.appTextMuted,
                letterSpacing: 0.5)),
        const SizedBox(height: 4),
        enabled
            ? TextFormField(
                controller: ctrl,
                maxLines: maxLines,
                style: (mono
                        ? GoogleFonts.jetBrainsMono(fontSize: 12)
                        : GoogleFonts.spaceGrotesk(fontSize: 13))
                    .copyWith(color: context.appTextPrimary),
                decoration: InputDecoration(
                  hintText: hint,
                  hintStyle: GoogleFonts.spaceGrotesk(
                      fontSize: 12, color: context.appTextMuted),
                  filled: true,
                  fillColor: context.appSurface2,
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 8),
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
                style: (mono
                        ? GoogleFonts.jetBrainsMono(fontSize: 12)
                        : GoogleFonts.spaceGrotesk(fontSize: 13))
                    .copyWith(
                        color: ctrl.text.isEmpty
                            ? context.appTextMuted
                            : context.appTextPrimary),
              ),
        const SizedBox(height: 10),
      ],
    );
  }

  Widget _dropDown(
    String label,
    String value,
    List<String> options,
    ValueChanged<String?> onChanged,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: GoogleFonts.spaceGrotesk(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: context.appTextMuted,
                letterSpacing: 0.5)),
        const SizedBox(height: 4),
        _editing
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
                    style: GoogleFonts.spaceGrotesk(
                        fontSize: 13, color: context.appTextPrimary),
                    items: options
                        .map((o) => DropdownMenuItem(
                              value: o,
                              child: Text(o),
                            ))
                        .toList(),
                    onChanged: onChanged,
                    icon: Icon(Icons.expand_more,
                        size: 16, color: context.appTextMuted),
                  ),
                ),
              )
            : Text(value,
                style: GoogleFonts.spaceGrotesk(
                    fontSize: 13, color: context.appTextPrimary)),
        const SizedBox(height: 10),
      ],
    );
  }

  Widget _themeBtn(BuildContext context, String label, ThemeMode mode, IconData icon) {
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
            child: Text(label,
                style: GoogleFonts.spaceGrotesk(
                    fontSize: 12, color: context.appTextMuted)),
          ),
          Expanded(
            child: Text(value,
                style: GoogleFonts.jetBrainsMono(
                    fontSize: 11, color: context.appTextSecondary)),
          ),
        ],
      ),
    );
  }

  Widget _badge(String label, Color color) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: color.withValues(alpha: 0.35)),
    ),
    child: Text(
      label,
      style: GoogleFonts.spaceGrotesk(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: color,
          letterSpacing: 0.2),
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
        style: GoogleFonts.spaceGrotesk(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: c),
      ),
    );
  }

  static Color _permColor(String p) {
    switch (p) {
      case 'write': return AppDS.green;
      case 'read':  return AppDS.accent;
      default:      return AppDS.textMuted;
    }
  }
}
