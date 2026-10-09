import 'dart:typed_data';

import 'package:flutter_edge_ai/flutter_edge_ai.dart';

import '../domain/gemma_chat_backend.dart';

class FlutterEdgeGemmaChatBackend implements GemmaChatBackend {
  static const modelFileName = 'gemma-4-E2B-it.litertlm';
  static const modelUrl =
      'https://huggingface.co/litert-community/gemma-4-E2B-it-litert-lm/'
      'resolve/main/gemma-4-E2B-it.litertlm';

  InferenceModel? _model;
  InferenceChat? _chat;

  @override
  String get activeBackendLabel =>
      _model?.activeBackend?.name ?? 'not reported';

  @override
  Future<bool> isModelInstalled() =>
      FlutterEdgeAi.isModelInstalled(modelFileName);

  @override
  Future<void> installModel({required void Function(int progress) onProgress}) {
    return FlutterEdgeAi.installModel(
      modelType: ModelType.gemma4,
      fileType: ModelFileType.litertlm,
    ).fromNetwork(modelUrl).withProgress(onProgress).install();
  }

  @override
  Future<void> prepareChat() async {
    _model ??= await FlutterEdgeAi.getActiveModel(
      maxTokens: 2048,
      preferredBackend: PreferredBackend.gpu,
      supportImage: true,
    );
    _chat ??= await _model!.createChat(
      supportImage: true,
      maxOutputTokens: 192,
      systemInstruction:
          'You are an on-device model smoke test, not an official '
          'emergency service. For emergency or disaster-response questions, '
          'make clear that this demo is not authoritative and direct the user '
          'to current guidance from local authorities. For other questions, '
          'answer concisely.',
    );
  }

  @override
  Stream<String> sendMessage(String prompt, {Uint8List? imageBytes}) async* {
    final chat = _chat;
    if (chat == null) {
      throw StateError('The model is not ready. Install and load it first.');
    }

    final message = imageBytes == null
        ? Message.text(text: prompt, isUser: true)
        : Message.withImage(text: prompt, imageBytes: imageBytes, isUser: true);
    await chat.addQueryChunk(message);
    await for (final response in chat.generateChatResponseAsync()) {
      if (response is TextResponse) {
        yield response.token;
      }
    }
  }

  @override
  Future<void> dispose() async {
    await _model?.close();
    _model = null;
    _chat = null;
  }
}
