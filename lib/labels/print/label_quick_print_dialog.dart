// label_quick_print_dialog.dart — Part of label_page.dart.
// Quick Print dialog: template chip selector + live preview + one-tap print.
// Called from list pages (stocks, reagents, etc.) with entity data pre-filled.

part of '../label_page.dart';

/// Opens the Quick Print dialog for [category] templates, pre-filling the
/// preview with [data] (keys must match the placeholder keys in the template).
/// Pass [entityId] (DB primary-key string) to fetch joined data (e.g.
/// fish_lines for Stocks) so all placeholders resolve correctly.
Future<void> showQuickPrintDialog(
  BuildContext context, {
  required String category,
  required Map<String, dynamic> data,
  String? entityId,
}) =>
    showDialog<void>(
      context: context,
      builder: (_) => _QuickPrintDialog(
          category: category, data: data, entityId: entityId),
    );

class _QuickPrintDialog extends StatefulWidget {
  final String category;
  final Map<String, dynamic> data;
  final String? entityId;
  const _QuickPrintDialog(
      {required this.category, required this.data, this.entityId});

  @override
  State<_QuickPrintDialog> createState() => _QuickPrintDialogState();
}

class _QuickPrintDialogState extends State<_QuickPrintDialog> {
  List<LabelTemplate> _templates = [];
  LabelTemplate?      _selected;
  PrinterProfile?     _activeProfile;
  Map<String, dynamic> _resolvedData = {};
  bool _loading  = true;
  bool _printing = false;

  @override
  void initState() {
    super.initState();
    _resolvedData = Map.from(widget.data);
    _load();
  }

