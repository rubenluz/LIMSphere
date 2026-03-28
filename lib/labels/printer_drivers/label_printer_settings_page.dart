// label_printer_settings_page.dart - Part of label_page.dart.
// Printer profiles UI: list of named profiles, edit/delete/set-active.

part of '../label_page.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Profile list tab
// ─────────────────────────────────────────────────────────────────────────────
class _ProfileListTab extends StatelessWidget {
  final List<PrinterProfile> profiles;
  final String? activeId;
  final void Function(String id) onSetActive;
  final void Function(PrinterProfile) onEdit;
  final void Function(PrinterProfile) onDelete;

  const _ProfileListTab({
    required this.profiles,
    required this.activeId,
    required this.onSetActive,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    if (profiles.isEmpty) {
      return Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.print_disabled_rounded, size: 48, color: AppDS.textMuted),
          const SizedBox(height: 16),
          Text('No printer profiles yet',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: context.appTextPrimary)),
          const SizedBox(height: 6),
          Text('Tap "Add Profile" or "Detect" to get started.',
              style: TextStyle(fontSize: 12, color: context.appTextSecondary)),
        ]),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.all(20),
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemCount: profiles.length,
      itemBuilder: (_, i) {
        final p = profiles[i];
        final isActive = p.id == activeId;
        return _ProfileCard(
          profile: p,
          isActive: isActive,
          onSetActive: () => onSetActive(p.id),
          onEdit: () => onEdit(p),
          onDelete: () => onDelete(p),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Profile card
// ─────────────────────────────────────────────────────────────────────────────
class _ProfileCard extends StatelessWidget {
  final PrinterProfile profile;
  final bool isActive;
  final VoidCallback onSetActive;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _ProfileCard({
    required this.profile,
    required this.isActive,
    required this.onSetActive,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final p = profile;
    final connLabel = p.connectionType == 'wifi' ? 'Wi-Fi ${p.ipAddress}' : 'USB ${p.usbPath}';
    final mediaLabel = p.continuousRoll ? 'Continuous roll' : 'Pre-cut';
    final protoLabel = switch (p.protocol) {
      'brother_ql'        => 'Brother QL',
      'brother_ql_legacy' => 'QL Legacy',
      _                   => 'ZPL',
    };

    return Container(
      decoration: BoxDecoration(
        color: context.appSurface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isActive ? AppDS.accent : context.appBorder,
          width: isActive ? 1.5 : 1,
        ),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            width: 36, height: 36,
            decoration: BoxDecoration(
              color: isActive ? AppDS.accent.withValues(alpha: 0.15) : context.appSurface2,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(Icons.print_rounded,
                size: 18, color: isActive ? AppDS.accent : context.appTextSecondary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Expanded(
                  child: Text(p.name,
                      style: TextStyle(
                          fontSize: 14, fontWeight: FontWeight.w700,
                          color: context.appTextPrimary),
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                ),
                if (isActive) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppDS.accent.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text('ACTIVE',
                        style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: AppDS.accent)),
                  ),
                ],
              ]),
              const SizedBox(height: 2),
              Text(p.deviceName,
                  style: TextStyle(fontSize: 11, color: context.appTextSecondary),
                  maxLines: 1, overflow: TextOverflow.ellipsis),
            ]),
          ),
        ]),
        const SizedBox(height: 12),
        Wrap(spacing: 6, runSpacing: 6, children: [
          _SmallBadge(protoLabel, AppDS.accent),
          _SmallBadge('${p.dpi} DPI', AppDS.purple),
          _SmallBadge(mediaLabel, AppDS.green),
          if (p.cutMode != 'none')
            _SmallBadge(p.cutMode == 'end' ? 'Cut at end' : 'Cut between', AppDS.yellow),
          if (p.halfCut) _SmallBadge('Half-cut', AppDS.orange),
          _SmallBadge(connLabel, context.appTextMuted),
        ]),
        const SizedBox(height: 12),
        Row(children: [
          if (!isActive)
            OutlinedButton(
              style: OutlinedButton.styleFrom(
                foregroundColor: AppDS.accent,
                side: const BorderSide(color: AppDS.accent),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                minimumSize: const Size(0, 32),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: onSetActive,
              child: const Text('Set Active', style: TextStyle(fontSize: 12)),
            ),
          if (!isActive) const SizedBox(width: 8),
          OutlinedButton(
            style: OutlinedButton.styleFrom(
              foregroundColor: context.appTextSecondary,
              side: BorderSide(color: context.appBorder),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              minimumSize: const Size(0, 32),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: onEdit,
            child: const Text('Edit', style: TextStyle(fontSize: 12)),
          ),
          const Spacer(),
          _TestPrintButton(profile: p),
          const SizedBox(width: 8),
          IconButton(
            icon: const Icon(Icons.delete_outline_rounded, size: 18),
            color: AppDS.red,
            tooltip: 'Delete profile',
            onPressed: onDelete,
          ),
        ]),
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Inline test-print button on a card
// ─────────────────────────────────────────────────────────────────────────────
class _TestPrintButton extends StatefulWidget {
  final PrinterProfile profile;
  const _TestPrintButton({required this.profile});
  @override State<_TestPrintButton> createState() => _TestPrintButtonState();
}

class _TestPrintButtonState extends State<_TestPrintButton> {
  bool _busy = false;

  Future<void> _send() async {
    setState(() => _busy = true);
    try {
      final testTpl = LabelTemplate(
        id: '_test', name: 'Test', category: 'General', labelW: 62, labelH: 30,
        fields: [
          LabelField(id: 'f1', type: LabelFieldType.text,
              content: 'Test Print', x: 4, y: 4, w: 120, h: 14,
              fontSize: 12, fontWeight: FontWeight.bold),
          LabelField(id: 'f2', type: LabelFieldType.text,
              content: 'BlueOpenLIMS', x: 4, y: 18, w: 120, h: 10, fontSize: 9),
        ],
      );
      await _sendToPrinter(
          widget.profile.applyTo(testTpl), const [], widget.profile.toPrinterConfig());
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: const Text('Test label sent'),
          backgroundColor: AppDS.green,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Error: $e'),
          backgroundColor: AppDS.red,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ));
      }
    }
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) => OutlinedButton.icon(
    style: OutlinedButton.styleFrom(
      foregroundColor: context.appTextSecondary,
      side: BorderSide(color: context.appBorder),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      minimumSize: const Size(0, 32),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    ),
    onPressed: _busy ? null : _send,
    icon: _busy
        ? const SizedBox(width: 12, height: 12,
            child: CircularProgressIndicator(color: AppDS.accent, strokeWidth: 2))
        : const Icon(Icons.print_outlined, size: 14),
    label: const Text('Test Print', style: TextStyle(fontSize: 12)),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// Edit dialog
// ─────────────────────────────────────────────────────────────────────────────
class _ProfileEditDialog extends StatefulWidget {
  final PrinterProfile profile;
  final void Function(PrinterProfile) onSave;
  const _ProfileEditDialog({required this.profile, required this.onSave});
  @override State<_ProfileEditDialog> createState() => _ProfileEditDialogState();
}

class _ProfileEditDialogState extends State<_ProfileEditDialog> {
  late PrinterProfile _p;
  late final _nameCtrl = TextEditingController(text: widget.profile.name);
  late final _ipCtrl   = TextEditingController(text: widget.profile.ipAddress);
  late final _usbCtrl  = TextEditingController(text: widget.profile.usbPath);

  static const _modelsByProtocol = {
    'zpl':               ['Zebra ZD421', 'Zebra ZD421t', 'Zebra ZD620', 'Zebra ZT410', 'Zebra GK420d'],
    'brother_ql':        ['Brother QL-820NWB', 'Brother QL-810W', 'Brother QL-800', 'Brother QL-700', 'Brother QL-570'],
    'brother_ql_legacy': ['Brother QL-500', 'Brother QL-550', 'Brother QL-650TD'],
  };

  @override
  void initState() {
    super.initState();
    _p = PrinterProfile(
      id:             widget.profile.id,
      name:           widget.profile.name,
      protocol:       widget.profile.protocol,
      connectionType: widget.profile.connectionType,
      deviceName:     widget.profile.deviceName,
      ipAddress:      widget.profile.ipAddress,
      usbPath:        widget.profile.usbPath,
      dpi:            widget.profile.dpi,
      cutMode:        widget.profile.cutMode,
      halfCut:        widget.profile.halfCut,
      continuousRoll: widget.profile.continuousRoll,
      topOffsetMm:    widget.profile.topOffsetMm,
    );
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _ipCtrl.dispose();
    _usbCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final models = _modelsByProtocol[_p.protocol] ?? _modelsByProtocol['zpl']!;
    final modelValue = models.contains(_p.deviceName) ? _p.deviceName : models.first;

    return AlertDialog(
      backgroundColor: context.appSurface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      title: Row(children: [
        const Icon(Icons.print_outlined, size: 16, color: AppDS.accent),
        const SizedBox(width: 8),
        Expanded(
          child: Text('Edit Printer Profile',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: context.appTextPrimary)),
        ),
      ]),
      content: SizedBox(
        width: 440,
        child: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [

            // Name
            _PropLabel('Profile Name'),
            const SizedBox(height: 4),
            TextField(
              controller: _nameCtrl,
              autofocus: true,
              style: TextStyle(fontSize: 13, color: context.appTextPrimary),
              decoration: _inputDeco(context, hint: 'e.g. Brother QL-570 (lab)'),
              onChanged: (v) => _p.name = v,
            ),
            const SizedBox(height: 16),

            // Protocol
            _SectionHeader('Connection', Icons.wifi_rounded),
            const SizedBox(height: 10),
            _SegmentRow(
              label: 'Protocol',
              options: const {'zpl': 'ZPL (Zebra)', 'brother_ql': 'Brother QL', 'brother_ql_legacy': 'QL Legacy'},
              value: _p.protocol,
              onChanged: (v) => setState(() {
                _p.protocol = v;
                _p.deviceName = _modelsByProtocol[v]!.first;
                if (v == 'brother_ql_legacy') _p.connectionType = 'usb';
              }),
            ),
            const SizedBox(height: 10),
            if (_p.protocol == 'brother_ql_legacy') ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: AppDS.accent.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppDS.accent.withValues(alpha: 0.3)),
                ),
                child: const Row(children: [
                  Icon(Icons.info_outline_rounded, size: 14, color: AppDS.accent),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'QL-500/550/650TD — USB only, fixed 300 DPI, no half-cut.',
                      style: TextStyle(fontSize: 11, color: AppDS.accent),
                    ),
                  ),
                ]),
              ),
              const SizedBox(height: 10),
            ],
            _SegmentRow(
              label: 'Type',
              options: _p.protocol == 'brother_ql_legacy'
                  ? const {'usb': 'USB'}
                  : const {'usb': 'USB', 'wifi': 'Wi-Fi', 'bluetooth': 'Bluetooth'},
              value: _p.connectionType,
              onChanged: (v) => setState(() => _p.connectionType = v),
            ),
            const SizedBox(height: 10),
            _DropdownRow(
              label: 'Model',
              options: models,
              value: modelValue,
              onChanged: (v) => setState(() {
                _p.deviceName = v ?? models.first;
                if (_p.deviceName.contains('QL-570')) {
                  _p.dpi = 300;
                  _p.halfCut = false;
                }
              }),
            ),
            const SizedBox(height: 10),
            if (_p.connectionType == 'usb') ...[
              _PropLabel(Platform.isWindows ? 'Printer Name (Windows queue)' : 'USB Device Path'),
              const SizedBox(height: 4),
              TextField(
                controller: _usbCtrl,
                style: TextStyle(fontSize: 13, color: context.appTextPrimary),
                decoration: _inputDeco(context,
                    hint: Platform.isWindows ? 'Brother QL-570' : '/dev/usb/lp0',
                    prefix: Icon(Icons.usb_rounded, size: 16, color: context.appTextMuted)),
                onChanged: (v) => _p.usbPath = v,
              ),
            ],
            if (_p.connectionType == 'wifi') ...[
              _PropLabel('IP Address'),
              const SizedBox(height: 4),
              TextField(
                controller: _ipCtrl,
                style: TextStyle(fontSize: 13, color: context.appTextPrimary),
                keyboardType: TextInputType.number,
                decoration: _inputDeco(context, hint: '192.168.1.100'),
                onChanged: (v) => _p.ipAddress = v,
              ),
            ],

            const SizedBox(height: 16),

            // Print quality
            _SectionHeader('Print Quality', Icons.tune_rounded),
            const SizedBox(height: 10),
            if (_p.protocol != 'brother_ql_legacy' && !_p.deviceName.contains('QL-570'))
              _SegmentRow(
                label: 'DPI',
                options: const {'300': '300', '600': '600'},
                value: _p.dpi.toString(),
                onChanged: (v) => setState(() => _p.dpi = int.parse(v)),
              ),
            const SizedBox(height: 10),
            _SegmentRow(
              label: 'Media',
              options: const {'true': 'Continuous', 'false': 'Pre-cut'},
              value: _p.continuousRoll.toString(),
              onChanged: (v) => setState(() => _p.continuousRoll = v == 'true'),
            ),
            const SizedBox(height: 10),
            _SegmentRow(
              label: 'Cut',
              options: const {'none': 'None', 'between': 'Between', 'end': 'End only'},
              value: _p.cutMode,
              onChanged: (v) => setState(() => _p.cutMode = v),
            ),
            const SizedBox(height: 10),
            Row(children: [
              const SizedBox(width: 80),
              if (_p.protocol != 'brother_ql_legacy' && !_p.deviceName.contains('QL-570')) ...[
                Switch(
                  value: _p.halfCut,
                  activeThumbColor: AppDS.accent,
                  onChanged: (v) => setState(() => _p.halfCut = v),
                ),
                const SizedBox(width: 8),
                Text('Half-cut', style: TextStyle(fontSize: 12, color: context.appTextPrimary)),
              ],
            ]),
          ]),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text('Cancel', style: TextStyle(fontSize: 13, color: context.appTextSecondary)),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
              backgroundColor: AppDS.accent,
              foregroundColor: AppDS.bg,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
          onPressed: () {
            _p.name = _nameCtrl.text.trim().isEmpty ? _p.deviceName : _nameCtrl.text.trim();
            widget.onSave(_p);
            Navigator.pop(context);
          },
          child: const Text('Save', style: TextStyle(fontSize: 13)),
        ),
      ],
    );
  }

  InputDecoration _inputDeco(BuildContext context, {String? hint, Widget? prefix}) => InputDecoration(
    isDense: true,
    filled: true,
    fillColor: context.appBg,
    hintText: hint,
    hintStyle: TextStyle(color: context.appTextMuted, fontSize: 12),
    prefixIcon: prefix,
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: context.appBorder)),
    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: context.appBorder)),
    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: AppDS.accent)),
    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
  );
}


