import 'package:flutter_test/flutter_test.dart';
import 'package:floodini/features/locations/data/maps_directions_launcher.dart';
import 'package:floodini/features/locations/domain/aid_facility.dart';

void main() {
  const destination = GeoPoint(latitude: 14.66, longitude: 121.1);

  test('builds a Google Maps walking link with no origin', () {
    final uri = MapsDirectionsLauncher.googleMapsWalkingUri(destination);

    expect(uri.host, 'www.google.com');
    expect(uri.path, '/maps/dir/');
    expect(uri.queryParameters, {
      'api': '1',
      'destination': '14.66,121.1',
      'travelmode': 'walking',
    });
  });

  test('builds a geo link with the place name for other maps apps', () {
    final uri = MapsDirectionsLauncher.geoUri(destination, 'Health Center #1');

    expect(uri.scheme, 'geo');
    expect(
      uri.toString(),
      'geo:14.66,121.1?q=14.66,121.1(Health%20Center%20%231)',
    );
  });
}
