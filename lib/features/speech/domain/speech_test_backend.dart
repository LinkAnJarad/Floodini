abstract interface class SpeechTestBackend {
  Future<bool> isWhisperInstalled();

  Future<void> installWhisper({
    required void Function(int progress) onProgress,
  });

  /// Records from the microphone and returns the Filipino transcript.
  ///
  /// Stops by itself once speech has been heard and then goes quiet, after
  /// [maxDuration], or after [waitForSpeech] with no speech at all. Returns an
  /// empty string when nothing was said or when [cancelListening] was called.
  Future<String> listen({
    Duration maxDuration = const Duration(seconds: 28),
    Duration silenceAfterSpeech = const Duration(milliseconds: 1500),
    Duration waitForSpeech = const Duration(seconds: 8),
  });

  /// Ends an active [listen] without transcribing it.
  Future<void> cancelListening();

  Future<FilipinoTtsVoiceStatus> checkFilipinoVoice();

  /// Speaks [text] with the installed Filipino voice, or the phone's default
  /// voice when none is installed. Completes when speech finishes.
  Future<void> speak(String text);

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
