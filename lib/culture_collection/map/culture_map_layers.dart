import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';

enum CultureBaseMap { street, satellite, terrain }

extension CultureBaseMapDefinition on CultureBaseMap {
  String get label => switch (this) {
    CultureBaseMap.street => 'Street',
    CultureBaseMap.satellite => 'Satellite',
    CultureBaseMap.terrain => 'Terrain',
  };

  IconData get icon => switch (this) {
    CultureBaseMap.street => Icons.map_outlined,
    CultureBaseMap.satellite => Icons.satellite_alt_outlined,
    CultureBaseMap.terrain => Icons.terrain_outlined,
  };

  String get attribution => switch (this) {
    CultureBaseMap.street => 'OpenStreetMap contributors',
    CultureBaseMap.satellite => 'Esri World Imagery',
    CultureBaseMap.terrain => 'OpenTopoMap contributors',
  };

  Uri get attributionUri => switch (this) {
    CultureBaseMap.street => Uri.parse(
      'https://www.openstreetmap.org/copyright',
    ),
    CultureBaseMap.satellite => Uri.parse(
      'https://www.esri.com/en-us/legal/terms/full-master-agreement',
    ),
    CultureBaseMap.terrain => Uri.parse('https://opentopomap.org/credits'),
  };
}

TileLayer cultureTileLayer(CultureBaseMap layer) => switch (layer) {
  CultureBaseMap.street => TileLayer(
    urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
    userAgentPackageName: 'com.silvuzapps.limsphere',
    maxNativeZoom: 19,
  ),
  CultureBaseMap.satellite => TileLayer(
    urlTemplate:
        'https://server.arcgisonline.com/ArcGIS/rest/services/'
        'World_Imagery/MapServer/tile/{z}/{y}/{x}',
    userAgentPackageName: 'com.silvuzapps.limsphere',
    maxNativeZoom: 19,
  ),
  CultureBaseMap.terrain => TileLayer(
    urlTemplate: 'https://{s}.tile.opentopomap.org/{z}/{x}/{y}.png',
    subdomains: const ['a', 'b', 'c'],
    userAgentPackageName: 'com.silvuzapps.limsphere',
    maxNativeZoom: 17,
  ),
};

PopupMenuButton<CultureBaseMap> cultureMapLayerButton({
  required CultureBaseMap selected,
  required ValueChanged<CultureBaseMap> onSelected,
}) => PopupMenuButton<CultureBaseMap>(
  tooltip: 'Map layer',
  initialValue: selected,
  onSelected: onSelected,
  icon: Icon(selected.icon),
  itemBuilder: (_) => [
    for (final layer in CultureBaseMap.values)
      PopupMenuItem(
        value: layer,
        child: Row(
          children: [
            Icon(layer.icon, size: 18),
            const SizedBox(width: 10),
            Text(layer.label),
            if (layer == selected) ...[
              const Spacer(),
              const Icon(Icons.check, size: 17),
            ],
          ],
        ),
      ),
  ],
);
