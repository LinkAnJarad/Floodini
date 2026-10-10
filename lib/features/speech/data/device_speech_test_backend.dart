import 'dart:async';
import 'dart:math' as math;
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
  double _levelDb = -100;
  Completer<void>? _listening;
  bool _listenCancelled = false;

  // ponytail: fixed dBFS gate for speech vs. room noise; make it adaptive
  // (track the noise floor) if it misfires on noisy phones.
  static const speechThresholdDb = -38.0;

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

  Future<void> _startRecording() async {
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
      _onAudioChunk,
      onError: (Object error) => _recordingError = error,
    );
    _isRecording = true;
  }

  Future<String> _stopAndTranscribe() async {
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

  void _onAudioChunk(Uint8List chunk) {
    _audio.add(chunk);
    final bytes = chunk.offsetInBytes.isEven
        ? chunk
        : Uint8List.fromList(chunk);
    final samples = bytes.buffer.asInt16List(
      bytes.offsetInBytes,
      bytes.lengthInBytes ~/ 2,
    );
    if (samples.isEmpty) return;
    var sum = 0.0;
    for (final sample in samples) {
      sum += sample * sample;
    }
    final rms = math.sqrt(sum / samples.length) / 32768;
    _levelDb = rms <= 0 ? -100 : 20 * math.log(rms) / math.ln10;
  }

  @override
  Future<String> listen({
    Duration maxDuration = const Duration(seconds: 28),
    Duration silenceAfterSpeech = const Duration(milliseconds: 1500),
    Duration waitForSpeech = const Duration(seconds: 8),
  }) async {
    if (_listening != null) return '';
    _listenCancelled = false;
    final done = _listening = Completer<void>();
    _levelDb = -100;
    try {
      await _startRecording();
      final clock = Stopwatch()..start();
      var heardSpeech = false;
      var lastLoud = Duration.zero;
      while (!done.isCompleted) {
        await Future.any([
          Future<void>.delayed(const Duration(milliseconds: 100)),
          done.future,
        ]);
        final now = clock.elapsed;
        if (_levelDb > speechThresholdDb) {
          heardSpeech = true;
          lastLoud = now;
        }
        if (now >= maxDuration ||
            (heardSpeech && now - lastLoud >= silenceAfterSpeech) ||
            (!heardSpeech && now >= waitForSpeech)) {
          break;
        }
      }
      if (_listenCancelled || !heardSpeech) {
        await _discardRecording();
        return '';
      }
      return await _stopAndTranscribe();
    } catch (_) {
      await _discardRecording();
      rethrow;
    } finally {
      _listening = null;
    }
  }

  @override
  Future<void> cancelListening() async {
    _listenCancelled = true;
    final done = _listening;
    if (done != null && !done.isCompleted) done.complete();
  }

  Future<void> _discardRecording() async {
    if (!_isRecording) return;
    await _recorder.stop();
    await _recordingSubscription?.cancel();
    _recordingSubscription = null;
    _isRecording = false;
    _audio.clear();
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

  Future<Map<String, String>?> _findFilipinoVoiceOrNull() async {
    final status = await checkFilipinoVoice();
    return status.canSpeak ? _filipinoVoice : null;
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
  Future<void> speak(String text) async {
    _filipinoVoice ??= await _findFilipinoVoiceOrNull();
    final voice = _filipinoVoice;
    if (voice != null) await _tts.setVoice(voice);
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
    await cancelListening();
    if (_isRecording) await _recorder.stop();
    await _recordingSubscription?.cancel();
    await _recognizer?.close();
    await _tts.stop();
    await _recorder.dispose();
  }
}
