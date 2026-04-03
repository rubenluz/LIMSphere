// tanks_mobile_view.dart — Part of tanks_page.dart.
// Phone-optimised tank map: compact cells showing position only,
// info widgets stacked vertically. Context menu preserved.

part of 'tanks_page.dart';


extension _MobileView on _FishTanksPageState {

  // ── Root layout ────────────────────────────────────────────────────────────
  Widget _buildMobileLayout() {
    final tanks     = _rackTanks;
    final occupied  = tanks.where(_isOccupied).length;
    final totalFish = tanks.fold(0, (s, t) =>
        s + (t.zebraMales ?? 0) + (t.zebraFemales ?? 0) + (t.zebraJuveniles ?? 0));

    return GestureDetector(
      // ignore: invalid_use_of_protected_member
      onTap: () => setState(() => _menuTank = null),
      child: Stack(children: [
        Column(children: [
          _buildMobileToolbar(occupied, totalFish),
          Container(height: 1, color: context.appBorder),
          if (_loading)
            const Expanded(child: Center(child: CircularProgressIndicator()))
          else if (_error != null)
            Expanded(child: Center(child: Text('Error: $_error',
                style: GoogleFonts.spaceGrotesk(color: AppDS.red, fontSize: 13))))
          else
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(12, 14, 12, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    LayoutBuilder(builder: (ctx, box) {
                      return _buildMobileRack(box.maxWidth);
                    }),
                    const SizedBox(height: 12),
                    _buildLegend(),
                    const SizedBox(height: 16),
                    TanksWidgetActiveStocks(rackTanks: _rackTanks),
                    const SizedBox(height: 10),
                    TanksWidgetActiveFishLines(rackTanks: _rackTanks),
                    const SizedBox(height: 10),
                    TanksWidgetCleaningTimeline(
                      events: _cleaningEvents,
                      loading: _cleaningLoading,
                    ),
                  ],
                ),
              ),
            ),
        ]),
        if (_menuTank != null) _buildContextMenu(),
      ]),
    );
  }

  // ── Compact toolbar ────────────────────────────────────────────────────────
  Widget _buildMobileToolbar(int occupied, int totalFish) {
    return Container(
      color: context.appBg,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Row 1: icon + title + rack selector
          Row(children: [
            const Icon(Icons.grid_view_outlined, size: 16, color: AppDS.accent),
            const SizedBox(width: 6),
            Text('Tank Map', style: GoogleFonts.spaceGrotesk(
                fontSize: 15, fontWeight: FontWeight.w600,
                color: context.appTextPrimary)),
            const SizedBox(width: 12),
            if (_racks.length > 1) ...[
              Text('Rack:', style: GoogleFonts.spaceGrotesk(
                  fontSize: 11, color: context.appTextSecondary)),
              const SizedBox(width: 6),
              DropdownButton<String>(
                value: _selectedRack,
                dropdownColor: context.appSurface2,
                underline: const SizedBox(),
                isDense: true,
                style: GoogleFonts.jetBrainsMono(
                    fontSize: 12, fontWeight: FontWeight.w700,
                    color: AppDS.accent),
                items: (_racks.keys.toList()..sort())
                    .map((r) => DropdownMenuItem(value: r, child: Text(r)))
                    .toList(),
                onChanged: (v) {
                  // ignore: invalid_use_of_protected_member
                  if (v != null) setState(() => _selectedRack = v);
                },
              ),
            ] else
              Text(_selectedRack, style: GoogleFonts.jetBrainsMono(
                  fontSize: 12, fontWeight: FontWeight.w700, color: AppDS.accent)),
            const Spacer(),
            PopupMenuButton<String>(
              tooltip: 'Rack options',
              offset: const Offset(0, 32),
              color: context.appSurface2,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                  side: BorderSide(color: context.appBorder2)),
              onSelected: (v) {
                if (v == 'add') _showAddRackDialog();
                if (v == 'delete') _showDeleteRackDialog();
              },
              itemBuilder: (_) => [
                PopupMenuItem(
                    value: 'add',
                    child: Row(children: [
                      const Icon(Icons.add, size: 16, color: AppDS.accent),
                      const SizedBox(width: 8),
                      Text('Add Rack', style: GoogleFonts.spaceGrotesk(
                          fontSize: 13, color: context.appTextPrimary)),
                    ])),
                PopupMenuItem(
                    value: 'delete',
                    enabled: _racks.length > 1,
                    child: Row(children: [
                      Icon(Icons.delete_outline, size: 16,
                          color: _racks.length > 1 ? AppDS.red : context.appTextMuted),
                      const SizedBox(width: 8),
                      Text('Delete $_selectedRack',
                          style: GoogleFonts.spaceGrotesk(
                              fontSize: 13,
                              color: _racks.length > 1 ? AppDS.red : context.appTextMuted)),
                    ])),
              ],
              icon: Icon(Icons.more_vert, size: 18, color: context.appTextSecondary),
            ),
          ]),
          const SizedBox(height: 6),
          // Row 2: summary chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(children: [
              _chip('$occupied occupied', AppDS.green),
              const SizedBox(width: 6),
              _chip('$totalFish fish', AppDS.green),
            ]),
          ),
        ],
      ),
    );
  }

  // ── Compact rack grid ──────────────────────────────────────────────────────
  static const double _mLabelW = 24.0;
  static const double _mGap    = 2.0;

  Widget _buildMobileRack(double availW) {
    final rows       = _byRow;
    final sortedKeys = rows.keys.toList()..sort();

    final innerW  = availW - _mLabelW - 8; // 8 = SizedBox between label and cells
    final cellW15 = innerW / _rowACount;
    final cellW35 = innerW / _rowBECount;

    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: context.isDark ? AppDS.surface2 : const Color(0xFFEFF6FF),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: context.appBorder2, width: 1.5),
        boxShadow: [BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 10, offset: const Offset(0, 3))],
      ),
      child: Column(
        children: sortedKeys.map((rowIdx) {
          final isTop = rowIdx == 0;
          final cellW = isTop ? cellW15 : cellW35;
          // Cell height proportional to width, clamped to be usable
          final cellH = (cellW * (isTop ? 1.1 : 1.0)).clamp(18.0, 40.0);
          return Padding(
            padding: EdgeInsets.only(bottom: isTop ? 6.0 : 3.0),
            child: _buildMobileRow(rowIdx, rows[rowIdx]!, isTop, cellW, cellH),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildMobileRow(
      int rowIdx, List<ZebrafishTank> tanks,
      bool isTop, double cellW, double cellH) {
    final label = _rowLabels[rowIdx];

    return SizedBox(
      height: cellH,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Row label
          SizedBox(
            width: _mLabelW,
            child: Center(
              child: Container(
                width: 18, height: 18,
                decoration: BoxDecoration(
                    color: context.appSurface3,
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: context.appBorder)),
                child: Center(child: Text(label,
                    style: GoogleFonts.jetBrainsMono(
                        fontSize: 9, fontWeight: FontWeight.w700,
                        color: context.appTextPrimary))),
              ),
            ),
          ),
          const SizedBox(width: 8),
          // Tank cells
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: () {
                final widgets = <Widget>[];
                bool skipNext = false;
                for (final t in tanks) {
                  if (skipNext) { skipNext = false; continue; }
                  widgets.add(Expanded(
                    flex: t.isEightLiter ? 2 : 1,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: _mGap),
                      child: _mobileTankCell(t),
                    ),
                  ));
                  if (t.isEightLiter) skipNext = true;
                }
                return widgets;
              }(),
            ),
          ),
        ],
      ),
    );
  }

  // ── Minimal tank cell (position only) ─────────────────────────────────────
  Widget _mobileTankCell(ZebrafishTank tank) {
    final occupied = _isOccupied(tank);
    final hasFish  = _hasFish(tank);
    final isSent   = _isSentinel(tank);

    final Color bg, border;
    if (isSent) {
      bg     = AppDS.pink.withValues(alpha: 0.22);
      border = AppDS.pink.withValues(alpha: 0.80);
    } else {
      switch (tank.zebraStatus) {
        case 'quarantine':
          bg = AppDS.yellow.withValues(alpha: 0.22);
          border = AppDS.yellow.withValues(alpha: 0.75);
          break;
        case 'retired':
          bg = AppDS.red.withValues(alpha: 0.12);
          border = AppDS.red.withValues(alpha: 0.55);
          break;
        case 'active':
          if (hasFish) {
            bg = AppDS.green.withValues(alpha: 0.30);
            border = AppDS.green.withValues(alpha: 0.65);
          } else {
            bg = AppDS.accent.withValues(alpha: 0.12);
            border = AppDS.accent.withValues(alpha: 0.40);
          }
          break;
        default:
          bg = (context.isDark ? AppDS.surface3 : Colors.white).withValues(alpha: 0.80);
          border = const Color(0xFFBDD4E8);
      }
    }

    final Color healthDot = switch (tank.zebraHealthStatus) {
      'sick'        => AppDS.red,
      'treatment'   => AppDS.orange,
      'observation' => AppDS.yellow,
      _             => AppDS.green,
    };

    final colLabel = tank.zebraColumn ?? '';

    return GestureDetector(
      onTapUp:          (d) => _showMenu(tank, d.globalPosition),
      onSecondaryTapUp: (d) => _showMenu(tank, d.globalPosition),
      child: Tooltip(
        message: _tooltip(tank),
        preferBelow: false,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(3),
            border: Border.all(
                color: border,
                width: (occupied || isSent) ? 1.5 : 1)),
          child: Stack(clipBehavior: Clip.hardEdge, children: [
            // Column number — centred
            Center(
              child: Text(colLabel,
                  style: GoogleFonts.jetBrainsMono(
                      fontSize: 8,
                      fontWeight: occupied ? FontWeight.w700 : FontWeight.normal,
                      color: occupied
                          ? const Color(0xFF0F172A)
                          : const Color(0xFFB0CADA)),
                  overflow: TextOverflow.clip),
            ),
            // Health dot (bottom-right)
            if (occupied)
              Positioned(bottom: 1, right: 1,
                  child: Container(width: 4, height: 4,
                      decoration: BoxDecoration(
                          color: healthDot, shape: BoxShape.circle))),
            // Sentinel dot (top-left)
            if (isSent)
              Positioned(top: 1, left: 1,
                  child: Container(width: 4, height: 4,
                      decoration: const BoxDecoration(
                          color: AppDS.pink, shape: BoxShape.circle))),
          ]),
        ),
      ),
    );
  }
}
