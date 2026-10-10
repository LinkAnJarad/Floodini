import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:floodini/app/setup_gate.dart';
import 'package:floodini/features/chat/domain/gemma_chat_backend.dart';
import 'package:floodini/features/knowledge/domain/knowledge_base.dart';
import 'package:floodini/features/knowledge/domain/retrieved_passage.dart';
import 'package:floodini/features/sendlater/domain/profile_repository.dart';
import 'package:floodini/features/sendlater/domain/user_profile.dart';
import 'package:floodini/features/speech/domain/speech_test_backend.dart';

void main() {
  Future<void> pump(WidgetTester tester, _Fakes fakes) async {
    tester.view.physicalSize = const Size(800, 3200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        home: SetupGate(
          chatBackend: fakes.chat,
          speechBackend: fakes.speech,
          knowledgeBase: fakes.knowledge,
          profileRepository: fakes.profile,
          child: const Text('home'),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> tapKey(WidgetTester tester, String key) async {
    await tester.tap(find.byKey(Key(key)));
    await tester.pumpAndSettle();
  }

  Future<void> fillProfile(WidgetTester tester, {bool accept = true}) async {
    await tester.enterText(find.byKey(const Key('profile-name')), 'Juan Cruz');
    await tester.enterText(
      find.byKey(const Key('contact-name-0')),
      'Maria Cruz',
    );
    await tester.enterText(
      find.byKey(const Key('contact-number-0')),
      '0917 123 4567',
    );
    if (accept) await tester.tap(find.byKey(const Key('disclaimer-checkbox')));
    await tester.pumpAndSettle();
  }

  FilledButton button(WidgetTester tester, String key) =>
      tester.widget<FilledButton>(find.byKey(Key(key)));

  testWidgets('onboards a fresh install, then installs every model', (
    tester,
  ) async {
    final fakes = _Fakes(installed: false);
    await pump(tester, fakes);

    // Step 1: welcome.
    expect(find.text('Meet Floodini.'), findsOneWidget);
    expect(find.text('Handa kahit offline.'), findsOneWidget);
    expect(find.text('home'), findsNothing);
    await tapKey(tester, 'welcome-start-button');

    // Step 2: about you. Nothing entered yet, so it cannot continue.
    expect(button(tester, 'profile-next-button').onPressed, isNull);

    // The disclaimer is required.
    await fillProfile(tester, accept: false);
    expect(button(tester, 'profile-next-button').onPressed, isNull);
    await tester.tap(find.byKey(const Key('disclaimer-checkbox')));
    await tester.pumpAndSettle();
    expect(button(tester, 'profile-next-button').onPressed, isNotNull);

    await tapKey(tester, 'profile-next-button');
    final saved = fakes.profile.saved!;
    expect(saved.name, 'Juan Cruz');
    expect(saved.contacts.single.name, 'Maria Cruz');
    expect(saved.contacts.single.number, '09171234567');
    expect(saved.disclaimerAccepted, isTrue);
    expect(fakes.installed, isEmpty);

    // Step 3: downloads.
    expect(find.text('Download once'), findsOneWidget);
    await tapKey(tester, 'get-started-button');

    expect(fakes.installed, ['whisper', 'knowledge', 'gemma']);
    expect(find.text('home'), findsOneWidget);
  });

  testWidgets('lets the user go back to fix their details', (tester) async {
    final fakes = _Fakes(installed: false);
    await pump(tester, fakes);
    await tapKey(tester, 'welcome-start-button');
    await fillProfile(tester);
    await tapKey(tester, 'profile-next-button');

    await tapKey(tester, 'wizard-back-button');

    expect(find.byKey(const Key('profile-name')), findsOneWidget);
    expect(find.text('Juan Cruz'), findsOneWidget);
  });

  testWidgets('lets the user add and remove emergency contacts', (
    tester,
  ) async {
    final fakes = _Fakes(installed: false);
    await pump(tester, fakes);
    await tapKey(tester, 'welcome-start-button');
    await fillProfile(tester);

    await tapKey(tester, 'add-contact-button');
    // A half-filled second row blocks continuing.
    await tester.enterText(find.byKey(const Key('contact-name-1')), 'Pedro');
    await tester.pumpAndSettle();
    expect(button(tester, 'profile-next-button').onPressed, isNull);

    await tester.enterText(
      find.byKey(const Key('contact-number-1')),
      '+63 918 765 4321',
    );
    await tester.pumpAndSettle();
    expect(button(tester, 'profile-next-button').onPressed, isNotNull);

    await tapKey(tester, 'profile-next-button');
    expect(fakes.profile.saved!.contacts.map((c) => c.number), [
      '09171234567',
      '+639187654321',
    ]);
  });

  testWidgets('rejects a bad mobile number', (tester) async {
    final fakes = _Fakes(installed: false);
    await pump(tester, fakes);
    await tapKey(tester, 'welcome-start-button');
    await fillProfile(tester);

    await tester.enterText(find.byKey(const Key('contact-number-0')), '12ab');
    await tester.pumpAndSettle();
    expect(find.text('Check the number'), findsOneWidget);
    expect(button(tester, 'profile-next-button').onPressed, isNull);
  });

  testWidgets('skips everything when set up already', (tester) async {
    final fakes = _Fakes(installed: true, hasProfile: true);
    await pump(tester, fakes);

    expect(find.text('home'), findsOneWidget);
    expect(fakes.installed, isEmpty);
  });

  testWidgets('asks only for the profile when models are installed', (
    tester,
  ) async {
    final fakes = _Fakes(installed: true);
    await pump(tester, fakes);

    await tapKey(tester, 'welcome-start-button');
    expect(find.byKey(const Key('profile-name')), findsOneWidget);
    await fillProfile(tester);
    // Last step, so the button finishes setup.
    await tapKey(tester, 'get-started-button');

    expect(fakes.profile.saved, isNotNull);
    expect(fakes.installed, isEmpty);
    expect(find.text('home'), findsOneWidget);
  });

  testWidgets('skips the form when only models are missing', (tester) async {
    final fakes = _Fakes(installed: false, hasProfile: true);
    await pump(tester, fakes);

    expect(find.byKey(const Key('profile-name')), findsNothing);
    expect(find.text('Download once'), findsOneWidget);
    expect(button(tester, 'get-started-button').onPressed, isNotNull);
    await tapKey(tester, 'get-started-button');
    expect(find.text('home'), findsOneWidget);
  });

  testWidgets('offers Retry after a failed download', (tester) async {
    final fakes = _Fakes(
      installed: false,
      hasProfile: true,
      failGemmaOnce: true,
    );
    await pump(tester, fakes);

    await tapKey(tester, 'get-started-button');
    expect(find.text('Retry'), findsOneWidget);
    expect(find.text('home'), findsNothing);

    await tapKey(tester, 'get-started-button');
    expect(find.text('home'), findsOneWidget);
    // Whisper and knowledge were not downloaded a second time.
    expect(fakes.installed, ['whisper', 'knowledge', 'gemma']);
  });
}

class _Fakes {
  _Fakes({
    required bool installed,
    bool hasProfile = false,
    bool failGemmaOnce = false,
  }) {
    chat = _Chat(this, installed, failGemmaOnce);
    speech = _Speech(this, installed);
    knowledge = _Knowledge(this, installed);
    profile = _Profiles(
      hasProfile
          ? const UserProfile(
              name: 'Saved',
              contacts: [EmergencyContact(name: 'Mom', number: '09170000000')],
              disclaimerAccepted: true,
            )
          : null,
    );
  }

  final installed = <String>[];
  late final _Chat chat;
  late final _Speech speech;
  late final _Knowledge knowledge;
  late final _Profiles profile;
}

class _Profiles implements ProfileRepository {
  _Profiles(this.saved);

  UserProfile? saved;

  @override
  Future<UserProfile?> load() async => saved;

  @override
  Future<void> save(UserProfile profile) async => saved = profile;
}

class _Chat implements GemmaChatBackend {
  _Chat(this.fakes, this.ready, this.failOnce);

  final _Fakes fakes;
  bool ready;
  bool failOnce;

  @override
  String get activeBackendLabel => 'test';

  @override
  Future<bool> isModelInstalled() async => ready;

  @override
  Future<void> installModel({required void Function(int) onProgress}) async {
    if (failOnce) {
      failOnce = false;
      throw StateError('network error');
    }
    onProgress(100);
    ready = true;
    fakes.installed.add('gemma');
  }

  @override
  Future<void> prepareChat() async {}

  @override
  Stream<String> sendMessage(String prompt, {Uint8List? imageBytes}) async* {}

  @override
  Future<void> dispose() async {}
}

class _Speech implements SpeechTestBackend {
  _Speech(this.fakes, this.ready);

  final _Fakes fakes;
  bool ready;

  @override
  Future<bool> isWhisperInstalled() async => ready;

  @override
  Future<void> installWhisper({required void Function(int) onProgress}) async {
    onProgress(100);
    ready = true;
    fakes.installed.add('whisper');
  }

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

class _Knowledge implements LocalKnowledgeBase {
  _Knowledge(this.fakes, this.ready);

  final _Fakes fakes;
  bool ready;

  @override
  bool get isReady => ready;

  @override
  Future<bool> restoreIfAvailable() async => ready;

  @override
  Future<void> installAndIndex({
    required void Function(KnowledgeBaseProgress progress) onProgress,
  }) async {
    onProgress(const KnowledgeBaseProgress(message: 'Indexing', percent: 100));
    ready = true;
    fakes.installed.add('knowledge');
  }

  @override
  Future<List<RetrievedPassage>> retrieve(String query) async => const [];

  @override
  Future<void> dispose() async {}
}
