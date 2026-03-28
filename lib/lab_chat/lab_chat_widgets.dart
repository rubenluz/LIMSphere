// lab_chat_widgets.dart - Part of lab_chat_page.dart.
// _MessageBubble: renders a single chat message with reactions, replies, edit.
// _ContextTag: chip linking a database record (strain, sample, etc.).
// _ContextPickerDialog: dialog to attach a record as message context.
part of 'lab_chat_page.dart';

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
  final VoidCallback?            onAvatarTap;
  final bool                     canEditDelete;

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
    required this.canEditDelete,
    this.onAvatarTap,
  });

  @override
  State<_MessageBubble> createState() => _MessageBubbleState();
}

class _MessageBubbleState extends State<_MessageBubble> {
  bool _hovered     = false;
  bool _showReplies = false;

  static const _avatarColors = [
    Color(0xFF00C8F0), // cyan
    Color(0xFF00D98A), // green
    Color(0xFF9B72CF), // purple
    Color(0xFFFF8C42), // orange
    Color(0xFFFF4D6D), // rose
    Color(0xFFFBBF24), // amber
    Color(0xFF34D399), // emerald
    Color(0xFF60A5FA), // blue
    Color(0xFFF472B6), // pink
    Color(0xFF2DD4BF), // teal
    Color(0xFFA78BFA), // violet
    Color(0xFFFF6B6B), // coral
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
            ? context.appSurface2.withValues(alpha: 0.45)
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
                                style: _mono(size: 8, color: context.appTextMuted)))
                          : const SizedBox())
                      : GestureDetector(
                          onTap: widget.onAvatarTap,
                          child: Container(
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
                              style: _mono(size: 9.5, color: context.appTextMuted)),
                            if (msg.edited) ...[
                              const SizedBox(width: 6),
                              Text('edited',
                                style: _mono(size: 9, color: context.appTextMuted)),
                            ],
                            const Spacer(),
                            AnimatedOpacity(
                              opacity: _hovered ? 1.0 : 0.0,
                              duration: const Duration(milliseconds: 100),
                              child: _buildHoverActions(context, msg)),
                          ]),
                        )
                      else if (_hovered)
                        Align(
                          alignment: Alignment.centerRight,
                          child: _buildHoverActions(context, msg)),
                      // Context tag (from message_context_type / message_context_id)
                      if (msg.contextType != null)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: _ContextTag(
                            type: msg.contextType!, id: msg.contextId)),
                      // Body or inline edit field
                      widget.isEditing
                          ? _buildEditField(context, msg)
                          : _buildBodyText(msg.body),
                      // Reply count chip
                      if (widget.replies.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: _buildReplySummary(context)),
                      // Expanded thread
                      if (_showReplies && widget.replies.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: _buildReplies(context)),
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
      return Text(text, style: _body(size: 13.5, color: context.appTextPrimary));
    }
    final spans = <InlineSpan>[];
    int last = 0;
    for (final m in tagRx.allMatches(text)) {
      if (m.start > last) {
        spans.add(TextSpan(
          text: text.substring(last, m.start),
          style: _body(size: 13.5, color: context.appTextPrimary)));
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
        text: text.substring(last),
        style: _body(size: 13.5, color: context.appTextPrimary)));
    }
    return RichText(text: TextSpan(children: spans));
  }

  Widget _buildEditField(BuildContext ctx, LabMessage msg) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      TextField(
        controller: widget.editCtrl,
        autofocus: true,
        maxLines: null,
        style: _body(size: 13),
        onSubmitted: (_) => widget.onSaveEdit(msg),
        decoration: InputDecoration(
          filled: true, fillColor: ctx.appSurface3,
          border: _eb(ctx), enabledBorder: _eb(ctx),
          focusedBorder: _eb(ctx, color: AppDS.accent),
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          isDense: true,
        ),
      ),
      const SizedBox(height: 6),
      Row(children: [
        _pill('Save',   AppDS.accent, () => widget.onSaveEdit(msg)),
        const SizedBox(width: 8),
        _pill('Cancel', ctx.appTextMuted, widget.onCancelEdit),
        const SizedBox(width: 10),
        Text('Enter to save', style: _mono(size: 9, color: ctx.appTextMuted)),
      ]),
    ]);
  }

  OutlineInputBorder _eb(BuildContext ctx, {Color? color}) =>
      OutlineInputBorder(
        borderRadius: BorderRadius.circular(7),
        borderSide: BorderSide(color: color ?? ctx.appBorder, width: 1.5));

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

  Widget _buildHoverActions(BuildContext ctx, LabMessage msg) {
    return Container(
      decoration: BoxDecoration(
        color: ctx.appSurface2,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: ctx.appBorder2),
        boxShadow: [BoxShadow(
          color: Colors.black.withValues(alpha: 0.35),
          blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        _aBtn(ctx, Icons.reply, 'Reply', () => widget.onReply(msg)),
        _aBtn(ctx,
          msg.pinned ? Icons.push_pin : Icons.push_pin_outlined,
          msg.pinned ? 'Unpin' : 'Pin',
          () => widget.onPin(msg),
          color: msg.pinned ? AppDS.yellow : null),
        if (widget.canEditDelete)
          _aBtn(ctx, Icons.edit_outlined, 'Edit', () => widget.onEdit(msg)),
        _aBtn(ctx, Icons.copy_outlined,  'Copy',   () => widget.onCopy(msg)),
        if (widget.canEditDelete)
          _aBtn(ctx, Icons.delete_outline, 'Delete', () => widget.onDelete(msg),
            color: AppDS.red),
      ]),
    );
  }

  Widget _aBtn(BuildContext ctx, IconData icon, String tip, VoidCallback onTap, {Color? color}) =>
      Tooltip(
        message: tip,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(6),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 6),
            child: Icon(icon, size: 14, color: color ?? ctx.appTextSecondary)),
        ),
      );

  Widget _buildReplySummary(BuildContext ctx) {
    final count = widget.replies.where((r) => !r.deleted).length;
    if (count == 0) return const SizedBox.shrink();
    return InkWell(
      onTap: () => setState(() => _showReplies = !_showReplies),
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: ctx.appSurface3,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: ctx.appBorder)),
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

  Widget _buildReplies(BuildContext ctx) {
    final visible = widget.replies.where((r) => !r.deleted).toList();
    return Container(
      margin: const EdgeInsets.only(top: 2),
      padding: const EdgeInsets.only(left: 14),
      decoration: BoxDecoration(
        border: Border(left: BorderSide(color: ctx.appBorder2, width: 2))),
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
                      style: _mono(size: 8.5, color: ctx.appTextMuted)),
                    if (r.edited) ...[
                      const SizedBox(width: 4),
                      Text('edited',
                        style: _mono(size: 8, color: ctx.appTextMuted)),
                    ],
                  ]),
                  Text(r.body, style: _body(size: 12.5, color: ctx.appTextPrimary)),
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
      backgroundColor: context.appSurface2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: context.appBorder2)),
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
                    color: sel ? t.$3.withValues(alpha: 0.15) : context.appSurface3,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: sel ? t.$3.withValues(alpha: 0.5) : context.appBorder)),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(t.$2, size: 13, color: sel ? t.$3 : context.appTextMuted),
                    const SizedBox(width: 5),
                    Text(t.$1,
                      style: _body(size: 12,
                        color: sel ? t.$3 : context.appTextSecondary,
                        weight: sel ? FontWeight.w600 : null)),
                  ]),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 14),
          Row(children: [
            Expanded(flex: 1,
              child: _f(context, 'ID',    _idCtrl,    hint: '1',              mono: true)),
            const SizedBox(width: 10),
            Expanded(flex: 3,
              child: _f(context, 'Label', _labelCtrl, hint: 'e.g. Tg(mpx:GFP)')),
          ]),
        ]),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context),
          child: Text('Cancel', style: _body(size: 13, color: context.appTextMuted))),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppDS.accent, foregroundColor: context.appBg),
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

  Widget _f(BuildContext ctx, String label, TextEditingController ctrl,
      {String? hint, bool mono = false}) =>
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label,
          style: _body(size: 11, color: ctx.appTextMuted, weight: FontWeight.w700)),
        const SizedBox(height: 4),
        TextField(
          controller: ctrl,
          style: (mono
              ? GoogleFonts.jetBrainsMono(fontSize: 12)
              : GoogleFonts.dmSans(fontSize: 13))
              .copyWith(color: ctx.appTextPrimary),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: _body(size: 12, color: ctx.appTextMuted),
            filled: true, fillColor: ctx.appSurface3,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(7),
              borderSide: BorderSide(color: ctx.appBorder)),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(7),
              borderSide: BorderSide(color: ctx.appBorder)),
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
