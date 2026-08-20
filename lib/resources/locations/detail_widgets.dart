// detail_widgets.dart - Shared collapsible section + inline field helpers
// used by RoomDetailPage and LocationDetailPage.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';

import '/theme/theme.dart';

class DetailSection extends StatelessWidget {
  final String title;
  final IconData icon;
  final bool expanded;
  final VoidCallback onToggle;
  final Widget child;

  const DetailSection({
    super.key,
    required this.title,
    required this.icon,
    required this.expanded,
    required this.onToggle,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: context.appSurface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: context.appBorder),
      ),
      child: Column(
        children: [
          InkWell(
            onTap: onToggle,
            borderRadius: BorderRadius.vertical(
              top: const Radius.circular(10),
              bottom: Radius.circular(expanded ? 0 : 10),
            ),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
              decoration: BoxDecoration(
                color: context.appSurface2,
                borderRadius: BorderRadius.vertical(
                  top: const Radius.circular(10),
                  bottom: Radius.circular(expanded ? 0 : 10),
                ),
              ),
              child: Row(
                children: [
                  Icon(icon, size: 14, color: AppDS.accent),
                  const SizedBox(width: 8),
                  Text(
                    title,
                    style: GoogleFonts.spaceGrotesk(
                      color: context.appTextSecondary,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.8,
                    ),
                  ),
                  const Spacer(),
                  Icon(
                    expanded ? Icons.expand_less : Icons.expand_more,
                    size: 18,
                    color: context.appTextMuted,
                  ),
                ],
              ),
            ),
          ),
          if (expanded) ...[
            Divider(height: 1, color: context.appBorder),
            Padding(padding: const EdgeInsets.all(14), child: child),
          ],
        ],
      ),
    );
  }
}

class DetailFieldRow extends StatelessWidget {
  final List<Widget> children;
  const DetailFieldRow({super.key, required this.children});

  @override
  Widget build(BuildContext context) {
    return Row(
      children:
          children
              .expand((w) => [Expanded(child: w), const SizedBox(width: 10)])
              .toList()
            ..removeLast(),
    );
  }
}

class DetailInlineField extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final int maxLines;
  final TextInputType? keyboardType;
  final bool readOnly;

  const DetailInlineField({
    super.key,
    required this.label,
    required this.controller,
    this.maxLines = 1,
    this.keyboardType,
    this.readOnly = false,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      keyboardType: keyboardType,
      readOnly: readOnly,
      style: GoogleFonts.spaceGrotesk(
        color: readOnly ? context.appTextSecondary : context.appTextPrimary,
        fontSize: 13,
      ),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: GoogleFonts.spaceGrotesk(
          color: context.appTextSecondary,
          fontSize: 11,
        ),
        filled: true,
        fillColor: readOnly ? context.appSurface2 : context.appSurface3,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: context.appBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: context.appBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(
            color: readOnly ? context.appBorder : AppDS.accent,
          ),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 10,
        ),
      ),
    );
  }
}

class DetailInlineDropdown<T> extends StatelessWidget {
  final String label;
  final T value;
  final List<DropdownMenuItem<T>> items;
  final void Function(T?) onChanged;
  final bool readOnly;

  const DetailInlineDropdown({
    super.key,
    required this.label,
    required this.value,
    required this.items,
    required this.onChanged,
    this.readOnly = false,
  });

  @override
  Widget build(BuildContext context) {
    return InputDecorator(
      decoration: InputDecoration(
        labelText: label,
        labelStyle: GoogleFonts.spaceGrotesk(
          color: context.appTextSecondary,
          fontSize: 11,
        ),
        filled: true,
        fillColor: readOnly ? context.appSurface2 : context.appSurface3,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: context.appBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: context.appBorder),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          value: value,
          isExpanded: true,
          dropdownColor: context.appSurface,
          style: GoogleFonts.spaceGrotesk(
            color: readOnly ? context.appTextSecondary : context.appTextPrimary,
            fontSize: 13,
          ),
          items: items,
          onChanged: readOnly ? null : onChanged,
          disabledHint: _disabledHint(context),
          icon: readOnly
              ? const SizedBox.shrink()
              : const Icon(Icons.arrow_drop_down),
        ),
      ),
    );
  }

  Widget? _disabledHint(BuildContext context) {
    final match = items.where((i) => i.value == value).toList();
    if (match.isEmpty) return null;
    return DefaultTextStyle.merge(
      style: GoogleFonts.spaceGrotesk(
        color: context.appTextSecondary,
        fontSize: 13,
      ),
      child: match.first.child,
    );
  }
}

