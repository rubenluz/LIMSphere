// qr_scanner_page.dart - QR/barcode scanner using the device camera via
// mobile_scanner; returns the decoded string to the caller via Navigator.pop.
// QR format rules and builder: qr_code_rules.dart

import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide LocalStorage;

import '/theme/module_permission.dart';
import '/theme/theme.dart';
import '/core/fish_db_schema.dart';
import '/core/sop_db_schema.dart';
import '/supabase/supabase_manager.dart';
import '../../resources/machines/machine_detail_page.dart';
import '../../resources/reagents/reagent_detail_page.dart';
import '../../resources/locations/location_detail_page.dart';
import '../../resources/locations/room_detail_page.dart';
import '../../culture_collection/strains/strain_detail_page.dart';
import '../../culture_collection/samples/sample_detail_page.dart';
import '../../fish_facility/lines/fish_lines_detail_page.dart';
import '../../fish_facility/lines/fish_lines_connection_model.dart';
import '../../fish_facility/stocks/stocks_detail_page.dart';
import '../../fish_facility/tanks/tanks_connection_model.dart';
import '../../users/user_detail_page.dart';
import '../../sops/sop_model.dart';
import '../../sops/doc_viewer_page.dart';
import 'qr_code_rules.dart';
import 'qr_record_lookup.dart';
import 'qr_scan_result_page.dart';

/// QR scanner page — mobile only.
/// Parses `limsphere://<projectCode>/<category>/<uniqueId>` and opens the
/// matching detail page.
class QrScannerPage extends StatefulWidget {
  const QrScannerPage({super.key});

  @override
  State<QrScannerPage> createState() => _QrScannerPageState();
}

class _QrScannerPageState extends State<QrScannerPage> {
  final MobileScannerController _ctrl = MobileScannerController();
  bool _handled = false;
  bool _fetching = false;

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

  Future<void> _handleQr(String raw) async {
    final payload = QrRules.parse(raw);
    if (payload == null) {
      await _rejectScan('Not a valid LIMS Sphere QR code.');
      return;
    }
    final currentProject = SupabaseManager.projectRef ?? 'local';
    if (!QrRules.belongsToProject(payload, currentProject)) {
      await _rejectScan(
        'This QR code belongs to project ${payload.projectCode}, not $currentProject.',
      );
      return;
    }

    setState(() {
      _handled = true;
      _fetching = true;
    });
    _ctrl.stop();

    Widget page;
    try {
      final record = await lookupQrRecord(payload);
      page = ResolvedModulePermission(
        moduleId: record.spec.moduleId,
        child: QrScanResultPage(
          record: record,
          openRecord: () => _resolveRoute(payload),
          scanAgainPage: const QrScannerPage(),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      _showError('Could not load record: $e');
      setState(() {
        _handled = false;
        _fetching = false;
      });
      _ctrl.start();
      return;
    }

    if (!mounted) return;
    Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => page));
  }

  Future<Widget> _resolveRoute(QrPayload payload) => resolveQrRoute(payload);

  Future<void> _rejectScan(String message) async {
    if (!mounted) return;
    setState(() => _handled = true);
    await _ctrl.stop();
    if (!mounted) return;
    _showError(message);
    await Future<void>.delayed(const Duration(milliseconds: 1400));
    if (!mounted) return;
    setState(() => _handled = false);
    await _ctrl.start();
  }

  Future<void> _enterQrLink() async {
    if (_handled) return;
    setState(() => _handled = true);
    await _ctrl.stop();
    if (!mounted) return;

    final controller = TextEditingController();
    final raw = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Look up QR link'),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: TextInputType.url,
          autocorrect: false,
          decoration: const InputDecoration(
            labelText: 'LIMSphere link',
            hintText: 'limsphere://project/category/id',
            border: OutlineInputBorder(),
          ),
          onSubmitted: (value) {
            final trimmed = value.trim();
            if (trimmed.isNotEmpty) Navigator.pop(dialogContext, trimmed);
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final value = controller.text.trim();
              if (value.isNotEmpty) Navigator.pop(dialogContext, value);
            },
            child: const Text('Look up'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (!mounted) return;
    setState(() => _handled = false);
    if (raw == null) {
      await _ctrl.start();
      return;
    }
    await _handleQr(raw);
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
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.keyboard_outlined, color: Colors.white70),
            tooltip: 'Enter QR link',
            onPressed: _enterQrLink,
          ),
          IconButton(
            icon: const Icon(Icons.flash_on_outlined, color: Colors.white70),
            tooltip: 'Toggle flash',
            onPressed: () => _ctrl.toggleTorch(),
          ),
        ],
      ),
      body: Stack(
        children: [
          MobileScanner(controller: _ctrl, onDetect: _onDetect),

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
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 8,
                ),
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

          // Loading overlay while fetching record
          if (_fetching)
            Container(
              color: Colors.black54,
              child: const Center(
                child: CircularProgressIndicator(color: AppDS.accent),
              ),
            ),
        ],
      ),
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
    const r = 12.0;

    void corner(double x, double y, double dx, double dy) {
      canvas.drawLine(
        Offset(x + dx * r, y),
        Offset(x + dx * (r + len), y),
        paint,
      );
      canvas.drawLine(
        Offset(x, y + dy * r),
        Offset(x, y + dy * (r + len)),
        paint,
      );
    }

    corner(0, 0, 1, 1);
    corner(size.width, 0, -1, 1);
    corner(0, size.height, 1, -1);
    corner(size.width, size.height, -1, -1);
  }

  @override
  bool shouldRepaint(covariant CustomPainter _) => false;
}

