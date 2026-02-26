import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'widgets/next_transfer_widget.dart';
import 'widgets/strains_by_origin_widget.dart';
import 'widgets/strains_by_medium_widget.dart';
import 'widgets/transfer_status_widget.dart';
import 'widgets/incare_widget.dart';

// All available widgets — add new ones here and they appear in the picker.
const _availableWidgets = [
  {'id': 'next_transfer',    'name': 'Next Transfers',    'icon': Icons.schedule},
  {'id': 'strains_by_origin','name': 'Strains by Origin', 'icon': Icons.pie_chart},
  {'id': 'strains_by_medium','name': 'Strains by Medium', 'icon': Icons.water_drop},
  {'id': 'transfer_status',  'name': 'Transfer Status',   'icon': Icons.warning_amber},
  {'id': 'in_care',          'name': 'In Care',           'icon': Icons.medical_services},
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

class _DashboardPageState extends State<DashboardPage> {
  // Desktop: 16-slot grid (Map<slotIndex, widgetId|null>)
  Map<int, String?> _desktopSlots = {};

  // Mobile: ordered list of widget ids (no empty slots)
  List<String> _mobileWidgets = [];

  @override
  void initState() {
    super.initState();
    _initializeDashboard();
  }

  // ── Init & persistence ─────────────────────────────────────────────────────

  Future<void> _initializeDashboard() async {
    // Desktop defaults
    _desktopSlots = {for (int i = 0; i < 16; i++) i: null};

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
    _desktopSlots[0] = 'next_transfer';
    _desktopSlots[1] = 'strains_by_origin';
    _desktopSlots[2] = 'strains_by_medium';
    _desktopSlots[3] = 'transfer_status';
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
      default:                  return const SizedBox.shrink();
    }
  }

  // ── Desktop: 4×4 grid ──────────────────────────────────────────────────────

  void _showDesktopWidgetPicker(int slotIndex) {
    final hasWidget = _desktopSlots[slotIndex] != null;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Manage Widget'),
        content: SizedBox(
          width: 300,
          child: ListView(
            shrinkWrap: true,
            children: _availableWidgets.map((w) => ListTile(
              leading: Icon(w['icon'] as IconData),
              title: Text(w['name'] as String),
              selected: _desktopSlots[slotIndex] == w['id'],
              onTap: () async {
                setState(() => _desktopSlots[slotIndex] = w['id'] as String);
                await _saveDesktopConfig();
                Navigator.of(ctx).pop();
              },
            )).toList(),
          ),
        ),
        actions: [
          if (hasWidget)
            TextButton.icon(
              icon: const Icon(Icons.delete_outline),
              label: const Text('Remove'),
              onPressed: () async {
                setState(() => _desktopSlots[slotIndex] = null);
                await _saveDesktopConfig();
                Navigator.of(ctx).pop();
              },
            ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
        ],
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
                    color: Colors.black.withOpacity(0.08),
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
    const cellSize = 280.0;
    const spacing = 12.0;
    const gridColumns = 4;
    
    return SingleChildScrollView(
      child: GridView.builder(
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: gridColumns,
          crossAxisSpacing: spacing,
          mainAxisSpacing: spacing,
          childAspectRatio: 1,
        ),
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: 8,
        itemBuilder: (_, i) => SizedBox(
          width: cellSize,
          height: cellSize,
          child: _buildDesktopSlot(i),
        ),
      ),
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
            const Text('Add Widget',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 12),
            ...available.map((w) => ListTile(
              leading: Icon(w['icon'] as IconData),
              title: Text(w['name'] as String),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
              onTap: () async {
                setState(() => _mobileWidgets.add(w['id'] as String));
                await _saveMobileConfig();
                Navigator.of(ctx).pop();
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

  Widget _buildHeader(bool isMobile) {
    final name = widget.userInfo['user_username'] ?? '';
    final role = widget.userInfo['user_role'] ?? '';
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(
        'Welcome back${name.isNotEmpty ? ", ${name.split('@').first}" : ''}!',
        style: const TextStyle(
            fontSize: 22, fontWeight: FontWeight.bold),
      ),
      const SizedBox(height: 2),
      Text(role,
          style: TextStyle(
              color: Colors.grey.shade500, fontSize: 13)),
    ]);
  }

  // ── BUILD ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 700;
    final screenSize = MediaQuery.of(context).size;

    return Padding(
      padding: EdgeInsets.all(isMobile ? 12 : 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(isMobile),
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
              : SingleChildScrollView(
                  child: _buildDesktopGrid(),
                ),
          ),
        ],
      ),
    );
  }
}