import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:blue_open_lims/pages/lab_chat/lab_message.dart';
import '/theme/theme.dart';

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
];

// ─── Font helpers ─────────────────────────────────────────────────────────────
TextStyle _mono({double size = 12, Color? color, FontWeight? weight}) =>
    GoogleFonts.jetBrainsMono(fontSize: size, color: color ?? AppDS.textPrimary, fontWeight: weight);

TextStyle _body({double size = 13, Color? color, FontWeight? weight}) =>
    GoogleFonts.dmSans(fontSize: size, color: color ?? AppDS.textPrimary, fontWeight: weight);

// ─── PAGE ─────────────────────────────────────────────────────────────────────
class LabChatPage extends StatefulWidget {
  const LabChatPage({super.key});

  @override
  State<LabChatPage> createState() => _LabChatPageState();
}

class _LabChatPageState extends State<LabChatPage> {
  final _supabase = Supabase.instance.client;

  final _msgCtrl    = TextEditingController();
  final _editCtrl   = TextEditingController();
  final _scrollCtrl = ScrollController();
  final _focusNode  = FocusNode();

  String _channel         = 'general';
  bool   _sidebarCollapsed = false;
  bool   _showPinnedOnly   = false;
  String _search           = '';

  LabMessage? _replyingTo;
  int?        _editingId;

  // Top-level messages for the current channel
  List<LabMessage> _messages = [];
  // Replies keyed by parent message_id
  Map<int, List<LabMessage>> _repliesByParent = {};

  // Per-channel message counts shown in sidebar
  final Map<String, int> _msgCount = {for (final c in _channels) c.id: 0};

  RealtimeChannel? _realtimeSub;
  final Map<String, Map<String, dynamic>> _usersByAuthUid = {};
  Map<String, dynamic>? _currentUser;

  // ── Lifecycle ─────────────────────────────────────────────────────────────
  @override
  void initState() {
    super.initState();
    _resolveCurrentUser();
    _loadAndSubscribe(_channel);
    _loadAllCounts();
  }

