import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide LocalStorage;
import '/core/supabase_manager.dart';
import '/theme/theme.dart';
import 'reagent_model.dart';

class ReagentDetailPage extends StatefulWidget {
  final int reagentId;
  const ReagentDetailPage({super.key, required this.reagentId});

  @override
  State<ReagentDetailPage> createState() => _ReagentDetailPageState();
}

class _ReagentDetailPageState extends State<ReagentDetailPage> {
  ReagentModel? _reagent;
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
          .from('reagents')
          .select('*, location:reagent_location_id(location_name)')
          .eq('reagent_id', widget.reagentId)
          .limit(1);

      if (rows.isEmpty) {
        if (mounted) setState(() => _loading = false);
        return;
      }
      final r = rows[0];
      final locData = r['location'];
      final locName = locData is Map ? locData['location_name'] as String? : null;
      if (mounted) {
        setState(() {
          _reagent = ReagentModel.fromMap({...r, 'location_name': locName});
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

  @override
  Widget build(BuildContext context) {
    final r = _reagent;
    return Scaffold(
      backgroundColor: AppDS.bg,
      appBar: AppBar(
        backgroundColor: AppDS.surface2,
        foregroundColor: AppDS.textPrimary,
        title: Text(r?.name ?? 'Reagent',
            style: GoogleFonts.spaceGrotesk(
                color: AppDS.textPrimary, fontWeight: FontWeight.w600)),
        actions: [
          if (r != null)
            IconButton(
              icon: const Icon(Icons.qr_code),
              tooltip: 'QR Code',
              onPressed: () => _showQr(r),
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : r == null
              ? Center(
                  child: Text('Reagent not found',
                      style: GoogleFonts.spaceGrotesk(color: AppDS.textMuted)))
              : _buildBody(r),
    );
  }

  void _showQr(ReagentModel r) {
    final ref = SupabaseManager.projectRef ?? 'local';
    final data = 'bluelims://$ref/reagent/${r.id}';
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppDS.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Text('QR — ${r.name}',
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
                  style: GoogleFonts.spaceGrotesk(color: AppDS.textSecondary))),
        ],
      ),
    );
  }

  Widget _buildBody(ReagentModel r) {
    const typeAccentMap = <String, Color>{
      'chemical': Color(0xFF38BDF8),
      'biological': Color(0xFF22C55E),
      'kit': Color(0xFF8B5CF6),
      'media': Color(0xFF10B981),
      'gas': Color(0xFF64748B),
      'consumable': Color(0xFFF59E0B),
    };
    final accent = typeAccentMap[r.type] ?? AppDS.accent;
    final qrData = 'bluelims://${SupabaseManager.projectRef ?? 'local'}/reagent/${r.id}';

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
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(r.name,
                  style: GoogleFonts.spaceGrotesk(
                      color: AppDS.textPrimary,
                      fontSize: 22,
                      fontWeight: FontWeight.w700)),
              if (r.brand != null) ...[
                const SizedBox(height: 4),
                Text(r.brand!,
                    style: GoogleFonts.spaceGrotesk(
                        color: AppDS.textSecondary, fontSize: 14)),
              ],
              const SizedBox(height: 8),
              Wrap(spacing: 8, runSpacing: 6, children: [
                _Badge(label: ReagentModel.typeLabel(r.type), color: accent),
                if (r.isExpired) _Badge(label: 'Expired', color: AppDS.red),
                if (r.isExpiringSoon && !r.isExpired)
                  _Badge(label: 'Expiring soon', color: AppDS.yellow),
                if (r.isLowStock) _Badge(label: 'Low stock', color: AppDS.orange),
                if (r.hazard != null && r.hazard!.isNotEmpty)
                  _Badge(label: r.hazard!, color: AppDS.yellow),
              ]),
            ]),
          ),
        ]),

        const SizedBox(height: 24),

        // ── Identification ──────────────────────────────────────────────────────
        _Section('Identification'),
        const SizedBox(height: 8),
        Wrap(spacing: 12, runSpacing: 12, children: [
          if (r.reference != null)
            _InfoCard(label: 'Reference', value: r.reference!),
          if (r.casNumber != null)
            _InfoCard(label: 'CAS Number', value: r.casNumber!),
          if (r.lotNumber != null)
            _InfoCard(label: 'Lot Number', value: r.lotNumber!),
          if (r.concentration != null)
            _InfoCard(label: 'Concentration', value: r.concentration!),
        ]),

        const SizedBox(height: 20),

        // ── Stock ───────────────────────────────────────────────────────────────
        _Section('Stock & Storage'),
        const SizedBox(height: 8),
        Wrap(spacing: 12, runSpacing: 12, children: [
          if (r.quantity != null)
            _InfoCard(label: 'Quantity', value: r.displayQuantity,
                highlight: r.isLowStock ? AppDS.orange : null),
          if (r.quantityMin != null)
            _InfoCard(label: 'Reorder threshold',
                value: '${r.quantityMin} ${r.unit ?? ''}'),
          if (r.storageTemp != null)
            _InfoCard(label: 'Storage Temp', value: r.storageTemp!),
          if (r.locationName != null)
            _InfoCard(label: 'Location', value: r.locationName!),
          if (r.position != null)
            _InfoCard(label: 'Position', value: r.position!),
        ]),

        const SizedBox(height: 20),

        // ── Dates ───────────────────────────────────────────────────────────────
        _Section('Dates'),
        const SizedBox(height: 8),
        Wrap(spacing: 12, runSpacing: 12, children: [
          if (r.expiryDate != null)
            _InfoCard(label: 'Expiry Date',
                value: _fmt(r.expiryDate!),
                highlight: r.isExpired
                    ? AppDS.red
                    : r.isExpiringSoon
                        ? AppDS.yellow
                        : null),
          if (r.receivedDate != null)
            _InfoCard(label: 'Received', value: _fmt(r.receivedDate!)),
          if (r.openedDate != null)
            _InfoCard(label: 'Opened', value: _fmt(r.openedDate!)),
          if (r.createdAt != null)
            _InfoCard(label: 'Added to system', value: _fmt(r.createdAt!)),
        ]),

        const SizedBox(height: 20),

        // ── Supplier ────────────────────────────────────────────────────────────
        if (r.supplier != null || r.responsible != null) ...[
          _Section('Supplier & Responsible'),
          const SizedBox(height: 8),
          Wrap(spacing: 12, runSpacing: 12, children: [
            if (r.supplier != null)
              _InfoCard(label: 'Supplier', value: r.supplier!),
            if (r.responsible != null)
              _InfoCard(label: 'Responsible', value: r.responsible!),
          ]),
          const SizedBox(height: 20),
        ],

        // ── Notes ───────────────────────────────────────────────────────────────
        if (r.notes != null && r.notes!.isNotEmpty) ...[
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
            child: Text(r.notes!,
                style: GoogleFonts.spaceGrotesk(
                    color: AppDS.textSecondary, fontSize: 13)),
          ),
        ],
      ]),
    );
  }

  String _fmt(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
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
  Widget build(BuildContext context) {
    return Container(
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
}

class _Badge extends StatelessWidget {
  final String label;
  final Color color;
  const _Badge({required this.label, required this.color});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(label,
            style: GoogleFonts.spaceGrotesk(color: color, fontSize: 11)),
      );
}
