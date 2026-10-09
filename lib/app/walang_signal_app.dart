import 'package:flutter/material.dart';

import '../features/chat/domain/gemma_chat_backend.dart';
import '../features/locations/domain/nearby_aid_finder.dart';
import '../features/knowledge/domain/knowledge_base.dart';
import '../features/speech/domain/speech_test_backend.dart';
import 'home_tabs.dart';

class WalangSignalApp extends StatelessWidget {
  const WalangSignalApp({
    super.key,
    required this.chatBackend,
    required this.speechBackend,
    required this.nearbyAidFinder,
    required this.knowledgeBase,
    this.initializationError,
  });

  final GemmaChatBackend chatBackend;
  final SpeechTestBackend speechBackend;
  final NearbyAidFinder nearbyAidFinder;
  final LocalKnowledgeBase knowledgeBase;
  final String? initializationError;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Walang Signal · local tests',
      theme: ThemeData(colorSchemeSeed: Colors.teal, useMaterial3: true),
      home: initializationError == null
          ? WalangSignalHome(
              chatBackend: chatBackend,
              speechBackend: speechBackend,
              nearbyAidFinder: nearbyAidFinder,
              knowledgeBase: knowledgeBase,
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
      appBar: AppBar(title: const Text('Walang Signal · startup')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: SelectableText('Could not initialize local AI:\n$error'),
        ),
      ),
    );
  }
}
