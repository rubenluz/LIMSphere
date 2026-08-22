import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:latlong2/latlong.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '/theme/module_permission.dart';
import '/theme/theme.dart';
import '../samples/sample_detail_page.dart';
import '../strains/strain_detail_page.dart';
import 'culture_map_data.dart';
import 'culture_map_layers.dart';

enum _MapContent { all, samples, strains }

class CultureMapPage extends StatefulWidget {
  final String initialQuery;
  final bool strainsOnly;
  final bool samplesOnly;
  final bool showBackButton;

  const CultureMapPage({
    super.key,
    this.initialQuery = '',
    this.strainsOnly = false,
    this.samplesOnly = false,
    this.showBackButton = false,
  }) : assert(!strainsOnly || !samplesOnly);

  @override
  State<CultureMapPage> createState() => _CultureMapPageState();
}

class _CultureMapPageState extends State<CultureMapPage> {
  static const _sampleColor = Color(0xFF3B82F6);
  static const _strainColor = Color(0xFF10B981);

  final _mapController = MapController();
  late final TextEditingController _searchController;
  List<CultureMapPoint> _points = [];
  int _sampleCount = 0;
  int _strainCount = 0;
  bool _loading = true;
  String? _error;
  late String _query;
  late _MapContent _content;
  CultureBaseMap _baseMap = CultureBaseMap.street;
  CultureMapPoint? _selected;

  List<CultureMapPoint> get _visiblePoints {
    final visible = <CultureMapPoint>[];
    for (final point in _points) {
      switch (_content) {
        case _MapContent.samples:
          if (point.sampleMatches(_query)) visible.add(point);
        case _MapContent.strains:
          final strains = point.matchingStrains(_query);
          if (strains.isNotEmpty) visible.add(point.withStrains(strains));
        case _MapContent.all:
          if (point.sampleMatches(_query)) {
            visible.add(point);
          } else {
            final strains = point.matchingStrains(_query);
            if (strains.isNotEmpty) visible.add(point.withStrains(strains));
          }
      }
    }
    return visible;
  }

  int get _mappedStrainCount =>
      _points.fold(0, (total, point) => total + point.strains.length);

  int get _visibleStrainCount =>
      _visiblePoints.fold(0, (total, point) => total + point.strains.length);

