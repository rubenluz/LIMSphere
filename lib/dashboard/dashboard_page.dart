// dashboard_page.dart - Customizable dashboard with 10 widget slot types
// (next transfers, strains by origin/medium, tank cleaning, fish by line,
// to-do, timelines, transfer status, in-care). Layout persisted in SharedPrefs.

import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import '/menu/app_nav.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dashboard_widgets/next_transfer_widget.dart';
import 'dashboard_widgets/strains_by_origin_widget.dart';
import 'dashboard_widgets/strains_by_medium_widget.dart';
import 'dashboard_widgets/transfer_status_widget.dart';
import 'dashboard_widgets/incare_widget.dart';
import 'dashboard_widgets/tank_cleaning_widget.dart';
import 'dashboard_widgets/fish_by_line_widget.dart';
import 'dashboard_widgets/to_do_widget.dart';
import 'dashboard_widgets/transfer_timeline_widget.dart';
import 'dashboard_widgets/tank_cleaning_timeline_widget.dart';
import 'dashboard_widgets/maintenance_overview_widget.dart';

// All available widgets — add new ones here and they appear in the picker.
const _availableWidgets = [
  {'id': 'next_transfer',    'name': 'Next Transfers',    'icon': Icons.schedule},
  {'id': 'strains_by_origin','name': 'Strains by Origin', 'icon': Icons.pie_chart},
  {'id': 'strains_by_medium','name': 'Strains by Medium', 'icon': Icons.water_drop},
  {'id': 'transfer_status',  'name': 'Transfer Status',   'icon': Icons.warning_amber},
  {'id': 'in_care',          'name': 'In Care',           'icon': Icons.medical_services},
  {'id': 'tank_cleaning',    'name': 'Tank Cleaning',     'icon': Icons.cleaning_services_outlined},
  {'id': 'fish_by_line',     'name': 'Active Fish Lines',  'icon': Icons.biotech_outlined},
  {'id': 'to_do',            'name': 'To-Do',             'icon': Icons.checklist_rounded},
  {'id': 'transfer_timeline', 'name': 'Transfer Timeline', 'icon': Icons.timeline_rounded},
  {'id': 'cleaning_timeline',       'name': 'Cleaning Timeline',      'icon': Icons.cleaning_services_outlined},
  {'id': 'maintenance_overview',    'name': 'Fish Facility Maintenance', 'icon': Icons.build_circle_outlined},
];

class DashboardPage extends StatefulWidget {
  final Map<String, dynamic> userInfo;
  final List<Map<String, dynamic>> pendingUsers;
  final VoidCallback onGoToPendingUsers;

  const DashboardPage({
    super.key,
    required this.userInfo,
    required this.pendingUsers,
    required this.onGoToPendingUsers,
  });

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

enum _UpdateStatus { checking, upToDate, updateAvailable, error }

class _DashboardPageState extends State<DashboardPage> {
  // Desktop: 8-slot grid (4 cols × 2 rows), index = row*4 + col
  Map<int, String?> _desktopSlots = {};

  // ── Update check (desktop only) ───────────────────────────────────────────
  _UpdateStatus _updateStatus = _UpdateStatus.checking;
  String? _currentVersion;
  String? _latestVersion;
  String? _downloadUrl;

  // Span per top-row slot (index 0-3): 1 = normal, 2 = double-height
  Map<int, int> _desktopSpans = {};

  // Mobile: ordered list of widget ids (no empty slots)
  List<String> _mobileWidgets = [];

  @override
  void initState() {
    super.initState();
    _initializeDashboard();
    _checkForUpdate();
  }

  // ── Update check ───────────────────────────────────────────────────────────

  static bool get _isDesktop =>
      !kIsWeb && (Platform.isWindows || Platform.isMacOS || Platform.isLinux);

  int _cmpVer(String a, String b) {
    final av = a.split('.').map(int.tryParse).toList();
    final bv = b.split('.').map(int.tryParse).toList();
    for (int i = 0; i < 3; i++) {
      final ai = (i < av.length ? av[i] : null) ?? 0;
      final bi = (i < bv.length ? bv[i] : null) ?? 0;
      if (ai != bi) return ai.compareTo(bi);
    }
    return 0;
  }

