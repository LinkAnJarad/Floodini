import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data/device_chat_image_picker.dart';
import '../domain/chat_image_picker.dart';
import '../domain/gemma_chat_backend.dart';
import '../../knowledge/domain/knowledge_base.dart';
import '../../knowledge/domain/rag_prompt_builder.dart';
import '../../knowledge/domain/retrieved_passage.dart';
import '../../speech/domain/speech_test_backend.dart';
import '../../../ui/floodini_mascot.dart';
import '../../../ui/status_chip.dart';
import '../../../ui/theme.dart';
import '../../../ui/voice_waveform.dart';

class GemmaChatScreen extends StatefulWidget {
  const GemmaChatScreen({
    super.key,
    required this.backend,
    this.imagePicker = const DeviceChatImagePicker(),
    this.showAppBar = true,
    this.knowledgeBase,
    this.speech,
  });

  final GemmaChatBackend backend;
  final ChatImagePicker imagePicker;
  final bool showAppBar;
  final LocalKnowledgeBase? knowledgeBase;

  /// Enables the mic button and hands-free conversation when provided.
  final SpeechTestBackend? speech;

  @override
  State<GemmaChatScreen> createState() => _GemmaChatScreenState();
}

enum _ModelState { checking, needsDownload, downloading, loading, ready, error }

enum _Voice { idle, listening, speaking }

class _ChatLine {
  _ChatLine({required this.text, required this.isUser, this.imageBytes});

  String text;
  final bool isUser;
  final Uint8List? imageBytes;
}

class _GemmaChatScreenState extends State<GemmaChatScreen> {
  final _composer = TextEditingController();
  final _messages = <_ChatLine>[];
  _ModelState _modelState = _ModelState.checking;
  bool _isGenerating = false;
  int _downloadProgress = 0;
  String? _error;
  Uint8List? _pendingImage;
  String? _imageError;
  String? _ragError;
  String _ragStatus = 'Offline RAG is not prepared';
  String _ragProgressMessage = '';
  int? _ragProgress;
  bool _ragReady = false;
  bool _ragPreparing = false;
  bool _isPickingImage = false;
  _Voice _voice = _Voice.idle;
  bool _handsFree = false;
  String? _voiceError;

  @override
  void initState() {
    super.initState();
    _composer.addListener(() {
      if (mounted) setState(() {});
    });
    unawaited(_checkModel());
    if (widget.knowledgeBase != null) unawaited(_checkKnowledgeBase());
  }

  @override
  void dispose() {
    _composer.dispose();
    _handsFree = false;
    unawaited(widget.backend.dispose());
    unawaited(widget.speech?.dispose());
    super.dispose();
  }