  @override
  void dispose() {
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
          .select('user_id, user_name, user_email, user_auth_uid')
          .eq('user_auth_uid', authUser.id)
          .maybeSingle();

      // Backfill legacy rows that were created before user_auth_uid was saved.
      if (row == null && authUser.email != null) {
        row = await _supabase
            .from('users')
            .select('user_id, user_name, user_email, user_auth_uid')
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
        _currentUser = row;
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
          .select('user_id, user_name, user_email, user_auth_uid')
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
        });
        _scrollToBottom();
      }
    } catch (e) {
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
      } catch (_) {}
    }
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

      await _supabase.from('messages').insert({
        'message_body'    : text,
        'message_channel' : _channel,
        if (replyTo != null) 
        'message_parent_id': replyTo.id,
        'message_user_uid': senderUid,
      });
      // Realtime INSERT callback handles adding to _messages
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
      backgroundColor: isError ? AppDS.red.withValues(alpha: 0.9) : AppDS.surface2,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
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
      backgroundColor: AppDS.bg,
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
          Container(width: 1, color: AppDS.border),
          // ── RIGHT: channel menu ──────────────────────────────────────────
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeInOut,
            width: _sidebarCollapsed ? 52 : 216,
            color: AppDS.surface,
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
      decoration: const BoxDecoration(
        color: AppDS.surface,
        border: Border(bottom: BorderSide(color: AppDS.border)),
      ),
      child: Row(children: [
        Icon(ch.icon, size: 16, color: ch.color),
        const SizedBox(width: 10),
        Text(ch.label, style: _body(size: 15, weight: FontWeight.w700)),
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 12),
          width: 1, height: 16, color: AppDS.border2),
        Text(
          '${_messages.where((m) => !m.deleted).length} messages',
          style: _mono(size: 10, color: AppDS.textMuted)),
        const SizedBox(width: 16),
        // Inline search
        SizedBox(
          width: 200, height: 32,
          child: TextField(
            onChanged: (v) => setState(() => _search = v),
            style: _body(size: 12),
            decoration: InputDecoration(
              hintText: 'Search…',
              hintStyle: _body(size: 12, color: AppDS.textMuted),
              prefixIcon: const Icon(Icons.search, size: 14, color: AppDS.textMuted),
              filled: true, fillColor: AppDS.surface2,
              border: _ob(), enabledBorder: _ob(),
              focusedBorder: _ob(color: AppDS.accent, w: 1.5),
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
    // Show spinner while the first fetch is in progress (messages is empty
    // but we haven't received any data yet).
    if (_messages.isEmpty) {
      return Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const SizedBox(
            width: 22, height: 22,
            child: CircularProgressIndicator(strokeWidth: 2, color: AppDS.accent)),
          const SizedBox(height: 14),
          Text('Loading #${_currentChannel.label}…',
            style: _body(size: 12, color: AppDS.textMuted)),
        ]),
      );
    }

    final msgs = _visibleMessages;
    if (msgs.isEmpty) {
      return Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(_currentChannel.icon, size: 38,
            color: AppDS.textMuted.withValues(alpha: 0.25)),
          const SizedBox(height: 12),
          Text('No messages in #${_currentChannel.label}',
            style: _body(size: 13, color: AppDS.textMuted)),
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
        return _MessageBubble(
          key: ValueKey(msg.id),
          message: msg,
          replies: _repliesByParent[msg.id] ?? [],
          compact: compact,
          channelColor: _currentChannel.color,
          isEditing: _editingId == msg.id,
          editCtrl: _editCtrl,
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
        );
      },
    );
  }

  // ── Reply banner ──────────────────────────────────────────────────────────
  Widget _buildReplyBanner() {
    final msg = _replyingTo!;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: const BoxDecoration(
        color: Color(0xFF0B1E33),
        border: Border(
          top: BorderSide(color: AppDS.border),
          left: BorderSide(color: AppDS.accent, width: 3)),
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
              style: _body(size: 11, color: AppDS.textSecondary)),
          ])),
        ),
        GestureDetector(
          onTap: () => setState(() => _replyingTo = null),
          child: const Icon(Icons.close, size: 14, color: AppDS.textMuted)),
      ]),
    );
  }

  // ── Composer ──────────────────────────────────────────────────────────────
  Widget _buildComposer() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
      decoration: const BoxDecoration(
        color: AppDS.surface,
        border: Border(top: BorderSide(color: AppDS.border)),
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
              hintStyle: _body(size: 12, color: AppDS.textMuted),
              filled: true, fillColor: AppDS.surface2,
              border: _ob(r: 10), enabledBorder: _ob(r: 10),
              focusedBorder: _ob(r: 10, color: AppDS.accent, w: 1.5),
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
            child: Icon(icon, size: 17, color: color ?? AppDS.textSecondary)),
        ),
      );

  // ── Right sidebar ─────────────────────────────────────────────────────────
  Widget _buildSidebarHeader() {
    return Container(
      height: 56,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppDS.border))),
      child: Row(children: [
        // Collapse button is always leftmost in the sidebar
        GestureDetector(
          onTap: () => setState(() => _sidebarCollapsed = !_sidebarCollapsed),
          child: Icon(
            _sidebarCollapsed ? Icons.chevron_left : Icons.chevron_right,
            size: 16, color: AppDS.textMuted),
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
    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 8),
      children: _channels.map((ch) {
        final isActive = _channel == ch.id;
        final count    = _msgCount[ch.id] ?? 0;
        return Tooltip(
          message: _sidebarCollapsed ? ch.label : '',
          // Tooltip on the left side since the sidebar is on the right
          child: InkWell(
            onTap: () => _switchChannel(ch.id),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 120),
              margin: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: isActive ? ch.color.withValues(alpha: 0.12) : Colors.transparent,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: isActive ? ch.color.withValues(alpha: 0.4) : Colors.transparent)),
              child: Row(children: [
                Icon(ch.icon, size: 15,
                  color: isActive ? ch.color : AppDS.textMuted),
                if (!_sidebarCollapsed) ...[
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(ch.label,
                      style: _body(size: 13,
                        color: isActive ? AppDS.textPrimary : AppDS.textSecondary,
                        weight: isActive ? FontWeight.w600 : FontWeight.w400)),
                  ),
                  if (count > 0)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                      decoration: BoxDecoration(
                        color: isActive ? ch.color.withValues(alpha: 0.2) : AppDS.surface3,
                        borderRadius: BorderRadius.circular(10)),
                      child: Text('$count',
                        style: _mono(size: 9,
                          color: isActive ? ch.color : AppDS.textMuted)),
                    ),
                ],
              ]),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildSidebarFooter() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: AppDS.border))),
      child: Row(children: [
        Container(
          width: 28, height: 28,
          decoration: BoxDecoration(
            color: AppDS.green.withValues(alpha: 0.15),
            shape: BoxShape.circle,
            border: Border.all(color: AppDS.green.withValues(alpha: 0.4))),
          child: Center(
            child: Text('Y',
              style: _mono(size: 11, color: AppDS.green, weight: FontWeight.w700)),
          ),
        ),
        if (!_sidebarCollapsed) ...[
          const SizedBox(width: 10),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('You', style: _body(size: 12, weight: FontWeight.w600)),
            Text('Online', style: _mono(size: 9, color: AppDS.green)),
          ]),
        ],
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
          color: active ? color.withValues(alpha: 0.15) : AppDS.surface2,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: active ? color.withValues(alpha: 0.4) : AppDS.border)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 12, color: active ? color : AppDS.textSecondary),
          const SizedBox(width: 5),
          Text(label,
            style: _body(size: 11,
              color: active ? color : AppDS.textSecondary,
              weight: FontWeight.w600)),
        ]),
      ),
    );
  }

  /// Shorthand for OutlineInputBorder
  OutlineInputBorder _ob({
    double r = 8, Color color = AppDS.border, double w = 1.0}) =>
      OutlineInputBorder(
        borderRadius: BorderRadius.circular(r),
        borderSide: BorderSide(color: color, width: w));

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

