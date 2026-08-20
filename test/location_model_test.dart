import 'package:flutter_test/flutter_test.dart';
import 'package:limsphere/resources/locations/location_model.dart';

void main() {
  test('LocationModel preserves its stable location code', () {
    final location = LocationModel.fromMap({
      'location_id': 42,
      'location_code': 'L2.3',
      'location_name': 'Freezer shelf',
      'location_type': 'shelf',
      'location_parent_id': 7,
    });

    expect(location.code, 'L2.3');
    expect(location.toInsertMap()['location_code'], 'L2.3');
    expect(location.copyWith(name: 'Shelf A').code, 'L2.3');
  });
}
