import 'dart:math' as math;

enum AidFacilityKind { hospital, clinic, shelterCandidate }

extension AidFacilityKindLabel on AidFacilityKind {
  String get label => switch (this) {
    AidFacilityKind.hospital => 'Hospital',
    AidFacilityKind.clinic => 'Clinic / health center',
    AidFacilityKind.shelterCandidate => 'Shelter candidate',
  };
}

class GeoPoint {
  const GeoPoint({required this.latitude, required this.longitude})
    : assert(latitude >= -90 && latitude <= 90),
      assert(longitude >= -180 && longitude <= 180);

  final double latitude;
  final double longitude;

  double distanceMetersTo(GeoPoint other) {
    const earthRadiusMeters = 6371008.8;
    final lat1 = _toRadians(latitude);
    final lat2 = _toRadians(other.latitude);
    final deltaLat = lat2 - lat1;
    final deltaLon = _toRadians(other.longitude - longitude);
    final a =
        math.pow(math.sin(deltaLat / 2), 2) +
        math.cos(lat1) * math.cos(lat2) * math.pow(math.sin(deltaLon / 2), 2);
    final boundedA = a.clamp(0.0, 1.0);
    return earthRadiusMeters *
        2 *
        math.atan2(math.sqrt(boundedA), math.sqrt(1 - boundedA));
  }

  static double _toRadians(double degrees) => degrees * math.pi / 180;
}

class LocationFix {
  const LocationFix({
    required this.point,
    required this.accuracyMeters,
    required this.timestamp,
    this.lastKnown = false,
  });

  final GeoPoint point;
  final double accuracyMeters;
  final DateTime timestamp;
  final bool lastKnown;
}

class GeoBounds {
  const GeoBounds({
    required this.west,
    required this.south,
    required this.east,
    required this.north,
  });

  final double west;
  final double south;
  final double east;
  final double north;

  bool contains(GeoPoint point) =>
      point.longitude >= west &&
      point.longitude <= east &&
      point.latitude >= south &&
      point.latitude <= north;
}

class AidFacility {
  const AidFacility({
    required this.id,
    required this.name,
    required this.kind,
    required this.point,
    this.city,
    this.province,
    this.phone,
    this.openingHours,
    this.emergency,
    this.source,
    this.provisional = false,
  });

  final String id;
  final String name;
  final AidFacilityKind kind;
  final GeoPoint point;
  final String? city;
  final String? province;
  final String? phone;
  final String? openingHours;
  final String? emergency;
  final String? source;
  final bool provisional;
}

class AidFacilityDataset {
  const AidFacilityDataset({
    required this.sourceFeatureCount,
    required this.facilities,
    required this.generatedAt,
    required this.attribution,
    required this.bounds,
  });

  final int sourceFeatureCount;
  final List<AidFacility> facilities;
  final DateTime? generatedAt;
  final String attribution;
  final GeoBounds? bounds;
}

class NearbyAidFacility {
  const NearbyAidFacility({
    required this.facility,
    required this.distanceMeters,
  });

  final AidFacility facility;
  final double distanceMeters;
}

class NearbyAidSearchResult {
  const NearbyAidSearchResult({
    required this.location,
    required this.dataset,
    required this.facilities,
  });

  final LocationFix location;
  final AidFacilityDataset dataset;
  final List<NearbyAidFacility> facilities;
}