// ─── MESSAGE BUBBLE ───────────────────────────────────────────────────────────
class _MessageBubble extends StatefulWidget {
  final LabMessage            message;
  final List<LabMessage>      replies;
  final bool                  compact;
  final Color                 channelColor;
  final bool                  isEditing;
  final TextEditingController editCtrl;
  final ValueChanged<LabMessage> onReply;
  final ValueChanged<LabMessage> onEdit;
  final ValueChanged<LabMessage> onSaveEdit;
  final VoidCallback             onCancelEdit;
  final ValueChanged<LabMessage> onPin;
  final ValueChanged<LabMessage> onDelete;
  final ValueChanged<LabMessage> onCopy;

  const _MessageBubble({
    required super.key,
    required this.message,
    required this.replies,
    required this.compact,
    required this.channelColor,
    required this.isEditing,
    required this.editCtrl,
    required this.onReply,
    required this.onEdit,
    required this.onSaveEdit,
    required this.onCancelEdit,
    required this.onPin,
    required this.onDelete,
    required this.onCopy,
  });

  @override
  State<_MessageBubble> createState() => _MessageBubbleState();
}

class _MessageBubbleState extends State<_MessageBubble> {
  bool _hovered     = false;
  bool _showReplies = false;

  static const _avatarColors = [
    Color(0xFF00C8F0), Color(0xFF00D98A),
    Color(0xFF9B72CF), Color(0xFFFF8C42),
  ];

  Color _avatarColor(String senderKey) =>
      _avatarColors[senderKey.hashCode.abs() % _avatarColors.length];

