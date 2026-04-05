// sops_widgets.dart - Part of sops_page.dart.
// _SopCard: document list tile with type/status badges and action buttons.
// _SopDialog: full add/edit dialog with file upload, tags, metadata fields.
// Helpers: _Badge, _MetaItem, _ActionBtn, _FilterChip, _Field, _DropField,
//          _DateField, _FileChip, _FileTypeChip.
part of 'sops_page.dart';

// ═════════════════════════════════════════════════════════════════════════════
// SOP Card
// ═════════════════════════════════════════════════════════════════════════════
class _SopCard extends StatelessWidget {
  final FacilitySop  sop;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback? onOpenPdf;
  final VoidCallback? onOpenTxt;
  final VoidCallback? onOpenDoc;

  const _SopCard({
    required this.sop,
    required this.onEdit,
    required this.onDelete,
    this.onOpenPdf,
    this.onOpenTxt,
    this.onOpenDoc,
  });

  @override
  Widget build(BuildContext context) {
    final reviewWarning = sop.isReviewOverdue
        ? AppDS.red
        : sop.isReviewSoon
            ? AppDS.yellow
            : null;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: context.appSurface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: reviewWarning != null
              ? reviewWarning.withValues(alpha: 0.45)
              : context.appBorder,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Wrap(
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 8,
                    runSpacing: 4,
                    children: [
                      Text(
                        sop.name,
                        style: GoogleFonts.spaceGrotesk(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: context.appTextPrimary,
                        ),
                      ),
                      if (sop.code != null)
                        Text(
                          sop.code!,
                          style: GoogleFonts.jetBrainsMono(
                              fontSize: 11, color: AppDS.accent),
                        ),
                      if (sop.version != null)
                        Text(
                          'v${sop.version}',
                          style: GoogleFonts.jetBrainsMono(
                              fontSize: 11, color: context.appTextMuted),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Wrap(
                  spacing: 6,
                  children: [
                    _Badge(
                        label: FacilitySop.typeLabel(sop.type),
                        color: _DS.typeColor(sop.type)),
                    _Badge(
                        label: FacilitySop.statusLabel(sop.status),
                        color: _DS.statusColor(sop.status)),
                  ],
                ),
              ],
            ),

            // Meta
            if (_hasMeta) ...[
              const SizedBox(height: 7),
              Wrap(
                spacing: 16,
                runSpacing: 4,
                children: [
                  if (sop.category != null)
                    _MetaItem(Icons.folder_outlined, sop.category!),
                  if (sop.responsible != null)
                    _MetaItem(Icons.person_outline, sop.responsible!),
                  if (sop.author != null)
                    _MetaItem(Icons.edit_outlined, 'Author: ${sop.author}'),
                  if (sop.reviewDate != null)
                    _MetaItem(
                      Icons.event_outlined,
                      'Review: ${_dateFmt.format(sop.reviewDate!)}',
                      color: reviewWarning,
                    ),
                  if (sop.effectiveDate != null)
                    _MetaItem(Icons.check_circle_outline,
                        'Effective: ${_dateFmt.format(sop.effectiveDate!)}'),
                ],
              ),
            ],

            // Description
            if (sop.description != null && sop.description!.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                sop.description!,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.spaceGrotesk(
                    fontSize: 12, color: context.appTextSecondary),
              ),
            ],

            // Tags (coloured — same tag text = same colour)
            if (sop.tags != null && sop.tags!.isNotEmpty) ...[
              const SizedBox(height: 6),
              Wrap(
                spacing: 6,
                runSpacing: 4,
                children: sop.tags!
                    .split(',')
                    .map((t) => t.trim())
                    .where((t) => t.isNotEmpty)
                    .map((t) {
                      final c = _tagColor(t);
                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: c.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: c.withValues(alpha: 0.35)),
                        ),
                        child: Text(t,
                            style: GoogleFonts.spaceGrotesk(
                                fontSize: 10, fontWeight: FontWeight.w600, color: c)),
                      );
                    })
                    .toList(),
              ),
            ],

            // File chips (one per slot)
            if (sop.hasAnyFile) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: [
                  if (sop.hasPdfFile)
                    _FileTypeChip(
                      icon: Icons.picture_as_pdf_outlined,
                      name: sop.fileName ?? 'document.pdf',
                      size: sop.pdfFileSizeLabel,
                      color: AppDS.red,
                    ),
                  if (sop.hasTxtFile)
                    _FileTypeChip(
                      icon: Icons.text_snippet_outlined,
                      name: sop.txtFileName ?? 'document.txt',
                      size: sop.txtFileSizeLabel,
                      color: AppDS.green,
                    ),
                  if (sop.hasDocFile)
                    _FileTypeChip(
                      icon: Icons.article_outlined,
                      name: sop.docFileName ?? 'document.docx',
                      size: sop.docFileSizeLabel,
                      color: const Color(0xFF2B5EB8),
                    ),
                ],
              ),
            ],

            // Actions
            const SizedBox(height: 10),
            Row(
              children: [
                _ActionBtn(icon: Icons.edit_outlined, label: 'Edit',
                    color: context.appTextSecondary, onTap: onEdit),
                if (onOpenPdf != null) ...[
                  const SizedBox(width: 8),
                  _ActionBtn(icon: Icons.picture_as_pdf_outlined, label: 'PDF',
                      color: AppDS.accent, onTap: onOpenPdf!),
                ],
                if (onOpenTxt != null) ...[
                  const SizedBox(width: 8),
                  _ActionBtn(icon: Icons.text_snippet_outlined, label: 'TXT',
                      color: AppDS.accent, onTap: onOpenTxt!),
                ],
                if (onOpenDoc != null) ...[
                  const SizedBox(width: 8),
                  _ActionBtn(icon: Icons.article_outlined, label: 'DOC',
                      color: AppDS.accent, onTap: onOpenDoc!),
                ],
                const Spacer(),
                _ActionBtn(icon: Icons.delete_outline, label: 'Delete',
                    color: AppDS.red, onTap: onDelete),
              ],
            ),
          ],
        ),
      ),
    );
  }

  bool get _hasMeta =>
      sop.category != null ||
      sop.responsible != null ||
      sop.author != null ||
      sop.reviewDate != null ||
      sop.effectiveDate != null;
}

