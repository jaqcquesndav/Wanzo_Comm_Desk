import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'image_picker_service_interface.dart';

/// Implémentation du service de sélection d'images pour desktop
/// Utilise file_picker car image_picker ne supporte pas bien desktop
class DesktopImagePickerService implements ImagePickerServiceInterface {
  static DesktopImagePickerService? _instance;

  DesktopImagePickerService._();

  static DesktopImagePickerService get instance {
    _instance ??= DesktopImagePickerService._();
    return _instance!;
  }

  @override
  bool get isCameraAvailable => false; // Pas de caméra intégrée sur desktop

  @override
  bool get isGalleryAvailable => true; // Sélection de fichiers toujours disponible

  @override
  Future<File?> pickFromGallery({
    int? maxWidth,
    int? maxHeight,
    int? imageQuality,
  }) async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        allowMultiple: false,
        withData: false,
        withReadStream: false,
      );

      if (result != null && result.files.isNotEmpty) {
        final path = result.files.first.path;
        if (path != null) {
          return File(path);
        }
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
    // La caméra n'est pas disponible sur desktop
    // On redirige vers la galerie
    return pickFromGallery(
      maxWidth: maxWidth,
      maxHeight: maxHeight,
      imageQuality: imageQuality,
    );
  }

  @override
  Future<List<File>> pickMultipleImages({
    int? maxWidth,
    int? maxHeight,
    int? imageQuality,
  }) async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        allowMultiple: true,
        withData: false,
        withReadStream: false,
      );

      if (result != null && result.files.isNotEmpty) {
        return result.files
            .where((file) => file.path != null)
            .map((file) => File(file.path!))
            .toList();
      }
      return [];
    } catch (e) {
      return [];
    }
  }
}
