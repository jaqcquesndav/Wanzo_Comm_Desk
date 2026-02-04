import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;

/// Service pour détecter la plateforme et adapter le comportement
class PlatformService {
  static PlatformService? _instance;

  PlatformService._();

  static PlatformService get instance {
    _instance ??= PlatformService._();
    return _instance!;
  }

  /// Vérifie si l'app tourne sur desktop (Windows, macOS, Linux)
  bool get isDesktop {
    if (kIsWeb) return false;
    return Platform.isWindows || Platform.isMacOS || Platform.isLinux;
  }

  /// Vérifie si l'app tourne sur mobile (Android, iOS)
  bool get isMobile {
    if (kIsWeb) return false;
    return Platform.isAndroid || Platform.isIOS;
  }

  /// Vérifie si l'app tourne sur Windows
  bool get isWindows {
    if (kIsWeb) return false;
    return Platform.isWindows;
  }

  /// Vérifie si l'app tourne sur macOS
  bool get isMacOS {
    if (kIsWeb) return false;
    return Platform.isMacOS;
  }

  /// Vérifie si l'app tourne sur Linux
  bool get isLinux {
    if (kIsWeb) return false;
    return Platform.isLinux;
  }

  /// Vérifie si l'app tourne sur Android
  bool get isAndroid {
    if (kIsWeb) return false;
    return Platform.isAndroid;
  }

  /// Vérifie si l'app tourne sur iOS
  bool get isIOS {
    if (kIsWeb) return false;
    return Platform.isIOS;
  }

  /// Vérifie si l'app tourne sur le web
  bool get isWeb => kIsWeb;

  /// Retourne le nom de la plateforme actuelle
  String get platformName {
    if (kIsWeb) return 'Web';
    if (Platform.isWindows) return 'Windows';
    if (Platform.isMacOS) return 'macOS';
    if (Platform.isLinux) return 'Linux';
    if (Platform.isAndroid) return 'Android';
    if (Platform.isIOS) return 'iOS';
    return 'Unknown';
  }

  /// Vérifie si la fonctionnalité caméra est supportée
  bool get isCameraSupported => isMobile || isMacOS;

  /// Vérifie si le scanner de code-barres est supporté
  bool get isBarcodeScennerSupported => isMobile;

  /// Vérifie si la reconnaissance vocale est supportée
  bool get isSpeechToTextSupported => isMobile || isMacOS;

  /// Vérifie si les notifications locales sont supportées
  bool get isLocalNotificationsSupported => !isWeb;

  /// Vérifie si le partage natif est supporté
  bool get isShareSupported => !isWeb;

  /// Retourne la largeur minimale pour le mode desktop
  double get desktopMinWidth => 1024.0;

  /// Retourne la largeur minimale pour le mode tablette
  double get tabletMinWidth => 600.0;
}
