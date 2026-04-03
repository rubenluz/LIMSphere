// reservations_page.dart - Equipment/resource reservation system: calendar and
// list views, availability tracking, booking/cancellation.
// Widget and dialog classes in reservations_widgets.dart (part).

import 'package:flutter/material.dart';
import '/theme/module_permission.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:io';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide LocalStorage;
import 'package:table_calendar/table_calendar.dart';
import '/core/data_cache.dart';
import '/theme/theme.dart';
import 'reservation_model.dart';

part 'reservations_widgets.dart';

class ReservationsPage extends StatefulWidget {
  const ReservationsPage({super.key});

  @override
  State<ReservationsPage> createState() => _ReservationsPageState();
}

class _ReservationsPageState extends State<ReservationsPage> {
  List<ReservationModel> _all = [];
  List<ReservationModel> _filtered = [];
  bool _loading = true;
  bool _calendarView = true;
  String _statusFilter = 'all';

  // Calendar state
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;

  // Equipment list for new reservation dialog
  List<Map<String, dynamic>> _equipment = [];

  @override
  void initState() {
    super.initState();
    _selectedDay = DateTime.now();
    _load();
  }

  Future<void> _load() async {
    final cachedRes = await DataCache.read('reservations');
    final cachedEquip = await DataCache.read('equipment_names');
    if (cachedRes != null && cachedEquip != null && mounted) {
      setState(() {
        _all = cachedRes.map<ReservationModel>((r) => ReservationModel.fromMap(Map<String, dynamic>.from(r as Map))).toList();
        _equipment = List<Map<String, dynamic>>.from(cachedEquip);
        _loading = false;
        _applyFilters();
      });
    } else {
      setState(() => _loading = true);
    }
    try {
      final rows = await Supabase.instance.client
          .from('reservations')
          .select()
          .order('reservation_start', ascending: false);

      final equipRows = await Supabase.instance.client
          .from('equipment')
          .select('equipment_id, equipment_name')
          .order('equipment_name');

      await DataCache.write('reservations', rows as List<dynamic>);
      await DataCache.write('equipment_names', equipRows as List<dynamic>);

      if (!mounted) return;
      setState(() {
        _all = rows.map<ReservationModel>((r) => ReservationModel.fromMap(r)).toList();
        _equipment = List<Map<String, dynamic>>.from(equipRows);
        _loading = false;
        _applyFilters();
      });
    } catch (e) {
      if (cachedRes == null && mounted) {
        setState(() => _loading = false);
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Failed to load: $e')));
      }
    }
  }

  void _applyFilters() {
    setState(() {
      _filtered = _all.where((r) {
        if (_statusFilter != 'all' && r.status != _statusFilter) return false;
        return true;
      }).toList();
    });
  }

  List<ReservationModel> _getEventsForDay(DateTime day) {
    return _filtered.where((r) {
      final start = DateTime(r.start.year, r.start.month, r.start.day);
      final end = DateTime(r.end.year, r.end.month, r.end.day);
      final d = DateTime(day.year, day.month, day.day);
      return !d.isBefore(start) && !d.isAfter(end);
    }).toList();
  }

