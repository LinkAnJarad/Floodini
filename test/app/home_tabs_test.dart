import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:walang_signal/app/home_tabs.dart';
import 'package:walang_signal/features/chat/domain/gemma_chat_backend.dart';
import 'package:walang_signal/features/locations/domain/aid_facility.dart';
import 'package:walang_signal/features/locations/domain/nearby_aid_finder.dart';
import 'package:walang_signal/features/knowledge/domain/knowledge_base.dart';
import 'package:walang_signal/features/knowledge/domain/retrieved_passage.dart';
import 'package:walang_signal/features/speech/domain/speech_test_backend.dart';

void main() {
  testWidgets('shows the Speech tab beside Chat', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: WalangSignalHome(
          chatBackend: _FakeChatBackend(),
          speechBackend: _FakeSpeechBackend(),
          nearbyAidFinder: _FakeNearbyAidFinder(),
          knowledgeBase: _FakeKnowledgeBase(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Chat'), findsOneWidget);
    expect(find.text('Speech'), findsOneWidget);
    expect(find.text('Nearby'), findsOneWidget);

    await tester.tap(find.text('Speech'));
    await tester.pumpAndSettle();
    expect(find.text('Filipino speech-to-text'), findsOneWidget);

    await tester.tap(find.text('Nearby'));
    await tester.pumpAndSettle();
    expect(find.text('Nearby aid'), findsOneWidget);
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
  Future<void> startRecording() async {}

  @override
  Future<String> stopAndTranscribe() async => '';

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
  Future<void> speakFilipino(String text) async {}

  @override
  Future<void> stopSpeaking() async {}

  @override
  Future<void> dispose() async {}
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
    required String accessToken,
    required void Function(KnowledgeBaseProgress progress) onProgress,
  }) async {}

  @override
  Future<List<RetrievedPassage>> retrieve(String query) async => const [];

  @override
  Future<void> dispose() async {}
}
