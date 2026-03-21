part of 'printing_page.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Starter templates — pre-built templates users can add to their collection
// ─────────────────────────────────────────────────────────────────────────────

final _kStarterTemplates = [
  // ── Strains ──────────────────────────────────────────────────────────────
  LabelTemplate(
    id: 'strain_default', name: 'Strain Label 62×30', category: 'Strains',
    labelW: 62, labelH: 30,
    fields: [
      LabelField(id: 'f1', type: LabelFieldType.text,
          content: '{strain_code}', x: 4, y: 3, w: 100, h: 14,
          fontSize: 11, fontWeight: FontWeight.bold, isPlaceholder: true),
      LabelField(id: 'f2', type: LabelFieldType.text,
          content: '{strain_species}', x: 4, y: 16, w: 120, h: 10,
          fontSize: 8, isPlaceholder: true),
      LabelField(id: 'f3', type: LabelFieldType.qrcode,
          content: '{strain_code}', x: 130, y: 2, w: 26, h: 26, isPlaceholder: true),
    ],
  ),
  LabelTemplate(
    id: 'strain_small', name: 'Strain ID Label 62×20', category: 'Strains',
    labelW: 62, labelH: 20,
    fields: [
      LabelField(id: 'f1', type: LabelFieldType.text,
          content: '{strain_code}', x: 4, y: 4, w: 80, h: 12,
          fontSize: 9, fontWeight: FontWeight.bold, isPlaceholder: true),
      LabelField(id: 'f2', type: LabelFieldType.barcode,
          content: '{strain_code}', x: 90, y: 2, w: 60, h: 16, isPlaceholder: true),
    ],
  ),
  // ── Reagents ─────────────────────────────────────────────────────────────
  LabelTemplate(
    id: 'reagent_default', name: 'Reagent Label 62×30', category: 'Reagents',
    labelW: 62, labelH: 30,
    fields: [
      LabelField(id: 'f1', type: LabelFieldType.text,
          content: '{reagent_code}', x: 4, y: 2, w: 100, h: 9,
          fontSize: 8, fontWeight: FontWeight.bold, isPlaceholder: true),
      LabelField(id: 'f2', type: LabelFieldType.text,
          content: '{reagent_name}', x: 4, y: 12, w: 120, h: 10,
          fontSize: 7, isPlaceholder: true),
      LabelField(id: 'f3', type: LabelFieldType.text,
          content: 'Lot: {reagent_lot}', x: 4, y: 21, w: 80, h: 7,
          fontSize: 6, isPlaceholder: true),
      LabelField(id: 'f4', type: LabelFieldType.qrcode,
          content: '{reagent_code}', x: 130, y: 2, w: 26, h: 26, isPlaceholder: true),
    ],
  ),
  LabelTemplate(
    id: 'reagent_vial', name: 'Reagent Vial 38×20', category: 'Reagents',
    labelW: 38, labelH: 20,
    fields: [
      LabelField(id: 'f1', type: LabelFieldType.text,
          content: '{reagent_code}', x: 3, y: 2, w: 70, h: 9,
          fontSize: 8, fontWeight: FontWeight.bold, isPlaceholder: true),
      LabelField(id: 'f2', type: LabelFieldType.text,
          content: '{reagent_lot}', x: 3, y: 12, w: 70, h: 7,
          fontSize: 6, isPlaceholder: true),
    ],
  ),
  // ── Equipment ────────────────────────────────────────────────────────────
  LabelTemplate(
    id: 'equipment_default', name: 'Equipment Tag 62×30', category: 'Equipment',
    labelW: 62, labelH: 30,
    fields: [
      LabelField(id: 'f1', type: LabelFieldType.text,
          content: '{eq_code}', x: 4, y: 2, w: 100, h: 10,
          fontSize: 9, fontWeight: FontWeight.bold, isPlaceholder: true),
      LabelField(id: 'f2', type: LabelFieldType.text,
          content: '{eq_name}', x: 4, y: 13, w: 120, h: 9,
          fontSize: 7, isPlaceholder: true),
      LabelField(id: 'f3', type: LabelFieldType.text,
          content: 'S/N: {eq_serial}', x: 4, y: 22, w: 100, h: 7,
          fontSize: 6, isPlaceholder: true),
      LabelField(id: 'f4', type: LabelFieldType.qrcode,
          content: '{eq_code}', x: 130, y: 2, w: 26, h: 26, isPlaceholder: true),
    ],
  ),
  // ── Samples ──────────────────────────────────────────────────────────────
  LabelTemplate(
    id: 'sample_default', name: 'Sample Label 62×30', category: 'Samples',
    labelW: 62, labelH: 30,
    fields: [
      LabelField(id: 'f1', type: LabelFieldType.text,
          content: '{sample_code}', x: 4, y: 2, w: 100, h: 10,
          fontSize: 9, fontWeight: FontWeight.bold, isPlaceholder: true),
      LabelField(id: 'f2', type: LabelFieldType.text,
          content: '{sample_type}', x: 4, y: 13, w: 100, h: 9,
          fontSize: 7, isPlaceholder: true),
      LabelField(id: 'f3', type: LabelFieldType.text,
          content: '{sample_date}', x: 4, y: 22, w: 100, h: 7,
          fontSize: 6, isPlaceholder: true),
      LabelField(id: 'f4', type: LabelFieldType.qrcode,
          content: '{sample_code}', x: 130, y: 2, w: 26, h: 26, isPlaceholder: true),
    ],
  ),
  LabelTemplate(
    id: 'sample_tube', name: 'Sample Tube 29×90', category: 'Samples',
    labelW: 29, labelH: 90,
    fields: [
      LabelField(id: 'f1', type: LabelFieldType.text,
          content: '{sample_code}', x: 3, y: 4, w: 60, h: 11,
          fontSize: 9, fontWeight: FontWeight.bold, isPlaceholder: true),
      LabelField(id: 'f2', type: LabelFieldType.text,
          content: '{sample_type}', x: 3, y: 17, w: 60, h: 9,
          fontSize: 7, isPlaceholder: true),
      LabelField(id: 'f3', type: LabelFieldType.text,
          content: '{sample_date}', x: 3, y: 27, w: 60, h: 8,
          fontSize: 6, isPlaceholder: true),
      LabelField(id: 'f4', type: LabelFieldType.barcode,
          content: '{sample_code}', x: 3, y: 40, w: 55, h: 40, isPlaceholder: true),
    ],
  ),
];