// ═════════════════════════════════════════════════════════════════════════════
// Add / Edit Dialog
// ═════════════════════════════════════════════════════════════════════════════
class _SopDialog extends StatefulWidget {
  final FacilitySop? sop;
  final String sopContext;
  const _SopDialog({this.sop, required this.sopContext});

  @override
  State<_SopDialog> createState() => _SopDialogState();
}

class _SopDialogState extends State<_SopDialog> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _name;
  late final TextEditingController _code;
  late final TextEditingController _version;
  late final TextEditingController _category;
  late final TextEditingController _description;
  late final TextEditingController _responsible;
  late final TextEditingController _author;
  late final TextEditingController _lastUpdatedBy;
  late final TextEditingController _revisionNotes;
  late final TextEditingController _tags;

  String    _type   = 'sop';
  String    _status = 'draft';
  DateTime? _effectiveDate;
  DateTime? _reviewDate;
  DateTime? _lastReviewed;

  // PDF slot
  Uint8List? _pdfBytes;
  String?    _pdfName;
  bool       _clearPdf = false;
  // TXT slot
  Uint8List? _txtBytes;
  String?    _txtName;
  bool       _clearTxt = false;
  // DOC/DOCX slot
  Uint8List? _docBytes;
  String?    _docName;
  bool       _clearDoc = false;

  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final s = widget.sop;
    _name          = TextEditingController(text: s?.name ?? '');
    _code          = TextEditingController(text: s?.code ?? '');
    _version       = TextEditingController(text: s?.version ?? '1.0');
    _category      = TextEditingController(text: s?.category ?? '');
    _description   = TextEditingController(text: s?.description ?? '');
    _responsible   = TextEditingController(text: s?.responsible ?? '');
    _author        = TextEditingController(text: s?.author ?? '');
    _lastUpdatedBy = TextEditingController(text: s?.lastUpdatedBy ?? '');
    _revisionNotes = TextEditingController(text: s?.revisionNotes ?? '');
    _tags          = TextEditingController(text: s?.tags ?? '');
    _type          = s?.type   ?? 'sop';
    _status        = s?.status ?? 'draft';
    _effectiveDate = s?.effectiveDate;
    _reviewDate    = s?.reviewDate;
    _lastReviewed  = s?.lastReviewed;
  }

  @override
  void dispose() {
    for (final c in [
      _name, _code, _version, _category, _description,
      _responsible, _author, _lastUpdatedBy, _revisionNotes, _tags,
    ]) { c.dispose(); }
    super.dispose();
  }

  void _snack(String msg, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: TextStyle(color: context.appTextPrimary)),
      backgroundColor: isError ? AppDS.red : context.appSurface3,
    ));
  }

  Future<void> _pickPdf() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom, allowedExtensions: ['pdf'], withData: true);
    if (result == null || result.files.isEmpty || result.files.first.bytes == null) return;
    setState(() { _pdfBytes = result.files.first.bytes; _pdfName = result.files.first.name; _clearPdf = false; });
  }

  Future<void> _pickTxt() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom, allowedExtensions: ['txt'], withData: true);
    if (result == null || result.files.isEmpty || result.files.first.bytes == null) return;
    setState(() { _txtBytes = result.files.first.bytes; _txtName = result.files.first.name; _clearTxt = false; });
  }

  Future<void> _pickDoc() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom, allowedExtensions: ['doc', 'docx'], withData: true);
    if (result == null || result.files.isEmpty || result.files.first.bytes == null) return;
    setState(() { _docBytes = result.files.first.bytes; _docName = result.files.first.name; _clearDoc = false; });
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      final isEdit = widget.sop?.id != null;
      final data = <String, dynamic>{
        SopSch.name:          _name.text.trim(),
        SopSch.code:          _code.text.trim().isEmpty          ? null : _code.text.trim(),
        SopSch.version:       _version.text.trim().isEmpty       ? null : _version.text.trim(),
        SopSch.type:          _type,
        SopSch.category:      _category.text.trim().isEmpty      ? null : _category.text.trim(),
        SopSch.status:        _status,
        SopSch.description:   _description.text.trim().isEmpty   ? null : _description.text.trim(),
        SopSch.tags:          _tags.text.trim().isEmpty          ? null : _tags.text.trim(),
        SopSch.responsible:   _responsible.text.trim().isEmpty   ? null : _responsible.text.trim(),
        SopSch.author:        _author.text.trim().isEmpty        ? null : _author.text.trim(),
        SopSch.lastUpdatedBy: _lastUpdatedBy.text.trim().isEmpty ? null : _lastUpdatedBy.text.trim(),
        SopSch.revisionNotes: _revisionNotes.text.trim().isEmpty ? null : _revisionNotes.text.trim(),
        SopSch.context:       widget.sopContext,
        SopSch.effectiveDate: _effectiveDate?.toIso8601String().substring(0, 10),
        SopSch.reviewDate:    _reviewDate?.toIso8601String().substring(0, 10),
        SopSch.lastReviewed:  _lastReviewed?.toIso8601String().substring(0, 10),
        SopSch.updatedAt:     DateTime.now().toIso8601String(),
      };

      int sopId;
      if (isEdit) {
        await Supabase.instance.client
            .from(SopSch.table)
            .update(data)
            .eq(SopSch.id, widget.sop!.id!);
        sopId = widget.sop!.id!;
      } else {
        final row = await Supabase.instance.client
            .from(SopSch.table)
            .insert(data)
            .select(SopSch.id)
            .single();
        sopId = row[SopSch.id] as int;
      }

      final storage = Supabase.instance.client.storage.from(SopSch.bucket);
      final db      = Supabase.instance.client.from(SopSch.table);

      // ── QR code ───────────────────────────────────────────────────────────
      final qrcode = QrRules.build(
          SupabaseManager.projectRef ?? 'local', 'sops', sopId);
      await db.update({SopSch.qrcode: qrcode}).eq(SopSch.id, sopId);

      // ── PDF slot ──────────────────────────────────────────────────────────
      if (_clearPdf && widget.sop?.hasPdfFile == true) {
        await storage.remove([widget.sop!.filePath!]);
        await db.update({SopSch.filePath: null, SopSch.fileName: null,
                         SopSch.fileSize: null, SopSch.fileMime: null})
            .eq(SopSch.id, sopId);
      } else if (_pdfBytes != null && _pdfName != null) {
        if (isEdit && widget.sop?.hasPdfFile == true) await storage.remove([widget.sop!.filePath!]);
        final path = '$sopId/pdf_$_pdfName';
        await storage.uploadBinary(path, _pdfBytes!,
            fileOptions: const FileOptions(contentType: 'application/pdf', upsert: true));
        await db.update({SopSch.filePath: path, SopSch.fileName: _pdfName,
                         SopSch.fileSize: _pdfBytes!.length, SopSch.fileMime: 'application/pdf'})
            .eq(SopSch.id, sopId);
      }

      // ── TXT slot ──────────────────────────────────────────────────────────
      if (_clearTxt && widget.sop?.hasTxtFile == true) {
        await storage.remove([widget.sop!.txtFilePath!]);
        await db.update({SopSch.txtFilePath: null, SopSch.txtFileName: null,
                         SopSch.txtFileSize: null})
            .eq(SopSch.id, sopId);
      } else if (_txtBytes != null && _txtName != null) {
        if (isEdit && widget.sop?.hasTxtFile == true) await storage.remove([widget.sop!.txtFilePath!]);
        final path = '$sopId/txt_$_txtName';
        await storage.uploadBinary(path, _txtBytes!,
            fileOptions: const FileOptions(contentType: 'text/plain', upsert: true));
        await db.update({SopSch.txtFilePath: path, SopSch.txtFileName: _txtName,
                         SopSch.txtFileSize: _txtBytes!.length})
            .eq(SopSch.id, sopId);
      }

      // ── DOC slot ──────────────────────────────────────────────────────────
      if (_clearDoc && widget.sop?.hasDocFile == true) {
        await storage.remove([widget.sop!.docFilePath!]);
        await db.update({SopSch.docFilePath: null, SopSch.docFileName: null,
                         SopSch.docFileSize: null})
            .eq(SopSch.id, sopId);
      } else if (_docBytes != null && _docName != null) {
        if (isEdit && widget.sop?.hasDocFile == true) await storage.remove([widget.sop!.docFilePath!]);
        final path = '$sopId/doc_$_docName';
        final mime = (_docName!.toLowerCase().endsWith('.doc'))
            ? 'application/msword'
            : 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
        await storage.uploadBinary(path, _docBytes!,
            fileOptions: FileOptions(contentType: mime, upsert: true));
        await db.update({SopSch.docFilePath: path, SopSch.docFileName: _docName,
                         SopSch.docFileSize: _docBytes!.length})
            .eq(SopSch.id, sopId);
      }

      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      _snack('Save failed: $e', isError: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.sop != null;
    return Dialog(
      backgroundColor: context.appSurface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 640, maxHeight: 820),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Title bar
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              decoration: BoxDecoration(
                color: context.appSurface2,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
                border: Border(bottom: BorderSide(color: context.appBorder)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.menu_book_outlined,
                      size: 18, color: AppDS.accent),
                  const SizedBox(width: 10),
                  Text(
                    isEdit ? 'Edit SOP' : 'New SOP',
                    style: GoogleFonts.spaceGrotesk(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: context.appTextPrimary,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: () => Navigator.pop(context, false),
                    icon: Icon(Icons.close,
                        size: 18, color: context.appTextMuted),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
            ),

            // Form
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Name + Code
                      Row(children: [
                        Expanded(
                          flex: 3,
                          child: _Field(
                            label: 'Name *',
                            controller: _name,
                            validator: (v) =>
                                (v == null || v.trim().isEmpty) ? 'Required' : null,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _Field(
                              label: 'Code',
                              controller: _code,
                              hint: 'SOP-001'),
                        ),
                      ]),
                      const SizedBox(height: 12),

                      // Type + Status + Version
                      Row(children: [
                        Expanded(
                          child: _DropField(
                            label: 'Type',
                            value: _type,
                            options: FacilitySop.types,
                            labelOf: FacilitySop.typeLabel,
                            onChanged: (v) =>
                                setState(() => _type = v ?? 'sop'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _DropField(
                            label: 'Status',
                            value: _status,
                            options: FacilitySop.statuses,
                            labelOf: FacilitySop.statusLabel,
                            onChanged: (v) =>
                                setState(() => _status = v ?? 'draft'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        SizedBox(
                          width: 90,
                          child: _Field(
                              label: 'Version',
                              controller: _version,
                              hint: '1.0'),
                        ),
                      ]),
                      const SizedBox(height: 12),

                      // Category + Responsible
                      Row(children: [
                        Expanded(
                          child: _Field(
                              label: 'Category',
                              controller: _category,
                              hint: 'Biosafety, Husbandry…'),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _Field(
                              label: 'Responsible',
                              controller: _responsible),
                        ),
                      ]),
                      const SizedBox(height: 12),

                      // Author + Last Updated By
                      Row(children: [
                        Expanded(
                          child: _Field(
                              label: 'Author', controller: _author),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _Field(
                              label: 'Last Updated By',
                              controller: _lastUpdatedBy),
                        ),
                      ]),
                      const SizedBox(height: 12),

                      // Dates
                      Row(children: [
                        Expanded(
                          child: _DateField(
                            label: 'Effective Date',
                            value: _effectiveDate,
                            onPick: (d) =>
                                setState(() => _effectiveDate = d),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _DateField(
                            label: 'Review Date',
                            value: _reviewDate,
                            onPick: (d) =>
                                setState(() => _reviewDate = d),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _DateField(
                            label: 'Last Reviewed',
                            value: _lastReviewed,
                            onPick: (d) =>
                                setState(() => _lastReviewed = d),
                          ),
                        ),
                      ]),
                      const SizedBox(height: 12),

                      // Description
                      _Field(
                        label: 'Description',
                        controller: _description,
                        maxLines: 3,
                      ),
                      const SizedBox(height: 12),

                      // Tags
                      _Field(
                        label: 'Tags',
                        controller: _tags,
                        hint: 'comma-separated, e.g. animal, biosafety',
                      ),
                      const SizedBox(height: 12),

                      // Revision Notes
                      _Field(
                        label: 'Revision Notes',
                        controller: _revisionNotes,
                        maxLines: 2,
                      ),
                      const SizedBox(height: 16),

                      // File
                      _buildFileSection(),
                    ],
                  ),
                ),
              ),
            ),

            // Footer
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 20, vertical: 12),
              decoration: BoxDecoration(
                border: Border(top: BorderSide(color: context.appBorder)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: _saving
                        ? null
                        : () => Navigator.pop(context, false),
                    child: Text('Cancel',
                        style: GoogleFonts.spaceGrotesk(
                            color: context.appTextSecondary)),
                  ),
                  const SizedBox(width: 10),
                  ElevatedButton(
                    onPressed: _saving ? null : _save,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppDS.accent,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 10),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8)),
                    ),
                    child: _saving
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white))
                        : Text('Save',
                            style: GoogleFonts.spaceGrotesk(
                                fontWeight: FontWeight.w600)),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFileSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Attachments',
            style: GoogleFonts.spaceGrotesk(
                fontSize: 11, fontWeight: FontWeight.w700,
                color: context.appTextMuted, letterSpacing: 0.5)),
        const SizedBox(height: 6),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: _buildSlot(
              label: 'PDF',
              icon: Icons.picture_as_pdf_outlined,
              color: AppDS.red,
              existingName: widget.sop?.hasPdfFile == true && !_clearPdf
                  ? widget.sop!.fileName ?? 'document.pdf' : null,
              existingSize: widget.sop?.hasPdfFile == true && !_clearPdf
                  ? widget.sop!.pdfFileSizeLabel : null,
              newName:  _pdfName,
              newBytes: _pdfBytes,
              onPick:   _pickPdf,
              onRemoveExisting: () => setState(() => _clearPdf = true),
              onRemoveNew: () => setState(() { _pdfBytes = null; _pdfName = null; }),
            )),
            const SizedBox(width: 8),
            Expanded(child: _buildSlot(
              label: 'TXT',
              icon: Icons.text_snippet_outlined,
              color: AppDS.green,
              existingName: widget.sop?.hasTxtFile == true && !_clearTxt
                  ? widget.sop!.txtFileName ?? 'document.txt' : null,
              existingSize: widget.sop?.hasTxtFile == true && !_clearTxt
                  ? widget.sop!.txtFileSizeLabel : null,
              newName:  _txtName,
              newBytes: _txtBytes,
              onPick:   _pickTxt,
              onRemoveExisting: () => setState(() => _clearTxt = true),
              onRemoveNew: () => setState(() { _txtBytes = null; _txtName = null; }),
            )),
            const SizedBox(width: 8),
            Expanded(child: _buildSlot(
              label: 'DOC',
              icon: Icons.article_outlined,
              color: const Color(0xFF4A90D9),
              existingName: widget.sop?.hasDocFile == true && !_clearDoc
                  ? widget.sop!.docFileName ?? 'document.docx' : null,
              existingSize: widget.sop?.hasDocFile == true && !_clearDoc
                  ? widget.sop!.docFileSizeLabel : null,
              newName:  _docName,
              newBytes: _docBytes,
              onPick:   _pickDoc,
              onRemoveExisting: () => setState(() => _clearDoc = true),
              onRemoveNew: () => setState(() { _docBytes = null; _docName = null; }),
            )),
          ],
        ),
      ],
    );
  }

  Widget _buildSlot({
    required String label,
    required IconData icon,
    required Color color,
    required String? existingName,
    required String? existingSize,
    required String? newName,
    required Uint8List? newBytes,
    required VoidCallback onPick,
    required VoidCallback onRemoveExisting,
    required VoidCallback onRemoveNew,
  }) {
    final hasExisting = existingName != null;
    final hasNew      = newName != null;
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: context.appSurface2,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
            color: (hasExisting || hasNew)
                ? color.withValues(alpha: 0.35)
                : context.appBorder2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(icon, size: 13, color: color),
            const SizedBox(width: 5),
            Text(label,
                style: GoogleFonts.spaceGrotesk(
                    fontSize: 11, fontWeight: FontWeight.w700, color: color)),
          ]),
          const SizedBox(height: 6),
          if (hasNew)
            _FileChip(
              name: newName,
              size: '${(newBytes!.length / 1024).toStringAsFixed(1)} KB (new)',
              onRemove: onRemoveNew,
            )
          else if (hasExisting)
            _FileChip(
              name: existingName,
              size: existingSize,
              onRemove: onRemoveExisting,
            )
          else
            Text('None',
                style: GoogleFonts.spaceGrotesk(
                    fontSize: 11, color: context.appTextMuted)),
          const SizedBox(height: 6),
          OutlinedButton.icon(
            onPressed: onPick,
            icon: const Icon(Icons.upload_file_outlined, size: 13),
            label: Text(hasExisting || hasNew ? 'Replace' : 'Attach',
                style: GoogleFonts.spaceGrotesk(fontSize: 11, fontWeight: FontWeight.w600)),
            style: OutlinedButton.styleFrom(
              foregroundColor: color,
              side: BorderSide(color: color.withValues(alpha: 0.5)),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          ),
        ],
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// Small reusable widgets
// ═════════════════════════════════════════════════════════════════════════════
class _Badge extends StatelessWidget {
  final String label;
  final Color  color;
  const _Badge({required this.label, required this.color});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.13),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: color.withValues(alpha: 0.35)),
    ),
    child: Text(
      label,
      style: GoogleFonts.spaceGrotesk(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: color,
          letterSpacing: 0.2),
    ),
  );
}

