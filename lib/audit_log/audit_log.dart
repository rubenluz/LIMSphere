// audit_log.dart - Audit Log: read-only chronological record of all system
// activity. Admin-only. Filterable by table, action, and free text search.
// Expandable rows reveal before/after values for data-change events.



import 'dart:io';
import 'package:flutter/material.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide LocalStorage;
import '/theme/theme.dart';

TextStyle _spaceGrotesk({
  TextStyle? textStyle,
  Color? color,
  Color? backgroundColor,
  double? fontSize,
  FontWeight? fontWeight,
  FontStyle? fontStyle,
  double? letterSpacing,
  double? wordSpacing,
  TextBaseline? textBaseline,
  double? height,
  Locale? locale,
  Paint? foreground,
  Paint? background,
  List<Shadow>? shadows,
  List<FontFeature>? fontFeatures,
  TextDecoration? decoration,
  Color? decorationColor,
  TextDecorationStyle? decorationStyle,
  double? decorationThickness,
}) {
  return (textStyle ?? const TextStyle()).copyWith(
    color: color,
    backgroundColor: backgroundColor,
    fontSize: fontSize,
    fontWeight: fontWeight,
    fontStyle: fontStyle,
    letterSpacing: letterSpacing,
    wordSpacing: wordSpacing,
    textBaseline: textBaseline,
    height: height,
    locale: locale,
    foreground: foreground,
    background: background,
    shadows: shadows,
    fontFeatures: fontFeatures,
    decoration: decoration,
    decorationColor: decorationColor,
    decorationStyle: decorationStyle,
    decorationThickness: decorationThickness,
  );
}

TextStyle _jetBrainsMono({
  TextStyle? textStyle,
  Color? color,
  Color? backgroundColor,
  double? fontSize,
  FontWeight? fontWeight,
  FontStyle? fontStyle,
  double? letterSpacing,
  double? wordSpacing,
  TextBaseline? textBaseline,
  double? height,
  Locale? locale,
  Paint? foreground,
  Paint? background,
  List<Shadow>? shadows,
  List<FontFeature>? fontFeatures,
  TextDecoration? decoration,
  Color? decorationColor,
  TextDecorationStyle? decorationStyle,
  double? decorationThickness,
}) {
  return (textStyle ?? const TextStyle()).copyWith(
    fontFamily: 'Consolas',
    fontFamilyFallback: const ['Courier New'],
    color: color,
    backgroundColor: backgroundColor,
    fontSize: fontSize,
    fontWeight: fontWeight,
    fontStyle: fontStyle,
    letterSpacing: letterSpacing,
    wordSpacing: wordSpacing,
    textBaseline: textBaseline,
    height: height,
    locale: locale,
    foreground: foreground,
    background: background,
    shadows: shadows,
    fontFeatures: fontFeatures,
    decoration: decoration,
    decorationColor: decorationColor,
    decorationStyle: decorationStyle,
    decorationThickness: decorationThickness,
  );
}

// ── Model ─────────────────────────────────────────────────────────────────────

class _AuditEntry {
  final int id;
  final String table;
  final int? recordId;
  final String action;
  final String? userName;
  final String? userEmail;
  final DateTime? timestamp;
  final String? oldValues;
  final String? newValues;
  final String? ipAddress;
  final String? notes;

  const _AuditEntry({
    required this.id,
    required this.table,
    this.recordId,
    required this.action,
    this.userName,
    this.userEmail,
    this.timestamp,
    this.oldValues,
    this.newValues,
    this.ipAddress,
    this.notes,
  });

  factory _AuditEntry.fromMap(Map<String, dynamic> m) {
    final userMap = m['user'] as Map?;
    return _AuditEntry(
      id: m['audit_id'] as int,
      table: m['audit_table'] as String? ?? '',
      recordId: m['audit_record_id'] as int?,
      action: m['audit_action'] as String? ?? '',
      userName: userMap?['user_name'] as String?,
      userEmail: userMap?['user_email'] as String?,
      timestamp: m['audit_timestamp'] != null
          ? DateTime.tryParse(m['audit_timestamp'] as String)
          : null,
      oldValues: m['audit_old_values'] as String?,
      newValues: m['audit_new_values'] as String?,
      ipAddress: m['audit_ip_address'] as String?,
      notes: m['audit_notes'] as String?,
    );
  }