class _SectionHeader extends StatelessWidget {
  final String label;
  final IconData icon;
  const _SectionHeader(this.label, this.icon);
  @override
  Widget build(BuildContext context) => Row(children: [
    Icon(icon, size: 14, color: AppDS.accent),
    const SizedBox(width: 8),
    Text(label, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: context.appTextPrimary)),
    const SizedBox(width: 12),
    Expanded(child: Divider(color: context.appBorder)),
  ]);
}

class _SegmentRow extends StatelessWidget {
  final String label;
  final Map<String, String> options;
  final String value;
  final void Function(String) onChanged;
  const _SegmentRow({required this.label, required this.options, required this.value, required this.onChanged});
  @override
  Widget build(BuildContext context) => Row(children: [
    SizedBox(width: 80, child: Text(label, style: TextStyle(fontSize: 12, color: context.appTextSecondary))),
    SegmentedButton<String>(
      style: ButtonStyle(
        visualDensity: VisualDensity.compact,
        backgroundColor: WidgetStateProperty.resolveWith((s) =>
            s.contains(WidgetState.selected) ? AppDS.accent.withValues(alpha: 0.2) : context.appSurface),
        foregroundColor: WidgetStateProperty.resolveWith((s) =>
            s.contains(WidgetState.selected) ? AppDS.accent : context.appTextSecondary),
        side: WidgetStateProperty.all(BorderSide(color: context.appBorder)),
      ),
      segments: options.entries.map((e) => ButtonSegment(value: e.key, label: Text(e.value, style: const TextStyle(fontSize: 12)))).toList(),
      selected: {value},
      onSelectionChanged: (s) => onChanged(s.first),
    ),
  ]);
}