  @override
  Widget build(BuildContext context) {
    final msg    = widget.message;
    final aColor = _avatarColor(msg.senderKey);

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit:  (_) => setState(() => _hovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 80),
        color: _hovered
            ? AppDS.surface2.withValues(alpha: 0.45)
            : msg.pinned ? AppDS.yellow.withValues(alpha: 0.025) : Colors.transparent,
        child: Padding(
          padding: EdgeInsets.only(
            top: widget.compact ? 2 : 10, bottom: 2, left: 4, right: 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Pinned strip
              if (msg.pinned)
                Padding(
                  padding: const EdgeInsets.only(left: 46, bottom: 3),
                  child: Row(children: [
                    const Icon(Icons.push_pin, size: 10, color: AppDS.yellow),
                    const SizedBox(width: 4),
                    Text('Pinned', style: _mono(size: 9, color: AppDS.yellow)),
                  ]),
                ),
              Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                // Avatar gutter
                SizedBox(
                  width: 36,
                  child: widget.compact
                      ? (_hovered
                          ? Center(
                              child: Text(_formatTime(msg.createdAt),
                                style: _mono(size: 8, color: AppDS.textMuted)))
                          : const SizedBox())
                      : Container(
                          width: 32, height: 32,
                          decoration: BoxDecoration(
                            color: aColor.withValues(alpha: 0.15),
                            shape: BoxShape.circle,
                            border: Border.all(color: aColor.withValues(alpha: 0.35))),
                          child: Center(
                            child: Text(
                              msg.displayName.isNotEmpty
                                  ? msg.displayName[0].toUpperCase() : '?',
                              style: _mono(size: 12, color: aColor,
                                weight: FontWeight.w700)),
                          ),
                        ),
                ),
                const SizedBox(width: 10),
                // Content
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Name + timestamp row (only on first bubble of a group)
                      if (!widget.compact)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 3),
                          child: Row(children: [
                            Text(msg.displayName,
                              style: _body(size: 13,
                                weight: FontWeight.w700, color: aColor)),
                            const SizedBox(width: 8),
                            Text(_formatDate(msg.createdAt),
                              style: _mono(size: 9.5, color: AppDS.textMuted)),
                            if (msg.edited) ...[
                              const SizedBox(width: 6),
                              Text('edited',
                                style: _mono(size: 9, color: AppDS.textMuted)),
                            ],
                            const Spacer(),
                            AnimatedOpacity(
                              opacity: _hovered ? 1.0 : 0.0,
                              duration: const Duration(milliseconds: 100),
                              child: _buildHoverActions(msg)),
                          ]),
                        )
                      else if (_hovered)
                        Align(
                          alignment: Alignment.centerRight,
                          child: _buildHoverActions(msg)),
                      // Context tag (from message_context_type / message_context_id)
                      if (msg.contextType != null)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: _ContextTag(
                            type: msg.contextType!, id: msg.contextId)),
                      // Body or inline edit field
                      widget.isEditing
                          ? _buildEditField(msg)
                          : _buildBodyText(msg.body),
                      // Reply count chip
                      if (widget.replies.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: _buildReplySummary()),
                      // Expanded thread
                      if (_showReplies && widget.replies.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: _buildReplies()),
                    ],
                  ),
                ),
              ]),
            ],
          ),
        ),
      ),
    );
  }

  // Render inline context tags e.g. [FISHLINE:3 Tg(mpx:GFP)] as chips
  Widget _buildBodyText(String text) {
    final tagRx = RegExp(r'\[(\w+):(\d+)\s([^\]]*)\]');
    if (!tagRx.hasMatch(text)) {
      return Text(text, style: _body(size: 13.5));
    }
    final spans = <InlineSpan>[];
    int last = 0;
    for (final m in tagRx.allMatches(text)) {
      if (m.start > last) {
        spans.add(TextSpan(
          text: text.substring(last, m.start), style: _body(size: 13.5)));
      }
      spans.add(WidgetSpan(
        alignment: PlaceholderAlignment.middle,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2),
          child: _ContextTag(
            type: m.group(1)!, id: int.tryParse(m.group(2)!),
            label: m.group(3))),
      ));
      last = m.end;
    }
    if (last < text.length) {
      spans.add(TextSpan(
        text: text.substring(last), style: _body(size: 13.5)));
    }
    return RichText(text: TextSpan(children: spans));
  }

  Widget _buildEditField(LabMessage msg) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      TextField(
        controller: widget.editCtrl,
        autofocus: true,
        maxLines: null,
        style: _body(size: 13),
        onSubmitted: (_) => widget.onSaveEdit(msg),
        decoration: InputDecoration(
          filled: true, fillColor: AppDS.surface3,
          border: _eb(), enabledBorder: _eb(),
          focusedBorder: _eb(color: AppDS.accent),
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          isDense: true,
        ),
      ),
      const SizedBox(height: 6),
      Row(children: [
        _pill('Save',   AppDS.accent, () => widget.onSaveEdit(msg)),
        const SizedBox(width: 8),
        _pill('Cancel', AppDS.textMuted, widget.onCancelEdit),
        const SizedBox(width: 10),
        Text('Enter to save', style: _mono(size: 9, color: AppDS.textMuted)),
      ]),
    ]);
  }

  OutlineInputBorder _eb({Color color = AppDS.border}) =>
      OutlineInputBorder(
        borderRadius: BorderRadius.circular(7),
        borderSide: BorderSide(color: color, width: 1.5));

  Widget _pill(String label, Color color, VoidCallback onTap) =>
      InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(5),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(5),
            border: Border.all(color: color.withValues(alpha: 0.3))),
          child: Text(label,
            style: _body(size: 11, color: color, weight: FontWeight.w700)),
        ),
      );

  Widget _buildHoverActions(LabMessage msg) {
    return Container(
      decoration: BoxDecoration(
        color: AppDS.surface2,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppDS.border2),
        boxShadow: [BoxShadow(
          color: Colors.black.withValues(alpha: 0.35),
          blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        _aBtn(Icons.reply, 'Reply', () => widget.onReply(msg)),
        _aBtn(
          msg.pinned ? Icons.push_pin : Icons.push_pin_outlined,
          msg.pinned ? 'Unpin' : 'Pin',
          () => widget.onPin(msg),
          color: msg.pinned ? AppDS.yellow : null),
        _aBtn(Icons.edit_outlined,  'Edit',   () => widget.onEdit(msg)),
        _aBtn(Icons.copy_outlined,  'Copy',   () => widget.onCopy(msg)),
        _aBtn(Icons.delete_outline, 'Delete', () => widget.onDelete(msg),
          color: AppDS.red),
      ]),
    );
  }

  Widget _aBtn(IconData icon, String tip, VoidCallback onTap, {Color? color}) =>
      Tooltip(
        message: tip,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(6),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 6),
            child: Icon(icon, size: 14, color: color ?? AppDS.textSecondary)),
        ),
      );

  Widget _buildReplySummary() {
    final count = widget.replies.where((r) => !r.deleted).length;
    if (count == 0) return const SizedBox.shrink();
    return InkWell(
      onTap: () => setState(() => _showReplies = !_showReplies),
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: AppDS.surface3,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: AppDS.border)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(_showReplies ? Icons.expand_less : Icons.expand_more,
            size: 13, color: AppDS.accent),
          const SizedBox(width: 6),
          Text(
            _showReplies
                ? 'Hide $count repl${count == 1 ? 'y' : 'ies'}'
                : '$count repl${count == 1 ? 'y' : 'ies'}',
            style: _body(size: 11, color: AppDS.accent, weight: FontWeight.w600)),
        ]),
      ),
    );
  }

  Widget _buildReplies() {
    final visible = widget.replies.where((r) => !r.deleted).toList();
    return Container(
      margin: const EdgeInsets.only(top: 2),
      padding: const EdgeInsets.only(left: 14),
      decoration: const BoxDecoration(
        border: Border(left: BorderSide(color: AppDS.border2, width: 2))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: visible.map((r) {
          final aColor = _avatarColor(r.senderKey);
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 5),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Container(
                width: 24, height: 24,
                decoration: BoxDecoration(
                  color: aColor.withValues(alpha: 0.15), shape: BoxShape.circle),
                child: Center(
                  child: Text(
                    r.displayName.isNotEmpty
                        ? r.displayName[0].toUpperCase() : '?',
                    style: _mono(size: 9, color: aColor,
                      weight: FontWeight.w700)),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Text(r.displayName,
                      style: _body(size: 11.5, color: aColor,
                        weight: FontWeight.w700)),
                    const SizedBox(width: 6),
                    Text(_formatDate(r.createdAt),
                      style: _mono(size: 8.5, color: AppDS.textMuted)),
                    if (r.edited) ...[
                      const SizedBox(width: 4),
                      Text('edited',
                        style: _mono(size: 8, color: AppDS.textMuted)),
                    ],
                  ]),
                  Text(r.body, style: _body(size: 12.5)),
                ]),
              ),
            ]),
          );
        }).toList(),
      ),
    );
  }

  String _formatDate(DateTime dt) {
    final now = DateTime.now();
    final today = dt.year == now.year &&
        dt.month == now.month && dt.day == now.day;
    return today
        ? 'Today ${_formatTime(dt)}'
        : '${dt.day.toString().padLeft(2, '0')}/'
          '${dt.month.toString().padLeft(2, '0')} ${_formatTime(dt)}';
  }

  String _formatTime(DateTime dt) =>
      '${dt.hour.toString().padLeft(2, '0')}:'
      '${dt.minute.toString().padLeft(2, '0')}';
}