  Future<void> _load() async {
    try {
      final futures = await Future.wait<dynamic>([
        Supabase.instance.client
            .from('label_templates')
            .select()
            .eq('tpl_category', widget.category)
            .order('tpl_created_at'),
        SharedPreferences.getInstance(),
        _fetchJoinedData(),
      ]);

      final rows    = futures[0] as List<dynamic>;
      final prefs   = futures[1] as SharedPreferences;
      final joined  = futures[2] as Map<String, dynamic>?;

      final templates = rows
          .map((r) {
            try { return LabelTemplate.fromDb(r as Map<String, dynamic>); }
            catch (_) { return null; }
          })
          .whereType<LabelTemplate>()
          .toList();

      final raw = prefs.getStringList('printer_profiles_v2') ?? [];
      final profiles = raw.map((s) {
        try { return PrinterProfile.fromJson(jsonDecode(s) as Map<String, dynamic>); }
        catch (_) { return null; }
      }).whereType<PrinterProfile>().toList();

      final activeId = prefs.getString('printer_active_profile_id');

      // Merge: joined DB row first (has fish_line_* etc.), then caller's
      // pre-converted string values override for fish_stocks_* fields.
      final merged = <String, dynamic>{};
      if (joined != null) {
        joined.forEach((k, v) {
          if (v != null) merged[k] = v.toString();
        });
      }
      merged.addAll(widget.data);

      // Inject QR deep-link if we have a numeric entity ID.
      final idStr = widget.entityId;
      if (idStr != null) {
        final id = int.tryParse(idStr);
        if (id != null && id > 0) {
          final ref = _projectRef();
          final type = _qrTypeForCategory(widget.category);
          if (type.isNotEmpty) merged['__qr__'] = QrRules.build(ref, type, id);
        }
      }

      if (!mounted) return;
      setState(() {
        _templates     = templates;
        _selected      = templates.firstOrNull;
        _activeProfile = profiles.firstWhereOrNull((p) => p.id == activeId)
            ?? profiles.firstOrNull;
        _resolvedData  = merged;
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  /// Fetches the full DB row (with joins) for categories that need it.
  /// Returns null when not applicable or on error.
  Future<Map<String, dynamic>?> _fetchJoinedData() async {
    final idStr = widget.entityId;
    if (idStr == null) return null;
    final select = _selectForCategory(widget.category);
    if (!select.contains('*,')) return null; // no join needed
    try {
      final idCol = _idColForCategory(widget.category);
      final table = _tableForEntity(widget.category);
      final row = await Supabase.instance.client
          .from(table)
          .select(select)
          .eq(idCol, idStr)
          .single();
      return _flattenJoins(row);
    } catch (_) {
      return null;
    }
  }

  Future<void> _print() async {
    final tpl = _selected;
    if (tpl == null) return;
    setState(() => _printing = true);
    try {
      final cfg    = _activeProfile?.toPrinterConfig() ?? PrinterConfig();
      final toSend = _activeProfile?.applyTo(tpl) ?? tpl;
      await _sendToPrinter(toSend, [_resolvedData], cfg);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Print failed: $e'),
          backgroundColor: AppDS.red,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ));
      }
    } finally {
      if (mounted) setState(() => _printing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: context.appSurface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      title: Row(children: [
        const Icon(Icons.print_outlined, color: AppDS.accent, size: 18),
        const SizedBox(width: 8),
        Text('Quick Print',
            style: GoogleFonts.spaceGrotesk(
                color: context.appTextPrimary, fontWeight: FontWeight.w600)),
      ]),
      content: SizedBox(
        width: 480,
        child: _loading
            ? const SizedBox(
                height: 120,
                child: Center(child: CircularProgressIndicator()))
            : _templates.isEmpty
                ? Padding(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    child: Text(
                      'No "${widget.category}" templates found.\nCreate one in the Labels section.',
                      style: GoogleFonts.spaceGrotesk(
                          color: context.appTextMuted, fontSize: 13),
                    ),
                  )
                : Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('TEMPLATE',
                          style: GoogleFonts.spaceGrotesk(
                              color: context.appTextSecondary,
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.8)),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 6,
                        children: _templates.map((t) {
                          final sel = t.id == _selected?.id;
                          return GestureDetector(
                            onTap: () => setState(() => _selected = t),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: sel
                                    ? AppDS.accent.withValues(alpha: 0.15)
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: sel ? AppDS.accent : context.appBorder,
                                  width: sel ? 1.5 : 1,
                                ),
                              ),
                              child: Text(t.name,
                                  style: GoogleFonts.spaceGrotesk(
                                      color: sel
                                          ? AppDS.accent
                                          : context.appTextSecondary,
                                      fontSize: 12,
                                      fontWeight: sel
                                          ? FontWeight.w600
                                          : FontWeight.normal)),
                            ),
                          );
                        }).toList(),
                      ),
                      if (_selected != null) ...[
                        const SizedBox(height: 20),
                        Center(
                          child: Container(
                            decoration: BoxDecoration(
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.2),
                                  blurRadius: 10,
                                  offset: const Offset(0, 3),
                                ),
                              ],
                            ),
                            child: _PreviewCanvas(
                              template: _selected!,
                              scale: (320 / _selected!.labelW).clamp(1.5, 4.0),
                              sampleData: _resolvedData,
                            ),
                          ),
                        ),
                      ],
                      if (_activeProfile != null) ...[
                        const SizedBox(height: 12),
                        Row(children: [
                          Icon(Icons.print_outlined,
                              size: 12, color: context.appTextMuted),
                          const SizedBox(width: 4),
                          Text(_activeProfile!.name,
                              style: GoogleFonts.spaceGrotesk(
                                  color: context.appTextMuted, fontSize: 11)),
                        ]),
                      ],
                    ],
                  ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text('Cancel',
              style: GoogleFonts.spaceGrotesk(color: context.appTextSecondary)),
        ),
        FilledButton.icon(
          onPressed: (_selected == null || _printing) ? null : _print,
          style: FilledButton.styleFrom(
            backgroundColor: AppDS.accent,
            foregroundColor: Colors.black,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
          icon: _printing
              ? const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.black))
              : const Icon(Icons.print, size: 16),
          label: Text('Print', style: GoogleFonts.spaceGrotesk()),
        ),
      ],
    );
  }
}
