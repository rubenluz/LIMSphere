import 'package:flutter/material.dart';

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
    _orcidController = TextEditingController(text: u['user_orcid'] ?? '');
    _institutionController = TextEditingController(text: u['user_institution'] ?? '');
    _groupController = TextEditingController(text: u['user_group'] ?? '');
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
    final orcidPattern = RegExp(r'^\d{4}-\d{4}-\d{4}-\d{3}[0-9X]$');
    return orcidPattern.hasMatch(s);
  }

  InputDecoration _dec(String label, IconData icon) => InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      );

  Widget _twoCols(Widget left, Widget right) {
    return Row(
      children: [
        Expanded(child: left),
        const SizedBox(width: 12),
        Expanded(child: right),
      ],
    );
  }

  Widget _permissionTile(String name, String value, IconData icon) {
    Color color;
    switch (value) {
      case 'read':
        color = Colors.orange;
        break;
      case 'write':
        color = Colors.green;
        break;
      default:
        color = Colors.grey;
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: color.withOpacity(0.08),
        border: Border.all(color: color.withOpacity(0.4)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color),
          const SizedBox(width: 10),
          Expanded(child: Text(name)),
          Text(value.toUpperCase(),
              style: TextStyle(color: color, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

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

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 650),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [

              /// TITLE + AVATAR
              Row(
                children: [
                  CircleAvatar(
                    radius: 32,
                    backgroundImage:
                        avatar.isNotEmpty ? NetworkImage(avatar) : null,
                    child: avatar.isEmpty ? const Icon(Icons.person, size: 32) : null,
                  ),
                  const SizedBox(width: 16),
                  const Text('Edit profile',
                      style:
                          TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                ],
              ),

              const SizedBox(height: 24),

              /// USER INFO
              _twoCols(
                TextField(controller: _usernameController, decoration: _dec('Username', Icons.person)),
                TextField(controller: _phoneController, decoration: _dec('Phone', Icons.phone)),
              ),

              const SizedBox(height: 12),

              _twoCols(
                TextField(controller: _orcidController, decoration: _dec('ORCID', Icons.badge)),
                TextField(controller: _groupController, decoration: _dec('Group', Icons.groups)),
              ),

              const SizedBox(height: 12),

              TextField(
                controller: _institutionController,
                decoration: _dec('Institution', Icons.account_balance),
              ),

              const SizedBox(height: 12),

              TextField(
                controller: _avatarController,
                decoration: _dec('Avatar URL', Icons.image),
                onChanged: (_) => setState(() {}),
              ),

              const SizedBox(height: 24),
              const Divider(),

              const Align(
                alignment: Alignment.centerLeft,
                child: Text('Permissions',
                    style:
                        TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ),

              const SizedBox(height: 12),

              GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                mainAxisSpacing: 10,
                crossAxisSpacing: 10,
                childAspectRatio: 3.5,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  _permissionTile('Dashboard', _perms['Dashboard']!, Icons.dashboard),
                  _permissionTile('Chat', _perms['Chat']!, Icons.chat),
                  _permissionTile('Culture', _perms['Culture collection']!, Icons.science),
                  _permissionTile('Fish facility', _perms['Fish facility']!, Icons.set_meal),
                  _permissionTile('Resources', _perms['Resources']!, Icons.folder),
                ],
              ),

              const SizedBox(height: 24),

              /// ACTIONS
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Cancel')),
                  const SizedBox(width: 12),
                  ElevatedButton.icon(
                    onPressed: _onSave,
                    icon: const Icon(Icons.save),
                    label: const Text('Save'),
                  ),
                ],
              )
            ],
          ),
        ),
      ),
    );
  }
}