// ─── CONTEXT TAG CHIP ────────────────────────────────────────────────────────
class _ContextTag extends StatelessWidget {
  final String  type;
  final int?    id;
  final String? label;
  const _ContextTag({required this.type, this.id, this.label});

  @override
  Widget build(BuildContext context) {
    const colors = <String, Color>{
      'fishline' : Color(0xFF00C8F0), 'strain'   : Color(0xFF9B72CF),
      'sample'   : Color(0xFFFF8C42), 'reagent'  : Color(0xFFFF4D6D),
      'equipment': Color(0xFF7A9CBF), 'protocol' : Color(0xFF00D98A),
    };
    const icons = <String, IconData>{
      'fishline' : Icons.water,
      'strain'   : Icons.biotech,
      'sample'   : Icons.science_outlined,
      'reagent'  : Icons.colorize_outlined,
      'equipment': Icons.precision_manufacturing_outlined,
      'protocol' : Icons.list_alt_outlined,
    };
    final key   = type.toLowerCase();
    final color = colors[key] ?? const Color(0xFF7A9CBF);
    final icon  = icons[key] ?? Icons.link;
    final text  = label != null
        ? '${type.toUpperCase()} · $label'
        : id != null ? '${type.toUpperCase()} #$id'
        : type.toUpperCase();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withValues(alpha: 0.35))),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 10, color: color),
        const SizedBox(width: 4),
        Text(text,
          style: GoogleFonts.jetBrainsMono(
            fontSize: 9.5, color: color, fontWeight: FontWeight.w600)),
      ]),
    );
  }
}

