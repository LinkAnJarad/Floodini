import 'package:flutter/material.dart';

import '../features/chat/domain/gemma_chat_backend.dart';
import '../features/chat/presentation/gemma_chat_screen.dart';
import '../features/locations/domain/nearby_aid_finder.dart';
import '../features/locations/presentation/nearby_aid_screen.dart';
import '../features/speech/domain/speech_test_backend.dart';
import '../features/speech/presentation/speech_test_screen.dart';

class WalangSignalHome extends StatelessWidget {
  const WalangSignalHome({
    super.key,
    required this.chatBackend,
    required this.speechBackend,
    required this.nearbyAidFinder,
  });

  final GemmaChatBackend chatBackend;
  final SpeechTestBackend speechBackend;
  final NearbyAidFinder nearbyAidFinder;

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Walang Signal · local tests'),
          bottom: const TabBar(
            tabs: [
              Tab(icon: Icon(Icons.chat_bubble_outline), text: 'Chat'),
              Tab(icon: Icon(Icons.mic_none), text: 'Speech'),
              Tab(icon: Icon(Icons.place_outlined), text: 'Nearby'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            GemmaChatScreen(backend: chatBackend, showAppBar: false),
            SpeechTestScreen(backend: speechBackend, showAppBar: false),
            NearbyAidScreen(finder: nearbyAidFinder, showAppBar: false),
          ],
        ),
      ),
    );
  }
}
