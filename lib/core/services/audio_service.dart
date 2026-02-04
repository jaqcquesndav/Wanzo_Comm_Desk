import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';

/// Service pour la gestion des sons dans l'application
class AudioService {
  static final AudioService _instance = AudioService._internal();
  factory AudioService() => _instance;
  
  AudioService._internal() {
    _initializeAudio();
  }

  late AudioPlayer _beepPlayer;
  bool _isInitialized = false;

  Future<void> _initializeAudio() async {
    try {
      _beepPlayer = AudioPlayer();
      await _beepPlayer.setAsset('assets/sounds/beep.mp3');
      _isInitialized = true;
      debugPrint('Service audio initialisé avec succès');
    } catch (e) {
      _isInitialized = false;
      debugPrint('Erreur lors de l\'initialisation du service audio: $e');
    }
  }

  /// Joue un bip court
  Future<void> playBeep() async {
    if (!_isInitialized) {
      await _initializeAudio();
    }
    
    try {
      if (_isInitialized) {
        await _beepPlayer.seek(Duration.zero);
        await _beepPlayer.play();
      }
    } catch (e) {
      debugPrint('Erreur lors de la lecture du bip: $e');
    }
  }

  /// Libère les ressources audio
  void dispose() {
    _beepPlayer.dispose();
  }
}