class _DropdownRow extends StatelessWidget {
  final String label;
  final List<String> options;
  final String value;
  final void Function(String?) onChanged;
  const _DropdownRow({required this.label, required this.options, required this.value, required this.onChanged});
  @override
  Widget build(BuildContext context) => Row(children: [
    SizedBox(width: 80, child: Text('Model', style: TextStyle(fontSize: 12, color: context.appTextSecondary))),
    Expanded(
      child: DropdownButtonFormField<String>(
        initialValue: options.contains(value) ? value : options.first,
        dropdownColor: context.appSurface,
        style: TextStyle(fontSize: 12, color: context.appTextPrimary),
        decoration: InputDecoration(
          isDense: true, filled: true, fillColor: context.appSurface,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: context.appBorder)),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: context.appBorder)),
          contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        ),
        items: options.map((o) => DropdownMenuItem(value: o, child: Text(o))).toList(),
        onChanged: onChanged,
      ),
    ),
  ]);
}

// ─────────────────────────────────────────────────────────────────────────────
// System-installed printer detection
// ─────────────────────────────────────────────────────────────────────────────

class _InstalledPrinterInfo {
  final String name;
  final String driverName;
  final String portName;
  final String protocol;       // 'zpl' | 'brother_ql'
  final String connectionType; // 'usb' | 'wifi'
  final String? ipAddress;
  final String? matchedModel;
  const _InstalledPrinterInfo({
    required this.name, required this.driverName, required this.portName,
    required this.protocol, required this.connectionType,
    this.ipAddress, this.matchedModel,
  });
}