// ─── Responsible @-mention field (chips, multi-user) ─────────────────────────
// Entries are stored in [controller.text] as a semicolon-separated list.
// Each entry is either a matched user's email (rendered as an accent chip
// showing the user name, clickable to open an info dialog) or free text
// that didn't resolve to any user (rendered as a muted/grey chip).
class DetailResponsibleField extends StatefulWidget {
  final String label;
  final TextEditingController controller;
  final List<Map<String, dynamic>> users;
  final bool readOnly;

  const DetailResponsibleField({
    super.key,
    required this.label,
    required this.controller,
    required this.users,
    required this.readOnly,
  });

  @override
  State<DetailResponsibleField> createState() => _DetailResponsibleFieldState();
}

class _DetailResponsibleFieldState extends State<DetailResponsibleField> {
  final _inputCtrl = TextEditingController();
  late final FocusNode _focus;
  final _layerLink = LayerLink();
  OverlayEntry? _overlay;
  List<String> _entries = [];
  String _query = '';
  int _selectedIndex = 0;

  @override
  void initState() {
    super.initState();
    _focus = FocusNode(onKeyEvent: _onKey);
    _syncFromParent();
    widget.controller.addListener(_syncFromParent);
    _inputCtrl.addListener(_onInputChanged);
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    if (_overlay == null) return KeyEventResult.ignored;
    final matches = _matches;
    if (matches.isEmpty) return KeyEventResult.ignored;

    if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
      setState(() => _selectedIndex = (_selectedIndex + 1) % matches.length);
      _overlay?.markNeedsBuild();
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
      setState(
        () => _selectedIndex =
            (_selectedIndex - 1 + matches.length) % matches.length,
      );
      _overlay?.markNeedsBuild();
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.enter ||
        event.logicalKey == LogicalKeyboardKey.numpadEnter) {
      final idx = _selectedIndex.clamp(0, matches.length - 1);
      _addEntry((matches[idx]['user_email'] as String?) ?? '');
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.escape) {
      _removeOverlay();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  void didUpdateWidget(covariant DetailResponsibleField old) {
    super.didUpdateWidget(old);
    if (old.controller != widget.controller) {
      old.controller.removeListener(_syncFromParent);
      widget.controller.addListener(_syncFromParent);
      _syncFromParent();
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_syncFromParent);
    _inputCtrl.removeListener(_onInputChanged);
    _inputCtrl.dispose();
    _removeOverlay();
    _focus.dispose();
    super.dispose();
  }

  void _syncFromParent() {
    final parsed = _parse(widget.controller.text);
    if (_listEq(parsed, _entries)) return;
    setState(() => _entries = parsed);
  }

  static List<String> _parse(String raw) =>
      raw.split(';').map((s) => s.trim()).where((s) => s.isNotEmpty).toList();

  static bool _listEq(List<String> a, List<String> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  void _writeToParent() {
    final joined = _entries.join('; ');
    if (widget.controller.text == joined) return;
    widget.controller.text = joined;
  }

  void _addEntry(String value) {
    final v = value.trim();
    if (v.isEmpty || _entries.contains(v)) {
      _inputCtrl.clear();
      _removeOverlay();
      return;
    }
    setState(() => _entries = [..._entries, v]);
    _writeToParent();
    _inputCtrl.clear();
    _removeOverlay();
  }

  void _removeEntry(String value) {
    setState(() => _entries = _entries.where((e) => e != value).toList());
    _writeToParent();
  }

  void _onInputChanged() {
    if (widget.readOnly) return;
    final text = _inputCtrl.text;
    if (text.isEmpty) {
      _removeOverlay();
      return;
    }
    final q = text.startsWith('@') ? text.substring(1) : text;
    if (q.contains(RegExp(r'\s'))) {
      _removeOverlay();
      return;
    }
    _query = q.toLowerCase();
    _selectedIndex = 0;
    _showOverlay();
  }

  List<Map<String, dynamic>> get _matches {
    final users = widget.users.where((u) {
      final email = (u['user_email'] as String?) ?? '';
      return !_entries.contains(email);
    });
    if (_query.isEmpty) return users.take(8).toList();
    return users
        .where((u) {
          final name = (u['user_name'] as String?)?.toLowerCase() ?? '';
          final email = (u['user_email'] as String?)?.toLowerCase() ?? '';
          return name.contains(_query) || email.contains(_query);
        })
        .take(8)
        .toList();
  }

  void _showOverlay() {
    final matches = _matches;
    if (matches.isEmpty) {
      _removeOverlay();
      return;
    }
    if (_overlay != null) {
      _overlay!.markNeedsBuild();
      return;
    }
    _overlay = OverlayEntry(builder: _buildOverlay);
    Overlay.of(context).insert(_overlay!);
  }

  Widget _buildOverlay(BuildContext ctx) {
    return Positioned(
      width: 280,
      child: CompositedTransformFollower(
        link: _layerLink,
        showWhenUnlinked: false,
        targetAnchor: Alignment.bottomLeft,
        followerAnchor: Alignment.topLeft,
        offset: const Offset(0, 4),
        child: TapRegion(
          groupId: _layerLink,
          child: Material(
            color: ctx.appSurface,
            elevation: 6,
            borderRadius: BorderRadius.circular(8),
            child: Container(
              decoration: BoxDecoration(
                border: Border.all(color: ctx.appBorder),
                borderRadius: BorderRadius.circular(8),
              ),
              child: ListView.builder(
                shrinkWrap: true,
                padding: const EdgeInsets.symmetric(vertical: 4),
                itemCount: _matches.length,
                itemBuilder: (_, i) {
                  final u = _matches[i];
                  final selected = i == _selectedIndex;
                  return InkWell(
                    onTap: () => _addEntry((u['user_email'] as String?) ?? ''),
                    onHover: (hovered) {
                      if (hovered && _selectedIndex != i) {
                        setState(() => _selectedIndex = i);
                        _overlay?.markNeedsBuild();
                      }
                    },
                    child: Container(
                      color: selected
                          ? AppDS.accent.withValues(alpha: 0.15)
                          : null,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.person_outline,
                            size: 14,
                            color: selected ? AppDS.accent : ctx.appTextMuted,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  (u['user_name'] as String?) ??
                                      (u['user_email'] as String? ?? ''),
                                  style: GoogleFonts.spaceGrotesk(
                                    color: selected
                                        ? AppDS.accent
                                        : ctx.appTextPrimary,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                Text(
                                  (u['user_email'] as String?) ?? '',
                                  style: GoogleFonts.jetBrainsMono(
                                    color: ctx.appTextMuted,
                                    fontSize: 10,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _removeOverlay() {
    _overlay?.remove();
    _overlay = null;
  }

  Map<String, dynamic>? _matchedUser(String raw) {
    final q = raw.trim().toLowerCase();
    if (q.isEmpty) return null;
    for (final u in widget.users) {
      if (((u['user_email'] as String?)?.toLowerCase() ?? '') == q) return u;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final chips = _entries
        .map(
          (e) => ResponsibleChip(
            raw: e,
            user: _matchedUser(e),
            onRemove: widget.readOnly ? null : () => _removeEntry(e),
          ),
        )
        .toList();

    if (widget.readOnly) {
      return InputDecorator(
        decoration: InputDecoration(
          labelText: widget.label,
          labelStyle: GoogleFonts.spaceGrotesk(
            color: context.appTextSecondary,
            fontSize: 11,
          ),
          filled: true,
          fillColor: context.appSurface2,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: context.appBorder),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: context.appBorder),
          ),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 8,
            vertical: 8,
          ),
        ),
        child: chips.isEmpty
            ? Text(
                '—',
                style: GoogleFonts.spaceGrotesk(
                  color: context.appTextMuted,
                  fontSize: 13,
                ),
              )
            : Wrap(spacing: 6, runSpacing: 6, children: chips),
      );
    }

    return TapRegion(
      groupId: _layerLink,
      onTapOutside: (_) => _removeOverlay(),
      child: CompositedTransformTarget(
        link: _layerLink,
        child: InputDecorator(
          decoration: InputDecoration(
            labelText: widget.label,
            labelStyle: GoogleFonts.spaceGrotesk(
              color: context.appTextSecondary,
              fontSize: 11,
            ),
            filled: true,
            fillColor: context.appSurface3,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: context.appBorder),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: context.appBorder),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: AppDS.accent),
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 8,
              vertical: 6,
            ),
          ),
          child: Wrap(
            spacing: 6,
            runSpacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              ...chips,
              SizedBox(
                width: 160,
                child: KeyboardListener(
                  focusNode: FocusNode(skipTraversal: true),
                  onKeyEvent: (ev) {
                    if (ev is KeyDownEvent &&
                        ev.logicalKey == LogicalKeyboardKey.backspace &&
                        _inputCtrl.text.isEmpty &&
                        _entries.isNotEmpty) {
                      _removeEntry(_entries.last);
                    }
                  },
                  child: TextField(
                    controller: _inputCtrl,
                    focusNode: _focus,
                    style: GoogleFonts.spaceGrotesk(
                      color: context.appTextPrimary,
                      fontSize: 13,
                    ),
                    decoration: InputDecoration(
                      isDense: true,
                      border: InputBorder.none,
                      hintText: _entries.isEmpty
                          ? 'Type @ to mention a user'
                          : 'Add…',
                      hintStyle: GoogleFonts.spaceGrotesk(
                        color: context.appTextMuted,
                        fontSize: 12,
                      ),
                      contentPadding: const EdgeInsets.symmetric(vertical: 6),
                    ),
                    onSubmitted: (v) {
                      // Prefer top match if query is active; otherwise free text.
                      if (_query.isNotEmpty && _matches.isNotEmpty) {
                        _addEntry(
                          (_matches.first['user_email'] as String?) ?? v,
                        );
                      } else {
                        final stripped = v.startsWith('@') ? v.substring(1) : v;
                        _addEntry(stripped);
                      }
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Read-only row of [ResponsibleChip]s parsed from a semicolon-separated raw
/// string. Used in detail-page headers to display the saved responsibles
/// inline with the entity name.
class DetailResponsibleChips extends StatelessWidget {
  final String? raw;
  final List<Map<String, dynamic>> users;
  final bool compact;

  const DetailResponsibleChips({
    super.key,
    required this.raw,
    required this.users,
    this.compact = true,
  });

  Map<String, dynamic>? _match(String value) {
    final q = value.trim().toLowerCase();
    if (q.isEmpty) return null;
    for (final u in users) {
      if (((u['user_email'] as String?)?.toLowerCase() ?? '') == q) return u;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final entries = (raw ?? '')
        .split(';')
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();
    if (entries.isEmpty) return const SizedBox.shrink();
    return Wrap(
      spacing: 6,
      runSpacing: 4,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: entries
          .map(
            (e) => ResponsibleChip(
              raw: e,
              user: _match(e),
              onRemove: null,
              compact: compact,
            ),
          )
          .toList(),
    );
  }
}

class ResponsibleChip extends StatelessWidget {
  final String raw;
  final Map<String, dynamic>? user;
  final VoidCallback? onRemove;
  final bool compact;

  const ResponsibleChip({
    super.key,
    required this.raw,
    required this.user,
    required this.onRemove,
    this.compact = false,
  });

  // Distinct accent palette so two different responsibles don't blend together
  // visually. Each user hashes deterministically to one slot, so the same
  // person keeps the same color across rows / pages.
  static const _palette = <Color>[
    Color(0xFF38BDF8), // sky
    Color(0xFF22C55E), // green
    Color(0xFFEAB308), // yellow
    Color(0xFFF97316), // orange
    Color(0xFFEF4444), // red
    Color(0xFFA855F7), // purple
    Color(0xFFEC4899), // pink
    Color(0xFF14B8A6), // teal
    Color(0xFF8B5CF6), // violet
  ];

  static Color _userColor(String key) {
    final k = key.trim().toLowerCase();
    if (k.isEmpty) return _palette[0];
    var h = 0;
    for (final c in k.codeUnits) {
      h = (h * 31 + c) & 0x7fffffff;
    }
    return _palette[h % _palette.length];
  }

  @override
  Widget build(BuildContext context) {
    final matched = user != null;
    final displayText = matched
        ? ((user!['user_name'] as String?)?.trim().isNotEmpty == true
              ? user!['user_name'] as String
              : (user!['user_email'] as String? ?? raw))
        : raw;
    final color = matched
        ? _userColor((user!['user_email'] as String?) ?? raw)
        : context.appTextMuted;
    final pad = compact
        ? const EdgeInsets.fromLTRB(6, 2, 6, 2)
        : const EdgeInsets.fromLTRB(8, 4, 4, 4);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: matched ? () => _showUserDialog(context, user!) : null,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: pad,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: color.withValues(alpha: 0.35)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                matched ? Icons.person_outline : Icons.help_outline,
                size: compact ? 11 : 12,
                color: color,
              ),
              const SizedBox(width: 4),
              Text(
                displayText,
                style: GoogleFonts.spaceGrotesk(
                  color: color,
                  fontSize: compact ? 11 : 12,
                  fontWeight: matched ? FontWeight.w600 : FontWeight.normal,
                ),
              ),
              if (onRemove != null) ...[
                const SizedBox(width: 2),
                InkWell(
                  onTap: onRemove,
                  borderRadius: BorderRadius.circular(10),
                  child: Padding(
                    padding: const EdgeInsets.all(2),
                    child: Icon(Icons.close, size: 12, color: color),
                  ),
                ),
              ] else if (!compact)
                const SizedBox(width: 4),
            ],
          ),
        ),
      ),
    );
  }

  void _showUserDialog(BuildContext context, Map<String, dynamic> u) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: ctx.appSurface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Row(
          children: [
            CircleAvatar(
              radius: 16,
              backgroundColor: AppDS.accent.withValues(alpha: 0.2),
              child: const Icon(
                Icons.person_outline,
                size: 16,
                color: AppDS.accent,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                (u['user_name'] as String?) ??
                    (u['user_email'] as String? ?? 'User'),
                style: GoogleFonts.spaceGrotesk(
                  color: ctx.appTextPrimary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _infoRow(ctx, Icons.email_outlined, u['user_email'] as String?),
            _infoRow(ctx, Icons.phone_outlined, u['user_phone'] as String?),
            _infoRow(
              ctx,
              Icons.business_outlined,
              u['user_institution'] as String?,
            ),
            _infoRow(ctx, Icons.groups_outlined, u['user_group'] as String?),
            _infoRow(ctx, Icons.badge_outlined, u['user_role'] as String?),
          ],
        ),
        actions: [
          if ((u['user_email'] as String?)?.trim().isNotEmpty == true) ...[
            TextButton.icon(
              onPressed: () async {
                final email = u['user_email'] as String;
                await Clipboard.setData(ClipboardData(text: email));
                if (ctx.mounted) {
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    SnackBar(
                      content: Text(
                        'Email copied',
                        style: GoogleFonts.spaceGrotesk(color: Colors.white),
                      ),
                      behavior: SnackBarBehavior.floating,
                      backgroundColor: AppDS.surface,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  );
                }
              },
              icon: Icon(Icons.copy, size: 14, color: ctx.appTextSecondary),
              label: Text(
                'Copy email',
                style: GoogleFonts.spaceGrotesk(color: ctx.appTextSecondary),
              ),
            ),
            TextButton.icon(
              onPressed: () async {
                final uri = Uri.parse('mailto:${u['user_email']}');
                if (await canLaunchUrl(uri)) {
                  await launchUrl(uri);
                }
              },
              icon: const Icon(
                Icons.send_outlined,
                size: 14,
                color: AppDS.accent,
              ),
              label: Text(
                'Send email',
                style: GoogleFonts.spaceGrotesk(color: AppDS.accent),
              ),
            ),
          ],
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              'Close',
              style: GoogleFonts.spaceGrotesk(color: ctx.appTextSecondary),
            ),
          ),
        ],
      ),
    );
  }

  Widget _infoRow(BuildContext context, IconData icon, String? value) {
    if (value == null || value.trim().isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 14, color: context.appTextMuted),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              value,
              style: GoogleFonts.spaceGrotesk(
                color: context.appTextPrimary,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

void detailSnack(BuildContext context, String msg) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(msg, style: const TextStyle(color: Colors.white)),
      behavior: SnackBarBehavior.floating,
      backgroundColor: AppDS.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    ),
  );
}

String detailFmtDate(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

// Strip any leading R#/L#.# prefix from a stored name so the derived code
// isn't duplicated when prepended at display time.
String stripLocationCodePrefix(String name) {
  final match = RegExp(
    r'^[RL]\d+(?:\.\d+)?\s*(?:[-·]\s*)?',
    caseSensitive: false,
  ).firstMatch(name.trim());
  if (match == null) return name.trim();
  return name.trim().substring(match.end).trim();
}
