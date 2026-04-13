// dashboard_page.dart – Customizable dashboard with 5 named profiles (desktop).
// Each profile persists its own 4×2 grid layout independently.
// Mobile: single reorderable widget list.

import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '/menu/app_nav.dart';
import '/theme/theme.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
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
import 'dashboard_widgets/low_stock_widget.dart';
import 'dashboard_widgets/reagents_by_type_widget.dart';
import 'dashboard_widgets/breeding_activity_widget.dart';
import 'dashboard_widgets/open_requests_widget.dart';
import 'dashboard_widgets/today_reservations_widget.dart';
import 'dashboard_widgets/pending_users_widget.dart';

const int _kProfileCount = 5;

// Category order for the widget picker.
const _widgetCategories = [
  'Fish Facility',
  'Culture Collection',
  'Resources',
  'Requests',
  'Backups',
  'General',
];

const _availableWidgets = [
  // ── Fish Facility ────────────────────────────────────────────────────────
  {'id': 'fish_by_line',        'name': 'Active Fish Lines',        'icon': Icons.biotech_outlined,           'cat': 'Fish Facility'},
  {'id': 'tank_cleaning',       'name': 'Tank Cleaning',            'icon': Icons.cleaning_services_outlined, 'cat': 'Fish Facility'},
  {'id': 'cleaning_timeline',   'name': 'Cleaning Timeline',        'icon': Icons.timeline_rounded,           'cat': 'Fish Facility'},
  {'id': 'maintenance_overview','name': 'Fish Facility Maintenance', 'icon': Icons.build_circle_outlined,      'cat': 'Fish Facility'},
  {'id': 'breeding_activity',  'name': 'Breeding Activity',        'icon': Icons.egg_outlined,               'cat': 'Fish Facility'},
  // ── Culture Collection ───────────────────────────────────────────────────
  {'id': 'next_transfer',       'name': 'Next Transfers',           'icon': Icons.schedule,                   'cat': 'Culture Collection'},
  {'id': 'transfer_status',     'name': 'Transfer Status',          'icon': Icons.warning_amber,              'cat': 'Culture Collection'},
  {'id': 'transfer_timeline',   'name': 'Transfer Timeline',        'icon': Icons.timeline_rounded,           'cat': 'Culture Collection'},
  {'id': 'in_care',             'name': 'In Care',                  'icon': Icons.medical_services,           'cat': 'Culture Collection'},
  {'id': 'strains_by_origin',   'name': 'Strains by Origin',        'icon': Icons.pie_chart,                  'cat': 'Culture Collection'},
  {'id': 'strains_by_medium',   'name': 'Strains by Medium',        'icon': Icons.water_drop,                 'cat': 'Culture Collection'},
  // ── Resources ────────────────────────────────────────────────────────────
  {'id': 'low_stock',           'name': 'Low Stock Alerts',         'icon': Icons.inventory_2_outlined,       'cat': 'Resources'},
  {'id': 'reagents_by_type',    'name': 'Reagents by Type',         'icon': Icons.donut_small_outlined,       'cat': 'Resources'},
  {'id': 'today_reservations',  'name': "Today's Reservations",     'icon': Icons.calendar_today_outlined,    'cat': 'Resources'},
  // ── Requests ────────────────────────────────────────────────────────────
  {'id': 'open_requests',       'name': 'Open Requests',            'icon': Icons.assignment_outlined,        'cat': 'Requests'},
  // ── General ──────────────────────────────────────────────────────────────
  {'id': 'to_do',               'name': 'To-Do',                   'icon': Icons.checklist_rounded,          'cat': 'General'},
  {'id': 'pending_users',       'name': 'Pending Users',            'icon': Icons.person_add_outlined,        'cat': 'General', 'role': 'admin'},
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
  // ── Profiles ───────────────────────────────────────────────────────────────
  int _activeProfile = 0;
  final List<String> _profileTitles =
      List.generate(_kProfileCount, (i) => 'Dashboard ${i + 1}');
  final List<Map<int, String?>> _profileSlots =
      List.generate(_kProfileCount, (_) => {for (int j = 0; j < 8; j++) j: null});
  final List<Map<int, int>> _profileSpans =
      List.generate(_kProfileCount, (_) => {for (int j = 0; j < 4; j++) j: 1});

  // Convenience getters pointing at the active profile's maps.
  Map<int, String?> get _desktopSlots => _profileSlots[_activeProfile];
  Map<int, int>    get _desktopSpans  => _profileSpans[_activeProfile];

  bool get _isAdmin {
    final role = widget.userInfo['user_role'] as String? ?? '';
    return role == 'admin' || role == 'superadmin';
  }

  List<Map<String, dynamic>> get _visibleWidgets => _availableWidgets
      .where((w) => w['role'] == null || _isAdmin)
      .toList();

  // ── Profile title editing ─────────────────────────────────────────────────
  bool _editingTitle = false;
  final _titleController = TextEditingController();
  final _titleFocusNode  = FocusNode();

  // ── Update check (desktop only) ───────────────────────────────────────────
  _UpdateStatus _updateStatus = _UpdateStatus.checking;
  String? _currentVersion;
  String? _latestVersion;
  String? _downloadUrl;

  // ── Mobile ────────────────────────────────────────────────────────────────
  List<String> _mobileWidgets = [];

  // ── Lifecycle ─────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _titleFocusNode.addListener(_onTitleFocusChange);
    _initializeDashboard();
    _checkForUpdate();
  }

  @override
  void dispose() {
    _titleFocusNode.removeListener(_onTitleFocusChange);
    _titleController.dispose();
    _titleFocusNode.dispose();
    super.dispose();
  }

  void _onTitleFocusChange() {
    if (!_titleFocusNode.hasFocus && _editingTitle) {
      _commitTitleEdit();
    }
  }

  // ── Platform helper ────────────────────────────────────────────────────────

  static bool get _isDesktop =>
      !kIsWeb && (Platform.isWindows || Platform.isMacOS || Platform.isLinux);

  // ── Update check ───────────────────────────────────────────────────────────

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
    const api =
        'https://api.github.com/repos/rubenluz/limsphere/contents/desktop_release';
    try {
      final client = HttpClient();
      final req = await client.getUrl(Uri.parse(api));
      req.headers.set('User-Agent', 'LIMSphere');
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
        final m = RegExp(r'LIMSphere_installer_v(\d+\.\d+\.\d+)').firstMatch(name);
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
    final prefs = await SharedPreferences.getInstance();

    // Migrate legacy single-profile keys → profile 0
    final oldSlots = prefs.getString('dashboard_slots');
    if (oldSlots != null) {
      await prefs.setString('dashboard_slots_0', oldSlots);
      await prefs.remove('dashboard_slots');
    }
    final oldSpans = prefs.getString('dashboard_spans');
    if (oldSpans != null) {
      await prefs.setString('dashboard_spans_0', oldSpans);
      await prefs.remove('dashboard_spans');
    }

    // Load profile titles
    final savedTitles = prefs.getString('dashboard_profile_titles');
    if (savedTitles != null) {
      try {
        final list = List<String>.from(jsonDecode(savedTitles) as List);
        for (int i = 0; i < _kProfileCount && i < list.length; i++) {
          _profileTitles[i] = list[i];
        }
      } catch (_) {}
    }

    // Load each profile's slots and spans
    for (int p = 0; p < _kProfileCount; p++) {
      final savedSlots = prefs.getString('dashboard_slots_$p');
      if (savedSlots != null && savedSlots.isNotEmpty) {
        try {
          final decoded = jsonDecode(savedSlots) as Map<String, dynamic>;
          decoded.forEach((key, value) {
            final index = int.tryParse(key);
            if (index != null) _profileSlots[p][index] = value as String?;
          });
        } catch (_) {
          if (p == 0) _applyDesktopDefaults(0);
        }
      } else if (p == 0) {
        // Profile 0 defaults on first launch
        _applyDesktopDefaults(0);
      }
      // Profiles 1–4 with no saved config start as empty grids.

      final savedSpans = prefs.getString('dashboard_spans_$p');
      if (savedSpans != null && savedSpans.isNotEmpty) {
        try {
          final decoded = jsonDecode(savedSpans) as Map<String, dynamic>;
          decoded.forEach((key, value) {
            final index = int.tryParse(key);
            if (index != null && index < 4) {
              _profileSpans[p][index] = (value as num).toInt();
            }
          });
        } catch (_) {}
      }
    }

    // Mobile widgets
    final savedMobile = prefs.getString('dashboard_mobile_widgets');
    if (savedMobile != null && savedMobile.isNotEmpty) {
      try {
        _mobileWidgets = List<String>.from(jsonDecode(savedMobile) as List);
      } catch (_) {
        _applyMobileDefaults();
      }
    } else {
      _applyMobileDefaults();
    }

    if (mounted) setState(() {});
  }

  void _applyDesktopDefaults(int profile) {
    _profileSlots[profile][0] = 'to_do';           _profileSpans[profile][0] = 2;
    _profileSlots[profile][4] = null;
    _profileSlots[profile][1] = 'next_transfer';   _profileSpans[profile][1] = 1;
    _profileSlots[profile][5] = 'tank_cleaning';
    _profileSlots[profile][2] = 'transfer_status'; _profileSpans[profile][2] = 1;
    _profileSlots[profile][6] = 'fish_by_line';
    _profileSlots[profile][3] = 'in_care';         _profileSpans[profile][3] = 2;
    _profileSlots[profile][7] = null;
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
    await prefs.setString('dashboard_slots_$_activeProfile', jsonEncode(toSave));
  }

  Future<void> _saveDesktopSpans() async {
    final prefs = await SharedPreferences.getInstance();
    final toSave = <String, int>{};
    _desktopSpans.forEach((k, v) => toSave[k.toString()] = v);
    await prefs.setString('dashboard_spans_$_activeProfile', jsonEncode(toSave));
  }

  Future<void> _saveMobileConfig() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('dashboard_mobile_widgets', jsonEncode(_mobileWidgets));
  }

  Future<void> _saveProfileTitles() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('dashboard_profile_titles', jsonEncode(_profileTitles));
  }

  // ── Profile switching & title editing ─────────────────────────────────────

  void _switchProfile(int index) {
    if (index == _activeProfile) return;
    setState(() {
      if (_editingTitle) _editingTitle = false;
      _activeProfile = index;
    });
  }

  void _startTitleEdit() {
    _titleController.text = _profileTitles[_activeProfile];
    setState(() => _editingTitle = true);
    WidgetsBinding.instance.addPostFrameCallback((_) => _titleFocusNode.requestFocus());
  }

  Future<void> _commitTitleEdit() async {
    final newTitle = _titleController.text.trim();
    setState(() {
      if (newTitle.isNotEmpty) _profileTitles[_activeProfile] = newTitle;
      _editingTitle = false;
    });
    await _saveProfileTitles();
  }

  // ── Widget builder ─────────────────────────────────────────────────────────

  Widget _buildWidget(String widgetType) {
    switch (widgetType) {
      case 'next_transfer':        return const NextTransferWidget();
      case 'strains_by_origin':    return const StrainsByOriginWidget();
      case 'strains_by_medium':    return const StrainsByMediumWidget();
      case 'transfer_status':      return const TransferStatusWidget();
      case 'in_care':              return const InCareWidget();
      case 'tank_cleaning':        return const TankCleaningWidget();
      case 'fish_by_line':         return const FishByLineWidget();
      case 'to_do':                return const ToDoWidget();
      case 'transfer_timeline':    return const TransferTimelineWidget();
      case 'cleaning_timeline':    return const TankCleaningTimelineWidget();
      case 'maintenance_overview': return const MaintenanceOverviewWidget();
      case 'breeding_activity':    return const BreedingActivityWidget();
      case 'low_stock':            return const LowStockWidget();
      case 'reagents_by_type':     return const ReagentsByTypeWidget();
      case 'open_requests':        return const OpenRequestsWidget();
      case 'today_reservations':   return const TodayReservationsWidget();
      case 'pending_users':        return const PendingUsersWidget();
      default:                     return const SizedBox.shrink();
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  // DESKTOP
  // ══════════════════════════════════════════════════════════════════════════

  void _showDesktopWidgetPicker(int slotIndex) {
    final hasWidget = _desktopSlots[slotIndex] != null;
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
                if (isTopRow) ...[
                  Row(children: [
                    const Icon(Icons.height, size: 16),
                    const SizedBox(width: 8),
                    const Text('Height:',
                        style: TextStyle(fontWeight: FontWeight.w500, fontSize: 13)),
                    const SizedBox(width: 12),
                    ChoiceChip(
                      label: const Text('1 row'),
                      selected: dialogSpan == 1,
                      onSelected: (v) { if (v) setDs(() => dialogSpan = 1); },
                    ),
                    const SizedBox(width: 8),
                    ChoiceChip(
                      label: const Text('2 rows'),
                      selected: dialogSpan == 2,
                      onSelected: (v) { if (v) setDs(() => dialogSpan = 2); },
                    ),
                  ]),
                  const Divider(height: 16),
                ],
                SizedBox(
                  height: 360,
                  child: ListView(
                    shrinkWrap: true,
                    children: [
                      for (final cat in _widgetCategories) ...[
                        ...() {
                          final ws = _visibleWidgets
                              .where((w) => w['cat'] == cat)
                              .toList();
                          if (ws.isEmpty) return <Widget>[];
                          return [
                            Padding(
                              padding: const EdgeInsets.fromLTRB(4, 12, 4, 2),
                              child: Row(children: [
                                Text(cat.toUpperCase(),
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: 1.0,
                                      color: Theme.of(ctx).colorScheme.outline,
                                    )),
                                const SizedBox(width: 8),
                                Expanded(
                                    child: Divider(
                                        color: Theme.of(ctx).dividerColor,
                                        height: 1)),
                              ]),
                            ),
                            for (final w in ws)
                              ListTile(
                                leading: Icon(w['icon'] as IconData),
                                title: Text(w['name'] as String),
                                selected: _desktopSlots[slotIndex] == w['id'],
                                dense: true,
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
                                        _desktopSlots[slotIndex + 4] = null;
                                      }
                                    }
                                  });
                                  final nav = Navigator.of(ctx);
                                  await _saveDesktopConfig();
                                  if (isTopRow) await _saveDesktopSpans();
                                  nav.pop();
                                },
                              ),
                          ];
                        }(),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
          actions: [
            if (hasWidget && isTopRow && dialogSpan != (_desktopSpans[slotIndex] ?? 1))
              TextButton(
                onPressed: () async {
                  final nav = Navigator.of(ctx);
                  setState(() {
                    _desktopSpans[slotIndex] = dialogSpan;
                    if (dialogSpan == 2) _desktopSlots[slotIndex + 4] = null;
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
                setState(() => _applyDesktopDefaults(_activeProfile));
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

  Widget _buildDesktopGrid() {
    const cols = 4;
    const spacing = 12.0;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: List.generate(cols, (col) {
        final topIdx = col;
        final botIdx = col + 4;
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

  /// Profile selector bar — sits below the toolbar, desktop only.
  Widget _buildProfileSelector() {
    return Container(
      height: 44,
      decoration: BoxDecoration(
        color: context.appSurface2,
        border: Border(bottom: BorderSide(color: context.appBorder)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          // ── Numbered profile buttons ─────────────────────────────────────
          ...List.generate(_kProfileCount, (i) {
            final active = i == _activeProfile;
            return Padding(
              padding: const EdgeInsets.only(right: 6),
              child: GestureDetector(
                onTap: () => _switchProfile(i),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: active ? AppDS.accent : Colors.transparent,
                    border: Border.all(
                      color: active ? AppDS.accent : context.appBorder,
                      width: 1.5,
                    ),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    '${i + 1}',
                    style: GoogleFonts.spaceGrotesk(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: active ? Colors.white : context.appTextSecondary,
                    ),
                  ),
                ),
              ),
            );
          }),
          const SizedBox(width: 8),
          Container(width: 1, height: 20, color: context.appBorder),
          const SizedBox(width: 12),
          // ── Editable profile title ───────────────────────────────────────
          if (_editingTitle)
            SizedBox(
              width: 200,
              height: 30,
              child: TextField(
                controller: _titleController,
                focusNode: _titleFocusNode,
                style: GoogleFonts.spaceGrotesk(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: context.appTextPrimary,
                ),
                cursorColor: AppDS.accent,
                decoration: InputDecoration(
                  isDense: true,
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                  filled: true,
                  fillColor: context.appSurface,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(6),
                    borderSide: BorderSide(color: context.appBorder),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(6),
                    borderSide: BorderSide(color: context.appBorder),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(6),
                    borderSide: const BorderSide(color: AppDS.accent),
                  ),
                ),
                onSubmitted: (_) => _commitTitleEdit(),
              ),
            )
          else
            GestureDetector(
              onTap: _startTitleEdit,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _profileTitles[_activeProfile],
                    style: GoogleFonts.spaceGrotesk(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: context.appTextPrimary,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Icon(Icons.edit_outlined, size: 13, color: context.appTextMuted),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildUpdateButton() {
    switch (_updateStatus) {
      case _UpdateStatus.checking:
        return SizedBox(
          width: 16, height: 16,
          child: CircularProgressIndicator(
              strokeWidth: 2, color: context.appTextSecondary),
        );
      case _UpdateStatus.upToDate:
        return Row(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.check_circle, size: 15, color: AppDS.green),
          const SizedBox(width: 5),
          Text(
            'Application up to date${_currentVersion != null ? ' (v$_currentVersion)' : ''}',
            style: const TextStyle(
                fontSize: 12, color: AppDS.green, fontWeight: FontWeight.w600),
          ),
        ]);
      case _UpdateStatus.updateAvailable:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_currentVersion != null)
              Text('Current: v$_currentVersion',
                  style: TextStyle(fontSize: 11, color: context.appTextMuted)),
            const SizedBox(height: 4),
            TextButton.icon(
              style: TextButton.styleFrom(
                foregroundColor: Colors.white,
                backgroundColor: const Color(0xFF38BDF8),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: _openDownload,
              icon: const Icon(Icons.download_rounded, size: 15),
              label: Text('Download v${_latestVersion ?? ''}',
                  style: const TextStyle(
                      fontSize: 12, fontWeight: FontWeight.w600)),
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
                Icon(Icons.refresh, size: 14, color: context.appTextMuted),
                const SizedBox(width: 4),
                Text('Retry',
                    style: TextStyle(
                        fontSize: 12, color: context.appTextMuted)),
              ]),
            ),
          ),
        );
    }
  }

  Widget _buildToolbar({bool isMobile = false}) {
    return Container(
      height: 56,
      decoration: BoxDecoration(
        color: context.appSurface2,
        border: Border(bottom: BorderSide(color: context.appBorder)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(children: [
        if (isMobile) ...[
          IconButton(
            icon: const Icon(Icons.menu_rounded, size: 20),
            color: context.appTextSecondary,
            tooltip: 'Menu',
            onPressed: openAppDrawer,
          ),
        ],
        const Icon(Icons.space_dashboard_outlined,
            size: 18, color: Color(0xFF6366F1)),
        const SizedBox(width: 8),
        Text('Dashboard',
            style: GoogleFonts.spaceGrotesk(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: context.appTextPrimary)),
        const Spacer(),
        if (_isDesktop) _buildUpdateButton(),
        const SizedBox(width: 12),
        Tooltip(
          message: 'View on GitHub',
          child: InkWell(
            borderRadius: BorderRadius.circular(6),
            onTap: () => launchUrl(
              Uri.parse('https://github.com/rubenluz/limsphere'),
              mode: LaunchMode.externalApplication,
            ),
            child: Padding(
              padding: const EdgeInsets.all(6),
              child: FaIcon(FontAwesomeIcons.github,
                  size: 18, color: context.appTextSecondary),
            ),
          ),
        ),
      ]),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // MOBILE
  // ══════════════════════════════════════════════════════════════════════════

  void _showMobileWidgetPicker() {
    final available = _visibleWidgets
        .where((w) => !_mobileWidgets.contains(w['id']))
        .toList();

    if (available.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('All widgets are already on your dashboard')),
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
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(children: [
              const Text('Add Widget',
                  style:
                      TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
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
            Flexible(
              child: ListView(
                shrinkWrap: true,
                children: [
                  for (final cat in _widgetCategories) ...[
                    ...() {
                      final ws = available
                          .where((w) => w['cat'] == cat)
                          .toList();
                      if (ws.isEmpty) return <Widget>[];
                      return [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(4, 12, 4, 2),
                          child: Row(children: [
                            Text(cat.toUpperCase(),
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 1.0,
                                  color:
                                      Theme.of(ctx).colorScheme.outline,
                                )),
                            const SizedBox(width: 8),
                            Expanded(
                                child: Divider(
                                    color: Theme.of(ctx).dividerColor,
                                    height: 1)),
                          ]),
                        ),
                        for (final w in ws)
                          ListTile(
                            leading: Icon(w['icon'] as IconData),
                            title: Text(w['name'] as String),
                            dense: true,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8)),
                            onTap: () async {
                              final nav = Navigator.of(ctx);
                              setState(() =>
                                  _mobileWidgets.add(w['id'] as String));
                              await _saveMobileConfig();
                              nav.pop();
                            },
                          ),
                      ];
                    }(),
                  ],
                ],
              ),
            ),
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
      itemCount: _mobileWidgets.length + 1,
      onReorder: (oldIndex, newIndex) async {
        if (oldIndex >= _mobileWidgets.length ||
            newIndex > _mobileWidgets.length) { return; }
        setState(() {
          if (newIndex > oldIndex) newIndex--;
          final item = _mobileWidgets.removeAt(oldIndex);
          _mobileWidgets.insert(newIndex, item);
        });
        await _saveMobileConfig();
      },
      itemBuilder: (ctx, i) {
        if (i == _mobileWidgets.length) {
          return ListTile(
            key: const ValueKey('__add__'),
            leading: const Icon(Icons.add_circle_outline),
            title: const Text('Add Widget'),
            onTap: _showMobileWidgetPicker,
          );
        }

        final widgetId = _mobileWidgets[i];
        final meta = _visibleWidgets.firstWhere(
          (w) => w['id'] == widgetId,
          orElse: () =>
              {'id': widgetId, 'name': widgetId, 'icon': Icons.widgets},
        );

        return Padding(
          key: ValueKey(widgetId),
          padding: const EdgeInsets.only(bottom: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
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
                  GestureDetector(
                    onTap: () async {
                      setState(() => _mobileWidgets.removeAt(i));
                      await _saveMobileConfig();
                    },
                    child:
                        Icon(Icons.close, size: 14, color: Colors.grey.shade400),
                  ),
                  const SizedBox(width: 8),
                  Icon(Icons.drag_handle,
                      size: 16, color: Colors.grey.shade400),
                ]),
              ),
              _buildWidget(widgetId),
            ],
          ),
        );
      },
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // TOP-LEVEL VIEW BUILDERS
  // ══════════════════════════════════════════════════════════════════════════

  Widget _buildDesktopView() {
    return Column(
      children: [
        _buildToolbar(),
        _buildProfileSelector(),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (widget.pendingUsers.isNotEmpty)
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
                Expanded(child: _buildDesktopGrid()),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMobileView() {
    return Column(
      children: [
        _buildToolbar(isMobile: true),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (widget.pendingUsers.isNotEmpty)
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
                Expanded(child: _buildMobileList()),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 700;
    return isMobile ? _buildMobileView() : _buildDesktopView();
  }
}