// ─── CONTEXT PICKER DIALOG ───────────────────────────────────────────────────
class _ContextPickerDialog extends StatefulWidget {
  final void Function(String type, int id, String label) onPick;
  const _ContextPickerDialog({required this.onPick});

  @override
  State<_ContextPickerDialog> createState() => _ContextPickerDialogState();
}

class _ContextPickerDialogState extends State<_ContextPickerDialog> {
  String _type = 'fishline';
  final _idCtrl    = TextEditingController();
  final _labelCtrl = TextEditingController();

  static const _types = [
    ('fishline',  Icons.water,                            Color(0xFF00C8F0)),
    ('strain',    Icons.biotech,                          Color(0xFF9B72CF)),
    ('sample',    Icons.science_outlined,                 Color(0xFFFF8C42)),
    ('reagent',   Icons.colorize_outlined,                Color(0xFFFF4D6D)),
    ('equipment', Icons.precision_manufacturing_outlined, Color(0xFF7A9CBF)),
    ('protocol',  Icons.list_alt_outlined,                Color(0xFF00D98A)),
  ];

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppDS.surface2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: AppDS.border2)),
      title: Text('Attach Context Reference',
        style: _body(size: 15, weight: FontWeight.w700)),
      content: SizedBox(
        width: 380,
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Wrap(spacing: 6, runSpacing: 6,
            children: _types.map((t) {
              final sel = _type == t.$1;
              return InkWell(
                onTap: () => setState(() => _type = t.$1),
                borderRadius: BorderRadius.circular(6),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: sel ? t.$3.withValues(alpha: 0.15) : AppDS.surface3,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: sel ? t.$3.withValues(alpha: 0.5) : AppDS.border)),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(t.$2, size: 13, color: sel ? t.$3 : AppDS.textMuted),
                    const SizedBox(width: 5),
                    Text(t.$1,
                      style: _body(size: 12,
                        color: sel ? t.$3 : AppDS.textSecondary,
                        weight: sel ? FontWeight.w600 : null)),
                  ]),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 14),
          Row(children: [
            Expanded(flex: 1,
              child: _f('ID',    _idCtrl,    hint: '1',              mono: true)),
            const SizedBox(width: 10),
            Expanded(flex: 3,
              child: _f('Label', _labelCtrl, hint: 'e.g. Tg(mpx:GFP)')),
          ]),
        ]),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context),
          child: Text('Cancel', style: _body(size: 13, color: AppDS.textMuted))),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppDS.accent, foregroundColor: AppDS.bg),
          onPressed: () {
            final id = int.tryParse(_idCtrl.text.trim());
            if (id == null) return;
            widget.onPick(_type, id, _labelCtrl.text.trim());
            Navigator.pop(context);
          },
          child: Text('Attach',
            style: _body(size: 13, weight: FontWeight.w700)),
        ),
      ],
    );
  }

  Widget _f(String label, TextEditingController ctrl,
      {String? hint, bool mono = false}) =>
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label,
          style: _body(size: 11, color: AppDS.textMuted, weight: FontWeight.w700)),
        const SizedBox(height: 4),
        TextField(
          controller: ctrl,
          style: (mono
              ? GoogleFonts.jetBrainsMono(fontSize: 12)
              : GoogleFonts.dmSans(fontSize: 13))
              .copyWith(color: AppDS.textPrimary),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: _body(size: 12, color: AppDS.textMuted),
            filled: true, fillColor: AppDS.surface3,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(7),
              borderSide: const BorderSide(color: AppDS.border)),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(7),
              borderSide: const BorderSide(color: AppDS.border)),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(7),
              borderSide: const BorderSide(color: AppDS.accent, width: 1.5)),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            isDense: true,
          ),
        ),
      ]);
}
