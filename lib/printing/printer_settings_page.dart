part of 'printing_page.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Tab 3 — Printer settings
// ─────────────────────────────────────────────────────────────────────────────
class _PrinterTab extends StatefulWidget {
  final PrinterConfig config;
  final VoidCallback onChanged;
  const _PrinterTab({super.key, required this.config, required this.onChanged});

  @override
  State<_PrinterTab> createState() => _PrinterTabState();
}

class _PrinterTabState extends State<_PrinterTab> {
  late final _ipCtrl  = TextEditingController(text: widget.config.ipAddress);
  late final _usbCtrl = TextEditingController(text: widget.config.usbPath);
  bool _testPrinting = false;
  String? _testStatus;

  static const _modelsByProtocol = {
    'zpl':               ['Zebra ZD421', 'Zebra ZD421t', 'Zebra ZD620', 'Zebra ZT410', 'Zebra GK420d'],
    'brother_ql':        ['Brother QL-820NWB', 'Brother QL-810W', 'Brother QL-800', 'Brother QL-700'],
    'brother_ql_legacy': ['Brother QL-500', 'Brother QL-550', 'Brother QL-570', 'Brother QL-650TD'],
  };

  @override
  Widget build(BuildContext context) {
    final cfg = widget.config;
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [

        _SectionHeader('Connection', Icons.wifi_rounded),
        const SizedBox(height: 12),
        _SegmentRow(
          label: 'Protocol',
          options: const {'zpl': 'ZPL (Zebra)', 'brother_ql': 'Brother QL', 'brother_ql_legacy': 'QL Legacy'},
          value: cfg.protocol,
          onChanged: (v) {
            setState(() {
              cfg.protocol = v;
              cfg.deviceName = _modelsByProtocol[v]!.first;
              // Legacy models are USB-only
              if (v == 'brother_ql_legacy') cfg.connectionType = 'usb';
            });
            widget.onChanged();
          },
        ),
        const SizedBox(height: 12),
        if (cfg.protocol == 'brother_ql_legacy') ...[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: AppDS.accent.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppDS.accent.withValues(alpha: 0.3)),
            ),
            child: Row(children: [
              const Icon(Icons.info_outline_rounded, size: 14, color: AppDS.accent),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'QL-500/550/570/650TD — USB only, fixed 300 DPI, no half-cut.',
                  style: TextStyle(fontSize: 11, color: AppDS.accent),
                ),
              ),
            ]),
          ),
          const SizedBox(height: 12),
        ],
        if (cfg.protocol != 'brother_ql_legacy')
          _SegmentRow(
            label: 'Type',
            options: const {'usb': 'USB', 'wifi': 'Wi-Fi', 'bluetooth': 'Bluetooth'},
            value: cfg.connectionType,
            onChanged: (v) { setState(() => cfg.connectionType = v); widget.onChanged(); },
          ),
        if (cfg.protocol == 'brother_ql_legacy')
          _SegmentRow(
            label: 'Type',
            options: const {'usb': 'USB'},
            value: 'usb',
            onChanged: (_) {},
          ),
        const SizedBox(height: 12),
        _DropdownRow(
          label: 'Model',
          options: _modelsByProtocol[cfg.protocol] ?? _modelsByProtocol['zpl']!,
          value: cfg.deviceName,
          onChanged: (v) { setState(() => cfg.deviceName = v!); widget.onChanged(); },
        ),
        const SizedBox(height: 12),
        if (cfg.connectionType == 'usb') ...[
          _PropLabel(Platform.isWindows ? 'Printer Name (Windows queue)' : 'USB Device Path'),
          const SizedBox(height: 4),
          TextField(
            controller: _usbCtrl,
            style: TextStyle(fontSize: 13, color: context.appTextPrimary),
            decoration: InputDecoration(
              isDense: true, filled: true, fillColor: context.appSurface,
              hintText: Platform.isWindows ? 'Zebra ZD421' : '/dev/usb/lp0',
              hintStyle: TextStyle(color: context.appTextSecondary),
              prefixIcon: Icon(Icons.usb_rounded, size: 16, color: context.appTextMuted),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: context.appBorder)),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: context.appBorder)),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppDS.accent)),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            ),
            onChanged: (v) { cfg.usbPath = v; widget.onChanged(); },
          ),
          const SizedBox(height: 6),
        ],
        if (cfg.connectionType == 'wifi') ...[
          _PropLabel('IP Address'),
          const SizedBox(height: 4),
          Row(children: [
            Expanded(
              child: TextField(
                controller: _ipCtrl,
                style: TextStyle(fontSize: 13, color: context.appTextPrimary),
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  isDense: true, filled: true, fillColor: context.appSurface,
                  hintText: '192.168.1.100',
                  hintStyle: TextStyle(color: context.appTextSecondary),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: context.appBorder)),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: context.appBorder)),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppDS.accent)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                ),
                onChanged: (v) { cfg.ipAddress = v; widget.onChanged(); },
              ),
            ),
            const SizedBox(width: 10),
            FilledButton.icon(
              style: FilledButton.styleFrom(backgroundColor: context.appBorder, foregroundColor: context.appTextPrimary,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10)),
              icon: const Icon(Icons.search_rounded, size: 16),
              label: const Text('Scan', style: TextStyle(fontSize: 12)),
              onPressed: _scanNetwork,
            ),
          ]),
          const SizedBox(height: 6),
        ],

        const SizedBox(height: 24),
        if (_testStatus != null) ...[
          Text(_testStatus!,
              style: TextStyle(
                  fontSize: 11,
                  color: _testStatus!.startsWith('Error') ? AppDS.red
                      : _testStatus!.contains('✓') ? AppDS.green
                      : context.appTextSecondary)),
          const SizedBox(height: 8),
        ],
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
                foregroundColor: AppDS.accent,
                side: const BorderSide(color: AppDS.accent),
                padding: const EdgeInsets.symmetric(vertical: 14)),
            icon: _testPrinting
                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: AppDS.accent, strokeWidth: 2))
                : const Icon(Icons.print_outlined, size: 18),
            label: Text(_testPrinting ? 'Sending…' : 'Send Test Print'),
            onPressed: _testPrinting ? null : _sendTestPrint,
          ),
        ),
      ],
    );
  }

  Future<void> _sendTestPrint() async {
    setState(() { _testPrinting = true; _testStatus = 'Sending test label…'; });
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
      await _sendToPrinter(testTpl, const [], widget.config);
      setState(() { _testPrinting = false; _testStatus = 'Test label sent ✓'; });
    } catch (e) {
      setState(() { _testPrinting = false; _testStatus = 'Error: $e'; });
    }
  }

  void _scanNetwork() {
    showDialog(
      context: context,
      builder: (_) => _ScanDialog(
        onSelect: (ip) {
          setState(() {
            widget.config.ipAddress = ip;
            _ipCtrl.text = ip;
          });
          widget.onChanged();
        },
      ),
    );
  }


  void _applyDetected(_InstalledPrinterInfo info) {
    setState(() {
      final cfg = widget.config;
      cfg.protocol       = info.protocol;
      // Legacy QL models are USB-only regardless of detected port type
      cfg.connectionType = info.protocol == 'brother_ql_legacy' ? 'usb' : info.connectionType;
      cfg.deviceName     = info.matchedModel ?? _modelsByProtocol[info.protocol]!.first;
      if (info.connectionType == 'usb') {
        cfg.usbPath  = info.name;
        _usbCtrl.text = info.name;
      } else if (info.connectionType == 'wifi' && info.ipAddress != null) {
        cfg.ipAddress = info.ipAddress!;
        _ipCtrl.text  = info.ipAddress!;
      }
    });
    widget.onChanged();
  }
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
    SizedBox(width: 80, child: Text(label, style: TextStyle(fontSize: 12, color: context.appTextSecondary))),
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
  // Legacy models
  'ql-500': 'Brother QL-500', 'ql-550': 'Brother QL-550',
  'ql-570': 'Brother QL-570', 'ql-650': 'Brother QL-650TD',
};

