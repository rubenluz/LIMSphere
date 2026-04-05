// water_qc_mobile_view.dart — Phone layout for WaterQcPage.
// Maintenance items displayed as vertical cards.
// QC records as cards in a single page-level CustomScrollView (no nested scroll).

part of 'water_qc_page.dart';

extension _MobileView on _WaterQcPageState {

  // ── Root layout ────────────────────────────────────────────────────────────

  Widget _buildMobileLayout() {
    return Column(
      children: [
        _buildMobileToolbar(),
        if (_showFilters) _buildMobileFilterPanel(),
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _error != null
                  ? Center(
                      child: Text('Error: $_error',
                          style: GoogleFonts.spaceGrotesk(
                              color: AppDS.red, fontSize: 13)))
                  : CustomScrollView(
                      slivers: [
                        SliverToBoxAdapter(
                          child: _buildMobileMaintSection(),
                        ),
                        SliverToBoxAdapter(
                          child: _buildMobileAddButton(),
                        ),
                        if (_filteredRows.isEmpty)
                          SliverToBoxAdapter(
                            child: Padding(
                              padding: const EdgeInsets.all(32),
                              child: Center(
                                child: Text('No records',
                                    style: GoogleFonts.spaceGrotesk(
                                        color: context.appTextMuted,
                                        fontSize: 13)),
                              ),
                            ),
                          )
                        else
                          SliverPadding(
                            padding: const EdgeInsets.fromLTRB(12, 0, 12, 24),
                            sliver: SliverList(
                              delegate: SliverChildBuilderDelegate(
                                (_, i) => _buildMobileQcCard(
                                    _filteredRows[i], i),
                                childCount: _filteredRows.length,
                              ),
                            ),
                          ),
                      ],
                    ),
        ),
      ],
    );
  }

  // ── Mobile toolbar ─────────────────────────────────────────────────────────

  Widget _buildMobileToolbar() {
    return Container(
      decoration: BoxDecoration(
        color: context.appSurface2,
        border: Border(bottom: BorderSide(color: context.appBorder)),
      ),
      padding: const EdgeInsets.fromLTRB(4, 0, 8, 0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(children: [
            IconButton(
              icon: const Icon(Icons.menu_rounded, size: 20),
              color: context.appTextSecondary,
              tooltip: 'Menu',
              onPressed: () => Scaffold.of(context).openDrawer(),
            ),
            const Icon(Icons.water_drop_outlined,
                size: 16, color: _pageAccent),
            const SizedBox(width: 6),
            Text('Water QC',
                style: GoogleFonts.spaceGrotesk(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: context.appTextPrimary)),
            const Spacer(),
            // Filter toggle with active dot
            Stack(children: [
              IconButton(
                icon: Icon(Icons.tune,
                    size: 18,
                    color: _showFilters
                        ? _pageAccent
                        : context.appTextSecondary),
                onPressed: () =>
                    // ignore: invalid_use_of_protected_member
                    setState(() => _showFilters = !_showFilters),
              ),
              if (_hasActiveFilter)
                Positioned(
                  right: 6,
                  top: 6,
                  child: Container(
                    width: 7,
                    height: 7,
                    decoration: const BoxDecoration(
                        color: _pageAccent, shape: BoxShape.circle),
                  ),
                ),
            ]),
            PopupMenuButton<String>(
              icon: Icon(Icons.more_vert,
                  color: context.appTextSecondary, size: 20),
              tooltip: 'More options',
              offset: const Offset(0, 36),
              color: context.appSurface2,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                  side: BorderSide(color: context.appBorder2)),
              onSelected: (v) {
                if (v == 'export') _exportCsv();
                if (v == 'add') _addRowForDate();
              },
              itemBuilder: (_) => [
                PopupMenuItem(
                  value: 'export',
                  child: Row(children: [
                    Icon(Icons.download_outlined,
                        size: 16, color: context.appTextSecondary),
                    const SizedBox(width: 10),
                    Text('Export CSV',
                        style: GoogleFonts.spaceGrotesk(
                            fontSize: 13,
                            color: context.appTextPrimary)),
                  ]),
                ),
                PopupMenuItem(
                  value: 'add',
                  child: Row(children: [
                    const Icon(Icons.add, size: 16, color: AppDS.accent),
                    const SizedBox(width: 10),
                    Text('Add QC Record',
                        style: GoogleFonts.spaceGrotesk(
                            fontSize: 13, color: AppDS.accent)),
                  ]),
                ),
              ],
            ),
          ]),
          // Search bar
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
            child: SizedBox(
              height: 36,
              child: TextField(
                controller: _searchCtrl,
                // ignore: invalid_use_of_protected_member
                onChanged: (_) => setState(() {}),
                style: GoogleFonts.spaceGrotesk(
                    color: context.appTextPrimary, fontSize: 13),
                decoration: InputDecoration(
                  hintText: 'Search records…',
                  hintStyle: GoogleFonts.spaceGrotesk(
                      color: context.appTextMuted, fontSize: 13),
                  prefixIcon: Icon(Icons.search,
                      color: context.appTextMuted, size: 16),
                  suffixIcon: _searchCtrl.text.isNotEmpty
                      ? IconButton(
                          icon: Icon(Icons.clear,
                              size: 14, color: context.appTextMuted),
                          onPressed: () =>
                              // ignore: invalid_use_of_protected_member
                              setState(() => _searchCtrl.clear()))
                      : null,
                  filled: true,
                  fillColor: context.appSurface3,
                  contentPadding: EdgeInsets.zero,
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide:
                          BorderSide(color: context.appBorder)),
                  enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide:
                          BorderSide(color: context.appBorder)),
                  focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide:
                          const BorderSide(color: _pageAccent)),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Mobile filter panel ────────────────────────────────────────────────────

  Widget _buildMobileFilterPanel() {
    return Container(
      decoration: BoxDecoration(
        color: context.appSurface,
        border: Border(bottom: BorderSide(color: context.appBorder)),
      ),
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
      child: Row(children: [
        Text('Show:',
            style: GoogleFonts.spaceGrotesk(
                color: context.appTextMuted,
                fontSize: 11,
                fontWeight: FontWeight.w600)),
        const SizedBox(width: 10),
        Wrap(spacing: 6, children: [
          _filterChip('All', 'all', null),
          _filterChip('Out of range', 'out_of_range', AppDS.red),
          _filterChip('Has incidents', 'has_incidents', AppDS.orange),
        ]),
      ]),
    );
  }

  // ── Maintenance section (mobile) ───────────────────────────────────────────

  Widget _buildMobileMaintSection() {
    final now = DateTime.now();
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header row
          Row(children: [
            const Icon(Icons.build_circle_outlined,
                size: 15, color: _pageAccent),
            const SizedBox(width: 6),
            Text('Maintenance',
                style: GoogleFonts.spaceGrotesk(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: context.appTextPrimary)),
          ]),
          const SizedBox(height: 8),
          // Quality limits
          _buildMobileThresholds(),
          const SizedBox(height: 8),
          // Maintenance cards grid
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 8,
            mainAxisSpacing: 8,
            childAspectRatio: 2.1,
            children: _maintKeys
                .map((k) => _buildMobileMaintCard(k, now))
                .toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildMobileThresholds() {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: context.appSurface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: context.appBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Quality limits',
              style: GoogleFonts.spaceGrotesk(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: context.appTextMuted)),
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            runSpacing: 4,
            children: _thresholdDefs.map((def) {
              final key = def.$1;
              final label = def.$2;
              final unit = def.$3;
              final hasMin = def.$4;
              final t = _thresholds[key];
              final min = t?['minValue'] as double?;
              final set = t?['setVal'] as double?;
              final max = t?['maxValue'] as double?;
              final isInt = _intCols.contains(key);
              String fmt(double v) {
                if (isInt) return v.round().toString();
                return v == v.roundToDouble()
                    ? v.toInt().toString()
                    : v.toStringAsFixed(1);
              }

              final String display;
              final suffix = unit.isNotEmpty ? ' $unit' : '';
              if (min != null && set != null && max != null) {
                display = '$label: ${fmt(min)}–${fmt(set)}–${fmt(max)}$suffix';
              } else if (min != null && max != null) {
                display = '$label: ${fmt(min)}–${fmt(max)}$suffix';
              } else if (set != null) {
                display = '$label: ${fmt(set)}$suffix';
              } else if (max != null) {
                display = '$label: ≤${fmt(max)}$suffix';
              } else if (min != null) {
                display = '$label: ≥${fmt(min)}$suffix';
              } else {
                display = '$label: —';
              }
              final hasValue = min != null || max != null;

              return GestureDetector(
                onTap: () => _editThreshold(key, label, hasMin),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: hasValue
                        ? _pageAccent.withValues(alpha: 0.08)
                        : context.appSurface2,
                    borderRadius: BorderRadius.circular(5),
                    border: Border.all(
                      color: hasValue
                          ? _pageAccent.withValues(alpha: 0.35)
                          : context.appBorder,
                    ),
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Text(display,
                        style: GoogleFonts.spaceGrotesk(
                            fontSize: 10,
                            color: hasValue
                                ? context.appTextPrimary
                                : context.appTextMuted)),
                    const SizedBox(width: 4),
                    Icon(Icons.edit_outlined,
                        size: 10, color: context.appTextMuted),
                  ]),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildMobileMaintCard(String key, DateTime now) {
    final label = _maintLabels[key] ?? key;
    final lastDate = _maint[key]?['lastDone'] as DateTime?;
    final optimalDays = (_maint[key]?['optimalDays'] as int?) ?? 30;

    Color badge = context.appTextMuted;
    String badgeStr = '—';
    String lastStr = '—';

    if (lastDate != null) {
      lastStr = fmtDate(lastDate);
      final nextDate = lastDate.add(Duration(days: optimalDays));
      final daysLeft = nextDate.difference(now).inDays;
      if (daysLeft < 0) {
        badge = AppDS.red;
        badgeStr = '${daysLeft.abs()}d overdue';
      } else if (daysLeft <= 7) {
        badge = AppDS.yellow;
        badgeStr = daysLeft == 0 ? 'today' : 'in ${daysLeft}d';
      } else {
        badge = AppDS.green;
        badgeStr = 'in ${daysLeft}d';
      }
    } else {
      badge = AppDS.red;
      badgeStr = 'never done';
    }

    return GestureDetector(
      onTap: () => _editMaintLastDone(key),
      child: Container(
        padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
        decoration: BoxDecoration(
          color: context.appSurface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: context.appBorder),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.spaceGrotesk(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: context.appTextSecondary)),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: badge.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(badgeStr,
                      style: GoogleFonts.spaceGrotesk(
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                          color: badge)),
                ),
              ],
            ),
            Row(children: [
              Icon(Icons.calendar_today_outlined,
                  size: 10, color: context.appTextMuted),
              const SizedBox(width: 4),
              Text(lastStr,
                  style: GoogleFonts.jetBrainsMono(
                      fontSize: 10,
                      color: lastDate != null
                          ? context.appTextSecondary
                          : context.appTextMuted)),
              const Spacer(),
              Text('$optimalDays d',
                  style: GoogleFonts.jetBrainsMono(
                      fontSize: 10, color: context.appTextMuted)),
            ]),
          ],
        ),
      ),
    );
  }

  // ── Add next record button ─────────────────────────────────────────────────

  Widget _buildMobileAddButton() {
    DateTime nextDate;
    if (_rows.isEmpty) {
      nextDate = DateTime.now();
    } else {
      final latestStr = _rows[0]['record_date']?.toString();
      final latest =
          latestStr != null ? DateTime.tryParse(latestStr) : null;
      nextDate = (latest ?? DateTime.now()).add(const Duration(days: 1));
    }
    final label = fmtDate(nextDate);

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            '${_filteredRows.length} record${_filteredRows.length == 1 ? '' : 's'}',
            style: GoogleFonts.spaceGrotesk(
                fontSize: 11, color: context.appTextMuted),
          ),
          InkWell(
            onTap: _addNextRow,
            borderRadius: BorderRadius.circular(8),
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: _pageAccent.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                    color: _pageAccent.withValues(alpha: 0.35)),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.add_circle_outline,
                    size: 14, color: _pageAccent),
                const SizedBox(width: 6),
                Text('Add $label',
                    style: GoogleFonts.spaceGrotesk(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: _pageAccent)),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  // ── QC record card ─────────────────────────────────────────────────────────

  Widget _buildMobileQcCard(Map<String, dynamic> row, int i) {
    final hasIncident =
        (row['incidents']?.toString().trim() ?? '').isNotEmpty;
    final hasObs =
        (row['observations']?.toString().trim() ?? '').isNotEmpty;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: context.appSurface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: hasIncident
              ? AppDS.red.withValues(alpha: 0.4)
              : context.appBorder,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Card header: date + delete
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: context.appSurface2,
              borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(7)),
            ),
            child: Row(children: [
              const Icon(Icons.calendar_today_outlined,
                  size: 12, color: _pageAccent),
              const SizedBox(width: 6),
              Text(row['record_date']?.toString() ?? '—',
                  style: GoogleFonts.jetBrainsMono(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: context.appTextPrimary)),
              const Spacer(),
              if (hasIncident)
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 6, vertical: 2),
                  margin: const EdgeInsets.only(right: 8),
                  decoration: BoxDecoration(
                    color: AppDS.red.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text('Incident',
                      style: GoogleFonts.spaceGrotesk(
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                          color: AppDS.red)),
                ),
              GestureDetector(
                onTap: () => _deleteRow(row),
                child: Icon(Icons.delete_outline,
                    size: 16, color: context.appTextMuted),
              ),
            ]),
          ),
          // Metrics grid
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
            child: _buildMobileMetricsGrid(row),
          ),
          // Incidents (if any)
          if (hasIncident)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 4, 12, 4),
              child: _buildMobileLabelRow(
                  Icons.warning_amber_outlined,
                  AppDS.orange,
                  'Incident:',
                  row['incidents'].toString()),
            ),
          // Observations (if any)
          if (hasObs)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 2, 12, 4),
              child: _buildMobileLabelRow(
                  Icons.notes_outlined,
                  context.appTextMuted,
                  'Obs:',
                  row['observations'].toString()),
            ),
          const SizedBox(height: 4),
          // Edit button
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
            child: GestureDetector(
              onTap: () => _showMobileEditSheet(row),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 6),
                decoration: BoxDecoration(
                  color: context.appSurface3,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: context.appBorder),
                ),
                child: Center(
                  child: Text('Edit record',
                      style: GoogleFonts.spaceGrotesk(
                          fontSize: 11,
                          color: context.appTextSecondary)),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMobileMetricsGrid(Map<String, dynamic> row) {
    const metrics = [
      ('ph', 'pH'),
      ('conductivity', 'Cond.'),
      ('temperature', 'Temp °C'),
      ('nitrates', 'NO₃⁻'),
      ('nitrites', 'NO₂⁻'),
      ('hardness_dkh', 'Hard. dKH'),
    ];

    return Wrap(
      spacing: 8,
      runSpacing: 6,
      children: metrics.map((m) {
        final key = m.$1;
        final label = m.$2;
        final val = row[key];
        final outOfRange = _isOutOfRange(key, val);
        final isInt = _intCols.contains(key);

        String display = '—';
        if (val != null) {
          if (isInt) {
            final n = double.tryParse(val.toString());
            display = n != null ? n.round().toString() : val.toString();
          } else {
            display = val.toString();
          }
        }

        return Container(
          padding:
              const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: outOfRange
                ? AppDS.red.withValues(alpha: 0.10)
                : context.appSurface2,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color: outOfRange
                  ? AppDS.red.withValues(alpha: 0.35)
                  : context.appBorder,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(label,
                  style: GoogleFonts.spaceGrotesk(
                      fontSize: 9,
                      color: context.appTextMuted,
                      fontWeight: FontWeight.w600)),
              const SizedBox(height: 1),
              Text(display,
                  style: GoogleFonts.jetBrainsMono(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: outOfRange
                          ? AppDS.red
                          : (val == null
                              ? context.appTextMuted
                              : context.appTextPrimary))),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildMobileLabelRow(
      IconData icon, Color color, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 12, color: color),
        const SizedBox(width: 5),
        Text(label,
            style: GoogleFonts.spaceGrotesk(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: color)),
        const SizedBox(width: 4),
        Expanded(
          child: Text(value,
              style: GoogleFonts.spaceGrotesk(
                  fontSize: 11, color: context.appTextSecondary)),
        ),
      ],
    );
  }

  // ── Mobile edit bottom sheet ───────────────────────────────────────────────

  void _showMobileEditSheet(Map<String, dynamic> row) {
    if (!context.canEditModule) {
      context.warnReadOnly();
      return;
    }

    final editableFields = [
      ('ph', 'pH', 'num'),
      ('conductivity', 'Conductivity (µS/cm)', 'num'),
      ('temperature', 'Temp (°C)', 'num'),
      ('nitrates', 'NO₃⁻ (mg/L)', 'num'),
      ('nitrites', 'NO₂⁻ (mg/L)', 'num'),
      ('hardness_dkh', 'Hardness (dKH)', 'num'),
      ('incidents', 'Incidents', 'text'),
      ('observations', 'Observations', 'text'),
    ];

    final controllers = {
      for (final f in editableFields)
        f.$1: TextEditingController(text: row[f.$1]?.toString() ?? '')
    };

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: context.appSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.85,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (_, sc) => Column(
          children: [
            // Handle
            Container(
              margin: const EdgeInsets.only(top: 10, bottom: 4),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: context.appBorder,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(children: [
                const Icon(Icons.edit_outlined,
                    size: 15, color: _pageAccent),
                const SizedBox(width: 8),
                Text(
                  'Edit — ${row['record_date'] ?? ''}',
                  style: GoogleFonts.spaceGrotesk(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: context.appTextPrimary),
                ),
              ]),
            ),
            Divider(height: 1, color: context.appBorder),
            Expanded(
              child: ListView(
                controller: sc,
                padding: EdgeInsets.fromLTRB(
                    16,
                    12,
                    16,
                    MediaQuery.of(ctx).viewInsets.bottom + 16),
                children: [
                  ...editableFields.map((f) {
                    final key = f.$1;
                    final label = f.$2;
                    final type = f.$3;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(label,
                              style: GoogleFonts.spaceGrotesk(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: context.appTextMuted)),
                          const SizedBox(height: 4),
                          TextField(
                            controller: controllers[key],
                            keyboardType: type == 'num'
                                ? const TextInputType.numberWithOptions(
                                    decimal: true)
                                : TextInputType.multiline,
                            maxLines: type == 'text' ? 3 : 1,
                            style: GoogleFonts.jetBrainsMono(
                                fontSize: 13,
                                color: context.appTextPrimary),
                            decoration: InputDecoration(
                              isDense: true,
                              filled: true,
                              fillColor: context.appSurface2,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide:
                                    BorderSide(color: context.appBorder),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide:
                                    BorderSide(color: context.appBorder),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: const BorderSide(
                                    color: _pageAccent, width: 1.5),
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 10),
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                  // Maintenance dates section
                  Divider(color: context.appBorder),
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Text('Maintenance dates',
                        style: GoogleFonts.spaceGrotesk(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: context.appTextMuted)),
                  ),
                  ...(_maintKeys.map((k) {
                    final label = _maintLabels[k] ?? k;
                    final val = row[k];
                    final display = (val != null &&
                            val.toString().trim().isNotEmpty)
                        ? val.toString()
                        : 'Not set';
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: GestureDetector(
                        onTap: () async {
                          Navigator.pop(ctx);
                          await _pickMaintDate(row, k);
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 10),
                          decoration: BoxDecoration(
                            color: context.appSurface2,
                            borderRadius: BorderRadius.circular(8),
                            border:
                                Border.all(color: context.appBorder),
                          ),
                          child: Row(children: [
                            Expanded(
                              child: Text(label,
                                  style: GoogleFonts.spaceGrotesk(
                                      fontSize: 12,
                                      color: context.appTextSecondary)),
                            ),
                            Text(display,
                                style: GoogleFonts.jetBrainsMono(
                                    fontSize: 12,
                                    color: val != null &&
                                            val
                                                .toString()
                                                .trim()
                                                .isNotEmpty
                                        ? const Color(0xFF15803D)
                                        : context.appTextMuted)),
                            const SizedBox(width: 6),
                            Icon(Icons.edit_calendar_outlined,
                                size: 14, color: context.appTextMuted),
                          ]),
                        ),
                      ),
                    );
                  })),
                  const SizedBox(height: 8),
                  // Save button
                  FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: _pageAccent,
                      foregroundColor: Colors.white,
                      minimumSize: const Size(double.infinity, 44),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                      textStyle: GoogleFonts.spaceGrotesk(
                          fontSize: 14, fontWeight: FontWeight.w600),
                    ),
                    onPressed: () {
                      Navigator.pop(ctx);
                      _saveMobileEdit(row, controllers, editableFields);
                    },
                    child: const Text('Save'),
                  ),
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: Text('Cancel',
                        style: GoogleFonts.spaceGrotesk(
                            color: context.appTextMuted)),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    ).then((_) {
      for (final c in controllers.values) {
        c.dispose();
      }
    });
  }

  void _saveMobileEdit(
    Map<String, dynamic> row,
    Map<String, TextEditingController> controllers,
    List<(String, String, String)> fields,
  ) {
    final updates = <String, dynamic>{};
    for (final f in fields) {
      final key = f.$1;
      final type = f.$3;
      final raw = controllers[key]!.text.trim();
      if (type == 'num') {
        updates[key] = raw.isEmpty
            ? null
            : double.tryParse(raw.replaceAll(',', '.'));
      } else {
        updates[key] = raw.isEmpty ? null : raw;
      }
    }

    final ri = _rows.indexWhere((r) => r['id'] == row['id']);
    // ignore: invalid_use_of_protected_member
    if (ri >= 0) setState(() => _rows[ri] = {..._rows[ri], ...updates});

    Supabase.instance.client
        .from('water_qc')
        .update(updates)
        .eq('id', row['id'] as int)
        .then((_) {})
        .catchError((_) {
      if (mounted) _load();
    });
  }
}
