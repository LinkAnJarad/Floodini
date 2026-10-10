import 'package:flutter/material.dart';
import 'package:flutter_edge_ai/flutter_edge_ai.dart';
import 'package:flutter_edge_ai_embeddings/flutter_edge_ai_embeddings.dart';
import 'package:flutter_edge_ai_litertlm/flutter_edge_ai_litertlm.dart';
import 'package:flutter_edge_ai_speech/flutter_edge_ai_speech.dart';

import 'app/floodini_app.dart';
import 'features/chat/data/flutter_edge_gemma_chat_backend.dart';
import 'features/locations/data/geolocator_location_provider.dart';
import 'features/locations/data/overpass_geojson_repository.dart';
import 'features/locations/data/maps_directions_launcher.dart';
import 'features/locations/domain/nearby_aid_finder.dart';
import 'features/knowledge/data/flutter_edge_knowledge_base.dart';
import 'features/sendlater/data/channel_send_later_gateway.dart';
import 'features/sendlater/data/prefs_profile_repository.dart';
import 'features/sendlater/domain/location_recorder.dart';
import 'features/speech/data/device_speech_test_backend.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  String? initializationError;
  try {
    await FlutterEdgeAi.initialize(
      inferenceEngines: const [LiteRtLmEngine()],
      embeddingBackends: const [LiteRtEmbeddingBackend()],
      embeddingTokenizers: const [GemmaEmbeddingTokenizers()],
      sttBackends: const [LiteRtSttBackend()],
    );
  } catch (error) {
    initializationError = error.toString();
  }

  final sendLaterGateway = ChannelSendLaterGateway();

  runApp(
    FloodiniApp(
      chatBackend: FlutterEdgeGemmaChatBackend(),
      knowledgeBase: FlutterEdgeKnowledgeBase(),
      speechBackend: DeviceSpeechTestBackend(),
      nearbyAidFinder: LocalNearbyAidFinder(
        locationProvider: const GeolocatorLocationProvider(),
        repository: OverpassGeoJsonRepository(),
      ),
      directionsLauncher: const MapsDirectionsLauncher(),
      sendLaterGateway: sendLaterGateway,
      profileRepository: const PrefsProfileRepository(),
      locationRecorder: LocationRecorder(
        provider: const GeolocatorLocationProvider(
          fixTimeout: Duration(seconds: 10),
        ),
        gateway: sendLaterGateway,
      ),
      initializationError: initializationError,
    ),
  );
}
