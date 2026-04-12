// reagent_excel_import_page.dart - 4-step import wizard for reagents.
// Supports CSV (.csv) and Excel (.xlsx) files.
// Steps: 0=pick file  1=map columns  2=preview  3=importing  4=done

import 'dart:convert';
import 'package:archive/archive.dart';
import 'package:csv/csv.dart' show CsvDecoder;
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:xml/xml.dart';
import '/theme/theme.dart';
import '../../backups/backup_service.dart';

// ── Reagent DB fields for mapping dropdowns ────────────────────────────────
const _reagentDbFields = [
  '— ignore —',
  'reagent_name',
  'reagent_code',
  'reagent_type',
  'reagent_brand',
  'reagent_reference',
  'reagent_cas_number',
  'reagent_supplier',
  'reagent_unit',
  'reagent_quantity',
  'reagent_quantity_min',
  'reagent_concentration',
  'reagent_storage_temp',
  'reagent_location_name',
  'reagent_position',
  'reagent_lot_number',
  'reagent_expiry_date',
  'reagent_received_date',
  'reagent_opened_date',
  'reagent_hazard',
  'reagent_responsible',
  'reagent_notes',
  'reagent_physical_state',
  'reagent_formula',
];

// ── Auto-mapping: header (lowercase) → DB field ────────────────────────────
const Map<String, String> _autoMap = {
  'name': 'reagent_name',
  'reagent name': 'reagent_name',
  'reagent_name': 'reagent_name',
  'code': 'reagent_code',
  'reagent code': 'reagent_code',
  'reagent_code': 'reagent_code',
  'type': 'reagent_type',
  'reagent type': 'reagent_type',
  'reagent_type': 'reagent_type',
  'brand': 'reagent_brand',
  'manufacturer': 'reagent_brand',
  'reference': 'reagent_reference',
  'ref': 'reagent_reference',
  'cat no': 'reagent_reference',
  'catalog number': 'reagent_reference',
  'catalogue number': 'reagent_reference',
  'cas': 'reagent_cas_number',
  'cas number': 'reagent_cas_number',
  'cas no': 'reagent_cas_number',
  'supplier': 'reagent_supplier',
  'vendor': 'reagent_supplier',
  'unit': 'reagent_unit',
  'units': 'reagent_unit',
  'quantity': 'reagent_quantity',
  'qty': 'reagent_quantity',
  'amount': 'reagent_quantity',
  'stock': 'reagent_quantity',
  'min quantity': 'reagent_quantity_min',
  'minimum quantity': 'reagent_quantity_min',
  'min qty': 'reagent_quantity_min',
  'min stock': 'reagent_quantity_min',
  'concentration': 'reagent_concentration',
  'conc': 'reagent_concentration',
  'size': 'reagent_concentration',
  'storage': 'reagent_storage_temp',
  'storage temp': 'reagent_storage_temp',
  'storage temperature': 'reagent_storage_temp',
  'temperature': 'reagent_storage_temp',
  'location': 'reagent_location_name',
  'room': 'reagent_location_name',
  'position': 'reagent_position',
  'shelf': 'reagent_position',
  'box': 'reagent_position',
  'lot': 'reagent_lot_number',
  'lot number': 'reagent_lot_number',
  'lot no': 'reagent_lot_number',
  'batch': 'reagent_lot_number',
  'expiry': 'reagent_expiry_date',
  'expiry date': 'reagent_expiry_date',
  'expiration': 'reagent_expiry_date',
  'expiration date': 'reagent_expiry_date',
  'expires': 'reagent_expiry_date',
  'received': 'reagent_received_date',
  'received date': 'reagent_received_date',
  'receipt date': 'reagent_received_date',
  'opened': 'reagent_opened_date',
  'open date': 'reagent_opened_date',
  'opened date': 'reagent_opened_date',
  'hazard': 'reagent_hazard',
  'ghs': 'reagent_hazard',
  'responsible': 'reagent_responsible',
  'owner': 'reagent_responsible',
  'notes': 'reagent_notes',
  'observations': 'reagent_notes',
  'comments': 'reagent_notes',
  'physical state': 'reagent_physical_state',
  'physical_state': 'reagent_physical_state',
  'state': 'reagent_physical_state',
  'form': 'reagent_physical_state',
  'formula': 'reagent_formula',
  'chemical formula': 'reagent_formula',
  'molecular formula': 'reagent_formula',
  'reagent_formula': 'reagent_formula',
};