// ─────────────────────────────────────────────────────────────────────────────
// Starters dialog — pick a pre-built template to add to your collection
// ─────────────────────────────────────────────────────────────────────────────
class _StartersDialog extends StatelessWidget {
  final void Function(LabelTemplate) onSelect;
  const _StartersDialog({required this.onSelect});

  @override
  Widget build(BuildContext context) {
    final byCategory = <String, List<LabelTemplate>>{};
    for (final t in _kStarterTemplates) {
      byCategory.putIfAbsent(t.category, () => []).add(t);
    }
    return Dialog(
      backgroundColor: context.appSurface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520, maxHeight: 580),
        child: Column(children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 12, 12),
            child: Row(children: [
              const Icon(Icons.library_books_outlined, size: 18, color: AppDS.accent),
              const SizedBox(width: 10),
              const Expanded(child: Text('Starter Templates',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppDS.textPrimary))),
              const Text('Pick one to add to your collection',
                  style: TextStyle(fontSize: 11, color: AppDS.textSecondary)),
              const SizedBox(width: 12),
              IconButton(
                icon: const Icon(Icons.close, size: 18, color: AppDS.textSecondary),
                onPressed: () => Navigator.pop(context),
              ),
            ]),
          ),
          Divider(height: 1, color: context.appBorder),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                for (final category in byCategory.keys) ...[
                  _CategoryHeader(category),
                  const SizedBox(height: 8),
                  for (final t in byCategory[category]!)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: _StarterCard(
                        template: t,
                        onAdd: () {
                          final cloned = t.clone();
                          cloned.id = 'tpl_${DateTime.now().millisecondsSinceEpoch}';
                          Navigator.pop(context);
                          onSelect(cloned);
                        },
                      ),
                    ),
                  const SizedBox(height: 4),
                ],
              ],
            ),
          ),
        ]),
      ),
    );
  }
}

class _StarterCard extends StatelessWidget {
  final LabelTemplate template;
  final VoidCallback onAdd;
  const _StarterCard({required this.template, required this.onAdd});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: context.appSurface2,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: context.appBorder),
      ),
      padding: const EdgeInsets.all(12),
      child: Row(children: [
        Container(
          width: 80, height: 40,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: context.appBorder),
          ),
          clipBehavior: Clip.antiAlias,
          child: FittedBox(
            fit: BoxFit.contain,
            child: _PreviewCanvas(
              template: template, scale: 1.5,
              sampleData: _sampleDataFor(template.category),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(template.name,
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: context.appTextPrimary)),
          Text('${template.labelW.toInt()}×${template.labelH.toInt()} mm · ${template.fields.length} fields',
              style: TextStyle(fontSize: 10, color: context.appTextSecondary)),
        ])),
        const SizedBox(width: 12),
        OutlinedButton(
          style: OutlinedButton.styleFrom(
            foregroundColor: AppDS.accent,
            side: const BorderSide(color: AppDS.accent),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            minimumSize: Size.zero,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(7)),
          ),
          onPressed: onAdd,
          child: const Text('Add', style: TextStyle(fontSize: 12)),
        ),
      ]),
    );
  }
}
