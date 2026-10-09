import 'package:flutter_test/flutter_test.dart';
import 'package:walang_signal/features/locations/data/overpass_geojson_repository.dart';
import 'package:walang_signal/features/locations/domain/aid_facility.dart';

const _fixture = '''
{
  "type": "FeatureCollection",
  "copyright": "OpenStreetMap contributors; ODbL",
  "timestamp": "2026-10-09T15:58:40Z",
  "features": [
    {
      "type": "Feature",
      "properties": {
        "@id": "node/1",
        "name": "Sample General Hospital",
        "amenity": "hospital",
        "healthcare": "hospital",
        "emergency": "yes",
        "addr:city": "Sample City",
        "phone": "+63 2 8000 0000"
      },
      "geometry": {"type": "Point", "coordinates": [121.01, 14.60]}
    },
    {
      "type": "Feature",
      "properties": {
        "@id": "node/2",
        "name": "Sample Health Center",
        "amenity": "clinic",
        "healthcare": "clinic"
      },
      "geometry": {"type": "Point", "coordinates": [121.02, 14.61]}
    },
    {
      "type": "Feature",
      "properties": {
        "@id": "way/3",
        "name": "Sample Elementary School",
        "amenity": "school",
        "social_facility": "shelter",
        "social_facility:for": "displaced",
        "source": "Department of Education"
      },
      "geometry": {"type": "Point", "coordinates": [121.03, 14.62]}
    },
    {
      "type": "Feature",
      "properties": {
        "@id": "node/4",
        "name": "Bus Shelter",
        "amenity": "shelter",
        "shelter_type": "public_transport"
      },
      "geometry": {"type": "Point", "coordinates": [121.04, 14.63]}
    },
    {
      "type": "Feature",
      "properties": {"@id": "node/5", "name": "Corner Store", "shop": "convenience"},
      "geometry": {"type": "Point", "coordinates": [121.05, 14.64]}
    }
  ]
}
''';

void main() {
  test(
    'parses only useful facility types and preserves attribution metadata',
    () {
      final dataset = OverpassGeoJsonRepository.parseGeoJson(_fixture);

      expect(dataset.sourceFeatureCount, 5);
      expect(dataset.facilities, hasLength(3));
      expect(dataset.facilities.map((facility) => facility.kind), [
        AidFacilityKind.hospital,
        AidFacilityKind.clinic,
        AidFacilityKind.shelterCandidate,
      ]);
      expect(dataset.facilities.first.name, 'Sample General Hospital');
      expect(dataset.facilities.first.point.latitude, 14.60);
      expect(dataset.facilities.first.point.longitude, 121.01);
      expect(dataset.facilities.first.emergency, 'yes');
      expect(dataset.facilities.first.phone, '+63 2 8000 0000');
      expect(dataset.attribution, contains('OpenStreetMap contributors'));
      expect(dataset.generatedAt, DateTime.parse('2026-10-09T15:58:40Z'));
    },
  );
}