// ── CSV parser ─────────────────────────────────────────────────────────────
List<List<dynamic>> _parseCsvBytes(List<int> bytes) {
  var content = utf8.decode(bytes, allowMalformed: true);
  if (content.startsWith('\uFEFF')) content = content.substring(1);
  return const CsvDecoder(
    fieldDelimiter: null,
    skipEmptyLines: true,
  ).convert(content);
}

// ── XLSX parser (archive + xml — no extra dependency) ─────────────────────
//
// Column letter → 0-based index  (A→0, B→1, Z→25, AA→26 …)
int _xlColIdx(String col) {
  int r = 0;
  for (final ch in col.codeUnits) {
    r = r * 26 + (ch - 65 + 1);
  }
  return r - 1;
}

List<List<dynamic>> _parseXlsxBytes(List<int> bytes) {
  final Archive archive;
  try {
    archive = ZipDecoder().decodeBytes(bytes);
  } catch (_) {
    throw const FormatException(
        'Not a valid XLSX file. Old .xls format is not supported — '
        'please save as .xlsx from Excel first.');
  }

  // 1. Shared strings table
  final sharedStrings = <String>[];
  final ssFile = archive.findFile('xl/sharedStrings.xml');
  if (ssFile != null) {
    try {
      final doc = XmlDocument.parse(
          utf8.decode(ssFile.content as List<int>, allowMalformed: true));
      for (final si in doc.findAllElements('si')) {
        // Rich-text nodes may have multiple <t> children; join them all.
        sharedStrings
            .add(si.findAllElements('t').map((e) => e.innerText).join());
      }
    } catch (_) {}
  }

  // 2. First sheet XML
  final sheetFile = archive.findFile('xl/worksheets/sheet1.xml');
  if (sheetFile == null) return [];

  final XmlDocument sheetDoc;
  try {
    sheetDoc = XmlDocument.parse(
        utf8.decode(sheetFile.content as List<int>, allowMalformed: true));
  } catch (_) {
    return [];
  }

  // 3. Parse rows
  final result = <List<dynamic>>[];
  for (final rowEl in sheetDoc.findAllElements('row')) {
    final cellMap = <int, String>{};
    int maxCol = -1;

    for (final c in rowEl.findElements('c')) {
      final ref = c.getAttribute('r') ?? '';
      // Split "AB12" into letters "AB" and digits "12"
      final colLetters = ref.replaceAll(RegExp(r'\d'), '');
      if (colLetters.isEmpty) continue;
      final colIdx = _xlColIdx(colLetters);
      if (colIdx > maxCol) maxCol = colIdx;

      final t = c.getAttribute('t') ?? '';
      final vText = c.findElements('v').firstOrNull?.innerText ?? '';

      final String value;
      if (t == 's') {
        // Shared string index
        final idx = int.tryParse(vText) ?? -1;
        value = (idx >= 0 && idx < sharedStrings.length)
            ? sharedStrings[idx]
            : '';
      } else if (t == 'inlineStr') {
        value =
            c.findAllElements('t').map((e) => e.innerText).join();
      } else if (t == 'b') {
        value = vText == '1' ? 'TRUE' : 'FALSE';
      } else if (t == 'e') {
        value = ''; // error cell
      } else {
        value = vText; // number, formula result, date serial
      }

      cellMap[colIdx] = value;
    }

    if (maxCol < 0) continue;
    final row = List<dynamic>.filled(maxCol + 1, '');
    cellMap.forEach((col, val) {
      if (col < row.length) row[col] = val;
    });
    if (row.any((c) => c.toString().isNotEmpty)) result.add(row);
  }

  return result;
}