  Future<void> _checkForUpdate() async {
    final info = await PackageInfo.fromPlatform();
    final currentVer = info.version;
    if (mounted) setState(() => _currentVersion = currentVer);

    if (!_isDesktop) {
      setState(() => _updateStatus = _UpdateStatus.upToDate);
      return;
    }
    const api = 'https://api.github.com/repos/rubenluz/blue_open_lims/contents/desktop_release';
    try {
      final client = HttpClient();
      final req = await client.getUrl(Uri.parse(api));
      req.headers.set('User-Agent', 'LIMSSphere');
      final res = await req.close().timeout(const Duration(seconds: 10));
      final body = await res.transform(const Utf8Decoder()).join();
      client.close();

      if (res.statusCode != 200) {
        if (mounted) setState(() => _updateStatus = _UpdateStatus.error);
        return;
      }

      final files = jsonDecode(body) as List<dynamic>;
      String? latestVer;
      String? latestUrl;

      for (final file in files) {
        final name = (file as Map<String, dynamic>)['name'] as String? ?? '';
        final m = RegExp(r'LIMSSphere_installer_v(\d+\.\d+\.\d+)').firstMatch(name);
        if (m != null) {
          final ver = m.group(1)!;
          if (latestVer == null || _cmpVer(ver, latestVer) > 0) {
            latestVer = ver;
            latestUrl = file['download_url'] as String?;
          }
        }
      }

      if (!mounted) return;
      if (latestVer == null) {
        setState(() => _updateStatus = _UpdateStatus.error);
      } else if (_cmpVer(latestVer, currentVer) > 0) {
        setState(() {
          _updateStatus = _UpdateStatus.updateAvailable;
          _latestVersion = latestVer;
          _downloadUrl = latestUrl;
        });
      } else {
        setState(() => _updateStatus = _UpdateStatus.upToDate);
      }
    } catch (_) {
      if (mounted) setState(() => _updateStatus = _UpdateStatus.error);
    }
  }

  void _openDownload() {
    final url = _downloadUrl;
    if (url == null) return;
    if (Platform.isWindows) {
      Process.run('cmd', ['/c', 'start', '', url], runInShell: true);
    } else if (Platform.isMacOS) {
      Process.run('open', [url]);
    } else {
      Process.run('xdg-open', [url]);
    }
  }

  // ── Init & persistence ─────────────────────────────────────────────────────

  Future<void> _initializeDashboard() async {
    _desktopSlots = {for (int i = 0; i < 8; i++) i: null};
    _desktopSpans = {for (int i = 0; i < 4; i++) i: 1};

    final prefs = await SharedPreferences.getInstance();

    // ── Desktop slots ──────────────────────────────────────────────────────
    final savedDesktop = prefs.getString('dashboard_slots');
    if (savedDesktop != null && savedDesktop.isNotEmpty) {
      try {
        final decoded = jsonDecode(savedDesktop) as Map<String, dynamic>;
        decoded.forEach((key, value) {
          final index = int.tryParse(key);
          if (index != null) _desktopSlots[index] = value as String?;
        });
      } catch (_) {
        _applyDesktopDefaults();
      }
    } else {
      _applyDesktopDefaults();
    }

    // ── Desktop spans ──────────────────────────────────────────────────────
    final savedSpans = prefs.getString('dashboard_spans');
    if (savedSpans != null && savedSpans.isNotEmpty) {
      try {
        final decoded = jsonDecode(savedSpans) as Map<String, dynamic>;
        decoded.forEach((key, value) {
          final index = int.tryParse(key);
          if (index != null && index < 4) {
            _desktopSpans[index] = (value as num).toInt();
          }
        });
      } catch (_) {}
    }

    // ── Mobile widget list ─────────────────────────────────────────────────
    final savedMobile = prefs.getString('dashboard_mobile_widgets');
    if (savedMobile != null && savedMobile.isNotEmpty) {
      try {
        _mobileWidgets = List<String>.from(jsonDecode(savedMobile));
      } catch (_) {
        _applyMobileDefaults();
      }
    } else {
      _applyMobileDefaults();
    }

    if (mounted) setState(() {});
  }

