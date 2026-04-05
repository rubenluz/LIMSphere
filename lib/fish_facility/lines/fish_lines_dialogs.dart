// fish_lines_dialogs.dart - Part of fish_lines_page.dart.
// _AddLineDialog: dialog for creating a new fish line (name, type, status).
part of 'fish_lines_page.dart';

// ─── ADD LINE DIALOG ─────────────────────────────────────────────────────────
class _AddLineDialog extends StatefulWidget {
  final ValueChanged<FishLine> onAdd;
  const _AddLineDialog({required this.onAdd});

  @override
  State<_AddLineDialog> createState() => _AddLineDialogState();
}

class _AddLineDialogState extends State<_AddLineDialog> {
  final _nameCtrl  = TextEditingController();
  final _aliasCtrl = TextEditingController();
  final _geneCtrl  = TextEditingController();
  final _labCtrl   = TextEditingController();
  String _type     = 'transgenic';
  String _status   = 'active';
  String _zygosity = 'heterozygous';
  bool   _saving   = false;
  String? _error;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _aliasCtrl.dispose();
    _geneCtrl.dispose();
    _labCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      setState(() => _error = 'Line name is required.');
      return;
    }
    setState(() { _saving = true; _error = null; });
    try {
      final resp = await Supabase.instance.client
          .from('fish_lines')
          .insert({
            FishSch.lineName:         name,
            FishSch.lineAlias:        _aliasCtrl.text.isEmpty ? null : _aliasCtrl.text.trim(),
            FishSch.lineType:         _type,
            FishSch.lineStatus:       _status,
            FishSch.lineZygosity:     _zygosity,
            FishSch.lineAffectedGene: _geneCtrl.text.isEmpty ? null : _geneCtrl.text.trim(),
            FishSch.lineOriginLab:    _labCtrl.text.isEmpty  ? null : _labCtrl.text.trim(),
          })
          .select()
          .single();
      final newId = resp[FishSch.lineId] as int?;
      final respWithQr = Map<String, dynamic>.from(resp);
      if (newId != null) {
        final qrcode = QrRules.build(
            SupabaseManager.projectRef ?? 'local', 'fish_lines', newId);
        await Supabase.instance.client
            .from('fish_lines')
            .update({FishSch.lineQrcode: qrcode})
            .eq(FishSch.lineId, newId);
        respWithQr[FishSch.lineQrcode] = qrcode;
      }
      widget.onAdd(FishLine.fromMap(respWithQr));
      if (mounted) { Navigator.pop(context); }
    } catch (e) {
      setState(() { _saving = false; _error = e.toString(); });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppDS.surface2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: AppDS.border2)),
      title: Text('New Fish Line',
        style: GoogleFonts.spaceGrotesk(
          fontSize: 16, fontWeight: FontWeight.w700, color: AppDS.textPrimary)),
      content: SizedBox(
        width: 440,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_error != null) ...[
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppDS.red.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppDS.red.withValues(alpha: 0.4)),
                ),
                child: Text(_error!,
                  style: GoogleFonts.spaceGrotesk(color: AppDS.red, fontSize: 12)),
              ),
              const SizedBox(height: 8),
            ],
            _f('Line Name (e.g. Tg(mpx:GFP)uwm1)', _nameCtrl),
            const SizedBox(height: 8),
            _f('Alias', _aliasCtrl),
            const SizedBox(height: 8),
            _f('Affected Gene', _geneCtrl),
            const SizedBox(height: 8),
            _f('Origin Lab', _labCtrl),
            const SizedBox(height: 8),
            Row(children: [
              Expanded(child: _dd('Type', _type,
                ['WT', 'transgenic', 'mutant', 'CRISPR', 'KO', 'KI'],
                (v) => setState(() => _type = v ?? _type))),
              const SizedBox(width: 8),
              Expanded(child: _dd('Status', _status,
                ['active', 'archived', 'cryopreserved', 'lost'],
                (v) => setState(() => _status = v ?? _status))),
            ]),
            const SizedBox(height: 8),
            _dd('Zygosity', _zygosity,
              ['homozygous', 'heterozygous', 'unknown'],
              (v) => setState(() => _zygosity = v ?? _zygosity)),
          ],
        ),
      ),
      actions: [
        OutlinedButton(
          onPressed: _saving ? null : () => Navigator.pop(context),
          child: const Text('Cancel')),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppDS.accent, foregroundColor: AppDS.bg),
          onPressed: _saving ? null : _submit,
          child: _saving
              ? const SizedBox(width: 16, height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2))
              : const Text('Add Line'),
        ),
      ],
    );
  }

  Widget _f(String label, TextEditingController ctrl) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label, style: GoogleFonts.spaceGrotesk(
        fontSize: 11, color: AppDS.textMuted, fontWeight: FontWeight.w700)),
      const SizedBox(height: 3),
      TextField(controller: ctrl,
        style: GoogleFonts.spaceGrotesk(color: AppDS.textPrimary, fontSize: 13),
        decoration: InputDecoration(
          isDense: true,
          filled: true, fillColor: AppDS.surface3,
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(6),
            borderSide: const BorderSide(color: AppDS.border)),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(6),
            borderSide: const BorderSide(color: AppDS.accent, width: 1.5)),
        )),
    ],
  );

  Widget _dd(String label, String value, List<String> opts, ValueChanged<String?> cb) =>
    Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: GoogleFonts.spaceGrotesk(
          fontSize: 11, color: AppDS.textMuted, fontWeight: FontWeight.w700)),
        const SizedBox(height: 3),
        DropdownButtonFormField<String>(
          initialValue: opts.contains(value) ? value : opts.first,
          dropdownColor: AppDS.surface2,
          style: GoogleFonts.spaceGrotesk(color: AppDS.textPrimary, fontSize: 13),
          items: opts.map((v) => DropdownMenuItem(value: v, child: Text(v))).toList(),
          onChanged: cb,
          decoration: InputDecoration(
            isDense: true,
            filled: true, fillColor: AppDS.surface3,
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(6),
              borderSide: const BorderSide(color: AppDS.border)),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(6),
              borderSide: const BorderSide(color: AppDS.accent, width: 1.5)),
          )),
      ],
    );
}