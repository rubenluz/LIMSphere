// docx_to_pdf_converter.dart — Converts DOCX bytes to PDF bytes.
//
// Strategy 1: LibreOffice CLI   — best quality, free, cross-platform.
// Strategy 2: Microsoft Word    — PowerShell COM, Windows + Office required.
// Strategy 3: In-app XML → pdf  — always available; handles headings,
//   paragraphs, tables, bold/italic/underline, shading, symbols,
//   headers/footers, alignment, font sizes.

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:xml/xml.dart';

// ─── Public API ──────────────────────────────────────────────────────────────

Future<Uint8List?> convertDocxToPdf(Uint8List bytes, String fileName) async {
  return await _convertViaLibreOffice(bytes, fileName)
      ?? await _convertViaWordCom(bytes, fileName)
      ?? await _convertViaXmlPdf(bytes);
}

// ─── Strategy 1: LibreOffice CLI ─────────────────────────────────────────────

const _loSearchPaths = [
  r'C:\Program Files\LibreOffice\program\soffice.exe',
  r'C:\Program Files (x86)\LibreOffice\program\soffice.exe',
  r'C:\Program Files\LibreOffice 7\program\soffice.exe',
  r'C:\Program Files\LibreOffice 6\program\soffice.exe',
  '/usr/bin/soffice',
  '/usr/bin/libreoffice',
  '/opt/libreoffice/program/soffice',
  '/Applications/LibreOffice.app/Contents/MacOS/soffice',
];

Future<Uint8List?> _convertViaLibreOffice(
    Uint8List bytes, String fileName) async {
  String? exe;
  for (final path in _loSearchPaths) {
    if (await File(path).exists()) { exe = path; break; }
  }
  if (exe == null) return null;

  try {
    final tmp     = await getTemporaryDirectory();
    final inFile  = File('${tmp.path}/$fileName');
    final base    = fileName.endsWith('.docx')
        ? fileName.substring(0, fileName.length - 5) : fileName;
    final outFile = File('${tmp.path}/$base.pdf');

    await inFile.writeAsBytes(bytes);
    if (await outFile.exists()) await outFile.delete();

    final res = await Process.run(
      exe,
      ['--headless', '--convert-to', 'pdf', '--outdir', tmp.path, inFile.path],
      runInShell: Platform.isWindows,
    );

    if (res.exitCode != 0 || !await outFile.exists()) return null;
    final pdf = await outFile.readAsBytes();
    await inFile.delete();
    await outFile.delete();
    return pdf;
  } catch (_) {
    return null;
  }
}

// ─── Strategy 2: Microsoft Word COM via PowerShell ────────────────────────────

Future<Uint8List?> _convertViaWordCom(
    Uint8List bytes, String fileName) async {
  if (!Platform.isWindows) return null;
  try {
    final tmp     = await getTemporaryDirectory();
    final inFile  = File('${tmp.path}\\$fileName');
    final base    = fileName.endsWith('.docx')
        ? fileName.substring(0, fileName.length - 5) : fileName;
    final outFile = File('${tmp.path}\\$base.pdf');

    await inFile.writeAsBytes(bytes);
    if (await outFile.exists()) await outFile.delete();

    // Single-quote escaping for PowerShell: replace ' with ''
    final inPath  = inFile.path.replaceAll("'", "''");
    final outPath = outFile.path.replaceAll("'", "''");

    final scriptFile = File('${tmp.path}\\word_conv.ps1');
    await scriptFile.writeAsString(
      "\$ErrorActionPreference = 'Stop'\n"
      "\$w = New-Object -ComObject Word.Application\n"
      "\$w.Visible = \$false\n"
      "try {\n"
      "  \$d = \$w.Documents.Open('$inPath')\n"
      "  \$d.SaveAs2('$outPath', 17)\n"
      "  \$d.Close(\$false)\n"
      "} finally { \$w.Quit() }\n",
      encoding: utf8,
    );

    final res = await Process.run('powershell', [
      '-NonInteractive', '-NoProfile',
      '-ExecutionPolicy', 'Bypass',
      '-File', scriptFile.path,
    ]);

    await scriptFile.delete();

    if (res.exitCode != 0 || !await outFile.exists()) return null;
    final pdf = await outFile.readAsBytes();
    await inFile.delete();
    await outFile.delete();
    return pdf;
  } catch (_) {
    return null;
  }
}

// ─── Strategy 3: In-app XML → pdf package ─────────────────────────────────────

