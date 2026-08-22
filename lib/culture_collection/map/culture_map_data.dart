import '../samples/sample_map_picker_page.dart';

class CultureMapPoint {
  final Map<String, dynamic> sample;
  final List<Map<String, dynamic>> strains;
  final SampleCoordinates coordinates;

  const CultureMapPoint({
    required this.sample,
    required this.strains,
    required this.coordinates,
  });

  String get sampleCode => sample['sample_code']?.toString() ?? '';

  Object? get sampleId => sample['sample_id'];

  String get locationLabel {
    final parts =
        [
              sample['sample_local'],
              sample['sample_island'],
              sample['sample_country'],
            ]
            .map((value) => value?.toString().trim() ?? '')
            .where((value) => value.isNotEmpty)
            .toList();
    return parts.isEmpty ? 'Location not specified' : parts.join(', ');
  }

  bool sampleMatches(String query) {
    final normalized = query.trim().toLowerCase();
    if (normalized.isEmpty) return true;
    final sampleValues = [
      sampleCode,
      sample['sample_rebeca'],
      sample['sample_ccpi'],
      sample['sample_country'],
      sample['sample_archipelago'],
      sample['sample_island'],
      sample['sample_region'],
      sample['sample_municipality'],
      sample['sample_parish'],
      sample['sample_local'],
      sample['sample_habitat_type'],
      sample['sample_collector'],
    ];
    if (sampleValues.any(
      (value) => value?.toString().toLowerCase().contains(normalized) == true,
    )) {
      return true;
    }
    return false;
  }

  List<Map<String, dynamic>> matchingStrains(String query) {
    final normalized = query.trim().toLowerCase();
    if (normalized.isEmpty) return strains;
    return strains
        .where(
          (strain) =>
              [
                strain['strain_code'],
                strain['strain_scientific_name'],
                strain['strain_genus'],
                strain['strain_species'],
                strain['strain_status'],
                strain['strain_organism_type'],
              ].any(
                (value) =>
                    value?.toString().toLowerCase().contains(normalized) ==
                    true,
              ),
        )
        .toList(growable: false);
  }

  bool matches(String query) =>
      sampleMatches(query) || matchingStrains(query).isNotEmpty;

  CultureMapPoint withStrains(List<Map<String, dynamic>> matching) =>
      CultureMapPoint(
        sample: sample,
        strains: List.unmodifiable(matching),
        coordinates: coordinates,
      );
}

List<CultureMapPoint> buildCultureMapPoints({
  required List<Map<String, dynamic>> samples,
  required List<Map<String, dynamic>> strains,
}) {
  final strainsBySample = <String, List<Map<String, dynamic>>>{};
  for (final strain in strains) {
    final sampleCode = strain['strain_sample_code']?.toString().trim() ?? '';
    if (sampleCode.isEmpty) continue;
    strainsBySample.putIfAbsent(sampleCode, () => []).add(strain);
  }

  final points = <CultureMapPoint>[];
  for (final sample in samples) {
    final coordinates = parseSampleCoordinates(
      gps: sample['sample_gps']?.toString(),
      latitude: sample['sample_latitude']?.toString(),
      longitude: sample['sample_longitude']?.toString(),
    );
    if (coordinates == null) continue;
    final sampleCode = sample['sample_code']?.toString().trim() ?? '';
    points.add(
      CultureMapPoint(
        sample: sample,
        strains: List.unmodifiable(strainsBySample[sampleCode] ?? const []),
        coordinates: coordinates,
      ),
    );
  }
  return points;
}
