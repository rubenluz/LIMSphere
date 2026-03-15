import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

// Design tokens
const _bg       = Color(0xFF0F172A);
const _surface  = Color(0xFF1E293B);
const _surface2 = Color(0xFF1A2438);
const _border   = Color(0xFF334155);
const _accent   = Color(0xFF38BDF8);
const _textPri  = Color(0xFFF1F5F9);
const _textSec  = Color(0xFF94A3B8);
const _textMut  = Color(0xFF64748B);

class UserSettingsDialog extends StatefulWidget {
  final Map<String, dynamic> userInfo;
  const UserSettingsDialog({super.key, required this.userInfo});

  @override
  State<UserSettingsDialog> createState() => _UserSettingsDialogState();
}

class _UserSettingsDialogState extends State<UserSettingsDialog> {
  late final TextEditingController _usernameController;
  late final TextEditingController _phoneController;
  late final TextEditingController _orcidController;
  late final TextEditingController _institutionController;
  late final TextEditingController _groupController;
  late final TextEditingController _avatarController;

  late final Map<String, String> _perms;

  @override
  void initState() {
    super.initState();
    final u = widget.userInfo;

    _usernameController = TextEditingController(text: u['user_name'] ?? '');
    _phoneController = TextEditingController(text: u['user_phone'] ?? '');
    _institutionController = TextEditingController(text: u['user_institution'] ?? '');
    _groupController = TextEditingController(text: u['user_group'] ?? '');
    _orcidController = TextEditingController(text: u['user_orcid'] ?? '');
    _avatarController = TextEditingController(text: u['user_avatar_url'] ?? '');

    _perms = {
      'Dashboard': u['user_table_dashboard'] ?? 'none',
      'Chat': u['user_table_chat'] ?? 'none',
      'Culture collection': u['user_table_culture_collection'] ?? 'none',
      'Fish facility': u['user_table_fish_facility'] ?? 'none',
      'Resources': u['user_table_resources'] ?? 'none',
    };
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _phoneController.dispose();
    _orcidController.dispose();
    _institutionController.dispose();
    _groupController.dispose();
    _avatarController.dispose();
    super.dispose();
  }

  bool _isValidOrcid(String s) {
    if (s.isEmpty) return true;
    return RegExp(r'^\d{4}-\d{4}-\d{4}-\d{3}[0-9X]$').hasMatch(s);
  }