Future<Uint8List?> _convertViaXmlPdf(Uint8List bytes) async {
  try {
    final archive = ZipDecoder().decodeBytes(bytes.toList());

    final docXml    = _archiveString(archive, 'word/document.xml');
    final stylesXml = _archiveString(archive, 'word/styles.xml');
    if (docXml == null) return null;

    final doc    = XmlDocument.parse(docXml);
    final styles = stylesXml != null ? XmlDocument.parse(stylesXml) : null;

    final styleMap  = _buildStyleMap(styles);
    final margins   = _parsePageMargins(doc);
    final nodes     = _parseBody(doc, styleMap);

    // Headers / footers — pick the primary (type="default" or first available)
    final headerRuns = _parseHeaderFooter(archive, 'word/header1.xml', styleMap)
        ?? _parseHeaderFooter(archive, 'word/header2.xml', styleMap)
        ?? [];
    final footerRuns = _parseHeaderFooter(archive, 'word/footer1.xml', styleMap)
        ?? _parseHeaderFooter(archive, 'word/footer2.xml', styleMap)
        ?? [];

    return await _buildPdf(nodes, margins, headerRuns, footerRuns);
  } catch (_) {
    return null;
  }
}

// ─── Archive helper ───────────────────────────────────────────────────────────

String? _archiveString(Archive a, String path) {
  final f = a.findFile(path);
  if (f == null) return null;
  try { return utf8.decode(f.content as List<int>); } catch (_) { return null; }
}

// ─── Style map ────────────────────────────────────────────────────────────────

Map<String, String> _buildStyleMap(XmlDocument? s) {
  final m = <String, String>{};
  if (s == null) return m;
  for (final style in s.findAllElements('w:style')) {
    final id   = style.getAttribute('w:styleId') ?? '';
    final name = style.findElements('w:name').firstOrNull
        ?.getAttribute('w:val') ?? '';
    final l = name.toLowerCase();
    m[id] = switch (l) {
      'title'     => 'Title',
      'heading 1' => 'Heading1',
      'heading 2' => 'Heading2',
      'heading 3' => 'Heading3',
      'heading 4' => 'Heading4',
      'heading 5' => 'Heading5',
      'heading 6' => 'Heading6',
      _           => 'normal',
    };
  }
  return m;
}

// ─── Page margins ─────────────────────────────────────────────────────────────

class _Margins {
  final double top, bottom, left, right;
  const _Margins(this.top, this.bottom, this.left, this.right);
}

_Margins _parsePageMargins(XmlDocument doc) {
  final pgMar = doc.findAllElements('w:pgMar').firstOrNull;
  double pt(String? v) => (int.tryParse(v ?? '') ?? 1440) / 20.0;
  return _Margins(
    pt(pgMar?.getAttribute('w:top')),
    pt(pgMar?.getAttribute('w:bottom')),
    pt(pgMar?.getAttribute('w:left')),
    pt(pgMar?.getAttribute('w:right')),
  );
}

// ─── Data model ───────────────────────────────────────────────────────────────

sealed class _Node {}

class _Para extends _Node {
  final List<_Run> runs;
  final String styleType;
  final String align;
  final double spacingBefore;
  final double spacingAfter;
  final PdfColor? shading;
  final bool isBullet;
  _Para(this.runs, this.styleType, this.align, this.spacingBefore,
      this.spacingAfter, {this.shading, this.isBullet = false});
  String get text => runs.map((r) => r.text).join();
}

class _Run {
  final String text;
  final bool bold;
  final bool italic;
  final bool underline;
  final double? fontSize;
  final PdfColor? color;
  _Run(this.text,
      {this.bold = false, this.italic = false, this.underline = false,
      this.fontSize, this.color});
}

class _Table extends _Node {
  final List<List<_Cell>> rows;
  _Table(this.rows);
}

class _Cell {
  final List<_Run> runs;
  final PdfColor? shading;
  _Cell(this.runs, {this.shading});
}

// ─── Body parser ─────────────────────────────────────────────────────────────

List<_Node> _parseBody(XmlDocument doc, Map<String, String> styleMap) {
  final body = doc.findAllElements('w:body').firstOrNull;
  if (body == null) return [];
  return body.children.whereType<XmlElement>().map((child) {
    if (child.name.local == 'tbl') return _parseTable(child, styleMap);
    return _parseParagraph(child, styleMap);
  }).toList();
}