  String get userDisplay =>
      (userName?.isNotEmpty ?? false) ? userName! : (userEmail ?? 'System');
}

// ── Helpers ───────────────────────────────────────────────────────────────────

String _formatTs(DateTime? ts) {
  if (ts == null) return '—';
  final d = ts.toLocal();
  final date =
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  final time =
      '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}:${d.second.toString().padLeft(2, '0')}';
  return '$date  $time';
}

Color _actionColor(String action) {
  switch (action.toUpperCase()) {
    case 'INSERT':
    case 'CREATE':
      return AppDS.green;
    case 'UPDATE':
      return AppDS.yellow;
    case 'DELETE':
      return AppDS.red;
    case 'LOGIN':
      return AppDS.accent;
    case 'LOGOUT':
      return AppDS.textMuted;
    default:
      return AppDS.purple;
  }
}

// ── Page ──────────────────────────────────────────────────────────────────────

class AuditLogPage extends StatefulWidget {
  const AuditLogPage({super.key});

  @override
  State<AuditLogPage> createState() => _AuditLogPageState();
}

class _AuditLogPageState extends State<AuditLogPage> {
  List<_AuditEntry> _all = [];
  List<_AuditEntry> _filtered = [];
  bool _loading = true;
  String _search = '';
  String _tableFilter = 'all';
  String _actionFilter = 'all';
  final _searchCtrl = TextEditingController();
  final Set<int> _expanded = {};
  int _limit = 200;
  bool _hasMore = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final rows = await Supabase.instance.client
          .from('audit_log')
          .select('*, user:audit_user_id(user_name, user_email)')
          .order('audit_timestamp', ascending: false)
          .limit(_limit + 1);
      if (!mounted) return;
      final list = (rows as List).cast<Map<String, dynamic>>();
      _hasMore = list.length > _limit;
      setState(() {
        _all = list.take(_limit).map(_AuditEntry.fromMap).toList();
        _loading = false;
        _applyFilters();
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Failed to load audit log: $e'),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        backgroundColor: AppDS.surface,
      ));
    }
  }

  void _applyFilters() {
    final q = _search.toLowerCase();
    setState(() {
      _filtered = _all.where((e) {
        if (_tableFilter != 'all' && e.table != _tableFilter) return false;
        if (_actionFilter != 'all' &&
            e.action.toUpperCase() != _actionFilter) { return false; }
        if (q.isEmpty) return true;
        return e.table.toLowerCase().contains(q) ||
            e.action.toLowerCase().contains(q) ||
            e.userDisplay.toLowerCase().contains(q) ||
            (e.notes?.toLowerCase().contains(q) ?? false) ||
            e.recordId?.toString() == q;
      }).toList();
    });
  }

  List<String> get _allTables {
    final t = _all.map((e) => e.table).toSet().toList()..sort();
    return t;
  }

  List<String> get _allActions {
    final a =
        _all.map((e) => e.action.toUpperCase()).toSet().toList()..sort();
    return a;
  }

  Future<void> _exportCsv() async {
    final buf = StringBuffer();
    buf.writeln(
        'ID,Timestamp,User,Table,Action,RecordID,Notes,OldValues,NewValues,IP');
    String esc(String? s) => '"${(s ?? '').replaceAll('"', '""')}"';
    for (final e in _filtered) {
      buf.writeln(
          '${e.id},${esc(_formatTs(e.timestamp))},${esc(e.userDisplay)},${esc(e.table)},${esc(e.action)},${e.recordId ?? ''},${esc(e.notes)},${esc(e.oldValues)},${esc(e.newValues)},${esc(e.ipAddress)}');
    }
    try {
      final dir = await getDownloadsDirectory() ??
          await getApplicationDocumentsDirectory();
      final file = File(
          '${dir.path}/audit_log_${DateTime.now().millisecondsSinceEpoch}.csv');
      await file.writeAsString(buf.toString());
      await OpenFilex.open(file.path);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Export failed: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      // ── Toolbar ──────────────────────────────────────────────────────────
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
              onPressed: () => Scaffold.of(context).openDrawer(),
            ),
          ],
          Icon(Icons.manage_search_outlined,
              color: context.appTextMuted, size: 18),
          const SizedBox(width: 8),
          Text('Audit Log',
              style: _spaceGrotesk(
                  color: context.appTextPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.w600)),
          const SizedBox(width: 16),
          Expanded(
            child: SizedBox(
              height: 36,
              child: TextField(
                controller: _searchCtrl,
                onChanged: (v) {
                  _search = v;
                  _applyFilters();
                },
                style: _spaceGrotesk(
                    color: context.appTextPrimary, fontSize: 13),
                decoration: InputDecoration(
                  hintText: 'Search user, table, action, record ID...',
                  hintStyle: _spaceGrotesk(
                      color: context.appTextMuted, fontSize: 13),
                  prefixIcon:
                      Icon(Icons.search, color: context.appTextMuted, size: 16),
                  suffixIcon: _search.isNotEmpty
                      ? IconButton(
                          icon: Icon(Icons.clear,
                              size: 14, color: context.appTextMuted),
                          onPressed: () {
                            _searchCtrl.clear();
                            _search = '';
                            _applyFilters();
                          })
                      : null,
                  filled: true,
                  fillColor: context.appSurface3,
                  contentPadding: EdgeInsets.zero,
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: context.appBorder)),
                  enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: context.appBorder)),
                  focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: AppDS.accent)),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          // Table filter
          SizedBox(
            height: 36,
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _tableFilter,
                dropdownColor: context.appSurface,
                style: _spaceGrotesk(
                    color: context.appTextPrimary, fontSize: 13),
                items: [
                  DropdownMenuItem(
                    value: 'all',
                    child: Text('All Tables',
                        style: _spaceGrotesk(
                            color: context.appTextSecondary, fontSize: 13)),
                  ),
                  ..._allTables.map((t) => DropdownMenuItem(
                        value: t,
                        child: Text(t,
                            style: _spaceGrotesk(
                                color: context.appTextPrimary, fontSize: 13)),
                      )),
                ],
                onChanged: (v) {
                  _tableFilter = v ?? 'all';
                  _applyFilters();
                },
              ),
            ),
          ),
          const SizedBox(width: 8),
          // Action filter
          SizedBox(
            height: 36,
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _actionFilter,
                dropdownColor: context.appSurface,
                style: _spaceGrotesk(
                    color: context.appTextPrimary, fontSize: 13),
                items: [
                  DropdownMenuItem(
                    value: 'all',
                    child: Text('All Actions',
                        style: _spaceGrotesk(
                            color: context.appTextSecondary, fontSize: 13)),
                  ),
                  ..._allActions.map((a) => DropdownMenuItem(
                        value: a,
                        child: Text(a,
                            style: _spaceGrotesk(
                                color: _actionColor(a), fontSize: 13)),
                      )),
                ],
                onChanged: (v) {
                  _actionFilter = v ?? 'all';
                  _applyFilters();
                },
              ),
            ),
          ),
          const SizedBox(width: 4),
          Tooltip(
            message: 'Export CSV',
            child: IconButton(
              icon: const Icon(Icons.download_outlined,
                  color: AppDS.textSecondary, size: 18),
              onPressed: _exportCsv,
            ),
          ),
          Tooltip(
            message: 'Refresh',
            child: IconButton(
              icon: const Icon(Icons.refresh_outlined,
                  color: AppDS.textSecondary, size: 18),
              onPressed: _load,
            ),
          ),
        ]),
      ),

      // ── Body ─────────────────────────────────────────────────────────────
      Expanded(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _filtered.isEmpty
                ? Center(
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                    const Icon(Icons.manage_search_outlined,
                        size: 48, color: AppDS.textMuted),
                    const SizedBox(height: 12),
                    Text('No audit entries found',
                        style: _spaceGrotesk(
                            color: AppDS.textMuted, fontSize: 15)),
                  ]))
                : Column(children: [
                    // ── Header row ─────────────────────────────────────────
                    Container(
                      height: 32,
                      decoration: BoxDecoration(
                        color: context.appHeaderBg,
                        border: Border(
                          top: BorderSide(color: context.appBorder),
                          bottom: BorderSide(color: context.appBorder),
                        ),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Row(children: [
                        const SizedBox(width: 20),
                        Expanded(
                            flex: 3, child: _hdr(context, 'TIMESTAMP')),
                        Expanded(flex: 2, child: _hdr(context, 'USER')),
                        Expanded(flex: 2, child: _hdr(context, 'TABLE')),
                        const SizedBox(
                            width: 90,
                            child: _HdrLabel('ACTION')),
                        const SizedBox(
                            width: 72,
                            child: _HdrLabel('RECORD')),
                        Expanded(flex: 3, child: _hdr(context, 'NOTES')),
                      ]),
                    ),
                    // ── Rows ───────────────────────────────────────────────
                    Expanded(
                      child: ListView.builder(
                        padding: EdgeInsets.zero,
                        itemCount:
                            _filtered.length + (_hasMore ? 1 : 0),
                        itemBuilder: (ctx, i) {
                          if (i == _filtered.length) {
                            return Padding(
                              padding: const EdgeInsets.all(16),
                              child: Center(
                                child: TextButton.icon(
                                  icon: const Icon(Icons.expand_more,
                                      size: 16),
                                  label: Text('Load more',
                                      style: _spaceGrotesk(
                                          fontSize: 13)),
                                  style: TextButton.styleFrom(
                                      foregroundColor: AppDS.accent),
                                  onPressed: () {
                                    _limit += 200;
                                    _load();
                                  },
                                ),
                              ),
                            );
                          }
                          final e = _filtered[i];
                          return _AuditRow(
                            entry: e,
                            isExpanded: _expanded.contains(e.id),
                            isEven: i.isEven,
                            onToggle: () => setState(() {
                              if (_expanded.contains(e.id)) {
                                _expanded.remove(e.id);
                              } else {
                                _expanded.add(e.id);
                              }
                            }),
                          );
                        },
                      ),
                    ),
                    // ── Footer count ───────────────────────────────────────
                    Container(
                      height: 30,
                      decoration: BoxDecoration(
                        color: context.appSurface2,
                        border:
                            Border(top: BorderSide(color: context.appBorder)),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      alignment: Alignment.centerLeft,
                      child: Text(
                        '${_filtered.length} entr${_filtered.length == 1 ? 'y' : 'ies'}'
                        '${_search.isNotEmpty || _tableFilter != 'all' || _actionFilter != 'all' ? ' (filtered from ${_all.length})' : ''}',
                        style: _spaceGrotesk(
                            color: context.appTextMuted, fontSize: 11),
                      ),
                    ),
                  ]),
      ),
    ]);
  }

  Widget _hdr(BuildContext context, String label) => Text(label,
      style: _spaceGrotesk(
          color: context.appTextMuted,
          fontSize: 10,
          letterSpacing: 0.8,
          fontWeight: FontWeight.w600));
}

