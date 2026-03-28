// printer_machine_driver.dart — Part of label_page.dart.
// Shared label rendering, USB communication, connection check, and print dispatch.
// Protocol-specific generation lives in printer_drivers/:
//   zpl_driver.dart, brother_ql_700.dart, brother_ql_570.dart.

part of '../label_page.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Placeholder resolution
// ─────────────────────────────────────────────────────────────────────────────

String _resolvePlaceholders(String content, Map<String, dynamic> data) {
  final now = DateTime.now();
  final dateFmt = DateFormat('yyyy-MM-dd');
  final timeFmt = DateFormat('HH:mm');
  String s = content
      .replaceAll('{current_time}', timeFmt.format(now))
      .replaceAll('{current_date}', dateFmt.format(now));
  s = s.replaceAllMapped(RegExp(r'\{date\+(\d+)\}'), (m) {
    final n = int.tryParse(m.group(1) ?? '') ?? 0;
    return dateFmt.format(now.add(Duration(days: n)));
  });
  data.forEach((k, v) => s = s.replaceAll('{$k}', v?.toString() ?? ''));
  return s.replaceAll(RegExp(r'\{[^}]+\}'), '');
}

// ─────────────────────────────────────────────────────────────────────────────
// Label rendering
// ─────────────────────────────────────────────────────────────────────────────

/// Renders a label template + data record to a rasterised [ui.Image].
///
/// [tpl.topOffsetMm] shifts all content UP by that many mm so it prints at the
/// correct position when the printer has an inherent top-feed offset (e.g.
/// compatible die-cut labels with a larger-than-spec gap). Content within the
/// top `topOffsetMm` mm of the template is clipped off the label image.
Future<ui.Image> _renderLabelToImage(
    LabelTemplate tpl, Map<String, dynamic> data, int dpi, {bool floorHeight = false}) async {
  final pxPerMm = dpi / 25.4;
  final w = (tpl.labelW * pxPerMm).ceil();
  final h = floorHeight ? (tpl.labelH * pxPerMm).floor() : (tpl.labelH * pxPerMm).ceil();

  final recorder = ui.PictureRecorder();
  final canvas = ui.Canvas(recorder, Rect.fromLTWH(0, 0, w.toDouble(), h.toDouble()));

  canvas.drawRect(Rect.fromLTWH(0, 0, w.toDouble(), h.toDouble()),
      ui.Paint()..color = const Color(0xFFFFFFFF));

  if (tpl.topOffsetMm != 0) canvas.translate(0, -(tpl.topOffsetMm * pxPerMm));

  for (final f in tpl.fields) {
    final x = f.x * pxPerMm;
    final y = f.y * pxPerMm;
    final fw = f.w * pxPerMm;
    final fh = f.h * pxPerMm;
    final content = f.isPlaceholder ? _resolvePlaceholders(f.content, data) : f.content;

    switch (f.type) {
      case LabelFieldType.text:
        final tp = TextPainter(
          text: TextSpan(
            text: content,
            style: TextStyle(
              fontSize: f.fontSize * pxPerMm * (25.4 / 72), // pt → px
              fontWeight: f.fontWeight,
              color: f.color,
            ),
          ),
          textDirection: ui.TextDirection.ltr,
          textAlign: f.textAlign,
        );
        tp.layout(maxWidth: fw);
        canvas.save();
        canvas.translate(x, y);
        tp.paint(canvas, Offset.zero);
        canvas.restore();
      case LabelFieldType.qrcode:
        if (content.isNotEmpty) {
          final qrPainter = QrPainter(
            data: content,
            version: QrVersions.auto,
            gapless: true,
            eyeStyle: const QrEyeStyle(eyeShape: QrEyeShape.square, color: Color(0xFF000000)),
            dataModuleStyle: const QrDataModuleStyle(dataModuleShape: QrDataModuleShape.square, color: Color(0xFF000000)),
          );
          canvas.save();
          canvas.translate(x, y);
          final qrSize = fh < fw ? fh : fw;
          qrPainter.paint(canvas, Size(qrSize, qrSize));
          canvas.restore();
        }
      case LabelFieldType.barcode:
        _drawBarcodeOnCanvas(canvas, Rect.fromLTWH(x, y, fw, fh));
      case LabelFieldType.divider:
        canvas.drawRect(Rect.fromLTWH(x, y + fh / 2, fw, 1.0),
            ui.Paint()..color = f.color);
      case LabelFieldType.image:
        break;
    }
  }

  final picture = recorder.endRecording();
  return picture.toImage(w, h);
}

