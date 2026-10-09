import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../data/device_chat_image_picker.dart';
import '../domain/chat_image_picker.dart';
import '../domain/gemma_chat_backend.dart';
import '../../knowledge/domain/knowledge_base.dart';
import '../../knowledge/domain/rag_prompt_builder.dart';
import '../../knowledge/domain/retrieved_passage.dart';

class GemmaChatScreen extends StatefulWidget {
  const GemmaChatScreen({
    super.key,
    required this.backend,
    this.imagePicker = const DeviceChatImagePicker(),
    this.showAppBar = true,
    this.knowledgeBase,
  });

  final GemmaChatBackend backend;
  final ChatImagePicker imagePicker;
  final bool showAppBar;
  final LocalKnowledgeBase? knowledgeBase;

  @override
  State<GemmaChatScreen> createState() => _GemmaChatScreenState();
}

enum _ModelState { checking, needsDownload, downloading, loading, ready, error }

class _ChatLine {
  _ChatLine({required this.text, required this.isUser, this.imageBytes});

  String text;
  final bool isUser;
  final Uint8List? imageBytes;
}

class _GemmaChatScreenState extends State<GemmaChatScreen> {
  final _composer = TextEditingController();
  final _huggingFaceToken = TextEditingController();
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

  @override
  void initState() {
    super.initState();
    unawaited(_checkModel());
    if (widget.knowledgeBase != null) unawaited(_checkKnowledgeBase());
  }