// ── Static header label widget (used in const context) ───────────────────────

class _HdrLabel extends StatelessWidget {
  final String label;
  const _HdrLabel(this.label);

  @override
  Widget build(BuildContext context) => Text(label,
      style: _spaceGrotesk(
          color: context.appTextMuted,
          fontSize: 10,
          letterSpacing: 0.8,
          fontWeight: FontWeight.w600));
}

// ── Row widget ────────────────────────────────────────────────────────────────

class _AuditRow extends StatelessWidget {
  final _AuditEntry entry;
  final bool isExpanded;
  final bool isEven;
  final VoidCallback onToggle;

  const _AuditRow({
    required this.entry,
    required this.isExpanded,
    required this.isEven,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    final ac = _actionColor(entry.action);
    final hasDetails = (entry.oldValues?.isNotEmpty ?? false) ||
        (entry.newValues?.isNotEmpty ?? false);

    return Column(mainAxisSize: MainAxisSize.min, children: [
      InkWell(
        onTap: hasDetails ? onToggle : null,
        child: Container(
          height: 40,
          decoration: BoxDecoration(
            color: isEven
                ? context.appSurface.withValues(alpha: 0.45)
                : context.appBg,
            border: Border(
                bottom: BorderSide(
                    color: context.appBorder.withValues(alpha: 0.4))),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(children: [
            SizedBox(
              width: 20,
              child: hasDetails
                  ? Icon(
                      isExpanded
                          ? Icons.expand_less_rounded
                          : Icons.expand_more_rounded,
                      size: 14,
                      color: context.appTextMuted,
                    )
                  : const SizedBox(),
            ),
            // Timestamp
            Expanded(
              flex: 3,
              child: Text(_formatTs(entry.timestamp),
                  style: _jetBrainsMono(
                      color: context.appTextSecondary, fontSize: 11),
                  overflow: TextOverflow.ellipsis),
            ),
            // User
            Expanded(
              flex: 2,
              child: Text(entry.userDisplay,
                  style: _spaceGrotesk(
                      color: context.appTextPrimary, fontSize: 12),
                  overflow: TextOverflow.ellipsis),
            ),
            // Table
            Expanded(
              flex: 2,
              child: Text(entry.table,
                  style: _jetBrainsMono(
                      color: context.appTextSecondary, fontSize: 11),
                  overflow: TextOverflow.ellipsis),
            ),
            // Action badge
            SizedBox(
              width: 90,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: ac.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(entry.action.toUpperCase(),
                    style: _spaceGrotesk(
                        color: ac,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.5),
                    overflow: TextOverflow.ellipsis),
              ),
            ),
            // Record ID
            SizedBox(
              width: 72,
              child: entry.recordId != null
                  ? Text('#${entry.recordId}',
                      style: _jetBrainsMono(
                          color: context.appTextMuted, fontSize: 11))
                  : const SizedBox(),
            ),
            // Notes
            Expanded(
              flex: 3,
              child: Text(entry.notes ?? '',
                  style: _spaceGrotesk(
                      color: context.appTextSecondary, fontSize: 12),
                  overflow: TextOverflow.ellipsis),
            ),
          ]),
        ),
      ),
      // ── Expanded detail: before / after values ────────────────────────
      if (isExpanded && hasDetails)
        Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: context.appSurface3,
            border: Border(
                bottom: BorderSide(color: context.appBorder)),
          ),
          padding: const EdgeInsets.fromLTRB(52, 10, 16, 12),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            if (entry.oldValues?.isNotEmpty ?? false)
              Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _detailLabel('BEFORE', AppDS.red),
                      const SizedBox(height: 4),
                      SelectableText(entry.oldValues!,
                          style: _jetBrainsMono(
                              color: AppDS.red.withValues(alpha: 0.85),
                              fontSize: 11)),
                    ]),
              ),
            if ((entry.oldValues?.isNotEmpty ?? false) &&
                (entry.newValues?.isNotEmpty ?? false))
              const SizedBox(width: 20),
            if (entry.newValues?.isNotEmpty ?? false)
              Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _detailLabel('AFTER', AppDS.green),
                      const SizedBox(height: 4),
                      SelectableText(entry.newValues!,
                          style: _jetBrainsMono(
                              color: AppDS.green.withValues(alpha: 0.85),
                              fontSize: 11)),
                    ]),
              ),
          ]),
        ),
    ]);
  }

  Widget _detailLabel(String text, Color color) => Row(children: [
        Container(
          width: 8,
          height: 8,
          margin: const EdgeInsets.only(right: 6),
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        Text(text,
            style: _spaceGrotesk(
                color: color,
                fontSize: 9,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.8)),
      ]);
}