const _kModelKeywords = {
  'zd421t': 'Zebra ZD421t', 'zd421': 'Zebra ZD421', 'zd620': 'Zebra ZD620',
  'zt410': 'Zebra ZT410',   'gk420': 'Zebra GK420d',
  'ql-820': 'Brother QL-820NWB', 'ql-810': 'Brother QL-810W',
  'ql-800': 'Brother QL-800',    'ql-700': 'Brother QL-700',
  'ql-500': 'Brother QL-500', 'ql-550': 'Brother QL-550',
  'ql-570': 'Brother QL-570', 'ql-650': 'Brother QL-650TD',
};

// Only QL-500/550/650TD are truly legacy (no ESC i z).
const _kLegacyQlPrefixes = ['ql-500', 'ql-550', 'ql-650'];

String _inferProtocol(String combined) {
  if (combined.contains('brother') || combined.contains('ql-')) {
    for (final prefix in _kLegacyQlPrefixes) {
      if (combined.contains(prefix)) return 'brother_ql_legacy';
    }
    return 'brother_ql';
  }
  return 'zpl';
}

String? _matchModel(String combined) {
  for (final e in _kModelKeywords.entries) {
    if (combined.contains(e.key)) return e.value;
  }
  return null;
}

_InstalledPrinterInfo _parseWindowsPrinter(String name, String driver, String port) {
  final combined = '${name.toLowerCase()} ${driver.toLowerCase()}';
  final portL = port.toLowerCase();
  String connectionType = 'usb';
  String? ipAddress;
  if (portL.startsWith('ip_') || portL.startsWith('tcp') || portL.startsWith('ne') ||
      portL.contains('wsd') || RegExp(r'^\d{1,3}\.\d{1,3}').hasMatch(port)) {
    connectionType = 'wifi';
    final m = RegExp(r'(\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3})').firstMatch(port);
    ipAddress = m?.group(1);
  }
  return _InstalledPrinterInfo(
    name: name, driverName: driver, portName: port,
    protocol: _inferProtocol(combined), connectionType: connectionType,
    ipAddress: ipAddress, matchedModel: _matchModel(combined),
  );
}

