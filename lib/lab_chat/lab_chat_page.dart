// lab_chat_page.dart - Multi-channel lab chat with 8 channels grouped by module,
// real-time Supabase subscription, unread badge tracking, reply threading.
// Widget classes extracted to lab_chat_widgets.dart (part).

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:blue_open_lims/lab_chat/lab_message.dart';
import '/theme/theme.dart';

part 'lab_chat_widgets.dart';

// ─── CHANNEL DEFINITIONS ─────────────────────────────────────────────────────
class _Channel {
  final String id;
  final String label;
  final IconData icon;
  final Color color;
  const _Channel(this.id, this.label, this.icon, this.color);
}

const _channels = [
  _Channel('general',       'General',       Icons.chat_bubble_outline,              Color(0xFF00C8F0)),
  _Channel('announcements', 'Announcements', Icons.campaign_outlined,                Color(0xFFFFD60A)),
  _Channel('fish',          'Fish',          Icons.water,                            Color(0xFF00D98A)),
  _Channel('strains',       'Strains',       Icons.biotech,                          Color(0xFF9B72CF)),
  _Channel('samples',       'Samples',       Icons.science_outlined,                 Color(0xFFFF8C42)),
  _Channel('reagents',      'Reagents',      Icons.colorize_outlined,                Color(0xFFFF4D6D)),
  _Channel('equipment',     'Equipment',     Icons.precision_manufacturing_outlined,  Color(0xFF7A9CBF)),
  _Channel('reservations',  'Reservations',  Icons.event_outlined,                   Color(0xFFEC4899)),
];

// Sidebar grouping: (group header label or null, channel ids)
const _channelGroups = <(String?, List<String>)>[
  (null,                 ['general', 'announcements']),
  ('Fish Facility',      ['fish']),
  ('Culture Collection', ['strains', 'samples']),
  ('Resources',          ['reagents', 'equipment', 'reservations']),
];

// ─── Font helpers ─────────────────────────────────────────────────────────────
TextStyle _mono({double size = 12, Color? color, FontWeight? weight}) =>
    GoogleFonts.jetBrainsMono(fontSize: size, color: color ?? AppDS.textPrimary, fontWeight: weight);

TextStyle _body({double size = 13, Color? color, FontWeight? weight}) =>
    GoogleFonts.dmSans(fontSize: size, color: color, fontWeight: weight);

// ─── PAGE ─────────────────────────────────────────────────────────────────────
class LabChatPage extends StatefulWidget {
  const LabChatPage({super.key});

  /// Total unread message count across all channels. MenuPage listens to this.
  static final unreadNotifier = ValueNotifier<int>(0);

  // ── Background unread tracker (always-on, independent of page being open) ──

  static RealtimeChannel? _bgSub;
  static final Map<String, int> _bgCounts   = {for (final c in _channels) c.id: 0};
  static final Map<String, int> _bgLastSeen = {};
  static String? _activeChannel;

  /// Start the always-on background listener. Call once from MenuPage.initState.
  static Future<void> startBackgroundListener() async {
    if (_bgSub != null) return;

    final prefs  = await SharedPreferences.getInstance();
    final client = Supabase.instance.client;

    for (final ch in _channels) {
      _bgLastSeen[ch.id] = prefs.getInt('lab_chat_seen_${ch.id}') ?? 0;
    }

    // Subscribe first so no inserts are missed during the initial count fetch.
    _bgSub = client
        .channel('lab_chat_background')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'messages',
          callback: (payload) async {
            final row = payload.newRecord;
            final ch  = row['message_channel']?.toString();
            if (ch == null || row['message_deleted'] == true) return;
            _bgCounts[ch] = (_bgCounts[ch] ?? 0) + 1;
            if (ch == _activeChannel) {
              _bgLastSeen[ch] = _bgCounts[ch]!;
              final p = await SharedPreferences.getInstance();
              await p.setInt('lab_chat_seen_$ch', _bgLastSeen[ch]!);
            }
            _recomputeBgUnread();
          },
        )
        .subscribe();

