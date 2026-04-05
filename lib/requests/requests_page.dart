// requests_page.dart - Unified request management.
// Any user can create requests; creators can edit/delete their own.
// Write-permission users (culture_collection) can edit/close any request.
// Admins can do everything.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide LocalStorage;
import '/theme/theme.dart';
import '/menu/app_nav.dart';

// ── Model ─────────────────────────────────────────────────────────────────────

class _Req {
  final int id;
  final String type, title, priority, status;
  final String? description, quantity, createdByName, closedByName, notes;
  final int? createdBy, closedBy;
  final DateTime? createdAt;

  const _Req({
    required this.id,
    required this.type,
    required this.title,
    required this.priority,
    required this.status,
    this.description,
    this.quantity,
    this.createdBy,
    this.createdByName,
    this.closedBy,
    this.closedByName,
    this.notes,
    this.createdAt,
  });

  factory _Req.fromMap(Map<String, dynamic> m) {
    final creator = m['creator'] as Map?;
    final closer  = m['closer']  as Map?;
    return _Req(
      id:            m['request_id']       as int,
      type:          m['request_type']     as String? ?? 'other',
      title:         m['request_title']    as String? ?? '',
      priority:      m['request_priority'] as String? ?? 'normal',
      status:        m['request_status']   as String? ?? 'pending',
      description:   m['request_description'] as String?,
      quantity:      m['request_quantity']    as String?,
      createdBy:     m['request_created_by']  as int?,
      createdByName: creator?['user_name']    as String?,
      closedBy:      m['request_closed_by']   as int?,
      closedByName:  closer?['user_name']     as String?,
      notes:         m['request_notes']       as String?,
      createdAt: m['request_created_at'] != null
          ? DateTime.tryParse(m['request_created_at'] as String)
          : null,
    );
  }
}

// ── Helpers ───────────────────────────────────────────────────────────────────

IconData _typeIcon(String t) => switch (t) {
  'strains'     => Icons.biotech_outlined,
  'fish_lines'  => Icons.science_outlined,
  'fish_eggs'   => Icons.egg_outlined,
  'reagents'    => Icons.water_drop_outlined,
  'equipment'   => Icons.precision_manufacturing_outlined,
  'consumables' => Icons.inventory_2_outlined,
  _             => Icons.help_outline_rounded,
};

String _typeLabel(String t) => switch (t) {
  'strains'     => 'Strains',
  'fish_lines'  => 'Fish Lines',
  'fish_eggs'   => 'Fish Eggs',
  'reagents'    => 'Reagents',
  'equipment'   => 'Equipment',
  'consumables' => 'Consumables',
  _             => 'Other',
};

Color _typeColor(String t) => switch (t) {
  'strains'     => const Color(0xFF10B981),
  'fish_lines'  => const Color(0xFF0EA5E9),
  'fish_eggs'   => const Color(0xFF38BDF8),
  'reagents'    => const Color(0xFFF59E0B),
  'equipment'   => const Color(0xFF14B8A6),
  'consumables' => const Color(0xFF8B5CF6),
  _             => const Color(0xFF64748B),
};

Color _priorityColor(String p) => switch (p) {
  'low'    => const Color(0xFF64748B),
  'high'   => AppDS.orange,
  'urgent' => AppDS.red,
  _        => AppDS.accent,
};

String _priorityLabel(String p) => switch (p) {
  'low'    => 'Low',
  'high'   => 'High',
  'urgent' => 'Urgent',
  _        => 'Normal',
};

Color _statusColor(String s) => switch (s) {
  'concluded' => AppDS.green,
  'refused'   => AppDS.red,
  _           => AppDS.yellow,
};

String _statusLabel(String s) => switch (s) {
  'concluded' => 'Concluded',
  'refused'   => 'Refused',
  _           => 'Pending',
};

String _fmtDate(DateTime? dt) {
  if (dt == null) return '';
  final d = dt.toLocal();
  return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}

const _kAccent = Color(0xFF8B5CF6);
const _kTypes = ['strains', 'fish_lines', 'fish_eggs', 'reagents', 'equipment', 'consumables', 'other'];
const _kPriorities = ['low', 'normal', 'high', 'urgent'];

// ── Page ──────────────────────────────────────────────────────────────────────

class RequestsPage extends StatefulWidget {
  const RequestsPage({super.key});

