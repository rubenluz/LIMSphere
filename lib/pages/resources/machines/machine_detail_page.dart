import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide LocalStorage;
import '/core/supabase_manager.dart';
import '/theme/theme.dart';
import 'machine_model.dart';
import '../reservations/reservation_model.dart';

class MachineDetailPage extends StatefulWidget {
  final int machineId;
  const MachineDetailPage({super.key, required this.machineId});

  @override
  State<MachineDetailPage> createState() => _MachineDetailPageState();
}

class _MachineDetailPageState extends State<MachineDetailPage> {
  MachineModel? _machine;
  List<ReservationModel> _reservations = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final rows = await Supabase.instance.client
          .from('equipment')
          .select('*, location:equipment_location_id(location_name)')
          .eq('equipment_id', widget.machineId)
          .limit(1);

      if (rows.isEmpty) {
        if (mounted) setState(() => _loading = false);
        return;
      }

      final r = rows[0];
      final locData = r['location'];
      final locName =
          locData is Map ? locData['location_name'] as String? : null;
      final machine = MachineModel.fromMap({...r, 'location_name': locName});

      final resRows = await Supabase.instance.client
          .from('reservations')
          .select()
          .eq('reservation_resource_type', 'equipment')
          .eq('reservation_resource_id', widget.machineId)
          .order('reservation_start', ascending: false)
          .limit(20);

      if (mounted) {
        setState(() {
          _machine = machine;
          _reservations = resRows
              .map<ReservationModel>(
                  (r) => ReservationModel.fromMap(r))
              .toList();
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Failed to load: $e')));
      }
    }
  }