_InstalledPrinterInfo _parseCupsPrinter(String name, String device) {
  final combined = name.toLowerCase();
  String connectionType = 'usb';
  String? ipAddress;
  if (device.startsWith('socket://') || device.startsWith('ipp') || device.startsWith('http')) {
    connectionType = 'wifi';
    final m = RegExp(r'(\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3})').firstMatch(device);
    ipAddress = m?.group(1);
  }
  return _InstalledPrinterInfo(
    name: name, driverName: '', portName: device,
    protocol: _inferProtocol(combined), connectionType: connectionType,
    ipAddress: ipAddress, matchedModel: _matchModel(combined),
  );
}

Future<List<_InstalledPrinterInfo>> _fetchInstalledPrinters() async {
  final printers = <_InstalledPrinterInfo>[];
  try {
    if (Platform.isWindows) {
      final res = await Process.run('powershell', [
        '-NoProfile', '-NonInteractive', '-Command',
        r'Get-WmiObject Win32_Printer | Select-Object Name,DriverName,PortName | ConvertTo-Json -Compress',
      ]);
      if (res.exitCode == 0) {
        final raw = (res.stdout as String).trim();
        if (raw.isNotEmpty) {
          final decoded = jsonDecode(raw);
          final list = decoded is List ? decoded : [decoded];
          for (final item in list) {
            printers.add(_parseWindowsPrinter(
              item['Name']?.toString() ?? '',
              item['DriverName']?.toString() ?? '',
              item['PortName']?.toString() ?? '',
            ));
          }
        }
      }
    } else {
      final res = await Process.run('lpstat', ['-v']);
      if (res.exitCode == 0) {
        for (final line in (res.stdout as String).split('\n')) {
          final m = RegExp(r'^device for (.+?):\s+(.+)$').firstMatch(line.trim());
          if (m != null) printers.add(_parseCupsPrinter(m.group(1)!.trim(), m.group(2)!.trim()));
        }
      }
    }
  } catch (_) {}
  return printers;
}

