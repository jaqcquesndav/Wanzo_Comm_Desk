import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'image_picker_service_interface.dart';

/// Implémentation du service de sélection d'images pour mobile
/// Utilise image_picker pour accéder à la caméra et la galerie
class MobileImagePickerService implements ImagePickerServiceInterface {
  static MobileImagePickerService? _instance;
  final ImagePicker _picker = ImagePicker();

  MobileImagePickerService._();

  static MobileImagePickerService get instance {
    _instance ??= MobileImagePickerService._();
    return _instance!;
  }

  @override
  bool get isCameraAvailable => true;

  @override
  bool get isGalleryAvailable => true;

  @override
  Future<File?> pickFromGallery({
    int? maxWidth,
    int? maxHeight,
    int? imageQuality,
  }) async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: maxWidth?.toDouble(),
        maxHeight: maxHeight?.toDouble(),
        imageQuality: imageQuality,
      );

      if (image != null) {
        return File(image.path);
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  @override
  Future<File?> pickFromCamera({
    int? maxWidth,
    int? maxHeight,
    int? imageQuality,
  }) async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.camera,
        maxWidth: maxWidth?.toDouble(),
        maxHeight: maxHeight?.toDouble(),
        imageQuality: imageQuality,
      );

      if (image != null) {
        return File(image.path);
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  @override
  Future<List<File>> pickMultipleImages({
    int? maxWidth,
    int? maxHeight,
    int? imageQuality,
  }) async {
    try {
      final List<XFile> images = await _picker.pickMultiImage(
        maxWidth: maxWidth?.toDouble(),
        maxHeight: maxHeight?.toDouble(),
        imageQuality: imageQuality,
      );

      return images.map((image) => File(image.path)).toList();
    } catch (e) {
      return [];
    }
  }
}
