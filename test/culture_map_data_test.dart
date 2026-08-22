import 'package:flutter_test/flutter_test.dart';
import 'package:limsphere/culture_collection/map/culture_map_data.dart';

void main() {
  test('builds georeferenced samples with their linked strains', () {
    final points = buildCultureMapPoints(
      samples: [
        {
          'sample_id': 1,
          'sample_code': 'S-001',
          'sample_latitude': '37.733',
          'sample_longitude': '-25.293',
          'sample_local': 'Furnas',
        },
        {'sample_id': 2, 'sample_code': 'S-002', 'sample_gps': 'invalid'},
      ],
      strains: [
        {
          'strain_id': 10,
          'strain_code': 'C-010',
          'strain_sample_code': 'S-001',
          'strain_genus': 'Nostoc',
        },
      ],
    );

    expect(points, hasLength(1));
    expect(points.single.sampleCode, 'S-001');
    expect(points.single.strains, hasLength(1));
    expect(points.single.coordinates.latitude, 37.733);
    expect(points.single.matches('Nostoc'), isTrue);
    expect(points.single.matches('Furnas'), isTrue);
  });

  test('filters the strains attached to a matching map point', () {
    final point = buildCultureMapPoints(
      samples: const [
        {
          'sample_id': 1,
          'sample_code': 'S-001',
          'sample_latitude': '37.7',
          'sample_longitude': '-25.3',
        },
      ],
      strains: const [
        {
          'strain_id': 10,
          'strain_code': 'C-010',
          'strain_sample_code': 'S-001',
          'strain_genus': 'Kamptonema',
          'strain_scientific_name': 'Kamptonema formosum',
        },
        {
          'strain_id': 11,
          'strain_code': 'C-011',
          'strain_sample_code': 'S-001',
          'strain_genus': 'Nostoc',
        },
      ],
    ).single;

    final matching = point.matchingStrains('kamptonem');

    expect(matching, hasLength(1));
    expect(matching.single['strain_genus'], 'Kamptonema');
    expect(point.matchingStrains('formosum'), hasLength(1));
    expect(point.withStrains(matching).strains, hasLength(1));
  });
}