class _InstalledPrintersDialog extends StatefulWidget {
  final void Function(_InstalledPrinterInfo) onSelect;
  const _InstalledPrintersDialog({required this.onSelect});
  @override State<_InstalledPrintersDialog> createState() => _InstalledPrintersDialogState();
}

class _InstalledPrintersDialogState extends State<_InstalledPrintersDialog> {
  List<_InstalledPrinterInfo>? _printers;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final p = await _fetchInstalledPrinters();
      if (mounted) setState(() => _printers = p);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: context.appSurface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      title: Row(children: [
        const Icon(Icons.manage_search_rounded, size: 18, color: AppDS.accent),
        const SizedBox(width: 10),
        Expanded(child: Text('Installed Printers',
            style: TextStyle(color: context.appTextPrimary, fontSize: 15, fontWeight: FontWeight.w600))),
        if (_printers == null && _error == null)
          const SizedBox(width: 14, height: 14,
              child: CircularProgressIndicator(color: AppDS.accent, strokeWidth: 2)),
      ]),
      content: SizedBox(
        width: 420, height: 320,
        child: _error != null
            ? Center(child: Text('Error: $_error',
                style: const TextStyle(color: AppDS.red, fontSize: 12)))
            : _printers == null
                ? Center(child: Text('Querying system…',
                    style: TextStyle(color: context.appTextSecondary, fontSize: 12)))
                : _printers!.isEmpty
                    ? Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                        Icon(Icons.print_disabled_rounded, size: 36, color: context.appTextMuted),
                        const SizedBox(height: 12),
                        Text('No printers detected',
                            style: TextStyle(color: context.appTextSecondary, fontSize: 13)),
                        const SizedBox(height: 4),
                        Text(
                          'Make sure the printer driver is installed\nand the device is connected.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: context.appTextMuted, fontSize: 11),
                        ),
                      ])
                    : ListView.separated(
                        separatorBuilder: (_, _) => Divider(height: 1, color: context.appBorder),
                        itemCount: _printers!.length,
                        itemBuilder: (_, i) => _InstalledPrinterTile(
                          printer: _printers![i],
                          onTap: () { Navigator.pop(context); widget.onSelect(_printers![i]); },
                        ),
                      ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text('Cancel', style: TextStyle(color: context.appTextSecondary)),
        ),
      ],
    );
  }
}

class _InstalledPrinterTile extends StatelessWidget {
  final _InstalledPrinterInfo printer;
  final VoidCallback onTap;
  const _InstalledPrinterTile({required this.printer, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      dense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      leading: Container(
        width: 34, height: 34,
        decoration: BoxDecoration(color: context.appSurface3, borderRadius: BorderRadius.circular(8)),
        child: const Icon(Icons.print_rounded, color: AppDS.accent, size: 18),
      ),
      title: Text(printer.name,
          style: TextStyle(color: context.appTextPrimary, fontSize: 13, fontWeight: FontWeight.w500)),
      subtitle: Text(
        printer.driverName.isNotEmpty ? printer.driverName : printer.portName,
        style: TextStyle(color: context.appTextSecondary, fontSize: 11),
        maxLines: 1, overflow: TextOverflow.ellipsis,
      ),
      trailing: Row(mainAxisSize: MainAxisSize.min, children: [
        _SmallBadge(printer.protocol == 'zpl' ? 'ZPL' : 'QL', AppDS.accent),
        const SizedBox(width: 4),
        _SmallBadge(printer.connectionType == 'wifi' ? 'Wi-Fi' : 'USB',
            printer.connectionType == 'wifi' ? AppDS.green : AppDS.textMuted),
        if (printer.matchedModel != null) ...[
          const SizedBox(width: 4),
          const Icon(Icons.check_circle_rounded, size: 13, color: AppDS.green),
        ],
      ]),
      onTap: onTap,
    );
  }
}

