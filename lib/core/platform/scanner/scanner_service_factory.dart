import '../platform_service.dart';
import 'scanner_service_interface.dart';
import 'desktop_scanner_service.dart';
import 'mobile_scanner_service.dart';

/// Factory pour obtenir le service de scan approprié selon la plateforme
class ScannerServiceFactory {
  static ScannerServiceInterface? _instance;

  /// Retourne l'instance du service de scan pour la plateforme actuelle
  static ScannerServiceInterface getInstance() {
    if (_instance != null) return _instance!;

    final platform = PlatformService.instance;

    if (platform.isDesktop) {
      _instance = DesktopScannerService.instance;
    } else {
      _instance = MobileScannerService.instance;
    }

    return _instance!;
  }

  /// Réinitialise l'instance (utile pour les tests)
  static void reset() {
    _instance = null;
  }
}
