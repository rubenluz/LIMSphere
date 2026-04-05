// label_widgets.dart — Part of label_page.dart.
// Template listing UI: _TemplatesTab, _ProfileSwitcherChip, _ConnDot,
// _CategoryHeader, _TemplateCard, _IconBtn.

part of '../label_page.dart';


// ─────────────────────────────────────────────────────────────────────────────
// Tab 1 — Templates (grouped by category)
// ─────────────────────────────────────────────────────────────────────────────
class _TemplatesTab extends StatelessWidget {
  final List<LabelTemplate> templates;
  final LabelTemplate? activeTemplate;
  final List<PrinterProfile> profiles;
  final PrinterProfile? activeProfile;
  final _ConnState connected;
  final List<Map<String, dynamic>> records;
  final String entityType;
  final void Function(LabelTemplate) onSelect;
  final void Function(LabelTemplate) onEdit;
  final void Function(LabelTemplate) onDelete;
  final void Function(LabelTemplate) onDuplicate;
  final void Function(PrinterProfile) onProfileChanged;

  const _TemplatesTab({
    required this.templates, required this.activeTemplate,
    required this.profiles, required this.activeProfile, required this.connected,
    required this.records, required this.entityType,
    required this.onSelect, required this.onEdit,
    required this.onDelete, required this.onDuplicate,
    required this.onProfileChanged,
  });

  @override
  Widget build(BuildContext context) {
    final Map<String, List<LabelTemplate>> byCategory = {};
    for (final t in templates) {
      byCategory.putIfAbsent(t.category, () => []).add(t);
    }

    return Column(children: [
      Expanded(
        child: templates.isEmpty
            ? Center(
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.view_quilt_outlined, size: 48, color: context.appTextMuted),
                  const SizedBox(height: 12),
                  Text('No templates yet',
                      style: TextStyle(fontSize: 14, color: context.appTextMuted)),
                  const SizedBox(height: 6),
                  Text('Use "Starters" to add a pre-built template, or "New Template" to build from scratch.',
                      style: TextStyle(fontSize: 12, color: context.appTextMuted)),
                ]),
              )
            : ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  for (final category in byCategory.keys) ...[
                    _CategoryHeader(category),
                    const SizedBox(height: 10),
                    for (final t in byCategory[category]!)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: _TemplateCard(
                          template: t,
                          isActive: activeTemplate?.id == t.id,
                          onSelect: () => onSelect(t),
                          onEdit: () => onEdit(t),
                          onDelete: () => onDelete(t),
                          onDuplicate: () => onDuplicate(t),
                          onPrint: () => _showPrintDialog(context, t),
                        ),
                      ),
                    const SizedBox(height: 8),
                  ],
                ],
              ),
      ),
    ]);
  }

  void _showPrintDialog(BuildContext context, LabelTemplate t) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _PrintLabelPage(
          template: t,
          profiles: profiles,
          activeProfile: activeProfile,
          onProfileChanged: onProfileChanged,
          initialRecords: records,
          entityType: t.category,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Profile switcher chip — shown in the AppBar title row
// ─────────────────────────────────────────────────────────────────────────────
class _ProfileSwitcherChip extends StatelessWidget {
  final List<PrinterProfile> profiles;
  final PrinterProfile? activeProfile;
  final void Function(PrinterProfile) onSelect;
  const _ProfileSwitcherChip({required this.profiles, required this.activeProfile, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _showMenu(context),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: context.appSurface2,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: context.appBorder),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.print_rounded, size: 12, color: AppDS.accent),
          const SizedBox(width: 6),
          Text(activeProfile?.name ?? 'No printer',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: context.appTextPrimary)),
          const SizedBox(width: 4),
          Icon(Icons.arrow_drop_down_rounded, size: 16, color: context.appTextSecondary),
        ]),
      ),
    );
  }

  void _showMenu(BuildContext context) {
    final box = context.findRenderObject() as RenderBox?;
    final offset = box?.localToGlobal(Offset.zero) ?? Offset.zero;
    final size = box?.size ?? Size.zero;
    showMenu<PrinterProfile>(
      context: context,
      color: context.appSurface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: context.appBorder),
      ),
      position: RelativeRect.fromLTRB(
        offset.dx, offset.dy + size.height + 4,
        offset.dx + size.width, 0,
      ),
      items: profiles.map((p) => PopupMenuItem<PrinterProfile>(
        value: p,
        child: Row(children: [
          Icon(Icons.print_rounded, size: 14,
              color: p.id == activeProfile?.id ? AppDS.accent : context.appTextSecondary),
          const SizedBox(width: 8),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(p.name,
                  style: TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w600,
                      color: p.id == activeProfile?.id ? AppDS.accent : context.appTextPrimary)),
              Text(p.deviceName,
                  style: TextStyle(fontSize: 10, color: context.appTextSecondary)),
            ]),
          ),
          if (p.id == activeProfile?.id)
            const Icon(Icons.check_rounded, size: 14, color: AppDS.accent),
        ]),
      )).toList(),
    ).then((p) { if (p != null) onSelect(p); });
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Single connection-state dot
// ─────────────────────────────────────────────────────────────────────────────
class _ConnDot extends StatelessWidget {
  final Color color;
  final bool lit;
  const _ConnDot(this.color, {required this.lit});