  InputDecoration _dec(String label, IconData icon) => InputDecoration(
        labelText: label,
        labelStyle: GoogleFonts.spaceGrotesk(color: _textSec, fontSize: 13),
        prefixIcon: Icon(icon, color: _textMut, size: 18),
        filled: true,
        fillColor: _surface2,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: _border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: _border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: _accent, width: 1.5),
        ),
      );

  void _onSave() {
    final newOrcid = _orcidController.text.trim();
    if (!_isValidOrcid(newOrcid)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Invalid ORCID format')),
      );
      return;
    }
    Navigator.pop(context, {
      'user_name': _usernameController.text.trim(),
      'user_phone': _phoneController.text.trim(),
      'user_orcid': newOrcid,
      'user_institution': _institutionController.text.trim(),
      'user_group': _groupController.text.trim(),
      'user_avatar_url': _avatarController.text.trim(),
    });
  }

  @override
  Widget build(BuildContext context) {
    final avatar = _avatarController.text;
    final bodyStyle = GoogleFonts.spaceGrotesk(color: _textPri, fontSize: 14);

    return Dialog(
      backgroundColor: _bg,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: _border),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 620),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ── Header ──────────────────────────────────────────────────
              Container(
                padding: const EdgeInsets.fromLTRB(24, 20, 24, 20),
                decoration: const BoxDecoration(
                  color: _surface,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
                  border: Border(bottom: BorderSide(color: _border)),
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 26,
                      backgroundColor: _surface2,
                      backgroundImage: avatar.isNotEmpty ? NetworkImage(avatar) : null,
                      child: avatar.isEmpty
                          ? const Icon(Icons.person, size: 26, color: _textSec)
                          : null,
                    ),
                    const SizedBox(width: 14),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Edit profile',
                            style: GoogleFonts.spaceGrotesk(
                                color: _textPri,
                                fontSize: 17,
                                fontWeight: FontWeight.w600)),
                        Text(widget.userInfo['user_email'] ?? '',
                            style: GoogleFonts.spaceGrotesk(
                                color: _textMut, fontSize: 12)),
                      ],
                    ),
                  ],
                ),
              ),

              // ── Body ────────────────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.all(24),
                child: DefaultTextStyle(
                  style: bodyStyle,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Fields — row 1
                      Row(children: [
                        Expanded(
                          child: TextField(
                            controller: _usernameController,
                            style: bodyStyle,
                            decoration: _dec('Username', Icons.person_outline),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextField(
                            controller: _phoneController,
                            style: bodyStyle,
                            decoration: _dec('Phone', Icons.phone_outlined),
                          ),
                        ),
                      ]),
                      const SizedBox(height: 12),

                      // Fields — row 2
                      Row(children: [
                        Expanded(
                          child: TextField(
                            controller: _orcidController,
                            style: bodyStyle,
                            decoration: _dec('ORCID', Icons.badge_outlined),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextField(
                            controller: _groupController,
                            style: bodyStyle,
                            decoration: _dec('Group', Icons.groups_outlined),
                          ),
                        ),
                      ]),
                      const SizedBox(height: 12),

                      TextField(
                        controller: _institutionController,
                        style: bodyStyle,
                        decoration: _dec('Institution', Icons.account_balance_outlined),
                      ),
                      const SizedBox(height: 12),

                      TextField(
                        controller: _avatarController,
                        style: bodyStyle,
                        decoration: _dec('Avatar URL', Icons.image_outlined),
                        onChanged: (_) => setState(() {}),
                      ),

                      const SizedBox(height: 24),

                      // ── Permissions table ──────────────────────────────
                      Text('Permissions',
                          style: GoogleFonts.spaceGrotesk(
                              color: _textSec,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0.8)),
                      const SizedBox(height: 8),

                      Container(
                        decoration: BoxDecoration(
                          color: _surface,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: _border),
                        ),
                        child: Column(
                          children: [
                            _permRow('Dashboard', _perms['Dashboard']!, Icons.dashboard_outlined, isFirst: true),
                            _divider(),
                            _permRow('Chat', _perms['Chat']!, Icons.chat_bubble_outline),
                            _divider(),
                            _permRow('Culture collection', _perms['Culture collection']!, Icons.science_outlined),
                            _divider(),
                            _permRow('Fish facility', _perms['Fish facility']!, Icons.set_meal_outlined),
                            _divider(),
                            _permRow('Resources', _perms['Resources']!, Icons.folder_outlined, isLast: true),
                          ],
                        ),
                      ),

                      const SizedBox(height: 24),

                      // ── Actions ────────────────────────────────────────
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton(
                            onPressed: () => Navigator.pop(context),
                            style: TextButton.styleFrom(
                              foregroundColor: _textSec,
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                            ),
                            child: Text('Cancel',
                                style: GoogleFonts.spaceGrotesk(fontSize: 13)),
                          ),
                          const SizedBox(width: 8),
                          FilledButton.icon(
                            onPressed: _onSave,
                            style: FilledButton.styleFrom(
                              backgroundColor: _accent,
                              foregroundColor: _bg,
                              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8)),
                            ),
                            icon: const Icon(Icons.save_outlined, size: 16),
                            label: Text('Save changes',
                                style: GoogleFonts.spaceGrotesk(
                                    fontSize: 13, fontWeight: FontWeight.w600)),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _divider() => const Divider(height: 1, thickness: 1, color: _border);

  Widget _permRow(String name, String value, IconData icon,
      {bool isFirst = false, bool isLast = false}) {
    final (Color badge, Color badgeBg, String label) = switch (value) {
      'write' => (const Color(0xFF34D399), const Color(0xFF064E3B), 'Write'),
      'read'  => (const Color(0xFFFBBF24), const Color(0xFF451A03), 'Read'),
      _       => (_textMut, _surface2, 'None'),
    };

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Row(
        children: [
          Icon(icon, size: 16, color: _textSec),
          const SizedBox(width: 10),
          Expanded(
            child: Text(name,
                style: GoogleFonts.spaceGrotesk(color: _textPri, fontSize: 13)),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: badgeBg,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(label,
                style: GoogleFonts.spaceGrotesk(
                    color: badge, fontSize: 11, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }
}