    // Fetch initial counts (take max in case realtime already fired).
    for (final ch in _channels) {
      try {
        final rows = await client
            .from('messages')
            .select('message_id')
            .eq('message_channel', ch.id)
            .eq('message_deleted', false) as List<dynamic>;
        if (rows.length > (_bgCounts[ch.id] ?? 0)) {
          _bgCounts[ch.id] = rows.length;
        }
      } catch (_) {}
    }
    _recomputeBgUnread();
  }

  static void _recomputeBgUnread() {
    int total = 0;
    for (final ch in _channels) {
      final seen    = _bgLastSeen[ch.id] ?? 0;
      final current = _bgCounts[ch.id] ?? 0;
      total += (current - seen).clamp(0, current);
    }
    unreadNotifier.value = total;
  }

  /// Update which channel is actively being viewed (null = chat page closed).
  /// Automatically marks that channel as read.
  static void setActiveChannel(String? channelId) {
    _activeChannel = channelId;
    if (channelId == null) return;
    final count = _bgCounts[channelId] ?? 0;
    if ((_bgLastSeen[channelId] ?? 0) >= count) return;
    _bgLastSeen[channelId] = count;
    _recomputeBgUnread();
    SharedPreferences.getInstance()
        .then((p) => p.setInt('lab_chat_seen_$channelId', count));
  }

  @override
  State<LabChatPage> createState() => _LabChatPageState();
}

class _LabChatPageState extends State<LabChatPage> {
  final _supabase = Supabase.instance.client;

  final _msgCtrl    = TextEditingController();
  final _editCtrl   = TextEditingController();
  final _scrollCtrl = ScrollController();
  final _focusNode  = FocusNode();

  String _channel          = 'general';
  bool   _sidebarCollapsed  = false;
  bool   _showPinnedOnly    = false;
  String _search            = '';
  bool   _messagesLoaded    = false;

  LabMessage? _replyingTo;
  int?        _editingId;

  // Top-level messages for the current channel
  List<LabMessage> _messages = [];
  // Replies keyed by parent message_id
  Map<int, List<LabMessage>> _repliesByParent = {};

  // Per-channel message counts shown in sidebar
  final Map<String, int> _msgCount = {for (final c in _channels) c.id: 0};
  // Per-channel last-seen counts (persisted in SharedPreferences)
  final Map<String, int> _lastSeenCounts = {for (final c in _channels) c.id: 0};

  RealtimeChannel? _realtimeSub;
  final Map<String, Map<String, dynamic>> _usersByAuthUid = {};
  Map<String, dynamic>? _currentUser;

