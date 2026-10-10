import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:floodini/features/locations/domain/aid_facility.dart';
import 'package:floodini/features/locations/domain/directions_launcher.dart';
import 'package:floodini/features/locations/domain/nearby_aid_finder.dart';
import 'package:floodini/features/locations/presentation/nearby_aid_screen.dart';

void main() {
  testWidgets(
    'shows nearby facility results after an explicit location search',
    (tester) async {
      final finder = _FakeNearbyAidFinder();
      tester.view.physicalSize = const Size(800, 3200);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
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

  testWidgets('opens walking directions when a result is tapped', (
    tester,
  ) async {
    final launcher = _FakeDirectionsLauncher();
    tester.view.physicalSize = const Size(800, 3200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        home: NearbyAidScreen(
          finder: _FakeNearbyAidFinder(),
          directions: launcher,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('find-nearby-button')));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.byKey(const Key('facility-node/123')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('facility-node/123')));
    await tester.pumpAndSettle();

    expect(launcher.opened.single.$1.latitude, 14.66);
    expect(launcher.opened.single.$2, 'Marikina City Health Center');
  });

  testWidgets('tells the user when no maps app could be opened', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 3200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        home: NearbyAidScreen(
          finder: _FakeNearbyAidFinder(),
          directions: _FakeDirectionsLauncher(succeeds: false),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('find-nearby-button')));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.byKey(const Key('facility-node/123')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('facility-node/123')));
    await tester.pump();

    expect(find.text('Could not open a maps app.'), findsOneWidget);
  });
}

class _FakeDirectionsLauncher implements DirectionsLauncher {
  _FakeDirectionsLauncher({this.succeeds = true});

  final bool succeeds;
  final opened = <(GeoPoint, String)>[];

  @override
  Future<bool> openWalkingDirections({
    required GeoPoint destination,
    required String label,
  }) async {
    opened.add((destination, label));
    return succeeds;
  }
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
