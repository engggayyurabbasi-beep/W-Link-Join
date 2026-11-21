import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';

class FirebaseStorageService {
  FirebaseStorageService({
    FirebaseStorage? storage,
    FirebaseAuth? auth,
  })  : _storage = storage ?? FirebaseStorage.instance,
        _auth = auth ?? FirebaseAuth.instance;

  final FirebaseStorage _storage;
  final FirebaseAuth _auth;

  Future<String> uploadGroupImage({
    required String groupId,
    required File imageFile,
  }) async {
    final user = _auth.currentUser;

    if (user == null) {
      throw StateError('Authentication required.');
    }

    if (!await imageFile.exists()) {
      throw StateError('Selected image file does not exist.');
    }

    final extension = imageFile.path.split('.').last.toLowerCase();

    const allowedExtensions = ['jpg', 'jpeg', 'png', 'webp'];

    if (!allowedExtensions.contains(extension)) {
      throw StateError('Only JPG, PNG and WebP images are allowed.');
    }

    final fileSize = await imageFile.length();

    if (fileSize == 0 || fileSize > 5 * 1024 * 1024) {
      throw StateError('Image must be between 1 byte and 5 MB.');
    }

    final contentType = switch (extension) {
      'jpg' || 'jpeg' => 'image/jpeg',
      'png' => 'image/png',
      'webp' => 'image/webp',
      _ => throw StateError('Unsupported image format.'),
    };

    final reference = _storage
        .ref()
        .child('group_images')
        .child(user.uid)
        .child('$groupId.$extension');

    await reference.putFile(
      imageFile,
      SettableMetadata(contentType: contentType),
    );

    return reference.getDownloadURL();
  }
}
