import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:cloudinary_public/cloudinary_public.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;

class ImageUploadService {
  final CloudinaryPublic _cloudinary;

  ImageUploadService()
      : _cloudinary = CloudinaryPublic(
          dotenv.env['CLOUDINARY_CLOUD_NAME'] ?? '', // Added null check and default
          dotenv.env['CLOUDINARY_UPLOAD_PRESET'] ?? '', // Added null check and default
          cache: true, // Enable caching if desired
        );

  Future<File?> compressImage(File imageFile) async {
    try {
      final tempDir = await getTemporaryDirectory();
      final targetPath = path.join(
        tempDir.path, 
        'compressed_${path.basename(imageFile.path)}'
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
