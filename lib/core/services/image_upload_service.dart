import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:cloudinary_public/cloudinary_public.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;

/// Résultat d'upload avec détails sur les succès et échecs
class ImageUploadResult {
  /// URLs des images uploadées avec succès
  final List<String> successfulUrls;

  /// Chemins des fichiers qui ont échoué
  final List<String> failedPaths;

  /// Messages d'erreur par chemin de fichier
  final Map<String, String> errorMessages;

  ImageUploadResult({
    required this.successfulUrls,
    required this.failedPaths,
    required this.errorMessages,
  });

  /// Retourne true si au moins un fichier a été uploadé avec succès
  bool get hasSuccessfulUploads => successfulUrls.isNotEmpty;

  /// Retourne true s'il y a eu des échecs
  bool get hasFailures => failedPaths.isNotEmpty;

  /// Retourne true si tous les fichiers ont été uploadés
  bool get allSuccessful => failedPaths.isEmpty;

  /// Nombre total de fichiers traités
  int get totalProcessed => successfulUrls.length + failedPaths.length;
}

class ImageUploadService {
  final CloudinaryPublic _cloudinary;

  /// Nombre maximum de tentatives par fichier
  static const int _maxRetries = 3;

  /// Délai initial entre les tentatives (exponential backoff)
  static const Duration _initialRetryDelay = Duration(seconds: 1);

  ImageUploadService()
    : _cloudinary = CloudinaryPublic(
        dotenv.env['CLOUDINARY_CLOUD_NAME'] ??
            '', // Added null check and default
        dotenv.env['CLOUDINARY_UPLOAD_PRESET'] ??
            '', // Added null check and default
        cache: true, // Enable caching if desired
      );

  Future<File?> compressImage(File imageFile) async {
    try {
      final tempDir = await getTemporaryDirectory();
      final targetPath = path.join(
        tempDir.path,
        'compressed_${path.basename(imageFile.path)}',
      );

      var result = await FlutterImageCompress.compressAndGetFile(
        imageFile.path,
        targetPath,
        quality: 80, // Adjust quality as needed (0-100)
        minWidth: 1024, // Max width
        minHeight: 1024, // Max height
      );

      return result != null ? File(result.path) : null;
    } catch (e) {
      debugPrint('Error compressing image: $e');
      // Return original file as fallback
      return imageFile;
    }
  }

  Future<String?> uploadImage(File imageFile, {String? publicId}) async {
    try {
      // Ensure credentials are loaded and not empty
      if ((dotenv.env['CLOUDINARY_CLOUD_NAME'] ?? '').isEmpty ||
          (dotenv.env['CLOUDINARY_UPLOAD_PRESET'] ?? '').isEmpty) {
        debugPrint('Cloudinary credentials are not set in .env file.');
        return null;
      }

      // Try to compress the image first
      File? compressedFile = await compressImage(imageFile);

      // If compression failed, use original file
      final fileToUpload = compressedFile ?? imageFile;

      debugPrint('Uploading image: ${fileToUpload.path}');
      CloudinaryResponse response = await _cloudinary.uploadFile(
        CloudinaryFile.fromFile(
          fileToUpload.path,
          publicId: publicId, // Optional: specify a public_id for the image
          // resourceType: CloudinaryResourceType.Image, // Default is Image
        ),
      );
      return response.secureUrl; // Or response.url if you don't need HTTPS
    } on CloudinaryException catch (e) {
      debugPrint('Cloudinary Upload Error: ${e.message}');
      return null;
    } catch (e) {
      debugPrint('Generic Image Upload Error: $e');
      return null;
    }
  }