// ── Date normalisation (used at mapping time so preview shows clean dates) ──
//
// Converts any value that looks like an Excel day-serial into yyyy-mm-dd.
// Also accepts common text formats so the preview is always human-readable.
String _normaliseDate(String raw) {
  final v = raw.trim();
  if (v.isEmpty) return v;

  // Excel serial: decimal number in plausible date range (1900–2100).
  final asDouble = double.tryParse(v);
  if (asDouble != null && asDouble > 1000 && asDouble < 200000) {
    final d = DateTime(1899, 12, 30).add(Duration(days: asDouble.toInt()));
    return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  }

  // ISO / slash-separated ISO (yyyy/mm/dd).
  final iso = DateTime.tryParse(v.replaceAll('/', '-'));
  if (iso != null) {
    return '${iso.year}-${iso.month.toString().padLeft(2, '0')}-${iso.day.toString().padLeft(2, '0')}';
  }

  // dd/mm/yyyy, dd-mm-yyyy, dd.mm.yyyy
  final parts = v.split(RegExp(r'[/\-\.]'));
  if (parts.length == 3) {
    final p1 = int.tryParse(parts[0]);
    final p2 = int.tryParse(parts[1]);
    final p3 = int.tryParse(parts[2]);
    if (p1 != null && p2 != null && p3 != null) {
      final year  = p3 > 31 ? p3 : (p3 < 100 ? 2000 + p3 : p3);
      final month = p3 > 31 ? p2 : p1;
      final day   = p3 > 31 ? p1 : p2;
      final d = DateTime.tryParse(
          '$year-${month.toString().padLeft(2, '0')}-${day.toString().padLeft(2, '0')}');
      if (d != null) {
        return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
      }
    }
  }

  return v; // leave as-is if nothing matched
}

// ── Shared helpers ─────────────────────────────────────────────────────────
List<String> _detectHeaders(List<List<dynamic>> rows) {
  for (final row in rows) {
    final cells = row.map((c) => c?.toString().trim() ?? '').toList();
    if (cells.any((c) => c.isNotEmpty)) return cells;
  }
  return [];
}

List<Map<String, String>> _applyMapping(
    List<List<dynamic>> rows, Map<int, String> colMap) {
  if (rows.length < 2) return [];
  final result = <Map<String, String>>[];
  for (int r = 1; r < rows.length; r++) {
    final row = rows[r];
    final record = <String, String>{};
    for (final e in colMap.entries) {
      if (e.value == '— ignore —') continue;
      var val =
          e.key < row.length ? (row[e.key]?.toString().trim() ?? '') : '';
      if (val.isNotEmpty && e.value.endsWith('_date')) {
        val = _normaliseDate(val);
      }
      if (val.isNotEmpty) record[e.value] = val;
    }
    if (record.isNotEmpty) result.add(record);
  }
  return result;
}

// ── Main wizard ────────────────────────────────────────────────────────────
class ReagentExcelImportPage extends StatefulWidget {
  const ReagentExcelImportPage({super.key});

  @override
  State<ReagentExcelImportPage> createState() => _ReagentExcelImportPageState();
}

class _ReagentExcelImportPageState extends State<ReagentExcelImportPage> {
  int _step = 0;

  List<List<dynamic>>? _rows;
  String _fileName = '';
  List<String> _headers = [];
  Map<int, String> _colMap = {};
  List<Map<String, String>> _parsed = [];
  String _importLog = '';
  int _importedCount = 0;
  int _skippedCount = 0;

  Map<String, int> _locationCache = {};

  final _previewHScroll = ScrollController();

  @override
  void dispose() {
    _previewHScroll.dispose();
    super.dispose();
  }

  // ── Step 0: pick file ──────────────────────────────────────────────────
  Future<void> _pickFile() async {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['csv', 'xlsx', 'xls'],
      withData: true,
    );
    if (result == null || result.files.isEmpty) return;
    final file = result.files.first;
    final bytes = file.bytes;
    if (bytes == null) return;

