import 'package:flutter/material.dart';

import '../features/chat/domain/gemma_chat_backend.dart';
import '../features/chat/presentation/gemma_chat_screen.dart';
import '../features/locations/domain/directions_launcher.dart';
import '../features/locations/domain/nearby_aid_finder.dart';
import '../features/knowledge/domain/knowledge_base.dart';
import '../features/locations/presentation/nearby_aid_screen.dart';
import '../features/sendlater/domain/location_recorder.dart';
import '../features/sendlater/domain/profile_repository.dart';
import '../features/sendlater/domain/send_later_gateway.dart';
import '../features/sendlater/presentation/send_later_screen.dart';
import '../features/speech/domain/speech_test_backend.dart';
import '../ui/floodini_mascot.dart';
import '../ui/status_chip.dart';

class FloodiniHome extends StatefulWidget {
  const FloodiniHome({
    super.key,
    required this.chatBackend,
    required this.speechBackend,
    required this.nearbyAidFinder,
    required this.directionsLauncher,
    required this.knowledgeBase,
    required this.sendLaterGateway,
    required this.profileRepository,
    required this.locationRecorder,
  });

  final GemmaChatBackend chatBackend;
  final SpeechTestBackend speechBackend;
  final NearbyAidFinder nearbyAidFinder;
  final DirectionsLauncher directionsLauncher;
  final SendLaterGateway sendLaterGateway;
  final ProfileRepository profileRepository;
  final LocationRecorder locationRecorder;
  final LocalKnowledgeBase knowledgeBase;

  @override
  State<FloodiniHome> createState() => _FloodiniHomeState();
}

class _FloodiniHomeState extends State<FloodiniHome> {
  int _index = 0;

  // A tab is built the first time it is opened and then kept alive, so a
  // download, chat or recording survives switching tabs, and opening the app
  // does not trigger every tab's permission prompts at once.
  final Set<int> _visited = {0};

  Widget _tab(int index) {
    if (!_visited.contains(index)) return const SizedBox.shrink();
    return switch (index) {
      0 => GemmaChatScreen(
        backend: widget.chatBackend,
        knowledgeBase: widget.knowledgeBase,
        speech: widget.speechBackend,
        showAppBar: false,
      ),
      1 => NearbyAidScreen(
        finder: widget.nearbyAidFinder,
        directions: widget.directionsLauncher,
        showAppBar: false,
      ),
      _ => SendLaterScreen(
        gateway: widget.sendLaterGateway,
        profiles: widget.profileRepository,
        locationRecorder: widget.locationRecorder,
        showAppBar: false,
      ),
    };
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 64,
        titleSpacing: 16,
        title: Row(
          children: [
            const FloodiniAvatar(size: 40),
            const SizedBox(width: 12),
            Text(
              'Floodini',
              style: Theme.of(context).textTheme.headlineSmall!.copyWith(
                color: Theme.of(context).appBarTheme.foregroundColor,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        actions: const [
          Padding(
            padding: EdgeInsets.only(right: 16),
            child: Center(child: OfflineReadyChip()),
          ),
        ],
      ),
      body: IndexedStack(
        index: _index,
        children: [for (var i = 0; i < 3; i++) _tab(i)],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (index) => setState(() {
          _index = index;
          _visited.add(index);
        }),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.chat_bubble_outline),
            selectedIcon: Icon(Icons.chat_bubble),
            label: 'Chat',
          ),
          NavigationDestination(
            icon: Icon(Icons.place_outlined),
            selectedIcon: Icon(Icons.place),
            label: 'Nearby',
          ),
          NavigationDestination(
            icon: Icon(Icons.schedule_send_outlined),
            selectedIcon: Icon(Icons.schedule_send),
            label: 'Send later',
          ),
        ],
      ),
    );
  }
}