  @override
  void initState() {
    super.initState();
    _query = widget.initialQuery.trim();
    _content = widget.strainsOnly
        ? _MapContent.strains
        : widget.samplesOnly
        ? _MapContent.samples
        : _MapContent.all;
    _searchController = TextEditingController(text: _query);
    _load();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _mapController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    if (mounted) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final results = await Future.wait([
        Supabase.instance.client
            .from('samples')
            .select('''
          sample_id, sample_code, sample_rebeca, sample_ccpi, sample_date,
          sample_collector, sample_country, sample_archipelago, sample_island,
          sample_region, sample_municipality, sample_parish, sample_local,
          sample_gps, sample_latitude, sample_longitude, sample_altitude_m,
          sample_habitat_type, sample_substrate
        ''')
            .order('sample_code'),
        Supabase.instance.client
            .from('strains')
            .select('''
          strain_id, strain_code, strain_sample_code, strain_status,
          strain_organism_type, strain_genus, strain_species,
          strain_scientific_name
        ''')
            .order('strain_code'),
      ]);
      final samples = (results[0] as List)
          .map((row) => Map<String, dynamic>.from(row as Map))
          .toList();
      final strains = (results[1] as List)
          .map((row) => Map<String, dynamic>.from(row as Map))
          .toList();
      if (!mounted) return;
      setState(() {
        _sampleCount = samples.length;
        _strainCount = strains.length;
        _points = buildCultureMapPoints(samples: samples, strains: strains);
        _loading = false;
        _selected = null;
      });
      WidgetsBinding.instance.addPostFrameCallback((_) => _fitVisible());
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = error.toString();
      });
    }
  }

  void _applyViewChange(VoidCallback change) {
    setState(() {
      change();
      if (_selected != null) {
        final selectedId = _selected!.sampleId;
        CultureMapPoint? replacement;
        for (final point in _visiblePoints) {
          if (point.sampleId == selectedId) {
            replacement = point;
            break;
          }
        }
        _selected = replacement;
      }
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => _fitVisible());
  }

  void _fitVisible() {
    if (!mounted || _visiblePoints.isEmpty) return;
    final latitudes = _visiblePoints
        .map((point) => point.coordinates.latitude)
        .toList();
    final longitudes = _visiblePoints
        .map((point) => point.coordinates.longitude)
        .toList();
    final minLat = latitudes.reduce(math.min);
    final maxLat = latitudes.reduce(math.max);
    final minLon = longitudes.reduce(math.min);
    final maxLon = longitudes.reduce(math.max);
    final center = LatLng((minLat + maxLat) / 2, (minLon + maxLon) / 2);
    final span = math.max(maxLat - minLat, maxLon - minLon);
    final zoom = switch (span) {
      > 100 => 2.0,
      > 40 => 3.0,
      > 15 => 4.0,
      > 7 => 5.0,
      > 3 => 6.0,
      > 1 => 7.0,
      > .3 => 9.0,
      > .1 => 10.0,
      > .03 => 12.0,
      _ => 14.0,
    };
    _mapController.move(center, zoom);
  }

  Future<void> _openSample(CultureMapPoint point) async {
    final id = point.sample['sample_id'];
    if (id is! int) return;
    await Navigator.of(context).push(
      modulePageRoute(
        context: context,
        moduleId: 'samples',
        child: SampleDetailPage(sampleId: id, onSaved: _load),
      ),
    );
  }

  Future<void> _openStrain(Map<String, dynamic> strain) async {
    final id = strain['strain_id'];
    if (id is! int) return;
    await Navigator.of(context).push(
      modulePageRoute(
        context: context,
        moduleId: 'strains',
        child: StrainDetailPage(strainId: id, onSaved: _load),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _buildToolbar(),
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _error != null
              ? _buildError()
              : _buildMap(),
        ),
      ],
    );
  }

  Widget _buildToolbar() {
    final controls = <Widget>[
      if (widget.showBackButton)
        IconButton(
          tooltip: 'Back to strains',
          onPressed: () => Navigator.maybePop(context),
          icon: const Icon(
            Icons.arrow_back_rounded,
            size: AppDS.moduleMenuIconSize,
          ),
        )
      else if (MediaQuery.of(context).size.width < 700)
        IconButton(
          tooltip: 'Menu',
          onPressed: () => Scaffold.of(context).openDrawer(),
          icon: const Icon(Icons.menu_rounded, size: AppDS.moduleMenuIconSize),
        ),
      Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.public_outlined,
            color: _sampleColor,
            size: AppDS.moduleTitleIconSize,
          ),
          const SizedBox(width: 8),
          Text('Culture Map', style: AppDS.moduleTitle(context.appTextPrimary)),
        ],
      ),
      SizedBox(
        width: 280,
        height: AppDS.moduleSearchHeight,
        child: TextField(
          controller: _searchController,
          onChanged: (value) => _applyViewChange(() => _query = value),
          style: GoogleFonts.spaceGrotesk(
            fontSize: AppDS.moduleSearchFontSize,
            color: context.appTextPrimary,
          ),
          decoration: InputDecoration(
            hintText: 'Search code, species or location',
            hintStyle: GoogleFonts.spaceGrotesk(
              fontSize: AppDS.moduleSearchFontSize,
              color: context.appTextMuted,
            ),
            prefixIcon: const Icon(
              Icons.search,
              size: AppDS.moduleSearchIconSize,
            ),
            suffixIcon: _query.isEmpty
                ? null
                : IconButton(
                    onPressed: () {
                      _searchController.clear();
                      _applyViewChange(() => _query = '');
                    },
                    icon: const Icon(
                      Icons.close,
                      size: AppDS.moduleClearIconSize,
                    ),
                  ),
            contentPadding: const EdgeInsets.symmetric(vertical: 8),
            border: const OutlineInputBorder(),
          ),
        ),
      ),
      SegmentedButton<_MapContent>(
        segments: const [
          ButtonSegment(value: _MapContent.all, label: Text('All')),
          ButtonSegment(value: _MapContent.samples, label: Text('Samples')),
          ButtonSegment(value: _MapContent.strains, label: Text('Strains')),
        ],
        selected: {_content},
        showSelectedIcon: false,
        onSelectionChanged: (value) =>
            _applyViewChange(() => _content = value.first),
      ),
      _statChip('${_visiblePoints.length} locations', _sampleColor),
      _statChip('$_visibleStrainCount visible strains', _strainColor),
      if (_sampleCount > _points.length)
        _statChip(
          '${_sampleCount - _points.length} samples without GPS',
          AppDS.orange,
        ),
      if (_strainCount > _mappedStrainCount)
        _statChip(
          '${_strainCount - _mappedStrainCount} strains without mapped sample',
          AppDS.textMuted,
        ),
      IconButton(
        tooltip: 'Fit visible locations',
        onPressed: _visiblePoints.isEmpty ? null : _fitVisible,
        icon: const Icon(
          Icons.center_focus_strong_outlined,
          size: AppDS.moduleActionIconSize,
        ),
      ),
      cultureMapLayerButton(
        selected: _baseMap,
        onSelected: (layer) => setState(() => _baseMap = layer),
      ),
      IconButton(
        tooltip: 'Refresh',
        onPressed: _load,
        icon: const Icon(
          Icons.refresh_rounded,
          size: AppDS.moduleActionIconSize,
        ),
      ),
    ];

    return Container(
      width: double.infinity,
      height: AppDS.moduleToolbarHeight,
      decoration: BoxDecoration(
        color: context.appSurface2,
        border: Border(bottom: BorderSide(color: context.appBorder)),
      ),
      padding: AppDS.moduleToolbarPadding,
      child: Align(
        alignment: Alignment.centerLeft,
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (var index = 0; index < controls.length; index++) ...[
                if (index > 0) const SizedBox(width: 10),
                controls[index],
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _statChip(String label, Color color) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
    decoration: BoxDecoration(
      color: color.withValues(alpha: .1),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: color.withValues(alpha: .28)),
    ),
    child: Text(
      label,
      style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w600),
    ),
  );

  Widget _buildError() => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.map_outlined, size: 48, color: AppDS.red),
        const SizedBox(height: 12),
        Text(
          'Could not load map data',
          style: TextStyle(color: context.appTextPrimary),
        ),
        const SizedBox(height: 6),
        Text(_error!, style: const TextStyle(color: AppDS.red, fontSize: 11)),
        const SizedBox(height: 12),
        FilledButton.icon(
          onPressed: _load,
          icon: const Icon(Icons.refresh),
          label: const Text('Retry'),
        ),
      ],
    ),
  );

  Widget _buildMap() {
    if (_points.isEmpty) {
      return Center(
        child: Text(
          'No samples with valid GPS coordinates were found.',
          style: TextStyle(color: context.appTextSecondary),
        ),
      );
    }
    return Stack(
      fit: StackFit.expand,
      children: [
        FlutterMap(
          mapController: _mapController,
          options: const MapOptions(
            initialCenter: LatLng(20, 0),
            initialZoom: 2.5,
            minZoom: 2,
            maxZoom: 19,
          ),
          children: [
            cultureTileLayer(_baseMap),
            MarkerLayer(markers: _visiblePoints.map(_buildMarker).toList()),
            RichAttributionWidget(
              attributions: [
                TextSourceAttribution(
                  _baseMap.attribution,
                  onTap: () => launchUrl(
                    _baseMap.attributionUri,
                    mode: LaunchMode.externalApplication,
                  ),
                ),
              ],
            ),
          ],
        ),
        Positioned(left: 12, bottom: 28, child: _buildLegend()),
        if (_selected != null)
          Positioned(
            top: 12,
            right: 12,
            bottom: 42,
            child: _buildDetails(_selected!),
          ),
      ],
    );
  }

  Marker _buildMarker(CultureMapPoint point) {
    final hasStrains = point.strains.isNotEmpty;
    final selected = point.sampleId == _selected?.sampleId;
    final color = hasStrains ? _strainColor : _sampleColor;
    return Marker(
      point: LatLng(point.coordinates.latitude, point.coordinates.longitude),
      width: 48,
      height: 54,
      alignment: Alignment.topCenter,
      child: Tooltip(
        message:
            '${point.sampleCode}\n${point.locationLabel}\n${point.strains.length} linked strain(s)',
        child: GestureDetector(
          onTap: () => setState(() => _selected = point),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Icon(
                Icons.location_pin,
                size: selected ? 50 : 44,
                color: color,
                shadows: const [Shadow(color: Colors.white, blurRadius: 3)],
              ),
              if (hasStrains)
                Positioned(
                  right: -1,
                  top: -2,
                  child: Container(
                    constraints: const BoxConstraints(minWidth: 20),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 5,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0F172A),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.white, width: 1.5),
                    ),
                    child: Text(
                      '${point.strains.length}',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLegend() => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
    decoration: BoxDecoration(
      color: context.appSurface.withValues(alpha: .94),
      borderRadius: BorderRadius.circular(9),
      border: Border.all(color: context.appBorder),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _legendDot(_sampleColor, 'Sample'),
        const SizedBox(width: 12),
        _legendDot(_strainColor, 'Sample with strains'),
      ],
    ),
  );

  Widget _legendDot(Color color, String label) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(
        width: 9,
        height: 9,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      ),
      const SizedBox(width: 5),
      Text(
        label,
        style: TextStyle(color: context.appTextSecondary, fontSize: 10),
      ),
    ],
  );

  Widget _buildDetails(CultureMapPoint point) => Container(
    width: math.min(310.0, MediaQuery.of(context).size.width - 24),
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: context.appSurface.withValues(alpha: .97),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: context.appBorder),
      boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 18)],
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.science_outlined, color: _sampleColor, size: 19),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                point.sampleCode.isEmpty ? 'Sample' : point.sampleCode,
                style: TextStyle(
                  color: context.appTextPrimary,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            IconButton(
              visualDensity: VisualDensity.compact,
              onPressed: () => setState(() => _selected = null),
              icon: const Icon(Icons.close, size: 17),
            ),
          ],
        ),
        Text(
          point.locationLabel,
          style: TextStyle(color: context.appTextSecondary, fontSize: 12),
        ),
        const SizedBox(height: 5),
        Text(
          '${point.coordinates.latitude.toStringAsFixed(6)}, ${point.coordinates.longitude.toStringAsFixed(6)}',
          style: TextStyle(
            color: context.appTextMuted,
            fontSize: 10,
            fontFamily: 'monospace',
          ),
        ),
        const SizedBox(height: 10),
        OutlinedButton.icon(
          onPressed: () => _openSample(point),
          icon: const Icon(Icons.open_in_new, size: 15),
          label: const Text('Open sample'),
        ),
        const SizedBox(height: 12),
        Text(
          'LINKED STRAINS (${point.strains.length})',
          style: TextStyle(
            color: context.appTextMuted,
            fontSize: 10,
            fontWeight: FontWeight.w700,
            letterSpacing: .5,
          ),
        ),
        const SizedBox(height: 7),
        Expanded(
          child: point.strains.isEmpty
              ? Text(
                  'No strains linked to this sample.',
                  style: TextStyle(
                    color: context.appTextSecondary,
                    fontSize: 12,
                  ),
                )
              : ListView.separated(
                  itemCount: point.strains.length,
                  separatorBuilder: (_, _) =>
                      Divider(color: context.appBorder, height: 1),
                  itemBuilder: (_, index) {
                    final strain = point.strains[index];
                    final scientificName =
                        strain['strain_scientific_name']?.toString().trim() ??
                        '';
                    final genus = strain['strain_genus']?.toString() ?? '';
                    final species = strain['strain_species']?.toString() ?? '';
                    final taxonomy = scientificName.isNotEmpty
                        ? scientificName
                        : '$genus $species'.trim();
                    return ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      title: Text(
                        strain['strain_code']?.toString() ?? 'Strain',
                        style: TextStyle(
                          color: context.appTextPrimary,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      subtitle: taxonomy.isEmpty
                          ? null
                          : Text(
                              taxonomy,
                              style: TextStyle(
                                color: context.appTextSecondary,
                                fontSize: 10,
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                      trailing: const Icon(Icons.chevron_right, size: 17),
                      onTap: () => _openStrain(strain),
                    );
                  },
                ),
        ),
      ],
    ),
  );
}
