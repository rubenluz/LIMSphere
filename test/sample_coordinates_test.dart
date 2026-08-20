import 'package:flutter_test/flutter_test.dart';
import 'package:limsphere/culture_collection/samples/sample_map_picker_page.dart';

void main() {
  group('sample GPS parsing', () {
    test('prefers separate decimal latitude and longitude fields', () {
      final result = parseSampleCoordinates(
        gps: '0, 0',
        latitude: '37.733',
        longitude: '-25.293',
      );

      expect(result, isNotNull);
      expect(result!.latitude, 37.733);
      expect(result.longitude, -25.293);
    });

    test('parses a decimal GPS pair', () {
      final result = parseSampleCoordinates(gps: '38.716667, -27.215139');

      expect(result, isNotNull);
      expect(result!.latitude, closeTo(38.716667, 0.000001));
      expect(result.longitude, closeTo(-27.215139, 0.000001));
    });

    test('parses Azores coordinates with decimal commas and slash', () {
      final result = parseSampleCoordinates(gps: '37,767146/-25,485625');

      expect(result, isNotNull);
      expect(result!.latitude, closeTo(37.767146, 0.000001));
      expect(result.longitude, closeTo(-25.485625, 0.000001));
    });

    test('parses decimal commas in separate coordinate fields', () {
      final result = parseSampleCoordinates(
        latitude: '37,767146',
        longitude: '-25,485625',
      );

      expect(result, isNotNull);
      expect(result!.latitude, closeTo(37.767146, 0.000001));
      expect(result.longitude, closeTo(-25.485625, 0.000001));
    });

    test('parses legacy degree minute second coordinates', () {
      final result = parseSampleCoordinates(gps: '37°43\'58.6"N 25°17\'36.8"W');

      expect(result, isNotNull);
      expect(result!.latitude, closeTo(37.732944, 0.000001));
      expect(result.longitude, closeTo(-25.293556, 0.000001));
    });

    test('rejects missing and out-of-range coordinates', () {
      expect(parseSampleCoordinates(gps: ''), isNull);
      expect(parseSampleCoordinates(gps: '120, 250'), isNull);
    });
  });
}