  void _applyDesktopDefaults() {
    // Col 0: To-Do spanning full height
    _desktopSlots[0] = 'to_do';      _desktopSpans[0] = 2;
    _desktopSlots[4] = null;

    // Col 1: Next Transfer (top) + Tank Cleaning (bottom)
    _desktopSlots[1] = 'next_transfer'; _desktopSpans[1] = 1;
    _desktopSlots[5] = 'tank_cleaning';

    // Col 2: Transfer Status (top) + Fish by Line (bottom)
    _desktopSlots[2] = 'transfer_status'; _desktopSpans[2] = 1;
    _desktopSlots[6] = 'fish_by_line';

    // Col 3: In Care spanning full height
    _desktopSlots[3] = 'in_care';    _desktopSpans[3] = 2;
    _desktopSlots[7] = null;
  }

  void _applyMobileDefaults() {
    _mobileWidgets = [
      'transfer_status',
      'next_transfer',
      'in_care',
      'strains_by_origin',
      'strains_by_medium',
    ];
  }

  Future<void> _saveDesktopConfig() async {
    final prefs = await SharedPreferences.getInstance();
    final toSave = <String, String?>{};
    _desktopSlots.forEach((k, v) => toSave[k.toString()] = v);
    await prefs.setString('dashboard_slots', jsonEncode(toSave));
  }

  Future<void> _saveDesktopSpans() async {
    final prefs = await SharedPreferences.getInstance();
    final toSave = <String, int>{};
    _desktopSpans.forEach((k, v) => toSave[k.toString()] = v);
    await prefs.setString('dashboard_spans', jsonEncode(toSave));
  }