_Para _parseParagraph(XmlElement p, Map<String, String> styleMap) {
  final pPr = p.findElements('w:pPr').firstOrNull;

  final styleId   = pPr?.findElements('w:pStyle').firstOrNull
      ?.getAttribute('w:val') ?? '';
  final styleType = styleMap[styleId] ?? 'normal';

  final jcVal = pPr?.findElements('w:jc').firstOrNull
      ?.getAttribute('w:val') ?? '';
  final align = switch (jcVal) {
    'center' => 'center', 'right' => 'right',
    'both' || 'distribute' => 'justify', _ => 'left',
  };

  final spacing = pPr?.findElements('w:spacing').firstOrNull;
  double tw(String? v) => (int.tryParse(v ?? '') ?? 0) / 20.0;

  // Shading (paragraph background)
  final shdFill = pPr?.findElements('w:shd').firstOrNull
      ?.getAttribute('w:fill');
  final shading = _hexColor(shdFill);

  // Bullet / numbered list
  final isBullet = pPr?.findElements('w:numPr').isNotEmpty ?? false;

  final runs = _parseRuns(p);

  return _Para(runs, styleType, align,
      tw(spacing?.getAttribute('w:before')),
      tw(spacing?.getAttribute('w:after')),
      shading: shading, isBullet: isBullet);
}

List<_Run> _parseRuns(XmlElement el) {
  final runs = <_Run>[];
  for (final r in el.findElements('w:r')) {
    final rPr = r.findElements('w:rPr').firstOrNull;

    final bold      = _boolProp(rPr, 'w:b');
    final italic    = _boolProp(rPr, 'w:i');
    final uVal      = rPr?.findElements('w:u').firstOrNull
        ?.getAttribute('w:val');
    final underline = uVal != null && uVal != 'none';

    final szVal    = rPr?.findElements('w:sz').firstOrNull
        ?.getAttribute('w:val');
    final fontSize = szVal != null ? (int.tryParse(szVal) ?? 0) / 2.0 : null;

    final colorVal = rPr?.findElements('w:color').firstOrNull
        ?.getAttribute('w:val');
    final color = _hexColor(colorVal);

    // Text nodes
    final text = r.findAllElements('w:t').map((t) => t.innerText).join();
    if (text.isNotEmpty) {
      runs.add(_Run(text, bold: bold, italic: italic,
          underline: underline, fontSize: fontSize, color: color));
    }

    // Tab
    if (r.findElements('w:tab').isNotEmpty) runs.add(_Run('    '));

    // Symbols (w:sym)
    for (final sym in r.findElements('w:sym')) {
      final charHex = sym.getAttribute('w:char');
      if (charHex != null) {
        final code = int.tryParse(charHex, radix: 16);
        if (code != null) {
          final ch = _resolveSymbol(code,
              sym.getAttribute('w:font') ?? '');
          runs.add(_Run(ch, bold: bold, italic: italic));
        }
      }
    }
  }
  return runs;
}

_Table _parseTable(XmlElement tbl, Map<String, String> styleMap) {
  final rows = <List<_Cell>>[];
  for (final tr in tbl.findElements('w:tr')) {
    final cells = <_Cell>[];
    for (final tc in tr.findElements('w:tc')) {
      final tcPr   = tc.findElements('w:tcPr').firstOrNull;
      final shdFill = tcPr?.findElements('w:shd').firstOrNull
          ?.getAttribute('w:fill');
      final runs = <_Run>[];
      for (final p in tc.findElements('w:p')) {
        final para = _parseParagraph(p, styleMap);
        if (para.runs.isNotEmpty) {
          runs.addAll(para.runs);
          runs.add(_Run(' '));
        }
      }
      cells.add(_Cell(runs, shading: _hexColor(shdFill)));
    }
    if (cells.isNotEmpty) rows.add(cells);
  }
  return _Table(rows);
}

// ─── Header / Footer parser ───────────────────────────────────────────────────

List<_Run>? _parseHeaderFooter(
    Archive archive, String path, Map<String, String> styleMap) {
  final xml = _archiveString(archive, path);
  if (xml == null) return null;
  try {
    final doc  = XmlDocument.parse(xml);
    final runs = <_Run>[];
    for (final p in doc.findAllElements('w:p')) {
      final para = _parseParagraph(p, styleMap);
      if (para.runs.isNotEmpty) {
        runs.addAll(para.runs);
        runs.add(_Run('  '));
      }
    }
    return runs.isEmpty ? null : runs;
  } catch (_) {
    return null;
  }
}

// ─── Helpers ─────────────────────────────────────────────────────────────────

bool _boolProp(XmlElement? rPr, String tag) {
  if (rPr == null) return false;
  final el = rPr.findElements(tag).firstOrNull;
  if (el == null) return false;
  final val = el.getAttribute('w:val');
  return val == null || val == '1' || val == 'true' || val == 'on';
}

PdfColor? _hexColor(String? hex) {
  if (hex == null || hex.toLowerCase() == 'auto' || hex.length != 6) return null;
  final v = int.tryParse(hex, radix: 16);
  if (v == null) return null;
  return PdfColor.fromInt(0xFF000000 | v);
}