  /// Count of pending requests. MenuPage listens to this for the badge.
  static final pendingNotifier = ValueNotifier<int>(0);

  static RealtimeChannel? _bgSub;
  static Timer? _bgTimer;

  /// Start the always-on background listener. Call once from MenuPage.initState.
  static Future<void> startBackgroundListener() async {
    if (_bgSub != null) return;
    final client = Supabase.instance.client;

    // Subscribe to explicit events (UPDATE requires REPLICA IDENTITY FULL,
    // so we also poll periodically as a reliable fallback).
    _bgSub = client
        .channel('requests_pending_background')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'requests',
          callback: (_) => _refreshPendingCount(),
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'requests',
          callback: (_) => _refreshPendingCount(),
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.delete,
          schema: 'public',
          table: 'requests',
          callback: (_) => _refreshPendingCount(),
        )
        .subscribe();

    // Poll every 30 s so the badge stays accurate even if realtime is not
    // enabled for this table in the Supabase dashboard.
    _bgTimer = Timer.periodic(const Duration(seconds: 30), (_) => _refreshPendingCount());

    await _refreshPendingCount();
  }

  static Future<void> _refreshPendingCount() async {
    try {
      final rows = await Supabase.instance.client
          .from('requests')
          .select('request_id')
          .eq('request_status', 'pending') as List<dynamic>;
      pendingNotifier.value = rows.length;
    } catch (_) {}
  }

  @override
  State<RequestsPage> createState() => _RequestsPageState();
}

class _RequestsPageState extends State<RequestsPage> {
  List<_Req> _all = [];
  bool _loading = true;
  String _statusFilter = 'all';
  String _typeFilter   = 'all';
  int?   _expandedId;

  int?   _currentUserId;
  String _userRole = '';
  bool   _hasWritePerm = false;

  @override
  void initState() {
    super.initState();
    _loadCurrentUser();
    _load();
  }

