import 'package:flutter/material.dart';

import '../features/chat/domain/gemma_chat_backend.dart';
import '../features/locations/domain/directions_launcher.dart';
import '../features/locations/domain/nearby_aid_finder.dart';
import '../features/knowledge/domain/knowledge_base.dart';
import '../features/sendlater/domain/location_recorder.dart';
import '../features/sendlater/domain/profile_repository.dart';
import '../features/sendlater/domain/send_later_gateway.dart';
import '../features/speech/domain/speech_test_backend.dart';
import 'home_tabs.dart';
import 'setup_gate.dart';
import '../ui/theme.dart';

class FloodiniApp extends StatelessWidget {
  const FloodiniApp({
    super.key,
    required this.chatBackend,
    required this.speechBackend,
    required this.nearbyAidFinder,
    required this.directionsLauncher,
    required this.knowledgeBase,
    required this.sendLaterGateway,
    required this.profileRepository,
    required this.locationRecorder,
    this.initializationError,
  });

  final GemmaChatBackend chatBackend;
  final SpeechTestBackend speechBackend;
  final NearbyAidFinder nearbyAidFinder;
  final DirectionsLauncher directionsLauncher;
  final SendLaterGateway sendLaterGateway;
  final ProfileRepository profileRepository;
  final LocationRecorder locationRecorder;
  final LocalKnowledgeBase knowledgeBase;
  final String? initializationError;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Floodini',
      theme: floodiniTheme(Brightness.light),
      darkTheme: floodiniTheme(Brightness.dark),
      themeMode: ThemeMode.system,
      home: initializationError == null
          ? SetupGate(
              chatBackend: chatBackend,
              speechBackend: speechBackend,
              knowledgeBase: knowledgeBase,
              profileRepository: profileRepository,
              child: FloodiniHome(
                chatBackend: chatBackend,
                speechBackend: speechBackend,
                nearbyAidFinder: nearbyAidFinder,
                directionsLauncher: directionsLauncher,
                knowledgeBase: knowledgeBase,
                sendLaterGateway: sendLaterGateway,
                profileRepository: profileRepository,
                locationRecorder: locationRecorder,
              ),
            )
          : _InitializationErrorScreen(error: initializationError!),
    );
  }
}

class _InitializationErrorScreen extends StatelessWidget {
  const _InitializationErrorScreen({required this.error});

  final String error;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Floodini')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: SelectableText('Could not initialize local AI:\n$error'),
        ),
      ),
    );
  }
}
