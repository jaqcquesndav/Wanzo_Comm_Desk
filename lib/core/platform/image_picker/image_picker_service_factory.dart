import '../platform_service.dart';
import 'image_picker_service_interface.dart';
import 'desktop_image_picker_service.dart';
import 'mobile_image_picker_service.dart';

/// Factory pour obtenir le service de sélection d'images approprié selon la plateforme
class ImagePickerServiceFactory {
  static ImagePickerServiceInterface? _instance;

  /// Retourne l'instance du service de sélection d'images pour la plateforme actuelle
  static ImagePickerServiceInterface getInstance() {
    if (_instance != null) return _instance!;

    final platform = PlatformService.instance;

    if (platform.isDesktop) {
      _instance = DesktopImagePickerService.instance;
    } else {
      _instance = MobileImagePickerService.instance;
    }

    return _instance!;
  }

  /// Réinitialise l'instance (utile pour les tests)
  static void reset() {
    _instance = null;
  }
}