class _MetaItem extends StatelessWidget {
  final IconData icon;
  final String   text;
  final Color?   color;
  const _MetaItem(this.icon, this.text, {this.color});

  @override
  Widget build(BuildContext context) {
    final c = color ?? context.appTextSecondary;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 12, color: c.withValues(alpha: 0.7)),
        const SizedBox(width: 4),
        Text(text,
            style: GoogleFonts.spaceGrotesk(fontSize: 12, color: c)),
      ],
    );
  }
}

class _ActionBtn extends StatelessWidget {
  final IconData     icon;
  final String       label;
  final Color        color;
  final VoidCallback onTap;
  const _ActionBtn({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(6),
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(label,
              style: GoogleFonts.spaceGrotesk(
                  fontSize: 12,
                  color: color,
                  fontWeight: FontWeight.w600)),
        ],
      ),
    ),
  );
}


// ── Filter chip ───────────────────────────────────────────────────────────────
class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final Color? color;
  const _FilterChip({required this.label, required this.selected, required this.onTap, this.color});

  @override
  Widget build(BuildContext context) {
    final c = color ?? AppDS.accent;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: selected ? c.withValues(alpha: 0.18) : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: selected ? c : AppDS.border, width: selected ? 1.5 : 1),
        ),
        child: Text(label,
            style: GoogleFonts.spaceGrotesk(
                color: selected ? c : AppDS.textSecondary,
                fontSize: 12,
                fontWeight: selected ? FontWeight.w600 : FontWeight.normal)),
      ),
    );
  }
}