    final ext = (file.extension ?? '').toLowerCase();
    List<List<dynamic>> rows;
    try {
      rows = (ext == 'xlsx' || ext == 'xls')
          ? _parseXlsxBytes(bytes)
          : _parseCsvBytes(bytes);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(e is FormatException ? e.message : 'Could not parse file: $e'),
        behavior: SnackBarBehavior.floating,
      ));
      return;
    }

    final headers = _detectHeaders(rows);
    final colMap = <int, String>{};
    for (int i = 0; i < headers.length; i++) {
      final n = headers[i].toLowerCase().trim();
      colMap[i] = _autoMap[n] ?? '— ignore —';
    }
    setState(() {
      _rows = rows;
      _fileName = file.name;
      _headers = headers;
      _colMap = colMap;
      _step = 1;
    });
  }

  // ── Step 1 → 2: preview ────────────────────────────────────────────────
  void _goToPreview() {
    if (_rows == null) return;
    setState(() {
      _parsed = _applyMapping(_rows!, _colMap);
      _step = 2;
    });
  }

  // ── Step 2 → 3: import ─────────────────────────────────────────────────
  Future<void> _runImport() async {
    setState(() => _step = 3);
    final sb = StringBuffer();
    final db = Supabase.instance.client;
    int imported = 0;
    int skipped = 0;

    try {
      final locRows = await db
          .from('storage_locations')
          .select('location_id, location_name');
      _locationCache = {
        for (final r in (locRows as List))
          (r['location_name'] as String).toLowerCase():
              (r['location_id'] as num).toInt(),
      };

      for (final record in _parsed) {
        final name = record['reagent_name'];
        final code = record['reagent_code'];
        final label = (name is String && name.isNotEmpty)
            ? name
            : (code is String && code.isNotEmpty)
                ? code
                : '(no name)';
        final row = _buildInsertRow(record);
        try {
          await db.from('reagents').insert(row);
          sb.writeln('✓ "$label" imported.');
          imported++;
        } catch (e) {
          sb.writeln('✗ "$label" failed: $e');
          skipped++;
        }
      }

      if (imported > 0) {
        await BackupService.instance.notifyCrudChange('reagents');
      }
    } catch (e) {
      sb.writeln('✗ Import aborted: $e');
    }

    if (!mounted) return;
    setState(() {
      _importLog = sb.toString();
      _importedCount = imported;
      _skippedCount = skipped;
      _step = 4;
    });
  }

  Map<String, dynamic> _buildInsertRow(Map<String, String> r) {
    final row = <String, dynamic>{};

    void putStr(String col, String? val) {
      if (val != null && val.isNotEmpty) row[col] = val;
    }

    void putNum(String col, String? val) {
      if (val != null && val.isNotEmpty) {
        final n = double.tryParse(val.replaceAll(',', '.'));
        if (n != null) row[col] = n;
      }
    }

    void putDate(String col, String? val) {
      if (val == null || val.isEmpty) return;
      // Values are already normalised to yyyy-mm-dd by _applyMapping,
      // but run through _normaliseDate again as a safety net.
      final normalised = _normaliseDate(val);
      if (normalised.isNotEmpty) row[col] = normalised;
    }

    if (r['reagent_name'] is String && (r['reagent_name'] as String).isNotEmpty) {
      row['reagent_name'] = r['reagent_name'];
    }
    row['reagent_type'] = r['reagent_type'] ?? 'biological';
    row['reagent_created_at'] = DateTime.now().toUtc().toIso8601String();

    putStr('reagent_code', r['reagent_code']);
    putStr('reagent_brand', r['reagent_brand']);
    putStr('reagent_reference', r['reagent_reference']);
    putStr('reagent_cas_number', r['reagent_cas_number']);
    putStr('reagent_supplier', r['reagent_supplier']);
    putStr('reagent_unit', r['reagent_unit']);
    putStr('reagent_concentration', r['reagent_concentration']);
    putStr('reagent_storage_temp', r['reagent_storage_temp']);
    putStr('reagent_position', r['reagent_position']);
    putStr('reagent_lot_number', r['reagent_lot_number']);
    putStr('reagent_hazard', r['reagent_hazard']);
    putStr('reagent_responsible', r['reagent_responsible']);
    putStr('reagent_notes', r['reagent_notes']);
    putStr('reagent_formula', r['reagent_formula']);

    // Physical state: only accept the three valid values (case-insensitive).
    final ps = r['reagent_physical_state']?.toLowerCase().trim();
    if (ps != null && const ['liquid', 'solid', 'gas'].contains(ps)) {
      row['reagent_physical_state'] = ps;
    }

    putNum('reagent_quantity', r['reagent_quantity']);
    putNum('reagent_quantity_min', r['reagent_quantity_min']);

    putDate('reagent_expiry_date', r['reagent_expiry_date']);
    putDate('reagent_received_date', r['reagent_received_date']);
    putDate('reagent_opened_date', r['reagent_opened_date']);

    final locName = r['reagent_location_name'];
    if (locName != null && locName.isNotEmpty) {
      final id = _locationCache[locName.toLowerCase()];
      if (id != null) row['reagent_location_id'] = id;
    }

    return row;
  }

  // ── Build ──────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.appBg,
      appBar: AppBar(
        backgroundColor: context.appSurface,
        foregroundColor: context.appTextPrimary,
        elevation: 0,
        titleSpacing: 0,
        title: Row(children: [
          const Icon(Icons.upload_file_outlined,
              color: Color(0xFFF59E0B), size: 18),
          const SizedBox(width: 8),
          Text('Import Reagents',
              style: GoogleFonts.spaceGrotesk(
                  color: context.appTextPrimary,
                  fontSize: 15,
                  fontWeight: FontWeight.w600)),
        ]),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: context.appBorder),
        ),
      ),
      body: Column(children: [
        _StepBar(current: _step),
        Expanded(child: _buildStep()),
      ]),
    );
  }

  Widget _buildStep() {
    return switch (_step) {
      0 => _buildPickStep(),
      1 => _buildMapStep(),
      2 => _buildPreviewStep(),
      3 => _buildImportingStep(),
      4 => _buildDoneStep(),
      _ => const SizedBox.shrink(),
    };
  }

  // ── Step 0: Pick file ──────────────────────────────────────────────────
  Widget _buildPickStep() {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: context.appSurface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: context.appBorder),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.table_chart_outlined,
                        color: Color(0xFFF59E0B), size: 48),
                    const SizedBox(height: 16),
                    Text('Select a CSV or Excel file',
                        style: GoogleFonts.spaceGrotesk(
                            color: context.appTextPrimary,
                            fontSize: 16,
                            fontWeight: FontWeight.w600)),
                    const SizedBox(height: 8),
                    Text(
                      'Supported formats: .csv and .xlsx\n'
                      'The first row must contain column headers.\n'
                      'reagent_name is the only required field.',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.spaceGrotesk(
                          color: context.appTextSecondary, fontSize: 13),
                    ),
                    const SizedBox(height: 24),
                    FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFFF59E0B),
                        foregroundColor: Colors.black,
                        minimumSize: const Size(double.infinity, 44),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8)),
                      ),
                      onPressed: _pickFile,
                      icon: const Icon(Icons.folder_open_outlined, size: 18),
                      label: Text('Choose file',
                          style: GoogleFonts.spaceGrotesk(
                              fontWeight: FontWeight.w600)),
                    ),
                    const SizedBox(height: 8),
                    Text('.csv  ·  .xlsx',
                        style: GoogleFonts.jetBrainsMono(
                            color: context.appTextMuted, fontSize: 11)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Step 1: Map columns ────────────────────────────────────────────────
  Widget _buildMapStep() {
    return Column(children: [
      Container(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
        decoration: BoxDecoration(
          color: context.appSurface,
          border: Border(bottom: BorderSide(color: context.appBorder)),
        ),
        child: Row(children: [
          const Icon(Icons.insert_drive_file_outlined,
              color: Color(0xFFF59E0B), size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Text(_fileName,
                style: GoogleFonts.spaceGrotesk(
                    color: context.appTextSecondary, fontSize: 13),
                overflow: TextOverflow.ellipsis),
          ),
          Text('${_headers.length} columns detected',
              style: GoogleFonts.spaceGrotesk(
                  color: context.appTextMuted, fontSize: 12)),
        ]),
      ),
      Expanded(
        child: ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: _headers.length,
          itemBuilder: (context, i) {
            final header = _headers[i];
            final mapped = _colMap[i] != '— ignore —';
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(children: [
                Expanded(
                  flex: 2,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: context.appSurface2,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: context.appBorder2),
                    ),
                    child: Text(header,
                        style: GoogleFonts.jetBrainsMono(
                            color: context.appTextSecondary, fontSize: 12),
                        overflow: TextOverflow.ellipsis),
                  ),
                ),
                const SizedBox(width: 8),
                Icon(Icons.arrow_forward_rounded,
                    color: context.appTextMuted, size: 16),
                const SizedBox(width: 8),
                Expanded(
                  flex: 3,
                  child: Container(
                    height: 40,
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    decoration: BoxDecoration(
                      color: context.appSurface2,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                          color: mapped
                              ? AppDS.accent.withValues(alpha: 0.5)
                              : context.appBorder2),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: _colMap[i] ?? '— ignore —',
                        dropdownColor: context.appSurface,
                        isExpanded: true,
                        style: GoogleFonts.spaceGrotesk(
                            color: mapped
                                ? AppDS.accent
                                : context.appTextMuted,
                            fontSize: 12),
                        items: _reagentDbFields
                            .map((f) => DropdownMenuItem(
                                  value: f,
                                  child: Text(f,
                                      style: GoogleFonts.spaceGrotesk(
                                          color: f != '— ignore —'
                                              ? context.appTextPrimary
                                              : context.appTextMuted,
                                          fontSize: 12)),
                                ))
                            .toList(),
                        onChanged: (v) {
                          if (v != null) setState(() => _colMap[i] = v);
                        },
                      ),
                    ),
                  ),
                ),
              ]),
            );
          },
        ),
      ),
      _BottomBar(
        onBack: () => setState(() {
          _step = 0;
          _rows = null;
        }),
        onNext: _headers.isEmpty ? null : _goToPreview,
        nextLabel: 'Preview',
      ),
    ]);
  }

  // ── Step 2: Preview ────────────────────────────────────────────────────
  Widget _buildPreviewStep() {
    final mappedCols = _colMap.entries
        .where((e) => e.value != '— ignore —')
        .toList()
      ..sort((a, b) => a.key.compareTo(b.key));

    return Column(children: [
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        decoration: BoxDecoration(
          color: context.appSurface,
          border: Border(bottom: BorderSide(color: context.appBorder)),
        ),
        child: Row(children: [
          const Icon(Icons.preview_outlined,
              color: Color(0xFFF59E0B), size: 16),
          const SizedBox(width: 8),
          Text('${_parsed.length} records will be imported',
              style: GoogleFonts.spaceGrotesk(
                  color: context.appTextSecondary, fontSize: 13)),
        ]),
      ),
      Expanded(
        child: Scrollbar(
          controller: _previewHScroll,
          child: SingleChildScrollView(
            controller: _previewHScroll,
            scrollDirection: Axis.horizontal,
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    for (final e in mappedCols)
                      _PreviewCell(
                          text: e.value,
                          isHeader: true,
                          width: _colWidth(e.value)),
                  ]),
                  for (final record in _parsed.take(50))
                    Row(children: [
                      for (final e in mappedCols)
                        _PreviewCell(
                            text: record[e.value] ?? '',
                            isHeader: false,
                            width: _colWidth(e.value)),
                    ]),
                  if (_parsed.length > 50)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        '… and ${_parsed.length - 50} more rows',
                        style: GoogleFonts.spaceGrotesk(
                            color: context.appTextMuted, fontSize: 12),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
      _BottomBar(
        onBack: () => setState(() => _step = 1),
        onNext: _parsed.isEmpty ? null : _runImport,
        nextLabel: 'Import ${_parsed.length} records',
        nextColor: AppDS.green,
      ),
    ]);
  }

  double _colWidth(String field) {
    if (field.contains('name') || field.contains('notes')) return 200;
    if (field.contains('date')) return 110;
    if (field.contains('quantity') || field.contains('unit')) return 90;
    return 130;
  }

  // ── Step 3: Importing ──────────────────────────────────────────────────
  Widget _buildImportingStep() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(color: Color(0xFFF59E0B)),
          const SizedBox(height: 20),
          Text('Importing…',
              style: TextStyle(color: context.appTextSecondary)),
        ],
      ),
    );
  }

  // ── Step 4: Done ───────────────────────────────────────────────────────
  Widget _buildDoneStep() {
    final hasErrors = _skippedCount > 0;
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: context.appSurface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: context.appBorder),
            ),
            child: Row(children: [
              Icon(
                hasErrors
                    ? Icons.warning_amber_rounded
                    : Icons.check_circle_rounded,
                color: hasErrors ? AppDS.yellow : AppDS.green,
                size: 28,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      hasErrors
                          ? 'Import completed with warnings'
                          : 'Import completed successfully',
                      style: GoogleFonts.spaceGrotesk(
                          color: context.appTextPrimary,
                          fontSize: 14,
                          fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '$_importedCount imported  ·  $_skippedCount skipped',
                      style: GoogleFonts.spaceGrotesk(
                          color: context.appTextSecondary, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ]),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: context.appSurface2,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: context.appBorder2),
              ),
              child: SingleChildScrollView(
                child: SelectableText(
                  _importLog,
                  style: GoogleFonts.jetBrainsMono(
                      color: context.appTextSecondary, fontSize: 12),
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: AppDS.accent,
              foregroundColor: Colors.black,
              minimumSize: const Size(double.infinity, 44),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () => Navigator.of(context).pop(true),
            child: Text('Done — back to Reagents',
                style:
                    GoogleFonts.spaceGrotesk(fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }
}

// ── Step bar ───────────────────────────────────────────────────────────────
class _StepBar extends StatelessWidget {
  final int current;
  const _StepBar({required this.current});

  static const _labels = ['File', 'Map columns', 'Preview', 'Import'];

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 40,
      color: context.appSurface2,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(_labels.length, (i) {
          final active = i == (current < 3 ? current : 3);
          final done = current > i || current == 4;
          return Row(children: [
            if (i > 0)
              Container(
                  width: 32,
                  height: 1,
                  color: done ? AppDS.accent : context.appBorder),
            Container(
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                color: done
                    ? AppDS.accent
                    : active
                        ? AppDS.accent.withValues(alpha: 0.2)
                        : context.appSurface3,
                shape: BoxShape.circle,
                border: Border.all(
                    color: (active || done) ? AppDS.accent : context.appBorder,
                    width: 1.5),
              ),
              child: Center(
                child: done
                    ? const Icon(Icons.check_rounded,
                        color: Colors.black, size: 12)
                    : Text('${i + 1}',
                        style: GoogleFonts.spaceGrotesk(
                            color: active ? AppDS.accent : context.appTextMuted,
                            fontSize: 10,
                            fontWeight: FontWeight.w700)),
              ),
            ),
            const SizedBox(width: 4),
            Text(_labels[i],
                style: GoogleFonts.spaceGrotesk(
                    color: (active || done)
                        ? context.appTextPrimary
                        : context.appTextMuted,
                    fontSize: 11,
                    fontWeight:
                        active ? FontWeight.w600 : FontWeight.w400)),
          ]);
        }),
      ),
    );
  }
}

