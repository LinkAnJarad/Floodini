import 'dart:async';

import 'package:geolocator/geolocator.dart';

import '../domain/aid_facility.dart';
import '../domain/location_provider.dart';

class GeolocatorLocationProvider implements LocationProvider {
  const GeolocatorLocationProvider({
    this.fixTimeout = const Duration(seconds: 25),
  });

  final Duration fixTimeout;

  @override
  Future<LocationFix> currentFix() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      throw StateError('Turn on Location services and try again.');
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.deniedForever) {
      throw StateError(
        'Location permission is permanently denied. Enable it in app settings.',
      );
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.unableToDetermine) {
      throw StateError('Location permission was not granted.');
    }

    try {
      return _fromPosition(
        await Geolocator.getCurrentPosition(
          locationSettings: LocationSettings(
            accuracy: LocationAccuracy.high,
            timeLimit: fixTimeout,
          ),
        ),
      );
    } on TimeoutException {
      final lastKnown = await Geolocator.getLastKnownPosition();
      if (lastKnown == null) rethrow;
      return _fromPosition(lastKnown, lastKnown: true);
    }
  }

  LocationFix _fromPosition(Position position, {bool lastKnown = false}) =>
      LocationFix(
        point: GeoPoint(
          latitude: position.latitude,
          longitude: position.longitude,
        ),
        accuracyMeters: position.accuracy,
        timestamp: position.timestamp,
        lastKnown: lastKnown,
      );
}