  void _showQr(MachineModel m) {
    final ref = SupabaseManager.projectRef ?? 'local';
    final data = 'bluelims://$ref/machine/${m.id}';
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppDS.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Text('QR — ${m.name}',
            style: GoogleFonts.spaceGrotesk(color: AppDS.textPrimary)),
        content: SizedBox(
          width: 260,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(
                color: Colors.white,
                padding: const EdgeInsets.all(12),
                child: QrImageView(data: data, size: 200)),
            const SizedBox(height: 10),
            Text(data,
                style: GoogleFonts.spaceGrotesk(
                    color: AppDS.textMuted, fontSize: 11)),
          ]),
        ),
        actions: [
          TextButton(
              onPressed: () async {
                await Clipboard.setData(ClipboardData(text: data));
                if (context.mounted) Navigator.pop(ctx);
                if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Link copied to clipboard')));
              },
              child: Text('Copy Link',
                  style: GoogleFonts.spaceGrotesk(color: AppDS.accent))),
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('Close',
                  style:
                      GoogleFonts.spaceGrotesk(color: AppDS.textSecondary))),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final m = _machine;
    return Scaffold(
      backgroundColor: AppDS.bg,
      appBar: AppBar(
        backgroundColor: AppDS.surface2,
        foregroundColor: AppDS.textPrimary,
        title: Text(m?.name ?? 'Machine',
            style: GoogleFonts.spaceGrotesk(
                color: AppDS.textPrimary, fontWeight: FontWeight.w600)),
        actions: [
          if (m != null)
            IconButton(
                icon: const Icon(Icons.qr_code),
                tooltip: 'QR Code',
                onPressed: () => _showQr(m)),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : m == null
              ? Center(
                  child: Text('Machine not found',
                      style:
                          GoogleFonts.spaceGrotesk(color: AppDS.textMuted)))
              : _buildBody(m),
    );
  }

  Widget _buildBody(MachineModel m) {
    final sc = m.statusColor;
    final qrData = 'bluelims://${SupabaseManager.projectRef ?? 'local'}/machine/${m.id}';
    final upcoming = _reservations
        .where((r) => r.start.isAfter(DateTime.now()) || r.isOngoing)
        .toList()
      ..sort((a, b) => a.start.compareTo(b.start));
    final past = _reservations
        .where((r) => r.end.isBefore(DateTime.now()))
        .toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // ── Header ─────────────────────────────────────────────────────────────
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
              color: Colors.white,
              padding: const EdgeInsets.all(12),
              child: QrImageView(data: qrData, size: 130)),
          const SizedBox(width: 24),
          Expanded(
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(m.name,
                      style: GoogleFonts.spaceGrotesk(
                          color: AppDS.textPrimary,
                          fontSize: 22,
                          fontWeight: FontWeight.w700)),
                  if (m.brand != null || m.model != null) ...[
                    const SizedBox(height: 4),
                    Text(
                        [if (m.brand != null) m.brand!, if (m.model != null) m.model!].join(' · '),
                        style: GoogleFonts.spaceGrotesk(
                            color: AppDS.textSecondary, fontSize: 14)),
                  ],
                  const SizedBox(height: 10),
                  Row(children: [
                    _StatusBadge(status: m.status, color: sc),
                    if (m.maintenanceOverdue) ...[
                      const SizedBox(width: 8),
                      _SmallBadge(label: 'Maintenance overdue', color: AppDS.red),
                    ] else if (m.maintenanceDueSoon) ...[
                      const SizedBox(width: 8),
                      _SmallBadge(label: 'Maintenance due soon', color: AppDS.yellow),
                    ],
                  ]),
                ]),
          ),
        ]),

        const SizedBox(height: 24),

        // ── Identification ──────────────────────────────────────────────────────
        _Section('Identification'),
        const SizedBox(height: 8),
        Wrap(spacing: 12, runSpacing: 12, children: [
          if (m.type != null) _InfoCard(label: 'Type', value: m.type!),
          if (m.serialNumber != null)
            _InfoCard(label: 'Serial Number', value: m.serialNumber!),
          if (m.patrimonyNumber != null)
            _InfoCard(label: 'Patrimony Number', value: m.patrimonyNumber!),
          if (m.locationName != null)
            _InfoCard(label: 'Location', value: m.locationName!),
          if (m.room != null) _InfoCard(label: 'Room', value: m.room!),
        ]),

        const SizedBox(height: 20),

        // ── Maintenance ─────────────────────────────────────────────────────────
        _Section('Maintenance & Calibration'),
        const SizedBox(height: 8),
        Wrap(spacing: 12, runSpacing: 12, children: [
          if (m.lastMaintenance != null)
            _InfoCard(label: 'Last Maintenance', value: _fmt(m.lastMaintenance!)),
          if (m.nextMaintenance != null)
            _InfoCard(
                label: 'Next Maintenance',
                value: _fmt(m.nextMaintenance!),
                highlight: m.maintenanceOverdue
                    ? AppDS.red
                    : m.maintenanceDueSoon
                        ? AppDS.yellow
                        : null),
          if (m.maintenanceIntervalDays != null)
            _InfoCard(
                label: 'Maint. Interval',
                value: '${m.maintenanceIntervalDays} days'),
          if (m.lastCalibration != null)
            _InfoCard(label: 'Last Calibration', value: _fmt(m.lastCalibration!)),
          if (m.nextCalibration != null)
            _InfoCard(label: 'Next Calibration', value: _fmt(m.nextCalibration!)),
          if (m.calibrationIntervalDays != null)
            _InfoCard(
                label: 'Cal. Interval',
                value: '${m.calibrationIntervalDays} days'),
        ]),

        const SizedBox(height: 20),

        // ── Purchase ────────────────────────────────────────────────────────────
        _Section('Purchase & Warranty'),
        const SizedBox(height: 8),
        Wrap(spacing: 12, runSpacing: 12, children: [
          if (m.purchaseDate != null)
            _InfoCard(label: 'Purchase Date', value: _fmt(m.purchaseDate!)),
          if (m.warrantyUntil != null)
            _InfoCard(label: 'Warranty Until', value: _fmt(m.warrantyUntil!)),
          if (m.supplier != null)
            _InfoCard(label: 'Supplier', value: m.supplier!),
          if (m.responsible != null)
            _InfoCard(label: 'Responsible', value: m.responsible!),
          if (m.manualLink != null)
            _InfoCard(label: 'Manual', value: m.manualLink!),
        ]),

        if (m.notes != null && m.notes!.isNotEmpty) ...[
          const SizedBox(height: 20),
          _Section('Notes'),
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppDS.surface,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppDS.border),
            ),
            child: Text(m.notes!,
                style: GoogleFonts.spaceGrotesk(
                    color: AppDS.textSecondary, fontSize: 13)),
          ),
        ],

        // ── Reservations ────────────────────────────────────────────────────────
        const SizedBox(height: 24),
        _Section('Upcoming / Ongoing Reservations (${upcoming.length})'),
        const SizedBox(height: 8),
        if (upcoming.isEmpty)
          Text('No upcoming reservations.',
              style:
                  GoogleFonts.spaceGrotesk(color: AppDS.textMuted, fontSize: 13))
        else
          ...upcoming.map((r) => _ReservationTile(reservation: r)),

        if (past.isNotEmpty) ...[
          const SizedBox(height: 16),
          _Section('Past Reservations (${past.length})'),
          const SizedBox(height: 8),
          ...past.take(5).map((r) => _ReservationTile(reservation: r, past: true)),
        ],
      ]),
    );
  }

  String _fmt(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}

