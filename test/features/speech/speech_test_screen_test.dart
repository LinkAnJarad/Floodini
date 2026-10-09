import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:walang_signal/features/speech/domain/speech_test_backend.dart';
import 'package:walang_signal/features/speech/presentation/speech_test_screen.dart';

void main() {
  testWidgets('installs Whisper and transcribes a short Filipino recording', (
    tester,
  ) async {
    final backend = _FakeSpeechTestBackend(installed: false);

    await tester.pumpWidget(
      MaterialApp(home: SpeechTestScreen(backend: backend)),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('install-whisper-button')), findsOneWidget);
    await tester.tap(find.byKey(const Key('install-whisper-button')));
    await tester.pumpAndSettle();

    expect(find.text('Whisper ready'), findsOneWidget);
    await tester.tap(find.byKey(const Key('start-recording-button')));
    await tester.pumpAndSettle();
    expect(find.text('Recording in Filipino mode…'), findsOneWidget);

    await tester.tap(find.byKey(const Key('stop-transcribe-button')));
    await tester.pumpAndSettle();

    expect(backend.startRecordingCalls, 1);
    expect(backend.transcriptionCalls, 1);
    expect(find.text('Magandang umaga po.'), findsOneWidget);
  });

  testWidgets('speaks a sample with an installed offline Filipino voice', (
    tester,
  ) async {
    final backend = _FakeSpeechTestBackend(
      installed: true,
      voiceStatus: const FilipinoTtsVoiceStatus(
        voiceFound: true,
        installed: true,
        networkRequired: false,
        voiceName: 'Filipino voice',
        locale: 'fil-PH',
      ),
    );

    await tester.pumpWidget(
      MaterialApp(home: SpeechTestScreen(backend: backend)),
    );
    await tester.pumpAndSettle();

    final speakButton = find.byKey(const Key('speak-filipino-button'));
    await tester.ensureVisible(speakButton);
    await tester.enterText(
      find.byKey(const Key('filipino-tts-input')),
      'Magandang araw. Ito ay pagsubok ng Filipino TTS.',
    );
    await tester.tap(speakButton);
    await tester.pumpAndSettle();

    expect(backend.speakCalls, 1);
    expect(
      backend.spokenText,
      'Magandang araw. Ito ay pagsubok ng Filipino TTS.',
    );
  });
}

class _FakeSpeechTestBackend implements SpeechTestBackend {
  _FakeSpeechTestBackend({
    required this.installed,
    this.voiceStatus = const FilipinoTtsVoiceStatus(
      voiceFound: false,
      installed: false,
      networkRequired: false,
      voiceName: null,
      locale: null,
    ),
  });

  bool installed;
  final FilipinoTtsVoiceStatus voiceStatus;
  int startRecordingCalls = 0;
  int transcriptionCalls = 0;
  int speakCalls = 0;
  String? spokenText;

  @override
  Future<bool> isWhisperInstalled() async => installed;

  @override
  Future<void> installWhisper({required void Function(int) onProgress}) async {
    onProgress(100);
    installed = true;
  }

  @override
  Future<void> startRecording() async {
    startRecordingCalls++;
  }

  @override
  Future<String> stopAndTranscribe() async {
    transcriptionCalls++;
    return 'Magandang umaga po.';
  }

  @override
  Future<FilipinoTtsVoiceStatus> checkFilipinoVoice() async => voiceStatus;

  @override
  Future<void> speakFilipino(String text) async {
    speakCalls++;
    spokenText = text;
  }

  @override
  Future<void> stopSpeaking() async {}

  @override
  Future<void> dispose() async {}
}
