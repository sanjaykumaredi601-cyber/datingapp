import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:firebase_storage/firebase_storage.dart';
import '../utils/image_compression_helper.dart';

/// Service managing photo and media uploads to Firebase Storage
/// for profile photos (`users/${uid}/photos/`) and intro recordings (`users/${uid}/intro/`).
class FirebaseMediaStorageService {
  static final FirebaseMediaStorageService _instance = FirebaseMediaStorageService._internal();
  factory FirebaseMediaStorageService() => _instance;
  FirebaseMediaStorageService._internal();

  FirebaseStorage? _storage;

  FirebaseStorage get storage {
    try {
      _storage ??= FirebaseStorage.instance;
      return _storage!;
    } catch (e) {
      debugPrint('[FirebaseMediaStorageService] Storage instance error: $e');
      rethrow;
    }
  }

  @visibleForTesting
  set storage(FirebaseStorage instance) => _storage = instance;

  /// Uploads a user profile photo to `users/${uid}/photos/${filename}`
  /// Pre-compresses image to 1080x1080 @ 75% JPEG (<350 KB) to prevent endless upload spinners
  Future<String> uploadUserPhoto({
    required String uid,
    required String localPath,
    Uint8List? fileBytes,
    String? filename,
  }) async {
    final name = filename ?? 'photo_${DateTime.now().millisecondsSinceEpoch}.jpg';
    final storagePath = 'users/$uid/photos/$name';

    try {
      debugPrint('[FirebaseMediaStorageService] Uploading photo to $storagePath...');
      final ref = storage.ref().child(storagePath);
      final metadata = SettableMetadata(
        contentType: 'image/jpeg',
        customMetadata: {'uploadedBy': uid, 'type': 'profile_photo'},
      );

      if (kIsWeb && fileBytes != null) {
        final compressedBytes = await ImageCompressionHelper.compressBytes(fileBytes);
        await ref.putData(compressedBytes, metadata).timeout(const Duration(seconds: 12));
      } else if (!kIsWeb && File(localPath).existsSync()) {
        final compressedFile = await ImageCompressionHelper.compressProfileImage(File(localPath));
        await ref.putFile(compressedFile, metadata).timeout(const Duration(seconds: 12));
      } else if (fileBytes != null) {
        final compressedBytes = await ImageCompressionHelper.compressBytes(fileBytes);
        await ref.putData(compressedBytes, metadata).timeout(const Duration(seconds: 12));
      } else {
        // Fallback for mock preview or virtual local path
        return localPath;
      }

      final downloadUrl = await ref.getDownloadURL().timeout(const Duration(seconds: 8));
      debugPrint('[FirebaseMediaStorageService] ✅ Photo uploaded successfully: $downloadUrl');
      return downloadUrl;
    } on TimeoutException {
      debugPrint('[FirebaseMediaStorageService] ⚠️ Photo upload timed out (12s). Falling back gracefully.');
      return localPath;
    } on FirebaseException catch (fe) {
      debugPrint('[FirebaseMediaStorageService] FirebaseException uploading photo: ${fe.code} - ${fe.message}');
      return localPath;
    } catch (e) {
      debugPrint('[FirebaseMediaStorageService] Error uploading photo: $e');
      return localPath;
    }
  }

  /// Uploads a voice or video intro to `users/${uid}/intro/${filename}`
  Future<String> uploadUserIntroMedia({
    required String uid,
    required String localPath,
    Uint8List? fileBytes,
    String? filename,
    bool isVideo = false,
  }) async {
    final extension = isVideo ? 'mp4' : 'm4a';
    final name = filename ?? 'intro_${DateTime.now().millisecondsSinceEpoch}.$extension';
    final storagePath = 'users/$uid/intro/$name';

    try {
      debugPrint('[FirebaseMediaStorageService] Uploading intro media to $storagePath...');
      final ref = storage.ref().child(storagePath);
      final metadata = SettableMetadata(
        contentType: isVideo ? 'video/mp4' : 'audio/mp4',
        customMetadata: {'uploadedBy': uid, 'type': 'intro_recording'},
      );

      if (kIsWeb && fileBytes != null) {
        await ref.putData(fileBytes, metadata).timeout(const Duration(seconds: 15));
      } else if (!kIsWeb && File(localPath).existsSync()) {
        await ref.putFile(File(localPath), metadata).timeout(const Duration(seconds: 15));
      } else if (fileBytes != null) {
        await ref.putData(fileBytes, metadata).timeout(const Duration(seconds: 15));
      } else {
        return localPath;
      }

      final downloadUrl = await ref.getDownloadURL().timeout(const Duration(seconds: 8));
      debugPrint('[FirebaseMediaStorageService] ✅ Intro media uploaded successfully: $downloadUrl');
      return downloadUrl;
    } on TimeoutException {
      debugPrint('[FirebaseMediaStorageService] ⚠️ Intro media upload timed out (15s). Falling back gracefully.');
      return localPath;
    } on FirebaseException catch (fe) {
      debugPrint('[FirebaseMediaStorageService] FirebaseException uploading intro: ${fe.code} - ${fe.message}');
      return localPath;
    } catch (e) {
      debugPrint('[FirebaseMediaStorageService] Error uploading intro media: $e');
      return localPath;
    }
  }
}
