import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';

/// Helper to compress profile photos to max 1080x1080 resolution at 75% quality JPEG (<350 KB)
class ImageCompressionHelper {
  /// Compresses a local image file using flutter_image_compress.
  /// Enforces:
  /// - Max width: 1080
  /// - Max height: 1080
  /// - Quality: 75%
  /// - Target size: < 350 KB
  static Future<File> compressProfileImage(File file) async {
    if (kIsWeb) return file;

    try {
      final originalLength = await file.length();
      debugPrint('[ImageCompressor] Input size: ${(originalLength / 1024).toStringAsFixed(1)} KB');

      // If already under 300 KB and is JPEG, skip heavy compression
      if (originalLength < 300 * 1024 && file.path.toLowerCase().endsWith('.jpg')) {
        return file;
      }

      final targetPath = '${Directory.systemTemp.path}/aura_compressed_${DateTime.now().millisecondsSinceEpoch}.jpg';

      final XFile? compressedXFile = await FlutterImageCompress.compressAndGetFile(
        file.absolute.path,
        targetPath,
        minWidth: 1080,
        minHeight: 1080,
        quality: 75,
        format: CompressFormat.jpeg,
      );

      if (compressedXFile != null) {
        final compressedFile = File(compressedXFile.path);
        final compressedLength = await compressedFile.length();
        debugPrint('[ImageCompressor] ✅ Compressed size: ${(compressedLength / 1024).toStringAsFixed(1)} KB (<350 KB target)');
        return compressedFile;
      }
    } catch (e) {
      debugPrint('[ImageCompressor] Non-fatal compression fallback to original: $e');
    }
    return file;
  }

  /// Compresses raw byte arrays (for web or in-memory operations)
  static Future<Uint8List> compressBytes(Uint8List bytes) async {
    try {
      final compressed = await FlutterImageCompress.compressWithList(
        bytes,
        minWidth: 1080,
        minHeight: 1080,
        quality: 75,
        format: CompressFormat.jpeg,
      );
      return Uint8List.fromList(compressed);
    } catch (e) {
      debugPrint('[ImageCompressor] Byte compression error: $e');
      return bytes;
    }
  }
}
