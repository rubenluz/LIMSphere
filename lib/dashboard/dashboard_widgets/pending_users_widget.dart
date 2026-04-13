// pending_users_widget.dart – Dashboard widget showing users with status
// 'pending' who are awaiting admin approval. Only admins can add this widget.

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:io' show Platform;
import '/theme/theme.dart';

class PendingUsersWidget extends StatefulWidget {
  const PendingUsersWidget({super.key});

  @override
  State<PendingUsersWidget> createState() => _PendingUsersWidgetState();
}

class _PendingUsersWidgetState extends State<PendingUsersWidget> {
  List<_PendingUser> _users = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  bool _isDesktop(BuildContext context) {
    if (kIsWeb) return true;
    try {
      if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) return true;
    } catch (_) {}
    return MediaQuery.of(context).size.width >= 600;
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final rows = await Supabase.instance.client
          .from('users')
          .select('user_name, user_email, user_role, user_created_at')
          .eq('user_status', 'pending')
          .order('user_created_at', ascending: false);

      final List<_PendingUser> users = [];
      for (final r in rows as List) {
        users.add(_PendingUser(
          name: r['user_name'] as String? ?? '',
          email: r['user_email'] as String? ?? '',
          role: r['user_role'] as String? ?? '',
          createdAt: DateTime.tryParse(
              r['user_created_at'] as String? ?? ''),
        ));
      }

      if (!mounted) return;
      setState(() {
        _users = users;
        _loading = false;
      });
    } catch (e) {
      debugPrint('PendingUsersWidget error: $e');
      if (mounted) setState(() => _loading = false);
    }
  }

  String _fmtDate(DateTime? d) {
    if (d == null) return '—';
    return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  }

  Widget _buildContent() {
    if (_loading) {
      return const Padding(
        padding: EdgeInsets.all(24),
        child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
      );
    }
    if (_users.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(24),
        child: Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.how_to_reg,
                size: 32, color: AppDS.green.withAlpha(180)),
            const SizedBox(height: 8),
            Text('No pending users',
                style: TextStyle(
                    fontSize: 12, color: context.appTextSecondary)),
          ]),
        ),
      );
    }

    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.all(10),
      itemCount: _users.length,
      separatorBuilder: (_, _) => const SizedBox(height: 6),
      itemBuilder: (_, i) {
        final u = _users[i];
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: AppDS.yellow.withAlpha(25),
            border: Border.all(color: AppDS.yellow.withAlpha(100)),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Row(children: [
            CircleAvatar(
              radius: 16,
              backgroundColor: AppDS.yellow.withAlpha(60),
              child: Text(
                (u.name.isNotEmpty ? u.name[0] : u.email.isNotEmpty ? u.email[0] : '?')
                    .toUpperCase(),
                style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: AppDS.yellow),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    u.name.isNotEmpty ? u.name : u.email,
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: context.appTextPrimary),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${u.email}  ·  ${_fmtDate(u.createdAt)}',
                    style: TextStyle(
                        fontSize: 10, color: context.appTextMuted),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: AppDS.yellow.withAlpha(50),
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: AppDS.yellow.withAlpha(100)),
              ),
              child: Text(u.role.isNotEmpty ? u.role : 'viewer',
                  style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: AppDS.yellow)),
            ),
          ]),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final desktop = _isDesktop(context);
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: AppDS.yellow, width: 2),
        borderRadius: BorderRadius.circular(8),
      ),
      height: desktop ? 360 : null,
      child: Column(
        mainAxisSize: desktop ? MainAxisSize.max : MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 6, 8),
            child: Row(children: [
              const Icon(Icons.person_add_outlined,
                  size: 20, color: AppDS.yellow),
              const SizedBox(width: 8),
              Expanded(
                child: Text.rich(TextSpan(children: [
                  TextSpan(
                    text: 'Pending Users',
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: context.appTextPrimary),
                  ),
                  if (_users.isNotEmpty)
                    TextSpan(
                      text: '  ${_users.length}',
                      style: TextStyle(
                          fontSize: 12, color: context.appTextMuted),
                    ),
                ])),
              ),
              IconButton(
                icon: const Icon(Icons.refresh, size: 16),
                padding: EdgeInsets.zero,
                constraints:
                    const BoxConstraints(minWidth: 24, minHeight: 24),
                onPressed: _load,
                tooltip: 'Refresh',
              ),
            ]),
          ),
          Divider(height: 1, color: context.appBorder),
          if (desktop)
            Expanded(child: SingleChildScrollView(child: _buildContent()))
          else
            _buildContent(),
        ],
      ),
    );
  }
}

class _PendingUser {
  final String name;
  final String email;
  final String role;
  final DateTime? createdAt;
  const _PendingUser({
    required this.name,
    required this.email,
    required this.role,
    required this.createdAt,
  });
}
