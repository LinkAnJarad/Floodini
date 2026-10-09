abstract interface class SpeechTestBackend {
  Future<bool> isWhisperInstalled();

  Future<void> installWhisper({
    required void Function(int progress) onProgress,
  });

  Future<void> startRecording();

  Future<String> stopAndTranscribe();

  Future<FilipinoTtsVoiceStatus> checkFilipinoVoice();

  Future<void> speakFilipino(String text);

  Future<void> stopSpeaking();

  Future<void> dispose();
}

class FilipinoTtsVoiceStatus {
  const FilipinoTtsVoiceStatus({
    required this.voiceFound,
    required this.installed,
    required this.networkRequired,
    required this.voiceName,
    required this.locale,
    this.error,
  });

  final bool voiceFound;
  final bool installed;
  final bool networkRequired;
  final String? voiceName;
  final String? locale;
  final String? error;

  bool get canSpeak => voiceFound && installed;
  bool get availableOffline => canSpeak && !networkRequired;
}
