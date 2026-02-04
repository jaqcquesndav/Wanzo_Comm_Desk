import '../platform_service.dart';
import 'speech_service_interface.dart';
import 'desktop_speech_service.dart';
import 'mobile_speech_service.dart';

/// Factory pour obtenir le service de reconnaissance vocale approprié selon la plateforme
class SpeechServiceFactory {
  static SpeechServiceInterface? _instance;

  /// Retourne l'instance du service de reconnaissance vocale pour la plateforme actuelle
  static SpeechServiceInterface getInstance() {
    if (_instance != null) return _instance!;

    final platform = PlatformService.instance;

    if (platform.isDesktop) {
      _instance = DesktopSpeechService.instance;
    } else {
      _instance = MobileSpeechService.instance;
    }

    return _instance!;
  }

  /// Réinitialise l'instance (utile pour les tests)
  static void reset() {
    _instance = null;
  }
}