class _SmallBadge extends StatelessWidget {
  final String label;
  final Color color;
  const _SmallBadge(this.label, this.color);
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.15),
      borderRadius: BorderRadius.circular(4),
    ),
    child: Text(label, style: TextStyle(color: color, fontSize: 9, fontWeight: FontWeight.w700)),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// Network scan dialog — probes port 9100 across the local subnet
// ─────────────────────────────────────────────────────────────────────────────
class _ScanDialog extends StatefulWidget {
  final void Function(String ip) onSelect;
  const _ScanDialog({required this.onSelect});
  @override State<_ScanDialog> createState() => _ScanDialogState();
}

class _ScanDialogState extends State<_ScanDialog> {
  final List<String> _found = [];
  bool _scanning = true;
  int _scanned = 0;
  static const _total = 254;

  @override
  void initState() {
    super.initState();
    _startScan();
  }

  Future<void> _startScan() async {
    String subnet = '192.168.1';
    try {
      final interfaces = await NetworkInterface.list(type: InternetAddressType.IPv4);
      outer:
      for (final iface in interfaces) {
        for (final addr in iface.addresses) {
          if (!addr.isLoopback) {
            final parts = addr.address.split('.');
            if (parts.length == 4) {
              subnet = '${parts[0]}.${parts[1]}.${parts[2]}';
              break outer;
            }
          }
        }
      }
    } catch (_) {}

    const batchSize = 32;
    for (int i = 1; i <= _total; i += batchSize) {
      if (!mounted) return;
      await Future.wait([
        for (int j = i; j < i + batchSize && j <= _total; j++) _probe('$subnet.$j'),
      ]);
    }
    if (mounted) setState(() => _scanning = false);
  }

  Future<void> _probe(String ip) async {
    try {
      final socket = await Socket.connect(ip, 9100, timeout: const Duration(milliseconds: 300));
      await socket.close();
      if (mounted) setState(() => _found.add(ip));
    } catch (_) {}
    if (mounted) setState(() => _scanned++);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppDS.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      title: Row(children: [
        const Icon(Icons.wifi_find_rounded, size: 18, color: AppDS.accent),
        const SizedBox(width: 10),
        const Text('Network Scan',
            style: TextStyle(color: AppDS.textPrimary, fontSize: 15, fontWeight: FontWeight.w600)),
        const Spacer(),
        if (_scanning)
          const SizedBox(width: 14, height: 14,
              child: CircularProgressIndicator(color: AppDS.accent, strokeWidth: 2)),
      ]),
      content: SizedBox(
        width: 320, height: 260,
        child: Column(children: [
          LinearProgressIndicator(
            value: _scanned / _total,
            backgroundColor: AppDS.surface3,
            valueColor: const AlwaysStoppedAnimation<Color>(AppDS.accent),
          ),
          const SizedBox(height: 6),
          Text(
            _scanning
                ? 'Scanning $_scanned/$_total hosts on port 9100…'
                : 'Done — found ${_found.length} printer${_found.length != 1 ? 's' : ''}',
            style: const TextStyle(color: AppDS.textSecondary, fontSize: 11),
          ),
          const SizedBox(height: 10),
          Expanded(
            child: _found.isEmpty
                ? Center(
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      const Icon(Icons.print_disabled_rounded, size: 32, color: AppDS.textMuted),
                      const SizedBox(height: 8),
                      Text(_scanning ? 'Searching…' : 'No printers found on port 9100',
                          style: const TextStyle(color: AppDS.textSecondary, fontSize: 12)),
                    ]))
                : ListView.builder(
                    itemCount: _found.length,
                    itemBuilder: (_, i) => ListTile(
                      dense: true,
                      leading: const Icon(Icons.print_rounded, color: AppDS.accent, size: 18),
                      title: Text(_found[i],
                          style: const TextStyle(color: AppDS.textPrimary, fontSize: 13)),
                      subtitle: const Text('Port 9100',
                          style: TextStyle(color: AppDS.textSecondary, fontSize: 11)),
                      onTap: () {
                        Navigator.pop(context);
                        widget.onSelect(_found[i]);
                      },
                    ),
                  ),
          ),
        ]),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel', style: TextStyle(color: AppDS.textSecondary)),
        ),
      ],
    );
  }
}