  Future<void> _checkModel() async {
    setState(() {
      _modelState = _ModelState.checking;
      _error = null;
    });
    try {
      final installed = await widget.backend.isModelInstalled();
      if (!mounted) return;
      if (!installed) {
        setState(() => _modelState = _ModelState.needsDownload);
        return;
      }
      setState(() => _modelState = _ModelState.loading);
      await widget.backend.prepareChat();
      if (mounted) setState(() => _modelState = _ModelState.ready);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _modelState = _ModelState.error;
        _error = error.toString();
      });
    }
  }

  Future<void> _installModel() async {
    setState(() {
      _modelState = _ModelState.downloading;
      _downloadProgress = 0;
      _error = null;
    });
    try {
      await widget.backend.installModel(
        onProgress: (progress) {
          if (mounted) setState(() => _downloadProgress = progress);
        },
      );
      if (!mounted) return;
      setState(() => _modelState = _ModelState.loading);
      await widget.backend.prepareChat();
      if (mounted) setState(() => _modelState = _ModelState.ready);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _modelState = _ModelState.error;
        _error = error.toString();
      });
    }
  }

  Future<void> _checkKnowledgeBase() async {
    final knowledgeBase = widget.knowledgeBase;
    if (knowledgeBase == null) return;
    try {
      final ready = await knowledgeBase.restoreIfAvailable();
      if (!mounted) return;
      setState(() {
        _ragReady = ready;
        _ragStatus = ready
            ? 'Offline RAG ready · semantic retrieval on every query'
            : 'The embedding model and local index are not ready';
        _ragError = null;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _ragReady = false;
        _ragStatus = 'Offline RAG could not be restored';
        _ragError = error.toString();
      });
    }
  }

  Future<void> _prepareKnowledgeBase() async {
    final knowledgeBase = widget.knowledgeBase;
    if (knowledgeBase == null || _ragPreparing) return;
    setState(() {
      _ragPreparing = true;
      _ragProgress = null;
      _ragProgressMessage = 'Preparing offline guidance…';
      _ragError = null;
    });
    try {
      await knowledgeBase.installAndIndex(
        onProgress: (progress) {
          if (!mounted) return;
          setState(() {
            _ragProgressMessage = progress.message;
            _ragProgress = progress.percent;
          });
        },
      );
      if (!mounted) return;
      setState(() {
        _ragReady = knowledgeBase.isReady;
        _ragStatus = 'Offline RAG ready · semantic retrieval on every query';
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _ragReady = false;
        _ragStatus = 'Offline RAG setup failed';
        _ragError = error.toString();
      });
    } finally {
      if (mounted) setState(() => _ragPreparing = false);
    }
  }

  Future<void> _pickImage(bool fromCamera) async {
    if (_modelState != _ModelState.ready || _isGenerating || _isPickingImage) {
      return;
    }
    setState(() {
      _isPickingImage = true;
      _imageError = null;
    });
    try {
      final bytes = await widget.imagePicker.pickImage(fromCamera: fromCamera);
      if (mounted && bytes != null) setState(() => _pendingImage = bytes);
    } catch (error) {
      if (mounted) setState(() => _imageError = error.toString());
    } finally {
      if (mounted) setState(() => _isPickingImage = false);
    }
  }

  void _removePendingImage() {
    setState(() => _pendingImage = null);
  }

  Future<void> _sendMessage() async {
    final imageBytes = _pendingImage;
    final typedPrompt = _composer.text.trim();
    if ((typedPrompt.isEmpty && imageBytes == null) ||
        _modelState != _ModelState.ready ||
        _isGenerating) {
      return;
    }
    final prompt = typedPrompt.isEmpty ? 'Describe this image.' : typedPrompt;

    _composer.clear();
    final responseIndex = _messages.length + 1;
    setState(() {
      _messages
        ..add(_ChatLine(text: prompt, isUser: true, imageBytes: imageBytes))
        ..add(_ChatLine(text: '', isUser: false));
      _pendingImage = null;
      _imageError = null;
      _isGenerating = true;
    });

    try {
      var passages = const <RetrievedPassage>[];
      final knowledgeBase = widget.knowledgeBase;
      if (knowledgeBase != null && knowledgeBase.isReady) {
        try {
          passages = await knowledgeBase.retrieve(prompt);
        } catch (error) {
          if (mounted) {
            setState(() => _ragError = 'Retrieval failed: $error');
          }
        }
      }
      final modelPrompt = RagPromptBuilder.withContext(prompt, passages);
      await for (final token in widget.backend.sendMessage(
        modelPrompt,
        imageBytes: imageBytes,
      )) {
        if (!mounted) return;
        setState(() => _messages[responseIndex].text += token);
      }
      if (mounted && _messages[responseIndex].text.isEmpty) {
        setState(() {
          _messages[responseIndex].text =
              'The model returned no text. Try another prompt.';
        });
      }
    } catch (error) {
      if (mounted) {
        setState(
          () => _messages[responseIndex].text = 'Generation failed: $error',
        );
      }
    } finally {
      if (mounted) setState(() => _isGenerating = false);
    }
  }

  /// Listens once and sends what was heard. Tapping again cancels.
  Future<void> _voiceInput() async {
    final speech = widget.speech;
    if (speech == null || _isGenerating) return;
    if (_voice == _Voice.listening) {
      await speech.cancelListening();
      return;
    }
    final heard = await _listen(speech);
    if (heard.isNotEmpty && mounted) {
      _composer.text = heard;
      await _sendMessage();
    }
  }

  /// Listen, send, speak the reply, repeat, until toggled off or the user
  /// stays silent twice in a row.
  Future<void> _toggleHandsFree() async {
    final speech = widget.speech;
    if (speech == null) return;
    if (_handsFree) {
      setState(() => _handsFree = false);
      await speech.cancelListening();
      await speech.stopSpeaking();
      return;
    }
    setState(() => _handsFree = true);
    var silent = 0;
    while (_handsFree && mounted) {
      final heard = await _listen(speech);
      if (!_handsFree || !mounted) break;
      if (heard.isEmpty) {
        if (++silent >= 2) break;
        continue;
      }
      silent = 0;
      _composer.text = heard;
      await _sendMessage();
      if (!_handsFree || !mounted) break;
      final reply = _messages.isEmpty ? '' : _messages.last.text;
      if (reply.isEmpty) continue;
      setState(() => _voice = _Voice.speaking);
      try {
        await speech.speak(_speakable(reply));
      } catch (error) {
        if (mounted) setState(() => _voiceError = 'Speech failed: $error');
        break;
      }
    }
    if (mounted) {
      setState(() {
        _handsFree = false;
        _voice = _Voice.idle;
      });
    }
  }

  Future<String> _listen(SpeechTestBackend speech) async {
    if (_modelState != _ModelState.ready) return '';
    setState(() {
      _voice = _Voice.listening;
      _voiceError = null;
    });
    try {
      return (await speech.listen()).trim();
    } catch (error) {
      if (mounted) {
        setState(() {
          _voiceError = error.toString();
          _handsFree = false;
        });
      }
      return '';
    } finally {
      if (mounted) setState(() => _voice = _Voice.idle);
    }
  }

  /// Drops citation markers and Markdown symbols so TTS does not read them.
  static String _speakable(String text) => text
      .replaceAll(RegExp(r'[d+]'), '')
      .replaceAll(RegExp(r'[*#_`>]'), '')
      .trim();

  Future<void> _copyConversation() async {
    final transcript = _messages
        .map((m) => '${m.isUser ? "You" : "Model"}: ${m.text}')
        .join('\n\n');
    await Clipboard.setData(ClipboardData(text: transcript));
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('Conversation copied')));
  }

  // Only topics the bundled guides actually cover (floods and wound care).
  static const _quickTopics = <(String, IconData, String)>[
    ('Baha', Icons.flood_outlined, 'Ano ang dapat gawin kapag may baha?'),
    (
      'Sugat at Pagdurugo',
      Icons.healing_outlined,
      'Paano gamutin ang sugat at pagdurugo?',
    ),
    (
      'Tubig-baha',
      Icons.water_drop_outlined,
      'Ligtas bang lumusong o uminom ng tubig-baha?',
    ),
    (
      'Pagkatapos ng baha',
      Icons.cleaning_services_outlined,
      'Ano ang dapat gawin pagkatapos ng baha?',
    ),
  ];

  void _prefill(String text) {
    _composer
      ..text = text
      ..selection = TextSelection.collapsed(offset: text.length);
  }

  @override
  Widget build(BuildContext context) {
    final ready = _modelState == _ModelState.ready;
    return Scaffold(
      appBar: widget.showAppBar
          ? AppBar(title: const Text('Floodini · Chat'))
          : null,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Column(
                children: [
                  _buildModelStatus(context),
                  if (widget.knowledgeBase != null)
                    _buildKnowledgeBaseCard(context),
                ],
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: ready ? _buildConversation() : _buildModelSetup(),
              ),
            ),
            _buildComposer(enabled: ready),
          ],
        ),
      ),
    );
  }

  Widget _buildModelStatus(BuildContext context) {
    final theme = Theme.of(context);
    final ready = _modelState == _ModelState.ready;
    if (ready) {
      final guidesSaved =
          widget.knowledgeBase != null &&
          _ragReady &&
          !_ragPreparing &&
          _ragError == null;
      return Row(
        children: [
          const Flexible(
            child: StatusChip(
              label: 'Ready to chat',
              tone: StatusTone.safe,
              icon: Icons.check_circle_outline,
            ),
          ),
          if (guidesSaved) ...[
            const SizedBox(width: 8),
            const Flexible(
              child: StatusChip(
                label: 'Guides saved',
                tone: StatusTone.safe,
                icon: Icons.menu_book_outlined,
              ),
            ),
          ],
          if (_imageError != null) ...[
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                'Image picker error: $_imageError',
                style: theme.textTheme.bodySmall!.copyWith(
                  color: theme.colorScheme.error,
                ),
              ),
            ),
          ],
          const Spacer(),
          PopupMenuButton<String>(
            key: const Key('chat-menu-button'),
            tooltip: 'More',
            onSelected: (value) {
              if (value == 'copy') _copyConversation();
              if (value == 'rebuild') _prepareKnowledgeBase();
            },
            itemBuilder: (context) => [
              if (_messages.isNotEmpty)
                const PopupMenuItem(
                  value: 'copy',
                  child: Text('Copy conversation'),
                ),
              if (widget.knowledgeBase != null)
                const PopupMenuItem(
                  value: 'rebuild',
                  child: Text('Rebuild safety guides'),
                ),
            ],
          ),
        ],
      );
    }
    final (label, icon, tone) = switch (_modelState) {
      _ModelState.checking => (
        'Checking for the model…',
        Icons.search,
        StatusTone.neutral,
      ),
      _ModelState.needsDownload => (
        'Model not installed',
        Icons.download,
        StatusTone.caution,
      ),
      _ModelState.downloading => (
        'Downloading model… $_downloadProgress%',
        Icons.downloading,
        StatusTone.caution,
      ),
      _ModelState.loading => (
        'Loading model on this phone…',
        Icons.memory,
        StatusTone.neutral,
      ),
      _ModelState.error => (
        'Could not prepare the local model',
        Icons.error_outline,
        StatusTone.danger,
      ),
      _ModelState.ready => ('Ready to chat', Icons.check, StatusTone.safe),
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: StatusChip(label: label, tone: tone, icon: icon),
        ),
        if (_modelState == _ModelState.downloading) ...[
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(value: _downloadProgress / 100),
          ),
        ],
        if (_error != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: SelectableText(
              _error!,
              style: TextStyle(color: theme.colorScheme.error),
            ),
          ),
      ],
    );
  }

  Widget _buildModelSetup() {
    final theme = Theme.of(context);
    if (_modelState == _ModelState.needsDownload) {
      return Center(
        child: SingleChildScrollView(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const FloodiniMascot(height: 120),
                const SizedBox(height: 16),
                Text(
                  'Download the AI model',
                  style: theme.textTheme.headlineSmall,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  'Gemma 4 E2B is about 2.6 GB. Use Wi-Fi and keep several GB '
                  'free. It downloads into this app only.',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyLarge,
                ),
                const SizedBox(height: 20),
                FilledButton.icon(
                  key: const Key('install-model-button'),
                  onPressed: _installModel,
                  icon: const Icon(Icons.download),
                  label: const Text('Download model'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    if (_modelState == _ModelState.error) {
      return Center(
        child: FilledButton.tonal(
          key: const Key('retry-button'),
          onPressed: _checkModel,
          child: const Text('Retry model check'),
        ),
      );
    }

    return Center(
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const FloodiniMascot(height: 120),
            const SizedBox(height: 16),
            Text(
              'Ginigising si Floodini…',
              style: theme.textTheme.headlineSmall,
            ),
            const SizedBox(height: 4),
            Text(
              'Sandali lang habang naghahanda ang AI.',
              style: theme.textTheme.bodyLarge,
            ),
            const SizedBox(height: 16),
            const SizedBox(width: 160, child: LinearProgressIndicator()),
          ],
        ),
      ),
    );
  }

  Widget _buildKnowledgeBaseCard(BuildContext context) {
    final theme = Theme.of(context);
    if (_ragReady && !_ragPreparing && _ragError == null) {
      return const SizedBox.shrink();
    }
    return Card(
      margin: const EdgeInsets.only(top: 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(
                  Icons.library_books_outlined,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Offline safety guides',
                    style: theme.textTheme.titleMedium,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(_ragPreparing ? _ragProgressMessage : _ragStatus),
            if (_ragPreparing) ...[
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: _ragProgress == null ? null : _ragProgress! / 100,
                ),
              ),
            ],
            if (_ragError != null)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  _ragError!,
                  style: TextStyle(color: theme.colorScheme.error),
                ),
              ),
            if (!_ragPreparing) ...[
              const SizedBox(height: 12),
              FilledButton.tonalIcon(
                key: const Key('prepare-rag-button'),
                onPressed: _prepareKnowledgeBase,
                icon: const Icon(Icons.download),
                label: Text(
                  _ragReady ? 'Rebuild local index' : 'Prepare offline guides',
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildConversation() {
    if (_messages.isEmpty) return _buildEmptyState();
    return ListView.builder(
      reverse: false,
      padding: const EdgeInsets.symmetric(vertical: 12),
      itemCount: _messages.length,
      itemBuilder: (context, index) => _buildBubble(context, index),
    );
  }

  Widget _buildEmptyState() {
    final theme = Theme.of(context);
    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 16),
      children: [
        const Center(child: FloodiniMascot(height: 130)),
        const SizedBox(height: 12),
        Text(
          'Kumusta? Nandito si Floodini.',
          textAlign: TextAlign.center,
          style: theme.textTheme.headlineSmall,
        ),
        const SizedBox(height: 4),
        Text(
          'Magtanong sa Filipino, English, o Taglish.',
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyLarge,
        ),
        const SizedBox(height: 20),
        Text('Mabilis na tanong', style: theme.textTheme.titleSmall),
        const SizedBox(height: 8),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 8,
          crossAxisSpacing: 8,
          childAspectRatio: 2.3,
          children: [
            for (final (label, icon, prompt) in _quickTopics)
              Card(
                margin: EdgeInsets.zero,
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  key: Key('topic-$label'),
                  onTap: () => _prefill(prompt),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Row(
                      children: [
                        Icon(icon, color: theme.colorScheme.primary),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(label, style: theme.textTheme.titleSmall),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 16),
        Text(
          'Gabay ito at hindi kapalit ng propesyonal na tulong.',
          textAlign: TextAlign.center,
          style: theme.textTheme.bodySmall,
        ),
      ],
    );
  }

  Widget _buildBubble(BuildContext context, int index) {
    final theme = Theme.of(context);
    final message = _messages[index];
    final user = message.isUser;
    final waiting = !user && message.text.isEmpty && _isGenerating;
    final bubble = Container(
      constraints: const BoxConstraints(maxWidth: 520),
      margin: const EdgeInsets.symmetric(vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: user
            ? theme.colorScheme.primaryContainer
            : theme.colorScheme.surfaceContainerLowest,
        borderRadius: BorderRadius.only(
          topLeft: const Radius.circular(16),
          topRight: const Radius.circular(16),
          bottomLeft: Radius.circular(user ? 16 : 4),
          bottomRight: Radius.circular(user ? 4 : 16),
        ),
        border: user ? null : Border.all(color: context.floodini.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (message.imageBytes != null)
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.memory(
                message.imageBytes!,
                width: 220,
                height: 160,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => const SizedBox(
                  width: 220,
                  height: 80,
                  child: Center(child: Text('Could not preview image')),
                ),
              ),
            ),
          if (message.imageBytes != null && message.text.isNotEmpty)
            const SizedBox(height: 8),
          if (waiting) const _TypingDots(),
          if (message.text.isNotEmpty)
            SelectableText(
              message.text,
              style: theme.textTheme.bodyLarge!.copyWith(
                color: user
                    ? theme.colorScheme.onPrimaryContainer
                    : theme.colorScheme.onSurface,
              ),
            ),
        ],
      ),
    );
    if (user) {
      return Align(alignment: Alignment.centerRight, child: bubble);
    }
    final finished =
        message.text.isNotEmpty &&
        !(_isGenerating && index == _messages.length - 1);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.only(top: 4, right: 8),
              child: FloodiniAvatar(size: 32),
            ),
            Flexible(child: bubble),
          ],
        ),
        if (finished)
          Padding(
            padding: const EdgeInsets.only(left: 40, bottom: 4),
            child: Text(
              'Gabay ito at hindi kapalit ng propesyonal na tulong.',
              style: theme.textTheme.bodySmall,
            ),
          ),
      ],
    );
  }

  Widget _buildComposer({required bool enabled}) {
    final theme = Theme.of(context);
    final controlsEnabled = enabled && !_isGenerating && !_isPickingImage;
    final speech = widget.speech;
    final listening = _voice == _Voice.listening;
    final showSend =
        speech == null ||
        _composer.text.trim().isNotEmpty ||
        _pendingImage != null ||
        _isGenerating;
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
      decoration: BoxDecoration(
        color: theme.brightness == Brightness.dark
            ? theme.colorScheme.surfaceContainerLow
            : theme.colorScheme.surfaceContainerLowest,
        border: Border(
          top: BorderSide(color: theme.colorScheme.outlineVariant),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_voice != _Voice.idle || _voiceError != null)
            _buildVoiceBar(theme),
          if (_pendingImage != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.memory(
                      _pendingImage!,
                      width: 56,
                      height: 56,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) =>
                          const SizedBox(
                            width: 56,
                            height: 56,
                            child: Icon(Icons.broken_image_outlined),
                          ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Expanded(child: Text('Image attached')),
                  IconButton(
                    key: const Key('remove-image-button'),
                    tooltip: 'Remove image',
                    onPressed: controlsEnabled ? _removePendingImage : null,
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
            ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              PopupMenuButton<bool>(
                key: const Key('attach-image-button'),
                enabled: controlsEnabled,
                tooltip: 'Add image',
                onSelected: _pickImage,
                itemBuilder: (context) => const [
                  PopupMenuItem(value: true, child: Text('Take a photo')),
                  PopupMenuItem(
                    value: false,
                    child: Text('Choose from gallery'),
                  ),
                ],
                icon: const Icon(Icons.add_photo_alternate_outlined),
              ),
              Expanded(
                child: TextField(
                  key: const Key('chat-input'),
                  controller: _composer,
                  enabled: controlsEnabled,
                  minLines: 1,
                  maxLines: 4,
                  textInputAction: TextInputAction.send,
                  onSubmitted: (_) => _sendMessage(),
                  decoration: const InputDecoration(
                    hintText: 'I-type ang tanong…',
                  ),
                ),
              ),
              if (speech != null)
                IconButton(
                  key: const Key('hands-free-button'),
                  tooltip: _handsFree
                      ? 'Stop hands-free'
                      : 'Hands-free conversation',
                  isSelected: _handsFree,
                  onPressed: enabled && (!_isGenerating || _handsFree)
                      ? _toggleHandsFree
                      : null,
                  icon: const Icon(Icons.headset_mic_outlined),
                  selectedIcon: const Icon(Icons.headset_mic),
                ),
              const SizedBox(width: 4),
              if (showSend)
                SizedBox(
                  width: 56,
                  height: 56,
                  child: IconButton.filled(
                    key: const Key('send-button'),
                    tooltip: 'Send',
                    style: IconButton.styleFrom(
                      minimumSize: const Size(56, 56),
                    ),
                    onPressed: controlsEnabled ? _sendMessage : null,
                    icon: _isGenerating
                        ? const SizedBox.square(
                            dimension: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.send),
                  ),
                )
              else
                SizedBox(
                  width: 64,
                  height: 64,
                  child: IconButton.filled(
                    key: const Key('mic-button'),
                    tooltip: listening
                        ? 'Stop listening'
                        : 'Pindutin at magsalita',
                    style: IconButton.styleFrom(
                      minimumSize: const Size(64, 64),
                      backgroundColor: listening
                          ? theme.colorScheme.tertiary
                          : theme.colorScheme.primary,
                      foregroundColor: listening
                          ? theme.colorScheme.onTertiary
                          : theme.colorScheme.onPrimary,
                    ),
                    onPressed: enabled && !_isGenerating && !_handsFree
                        ? _voiceInput
                        : null,
                    icon: Icon(listening ? Icons.stop : Icons.mic, size: 30),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildVoiceBar(ThemeData theme) {
    final error = _voiceError != null;
    final speaking = _voice == _Voice.speaking;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: error
            ? theme.colorScheme.errorContainer
            : theme.colorScheme.tertiaryContainer.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(16),
      ),
      child: error
          ? Text(
              _voiceError!,
              style: TextStyle(color: theme.colorScheme.onErrorContainer),
            )
          : Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                VoiceWaveform(height: 32, bars: 28, active: !error),
                const SizedBox(height: 4),
                Text(
                  speaking
                      ? 'Nagsasalita si Floodini…'
                      : 'Nakikinig… magsalita na',
                  style: theme.textTheme.labelLarge,
                ),
              ],
            ),
    );
  }
}

/// Three pulsing dots shown while the model has not produced text yet.
class _TypingDots extends StatefulWidget {
  const _TypingDots();

  @override
  State<_TypingDots> createState() => _TypingDotsState();
}

class _TypingDotsState extends State<_TypingDots>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1000),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.primary;
    return Semantics(
      label: 'Floodini is typing',
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) => Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var i = 0; i < 3; i++)
              Container(
                width: 8,
                height: 8,
                margin: const EdgeInsets.symmetric(horizontal: 3, vertical: 8),
                decoration: BoxDecoration(
                  color: color.withValues(
                    alpha:
                        0.35 +
                        0.65 * ((_controller.value * 3 - i) % 3 < 1 ? 1 : 0),
                  ),
                  shape: BoxShape.circle,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