/// Top-level — shared by [QrScannerPage] and the MenuPage deep-link handler.
Future<Widget> resolveQrRoute(QrPayload payload) async {
  // Confirm the target still exists (and apply user-record access checks)
  // before constructing any detail route, including external deep links.
  await lookupQrRecord(payload);
  switch (payload.type) {
    case 'machines':
      return ResolvedModulePermission(
        moduleId: 'equipment',
        child: MachineDetailPage(machineId: payload.id),
      );

    case 'reagents':
      return ResolvedModulePermission(
        moduleId: 'reagents',
        child: ReagentDetailPage(reagentId: payload.id),
      );

    case 'locations':
      final row = await Supabase.instance.client
          .from('storage_locations')
          .select('location_type')
          .eq('location_id', payload.id)
          .single();
      final isRoom =
          row['location_type'] == null || row['location_type'] == 'room';
      return ResolvedModulePermission(
        moduleId: 'locations',
        child: isRoom
            ? RoomDetailPage(locationId: payload.id)
            : LocationDetailPage(locationId: payload.id),
      );

    case 'strains':
      return ResolvedModulePermission(
        moduleId: 'strains',
        child: StrainDetailPage(strainId: payload.id),
      );

    case 'samples':
      return ResolvedModulePermission(
        moduleId: 'samples',
        child: SampleDetailPage(sampleId: payload.id),
      );

    case 'fish_lines':
      final row = await Supabase.instance.client
          .from(FishSch.linesTable)
          .select()
          .eq(FishSch.lineId, payload.id)
          .single();
      return ResolvedModulePermission(
        moduleId: 'fish_lines',
        child: FishLineDetailPage(
          fishLine: FishLine.fromMap(Map<String, dynamic>.from(row)),
        ),
      );

    case 'fish_stocks':
      final row = await Supabase.instance.client
          .from(FishSch.stocksTable)
          .select()
          .eq(FishSch.stockId, payload.id)
          .single();
      return ResolvedModulePermission(
        moduleId: 'fish_stock',
        child: TankDetailPage(
          tank: ZebrafishTank.fromMap(Map<String, dynamic>.from(row)),
        ),
      );

    case 'users':
      final viewerEmail =
          Supabase.instance.client.auth.currentSession?.user.email ??
          Supabase.instance.client.auth.currentUser?.email ??
          '';
      if (viewerEmail.isEmpty) {
        throw Exception('Access denied.');
      }
      final viewer = await Supabase.instance.client
          .from('users')
          .select('user_id, user_role')
          .eq('user_email', viewerEmail)
          .maybeSingle();
      final viewerRole = viewer?['user_role'] as String? ?? '';
      final viewerId = viewer?['user_id'] as int?;
      final canOpenUser =
          viewerId == payload.id ||
          viewerRole == 'admin' ||
          viewerRole == 'superadmin';
      if (!canOpenUser) {
        throw Exception('Access denied.');
      }
      final row = await Supabase.instance.client
          .from('users')
          .select()
          .eq('user_id', payload.id)
          .single();
      return UserDetailPage(userMap: Map<String, dynamic>.from(row));

    case 'sops':
      final row = await Supabase.instance.client
          .from(SopSch.table)
          .select()
          .eq(SopSch.id, payload.id)
          .single();
      final sop = FacilitySop.fromMap(Map<String, dynamic>.from(row));
      final String filePath;
      final String fileName;
      final DocViewMode mode;
      if (sop.hasPdfFile) {
        filePath = sop.filePath!;
        fileName = sop.fileName!;
        mode = DocViewMode.pdf;
      } else if (sop.hasTxtFile) {
        filePath = sop.txtFilePath!;
        fileName = sop.txtFileName!;
        mode = DocViewMode.txt;
      } else if (sop.hasDocFile) {
        filePath = sop.docFilePath!;
        fileName = sop.docFileName!;
        mode = DocViewMode.doc;
      } else {
        throw Exception('"${sop.name}" has no attached file.');
      }
      final bytes = await Supabase.instance.client.storage
          .from(SopSch.bucket)
          .download(filePath);
      return DocViewerPage(
        bytes: bytes,
        title: sop.name,
        fileName: fileName,
        viewMode: mode,
      );

    default:
      throw StateError('unhandled type: ${payload.type}');
  }
}
