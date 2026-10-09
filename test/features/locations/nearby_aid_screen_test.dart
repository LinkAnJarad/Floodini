import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:walang_signal/features/locations/domain/aid_facility.dart';
import 'package:walang_signal/features/locations/domain/nearby_aid_finder.dart';
import 'package:walang_signal/features/locations/presentation/nearby_aid_screen.dart';

void main() {
  testWidgets(
    'shows nearby facility results after an explicit location search',
    (tester) async {
      final finder = _FakeNearbyAidFinder();
      await tester.pumpWidget(
        MaterialApp(home: NearbyAidScreen(finder: finder)),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('find-nearby-button')));
      await tester.pumpAndSettle();

      expect(finder.searchCalls, 1);
      expect(find.text('Marikina City Health Center'), findsOneWidget);
      expect(find.text('1.2 km'), findsOneWidget);
      expect(find.text('OpenStreetMap contributors · ODbL'), findsOneWidget);
    },
  );
}

class _FakeNearbyAidFinder implements NearbyAidFinder {
  int searchCalls = 0;

  @override
  Future<NearbyAidSearchResult> findNearby({
    required Set<AidFacilityKind> kinds,
    required double radiusMeters,
  }) async {
    searchCalls++;
    return NearbyAidSearchResult(
      location: LocationFix(
        point: const GeoPoint(latitude: 14.65, longitude: 121.1),
        accuracyMeters: 8,
        timestamp: DateTime.utc(2026, 10, 9),
      ),
      dataset: AidFacilityDataset(
        sourceFeatureCount: 2836,
        facilities: const [],
        generatedAt: DateTime.utc(2026, 10, 9),
        attribution: 'OpenStreetMap contributors · ODbL',
        bounds: null,
      ),
      facilities: [
        NearbyAidFacility(
          facility: const AidFacility(
            id: 'node/123',
            name: 'Marikina City Health Center',
            kind: AidFacilityKind.clinic,
            point: GeoPoint(latitude: 14.66, longitude: 121.1),
            city: 'Marikina',
          ),
          distanceMeters: 1200,
        ),
      ],
    );
  }
}