// QL-500/550/570/650TD use the legacy raster protocol
const _kLegacyQlPrefixes = ['ql-5', 'ql-650'];

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
      backgroundColor: AppDS.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      title: Row(children: [
        const Icon(Icons.manage_search_rounded, size: 18, color: AppDS.accent),
        const SizedBox(width: 10),
        const Expanded(child: Text('Installed Printers',
            style: TextStyle(color: AppDS.textPrimary, fontSize: 15, fontWeight: FontWeight.w600))),
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
                ? const Center(child: Text('Querying system…',
                    style: TextStyle(color: AppDS.textSecondary, fontSize: 12)))
                : _printers!.isEmpty
                    ? Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                        Icon(Icons.print_disabled_rounded, size: 36, color: AppDS.textMuted),
                        const SizedBox(height: 12),
                        const Text('No printers detected',
                            style: TextStyle(color: AppDS.textSecondary, fontSize: 13)),
                        const SizedBox(height: 4),
                        const Text(
                          'Make sure the printer driver is installed\nand the device is connected.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: AppDS.textMuted, fontSize: 11),
                        ),
                      ])
                    : ListView.separated(
                        separatorBuilder: (_, _) => Divider(height: 1, color: AppDS.border),
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
          child: const Text('Cancel', style: TextStyle(color: AppDS.textSecondary)),
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
        decoration: BoxDecoration(color: AppDS.surface3, borderRadius: BorderRadius.circular(8)),
        child: const Icon(Icons.print_rounded, color: AppDS.accent, size: 18),
      ),
      title: Text(printer.name,
          style: const TextStyle(color: AppDS.textPrimary, fontSize: 13, fontWeight: FontWeight.w500)),
      subtitle: Text(
        printer.driverName.isNotEmpty ? printer.driverName : printer.portName,
        style: const TextStyle(color: AppDS.textSecondary, fontSize: 11),
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
                      Icon(Icons.print_disabled_rounded, size: 32, color: AppDS.textMuted),
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