void _drawBarcodeOnCanvas(ui.Canvas canvas, Rect rect) {
  final paint = ui.Paint()..color = const Color(0xFF000000);
  final widths = [2.0, 1.0, 3.0, 1.0, 2.0, 1.0, 1.0, 3.0, 2.0, 1.0, 2.0, 1.0, 3.0, 1.0, 2.0];
  final total = widths.fold(0.0, (a, b) => a + b);
  double x = rect.left;
  bool draw = true;
  for (final w in widths) {
    final barW = w / total * rect.width;
    if (draw) { canvas.drawRect(Rect.fromLTWH(x, rect.top, barW - 0.5, rect.height), paint); }
    x += barW;
    draw = !draw;
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// USB communication
// ─────────────────────────────────────────────────────────────────────────────

/// Sends raw bytes to a USB-connected printer.
/// - Linux/macOS: writes directly to the device file (e.g. /dev/usb/lp0).
/// - Windows: uses the Windows Print Spooler with RAW data type via PowerShell.
Future<void> _sendViaUsb(String path, Uint8List data) async {
  if (Platform.isLinux || Platform.isMacOS) {
    final raf = await File(path).open(mode: FileMode.writeOnly);
    try { await raf.writeFrom(data); } finally { await raf.close(); }
  } else if (Platform.isWindows) {
    final tmp = File('${Directory.systemTemp.path}\\bluelims_print.prn');
    final ps1 = File('${Directory.systemTemp.path}\\bluelims_print.ps1');
    await tmp.writeAsBytes(data);
    // Write PS1 with UTF-8 BOM so PowerShell 5.1 reads it as UTF-8, not ANSI.
    // All $variables are PowerShell; Dart raw string r''' keeps them literal.
    const psScript = r'''
param([string]$dataFile, [string]$printerName)
$ErrorActionPreference = "Stop"

$bytes = [System.IO.File]::ReadAllBytes($dataFile)
Write-Host "[PS] bytes=$($bytes.Length) printer=$printerName"

Add-Type -TypeDefinition @"
using System;
using System.Runtime.InteropServices;
[StructLayout(LayoutKind.Sequential, CharSet=CharSet.Ansi)]
public class DOCINFOA {
  [MarshalAs(UnmanagedType.LPStr)] public string pDocName;
  [MarshalAs(UnmanagedType.LPStr)] public string pOutputFile;
  [MarshalAs(UnmanagedType.LPStr)] public string pDataType;
}
public class WinSpool {
  [DllImport("winspool.drv", EntryPoint="OpenPrinterA")]
  public static extern bool OpenPrinter([MarshalAs(UnmanagedType.LPStr)] string n, out IntPtr h, IntPtr d);
  [DllImport("winspool.drv")]
  public static extern bool ClosePrinter(IntPtr h);
  [DllImport("winspool.drv", EntryPoint="StartDocPrinterA")]
  public static extern int StartDocPrinter(IntPtr h, int lv, [In, MarshalAs(UnmanagedType.LPStruct)] DOCINFOA di);
  [DllImport("winspool.drv")]
  public static extern bool EndDocPrinter(IntPtr h);
  [DllImport("winspool.drv")]
  public static extern bool StartPagePrinter(IntPtr h);
  [DllImport("winspool.drv")]
  public static extern bool EndPagePrinter(IntPtr h);
  [DllImport("winspool.drv")]
  public static extern bool WritePrinter(IntPtr h, byte[] b, int n, out int w);
}
"@ -ErrorAction SilentlyContinue

$ph = [IntPtr]::Zero
if (-not [WinSpool]::OpenPrinter($printerName, [ref]$ph, [IntPtr]::Zero)) {
  throw "OpenPrinter failed for: $printerName"
}
try {
  $di = New-Object DOCINFOA
  $di.pDocName  = 'BlueOpenLIMS'
  $di.pDataType = 'RAW'
  $job = [WinSpool]::StartDocPrinter($ph, 1, $di)
  if ($job -le 0) { throw "StartDocPrinter failed (job=$job)" }
  try {
    [WinSpool]::StartPagePrinter($ph) | Out-Null
    $w = 0
    if (-not [WinSpool]::WritePrinter($ph, $bytes, $bytes.Length, [ref]$w)) {
      throw "WritePrinter failed"
    }
    Write-Host "[PS] WritePrinter: written=$w"
    [WinSpool]::EndPagePrinter($ph) | Out-Null
  } finally { [WinSpool]::EndDocPrinter($ph) | Out-Null }
} finally { [WinSpool]::ClosePrinter($ph) | Out-Null }

$flagLabels = [ordered]@{
  0x0002 = 'Print error';
  0x0040 = 'Out of paper / wrong media';
  0x0020 = 'Printer offline';
  0x0200 = 'Job blocked by device queue';
  0x0400 = 'User intervention required'
}
$deadline = (Get-Date).AddSeconds(8)
while ((Get-Date) -lt $deadline) {
  Start-Sleep -Milliseconds 400
  $pj = Get-WmiObject Win32_PrintJob 2>$null | Where-Object { $_.Name -like "*,$job" }
  if ($null -eq $pj) { break }
  $mask = [int]$pj.StatusMask
  if ($mask -band 0x0080) { break }
  if ($mask -band 0x0100) { break }
  foreach ($flag in $flagLabels.Keys) {
    if ($mask -band $flag) { throw "Printer error: $($flagLabels[$flag])" }
  }
}
''';
    await ps1.writeAsBytes([0xEF, 0xBB, 0xBF, ...psScript.codeUnits]);
    try {
      final r = await Process.run('powershell', [
        '-NoProfile', '-NonInteractive', '-ExecutionPolicy', 'Bypass',
        '-File', ps1.path, '-dataFile', tmp.path, '-printerName', path,
      ]);
      final stdout = (r.stdout as String).trim();
      final stderr = (r.stderr as String).trim();
      debugPrint('[PRINT] PS exit=${r.exitCode}');
      if (stdout.isNotEmpty) debugPrint('[PRINT] PS stdout:\n$stdout');
      if (stderr.isNotEmpty) debugPrint('[PRINT] PS stderr:\n$stderr');
      if (r.exitCode != 0) {
        final msg = stderr.split('\n').first.trim();
        throw Exception(msg.isNotEmpty ? msg : 'USB print failed (stdout: $stdout)');
      }
    } finally {
      await tmp.delete().catchError((_) => tmp);
      await ps1.delete().catchError((_) => ps1);
    }
  } else {
    throw UnsupportedError('USB printing is not supported on this platform.');
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Connection check
// ─────────────────────────────────────────────────────────────────────────────

/// Checks whether the configured printer is reachable.
///
/// Returns [_ConnState.connected] if the printer is ready to receive jobs,
/// [_ConnState.driverOnly] if the driver/port is registered but the device is
/// offline or not physically connected (Windows USB only), and
/// [_ConnState.unreachable] if the printer cannot be found at all.
Future<_ConnState> _checkPrinterConnection(PrinterConfig cfg) async {
  try {
    if (cfg.connectionType == 'usb') {
      if (Platform.isLinux || Platform.isMacOS) {
        return File(cfg.usbPath).existsSync()
            ? _ConnState.connected
            : _ConnState.unreachable;
      } else if (Platform.isWindows) {
        final name = cfg.usbPath.replaceAll("'", "''");
        final filter = "Name='$name'";
        final script =
            "\$p = Get-WmiObject Win32_Printer -Filter \"$filter\" 2>\$null; "
            "if (\$null -ne \$p) { "
            "  if (\$p.WorkOffline -eq \$true -or \$p.PrinterStatus -eq 7) { 'driver_only' } "
            "  else { 'ready' } "
            "} else { 'not_found' }";
        final r = await Process.run(
          'powershell',
          ['-Command', script],
          runInShell: true,
        );
        final out = r.stdout.toString().trim();
        if (out.contains('ready')) return _ConnState.connected;
        if (out.contains('driver_only')) return _ConnState.driverOnly;
        return _ConnState.unreachable;
      }
      return _ConnState.unreachable;
    } else {
      final socket = await Socket.connect(
          cfg.ipAddress, 9100, timeout: const Duration(seconds: 3));
      await socket.close();
      return _ConnState.connected;
    }
  } catch (_) {
    return _ConnState.unreachable;
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Print dispatch
// ─────────────────────────────────────────────────────────────────────────────

/// Dispatches to the appropriate protocol generator, then routes to USB / Wi-Fi.
Future<void> _sendToPrinter(
    LabelTemplate tpl, List<Map<String, dynamic>> records, PrinterConfig cfg) async {
  debugPrint('[PRINT] protocol=${cfg.protocol} connection=${cfg.connectionType} '
      'device="${cfg.deviceName}" usbPath="${cfg.usbPath}" ip=${cfg.ipAddress}');
  debugPrint('[PRINT] template: ${tpl.labelW}×${tpl.labelH}mm DPI=${tpl.dpi} '
      'continuous=${cfg.continuousRoll} cutMode=${tpl.cutMode} records=${records.length}');

  if (cfg.protocol == 'brother_ql_legacy') {
    final data = await _generateBrotherQl570Data(tpl, records, cfg);
    debugPrint('[PRINT] QL-570 legacy data: ${data.length} bytes → USB "${cfg.usbPath}"');
    await _sendViaUsb(cfg.usbPath, data);
  } else if (cfg.protocol == 'brother_ql') {
    final data = await _generateBrotherQl700Data(tpl, records, cfg);
    if (cfg.connectionType == 'usb') {
      debugPrint('[PRINT] QL-700 raster data: ${data.length} bytes → USB "${cfg.usbPath}"');
      await _sendViaUsb(cfg.usbPath, data);
    } else {
      debugPrint('[PRINT] QL-700 raster data: ${data.length} bytes → TCP ${cfg.ipAddress}:9100');
      await _sendBrotherQl700(cfg.ipAddress, data);
    }
  } else {
    final zpl = _generateZpl(tpl, records, cfg);
    if (cfg.connectionType == 'usb') {
      debugPrint('[PRINT] ZPL data: ${zpl.length} chars → USB "${cfg.usbPath}"');
      await _sendViaUsb(cfg.usbPath, Uint8List.fromList(zpl.codeUnits));
    } else {
      debugPrint('[PRINT] ZPL: ${zpl.length} chars → TCP ${cfg.ipAddress}:9100');
      await _sendZplOverWifi(cfg.ipAddress, zpl);
    }
  }
}
