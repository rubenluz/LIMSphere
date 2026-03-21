// printing_driver.dart - Part of printing_page.dart.
// ZPL and Brother QL raster protocol generators; USB/Wi-Fi/TCP send;
// printer reachability check (_checkPrinterConnection).

part of 'printing_page.dart';

// ─────────────────────────────────────────────────────────────────────────────
// ZPL generation (Zebra Programming Language — for Wi-Fi TCP printing)
// ─────────────────────────────────────────────────────────────────────────────

/// Generates a ZPL string for all [records]. Each record produces [cfg.copies]
/// labels. Pass an empty list to produce one label from template placeholders only.
String _generateZpl(LabelTemplate tpl, List<Map<String, dynamic>> records, PrinterConfig cfg) {
  final buf = StringBuffer();
  final dotsPerMm = tpl.dpi / 25.4;
  int mm(double v) => (v * dotsPerMm).round().clamp(0, 9999);

  final printRecords = records.isEmpty ? [<String, dynamic>{}] : records;

  for (final record in printRecords) {
    for (int c = 0; c < tpl.copies; c++) {
      buf.write('^XA\n');
      buf.write('^PW${mm(tpl.labelW)}\n');
      buf.write('^LL${mm(tpl.labelH)}\n');
      buf.write('^CI28\n'); // UTF-8
      if (tpl.rotate) buf.write('^FWR\n');

      for (final f in tpl.fields) {
        // Resolve placeholders
        String value = f.content;
        if (f.isPlaceholder) {
          record.forEach((k, v) => value = value.replaceAll('{$k}', v?.toString() ?? ''));
          value = value.replaceAll(RegExp(r'\{[^}]+\}'), ''); // strip unresolved
        }
        // Sanitise: ZPL field data must not contain ^ or ~
        value = value.replaceAll('^', ' ').replaceAll('~', ' ');

        final x = mm(f.x);
        final y = mm(f.y);
        final w = mm(f.w);
        final h = mm(f.h);

        switch (f.type) {
          case LabelFieldType.text:
            final fh = mm(f.h).clamp(8, 200);
            final fw = (fh * 0.6).round();
            buf.write('^FO$x,$y^A0N,$fh,$fw^FD$value^FS\n');
          case LabelFieldType.qrcode:
            final mag = (h / 21.0).clamp(1.0, 10.0).round();
            buf.write('^FO$x,$y^BQN,2,$mag^FDQA,$value^FS\n');
          case LabelFieldType.barcode:
            buf.write('^FO$x,$y^BY2^BCN,$h,Y,N,N^FD$value^FS\n');
          case LabelFieldType.divider:
            buf.write('^FO$x,$y^GB$w,1,1^FS\n');
          case LabelFieldType.image:
            break; // image fields not supported in ZPL output
        }
      }

      buf.write('^XZ\n');
    }
  }
  return buf.toString();
}