// ── Form field helpers ────────────────────────────────────────────────────────
class _Field extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final String? hint;
  final int maxLines;
  final String? Function(String?)? validator;
  const _Field({
    required this.label,
    required this.controller,
    this.hint,
    this.maxLines = 1,
    this.validator,
  });

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        label,
        style: GoogleFonts.spaceGrotesk(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: context.appTextMuted,
            letterSpacing: 0.5),
      ),
      const SizedBox(height: 4),
      TextFormField(
        controller: controller,
        maxLines: maxLines,
        validator: validator,
        style: GoogleFonts.spaceGrotesk(
            fontSize: 13, color: context.appTextPrimary),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: GoogleFonts.spaceGrotesk(
              fontSize: 12, color: context.appTextMuted),
          filled: true,
          fillColor: context.appSurface2,
          contentPadding: const EdgeInsets.symmetric(
              horizontal: 10, vertical: 9),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(6),
            borderSide: BorderSide(color: context.appBorder2),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(6),
            borderSide: BorderSide(color: context.appBorder2),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(6),
            borderSide: const BorderSide(color: AppDS.accent),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(6),
            borderSide: const BorderSide(color: AppDS.red),
          ),
          focusedErrorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(6),
            borderSide: const BorderSide(color: AppDS.red),
          ),
        ),
      ),
    ],
  );
}