  Future<void> _showNewReservationDialog([ReservationModel? existing]) async {
    if (!context.canEditModule) { context.warnReadOnly(); return; }
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => _ReservationFormDialog(
        existing: existing,
        equipment: _equipment,
        allReservations: _all,
      ),
    );
    if (result == true) _load();
  }

  Future<void> _delete(ReservationModel r) async {
    if (!context.canEditModule) { context.warnReadOnly(); return; }
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: ctx.appSurface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Text('Cancel Reservation',
            style: GoogleFonts.spaceGrotesk(color: ctx.appTextPrimary)),
        content: Text(
            'Delete reservation for "${r.resourceName ?? r.resourceType}"?',
            style: GoogleFonts.spaceGrotesk(color: ctx.appTextSecondary)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text('Cancel',
                  style: GoogleFonts.spaceGrotesk(
                      color: ctx.appTextSecondary))),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text('Delete',
                  style: GoogleFonts.spaceGrotesk(color: AppDS.red))),
        ],
      ),
    );
    if (confirm != true) return;
    try {
      await Supabase.instance.client
          .from('reservations')
          .delete()
          .eq('reservation_id', r.id);
      _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Failed: $e')));
      }
    }
  }

  Future<void> _exportCsv() async {
    final buf = StringBuffer();
    buf.writeln(
        'ID,ResourceType,ResourceName,Start,End,Purpose,Project,Status,Notes');
    for (final r in _filtered) {
      buf.writeln(
          '${r.id},"${r.resourceType}","${r.resourceName ?? ''}","${r.start.toIso8601String()}","${r.end.toIso8601String()}","${r.purpose ?? ''}","${r.project ?? ''}","${r.status}","${r.notes ?? ''}"');
    }
    try {
      final dir = await getDownloadsDirectory() ?? await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/reservations_${DateTime.now().millisecondsSinceEpoch}.csv');
      await file.writeAsString(buf.toString());
      await OpenFilex.open(file.path);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Export failed: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      // ── Toolbar ──────────────────────────────────────────────────────────────
      Container(
        height: 56,
        decoration: BoxDecoration(
          color: context.appSurface2,
          border: Border(bottom: BorderSide(color: context.appBorder)),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(children: [
          if (MediaQuery.of(context).size.width < 700) ...[
            IconButton(
              icon: const Icon(Icons.menu_rounded, size: 20),
              color: context.appTextSecondary,
              tooltip: 'Menu',
              onPressed: () => Scaffold.of(context).openDrawer(),
            ),
          ],
          const Icon(Icons.event_outlined,
              color: Color(0xFFEC4899), size: 18),
          const SizedBox(width: 8),
          Text('Reservations',
              style: GoogleFonts.spaceGrotesk(
                  color: context.appTextPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.w600)),
          const SizedBox(width: 16),
          // View toggle
          Container(
            height: 34,
            decoration: BoxDecoration(
              color: context.appSurface3,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: context.appBorder),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              _ViewToggleBtn(
                icon: Icons.calendar_month_outlined,
                label: 'Calendar',
                active: _calendarView,
                onTap: () => setState(() => _calendarView = true),
              ),
              _ViewToggleBtn(
                icon: Icons.list_outlined,
                label: 'List',
                active: !_calendarView,
                onTap: () => setState(() => _calendarView = false),
              ),
            ]),
          ),
          const SizedBox(width: 12),
          // Status filter
          SizedBox(
            height: 36,
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _statusFilter,
                dropdownColor: context.appSurface,
                style: GoogleFonts.spaceGrotesk(
                    color: context.appTextPrimary, fontSize: 13),
                items: [
                  DropdownMenuItem(
                      value: 'all',
                      child: Text('All Status',
                          style: GoogleFonts.spaceGrotesk(
                              color: context.appTextSecondary, fontSize: 13))),
                  ...ReservationModel.statusOptions.map((s) =>
                      DropdownMenuItem(
                          value: s,
                          child: Text(
                              s[0].toUpperCase() + s.substring(1),
                              style: GoogleFonts.spaceGrotesk(
                                  color: context.appTextPrimary, fontSize: 13)))),
                ],
                onChanged: (v) {
                  _statusFilter = v ?? 'all';
                  _applyFilters();
                },
              ),
            ),
          ),
          const Spacer(),
          Tooltip(
            message: 'Export CSV',
            child: IconButton(
              icon: Icon(Icons.download_outlined,
                  color: context.appTextSecondary, size: 18),
              onPressed: _exportCsv,
            ),
          ),
          const SizedBox(width: 4),
          FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFEC4899),
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
              minimumSize: const Size(0, 36),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () => _showNewReservationDialog(),
            icon: const Icon(Icons.add, size: 16),
            label: Text('New Reservation',
                style: GoogleFonts.spaceGrotesk(fontSize: 13)),
          ),
        ]),
      ),

      // ── Body ─────────────────────────────────────────────────────────────────
      Expanded(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _calendarView
                ? _buildCalendarView(context)
                : _buildListView(context),
      ),
    ]);
  }

  // ── Calendar View ─────────────────────────────────────────────────────────────
  Widget _buildCalendarView(BuildContext context) {
    final eventsForSelected = _selectedDay != null
        ? _getEventsForDay(_selectedDay!)
        : <ReservationModel>[];

    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      // Calendar panel
      Container(
        width: 380,
        decoration: BoxDecoration(
          border: Border(right: BorderSide(color: context.appBorder)),
        ),
        child: TableCalendar<ReservationModel>(
          firstDay: DateTime(2020),
          lastDay: DateTime(2030),
          focusedDay: _focusedDay,
          selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
          onDaySelected: (selectedDay, focusedDay) {
            setState(() {
              _selectedDay = selectedDay;
              _focusedDay = focusedDay;
            });
          },
          eventLoader: _getEventsForDay,
          calendarFormat: CalendarFormat.month,
          availableCalendarFormats: const {CalendarFormat.month: 'Month'},
          calendarStyle: CalendarStyle(
            defaultTextStyle: GoogleFonts.spaceGrotesk(
                color: context.appTextPrimary, fontSize: 13),
            weekendTextStyle: GoogleFonts.spaceGrotesk(
                color: context.appTextSecondary, fontSize: 13),
            outsideDaysVisible: false,
            outsideTextStyle: GoogleFonts.spaceGrotesk(
                color: context.appTextMuted, fontSize: 13),
            todayDecoration: BoxDecoration(
              color: AppDS.accent.withValues(alpha: 0.25),
              shape: BoxShape.circle,
            ),
            todayTextStyle: GoogleFonts.spaceGrotesk(
                color: AppDS.accent,
                fontSize: 13,
                fontWeight: FontWeight.w700),
            selectedDecoration: const BoxDecoration(
              color: Color(0xFFEC4899),
              shape: BoxShape.circle,
            ),
            selectedTextStyle: GoogleFonts.spaceGrotesk(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w700),
            markerDecoration: const BoxDecoration(
              color: Color(0xFFEC4899),
              shape: BoxShape.circle,
            ),
            markerSize: 5,
            cellMargin: const EdgeInsets.all(4),
          ),
          headerStyle: HeaderStyle(
            formatButtonVisible: false,
            titleCentered: true,
            titleTextStyle: GoogleFonts.spaceGrotesk(
                color: context.appTextPrimary,
                fontSize: 15,
                fontWeight: FontWeight.w600),
            leftChevronIcon: Icon(Icons.chevron_left,
                color: context.appTextSecondary),
            rightChevronIcon: Icon(Icons.chevron_right,
                color: context.appTextSecondary),
            decoration: BoxDecoration(
              color: context.appSurface2,
              border: Border(bottom: BorderSide(color: context.appBorder)),
            ),
          ),
          daysOfWeekStyle: DaysOfWeekStyle(
            weekdayStyle: GoogleFonts.spaceGrotesk(
                color: context.appTextMuted,
                fontSize: 11,
                fontWeight: FontWeight.w600),
            weekendStyle: GoogleFonts.spaceGrotesk(
                color: context.appTextMuted,
                fontSize: 11,
                fontWeight: FontWeight.w600),
          ),
          rowHeight: 48,
          calendarBuilders: CalendarBuilders(
            defaultBuilder: (ctx, day, focusedDay) => null,
          ),
        ),
      ),

      // Events panel for selected day
      Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: context.appSurface2,
              border: Border(bottom: BorderSide(color: context.appBorder)),
            ),
            child: Text(
              _selectedDay != null
                  ? '${_selectedDay!.year}-${_selectedDay!.month.toString().padLeft(2, '0')}-${_selectedDay!.day.toString().padLeft(2, '0')} — ${eventsForSelected.length} reservation${eventsForSelected.length == 1 ? '' : 's'}'
                  : 'Select a day',
              style: GoogleFonts.spaceGrotesk(
                  color: context.appTextPrimary,
                  fontSize: 13,
                  fontWeight: FontWeight.w600),
            ),
          ),
          Expanded(
            child: eventsForSelected.isEmpty
                ? Center(
                    child: Text('No reservations on this day.',
                        style: GoogleFonts.spaceGrotesk(
                            color: context.appTextMuted, fontSize: 13)))
                : ListView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: eventsForSelected.length,
                    itemBuilder: (ctx, i) => _ReservationCard(
                      reservation: eventsForSelected[i],
                      onEdit: () =>
                          _showNewReservationDialog(eventsForSelected[i]),
                      onDelete: () => _delete(eventsForSelected[i]),
                    ),
                  ),
          ),
        ]),
      ),
    ]);
  }

  // ── List View ─────────────────────────────────────────────────────────────────
  Widget _buildListView(BuildContext context) {
    final now = DateTime.now();
    final future = _filtered
        .where((r) => r.end.isAfter(now))
        .toList()
      ..sort((a, b) => a.start.compareTo(b.start));
    final past = _filtered
        .where((r) => r.end.isBefore(now))
        .toList()
      ..sort((a, b) => b.start.compareTo(a.start));

    if (_filtered.isEmpty) {
      return Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.event_outlined, size: 48, color: context.appTextMuted),
          const SizedBox(height: 12),
          Text('No reservations found',
              style: GoogleFonts.spaceGrotesk(
                  color: context.appTextMuted, fontSize: 15)),
        ]),
      );
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (future.isNotEmpty) ...[
          _ListSectionHeader(
              'Upcoming & Ongoing (${future.length})'),
          const SizedBox(height: 8),
          ...future.map((r) => _ReservationCard(
                reservation: r,
                onEdit: () => _showNewReservationDialog(r),
                onDelete: () => _delete(r),
              )),
          const SizedBox(height: 16),
        ],
        if (past.isNotEmpty) ...[
          _ListSectionHeader('Past (${past.length})'),
          const SizedBox(height: 8),
          ...past.map((r) => _ReservationCard(
                reservation: r,
                past: true,
                onEdit: () => _showNewReservationDialog(r),
                onDelete: () => _delete(r),
              )),
        ],
      ],
    );
  }
}