class _ReservationTile extends StatelessWidget {
  final ReservationModel reservation;
  final bool past;
  const _ReservationTile({required this.reservation, this.past = false});

  @override
  Widget build(BuildContext context) {
    final r = reservation;
    final sc = r.statusColor;
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppDS.surface,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: past ? AppDS.border : sc.withValues(alpha: 0.4)),
      ),
      child: Row(children: [
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(
              '${_fmtDt(r.start)} → ${_fmtDt(r.end)}',
              style: GoogleFonts.spaceGrotesk(
                  color: past ? AppDS.textSecondary : AppDS.textPrimary,
                  fontSize: 13,
                  fontWeight: FontWeight.w500),
            ),
            if (r.purpose != null || r.project != null)
              Text(
                [if (r.purpose != null) r.purpose!, if (r.project != null) r.project!].join(' · '),
                style: GoogleFonts.spaceGrotesk(
                    color: AppDS.textMuted, fontSize: 11),
              ),
          ]),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
          decoration: BoxDecoration(
            color: sc.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(r.status,
              style: GoogleFonts.spaceGrotesk(color: sc, fontSize: 11)),
        ),
      ]),
    );
  }

  String _fmtDt(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')} ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
}

class _Section extends StatelessWidget {
  final String title;
  const _Section(this.title);

  @override
  Widget build(BuildContext context) => Text(title,
      style: GoogleFonts.spaceGrotesk(
          color: AppDS.textSecondary,
          fontSize: 12,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.8));
}

class _InfoCard extends StatelessWidget {
  final String label;
  final String value;
  final Color? highlight;
  const _InfoCard({required this.label, required this.value, this.highlight});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: AppDS.surface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
              color: highlight != null
                  ? highlight!.withValues(alpha: 0.5)
                  : AppDS.border),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label,
              style: GoogleFonts.spaceGrotesk(
                  color: AppDS.textMuted, fontSize: 10)),
          const SizedBox(height: 2),
          Text(value,
              style: GoogleFonts.spaceGrotesk(
                  color: highlight ?? AppDS.textPrimary,
                  fontSize: 13,
                  fontWeight: FontWeight.w500)),
        ]),
      );
}

class _StatusBadge extends StatelessWidget {
  final String status;
  final Color color;
  const _StatusBadge({required this.status, required this.color});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(MachineModel.statusLabel(status),
            style: GoogleFonts.spaceGrotesk(
                color: color, fontSize: 13, fontWeight: FontWeight.w600)),
      );
}

class _SmallBadge extends StatelessWidget {
  final String label;
  final Color color;
  const _SmallBadge({required this.label, required this.color});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(label,
            style: GoogleFonts.spaceGrotesk(color: color, fontSize: 11)),
      );
}