  Future<void> _loadCurrentUser() async {
    try {
      final email = Supabase.instance.client.auth.currentSession?.user.email ?? '';
      final rows  = await Supabase.instance.client
          .from('users')
          .select('user_id, user_role, user_table_culture_collection')
          .eq('user_email', email)
          .limit(1);
      if (!mounted) return;
      if (rows.isNotEmpty) {
        final r = rows[0];
        setState(() {
          _currentUserId = r['user_id'] as int?;
          _userRole      = r['user_role'] as String? ?? '';
          _hasWritePerm  = _isAdmin ||
              (r['user_table_culture_collection'] as String? ?? 'none') == 'write';
        });
      }
    } catch (_) {}
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final rows = await Supabase.instance.client
          .from('requests')
          .select('*, creator:request_created_by(user_name), closer:request_closed_by(user_name)')
          .order('request_created_at', ascending: false)
          .limit(500);
      if (!mounted) return;
      setState(() {
        _all     = rows.map((r) => _Req.fromMap(Map<String, dynamic>.from(r))).toList();
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  List<_Req> get _filtered => _all.where((r) {
    if (_statusFilter != 'all' && r.status != _statusFilter) return false;
    if (_typeFilter   != 'all' && r.type   != _typeFilter)   return false;
    return true;
  }).toList();

  bool get _isAdmin    => ['admin', 'superadmin'].contains(_userRole);
  bool _isCreator(_Req r) => r.createdBy != null && r.createdBy == _currentUserId;
  bool _canEdit(_Req r)   => _isAdmin || _hasWritePerm || _isCreator(r);
  bool get _canClose      => _isAdmin || _hasWritePerm;

  void _showTypeFilterMenu() {
    final renderBox = context.findRenderObject() as RenderBox;
    final offset = renderBox.localToGlobal(Offset.zero);
    showMenu<String>(
      context: context,
      position: RelativeRect.fromLTRB(offset.dx + renderBox.size.width - 180, offset.dy + 56, 0, 0),
      color: context.appSurface2,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: BorderSide(color: context.appBorder2)),
      items: ['all', ..._kTypes].map((t) => PopupMenuItem(
        value: t,
        child: Text(t == 'all' ? 'All Types' : _typeLabel(t),
            style: GoogleFonts.spaceGrotesk(
                fontSize: 13, color: context.appTextPrimary)),
      )).toList(),
    ).then((v) { if (v != null) setState(() => _typeFilter = v); });
  }

  // ── Dialogs ─────────────────────────────────────────────────────────────────

  void _showRequestDialog([_Req? existing]) {
    final titleCtrl = TextEditingController(text: existing?.title ?? '');
    final descCtrl  = TextEditingController(text: existing?.description ?? '');
    final qtyCtrl   = TextEditingController(text: existing?.quantity ?? '');
    String type     = existing?.type     ?? 'strains';
    String priority = existing?.priority ?? 'normal';
    final formKey   = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlg) => AlertDialog(
          backgroundColor: ctx.appSurface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          title: Text(
            existing == null ? 'New Request' : 'Edit Request',
            style: GoogleFonts.spaceGrotesk(
                color: ctx.appTextPrimary, fontWeight: FontWeight.w700),
          ),
          content: SizedBox(
            width: 440,
            child: Form(
              key: formKey,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Type
                    Text('Type',
                        style: GoogleFonts.spaceGrotesk(
                            fontSize: 11, color: ctx.appTextSecondary,
                            fontWeight: FontWeight.w600)),
                    const SizedBox(height: 8),
                    Wrap(spacing: 6, runSpacing: 6,
                      children: _kTypes.map((t) {
                        final sel = t == type;
                        return GestureDetector(
                          onTap: () => setDlg(() => type = t),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              color: sel
                                  ? _typeColor(t).withValues(alpha: 0.15)
                                  : ctx.appSurface2,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                  color: sel ? _typeColor(t) : ctx.appBorder),
                            ),
                            child: Row(mainAxisSize: MainAxisSize.min, children: [
                              Icon(_typeIcon(t), size: 13,
                                  color: sel ? _typeColor(t) : ctx.appTextMuted),
                              const SizedBox(width: 4),
                              Text(_typeLabel(t),
                                  style: GoogleFonts.spaceGrotesk(
                                      fontSize: 11,
                                      color: sel ? _typeColor(t) : ctx.appTextSecondary)),
                            ]),
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 16),
                    // Priority
                    Text('Priority',
                        style: GoogleFonts.spaceGrotesk(
                            fontSize: 11, color: ctx.appTextSecondary,
                            fontWeight: FontWeight.w600)),
                    const SizedBox(height: 8),
                    Row(children: _kPriorities.map((p) {
                      final sel = p == priority;
                      return Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: GestureDetector(
                          onTap: () => setDlg(() => priority = p),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 5),
                            decoration: BoxDecoration(
                              color: sel
                                  ? _priorityColor(p).withValues(alpha: 0.15)
                                  : ctx.appSurface2,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                  color: sel
                                      ? _priorityColor(p)
                                      : ctx.appBorder),
                            ),
                            child: Text(_priorityLabel(p),
                                style: GoogleFonts.spaceGrotesk(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: sel
                                        ? _priorityColor(p)
                                        : ctx.appTextSecondary)),
                          ),
                        ),
                      );
                    }).toList()),
                    const SizedBox(height: 16),
                    // Title
                    TextFormField(
                      controller: titleCtrl,
                      style: GoogleFonts.spaceGrotesk(
                          color: ctx.appTextPrimary, fontSize: 13),
                      decoration: _inputDec(ctx, 'Title *'),
                      validator: (v) =>
                          (v?.trim().isEmpty ?? true) ? 'Required' : null,
                    ),
                    const SizedBox(height: 10),
                    // Description
                    TextFormField(
                      controller: descCtrl,
                      maxLines: 3,
                      style: GoogleFonts.spaceGrotesk(
                          color: ctx.appTextPrimary, fontSize: 13),
                      decoration: _inputDec(ctx, 'Description (optional)'),
                    ),
                    const SizedBox(height: 10),
                    // Quantity
                    TextFormField(
                      controller: qtyCtrl,
                      style: GoogleFonts.spaceGrotesk(
                          color: ctx.appTextPrimary, fontSize: 13),
                      decoration: _inputDec(ctx, 'Quantity (optional)'),
                    ),
                  ],
                ),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('Cancel',
                  style: GoogleFonts.spaceGrotesk(color: ctx.appTextSecondary)),
            ),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: _kAccent),
              onPressed: () async {
                if (!formKey.currentState!.validate()) return;
                Navigator.pop(ctx);
                await _save(
                  existing:    existing,
                  type:        type,
                  priority:    priority,
                  title:       titleCtrl.text.trim(),
                  description: descCtrl.text.trim().isEmpty ? null : descCtrl.text.trim(),
                  quantity:    qtyCtrl.text.trim().isEmpty  ? null : qtyCtrl.text.trim(),
                );
              },
              child: Text(existing == null ? 'Submit' : 'Save',
                  style: GoogleFonts.spaceGrotesk(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _save({
    _Req?   existing,
    required String type,
    required String priority,
    required String title,
    String? description,
    String? quantity,
  }) async {
    try {
      final patch = <String, dynamic>{
        'request_type':        type,
        'request_priority':    priority,
        'request_title':       title,
        'request_description': description,
        'request_quantity':    quantity,
        'request_updated_at':  DateTime.now().toIso8601String(),
      };
      if (existing == null) {
        patch['request_created_by'] = _currentUserId;
        await Supabase.instance.client.from('requests').insert(patch);
      } else {
        await Supabase.instance.client
            .from('requests').update(patch).eq('request_id', existing.id);
      }
      await _load();
    } catch (_) {}
  }

  void _showCloseDialog(_Req r, String newStatus) {
    final notesCtrl = TextEditingController(text: r.notes ?? '');
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: ctx.appSurface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Text(
          newStatus == 'concluded' ? 'Mark as Concluded' : 'Refuse Request',
          style: GoogleFonts.spaceGrotesk(
              color: ctx.appTextPrimary, fontWeight: FontWeight.w700),
        ),
        content: SizedBox(
          width: 380,
          child: TextField(
            controller: notesCtrl,
            maxLines: 3,
            style: GoogleFonts.spaceGrotesk(color: ctx.appTextPrimary, fontSize: 13),
            decoration: _inputDec(ctx, 'Notes (optional)'),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel',
                style: GoogleFonts.spaceGrotesk(color: ctx.appTextSecondary)),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
                backgroundColor:
                    newStatus == 'concluded' ? AppDS.green : AppDS.red),
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                await Supabase.instance.client.from('requests').update({
                  'request_status':    newStatus,
                  'request_closed_by': _currentUserId,
                  'request_notes':
                      notesCtrl.text.trim().isEmpty ? null : notesCtrl.text.trim(),
                  'request_updated_at': DateTime.now().toIso8601String(),
                }).eq('request_id', r.id);
                await _load();
              } catch (_) {}
            },
            child: Text(
              newStatus == 'concluded' ? 'Conclude' : 'Refuse',
              style: GoogleFonts.spaceGrotesk(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _reopen(_Req r) async {
    try {
      await Supabase.instance.client.from('requests').update({
        'request_status':     'pending',
        'request_closed_by':  null,
        'request_notes':      null,
        'request_updated_at': DateTime.now().toIso8601String(),
      }).eq('request_id', r.id);
      await _load();
    } catch (_) {}
  }

  Future<void> _delete(_Req r) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: ctx.appSurface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Text('Delete Request',
            style: GoogleFonts.spaceGrotesk(
                color: ctx.appTextPrimary, fontWeight: FontWeight.w700)),
        content: Text('Delete "${r.title}"? This cannot be undone.',
            style: GoogleFonts.spaceGrotesk(color: ctx.appTextSecondary)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancel',
                style: GoogleFonts.spaceGrotesk(color: ctx.appTextSecondary)),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppDS.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Delete',
                style: GoogleFonts.spaceGrotesk(color: Colors.white)),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await Supabase.instance.client
          .from('requests').delete().eq('request_id', r.id);
      setState(() {
        _all.removeWhere((x) => x.id == r.id);
        if (_expandedId == r.id) _expandedId = null;
      });
    } catch (_) {}
  }

  // ── UI helpers ───────────────────────────────────────────────────────────────

  InputDecoration _inputDec(BuildContext ctx, String hint) => InputDecoration(
    hintText: hint,
    hintStyle: GoogleFonts.spaceGrotesk(color: ctx.appTextMuted, fontSize: 12),
    filled: true,
    fillColor: ctx.appSurface2,
    border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: ctx.appBorder)),
    enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: ctx.appBorder)),
    focusedBorder: const OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(8)),
        borderSide: BorderSide(color: _kAccent)),
    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
    isDense: true,
  );

  Widget _badge(String label, Color color) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(
      color:        color.withValues(alpha: 0.15),
      borderRadius: BorderRadius.circular(20),
      border:       Border.all(color: color.withValues(alpha: 0.4)),
    ),
    child: Text(label,
        style: GoogleFonts.spaceGrotesk(
            fontSize: 10, fontWeight: FontWeight.w600, color: color)),
  );

  Widget _actionBtn({
    required String label,
    required IconData icon,
    required Color color,
    required VoidCallback onPressed,
  }) =>
      OutlinedButton.icon(
        style: OutlinedButton.styleFrom(
          foregroundColor: color,
          side: BorderSide(color: color.withValues(alpha: 0.4)),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          visualDensity: VisualDensity.compact,
        ),
        icon: Icon(icon, size: 14),
        label: Text(label, style: GoogleFonts.spaceGrotesk(fontSize: 12)),
        onPressed: onPressed,
      );

  // ── Build ─────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final filtered = _filtered;
    return Column(
      children: [
        // ── Toolbar ────────────────────────────────────────────────────────
        Container(
          height: 56,
          decoration: BoxDecoration(
            color: context.appSurface2,
            border: Border(bottom: BorderSide(color: context.appBorder)),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(children: [
            if (MediaQuery.of(context).size.width < 700) ...[
              IconButton(
                icon: const Icon(Icons.menu_rounded, size: 20),
                color: context.appTextSecondary,
                tooltip: 'Menu',
                onPressed: openAppDrawer,
              ),
            ],
            const Icon(Icons.assignment_outlined, size: 18, color: Color(0xFF8B5CF6)),
            const SizedBox(width: 8),
            Text('Requests', style: GoogleFonts.spaceGrotesk(
              fontSize: 16, fontWeight: FontWeight.w600,
              color: context.appTextPrimary)),
            const SizedBox(width: 16),
            // Status chips
            Expanded(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(children: [
                  for (final (key, label) in [
                    ('all',       'All'),
                    ('pending',   'Pending'),
                    ('concluded', 'Concluded'),
                    ('refused',   'Refused'),
                  ])
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: GestureDetector(
                        onTap: () => setState(() => _statusFilter = key),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 5),
                          decoration: BoxDecoration(
                            color: _statusFilter == key
                                ? (key == 'all'
                                        ? _kAccent
                                        : _statusColor(key))
                                    .withValues(alpha: 0.15)
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: _statusFilter == key
                                  ? (key == 'all' ? _kAccent : _statusColor(key))
                                  : context.appBorder,
                            ),
                          ),
                          child: Text(label,
                              style: GoogleFonts.spaceGrotesk(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: _statusFilter == key
                                    ? (key == 'all' ? _kAccent : _statusColor(key))
                                    : context.appTextSecondary,
                              )),
                        ),
                      ),
                    ),
                  Text('${filtered.length}',
                      style: GoogleFonts.jetBrainsMono(
                          fontSize: 11, color: context.appTextMuted)),
                ]),
              ),
            ),
            if (MediaQuery.of(context).size.width < 700)
              PopupMenuButton<String>(
                icon: Icon(Icons.more_vert, color: context.appTextSecondary, size: 20),
                tooltip: 'More options',
                offset: const Offset(0, 36),
                color: context.appSurface2,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                    side: BorderSide(color: context.appBorder2)),
                onSelected: (v) {
                  if (v == 'type') _showTypeFilterMenu();
                  if (v == 'refresh') _load();
                  if (v == 'add') _showRequestDialog();
                },
                itemBuilder: (_) => [
                  PopupMenuItem(
                    value: 'type',
                    child: Row(children: [
                      Icon(Icons.filter_list_rounded, size: 16,
                          color: _typeFilter != 'all' ? _kAccent : context.appTextSecondary),
                      const SizedBox(width: 10),
                      Text(_typeFilter == 'all' ? 'Filter Type' : _typeLabel(_typeFilter),
                          style: GoogleFonts.spaceGrotesk(
                              fontSize: 13, color: context.appTextPrimary)),
                      if (_typeFilter != 'all') ...[
                        const Spacer(),
                        Container(width: 7, height: 7,
                            decoration: const BoxDecoration(color: _kAccent, shape: BoxShape.circle)),
                      ],
                    ])),
                  PopupMenuItem(
                    value: 'refresh',
                    child: Row(children: [
                      Icon(Icons.refresh_rounded, size: 16, color: context.appTextSecondary),
                      const SizedBox(width: 10),
                      Text('Refresh', style: GoogleFonts.spaceGrotesk(
                          fontSize: 13, color: context.appTextPrimary)),
                    ])),
                  PopupMenuItem(
                    value: 'add',
                    child: Row(children: [
                      const Icon(Icons.add, size: 16, color: _kAccent),
                      const SizedBox(width: 10),
                      Text('New Request', style: GoogleFonts.spaceGrotesk(
                          fontSize: 13, color: _kAccent)),
                    ])),
                ],
              )
            else ...[
              // Type filter dropdown
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _typeFilter,
                    dropdownColor: context.appSurface2,
                    icon: Icon(Icons.filter_list_rounded,
                        size: 14, color: context.appTextSecondary),
                    selectedItemBuilder: (_) =>
                        ['all', ..._kTypes].map((t) => Align(
                          alignment: Alignment.centerLeft,
                          child: Text(t == 'all' ? 'All Types' : _typeLabel(t),
                              style: GoogleFonts.spaceGrotesk(
                                  color: context.appTextSecondary, fontSize: 12)),
                        )).toList(),
                    items: ['all', ..._kTypes].map((t) => DropdownMenuItem(
                      value: t,
                      child: Text(t == 'all' ? 'All Types' : _typeLabel(t),
                          style: GoogleFonts.spaceGrotesk(
                              color: context.appTextPrimary, fontSize: 12)),
                    )).toList(),
                    onChanged: (v) { if (v != null) setState(() => _typeFilter = v); },
                  ),
                ),
              ),
              Tooltip(
                message: 'Refresh',
                child: IconButton(
                  icon: Icon(Icons.refresh_rounded,
                      color: context.appTextSecondary, size: 18),
                  onPressed: _load,
                ),
              ),
              FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: _kAccent,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
                  minimumSize: const Size(0, 36),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  textStyle: GoogleFonts.spaceGrotesk(fontSize: 13),
                ),
                icon: const Icon(Icons.add, size: 16),
                label: const Text('New Request'),
                onPressed: _showRequestDialog,
              ),
            ],
          ]),
        ),
        Container(height: 1, color: context.appBorder),

        // ── List ──────────────────────────────────────────────────────────
        Expanded(
          child: _loading
              ? const Center(
                  child: CircularProgressIndicator(color: _kAccent))
              : filtered.isEmpty
                  ? Center(
                      child: Text('No requests found.',
                          style: GoogleFonts.spaceGrotesk(
                              color: context.appTextMuted)))
                  : ListView.separated(
                      padding: const EdgeInsets.all(16),
                      itemCount: filtered.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 8),
                      itemBuilder: (_, i) => _buildCard(filtered[i]),
                    ),
        ),
      ],
    );
  }

  Widget _buildCard(_Req r) {
    final expanded  = _expandedId == r.id;
    final typeColor = _typeColor(r.type);
    final canEdit   = _canEdit(r);

    return GestureDetector(
      onTap: () => setState(
          () => _expandedId = expanded ? null : r.id),
      child: Container(
        decoration: BoxDecoration(
          color: context.appSurface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: expanded
                ? _kAccent.withValues(alpha: 0.5)
                : context.appBorder,
          ),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // ── Header ─────────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.all(14),
            child: Row(children: [
              Container(
                width: 36, height: 36,
                decoration: BoxDecoration(
                  color: typeColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(_typeIcon(r.type), size: 18, color: typeColor),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Text(r.title,
                      style: GoogleFonts.spaceGrotesk(
                          color: context.appTextPrimary,
                          fontWeight: FontWeight.w600,
                          fontSize: 14)),
                  const SizedBox(height: 2),
                  Row(children: [
                    Text(_typeLabel(r.type),
                        style: GoogleFonts.spaceGrotesk(
                            color: context.appTextMuted, fontSize: 11)),
                    if (r.createdByName != null) ...[
                      Text('  ·  ',
                          style: GoogleFonts.spaceGrotesk(
                              color: context.appTextMuted, fontSize: 11)),
                      Text(r.createdByName!,
                          style: GoogleFonts.spaceGrotesk(
                              color: context.appTextMuted, fontSize: 11)),
                    ],
                    if (r.createdAt != null) ...[
                      Text('  ·  ',
                          style: GoogleFonts.spaceGrotesk(
                              color: context.appTextMuted, fontSize: 11)),
                      Text(_fmtDate(r.createdAt),
                          style: GoogleFonts.spaceGrotesk(
                              color: context.appTextMuted, fontSize: 11)),
                    ],
                  ]),
                ]),
              ),
              const SizedBox(width: 8),
              _badge(_priorityLabel(r.priority), _priorityColor(r.priority)),
              const SizedBox(width: 6),
              _badge(_statusLabel(r.status), _statusColor(r.status)),
            ]),
          ),

          // ── Expanded ───────────────────────────────────────────────────────
          if (expanded) ...[
            Divider(height: 1, color: context.appBorder),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start, children: [
                if (r.description?.isNotEmpty ?? false) ...[
                  Text(r.description!,
                      style: GoogleFonts.spaceGrotesk(
                          color: context.appTextSecondary, fontSize: 13)),
                  const SizedBox(height: 10),
                ],
                if (r.quantity?.isNotEmpty ?? false)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Row(children: [
                      Icon(Icons.inventory_2_outlined,
                          size: 13, color: context.appTextMuted),
                      const SizedBox(width: 4),
                      Text('Qty: ${r.quantity}',
                          style: GoogleFonts.spaceGrotesk(
                              color: context.appTextSecondary, fontSize: 12)),
                    ]),
                  ),
                if (r.status != 'pending' && r.closedByName != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Row(children: [
                      Icon(Icons.check_circle_outline,
                          size: 13,
                          color: _statusColor(r.status).withValues(alpha: 0.8)),
                      const SizedBox(width: 4),
                      Text(
                        '${_statusLabel(r.status)} by ${r.closedByName}',
                        style: GoogleFonts.spaceGrotesk(
                            color: _statusColor(r.status), fontSize: 11),
                      ),
                    ]),
                  ),
                if (r.notes?.isNotEmpty ?? false)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Text(r.notes!,
                        style: GoogleFonts.spaceGrotesk(
                            color: context.appTextSecondary,
                            fontSize: 12,
                            fontStyle: FontStyle.italic)),
                  ),

                // Action buttons
                const SizedBox(height: 4),
                Wrap(spacing: 8, runSpacing: 6, children: [
                  if (canEdit)
                    _actionBtn(
                      label: 'Edit',
                      icon: Icons.edit_outlined,
                      color: context.appTextSecondary,
                      onPressed: () => _showRequestDialog(r),
                    ),
                  if (_canClose && r.status == 'pending') ...[
                    _actionBtn(
                      label: 'Conclude',
                      icon: Icons.check_circle_outline,
                      color: AppDS.green,
                      onPressed: () => _showCloseDialog(r, 'concluded'),
                    ),
                    _actionBtn(
                      label: 'Refuse',
                      icon: Icons.cancel_outlined,
                      color: AppDS.red,
                      onPressed: () => _showCloseDialog(r, 'refused'),
                    ),
                  ],
                  if (_canClose && r.status != 'pending')
                    _actionBtn(
                      label: 'Reopen',
                      icon: Icons.refresh_rounded,
                      color: AppDS.yellow,
                      onPressed: () => _reopen(r),
                    ),
                  if (canEdit)
                    _actionBtn(
                      label: 'Delete',
                      icon: Icons.delete_outline,
                      color: AppDS.red,
                      onPressed: () => _delete(r),
                    ),
                ]),
              ]),
            ),
          ],
        ]),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Standalone quick-request entry point — callable from any page
