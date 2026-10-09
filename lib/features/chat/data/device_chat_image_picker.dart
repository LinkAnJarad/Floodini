import 'dart:typed_data';

import 'package:image_picker/image_picker.dart';

import '../domain/chat_image_picker.dart';

class DeviceChatImagePicker implements ChatImagePicker {
  const DeviceChatImagePicker();

  @override
  Future<Uint8List?> pickImage({required bool fromCamera}) async {
    final file = await ImagePicker().pickImage(
      source: fromCamera ? ImageSource.camera : ImageSource.gallery,
      maxWidth: 2048,
      imageQuality: 90,
    );
    return file?.readAsBytes();
  }
}
