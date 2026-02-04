import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:speech_to_text/speech_recognition_result.dart';
import 'speech_service_interface.dart';

/// Implémentation du service de reconnaissance vocale pour mobile
/// Utilise speech_to_text pour la reconnaissance vocale native
class MobileSpeechService implements SpeechServiceInterface {
  static MobileSpeechService? _instance;
  final stt.SpeechToText _speech = stt.SpeechToText();

  MobileSpeechService._();

  static MobileSpeechService get instance {
    _instance ??= MobileSpeechService._();
    return _instance!;
  }

  bool _isInitialized = false;
  Function(String text, double confidence)? _onResult;
  Function(String status)? _onStatus;
  Function(String error)? _onError;

  @override
  Future<bool> isSupported() async {
    return true;
  }

  @override
  Future<bool> initialize() async {
    if (_isInitialized) return true;

    _isInitialized = await _speech.initialize(
      onStatus: (status) => _onStatus?.call(status),
      onError: (error) => _onError?.call(error.errorMsg),
    );

    return _isInitialized;
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
    _onResult = onResult;
    _onStatus = onStatus;
    _onError = onError;

    if (!_isInitialized) {
      final success = await initialize();
      if (!success) {
        onError?.call('Impossible d\'initialiser la reconnaissance vocale');
        return;
      }
    }

    await _speech.listen(
      onResult: _handleResult,
      listenFor: listenFor,
      pauseFor: pauseFor,
      listenOptions: stt.SpeechListenOptions(partialResults: true),
      localeId: localeId,
    );
  }

  void _handleResult(SpeechRecognitionResult result) {
    _onResult?.call(result.recognizedWords, result.confidence);
  }

  @override
  Future<void> stopListening() async {
    await _speech.stop();
  }

  @override
  bool get isListening => _speech.isListening;

  @override
  void dispose() {
    _speech.stop();
    _onResult = null;
    _onStatus = null;
    _onError = null;
  }
}