// ─────────────────────────────────────────────────────────────────────────────

/// Shows the New Request dialog pre-filled with [type] and [prefillTitle].
/// Resolves the current user id and inserts directly — no page reload needed.
Future<void> showQuickRequestDialog(
  BuildContext context, {
  required String type,
  String prefillTitle = '',
}) async {
  int? userId;
  try {
    final email = Supabase.instance.client.auth.currentSession?.user.email ?? '';
    final rows = await Supabase.instance.client
        .from('users').select('user_id').eq('user_email', email).limit(1);
    if (rows.isNotEmpty) userId = rows[0]['user_id'] as int?;
  } catch (_) {}
  if (!context.mounted) return;

  final titleCtrl     = TextEditingController(text: prefillTitle);
  final descCtrl      = TextEditingController();
  final qtyCtrl       = TextEditingController();
  String selectedType = _kTypes.contains(type) ? type : 'other';
  String priority     = 'normal';
  final formKey       = GlobalKey<FormState>();

  showDialog(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setDlg) => AlertDialog(
        backgroundColor: ctx.appSurface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Text('New Request',
            style: GoogleFonts.spaceGrotesk(
                color: ctx.appTextPrimary, fontWeight: FontWeight.w700)),
        content: SizedBox(
          width: 440,
          child: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Type',
                      style: GoogleFonts.spaceGrotesk(
                          fontSize: 11, color: ctx.appTextSecondary,
                          fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6, runSpacing: 6,
                    children: _kTypes.map((t) {
                      final sel = t == selectedType;
                      return GestureDetector(
                        onTap: () => setDlg(() => selectedType = t),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: sel ? _typeColor(t).withValues(alpha: 0.15) : ctx.appSurface2,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: sel ? _typeColor(t) : ctx.appBorder),
                          ),
                          child: Row(mainAxisSize: MainAxisSize.min, children: [
                            Icon(_typeIcon(t), size: 13,
                                color: sel ? _typeColor(t) : ctx.appTextMuted),
                            const SizedBox(width: 4),
                            Text(_typeLabel(t),
                                style: GoogleFonts.spaceGrotesk(
                                    fontSize: 11,
                                    color: sel ? _typeColor(t) : ctx.appTextSecondary)),
                          ]),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 16),
                  Text('Priority',
                      style: GoogleFonts.spaceGrotesk(
                          fontSize: 11, color: ctx.appTextSecondary,
                          fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  Row(
                    children: _kPriorities.map((p) {
                      final sel = p == priority;
                      return Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: GestureDetector(
                          onTap: () => setDlg(() => priority = p),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                            decoration: BoxDecoration(
                              color: sel ? _priorityColor(p).withValues(alpha: 0.15) : ctx.appSurface2,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: sel ? _priorityColor(p) : ctx.appBorder),
                            ),
                            child: Text(_priorityLabel(p),
                                style: GoogleFonts.spaceGrotesk(
                                    fontSize: 11, fontWeight: FontWeight.w600,
                                    color: sel ? _priorityColor(p) : ctx.appTextSecondary)),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: titleCtrl,
                    style: GoogleFonts.spaceGrotesk(color: ctx.appTextPrimary, fontSize: 13),
                    decoration: _inputDecFn(ctx, 'Title *'),
                    validator: (v) => (v?.trim().isEmpty ?? true) ? 'Required' : null,
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: descCtrl,
                    maxLines: 3,
                    style: GoogleFonts.spaceGrotesk(color: ctx.appTextPrimary, fontSize: 13),
                    decoration: _inputDecFn(ctx, 'Description (optional)'),
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: qtyCtrl,
                    style: GoogleFonts.spaceGrotesk(color: ctx.appTextPrimary, fontSize: 13),
                    decoration: _inputDecFn(ctx, 'Quantity (optional)'),
                  ),
                ],
              ),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel',
                style: GoogleFonts.spaceGrotesk(color: ctx.appTextSecondary)),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: _kAccent),
            onPressed: () async {
              if (!formKey.currentState!.validate()) return;
              Navigator.pop(ctx);
              try {
                await Supabase.instance.client.from('requests').insert({
                  'request_type':        selectedType,
                  'request_priority':    priority,
                  'request_title':       titleCtrl.text.trim(),
                  'request_description': descCtrl.text.trim().isEmpty ? null : descCtrl.text.trim(),
                  'request_quantity':    qtyCtrl.text.trim().isEmpty  ? null : qtyCtrl.text.trim(),
                  'request_created_by':  userId,
                  'request_updated_at':  DateTime.now().toIso8601String(),
                });
              } catch (_) {}
            },
            child: Text('Submit', style: GoogleFonts.spaceGrotesk(color: Colors.white)),
          ),
        ],
      ),
    ),
  );
}

InputDecoration _inputDecFn(BuildContext ctx, String hint) => InputDecoration(
  hintText: hint,
  hintStyle: GoogleFonts.spaceGrotesk(color: ctx.appTextMuted, fontSize: 12),
  filled: true,
  fillColor: ctx.appSurface2,
  border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: BorderSide(color: ctx.appBorder)),
  enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: BorderSide(color: ctx.appBorder)),
  focusedBorder: const OutlineInputBorder(
      borderRadius: BorderRadius.all(Radius.circular(8)),
      borderSide: BorderSide(color: _kAccent)),
  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
  isDense: true,
);
