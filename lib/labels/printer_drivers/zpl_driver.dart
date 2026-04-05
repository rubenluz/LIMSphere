// zpl_driver.dart — Part of label_page.dart.
// ZPL (Zebra Programming Language) driver.
// Supported printers: Zebra ZD421, ZD620, ZD230, GK420d, and ZPL-compatible models.
// Connection: Wi-Fi or USB via raw TCP port 9100.

part of '../label_page.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Driver info
// ─────────────────────────────────────────────────────────────────────────────

/// Raw TCP port used by all ZPL printers.
const _kZplPort = 9100;

// ─────────────────────────────────────────────────────────────────────────────
// ZPL generation
// ─────────────────────────────────────────────────────────────────────────────

/// Generates a ZPL string for all [records]. Each record produces [tpl.copies]
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
        String value = f.content;
        if (f.isPlaceholder) {
          value = _resolveDataFields(value, record);
          value = value.replaceAll(RegExp(r'\{[^}]+\}'), '');
        }
        // ZPL field data must not contain ^ or ~
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
            break;
        }
      }

      buf.write('^XZ\n');
    }
  }
  return buf.toString();
}

// ─────────────────────────────────────────────────────────────────────────────
// Communication
// ─────────────────────────────────────────────────────────────────────────────

/// Sends ZPL to a Wi-Fi printer on port [_kZplPort] (raw TCP).
Future<void> _sendZplOverWifi(String ip, String zpl) async {
  final socket = await Socket.connect(ip, _kZplPort, timeout: const Duration(seconds: 8));
  try {
    socket.write(zpl);
    await socket.flush();
  } finally {
    await socket.close();
  }
}

Future<void> _sendZplOverUsb(PrinterConfig cfg, String zpl) async {
  if (cfg.connectionType != 'usb') {
    throw UnsupportedError('ZPL USB send requires a USB profile.');
  }
  await _sendViaUsb(cfg.usbPath, Uint8List.fromList(utf8.encode(zpl)));
}

Future<_ConnState> _checkZplConnection(PrinterConfig cfg) async {
  if (cfg.connectionType == 'usb') {
    return _checkUsbPrinterConnection(cfg.usbPath);
  }
  return _checkTcpPrinterConnection(cfg.ipAddress, _kZplPort);
}

Future<void> _printZpl(
    LabelTemplate tpl, List<Map<String, dynamic>> records, PrinterConfig cfg) async {
  final zpl = _generateZpl(tpl, records, cfg);
  if (cfg.connectionType == 'usb') {
    debugPrint('[PRINT] ZPL data: ${zpl.length} chars -> USB "${cfg.usbPath}"');
    await _sendZplOverUsb(cfg, zpl);
  } else {
    debugPrint('[PRINT] ZPL: ${zpl.length} chars -> TCP ${cfg.ipAddress}:$_kZplPort');
    await _sendZplOverWifi(cfg.ipAddress, zpl);
  }
}
