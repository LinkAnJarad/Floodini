import 'aid_facility.dart';
import 'aid_facility_repository.dart';
import 'location_provider.dart';

abstract interface class NearbyAidFinder {
  Future<NearbyAidSearchResult> findNearby({
    required Set<AidFacilityKind> kinds,
    required double radiusMeters,
  });
}

class LocalNearbyAidFinder implements NearbyAidFinder {
  const LocalNearbyAidFinder({
    required this.locationProvider,
    required this.repository,
  });

  final LocationProvider locationProvider;
  final AidFacilityRepository repository;

  @override
  Future<NearbyAidSearchResult> findNearby({
    required Set<AidFacilityKind> kinds,
    required double radiusMeters,
  }) async {
    if (!radiusMeters.isFinite || radiusMeters <= 0) {
      throw ArgumentError.value(
        radiusMeters,
        'radiusMeters',
        'must be positive and finite',
      );
    }

    final location = await locationProvider.currentFix();
    final dataset = await repository.load();
    final nearby = <NearbyAidFacility>[];
    for (final facility in dataset.facilities) {
      if (!kinds.contains(facility.kind)) continue;
      final distance = location.point.distanceMetersTo(facility.point);
      if (distance <= radiusMeters) {
        nearby.add(
          NearbyAidFacility(facility: facility, distanceMeters: distance),
        );
      }
    }
    nearby.sort((a, b) => a.distanceMeters.compareTo(b.distanceMeters));
    return NearbyAidSearchResult(
      location: location,
      dataset: dataset,
      facilities: List.unmodifiable(nearby),
    );
  }
}
