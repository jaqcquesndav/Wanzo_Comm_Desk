import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:wanzo/core/services/image_upload_service.dart';

class FileStorageService {
  final ImageUploadService _imageUploadService;

  FileStorageService({ImageUploadService? imageUploadService})
    : _imageUploadService = imageUploadService ?? ImageUploadService();

  /// Uploads a profile image for the given user.
  ///
  /// Returns the download URL of the uploaded image, or null on failure.
  Future<String?> uploadProfileImage(File imageFile, String userId) async {
    try {
      debugPrint(
        '📤 Uploading profile image for user $userId. Image path: ${imageFile.path}',
      );

      // Utiliser ImageUploadService pour uploader vers Cloudinary avec retry
      final url = await _imageUploadService.uploadImageWithRetry(
        imageFile,
        publicId: 'profile_$userId',
      );

      if (url != null) {
        debugPrint('✅ Profile image uploaded successfully: $url');
        return url;
      } else {
        debugPrint('❌ Failed to upload profile image to Cloudinary');
        return null;
      }
    } catch (e) {
      debugPrint('❌ Error uploading profile image: $e');
      return null;
    }
  }
}
