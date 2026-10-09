import 'dart:async';

import 'package:flutter/material.dart';

import '../domain/speech_test_backend.dart';

class SpeechTestScreen extends StatefulWidget {
  const SpeechTestScreen({
    super.key,
    required this.backend,
    this.showAppBar = true,
  });

  final SpeechTestBackend backend;
  final bool showAppBar;

  @override
  State<SpeechTestScreen> createState() => _SpeechTestScreenState();
}

class _SpeechTestScreenState extends State<SpeechTestScreen> {
  static const _sampleText =
      'Magandang araw. Ito ay pagsubok ng pagsasalita sa Filipino.';

  final _ttsController = TextEditingController(text: _sampleText);
  bool _checking = true;
  bool _whisperInstalled = false;
  bool _installing = false;
  bool _recording = false;
  bool _transcribing = false;
  bool _speaking = false;
  int _installProgress = 0;
  String? _transcript;
  String? _error;
  FilipinoTtsVoiceStatus? _voiceStatus;

  @override
  void initState() {
    super.initState();
    unawaited(_refreshStatus());
  }

  @override
  void dispose() {
    _ttsController.dispose();
    unawaited(widget.backend.dispose());
    super.dispose();
  }

  Future<void> _refreshStatus() async {
    setState(() {
      _checking = true;
      _error = null;
    });
    try {
      final installed = await widget.backend.isWhisperInstalled();
      final voiceStatus = await widget.backend.checkFilipinoVoice();
      if (!mounted) return;
      setState(() {
        _whisperInstalled = installed;
        _voiceStatus = voiceStatus;
      });
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _checking = false);
    }
  }

  Future<void> _installWhisper() async {
    setState(() {
      _installing = true;
      _installProgress = 0;
      _error = null;
    });
    try {
      await widget.backend.installWhisper(
        onProgress: (progress) {
          if (mounted) setState(() => _installProgress = progress);
        },
      );
      if (mounted) setState(() => _whisperInstalled = true);
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _installing = false);
    }
  }

  Future<void> _toggleRecording() async {
    if (_transcribing || _installing || !_whisperInstalled) return;
    if (!_recording) {
      setState(() {
        _error = null;
        _transcript = null;
      });
      try {
        await widget.backend.startRecording();
        if (mounted) setState(() => _recording = true);
      } catch (error) {
        if (mounted) setState(() => _error = error.toString());
      }
      return;
    }

    setState(() {
      _recording = false;
      _transcribing = true;
      _error = null;
    });
    try {
      final transcript = await widget.backend.stopAndTranscribe();
      if (mounted) setState(() => _transcript = transcript);
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _transcribing = false);
    }
  }

  Future<void> _checkFilipinoVoice() async {
    setState(() => _voiceStatus = null);
    try {
      final status = await widget.backend.checkFilipinoVoice();
      if (mounted) setState(() => _voiceStatus = status);
    } catch (error) {
      if (mounted) {
        setState(
          () => _voiceStatus = FilipinoTtsVoiceStatus(
            voiceFound: false,
            installed: false,
            networkRequired: false,
            voiceName: null,
            locale: null,
            error: error.toString(),
          ),
        );
      }
    }
  }

  Future<void> _speakFilipino() async {
    final text = _ttsController.text.trim();
    if (text.isEmpty || !(_voiceStatus?.canSpeak ?? false) || _speaking) return;
    setState(() {
      _speaking = true;
      _error = null;
    });
    try {
      await widget.backend.speakFilipino(text);
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _speaking = false);
    }
  }

  Future<void> _stopSpeaking() async {
    try {
      await widget.backend.stopSpeaking();
    } finally {
      if (mounted) setState(() => _speaking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: widget.showAppBar
          ? AppBar(title: const Text('Filipino speech test'))
          : null,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildSttCard(context),
              const SizedBox(height: 16),
              _buildTtsCard(context),
              if (_error != null) ...[
                const SizedBox(height: 12),
                SelectableText('Error: $_error'),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSttCard(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Filipino speech-to-text', style: theme.textTheme.titleLarge),
            const SizedBox(height: 6),
            const Text(
              'On-device Whisper · Tagalog language code “tl” · 16 kHz mono. '
              'Keep each recording under 30 seconds.',
            ),
            const SizedBox(height: 12),
            if (_checking)
              const LinearProgressIndicator()
            else if (_whisperInstalled)
              const Text('Whisper ready')
            else
              FilledButton.tonal(
                key: const Key('install-whisper-button'),
                onPressed: _installing ? null : _installWhisper,
                child: Text(
                  _installing
                      ? 'Installing Whisper… $_installProgress%'
                      : 'Install Whisper model',
                ),
              ),
            if (_installing) ...[
              const SizedBox(height: 8),
              LinearProgressIndicator(value: _installProgress / 100),
            ],
            if (_whisperInstalled) ...[
              const SizedBox(height: 8),
              FilledButton.icon(
                key: Key(
                  _recording
                      ? 'stop-transcribe-button'
                      : 'start-recording-button',
                ),
                onPressed: _transcribing ? null : _toggleRecording,
                icon: Icon(_recording ? Icons.stop : Icons.mic),
                label: Text(
                  _transcribing
                      ? 'Transcribing…'
                      : _recording
                      ? 'Stop & transcribe'
                      : 'Start recording',
                ),
              ),
            ],
            if (_recording) ...[
              const SizedBox(height: 8),
              const Text('Recording in Filipino mode…'),
            ],
            if (_transcript != null) ...[
              const SizedBox(height: 12),
              Text('Transcript', style: theme.textTheme.titleSmall),
              const SizedBox(height: 4),
              SelectableText(_transcript!),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildTtsCard(BuildContext context) {
    final theme = Theme.of(context);
    final status = _voiceStatus;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Filipino text-to-speech', style: theme.textTheme.titleLarge),
            const SizedBox(height: 6),
            const Text(
              'Checks the phone’s installed fil-PH / tl-PH system voice. '
              'It is offline only if Android reports an installed voice that '
              'does not require a network connection.',
            ),
            const SizedBox(height: 8),
            Text(_voiceStatusLabel(status)),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                key: const Key('check-filipino-voice-button'),
                onPressed: _checking ? null : _checkFilipinoVoice,
                icon: const Icon(Icons.refresh),
                label: const Text('Check Filipino voice'),
              ),
            ),
            TextField(
              key: const Key('filipino-tts-input'),
              controller: _ttsController,
              minLines: 2,
              maxLines: 4,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                labelText: 'Text to speak',
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    key: const Key('speak-filipino-button'),
                    onPressed: status?.canSpeak == true && !_speaking
                        ? _speakFilipino
                        : null,
                    icon: const Icon(Icons.volume_up),
                    label: const Text('Speak Filipino sample'),
                  ),
                ),
                if (_speaking) ...[
                  const SizedBox(width: 8),
                  IconButton(
                    tooltip: 'Stop speaking',
                    onPressed: _stopSpeaking,
                    icon: const Icon(Icons.stop),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _voiceStatusLabel(FilipinoTtsVoiceStatus? status) {
    if (_checking) return 'Checking installed system voices…';
    if (status == null) return 'Voice status not checked.';
    if (status.error != null) {
      return 'Could not inspect system TTS: ${status.error}';
    }
    if (!status.voiceFound) {
      return 'No Filipino/TL voice was listed by the current system TTS engine. '
          'Install a Filipino voice in Android text-to-speech settings, then check again.';
    }
    if (!status.installed) {
      return 'Found ${status.voiceName} (${status.locale}), but it is not installed yet.';
    }
    if (status.networkRequired) {
      return 'Installed voice: ${status.voiceName} (${status.locale}); '
          'Android reports that it requires a network connection.';
    }
    return 'Offline voice ready: ${status.voiceName} (${status.locale}).';
  }
}