class _DropField extends StatelessWidget {
  final String   label;
  final String   value;
  final List<String> options;
  final String Function(String?) labelOf;
  final ValueChanged<String?> onChanged;
  const _DropField({
    required this.label,
    required this.value,
    required this.options,
    required this.labelOf,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        label,
        style: GoogleFonts.spaceGrotesk(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: context.appTextMuted,
            letterSpacing: 0.5),
      ),
      const SizedBox(height: 4),
      Container(
        height: 40,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          color: context.appSurface2,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: context.appBorder2),
        ),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<String>(
            value: value,
            isExpanded: true,
            dropdownColor: context.appSurface2,
            style: GoogleFonts.spaceGrotesk(
                fontSize: 13, color: context.appTextPrimary),
            items: options
                .map((o) => DropdownMenuItem(
                      value: o,
                      child: Text(labelOf(o)),
                    ))
                .toList(),
            onChanged: onChanged,
            icon: Icon(Icons.expand_more,
                size: 16, color: context.appTextMuted),
          ),
        ),
      ),
    ],
  );
}

class _DateField extends StatelessWidget {
  final String   label;
  final DateTime? value;
  final ValueChanged<DateTime?> onPick;
  const _DateField({
    required this.label,
    required this.value,
    required this.onPick,
  });

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        label,
        style: GoogleFonts.spaceGrotesk(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: context.appTextMuted,
            letterSpacing: 0.5),
      ),
      const SizedBox(height: 4),
      InkWell(
        onTap: () async {
          final d = await showDatePicker(
            context: context,
            initialDate: value ?? DateTime.now(),
            firstDate: DateTime(2000),
            lastDate: DateTime(2100),
            builder: (ctx, child) => Theme(
              data: ThemeData.dark().copyWith(
                colorScheme: const ColorScheme.dark(
                  primary: AppDS.accent,
                  surface: Color(0xFF1A2438),
                ),
              ),
              child: child!,
            ),
          );
          if (d != null) onPick(d);
        },
        borderRadius: BorderRadius.circular(6),
        child: Container(
          height: 40,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            color: context.appSurface2,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: context.appBorder2),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  value != null ? _dateFmt.format(value!) : '—',
                  style: GoogleFonts.spaceGrotesk(
                      fontSize: 12,
                      color: value != null
                          ? context.appTextPrimary
                          : context.appTextMuted),
                ),
              ),
              if (value != null)
                GestureDetector(
                  onTap: () => onPick(null),
                  child: Icon(Icons.clear,
                      size: 14, color: context.appTextMuted),
                )
              else
                Icon(Icons.calendar_today_outlined,
                    size: 13, color: context.appTextMuted),
            ],
          ),
        ),
      ),
    ],
  );
}

