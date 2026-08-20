import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

import '/theme/theme.dart';

class SampleCoordinates {
  final double latitude;
  final double longitude;

  const SampleCoordinates(this.latitude, this.longitude);
}

SampleCoordinates? parseSampleCoordinates({
  String? gps,
  String? latitude,
  String? longitude,
}) {
  final decimalLatitude = double.tryParse(latitude?.trim() ?? '');
  final decimalLongitude = double.tryParse(longitude?.trim() ?? '');
  if (_coordinatesInRange(decimalLatitude, decimalLongitude)) {
    return SampleCoordinates(decimalLatitude!, decimalLongitude!);
  }

  final rawGps = gps?.trim() ?? '';
  final decimalPair = RegExp(
    r'^\s*(-?\d+(?:\.\d+)?)\s*[,;]\s*(-?\d+(?:\.\d+)?)\s*$',
  ).firstMatch(rawGps);
  if (decimalPair != null) {
    final lat = double.tryParse(decimalPair.group(1)!);
    final lon = double.tryParse(decimalPair.group(2)!);
    if (_coordinatesInRange(lat, lon)) return SampleCoordinates(lat!, lon!);
  }

  final dmsPattern = RegExp(
    r'''(\d{1,3})\s*[°º]\s*(\d{1,2})\s*['′]\s*([\d.]+)\s*(?:["″]|'{1,2})?\s*([NSEW])''',
    caseSensitive: false,
  );
  final matches = dmsPattern.allMatches(rawGps).toList();
  if (matches.length >= 2) {
    double convert(RegExpMatch match) {
      final degrees = double.parse(match.group(1)!);
      final minutes = double.parse(match.group(2)!);
      final seconds = double.parse(match.group(3)!);
      final direction = match.group(4)!.toUpperCase();
      final value = degrees + minutes / 60 + seconds / 3600;
      return direction == 'S' || direction == 'W' ? -value : value;
    }

    final lat = convert(matches.first);
    final lon = convert(matches[1]);
    if (_coordinatesInRange(lat, lon)) return SampleCoordinates(lat, lon);
  }
  return null;
}

bool _coordinatesInRange(double? latitude, double? longitude) =>
    latitude != null &&
    longitude != null &&
    latitude.isFinite &&
    longitude.isFinite &&
    latitude >= -90 &&
    latitude <= 90 &&
    longitude >= -180 &&
    longitude <= 180;

class SampleMapPickerPage extends StatefulWidget {
  final double? initialLatitude;
  final double? initialLongitude;
  final bool allowEditing;

  const SampleMapPickerPage({
    super.key,
    this.initialLatitude,
    this.initialLongitude,
    this.allowEditing = true,
  });

  @override
  State<SampleMapPickerPage> createState() => _SampleMapPickerPageState();
}

class _SampleMapPickerPageState extends State<SampleMapPickerPage> {
  LatLng? _pin;

  @override
  void initState() {
    super.initState();
    final latitude = widget.initialLatitude;
    final longitude = widget.initialLongitude;
    if (_coordinatesInRange(latitude, longitude)) {
      _pin = LatLng(latitude!, longitude!);
    }
  }

  @override
  Widget build(BuildContext context) {
    final initialCenter = _pin ?? const LatLng(20, 0);
    return Scaffold(
      backgroundColor: context.appBg,
      appBar: AppBar(
        backgroundColor: context.appSurface,
        foregroundColor: context.appTextPrimary,
        title: const Text('Choose GPS position'),
        actions: widget.allowEditing
            ? [
                Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: FilledButton.icon(
                    onPressed: _pin == null
                        ? null
                        : () => Navigator.of(context).pop(
                            SampleCoordinates(_pin!.latitude, _pin!.longitude),
                          ),
                    icon: const Icon(Icons.check, size: 17),
                    label: const Text('Use this location'),
                  ),
                ),
              ]
            : null,
      ),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            color: context.appSurface2,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              children: [
                const Icon(Icons.touch_app_outlined, size: 17),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    widget.allowEditing
                        ? 'Tap or click the map to move the sample pin.'
                        : 'Current saved sample position.',
                    style: TextStyle(
                      color: context.appTextSecondary,
                      fontSize: 12,
                    ),
                  ),
                ),
                if (_pin != null)
                  Text(
                    '${_pin!.latitude.toStringAsFixed(6)}, '
                    '${_pin!.longitude.toStringAsFixed(6)}',
                    style: TextStyle(
                      color: context.appTextPrimary,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            child: FlutterMap(
              options: MapOptions(
                initialCenter: initialCenter,
                initialZoom: _pin == null ? 2.5 : 13,
                minZoom: 2,
                maxZoom: 19,
                onTap: widget.allowEditing
                    ? (_, point) => setState(() => _pin = point)
                    : null,
              ),
              children: [
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.silvuzapps.limsphere',
                ),
                if (_pin != null)
                  MarkerLayer(
                    markers: [
                      Marker(
                        point: _pin!,
                        width: 48,
                        height: 48,
                        alignment: Alignment.topCenter,
                        child: const Icon(
                          Icons.location_pin,
                          size: 46,
                          color: Color(0xFFDC2626),
                          shadows: [Shadow(color: Colors.white, blurRadius: 3)],
                        ),
                      ),
                    ],
                  ),
                RichAttributionWidget(
                  attributions: [
                    TextSourceAttribution(
                      'OpenStreetMap contributors',
                      onTap: () async {
                        await launchUrl(
                          Uri.parse('https://www.openstreetmap.org/copyright'),
                          mode: LaunchMode.externalApplication,
                        );
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
