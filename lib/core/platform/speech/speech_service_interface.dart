/// Interface abstraite pour le service de reconnaissance vocale
/// Permet d'avoir différentes implémentations selon la plateforme
abstract class SpeechServiceInterface {
  /// Vérifie si la reconnaissance vocale est supportée
  Future<bool> isSupported();

  /// Initialise le service
  Future<bool> initialize();

  /// Démarre l'écoute
  Future<void> startListening({
    required Function(String text, double confidence) onResult,
    Function(String status)? onStatus,
    Function(String error)? onError,
    String localeId = 'fr_FR',
    Duration listenFor = const Duration(seconds: 30),
    Duration pauseFor = const Duration(seconds: 3),
  });

  /// Arrête l'écoute
  Future<void> stopListening();

  /// Vérifie si le service est en train d'écouter
  bool get isListening;

  /// Libère les ressources
  void dispose();
}