  Future<void> _saveMobileConfig() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        'dashboard_mobile_widgets', jsonEncode(_mobileWidgets));
  }

  // ── Widget builder ─────────────────────────────────────────────────────────

  Widget _buildWidget(String widgetType) {
    switch (widgetType) {
      case 'next_transfer':     return const NextTransferWidget();
      case 'strains_by_origin': return const StrainsByOriginWidget();
      case 'strains_by_medium': return const StrainsByMediumWidget();
      case 'transfer_status':   return const TransferStatusWidget();
      case 'in_care':           return const InCareWidget();
      case 'tank_cleaning':     return const TankCleaningWidget();
      case 'fish_by_line':      return const FishByLineWidget();
      case 'to_do':              return const ToDoWidget();
      case 'transfer_timeline':  return const TransferTimelineWidget();
      case 'cleaning_timeline':      return const TankCleaningTimelineWidget();
      case 'maintenance_overview':   return const MaintenanceOverviewWidget();
      default:                       return const SizedBox.shrink();
    }
  }

  // ── Desktop: 4-col × 2-row grid ────────────────────────────────────────────

  void _showDesktopWidgetPicker(int slotIndex) {
    final hasWidget = _desktopSlots[slotIndex] != null;
    // Spans only apply to top-row slots (0–3); bottom slots use index as-is
    final isTopRow = slotIndex < 4;
    int dialogSpan = _desktopSpans[slotIndex] ?? 1;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDs) => AlertDialog(
          title: const Text('Manage Widget'),
          content: SizedBox(
            width: 320,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // ── Height selector (top-row slots only) ──────────────────
                if (isTopRow) ...[
                  Row(children: [
                    const Icon(Icons.height, size: 16),
                    const SizedBox(width: 8),
                    const Text('Height:',
                        style: TextStyle(
                            fontWeight: FontWeight.w500, fontSize: 13)),
                    const SizedBox(width: 12),
                    ChoiceChip(
                      label: const Text('1 row'),
                      selected: dialogSpan == 1,
                      onSelected: (v) {
                        if (v) setDs(() => dialogSpan = 1);
                      },
                    ),
                    const SizedBox(width: 8),
                    ChoiceChip(
                      label: const Text('2 rows'),
                      selected: dialogSpan == 2,
                      onSelected: (v) {
                        if (v) setDs(() => dialogSpan = 2);
                      },
                    ),
                  ]),
                  const Divider(height: 16),
                ],
                // ── Widget list ────────────────────────────────────────────
                SizedBox(
                  height: 240,
                  child: ListView(
                    shrinkWrap: true,
                    children: _availableWidgets
                        .map((w) => ListTile(
                              leading: Icon(w['icon'] as IconData),
                              title: Text(w['name'] as String),
                              selected:
                                  _desktopSlots[slotIndex] == w['id'],
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8)),
                              onTap: () async {
                                final span = isTopRow ? dialogSpan : 1;
                                setState(() {
                                  _desktopSlots[slotIndex] =
                                      w['id'] as String;
                                  if (isTopRow) {
                                    _desktopSpans[slotIndex] = span;
                                    if (span == 2) {
                                      // absorb the bottom slot
                                      _desktopSlots[slotIndex + 4] = null;
                                    }
                                  }
                                });
                                final nav = Navigator.of(ctx);
                                await _saveDesktopConfig();
                                if (isTopRow) await _saveDesktopSpans();
                                nav.pop();
                              },
                            ))
                        .toList(),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            // Apply height change without changing the widget
            if (hasWidget &&
                isTopRow &&
                dialogSpan != (_desktopSpans[slotIndex] ?? 1))
              TextButton(
                onPressed: () async {
                  final nav = Navigator.of(ctx);
                  setState(() {
                    _desktopSpans[slotIndex] = dialogSpan;
                    if (dialogSpan == 2) {
                      _desktopSlots[slotIndex + 4] = null;
                    }
                  });
                  await _saveDesktopConfig();
                  await _saveDesktopSpans();
                  nav.pop();
                },
                child: const Text('Apply Height'),
              ),
            if (hasWidget)
              TextButton.icon(
                icon: const Icon(Icons.delete_outline),
                label: const Text('Remove'),
                onPressed: () async {
                  final nav = Navigator.of(ctx);
                  setState(() {
                    _desktopSlots[slotIndex] = null;
                    if (isTopRow) _desktopSpans[slotIndex] = 1;
                  });
                  await _saveDesktopConfig();
                  if (isTopRow) await _saveDesktopSpans();
                  nav.pop();
                },
              ),
            TextButton.icon(
              icon: const Icon(Icons.restore, size: 16),
              label: const Text('Reset to Defaults'),
              onPressed: () async {
                final nav = Navigator.of(ctx);
                setState(() {
                  _applyDesktopDefaults();
                });
                await _saveDesktopConfig();
                await _saveDesktopSpans();
                nav.pop();
              },
            ),
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancel'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDesktopSlot(int index) {
    final widgetType = _desktopSlots[index];
    return GestureDetector(
      onTap: () => _showDesktopWidgetPicker(index),
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(
              color: widgetType == null
                  ? Colors.grey.shade300
                  : Colors.transparent),
          borderRadius: BorderRadius.circular(8),
          color: widgetType == null ? Colors.grey.shade50 : null,
        ),
        child: widgetType == null
            ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.add, size: 28, color: Colors.grey.shade400),
                    const SizedBox(height: 6),
                    Text('Add Widget',
                        style: TextStyle(
                            color: Colors.grey.shade500, fontSize: 11)),
                  ],
                ),
              )
            : Stack(children: [
                Positioned.fill(child: _buildWidget(widgetType)),
                // Small edit button top-right
                Positioned(
                  top: 4, right: 4,
                  child: Material(
                    color: Colors.black.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(6),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(6),
                      onTap: () => _showDesktopWidgetPicker(index),
                      child: const Padding(
                        padding: EdgeInsets.all(4),
                        child: Icon(Icons.edit, size: 12, color: Colors.white70),
                      ),
                    ),
                  ),
                ),
              ]),
      ),
    );
  }

  // Grid fills the available height; each column handles its own span.
  Widget _buildDesktopGrid() {
    const cols = 4;
    const spacing = 12.0;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: List.generate(cols, (col) {
        final topIdx = col;     // row 0: indices 0–3
        final botIdx = col + 4; // row 1: indices 4–7
        final span = _desktopSpans[topIdx] ?? 1;

        final Widget colContent = span == 2
            ? _buildDesktopSlot(topIdx)
            : Column(children: [
                Expanded(child: _buildDesktopSlot(topIdx)),
                const SizedBox(height: spacing),
                Expanded(child: _buildDesktopSlot(botIdx)),
              ]);

        return Expanded(
          child: col < cols - 1
              ? Padding(
                  padding: const EdgeInsets.only(right: spacing),
                  child: colContent,
                )
              : colContent,
        );
      }),
    );
  }

  // ── Mobile: reorderable list ───────────────────────────────────────────────

  void _showMobileWidgetPicker() {
    // Only show widgets not already on the list
    final available = _availableWidgets
        .where((w) => !_mobileWidgets.contains(w['id']))
        .toList();

    if (available.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('All widgets are already on your dashboard')),
      );
      return;
    }

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 36, height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(children: [
              const Text('Add Widget',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const Spacer(),
              TextButton.icon(
                icon: const Icon(Icons.restore, size: 14),
                label: const Text('Reset', style: TextStyle(fontSize: 13)),
                onPressed: () async {
                  final nav = Navigator.of(ctx);
                  setState(() => _applyMobileDefaults());
                  await _saveMobileConfig();
                  nav.pop();
                },
              ),
            ]),
            const SizedBox(height: 12),
            ...available.map((w) => ListTile(
              leading: Icon(w['icon'] as IconData),
              title: Text(w['name'] as String),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
              onTap: () async {
                final nav = Navigator.of(ctx);
                setState(() => _mobileWidgets.add(w['id'] as String));
                await _saveMobileConfig();
                nav.pop();
              },
            )),
          ],
        ),
      ),
    );
  }

  Widget _buildMobileList() {
    return ReorderableListView.builder(
      shrinkWrap: true,
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.only(bottom: 80),
      itemCount: _mobileWidgets.length + 1, // +1 for the "Add" button at end
      onReorder: (oldIndex, newIndex) async {
        // Guard: don't reorder into/from the Add button slot
        if (oldIndex >= _mobileWidgets.length ||
            newIndex > _mobileWidgets.length) {
          return;
        }
        setState(() {
          if (newIndex > oldIndex) newIndex--;
          final item = _mobileWidgets.removeAt(oldIndex);
          _mobileWidgets.insert(newIndex, item);
        });
        await _saveMobileConfig();
      },
      itemBuilder: (ctx, i) {
        // Last slot: Add Widget button (non-reorderable)
        if (i == _mobileWidgets.length) {
          return ListTile(
            key: const ValueKey('__add__'),
            leading: const Icon(Icons.add_circle_outline),
            title: const Text('Add Widget'),
            onTap: _showMobileWidgetPicker,
          );
        }

        final widgetId = _mobileWidgets[i];
        final meta = _availableWidgets.firstWhere(
          (w) => w['id'] == widgetId,
          orElse: () => {'id': widgetId, 'name': widgetId, 'icon': Icons.widgets},
        );

        return Padding(
          key: ValueKey(widgetId),
          padding: const EdgeInsets.only(bottom: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Widget header row with drag handle + remove
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(children: [
                  Icon(meta['icon'] as IconData,
                      size: 14, color: Colors.grey.shade500),
                  const SizedBox(width: 6),
                  Text(meta['name'] as String,
                      style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                          fontWeight: FontWeight.w500)),
                  const Spacer(),
                  // Remove button
                  GestureDetector(
                    onTap: () async {
                      setState(() => _mobileWidgets.removeAt(i));
                      await _saveMobileConfig();
                    },
                    child: Icon(Icons.close,
                        size: 14, color: Colors.grey.shade400),
                  ),
                  const SizedBox(width: 8),
                  // Drag handle
                  Icon(Icons.drag_handle,
                      size: 16, color: Colors.grey.shade400),
                ]),
              ),
              // Widget sizes itself naturally — no fixed height
              _buildWidget(widgetId),
            ],
          ),
        );
      },
    );
  }

  // ── Header ─────────────────────────────────────────────────────────────────

  Widget _buildUpdateButton() {
    switch (_updateStatus) {
      case _UpdateStatus.checking:
        return const SizedBox(
          width: 16, height: 16,
          child: CircularProgressIndicator(strokeWidth: 2),
        );
      case _UpdateStatus.upToDate:
        return Row(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.check_circle, size: 15, color: Color(0xFF22C55E)),
          const SizedBox(width: 5),
          Text('Application up to date${_currentVersion != null ? ' (v$_currentVersion)' : ''}',
              style: TextStyle(fontSize: 12, color: Colors.green.shade600,
                  fontWeight: FontWeight.w600)),
        ]);
      case _UpdateStatus.updateAvailable:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_currentVersion != null)
              Text('Current: v$_currentVersion',
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
            const SizedBox(height: 4),
            TextButton.icon(
              style: TextButton.styleFrom(
                foregroundColor: Colors.white,
                backgroundColor: const Color(0xFF38BDF8),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: _openDownload,
              icon: const Icon(Icons.download_rounded, size: 15),
              label: Text('Download v${_latestVersion ?? ''}',
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
            ),
          ],
        );
      case _UpdateStatus.error:
        return Tooltip(
          message: 'Could not check for updates',
          child: InkWell(
            borderRadius: BorderRadius.circular(6),
            onTap: () {
              setState(() => _updateStatus = _UpdateStatus.checking);
              _checkForUpdate();
            },
            child: Padding(
              padding: const EdgeInsets.all(4),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.refresh, size: 14, color: Colors.grey.shade400),
                const SizedBox(width: 4),
                Text('Retry',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade400)),
              ]),
            ),
          ),
        );
    }
  }

  Widget _buildHeader() {
    final name = widget.userInfo['user_name'] as String? ??
        widget.userInfo['user_username'] as String? ?? '';
    final isMobile = MediaQuery.of(context).size.width < 700;
    return Row(
      children: [
        if (isMobile) ...[
          IconButton(
            icon: const Icon(Icons.menu_rounded, size: 20),
            tooltip: 'Menu',
            onPressed: openAppDrawer,
          ),
          const SizedBox(width: 4),
        ],
        Text(
          'Welcome back${name.isNotEmpty ? ", $name" : ''}!',
          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
        ),
        const Spacer(),
        if (_isDesktop) _buildUpdateButton(),
        const SizedBox(width: 12),
        Tooltip(
          message: 'View on GitHub',
          child: InkWell(
            borderRadius: BorderRadius.circular(6),
            onTap: () {
              const url = 'https://github.com/rubenluz/blue_open_lims';
              if (Platform.isWindows) {
                Process.run('cmd', ['/c', 'start', '', url], runInShell: true);
              } else if (Platform.isMacOS) {
                Process.run('open', [url]);
              } else {
                Process.run('xdg-open', [url]);
              }
            },
            child: const Padding(
              padding: EdgeInsets.all(6),
              child: FaIcon(FontAwesomeIcons.github, size: 18),
            ),
          ),
        ),
      ],
    );
  }

  // ── BUILD ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 700;

    return Padding(
      padding: EdgeInsets.all(isMobile ? 12 : 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(),
          const SizedBox(height: 16),

          // ── Pending users banner ─────────────────────────────────────────
          if (widget.pendingUsers.isNotEmpty) ...[
            Card(
              color: Theme.of(context).colorScheme.errorContainer,
              margin: const EdgeInsets.only(bottom: 16),
              child: ListTile(
                leading: const Icon(Icons.person_add_outlined),
                title: Text(
                    '${widget.pendingUsers.length} user(s) awaiting approval'),
                trailing: TextButton(
                  onPressed: widget.onGoToPendingUsers,
                  child: const Text('Review'),
                ),
              ),
            ),
          ],

          // ── Grid (desktop) or List (mobile) ──────────────────────────────
          Expanded(
            child: isMobile
                ? _buildMobileList()
                : _buildDesktopGrid(),
          ),
        ],
      ),
    );
  }
}
