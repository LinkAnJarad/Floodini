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
        )
        .fromNetwork(modelUrl, foreground: true)
        .withProgress(onProgress)
        .install();
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
          'You are an offline disaster-aid demo focused on immediate flood '
          'danger and basic floodwater or wound safety. You do not receive '
          'current weather, evacuation orders, road conditions, or facility '
          'availability; never claim those live facts. If someone may be in '
          'immediate danger, say not to enter floodwater, advise moving to '
          'higher safe ground only if reachable without entering water, and '
          'suggest contacting local responders when possible. Do not diagnose '
          'or prescribe. When OFFLINE KNOWLEDGE passages are supplied, ground '
          'specific guidance in them and cite their bracketed source numbers. '
          'If no relevant passage is supplied, say the local library has no '
          'matching verified guidance; do not invent detailed medical advice. '
          'This demo is not an official emergency service. Answer concisely, in '
          'the same language the user writes or speaks (English, Filipino, or '
          'Taglish).',
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