  // ── Lifecycle ─────────────────────────────────────────────────────────────
  @override
  void initState() {
    super.initState();
    _loadSidebarPref();
    _loadLastSeenCounts();
    _resolveCurrentUser();
    _loadAndSubscribe(_channel);
    _loadAllCounts();
    // Defer until after the first frame — setActiveChannel → _recomputeBgUnread
    // → unreadNotifier.value fires synchronously, which would hit "setState during
    // build" because initState() is called while the parent is still building.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) LabChatPage.setActiveChannel(_channel);
    });
  }

  Future<void> _loadSidebarPref() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() => _sidebarCollapsed = prefs.getBool('lab_chat_sidebar_collapsed') ?? false);
    }
  }

  Future<void> _saveSidebarPref(bool collapsed) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('lab_chat_sidebar_collapsed', collapsed);
  }

  Future<void> _loadLastSeenCounts() async {
    final prefs = await SharedPreferences.getInstance();
    for (final ch in _channels) {
      _lastSeenCounts[ch.id] = prefs.getInt('lab_chat_seen_${ch.id}') ?? 0;
    }
    _recomputeUnread();
  }

  Future<void> _markChannelRead(String channelId) async {
    final count = _msgCount[channelId] ?? 0;
    if ((_lastSeenCounts[channelId] ?? 0) == count) return;
    _lastSeenCounts[channelId] = count;
    _recomputeUnread();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('lab_chat_seen_$channelId', count);
  }

  void _recomputeUnread() {
    int total = 0;
    for (final ch in _channels) {
      final seen    = _lastSeenCounts[ch.id] ?? 0;
      final current = _msgCount[ch.id] ?? 0;
      total += (current - seen).clamp(0, current);
    }
    LabChatPage.unreadNotifier.value = total;
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    LabChatPage.setActiveChannel(null);
    _realtimeSub?.unsubscribe();
    _msgCtrl.dispose();
    _editCtrl.dispose();
    _scrollCtrl.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  // ── Data loading & realtime ───────────────────────────────────────────────

  Future<void> _resolveCurrentUser() async {
    final authUser = _supabase.auth.currentUser;
    if (authUser == null) return;

    try {
      Map<String, dynamic>? row = await _supabase
          .from('users')
          .select('user_id, user_name, user_email, user_auth_uid, user_phone, user_institution, user_group')
          .eq('user_auth_uid', authUser.id)
          .maybeSingle();

      // Backfill legacy rows that were created before user_auth_uid was saved.
      if (row == null && authUser.email != null) {
        row = await _supabase
            .from('users')
            .select('user_id, user_name, user_email, user_auth_uid, user_phone, user_institution, user_group')
            .eq('user_email', authUser.email!)
            .maybeSingle();
        if (row != null) {
          await _supabase
              .from('users')
              .update({'user_auth_uid': authUser.id})
              .eq('user_id', row['user_id']);
          row = {
            ...row,
            'user_auth_uid': authUser.id,
          };
        }
      }

      if (row != null) {
        final uid = row['user_auth_uid']?.toString();
        if (uid != null && uid.isNotEmpty) {
          _usersByAuthUid[uid] = row;
        }
        if (mounted) setState(() => _currentUser = row);
      }
    } catch (_) {}
  }

  Future<void> _ensureUsersCachedForAuthUids(Iterable<String?> authUids) async {
    final missing = authUids
        .whereType<String>()
        .where((uid) => uid.isNotEmpty && !_usersByAuthUid.containsKey(uid))
        .toSet()
        .toList();
    if (missing.isEmpty) return;

    try {
      final rows = await _supabase
          .from('users')
          .select('user_id, user_name, user_email, user_auth_uid, user_phone, user_institution, user_group')
          .inFilter('user_auth_uid', missing) as List<dynamic>;

      for (final raw in rows) {
        final row = raw as Map<String, dynamic>;
        final uid = row['user_auth_uid']?.toString();
        if (uid != null && uid.isNotEmpty) {
          _usersByAuthUid[uid] = row;
        }
      }
    } catch (_) {}
  }

  LabMessage _messageFromRowWithUser(Map<String, dynamic> row) {
    final uid = row['message_user_uid']?.toString();
    final user = uid != null ? _usersByAuthUid[uid] : null;
    return LabMessage.fromJson({
      ...row,
      if (user != null) ...{
        'user_id': user['user_id'],
        'user_name': user['user_name'] ?? user['user_email'],
      },
    });
  }

  /// Fetch existing messages for [channelId] and subscribe to realtime changes.
  void _loadAndSubscribe(String channelId) {
    // Cancel previous subscription first
    _realtimeSub?.unsubscribe();
    setState(() {
      _messages = [];
      _repliesByParent = {};
      _messagesLoaded = false;
    });

    _fetchMessages(channelId);

    // Listen for INSERT and UPDATE events on the messages table.
    // We filter in-app because postgres_changes filter on columns other than
    // eq(primary key) requires a paid Supabase plan.
    _realtimeSub = _supabase
        .channel('lab_chat_$channelId')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'messages',
          callback: (payload) async {
            final row = payload.newRecord;
            // Only handle messages for the current channel
            if (row['message_channel'] != channelId) return;
            if (row['message_deleted'] == true) return;

            await _ensureUsersCachedForAuthUids(
              [row['message_user_uid']?.toString()],
            );
            final msg = _messageFromRowWithUser(row);
            if (!mounted) return;
            setState(() {
              if (msg.parentId == null) {
                // Top-level: append if not already present
                if (!_messages.any((m) => m.id == msg.id)) {
                  _messages.add(msg);
                  _msgCount[channelId] = (_msgCount[channelId] ?? 0) + 1;
                }
              } else {
                // Reply: add under parent
                final list = List<LabMessage>.from(
                    _repliesByParent[msg.parentId!] ?? []);
                if (!list.any((m) => m.id == msg.id)) {
                  list.add(msg);
                  _repliesByParent = {
                    ..._repliesByParent,
                    msg.parentId!: list,
                  };
                }
              }
            });
            _scrollToBottom();
            // User is watching this channel — keep it marked as read
            _markChannelRead(channelId);
          },
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'messages',
          callback: (payload) async {
            final row = payload.newRecord;
            if (row['message_channel'] != channelId) return;
            await _ensureUsersCachedForAuthUids(
              [row['message_user_uid']?.toString()],
            );
            final updated = _messageFromRowWithUser(row);
            if (!mounted) return;
            setState(() => _applyUpdate(updated));
          },
        )
        .subscribe();
  }

  Future<void> _fetchMessages(String channelId) async {
    try {
      final rows = (await _supabase
          .from('messages')
          .select()
          .eq('message_channel', channelId)
          .eq('message_deleted', false)
          .order('message_created_at', ascending: true) as List<dynamic>)
          .cast<Map<String, dynamic>>();

      await _ensureUsersCachedForAuthUids(
        rows.map((r) => r['message_user_uid']?.toString()),
      );

      final all = rows
          .map(_messageFromRowWithUser)
          .toList();

      final topLevel = all.where((m) => m.parentId == null).toList();
      final byParent = <int, List<LabMessage>>{};
      for (final r in all.where((m) => m.parentId != null)) {
        byParent.putIfAbsent(r.parentId!, () => []).add(r);
      }

      if (mounted) {
        setState(() {
          _messages = topLevel;
          _repliesByParent = byParent;
          _messagesLoaded = true;
        });
        _scrollToBottom();
        _markChannelRead(channelId);
      }
    } catch (e) {
      if (mounted) setState(() => _messagesLoaded = true);
      _showSnack('Failed to load messages: $e', isError: true);
    }
  }

  Future<void> _loadAllCounts() async {
    for (final ch in _channels) {
      try {
        final resp = await _supabase
            .from('messages')
            .select('message_id')
            .eq('message_channel', ch.id)
            .eq('message_deleted', false) as List<dynamic>;
        if (mounted) setState(() => _msgCount[ch.id] = resp.length);
        // Keep bg counts in sync (take the larger of the two).
        if (resp.length > (LabChatPage._bgCounts[ch.id] ?? 0)) {
          LabChatPage._bgCounts[ch.id] = resp.length;
        }
      } catch (_) {}
    }
    _recomputeUnread();
    LabChatPage._recomputeBgUnread();
  }

  void _applyUpdate(LabMessage updated) {
    // Check top-level list
    final idx = _messages.indexWhere((m) => m.id == updated.id);
    if (idx >= 0) {
      // Soft-deleted → remove from list
      if (updated.deleted) {
        _messages.removeAt(idx);
      } else {
        _messages[idx] = updated;
      }
      return;
    }
    // Check replies
    if (updated.parentId != null) {
      final replies = List<LabMessage>.from(
          _repliesByParent[updated.parentId!] ?? []);
      final ri = replies.indexWhere((r) => r.id == updated.id);
      if (ri >= 0) {
        if (updated.deleted) {
          replies.removeAt(ri);
        } else {
          replies[ri] = updated;
        }
        _repliesByParent = {..._repliesByParent, updated.parentId!: replies};
      }
    }
  }

  // ── CRUD actions ──────────────────────────────────────────────────────────

  Future<void> _send() async {
    final text = _msgCtrl.text.trim();
    if (text.isEmpty) return;

    final replyTo = _replyingTo;
    setState(() {
      _replyingTo = null;
      _msgCtrl.clear();
    });

    try {
      await _resolveCurrentUser();
      final authUid = _supabase.auth.currentUser?.id;
      final senderUid = _currentUser?['user_auth_uid']?.toString() ?? authUid;

      // Use .select() to get the inserted row back immediately —
      // don't rely solely on the realtime callback, which can lag or be missed.
      final inserted = await _supabase.from('messages').insert({
        'message_body'     : text,
        'message_channel'  : _channel,
        if (replyTo != null)
        'message_parent_id': replyTo.id,
        'message_user_uid' : senderUid,
      }).select().single();

      final msg = _messageFromRowWithUser({
        ...inserted,
        if (_currentUser != null) ...{
          'user_id'  : _currentUser!['user_id'],
          'user_name': _currentUser!['user_name'] ?? _currentUser!['user_email'],
        },
      });

      if (!mounted) return;
      setState(() {
        if (msg.parentId == null) {
          if (!_messages.any((m) => m.id == msg.id)) {
            _messages.add(msg);
            _msgCount[_channel] = (_msgCount[_channel] ?? 0) + 1;
          }
        } else {
          final list = List<LabMessage>.from(
              _repliesByParent[msg.parentId!] ?? []);
          if (!list.any((m) => m.id == msg.id)) {
            list.add(msg);
            _repliesByParent = {..._repliesByParent, msg.parentId!: list};
          }
        }
      });
      _scrollToBottom();
    } catch (e) {
      _showSnack('Send failed: $e', isError: true);
      setState(() {
        _replyingTo = replyTo;
        _msgCtrl.text = text;
      });
    }
  }

  Future<void> _saveEdit(LabMessage msg) async {
    final text = _editCtrl.text.trim();
    setState(() => _editingId = null);
    if (text.isEmpty || text == msg.body) return;
    try {
      await _supabase.from('messages').update({
        'message_body'      : text,
        'message_edited'    : true,
        'message_edited_at' : DateTime.now().toIso8601String(),
      }).eq('message_id', msg.id);
      // Realtime UPDATE callback refreshes the row
    } catch (e) {
      _showSnack('Edit failed: $e', isError: true);
    }
  }

  Future<void> _togglePin(LabMessage msg) async {
    try {
      await _supabase.from('messages')
          .update({'message_pinned': !msg.pinned})
          .eq('message_id', msg.id);
    } catch (e) {
      _showSnack('Pin failed: $e', isError: true);
    }
  }

  Future<void> _softDelete(LabMessage msg) async {
    // Optimistic removal for instant feedback
    setState(() {
      _messages.removeWhere((m) => m.id == msg.id);
      if (msg.parentId != null) {
        final r = List<LabMessage>.from(
            _repliesByParent[msg.parentId!] ?? []);
        r.removeWhere((m) => m.id == msg.id);
        _repliesByParent = {..._repliesByParent, msg.parentId!: r};
      }
    });
    try {
      await _supabase.from('messages')
          .update({'message_deleted': true})
          .eq('message_id', msg.id);
    } catch (e) {
      _showSnack('Delete failed: $e', isError: true);
      _fetchMessages(_channel); // restore on failure
    }
  }

  void _switchChannel(String channelId) {
    if (_channel == channelId) return;
    setState(() {
      _channel         = channelId;
      _replyingTo      = null;
      _editingId       = null;
      _showPinnedOnly  = false;
      _search          = '';
    });
    _loadAndSubscribe(channelId);
    _markChannelRead(channelId);
    LabChatPage.setActiveChannel(channelId);
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 280),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _showSnack(String msg, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: _body(size: 12)),
      backgroundColor: isError ? AppDS.red.withValues(alpha: 0.9) : null,
    ));
  }

  // ── Derived lists ─────────────────────────────────────────────────────────

  List<LabMessage> get _visibleMessages {
    var msgs = _messages.where((m) => !m.deleted).toList();
    if (_showPinnedOnly) msgs = msgs.where((m) => m.pinned).toList();
    if (_search.isNotEmpty) {
      final q = _search.toLowerCase();
      msgs = msgs.where((m) => m.body.toLowerCase().contains(q)).toList();
    }
    return msgs;
  }

  int get _pinnedCount =>
      _messages.where((m) => m.pinned && !m.deleted).length;

  _Channel get _currentChannel =>
      _channels.firstWhere((c) => c.id == _channel);

  // ── Build ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.appBg,
      body: Row(
        children: [
          // ── LEFT: chat area ──────────────────────────────────────────────
          Expanded(
            child: Column(
              children: [
                _buildChatHeader(),
                if (_showPinnedOnly || _search.isNotEmpty) _buildFilterBar(),
                Expanded(child: _buildMessageList()),
                if (_replyingTo != null) _buildReplyBanner(),
                _buildComposer(),
              ],
            ),
          ),
          // ── DIVIDER ──────────────────────────────────────────────────────
          Container(width: 1, color: context.appBorder),
          // ── RIGHT: channel menu ──────────────────────────────────────────
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeInOut,
            width: _sidebarCollapsed ? 52 : 216,
            color: context.appSurface,
            child: Column(
              children: [
                _buildSidebarHeader(),
                Expanded(child: _buildChannelList()),
                _buildSidebarFooter(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Chat header ───────────────────────────────────────────────────────────
  Widget _buildChatHeader() {
    final ch = _currentChannel;
    return Container(
      height: 56,
      padding: const EdgeInsets.symmetric(horizontal: 18),
      decoration: BoxDecoration(
        color: context.appSurface,
        border: Border(bottom: BorderSide(color: context.appBorder)),
      ),
      child: Row(children: [
        Icon(ch.icon, size: 16, color: ch.color),
        const SizedBox(width: 10),
        Text(ch.label, style: _body(size: 15, weight: FontWeight.w700)),
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 12),
          width: 1, height: 16, color: context.appBorder2),
        Text(
          '${_messages.where((m) => !m.deleted).length} messages',
          style: _mono(size: 10, color: context.appTextMuted)),
        const SizedBox(width: 16),
        // Inline search
        SizedBox(
          width: 200, height: 32,
          child: TextField(
            onChanged: (v) => setState(() => _search = v),
            style: _body(size: 12),
            decoration: InputDecoration(
              hintText: 'Search…',
              hintStyle: _body(size: 12, color: context.appTextMuted),
              prefixIcon: Icon(Icons.search, size: 14, color: context.appTextMuted),
              filled: true, fillColor: context.appSurface2,
              border: _ob(context), enabledBorder: _ob(context),
              focusedBorder: _ob(context, color: AppDS.accent, w: 1.5),
              contentPadding: EdgeInsets.zero, isDense: true,
            ),
          ),
        ),
        const Spacer(),
        if (_pinnedCount > 0) ...[
          _chip(Icons.push_pin, '$_pinnedCount pinned', AppDS.yellow,
            () => setState(() => _showPinnedOnly = !_showPinnedOnly),
            active: _showPinnedOnly),
          const SizedBox(width: 8),
        ],
      ]),
    );
  }

  Widget _buildFilterBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      color: AppDS.yellow.withValues(alpha: 0.05),
      child: Row(children: [
        const Icon(Icons.filter_list, size: 12, color: AppDS.yellow),
        const SizedBox(width: 6),
        Text(
          _showPinnedOnly ? 'Showing pinned messages only'
              : 'Search: "$_search"',
          style: _body(size: 11, color: AppDS.yellow)),
        const Spacer(),
        GestureDetector(
          onTap: () => setState(() { _showPinnedOnly = false; _search = ''; }),
          child: const Icon(Icons.close, size: 13, color: AppDS.yellow)),
      ]),
    );
  }

  // ── Message list ──────────────────────────────────────────────────────────
  Widget _buildMessageList() {
    if (!_messagesLoaded) {
      return Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const SizedBox(
            width: 22, height: 22,
            child: CircularProgressIndicator(strokeWidth: 2, color: AppDS.accent)),
          const SizedBox(height: 14),
          Text('Loading #${_currentChannel.label}…',
            style: _body(size: 12, color: context.appTextMuted)),
        ]),
      );
    }

    final msgs = _visibleMessages;
    if (msgs.isEmpty) {
      return Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(_currentChannel.icon, size: 48,
            color: context.appTextMuted.withValues(alpha: 0.2)),
          const SizedBox(height: 14),
          Text('No messages yet in #${_currentChannel.label}',
            style: _body(size: 14, color: context.appTextMuted)),
          const SizedBox(height: 6),
          Text('Be the first to say something!',
            style: _body(size: 12, color: context.appTextMuted.withValues(alpha: 0.6))),
        ]),
      );
    }

    return ListView.builder(
      controller: _scrollCtrl,
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 6),
      itemCount: msgs.length,
      itemBuilder: (ctx, i) {
        final msg  = msgs[i];
        final prev = i > 0 ? msgs[i - 1] : null;
        // Compact (no avatar) when same user posts within 5 minutes
        final compact = prev != null &&
            prev.senderKey == msg.senderKey &&
            msg.createdAt.difference(prev.createdAt).inMinutes < 5;
        final currentAuthUid = _supabase.auth.currentUser?.id;
        final currentRole = _currentUser?['user_role'] as String?;
        final isAdmin = currentRole == 'admin' || currentRole == 'superadmin';
        final canEditDelete = isAdmin ||
            (currentAuthUid != null && msg.userAuthUid == currentAuthUid);
        return _MessageBubble(
          key: ValueKey(msg.id),
          message: msg,
          replies: _repliesByParent[msg.id] ?? [],
          compact: compact,
          channelColor: _currentChannel.color,
          isEditing: _editingId == msg.id,
          editCtrl: _editCtrl,
          canEditDelete: canEditDelete,
          onReply: (m) {
            setState(() => _replyingTo = m);
            _focusNode.requestFocus();
          },
          onEdit: (m) => setState(() {
            _editingId = m.id;
            _editCtrl.text = m.body;
          }),
          onSaveEdit: _saveEdit,
          onCancelEdit: () => setState(() => _editingId = null),
          onPin: _togglePin,
          onDelete: _softDelete,
          onCopy: (m) => Clipboard.setData(ClipboardData(text: m.body)),
          onAvatarTap: () {
            final user = msg.userAuthUid != null
                ? _usersByAuthUid[msg.userAuthUid]
                : null;
            _showUserInfoDialog(msg.displayName, user);
          },
        );
      },
    );
  }

  // ── Reply banner ──────────────────────────────────────────────────────────
  Widget _buildReplyBanner() {
    final msg = _replyingTo!;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: context.appSurface2,
        border: Border(
          top: BorderSide(color: context.appBorder),
          left: const BorderSide(color: AppDS.accent, width: 3)),
      ),
      child: Row(children: [
        const Icon(Icons.reply, size: 14, color: AppDS.accent),
        const SizedBox(width: 8),
        Expanded(
          child: RichText(text: TextSpan(children: [
            TextSpan(text: 'Replying to ${msg.displayName}   ',
              style: _body(size: 11, color: AppDS.accent, weight: FontWeight.w600)),
            TextSpan(
              text: msg.body.length > 70
                  ? '${msg.body.substring(0, 70)}…' : msg.body,
              style: _body(size: 11, color: context.appTextSecondary)),
          ])),
        ),
        GestureDetector(
          onTap: () => setState(() => _replyingTo = null),
          child: Icon(Icons.close, size: 14, color: context.appTextMuted)),
      ]),
    );
  }

  // ── Composer ──────────────────────────────────────────────────────────────
  Widget _buildComposer() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
      decoration: BoxDecoration(
        color: context.appSurface,
        border: Border(top: BorderSide(color: context.appBorder)),
      ),
      child: CallbackShortcuts(
        bindings: {
          const SingleActivator(LogicalKeyboardKey.enter): _send,
        },
        child: Focus(
          child: TextField(
            controller: _msgCtrl,
            focusNode: _focusNode,
            maxLines: null, minLines: 1,
            style: _body(size: 13),
            textInputAction: TextInputAction.newline,
            decoration: InputDecoration(
              hintText: 'Message #${_currentChannel.label}'
                  '${_replyingTo != null ? '  (replying)' : ''}'
                  '  ·  Enter to send',
              hintStyle: _body(size: 12, color: context.appTextMuted),
              filled: true, fillColor: context.appSurface2,
              border: _ob(context, r: 10), enabledBorder: _ob(context, r: 10),
              focusedBorder: _ob(context, r: 10, color: AppDS.accent, w: 1.5),
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              isDense: true,
              suffixIcon: Padding(
                padding: const EdgeInsets.only(right: 4),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  _cBtn(Icons.tag, 'Attach context', _showContextPicker),
                  _cBtn(Icons.send_rounded, 'Send (Enter)', _send,
                    color: AppDS.accent),
                ]),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _cBtn(IconData icon, String tip, VoidCallback onTap, {Color? color}) =>
      Tooltip(
        message: tip,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(6),
          child: Padding(
            padding: const EdgeInsets.all(7),
            child: Icon(icon, size: 17, color: color ?? context.appTextSecondary)),
        ),
      );

  // ── Right sidebar ─────────────────────────────────────────────────────────
  Widget _buildSidebarHeader() {
    return Container(
      height: 56,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: context.appBorder))),
      child: Row(children: [
        // Collapse button is always leftmost in the sidebar
        GestureDetector(
          onTap: () {
            setState(() => _sidebarCollapsed = !_sidebarCollapsed);
            _saveSidebarPref(_sidebarCollapsed);
          },
          child: Icon(
            _sidebarCollapsed ? Icons.chevron_left : Icons.chevron_right,
            size: 16, color: context.appTextMuted),
        ),
        if (!_sidebarCollapsed) ...[
          const SizedBox(width: 8),
          const Icon(Icons.forum_outlined, size: 14, color: AppDS.accent),
          const SizedBox(width: 7),
          Text('Channels',
            style: _mono(size: 11, color: AppDS.accent, weight: FontWeight.w700)),
        ],
      ]),
    );
  }

  Widget _buildChannelList() {
    final items = <Widget>[];
    for (final group in _channelGroups) {
      final header = group.$1;
      final ids    = group.$2;

      // Group header (hidden when collapsed)
      if (header != null && !_sidebarCollapsed) {
        items.add(Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 8, 4),
          child: Text(header.toUpperCase(),
            style: _mono(size: 9.5, color: context.appTextMuted,
              weight: FontWeight.w700)),
        ));
      } else if (header != null && _sidebarCollapsed) {
        // Thin divider between groups when collapsed
        items.add(Divider(height: 10, indent: 8, endIndent: 8,
          color: context.appBorder));
      }

      for (final id in ids) {
        final ch      = _channels.firstWhere((c) => c.id == id);
        final isActive = _channel == ch.id;
        final total    = _msgCount[ch.id] ?? 0;
        final seen     = _lastSeenCounts[ch.id] ?? 0;
        final unread   = isActive ? 0 : (total - seen).clamp(0, total);
        final hasUnread = unread > 0;
        items.add(Tooltip(
          message: _sidebarCollapsed ? ch.label : '',
          child: InkWell(
            onTap: () => _switchChannel(ch.id),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 120),
              margin: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: isActive
                    ? ch.color.withValues(alpha: 0.12)
                    : hasUnread
                        ? ch.color.withValues(alpha: 0.06)
                        : Colors.transparent,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: isActive
                      ? ch.color.withValues(alpha: 0.4)
                      : hasUnread
                          ? ch.color.withValues(alpha: 0.25)
                          : Colors.transparent)),
              child: Row(children: [
                Icon(ch.icon, size: 15,
                  color: isActive ? ch.color : hasUnread ? ch.color : context.appTextMuted),
                if (!_sidebarCollapsed) ...[
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(ch.label,
                      style: _body(size: 13,
                        color: isActive
                            ? context.appTextPrimary
                            : hasUnread
                                ? context.appTextPrimary
                                : context.appTextSecondary,
                        weight: (isActive || hasUnread) ? FontWeight.w600 : FontWeight.w400)),
                  ),
                  if (hasUnread)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                      decoration: BoxDecoration(
                        color: ch.color,
                        borderRadius: BorderRadius.circular(10)),
                      child: Text('$unread',
                        style: _mono(size: 9, color: Colors.white,
                          weight: FontWeight.w700)),
                    )
                  else if (isActive && total > 0)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                      decoration: BoxDecoration(
                        color: ch.color.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(10)),
                      child: Text('$total',
                        style: _mono(size: 9, color: ch.color)),
                    ),
                ],
              ]),
            ),
          ),
        ));
      }
    }
    return ListView(
      padding: const EdgeInsets.only(bottom: 8),
      children: items,
    );
  }

  Widget _buildSidebarFooter() {
    if (_sidebarCollapsed) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: context.appBorder))),
      child: Row(children: [
        Container(
          width: 8, height: 8,
          decoration: BoxDecoration(
            color: AppDS.green, shape: BoxShape.circle)),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            _currentUser?['user_name']?.toString() ?? '…',
            style: _body(size: 12, color: context.appTextPrimary, weight: FontWeight.w600),
            overflow: TextOverflow.ellipsis),
        ),
      ]),
    );
  }

  // ── Small helpers ─────────────────────────────────────────────────────────
  Widget _chip(IconData icon, String label, Color color,
      VoidCallback onTap, {bool active = false}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: active ? color.withValues(alpha: 0.15) : context.appSurface2,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: active ? color.withValues(alpha: 0.4) : context.appBorder)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 12, color: active ? color : context.appTextSecondary),
          const SizedBox(width: 5),
          Text(label,
            style: _body(size: 11,
              color: active ? color : context.appTextSecondary,
              weight: FontWeight.w600)),
        ]),
      ),
    );
  }

  /// Shorthand for OutlineInputBorder
  OutlineInputBorder _ob(BuildContext ctx, {
    double r = 8, Color? color, double w = 1.0}) =>
      OutlineInputBorder(
        borderRadius: BorderRadius.circular(r),
        borderSide: BorderSide(color: color ?? ctx.appBorder, width: w));

  void _showUserInfoDialog(String displayName, Map<String, dynamic>? user) {
    final aColors = const [
      Color(0xFF00C8F0), Color(0xFF00D98A),
      Color(0xFF9B72CF), Color(0xFFFF8C42),
    ];
    final aColor = aColors[displayName.hashCode.abs() % aColors.length];
    final email       = user?['user_email']?.toString();
    final phone       = user?['user_phone']?.toString();
    final institution = user?['user_institution']?.toString();
    final group       = user?['user_group']?.toString();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: context.appSurface2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: context.appBorder2)),
        titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
        title: Row(children: [
          Container(
            width: 40, height: 40,
            decoration: BoxDecoration(
              color: aColor.withValues(alpha: 0.15),
              shape: BoxShape.circle,
              border: Border.all(color: aColor.withValues(alpha: 0.35))),
            child: Center(
              child: Text(displayName.isNotEmpty ? displayName[0].toUpperCase() : '?',
                style: _mono(size: 16, color: aColor, weight: FontWeight.w700)),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(displayName,
              style: _body(size: 15, color: context.appTextPrimary, weight: FontWeight.w700)),
          ),
        ]),
        contentPadding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          if (email != null) _infoRow(Icons.email_outlined, email),
          if (phone != null) _infoRow(Icons.phone_outlined, phone),
          if (institution != null) _infoRow(Icons.business_outlined, institution),
          if (group != null) _infoRow(Icons.group_outlined, group),
          if (email == null && phone == null && institution == null && group == null)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text('No additional info available.',
                style: _body(size: 12, color: context.appTextMuted)),
            ),
        ]),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Close', style: _body(size: 13, color: context.appTextSecondary))),
        ],
      ),
    );
  }

  Widget _infoRow(IconData icon, String text) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 5),
    child: Row(children: [
      Icon(icon, size: 15, color: context.appTextMuted),
      const SizedBox(width: 10),
      Expanded(child: Text(text,
        style: _body(size: 13, color: context.appTextSecondary))),
    ]),
  );

  void _showContextPicker() {
    showDialog(
      context: context,
      builder: (_) => _ContextPickerDialog(
        onPick: (type, id, label) {
          final tag = '[${type.toUpperCase()}:$id $label]';
          final cur = _msgCtrl.text;
          _msgCtrl.text = cur.isEmpty ? '$tag ' : '$tag $cur';
          _focusNode.requestFocus();
        },
      ),
    );
  }
}

