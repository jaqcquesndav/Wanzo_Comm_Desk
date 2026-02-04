import 'dart:io';

/// Interface abstraite pour le service de sélection d'images
/// Permet d'avoir différentes implémentations selon la plateforme
abstract class ImagePickerServiceInterface {
  /// Sélectionne une image depuis la galerie
  Future<File?> pickFromGallery({
    int? maxWidth,
    int? maxHeight,
    int? imageQuality,
  });

  /// Prend une photo avec la caméra
  Future<File?> pickFromCamera({
    int? maxWidth,
    int? maxHeight,
    int? imageQuality,
  });

  /// Sélectionne plusieurs images depuis la galerie
  Future<List<File>> pickMultipleImages({
    int? maxWidth,
    int? maxHeight,
    int? imageQuality,
  });

  /// Vérifie si la caméra est disponible sur cette plateforme
  bool get isCameraAvailable;

  /// Vérifie si la galerie est disponible sur cette plateforme
  bool get isGalleryAvailable;
}