// Symbol font: private-use-area (0xF000+) → Unicode
String _resolveSymbol(int code, String font) {
  if (code >= 0xF000) {
    final byte = code & 0xFF;
    if (font.toLowerCase().contains('symbol') ||
        font.toLowerCase().contains('wingdings') == false) {
      const symbolMap = {
        0xB7: '•', 0xD7: '×', 0xF7: '÷', 0xB1: '±',
        0xB0: '°', 0xB5: 'µ', 0xAA: 'ª',
        0x22: '∀', 0x24: '∃', 0x27: '∋', 0xA5: '∞',
        0xB9: '≠', 0xBA: '≡', 0xBB: '≈',
        0x41: 'Α', 0x42: 'Β', 0x43: 'Χ', 0x44: 'Δ', 0x45: 'Ε',
        0x46: 'Φ', 0x47: 'Γ', 0x48: 'Η', 0x49: 'Ι',
        0x4B: 'Κ', 0x4C: 'Λ', 0x4D: 'Μ', 0x4E: 'Ν', 0x4F: 'Ο',
        0x50: 'Π', 0x52: 'Ρ', 0x53: 'Σ', 0x54: 'Τ', 0x55: 'Υ',
        0x57: 'Ω', 0x58: 'Ξ', 0x59: 'Ψ', 0x5A: 'Ζ',
        0x61: 'α', 0x62: 'β', 0x63: 'χ', 0x64: 'δ', 0x65: 'ε',
        0x66: 'φ', 0x67: 'γ', 0x68: 'η', 0x69: 'ι',
        0x6B: 'κ', 0x6C: 'λ', 0x6D: 'μ', 0x6E: 'ν', 0x6F: 'ο',
        0x70: 'π', 0x72: 'ρ', 0x73: 'σ', 0x74: 'τ', 0x75: 'υ',
        0x77: 'ω', 0x78: 'ξ', 0x79: 'ψ', 0x7A: 'ζ',
      };
      if (symbolMap.containsKey(byte)) return symbolMap[byte]!;
    }
    return String.fromCharCode(code - 0xF000 + 0x20);
  }
  return String.fromCharCode(code);
}

// ─── PDF builder ─────────────────────────────────────────────────────────────

Future<Uint8List> _buildPdf(
    List<_Node> nodes, _Margins m,
    List<_Run> headerRuns, List<_Run> footerRuns) async {
  final pdf = pw.Document(
    theme: pw.ThemeData.withFont(
      base:       pw.Font.helvetica(),
      bold:       pw.Font.helveticaBold(),
      italic:     pw.Font.helveticaOblique(),
      boldItalic: pw.Font.helveticaBoldOblique(),
    ),
  );

  final margin = pw.EdgeInsets.fromLTRB(
    m.left   * PdfPageFormat.point,
    m.top    * PdfPageFormat.point,
    m.right  * PdfPageFormat.point,
    m.bottom * PdfPageFormat.point,
  );

  pdf.addPage(pw.MultiPage(
    pageFormat: PdfPageFormat.a4,
    margin: margin,
    header: headerRuns.isEmpty ? null : (_) => pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 6),
      child: pw.Column(children: [
        _runsWidget(headerRuns, 9, pw.TextAlign.left),
        pw.Divider(height: 1, thickness: 0.5, color: PdfColors.grey400),
      ]),
    ),
    footer: footerRuns.isEmpty ? null : (ctx) => pw.Padding(
      padding: const pw.EdgeInsets.only(top: 6),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          _runsWidget(footerRuns, 9, pw.TextAlign.left),
          pw.Text('${ctx.pageNumber} / ${ctx.pagesCount}',
              style: pw.TextStyle(fontSize: 9, color: PdfColors.grey600)),
        ],
      ),
    ),
    build: (ctx) => nodes.map(_nodeToWidget).toList(),
  ));

  return await pdf.save();
}

pw.Widget _nodeToWidget(_Node node) => switch (node) {
  _Para p  => _paraWidget(p),
  _Table t => _tableWidget(t),
};