class _FileChip extends StatelessWidget {
  final String  name;
  final String? size;
  final VoidCallback onRemove;
  const _FileChip(
      {required this.name, this.size, required this.onRemove});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    decoration: BoxDecoration(
      color: context.appSurface3,
      borderRadius: BorderRadius.circular(6),
      border: Border.all(color: context.appBorder),
    ),
    child: Row(
      children: [
        Icon(Icons.insert_drive_file_outlined,
            size: 14, color: context.appTextSecondary),
        const SizedBox(width: 6),
        Flexible(
          child: Text(name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.jetBrainsMono(
                  fontSize: 11, color: context.appTextSecondary)),
        ),
        if (size != null) ...[
          const SizedBox(width: 6),
          Text(size!,
              style: GoogleFonts.jetBrainsMono(
                  fontSize: 10, color: context.appTextMuted)),
        ],
        const SizedBox(width: 8),
        GestureDetector(
          onTap: onRemove,
          child: Icon(Icons.close,
              size: 13, color: context.appTextMuted),
        ),
      ],
    ),
  );
}

class _FileTypeChip extends StatelessWidget {
  final IconData icon;
  final String   name;
  final String   size;
  final Color    color;
  const _FileTypeChip({
    required this.icon,
    required this.name,
    required this.size,
    required this.color,
  });

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.10),
      borderRadius: BorderRadius.circular(6),
      border: Border.all(color: color.withValues(alpha: 0.30)),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 12, color: color),
        const SizedBox(width: 5),
        Text(name,
            style: GoogleFonts.jetBrainsMono(
                fontSize: 10, color: color)),
        if (size.isNotEmpty) ...[
          const SizedBox(width: 5),
          Text(size,
              style: GoogleFonts.jetBrainsMono(
                  fontSize: 9, color: color.withValues(alpha: 0.65))),
        ],
      ],
    ),
  );
}
