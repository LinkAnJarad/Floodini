import 'package:url_launcher/url_launcher.dart';

import '../domain/aid_facility.dart';
import '../domain/directions_launcher.dart';

/// Opens Google Maps walking directions, falling back to any app that handles
/// a `geo:` link. The origin is omitted so Maps uses the live GPS position.
class MapsDirectionsLauncher implements DirectionsLauncher {
  const MapsDirectionsLauncher();

  static Uri googleMapsWalkingUri(GeoPoint destination) =>
      Uri.https('www.google.com', '/maps/dir/', {
        'api': '1',
        'destination': '${destination.latitude},${destination.longitude}',
        'travelmode': 'walking',
      });

  static Uri geoUri(GeoPoint destination, String label) {
    final point = '${destination.latitude},${destination.longitude}';
    return Uri.parse('geo:$point?q=$point(${Uri.encodeComponent(label)})');
  }

  @override
  Future<bool> openWalkingDirections({
    required GeoPoint destination,
    required String label,
  }) async {
    for (final uri in [
      googleMapsWalkingUri(destination),
      geoUri(destination, label),
    ]) {
      try {
        if (await launchUrl(uri, mode: LaunchMode.externalApplication)) {
          return true;
        }
      } catch (_) {
        // Try the next option.
      }
    }
    return false;
  }
}