  @override
  void dispose() {
    _composer.dispose();
    _huggingFaceToken.dispose();
    unawaited(widget.backend.dispose());
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
            : 'EmbeddingGemma and the local index are not ready';
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
    final accessToken = _huggingFaceToken.text.trim();
    setState(() {
      _ragPreparing = true;
      _ragProgress = null;
      _ragProgressMessage = 'Preparing offline guidance…';
      _ragError = null;
    });
    try {
      await knowledgeBase.installAndIndex(
        accessToken: accessToken,
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
        _ragError = error.toString().replaceAll(accessToken, '[redacted]');
      });
    } finally {
      _huggingFaceToken.clear();
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

  @override
  Widget build(BuildContext context) {
    final ready = _modelState == _ModelState.ready;
    return Scaffold(
      appBar: widget.showAppBar
          ? AppBar(title: const Text('Gemma 4 E2B · local chat test'))
          : null,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              _buildModelStatus(context),
              if (widget.knowledgeBase != null) ...[
                const SizedBox(height: 8),
                _buildKnowledgeBaseCard(context),
              ],
              const SizedBox(height: 12),
              Expanded(
                child: ready ? _buildConversation() : _buildModelSetup(),
              ),
              const SizedBox(height: 12),
              _buildComposer(enabled: ready),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildModelStatus(BuildContext context) {
    final theme = Theme.of(context);
    final (label, icon) = switch (_modelState) {
      _ModelState.checking => ('Checking for the model…', Icons.search),
      _ModelState.needsDownload => ('Model not installed', Icons.download),
      _ModelState.downloading => (
        'Downloading model… $_downloadProgress%',
        Icons.downloading,
      ),
      _ModelState.loading => ('Loading model on this phone…', Icons.memory),
      _ModelState.ready => ('Ready to chat', Icons.check_circle_outline),
      _ModelState.error => (
        'Could not prepare the local model',
        Icons.error_outline,
      ),
    };
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: theme.colorScheme.primary),
                const SizedBox(width: 8),
                Expanded(child: Text(label, style: theme.textTheme.titleSmall)),
              ],
            ),
            if (_modelState == _ModelState.downloading) ...[
              const SizedBox(height: 8),
              LinearProgressIndicator(value: _downloadProgress / 100),
            ],
            if (_modelState == _ModelState.ready)
              Padding(
                padding: const EdgeInsets.only(left: 32, top: 4),
                child: Text(
                  'Runtime backend: ${widget.backend.activeBackendLabel}',
                ),
              ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: SelectableText(_error!),
              ),
            if (_imageError != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text('Image picker error: $_imageError'),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildModelSetup() {
    if (_modelState == _ModelState.needsDownload) {
      return Center(
        child: SingleChildScrollView(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.smart_toy_outlined, size: 56),
                const SizedBox(height: 12),
                Text(
                  'Download Gemma 4 E2B',
                  style: Theme.of(context).textTheme.headlineSmall,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                const Text(
                  'The model is about 2.6 GB. Use Wi-Fi and make sure you have '
                  'several GB of free space. It downloads into this app; it does '
                  'not reuse EdgeGallery’s model files.',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
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

    return const Center(child: CircularProgressIndicator());
  }

  Widget _buildKnowledgeBaseCard(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(
                  _ragReady ? Icons.menu_book : Icons.library_books_outlined,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Offline health and floodwater RAG',
                    style: theme.textTheme.titleSmall,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(_ragPreparing ? _ragProgressMessage : _ragStatus),
            if (_ragPreparing) ...[
              const SizedBox(height: 8),
              LinearProgressIndicator(
                value: _ragProgress == null ? null : _ragProgress! / 100,
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
            if (!_ragReady && !_ragPreparing) ...[
              const SizedBox(height: 8),
              TextField(
                key: const Key('hugging-face-token-input'),
                controller: _huggingFaceToken,
                obscureText: true,
                autocorrect: false,
                enableSuggestions: false,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  labelText: 'Hugging Face read token',
                  hintText: 'Required for first-time model download',
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Accept the Gemma terms on Hugging Face first. The token is '
                'used only for this download and is not saved by the app.',
                style: TextStyle(fontSize: 12),
              ),
            ],
            if (!_ragPreparing) ...[
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerLeft,
                child: FilledButton.tonalIcon(
                  key: const Key('prepare-rag-button'),
                  onPressed: _prepareKnowledgeBase,
                  icon: const Icon(Icons.download),
                  label: Text(
                    _ragReady ? 'Rebuild local index' : 'Prepare offline RAG',
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildConversation() {
    if (_messages.isEmpty) {
      return const Center(
        child: Text('Ask a question to check local Gemma inference.'),
      );
    }
    return ListView.builder(
      itemCount: _messages.length,
      itemBuilder: (context, index) {
        final message = _messages[index];
        return Align(
          alignment: message.isUser
              ? Alignment.centerRight
              : Alignment.centerLeft,
          child: Container(
            constraints: const BoxConstraints(maxWidth: 560),
            margin: const EdgeInsets.symmetric(vertical: 5),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: message.isUser
                  ? Theme.of(context).colorScheme.primaryContainer
                  : Theme.of(context).colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: message.isUser
                  ? CrossAxisAlignment.end
                  : CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (message.imageBytes != null)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Image.memory(
                      message.imageBytes!,
                      width: 220,
                      height: 160,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) =>
                          const SizedBox(
                            width: 220,
                            height: 80,
                            child: Center(
                              child: Text('Could not preview image'),
                            ),
                          ),
                    ),
                  ),
                if (message.imageBytes != null && message.text.isNotEmpty)
                  const SizedBox(height: 8),
                if (message.text.isNotEmpty) Text(message.text),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildComposer({required bool enabled}) {
    final controlsEnabled = enabled && !_isGenerating && !_isPickingImage;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
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
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            PopupMenuButton<bool>(
              key: const Key('attach-image-button'),
              enabled: controlsEnabled,
              tooltip: 'Add image',
              onSelected: _pickImage,
              itemBuilder: (context) => const [
                PopupMenuItem(value: true, child: Text('Take a photo')),
                PopupMenuItem(value: false, child: Text('Choose from gallery')),
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
                  border: OutlineInputBorder(),
                  hintText: 'Message the local model',
                ),
              ),
            ),
            const SizedBox(width: 8),
            IconButton.filled(
              key: const Key('send-button'),
              tooltip: 'Send',
              onPressed: controlsEnabled ? _sendMessage : null,
              icon: _isGenerating
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.send),
            ),
          ],
        ),
      ],
    );
  }
}
