import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:floodini/app/home_tabs.dart';
import 'package:floodini/features/chat/domain/gemma_chat_backend.dart';
import 'package:floodini/features/locations/domain/aid_facility.dart';
import 'package:floodini/features/locations/domain/directions_launcher.dart';
import 'package:floodini/features/locations/domain/nearby_aid_finder.dart';
import 'package:floodini/features/knowledge/domain/knowledge_base.dart';
import 'package:floodini/features/knowledge/domain/retrieved_passage.dart';
import 'package:floodini/features/locations/domain/location_provider.dart';
import 'package:floodini/features/sendlater/domain/location_recorder.dart';
import 'package:floodini/features/sendlater/domain/profile_repository.dart';
import 'package:floodini/features/sendlater/domain/queued_message.dart';
import 'package:floodini/features/sendlater/domain/send_later_gateway.dart';
import 'package:floodini/features/sendlater/domain/user_profile.dart';
import 'package:floodini/features/speech/domain/speech_test_backend.dart';

void main() {
  testWidgets('shows Chat with the voice controls beside Nearby', (
    tester,
  ) async {
    final gateway = _FakeGateway();
    await tester.pumpWidget(
      MaterialApp(
        home: FloodiniHome(
          chatBackend: _FakeChatBackend(),
          speechBackend: _FakeSpeechBackend(),
          nearbyAidFinder: _FakeNearbyAidFinder(),
          directionsLauncher: _FakeDirectionsLauncher(),
          sendLaterGateway: gateway,
          profileRepository: _FakeProfiles(),
          locationRecorder: LocationRecorder(
            provider: _FakeLocationProvider(),
            gateway: gateway,
          ),
          knowledgeBase: _FakeKnowledgeBase(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Chat'), findsOneWidget);
    expect(find.text('Speech'), findsNothing);
    expect(find.text('Nearby'), findsOneWidget);

    await tester.tap(find.text('Nearby'));
    await tester.pumpAndSettle();
    expect(find.text('Nearby aid'), findsOneWidget);

    await tester.tap(find.text('Send later'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('safe-button')), findsOneWidget);
  });
}

class _FakeChatBackend implements GemmaChatBackend {
  @override
  String get activeBackendLabel => 'test';

  @override
  Future<bool> isModelInstalled() async => false;

  @override
  Future<void> installModel({required void Function(int) onProgress}) async {}

  @override
  Future<void> prepareChat() async {}

  @override
  Stream<String> sendMessage(String prompt, {Uint8List? imageBytes}) async* {}

  @override
  Future<void> dispose() async {}
}

class _FakeSpeechBackend implements SpeechTestBackend {
  @override
  Future<bool> isWhisperInstalled() async => false;

  @override
  Future<void> installWhisper({required void Function(int) onProgress}) async {}

  @override
  Future<String> listen({
    Duration maxDuration = const Duration(seconds: 28),
    Duration silenceAfterSpeech = const Duration(milliseconds: 1500),
    Duration waitForSpeech = const Duration(seconds: 8),
  }) async => '';

  @override
  Future<void> cancelListening() async {}

  @override
  Future<FilipinoTtsVoiceStatus> checkFilipinoVoice() async =>
      const FilipinoTtsVoiceStatus(
        voiceFound: false,
        installed: false,
        networkRequired: false,
        voiceName: null,
        locale: null,
      );

  @override
  Future<void> speak(String text) async {}

  @override
  Future<void> stopSpeaking() async {}

  @override
  Future<void> dispose() async {}
}

class _FakeDirectionsLauncher implements DirectionsLauncher {
  @override
  Future<bool> openWalkingDirections({
    required GeoPoint destination,
    required String label,
  }) async => true;
}

class _FakeNearbyAidFinder implements NearbyAidFinder {
  @override
  Future<NearbyAidSearchResult> findNearby({
    required Set<AidFacilityKind> kinds,
    required double radiusMeters,
  }) async => NearbyAidSearchResult(
    location: LocationFix(
      point: const GeoPoint(latitude: 14.6, longitude: 121.0),
      accuracyMeters: 5,
      timestamp: DateTime.utc(2026, 10, 9),
    ),
    dataset: const AidFacilityDataset(
      sourceFeatureCount: 0,
      facilities: [],
      generatedAt: null,
      attribution: 'OpenStreetMap contributors; ODbL',
      bounds: null,
    ),
    facilities: const [],
  );
}

class _FakeKnowledgeBase implements LocalKnowledgeBase {
  @override
  bool get isReady => false;

  @override
  Future<bool> restoreIfAvailable() async => false;

  @override
  Future<void> installAndIndex({
    required void Function(KnowledgeBaseProgress progress) onProgress,
  }) async {}

  @override
  Future<List<RetrievedPassage>> retrieve(String query) async => const [];

  @override
  Future<void> dispose() async {}
}

class _FakeGateway implements SendLaterGateway {
  @override
  Future<bool> hasSmsPermission() async => true;

  @override
  Future<bool> requestSmsPermission() async => true;

  @override
  Future<List<QueuedMessage>> list() async => const [];

  @override
  Future<void> enqueue(QueuedMessage message) async {}

  @override
  Future<void> remove(String id) async {}

  @override
  Future<SendSummary> sendNow() async => const SendSummary(sent: 0, failed: 0);

  @override
  Future<void> saveLocation(LocationFix fix) async {}

  @override
  Future<LocationFix?> lastLocation() async => null;
}

class _FakeProfiles implements ProfileRepository {
  @override
  Future<UserProfile?> load() async => const UserProfile(
    name: 'Juan',
    contacts: [EmergencyContact(name: 'Mom', number: '09170000000')],
    disclaimerAccepted: true,
  );

  @override
  Future<void> save(UserProfile profile) async {}
}

class _FakeLocationProvider implements LocationProvider {
  @override
  Future<LocationFix> currentFix() async => throw StateError('no gps');
}
