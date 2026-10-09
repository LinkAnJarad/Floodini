import 'dart:typed_data';

abstract interface class GemmaChatBackend {
  String get activeBackendLabel;

  Future<bool> isModelInstalled();

  Future<void> installModel({required void Function(int progress) onProgress});

  Future<void> prepareChat();

  Stream<String> sendMessage(String prompt, {Uint8List? imageBytes});

  Future<void> dispose();
}
