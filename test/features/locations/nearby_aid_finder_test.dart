import 'package:flutter_test/flutter_test.dart';
import 'package:walang_signal/features/locations/domain/aid_facility.dart';
import 'package:walang_signal/features/locations/domain/aid_facility_repository.dart';
import 'package:walang_signal/features/locations/domain/location_provider.dart';
import 'package:walang_signal/features/locations/domain/nearby_aid_finder.dart';

void main() {
  test(
    'filters by facility kind and sorts by straight-line distance',
    () async {
      final origin = GeoPoint(latitude: 0, longitude: 0);
      final dataset = AidFacilityDataset(
        sourceFeatureCount: 4,
        generatedAt: null,
        attribution: 'OpenStreetMap contributors; ODbL',
        bounds: null,
        facilities: [
          _facility('hospital-far', AidFacilityKind.hospital, 1.2),
          _facility('hospital-mid', AidFacilityKind.hospital, 0.5),
          _facility('clinic-near', AidFacilityKind.clinic, 0.1),
          _facility('hospital-near', AidFacilityKind.hospital, 0.25),
          _facility('shelter', AidFacilityKind.shelterCandidate, 0.05),
        ],
      );
      final finder = LocalNearbyAidFinder(
        locationProvider: _FakeLocationProvider(
          LocationFix(
            point: origin,
            accuracyMeters: 5,
            timestamp: DateTime.utc(2026, 10, 9),
          ),
        ),
        repository: _FakeFacilityRepository(dataset),
      );

      final result = await finder.findNearby(
        kinds: {AidFacilityKind.hospital},
        radiusMeters: 100000,
      );

      expect(result.facilities.map((item) => item.facility.id), [
        'hospital-near',
        'hospital-mid',
      ]);
      expect(
        result.facilities.first.distanceMeters,
        lessThan(result.facilities.last.distanceMeters),
      );
    },
  );
}

AidFacility _facility(String id, AidFacilityKind kind, double longitude) =>
    AidFacility(
      id: id,
      name: id,
      kind: kind,
      point: GeoPoint(latitude: 0, longitude: longitude),
    );

class _FakeLocationProvider implements LocationProvider {
  _FakeLocationProvider(this.fix);

  final LocationFix fix;

  @override
  Future<LocationFix> currentFix() async => fix;
}

class _FakeFacilityRepository implements AidFacilityRepository {
  _FakeFacilityRepository(this.dataset);

  final AidFacilityDataset dataset;

  @override
  Future<AidFacilityDataset> load() async => dataset;
}
