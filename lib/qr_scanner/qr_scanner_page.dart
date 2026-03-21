import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '/theme/theme.dart';
import '../resources/machines/machine_detail_page.dart';
import '../resources/reagents/reagent_detail_page.dart';
import '../locations/location_detail_page.dart';

/// QR scanner page — mobile only.
/// Parses `bluelims://<projectRef>/<type>/<id>` and opens the matching detail page.
class QrScannerPage extends StatefulWidget {
  const QrScannerPage({super.key});

  @override
  State<QrScannerPage> createState() => _QrScannerPageState();
}

class _QrScannerPageState extends State<QrScannerPage> {
  final MobileScannerController _ctrl = MobileScannerController();
  bool _handled = false;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    if (_handled) return;
    final raw = capture.barcodes.firstOrNull?.rawValue;
    if (raw == null) return;
    _handleQr(raw);
  }

  void _handleQr(String raw) {
    final uri = Uri.tryParse(raw);
    if (uri == null || uri.scheme != 'bluelims') {
      _showError('Not a BlueOpenLIMS QR code.');
      return;
    }

    // URL: bluelims://<projectRef>/<type>/<id>
    // uri.host = projectRef, uri.pathSegments = ['<type>', '<id>']
    final segments = uri.pathSegments;
    if (segments.length < 2) {
      _showError('Invalid QR code format.');
      return;
    }

    final type = segments[0];
    final id   = int.tryParse(segments[1]);
    if (id == null) {
      _showError('Invalid item ID in QR code.');
      return;
    }

    setState(() => _handled = true);
    _ctrl.stop();

    Widget page;
    switch (type) {
      case 'machine':
        page = MachineDetailPage(machineId: id);
        break;
      case 'reagent':
        page = ReagentDetailPage(reagentId: id);
        break;
      case 'location':
        page = LocationDetailPage(locationId: id);
        break;
      default:
        _showError('Unknown type: $type');
        setState(() => _handled = false);
        _ctrl.start();
        return;
    }

    // Replace the scanner with the detail page so back returns to the main menu.
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => page),
    );
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: AppDS.red,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: AppDS.bg,
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text(
          'Scan QR Code',
          style: TextStyle(
              color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.flash_on_outlined, color: Colors.white70),
            tooltip: 'Toggle flash',
            onPressed: () => _ctrl.toggleTorch(),
          ),
        ],
      ),
      body: Stack(children: [
        MobileScanner(
          controller: _ctrl,
          onDetect: _onDetect,
        ),

        // Scan-area overlay
        Center(
          child: Container(
            width: 250,
            height: 250,
            decoration: BoxDecoration(
              border: Border.all(color: AppDS.accent, width: 3),
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),

        // Corner accents (cosmetic)
        Center(
          child: SizedBox(
            width: 250,
            height: 250,
            child: CustomPaint(painter: _CornerPainter()),
          ),
        ),

        // Hint label
        Positioned(
          bottom: 60,
          left: 0,
          right: 0,
          child: Center(
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.black54,
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Text(
                'Align QR code within the frame',
                style: TextStyle(color: Colors.white70, fontSize: 13),
              ),
            ),
          ),
        ),
      ]),
    );
  }
}

class _CornerPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppDS.accent
      ..strokeWidth = 4
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    const len = 28.0;
    const r   = 12.0;

    void corner(double x, double y, double dx, double dy) {
      canvas.drawLine(
          Offset(x + dx * r, y), Offset(x + dx * (r + len), y), paint);
      canvas.drawLine(
          Offset(x, y + dy * r), Offset(x, y + dy * (r + len)), paint);
    }

    corner(0, 0, 1, 1);
    corner(size.width, 0, -1, 1);
    corner(0, size.height, 1, -1);
    corner(size.width, size.height, -1, -1);
  }

  @override
  bool shouldRepaint(covariant CustomPainter _) => false;
}