  /// Upload un fichier avec retry automatique et exponential backoff
  /// Ne lance jamais d'exception - retourne null en cas d'échec définitif
  Future<String?> uploadImageWithRetry(
    File imageFile, {
    String? publicId,
    int maxRetries = 3,
  }) async {
    // Vérifier les credentials une seule fois
    if ((dotenv.env['CLOUDINARY_CLOUD_NAME'] ?? '').isEmpty ||
        (dotenv.env['CLOUDINARY_UPLOAD_PRESET'] ?? '').isEmpty) {
      debugPrint('❌ Cloudinary credentials are not set in .env file.');
      return null;
    }

    // Compresser l'image une seule fois avant les retries
    File? compressedFile = await compressImage(imageFile);
    final fileToUpload = compressedFile ?? imageFile;

    String? lastError;

    for (int attempt = 1; attempt <= maxRetries; attempt++) {
      try {
        debugPrint(
          '📤 Uploading image (attempt $attempt/$maxRetries): ${fileToUpload.path}',
        );

        CloudinaryResponse response = await _cloudinary.uploadFile(
          CloudinaryFile.fromFile(fileToUpload.path, publicId: publicId),
        );

        debugPrint('✅ Upload successful: ${response.secureUrl}');
        return response.secureUrl;
      } on CloudinaryException catch (e) {
        lastError = e.message ?? 'Cloudinary error';
        debugPrint('⚠️ Cloudinary error (attempt $attempt): $lastError');
      } on SocketException catch (e) {
        lastError = 'Network error: ${e.message}';
        debugPrint('⚠️ Network error (attempt $attempt): $lastError');
      } catch (e) {
        lastError = e.toString();
        debugPrint('⚠️ Generic error (attempt $attempt): $lastError');
      }

      // Si ce n'est pas la dernière tentative, attendre avec exponential backoff
      if (attempt < maxRetries) {
        final delay =
            _initialRetryDelay * (1 << (attempt - 1)); // 1s, 2s, 4s...
        debugPrint('⏳ Waiting ${delay.inSeconds}s before retry...');
        await Future.delayed(delay);
      }
    }

    debugPrint('❌ Upload failed after $maxRetries attempts: ${imageFile.path}');
    return null;
  }

  Future<List<String>> uploadImages(List<File> imageFiles) async {
    List<String> uploadedUrls = [];
    for (File imageFile in imageFiles) {
      final url = await uploadImage(imageFile);
      if (url != null) {
        uploadedUrls.add(url);
      } else {
        // Handle individual upload failure if necessary, e.g., log or skip
        debugPrint('Failed to upload image: ${imageFile.path}');
      }
    }
    return uploadedUrls;
  }

  /// Upload plusieurs fichiers avec gestion d'erreurs robuste
  /// Ne lance JAMAIS d'exception - continue même si certains uploads échouent
  /// Retourne un ImageUploadResult avec les détails des succès et échecs
  Future<ImageUploadResult> uploadImagesWithDetails(
    List<File> imageFiles,
  ) async {
    final List<String> successfulUrls = [];
    final List<String> failedPaths = [];
    final Map<String, String> errorMessages = {};

    debugPrint('📤 Starting upload of ${imageFiles.length} file(s)...');

    for (final imageFile in imageFiles) {
      try {
        final url = await uploadImageWithRetry(
          imageFile,
          maxRetries: _maxRetries,
        );

        if (url != null) {
          successfulUrls.add(url);
          debugPrint('✅ Successfully uploaded: ${imageFile.path}');
        } else {
          failedPaths.add(imageFile.path);
          errorMessages[imageFile.path] =
              'Upload failed after $_maxRetries attempts';
          debugPrint('❌ Failed to upload (after retries): ${imageFile.path}');
        }
      } catch (e) {
        // Ce bloc ne devrait jamais être atteint car uploadImageWithRetry ne lance pas d'exception
        // mais on le garde par sécurité
        failedPaths.add(imageFile.path);
        errorMessages[imageFile.path] = e.toString();
        debugPrint('❌ Unexpected error uploading ${imageFile.path}: $e');
      }
    }

    // Log du résumé
    debugPrint(
      '📊 Upload summary: ${successfulUrls.length} success, ${failedPaths.length} failed',
    );
    if (failedPaths.isNotEmpty) {
      debugPrint('⚠️ Failed files: ${failedPaths.join(', ')}');
    }

    return ImageUploadResult(
      successfulUrls: successfulUrls,
      failedPaths: failedPaths,
      errorMessages: errorMessages,
    );
  }

  // Optional: Method to delete an image from Cloudinary by public_id
  // This requires backend authentication or a signed request,
  // as direct deletion from the client-side is often restricted for security.
  // Future<bool> deleteImage(String publicId) async {
  //   try {
  //     // Deletion typically requires admin API or signed requests.
  //     // The cloudinary_public package might not support direct deletion
  //     // without additional setup for signed requests.
  //     // Consult Cloudinary documentation for secure deletion practices.
  //     print('Deletion request for $publicId - requires backend implementation.');
  //     return false; // Placeholder
  //   } catch (e) {
  //     print('Error deleting image: $e');
  //     return false;
  //   }
  // }
}