pw.Widget _paraWidget(_Para p) {
  if (p.runs.isEmpty) return pw.SizedBox(height: 4);

  final isHeading  = p.styleType != 'normal' && p.styleType != 'Title';
  final baseFontSz = _headingFontSize(p.styleType);
  final baseWeight = (isHeading || p.styleType == 'Title')
      ? pw.FontWeight.bold : pw.FontWeight.normal;
  final align      = _textAlign(p.align);

  final top    = p.spacingBefore > 0
      ? p.spacingBefore * PdfPageFormat.point : (isHeading ? 6.0 : 0.0);
  final bottom = p.spacingAfter  > 0
      ? p.spacingAfter  * PdfPageFormat.point : 4.0;

  final prefix = p.isBullet ? '• ' : '';
  final allRuns = prefix.isNotEmpty
      ? [_Run(prefix, bold: baseWeight == pw.FontWeight.bold), ...p.runs]
      : p.runs;

  pw.Widget content;
  if (allRuns.length == 1) {
    final r = allRuns.first;
    content = pw.Text(
      r.text,
      textAlign: align,
      style: pw.TextStyle(
        fontSize:   r.fontSize ?? baseFontSz,
        fontWeight: r.bold  ? pw.FontWeight.bold   : baseWeight,
        fontStyle:  r.italic ? pw.FontStyle.italic : pw.FontStyle.normal,
        decoration: r.underline ? pw.TextDecoration.underline : null,
        color:      r.color,
      ),
    );
  } else {
    content = pw.RichText(
      textAlign: align,
      text: pw.TextSpan(
        children: allRuns.map((r) => pw.TextSpan(
          text: r.text,
          style: pw.TextStyle(
            fontSize:   r.fontSize ?? baseFontSz,
            fontWeight: r.bold   ? pw.FontWeight.bold   : baseWeight,
            fontStyle:  r.italic ? pw.FontStyle.italic : pw.FontStyle.normal,
            decoration: r.underline ? pw.TextDecoration.underline : null,
            color:      r.color,
          ),
        )).toList(),
      ),
    );
  }

  if (p.shading != null) {
    content = pw.Container(
      color: p.shading,
      padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      child: content,
    );
  }

  return pw.Padding(
    padding: pw.EdgeInsets.only(top: top, bottom: bottom),
    child: content,
  );
}

pw.Widget _tableWidget(_Table t) {
  if (t.rows.isEmpty) return pw.SizedBox();
  final colCount = t.rows.map((r) => r.length).reduce((a, b) => a > b ? a : b);
  return pw.Padding(
    padding: const pw.EdgeInsets.symmetric(vertical: 6),
    child: pw.Table(
      border: pw.TableBorder.all(width: 0.5, color: PdfColors.grey600),
      columnWidths: { for (int i = 0; i < colCount; i++)
        i: const pw.FlexColumnWidth() },
      children: t.rows.map((row) => pw.TableRow(
        children: List.generate(colCount, (ci) {
          final cell = ci < row.length ? row[ci] : _Cell([]);
          pw.Widget content = pw.Padding(
            padding: const pw.EdgeInsets.all(4),
            child: _runsWidget(cell.runs, 10, pw.TextAlign.left),
          );
          if (cell.shading != null) {
            content = pw.Container(color: cell.shading, child: content);
          }
          return content;
        }),
      )).toList(),
    ),
  );
}

pw.Widget _runsWidget(List<_Run> runs, double defaultSize, pw.TextAlign align) {
  if (runs.isEmpty) return pw.SizedBox();
  if (runs.length == 1) {
    final r = runs.first;
    return pw.Text(r.text,
        textAlign: align,
        style: pw.TextStyle(
          fontSize: r.fontSize ?? defaultSize,
          fontWeight: r.bold   ? pw.FontWeight.bold   : pw.FontWeight.normal,
          fontStyle:  r.italic ? pw.FontStyle.italic  : pw.FontStyle.normal,
          decoration: r.underline ? pw.TextDecoration.underline : null,
          color: r.color,
        ));
  }
  return pw.RichText(
    textAlign: align,
    text: pw.TextSpan(
      children: runs.map((r) => pw.TextSpan(
        text: r.text,
        style: pw.TextStyle(
          fontSize:   r.fontSize ?? defaultSize,
          fontWeight: r.bold   ? pw.FontWeight.bold  : pw.FontWeight.normal,
          fontStyle:  r.italic ? pw.FontStyle.italic : pw.FontStyle.normal,
          decoration: r.underline ? pw.TextDecoration.underline : null,
          color:      r.color,
        ),
      )).toList(),
    ),
  );
}

pw.TextAlign _textAlign(String a) => switch (a) {
  'center'  => pw.TextAlign.center,
  'right'   => pw.TextAlign.right,
  'justify' => pw.TextAlign.justify,
  _         => pw.TextAlign.left,
};

double _headingFontSize(String t) => switch (t) {
  'Title'    => 22,
  'Heading1' => 18, 'Heading2' => 16, 'Heading3' => 14,
  'Heading4' => 13, 'Heading5' => 12, 'Heading6' => 11,
  _          => 11,
};