// ── Bottom action bar ──────────────────────────────────────────────────────
class _BottomBar extends StatelessWidget {
  final VoidCallback? onBack;
  final VoidCallback? onNext;
  final String nextLabel;
  final Color? nextColor;

  const _BottomBar({
    required this.onBack,
    required this.onNext,
    required this.nextLabel,
    this.nextColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        color: context.appSurface,
        border: Border(top: BorderSide(color: context.appBorder)),
      ),
      child: Row(children: [
        if (onBack != null)
          TextButton.icon(
            style: TextButton.styleFrom(
                foregroundColor: context.appTextSecondary),
            onPressed: onBack,
            icon: const Icon(Icons.arrow_back_rounded, size: 16),
            label: Text('Back',
                style: GoogleFonts.spaceGrotesk(fontSize: 13)),
          ),
        const Spacer(),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: nextColor ?? const Color(0xFFF59E0B),
            foregroundColor: Colors.black,
            minimumSize: const Size(0, 40),
            padding: const EdgeInsets.symmetric(horizontal: 20),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8)),
          ),
          onPressed: onNext,
          child: Text(nextLabel,
              style: GoogleFonts.spaceGrotesk(
                  fontWeight: FontWeight.w600, fontSize: 13)),
        ),
      ]),
    );
  }
}

// ── Preview cell ───────────────────────────────────────────────────────────
class _PreviewCell extends StatelessWidget {
  final String text;
  final bool isHeader;
  final double width;

  const _PreviewCell(
      {required this.text, required this.isHeader, required this.width});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: isHeader ? 32 : 28,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: isHeader ? context.appSurface3 : context.appSurface2,
        border: Border(
          right: BorderSide(color: context.appBorder2),
          bottom: BorderSide(color: context.appBorder2),
        ),
      ),
      alignment: Alignment.centerLeft,
      child: Text(
        text,
        style: isHeader
            ? GoogleFonts.spaceGrotesk(
                color: AppDS.accent,
                fontSize: 11,
                fontWeight: FontWeight.w600)
            : GoogleFonts.spaceGrotesk(
                color: context.appTextSecondary, fontSize: 11),
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}