  @override
  Widget build(BuildContext context) => AnimatedContainer(
    duration: const Duration(milliseconds: 300),
    width: 7, height: 7,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      color: lit ? color : color.withValues(alpha: 0.18),
    ),
  );
}

class _CategoryHeader extends StatelessWidget {
  final String category;
  const _CategoryHeader(this.category);

  static const _icons = <String, IconData>{
    'Strains':   Icons.science_outlined,
    'Reagents':  Icons.water_drop_outlined,
    'Equipment': Icons.build_outlined,
    'Samples':   Icons.inventory_2_outlined,
    'Stocks':    Icons.set_meal_rounded,
    'General':   Icons.label_outline,
  };

  @override
  Widget build(BuildContext context) {
    final icon = _icons[category] ?? Icons.label_outline;
    return Row(children: [
      Icon(icon, size: 13, color: context.appTextSecondary),
      const SizedBox(width: 6),
      Text(category.toUpperCase(),
          style: TextStyle(fontSize: 10, letterSpacing: 1.1,
              color: context.appTextSecondary, fontWeight: FontWeight.w700)),
      const SizedBox(width: 10),
      Expanded(child: Divider(color: context.appBorder)),
    ]);
  }
}

class _TemplateCard extends StatefulWidget {
  final LabelTemplate template;
  final bool isActive;
  final VoidCallback onSelect, onEdit, onDelete, onDuplicate, onPrint;
  const _TemplateCard({
    required this.template, required this.isActive,
    required this.onSelect, required this.onEdit,
    required this.onDelete, required this.onDuplicate, required this.onPrint,
  });
  @override
  State<_TemplateCard> createState() => _TemplateCardState();
}

class _TemplateCardState extends State<_TemplateCard> {
  Map<String, dynamic>? _previewData;

  @override
  void initState() {
    super.initState();
    _fetchPreviewRow();
  }

  @override
  void didUpdateWidget(_TemplateCard old) {
    super.didUpdateWidget(old);
    if (old.template.category != widget.template.category) _fetchPreviewRow();
  }

  Future<void> _fetchPreviewRow() async {
    try {
      final table = _tableForEntity(widget.template.category);
      final rows = await Supabase.instance.client
          .from(table).select(_selectForCategory(widget.template.category)).limit(100) as List<dynamic>;
      if (!mounted || rows.isEmpty) return;
      final idx = DateTime.now().microsecondsSinceEpoch % rows.length;
      final row = _flattenJoins(rows[idx]);
      _injectQr([row], widget.template.category);
      setState(() => _previewData = row);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final data = _previewData ?? _sampleDataFor(widget.template.category);
    return GestureDetector(
      onTap: widget.onSelect,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        decoration: BoxDecoration(
          color: context.appSurface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: widget.isActive ? AppDS.accent : context.appBorder,
            width: widget.isActive ? 1.5 : 1,
          ),
          boxShadow: widget.isActive ? [BoxShadow(color: AppDS.accent.withValues(alpha: 0.15), blurRadius: 12)] : null,
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(children: [
            // Preview thumbnail — real DB data when available
            Container(
              width: 90, height: 44,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: context.appBorder),
              ),
              clipBehavior: Clip.antiAlias,
              child: FittedBox(
                fit: BoxFit.contain,
                child: _PreviewCanvas(
                  template: widget.template, scale: 1.5,
                  sampleData: data,
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(widget.template.name,
                  style: TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w600,
                    color: widget.isActive ? AppDS.accent : context.appTextPrimary,
                  )),
              const SizedBox(height: 3),
              Text('${widget.template.labelW.toInt()}×${widget.template.labelH.toInt()} mm · ${widget.template.fields.length} fields',
                  style: TextStyle(fontSize: 11, color: context.appTextSecondary)),
            ])),
            if (widget.isActive) const Icon(Icons.check_circle_rounded, color: AppDS.accent, size: 16),
            const SizedBox(width: 8),
            _IconBtn(icon: Icons.edit_outlined, onTap: widget.onEdit, tooltip: 'Edit'),
            _IconBtn(icon: Icons.copy_rounded, onTap: widget.onDuplicate, tooltip: 'Duplicate'),
            _IconBtn(icon: Icons.print_rounded, onTap: widget.onPrint, tooltip: 'Print'),
            _IconBtn(icon: Icons.delete_outline_rounded, onTap: widget.onDelete,
                tooltip: 'Delete', color: AppDS.red),
          ]),
        ),
      ),
    );
  }
}



class _IconBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final String tooltip;
  final Color color;
  const _IconBtn({required this.icon, required this.onTap, required this.tooltip, this.color = AppDS.textSecondary});

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(6),
        child: Padding(
          padding: const EdgeInsets.all(6),
          child: Icon(icon, size: 17, color: color),
        ),
      ),
    );
  }
}
