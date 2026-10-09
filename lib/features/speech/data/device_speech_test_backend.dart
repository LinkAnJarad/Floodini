import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_edge_ai/flutter_edge_ai.dart';
import 'package:record/record.dart';
import 'package:flutter_tts/flutter_tts.dart';

import '../domain/speech_test_backend.dart';

class DeviceSpeechTestBackend implements SpeechTestBackend {
  static const whisperModelUrl =
      'https://huggingface.co/litert-community/whisper-tiny/resolve/main/'
      'whisper_tiny_30s_f32.tflite';
  static const whisperTokenizerUrl =
      'https://huggingface.co/openai/whisper-tiny/resolve/main/tokenizer.json';

  final AudioRecorder _recorder = AudioRecorder();
  final FlutterTts _tts = FlutterTts();
  BytesBuilder _audio = BytesBuilder(copy: false);
  StreamSubscription<Uint8List>? _recordingSubscription;
  SpeechRecognizer? _recognizer;
  Map<String, String>? _filipinoVoice;
  bool _isRecording = false;
  Object? _recordingError;

  @override
  Future<bool> isWhisperInstalled() async =>
      FlutterEdgeAi.activeSttSpec?.sttModelType == SttModelType.whisper;

  @override
  Future<void> installWhisper({
    required void Function(int progress) onProgress,
  }) async {
    var modelProgress = 0;
    var tokenizerProgress = 0;
    void reportProgress() =>
        onProgress((modelProgress + tokenizerProgress) ~/ 2);

    await FlutterEdgeAi.installStt()
        .modelFromNetwork(whisperModelUrl)
        .tokenizerFromNetwork(whisperTokenizerUrl)
        .ofType(SttModelType.whisper)
        .withModelProgress((progress) {
          modelProgress = progress;
          reportProgress();
        })
        .withTokenizerProgress((progress) {
          tokenizerProgress = progress;
          reportProgress();
        })
        .install();
  }

  @override
  Future<void> startRecording() async {
    if (_isRecording) return;
    if (!await _recorder.hasPermission()) {
      throw StateError('Microphone permission was not granted.');
    }

    _audio = BytesBuilder(copy: false);
    _recordingError = null;
    final stream = await _recorder.startStream(
      const RecordConfig(
        encoder: AudioEncoder.pcm16bits,
        sampleRate: 16000,
        numChannels: 1,
      ),
    );
    _recordingSubscription = stream.listen(
      _audio.add,
      onError: (Object error) => _recordingError = error,
    );
    _isRecording = true;
  }

  @override
  Future<String> stopAndTranscribe() async {
    if (!_isRecording) {
      throw StateError('Start a recording before transcribing.');
    }

    await _recorder.stop();
    await _recordingSubscription?.cancel();
    _recordingSubscription = null;
    _isRecording = false;

    if (_recordingError != null) {
      throw StateError('Audio capture failed: $_recordingError');
    }
    final pcm = _audio.takeBytes();
    if (pcm.isEmpty) throw StateError('No audio was captured. Try again.');

    final whisper = FlutterEdgeAi.activeSttSpec?.sttModelType;
    if (whisper != SttModelType.whisper) {
      throw StateError('Install the Whisper STT model first.');
    }
    _recognizer ??= await FlutterEdgeAi.getActiveStt(language: 'tl');
    return _recognizer!.transcribe(pcm, language: 'tl');
  }

  @override
  Future<FilipinoTtsVoiceStatus> checkFilipinoVoice() async {
    try {
      final rawVoices = await _tts.getVoices;
      if (rawVoices is! List) return _noFilipinoVoice();

      for (final rawVoice in rawVoices) {
        if (rawVoice is! Map) continue;
        final locale = rawVoice['locale']?.toString();
        if (locale == null || !_isFilipinoLocale(locale)) continue;

        final installed = _asBool(await _tts.isLanguageInstalled(locale));
        final networkRequired = _asBool(rawVoice['network_required']);
        final name = rawVoice['name']?.toString() ?? locale;
        _filipinoVoice = {'name': name, 'locale': locale};
        return FilipinoTtsVoiceStatus(
          voiceFound: true,
          installed: installed,
          networkRequired: networkRequired,
          voiceName: name,
          locale: locale,
        );
      }
      _filipinoVoice = null;
      return _noFilipinoVoice();
    } catch (error) {
      _filipinoVoice = null;
      return FilipinoTtsVoiceStatus(
        voiceFound: false,
        installed: false,
        networkRequired: false,
        voiceName: null,
        locale: null,
        error: error.toString(),
      );
    }
  }

  static bool _isFilipinoLocale(String locale) {
    final language = locale.toLowerCase().replaceAll('_', '-').split('-').first;
    return language == 'fil' || language == 'tl';
  }

  static bool _asBool(Object? value) =>
      value == true || value == 1 || value?.toString().toLowerCase() == 'true';

  static FilipinoTtsVoiceStatus _noFilipinoVoice() =>
      const FilipinoTtsVoiceStatus(
        voiceFound: false,
        installed: false,
        networkRequired: false,
        voiceName: null,
        locale: null,
      );

  @override
  Future<void> speakFilipino(String text) async {
    final voice = _filipinoVoice;
    if (voice == null) {
      throw StateError(
        'Check for an installed Filipino voice before speaking.',
      );
    }
    await _tts.setVoice(voice);
    await _tts.setSpeechRate(0.48);
    await _tts.awaitSpeakCompletion(true);
    await _tts.speak(text);
  }

  @override
  Future<void> stopSpeaking() async {
    await _tts.stop();
  }

  @override
  Future<void> dispose() async {
    if (_isRecording) await _recorder.stop();
    await _recordingSubscription?.cancel();
    await _recognizer?.close();
    await _tts.stop();
    await _recorder.dispose();
  }
}