/// Sends ZPL to a Wi-Fi printer on port 9100 (raw TCP).
Future<void> _sendZplOverWifi(String ip, String zpl) async {
  final socket = await Socket.connect(ip, 9100, timeout: const Duration(seconds: 8));
  try {
    socket.write(zpl);
    await socket.flush();
  } finally {
    await socket.close();
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Brother QL raster protocol (TCP port 9100)
// Supports: QL-820NWB, QL-810W, QL-800, QL-700 and compatible models.
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

/// Renders a label template + data record to a rasterised [ui.Image].
Future<ui.Image> _renderLabelToImage(
    LabelTemplate tpl, Map<String, dynamic> data, int dpi) async {
  final pxPerMm = dpi / 25.4;
  final w = (tpl.labelW * pxPerMm).ceil();
  final h = (tpl.labelH * pxPerMm).ceil();

  final recorder = ui.PictureRecorder();
  final canvas = ui.Canvas(recorder, Rect.fromLTWH(0, 0, w.toDouble(), h.toDouble()));

  // White background
  canvas.drawRect(Rect.fromLTWH(0, 0, w.toDouble(), h.toDouble()),
      ui.Paint()..color = const Color(0xFFFFFFFF));

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
              fontSize: f.fontSize * pxPerMm / (25.4 / 72), // pt → px at target DPI
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
          qrPainter.paint(canvas, Size(fh, fh));
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

/// Generates a Brother QL raster data blob for all [records].
/// Send the result via [_sendBrotherQl].
Future<Uint8List> _generateBrotherQlData(
    LabelTemplate tpl, List<Map<String, dynamic>> records, PrinterConfig cfg) async {
  final printRecords = records.isEmpty ? [<String, dynamic>{}] : records;
  final buf = BytesBuilder();

  // Invalidate (200 null bytes) + Initialize (ESC @)
  buf.add(List.filled(200, 0));
  buf.add(const [0x1B, 0x40]);

  int pageNum = 0;
  for (final record in printRecords) {
    for (int c = 0; c < tpl.copies; c++, pageNum++) {
      // Switch to raster mode (ESC i a 0x01)
      buf.add(const [0x1B, 0x69, 0x61, 0x01]);

      // Print info (ESC i z) — flags | media type | width mm | length mm | ... | page#
      buf.add([
        0x1B, 0x69, 0x7A,
        0x8E,                   // flags: auto-detect
        0x0B,                   // media type: die-cut label
        tpl.labelW.round(),     // tape width in mm
        tpl.labelH.round(),     // label length in mm
        0, 0, 0, 0,
        pageNum,
        0,
      ]);

      // Auto-cut (ESC i M) if enabled
      if (tpl.autoCut) { buf.add(const [0x1B, 0x69, 0x4D, 0x40]); }

      // Render label to RGBA image
      final image = await _renderLabelToImage(tpl, record, tpl.dpi);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
      if (byteData == null) continue;
      final rgba = byteData.buffer.asUint8List();
      final iw = image.width;
      final ih = image.height;

      // Brother QL uses 90 bytes per raster line for 62 mm tape (720 dots).
      // Adjust bytesPerLine for other tape widths.
      const bytesPerLine = 90;

      for (int row = 0; row < ih; row++) {
        final line = List<int>.filled(bytesPerLine, 0);
        for (int col = 0; col < iw && col < bytesPerLine * 8; col++) {
          final idx = (row * iw + col) * 4;
          final gray = (rgba[idx] * 0.299 + rgba[idx + 1] * 0.587 + rgba[idx + 2] * 0.114).round();
          if (gray < 128) {
            // Black pixel — set bit (MSB first)
            final byteIdx = col ~/ 8;
            if (byteIdx < bytesPerLine) { line[byteIdx] |= (1 << (7 - col % 8)); }
          }
        }
        buf.add([0x67, 0x00, bytesPerLine]);
        buf.add(line);
      }

      // Print + feed (0x1A) or print without feed (0x0C)
      buf.addByte(tpl.autoCut ? 0x1A : 0x0C);
    }
  }

  return buf.toBytes();
}

// ─────────────────────────────────────────────────────────────────────────────
// Brother QL legacy raster protocol (QL-500, QL-550, QL-570, QL-650TD)
// These older models omit the ESC i z print-info command, are USB-only,
// and are fixed at 300 DPI.
// ─────────────────────────────────────────────────────────────────────────────

Future<Uint8List> _generateBrotherQlLegacyData(
    LabelTemplate tpl, List<Map<String, dynamic>> records) async {
  final printRecords = records.isEmpty ? [<String, dynamic>{}] : records;
  final buf = BytesBuilder();

  // Invalidate (200 null bytes) + Initialize (ESC @)
  buf.add(List.filled(200, 0));
  buf.add(const [0x1B, 0x40]);
  // Switch to raster mode (ESC i a 0x01)
  buf.add(const [0x1B, 0x69, 0x61, 0x01]);

  // No ESC i z (print-info) — not supported on legacy models.
  // No ESC i M (auto-cut settings) — cut is triggered per-page via 0x1A.

  for (final record in printRecords) {
    for (int c = 0; c < tpl.copies; c++) {
      // Legacy models are fixed at 300 DPI
      final image = await _renderLabelToImage(tpl, record, 300);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
      if (byteData == null) continue;
      final rgba = byteData.buffer.asUint8List();
      final iw = image.width;
      final ih = image.height;

      const bytesPerLine = 90; // 720 dots for 62 mm tape at 300 DPI
      for (int row = 0; row < ih; row++) {
        final line = List<int>.filled(bytesPerLine, 0);
        for (int col = 0; col < iw && col < bytesPerLine * 8; col++) {
          final idx = (row * iw + col) * 4;
          final gray = (rgba[idx] * 0.299 + rgba[idx + 1] * 0.587 + rgba[idx + 2] * 0.114).round();
          if (gray < 128) {
            final byteIdx = col ~/ 8;
            if (byteIdx < bytesPerLine) { line[byteIdx] |= (1 << (7 - col % 8)); }
          }
        }
        buf.add([0x67, 0x00, bytesPerLine]);
        buf.add(line);
      }
      // 0x1A = print + cut, 0x0C = print without cut
      buf.addByte(tpl.autoCut ? 0x1A : 0x0C);
    }
  }
  return buf.toBytes();
}

/// Sends Brother QL raster data to the printer over raw TCP port 9100.
Future<void> _sendBrotherQl(String ip, Uint8List data) async {
  final socket = await Socket.connect(ip, 9100, timeout: const Duration(seconds: 8));
  try {
    socket.add(data);
    await socket.flush();
  } finally {
    await socket.close();
  }
}

/// Sends raw bytes to a USB-connected printer.
/// - Linux/macOS: writes directly to the device file (e.g. /dev/usb/lp0).
/// - Windows: spools to the print queue via `COPY /B`.
Future<void> _sendViaUsb(String path, Uint8List data) async {
  if (Platform.isLinux || Platform.isMacOS) {
    final raf = await File(path).open(mode: FileMode.writeOnly);
    try { await raf.writeFrom(data); } finally { await raf.close(); }
  } else if (Platform.isWindows) {
    final tmp = File('${Directory.systemTemp.path}\\bluelims_print.prn');
    await tmp.writeAsBytes(data);
    try {
      final r = await Process.run('cmd', ['/c', 'COPY /B "${tmp.path}" "$path"'], runInShell: true);
      if (r.exitCode != 0) throw Exception('USB print failed: ${r.stderr}');
    } finally {
      await tmp.delete();
    }
  } else {
    throw UnsupportedError('USB printing is not supported on this platform.');
  }
}

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
        // On Linux/macOS the device file (e.g. /dev/usb/lp0) only exists when
        // the USB device is physically enumerated — so existsSync() is reliable.
        return File(cfg.usbPath).existsSync()
            ? _ConnState.connected
            : _ConnState.unreachable;
      } else if (Platform.isWindows) {
        // Use WMI Win32_Printer to distinguish between:
        //   • driver installed + printer actually online  → connected
        //   • driver installed + printer offline/not plugged → driverOnly
        //   • no driver / unknown name                    → unreachable
        final name = cfg.usbPath.replaceAll("'", "''"); // escape WMI filter
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
      // Wi-Fi / Bluetooth: attempt a TCP handshake on port 9100
      final socket = await Socket.connect(
          cfg.ipAddress, 9100, timeout: const Duration(seconds: 3));
      await socket.close();
      return _ConnState.connected;
    }
  } catch (_) {
    return _ConnState.unreachable;
  }
}

/// Dispatches to ZPL or Brother QL, then routes to USB / Wi-Fi / Bluetooth.
Future<void> _sendToPrinter(
    LabelTemplate tpl, List<Map<String, dynamic>> records, PrinterConfig cfg) async {
  if (cfg.protocol == 'brother_ql_legacy') {
    // Legacy QL models (QL-500/550/570/650TD) are USB-only
    final data = await _generateBrotherQlLegacyData(tpl, records);
    await _sendViaUsb(cfg.usbPath, data);
  } else if (cfg.connectionType == 'usb') {
    final Uint8List data;
    if (cfg.protocol == 'brother_ql') {
      data = await _generateBrotherQlData(tpl, records, cfg);
    } else {
      data = Uint8List.fromList(_generateZpl(tpl, records, cfg).codeUnits);
    }
    await _sendViaUsb(cfg.usbPath, data);
  } else if (cfg.protocol == 'brother_ql') {
    final data = await _generateBrotherQlData(tpl, records, cfg);
    await _sendBrotherQl(cfg.ipAddress, data);
  } else {
    final zpl = _generateZpl(tpl, records, cfg);
    await _sendZplOverWifi(cfg.ipAddress, zpl);
  }
}
