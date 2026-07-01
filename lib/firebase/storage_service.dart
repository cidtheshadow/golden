import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';

class StorageService {
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  Future<String?> uploadProfileImage(
    String userId,
    Uint8List imageBytes, {
    String? contentType,
  }) async {
    try {
      final authUid = _auth.currentUser?.uid;
      if (authUid == null) {
        debugPrint('Error uploading image: user not authenticated');
        return null;
      }

      // Always write to the authenticated user's object to satisfy ownership rules.
      final ownerUid = authUid;
      if (userId != authUid) {
        debugPrint(
          '[StorageService] uploadProfileImage owner mismatch. '
          'Requested=$userId Auth=$authUid. Using Auth UID.',
        );
      }

      final ref = _storage.ref().child('profile_images').child('$ownerUid.jpg');
      final uploadTask = ref.putData(
        imageBytes,
        SettableMetadata(contentType: _normalizeImageContentType(contentType)),
      );
      final snapshot = await uploadTask.whenComplete(() {});
      return await snapshot.ref.getDownloadURL();
    } catch (e) {
      debugPrint('Error uploading image: $e');
      return null;
    }
  }

  String _normalizeImageContentType(String? rawContentType) {
    final normalized = (rawContentType ?? '').trim().toLowerCase();
    if (normalized.startsWith('image/')) {
      return normalized;
    }
    return 'image/jpeg';
  }
}
