import 'dart:typed_data';

abstract interface class ChatImagePicker {
  Future<Uint8List?> pickImage({required bool fromCamera});
}
