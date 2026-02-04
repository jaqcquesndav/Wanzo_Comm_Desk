import 'speech_service_interface.dart';

/// Implémentation du service de reconnaissance vocale pour desktop
/// Sur desktop Windows, la reconnaissance vocale n'est pas supportée nativement par Flutter
/// Cette implémentation retourne toujours false pour isSupported()
class DesktopSpeechService implements SpeechServiceInterface {
  static DesktopSpeechService? _instance;

  DesktopSpeechService._();

  static DesktopSpeechService get instance {
    _instance ??= DesktopSpeechService._();
    return _instance!;
  }

  bool _isListening = false;

  @override
  Future<bool> isSupported() async {
    // La reconnaissance vocale n'est pas bien supportée sur desktop
    // Les utilisateurs doivent utiliser la saisie texte
    return false;
  }

  @override
  Future<bool> initialize() async {
    return false;
  }

  @override
  Future<void> startListening({
    required Function(String text, double confidence) onResult,
    Function(String status)? onStatus,
    Function(String error)? onError,
    String localeId = 'fr_FR',
    Duration listenFor = const Duration(seconds: 30),
    Duration pauseFor = const Duration(seconds: 3),
  }) async {
    onError?.call(
      'La reconnaissance vocale n\'est pas disponible sur desktop. Utilisez la saisie texte.',
    );
  }

  @override
  Future<void> stopListening() async {
    _isListening = false;
  }

  @override
  bool get isListening => _isListening;

  @override
  void dispose() {
    _isListening = false;
  }
}
