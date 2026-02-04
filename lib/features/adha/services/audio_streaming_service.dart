import 'dart:async';
import 'dart:math';
import 'dart:io';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:record/record.dart';
import 'package:just_audio/just_audio.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:web_socket_channel/status.dart' as status;
import 'package:path_provider/path_provider.dart';

/// Service pour gérer le streaming audio bidirectionnel avec Adha
class AudioStreamingService {
  static const int sampleRate = 16000;
  static const int channels = 1;
  static const int bitRate = 16;
  
  final AudioRecorder _audioRecorder = AudioRecorder();
  final AudioPlayer _audioPlayer = AudioPlayer();
  
  WebSocketChannel? _webSocketChannel;
  StreamSubscription<Uint8List>? _audioStreamSubscription;
  
  // Buffer pour les données audio en attente de lecture
  final List<Uint8List> _audioBuffer = [];
  bool _isBuffering = false;
  Timer? _bufferTimer;
  
  // Stream controller pour créer un flux audio personnalisé
  StreamController<List<int>>? _audioStreamController;
  
  // Streams pour notifier les changements d'état
  final _connectionStateController = StreamController<AudioConnectionState>.broadcast();
  final _audioLevelController = StreamController<double>.broadcast();
  final _isRecordingController = StreamController<bool>.broadcast();
  final _isPlayingController = StreamController<bool>.broadcast();
  
  // Getters pour les streams
  Stream<AudioConnectionState> get connectionState => _connectionStateController.stream;
  Stream<double> get audioLevel => _audioLevelController.stream;
  Stream<bool> get isRecording => _isRecordingController.stream;
  Stream<bool> get isPlaying => _isPlayingController.stream;
  
  // État actuel
  AudioConnectionState _currentState = AudioConnectionState.disconnected;
  bool _isRecordingActive = false;
  bool _isPlayingActive = false;
  String? _conversationId;
  
  // Configuration
  String? _wsUrl;
  Map<String, String>? _headers;
  
  /// Initialise le service avec l'URL WebSocket et les headers d'authentification
  void configure({
    required String wsUrl,
    Map<String, String>? headers,
  }) {
    _wsUrl = wsUrl;
    _headers = headers;
  }
  
  /// Démarre une session audio avec Adha
  Future<void> startAudioSession({
    required String conversationId,
    Map<String, dynamic>? contextInfo,
  }) async {
    if (_wsUrl == null) {
      throw Exception('Service non configuré. Appelez configure() d\'abord.');
    }
    
    try {
      _conversationId = conversationId;
      _updateConnectionState(AudioConnectionState.connecting);
      
      // Vérifier les permissions audio
      if (!await _audioRecorder.hasPermission()) {
        throw AudioPermissionException('Permission microphone refusée');
      }
      
      // Initialiser le stream controller pour l'audio
      await _initializeAudioStream();
      
      // Établir la connexion WebSocket avec headers d'authentification
      final uri = Uri.parse('$_wsUrl/audio-chat/$conversationId');
      
      _webSocketChannel = WebSocketChannel.connect(
        uri,
        protocols: ['audio-chat'],
      );
      
      // Ajouter les headers d'authentification si disponibles
      if (_headers != null) {
        debugPrint('Connexion WebSocket avec authentification pour conversation: $_conversationId');
        // Note: WebSocketChannel ne supporte pas directement les headers personnalisés
        // Pour une implémentation complète, utilisez HttpClientRequest ou une autre méthode
      }
      
      // Écouter les messages WebSocket
      _webSocketChannel!.stream.listen(
        _handleWebSocketMessage,
        onError: _handleWebSocketError,
        onDone: _handleWebSocketDone,
      );
      
      // Envoyer les métadonnées de session
      final sessionMetadata = {
        'type': 'session_start',
        'config': {
          'sample_rate': sampleRate,
          'channels': channels,
          'bit_rate': bitRate,
          'format': 'pcm16',
        },
        'context_info': contextInfo,
        'timestamp': DateTime.now().toIso8601String(),
      };
      
      _webSocketChannel!.sink.add(jsonEncode(sessionMetadata));
      _updateConnectionState(AudioConnectionState.connected);
      
    } catch (e) {
      _updateConnectionState(AudioConnectionState.error);
      rethrow;
    }
  }
  
  /// Démarre l'enregistrement et l'envoi audio
  Future<void> startRecording() async {
    if (_currentState != AudioConnectionState.connected) {
      throw Exception('Pas de connexion active');
    }
    
    try {
      // Configuration de l'enregistrement
      final config = RecordConfig(
        encoder: AudioEncoder.wav,
        sampleRate: sampleRate,
        numChannels: channels,
        bitRate: bitRate * 1000, // bitRate en bits/sec
      );
      
      // Démarrer l'enregistrement avec stream
      final audioStream = await _audioRecorder.startStream(config);
      
      _isRecordingActive = true;
      _isRecordingController.add(true);
      
      // Écouter le stream audio et l'envoyer via WebSocket
      _audioStreamSubscription = audioStream.listen(
        (audioData) {
          _sendAudioData(audioData);
          _calculateAndSendAudioLevel(audioData);
        },
        onError: (error) {
          debugPrint('Erreur stream audio: $error');
          stopRecording();
        },
      );
      
    } catch (e) {
      _isRecordingActive = false;
      _isRecordingController.add(false);
      rethrow;
    }
  }
  
  /// Arrête l'enregistrement
  Future<void> stopRecording() async {
    if (!_isRecordingActive) return;
    
    await _audioStreamSubscription?.cancel();
    await _audioRecorder.stop();
    
    _isRecordingActive = false;
    _isRecordingController.add(false);
    
    // Notifier la fin de l'enregistrement
    _webSocketChannel?.sink.add(jsonEncode({
      'type': 'recording_stopped',
      'conversation_id': _conversationId,
      'timestamp': DateTime.now().toIso8601String(),
    }));
  }
  
  /// Active/désactive le mode push-to-talk
  Future<void> togglePushToTalk(bool enabled) async {
    if (enabled && !_isRecordingActive) {
      await startRecording();
    } else if (!enabled && _isRecordingActive) {
      await stopRecording();
    }
  }
  
  /// Interrompt Adha pendant qu'il parle
  Future<void> interrupt() async {
    if (_isPlayingActive) {
      await _audioPlayer.stop();
      _isPlayingActive = false;
      _isPlayingController.add(false);
      
      // Vider le buffer audio
      _audioBuffer.clear();
      _audioStreamController?.close();
      
      // Notifier l'interruption au serveur
      _webSocketChannel?.sink.add(jsonEncode({
        'type': 'user_interrupt',
        'conversation_id': _conversationId,
        'timestamp': DateTime.now().toIso8601String(),
      }));
    }
  }
  
  /// Ajuste le volume de lecture
  Future<void> setVolume(double volume) async {
    await _audioPlayer.setVolume(volume.clamp(0.0, 1.0));
  }
  
  /// Termine la session audio
  Future<void> endSession() async {
    await stopRecording();
    
    if (_isPlayingActive) {
      await _audioPlayer.stop();
      _isPlayingActive = false;
      _isPlayingController.add(false);
    }
    
    // Nettoyer les ressources audio
    await _cleanupAudioResources();
    
    // Fermer la connexion WebSocket
    await _webSocketChannel?.sink.close(status.goingAway);
    _webSocketChannel = null;
    
    _updateConnectionState(AudioConnectionState.disconnected);
    _conversationId = null;
  }
  
  /// Gère les messages reçus via WebSocket
  void _handleWebSocketMessage(dynamic message) {
    try {
      if (message is String) {
        // Message JSON
        final Map<String, dynamic> data = jsonDecode(message);
        final type = data['type'] as String?;
        
        switch (type) {
          case 'audio_start':
            _startAudioPlayback();
            break;
            
          case 'audio_end':
            _stopAudioPlayback();
            break;
            
          case 'session_ready':
            _updateConnectionState(AudioConnectionState.ready);
            break;
            
          case 'error':
            final errorMsg = data['message'] as String? ?? 'Erreur inconnue';
            _updateConnectionState(AudioConnectionState.error);
            throw AudioStreamingException(errorMsg);
        }
      } else if (message is List<int>) {
        // Données audio binaires reçues d'Adha
        _handleAudioData(Uint8List.fromList(message));
      }
    } catch (e) {
      debugPrint('Erreur traitement message WebSocket: $e');
    }
  }
  
  /// Envoie les données audio via WebSocket  
  void _sendAudioData(Uint8List audioData) {
    if (_webSocketChannel != null && _currentState == AudioConnectionState.connected) {
      // Envoyer directement les données binaires
      _webSocketChannel!.sink.add(audioData);
    }
  }
  
  /// Initialise le stream audio pour la lecture
  Future<void> _initializeAudioStream() async {
    try {
      _audioStreamController = StreamController<List<int>>();
      
      // Le player sera initialisé lors de la première lecture
      debugPrint('Stream audio initialisé');
      
    } catch (e) {
      debugPrint('Erreur initialisation stream audio: $e');
      throw AudioStreamingException('Impossible d\'initialiser le stream audio');
    }
  }
  
  /// Démarre la lecture audio
  void _startAudioPlayback() {
    _isPlayingActive = true;
    _isPlayingController.add(true);
    _isBuffering = true;
    
    // Buffer initial avant de commencer la lecture
    _bufferTimer = Timer(const Duration(milliseconds: 100), () {
      _isBuffering = false;
      _processAudioBuffer();
    });
  }
  
  /// Arrête la lecture audio
  void _stopAudioPlayback() {
    _isPlayingActive = false;
    _isPlayingController.add(false);
    _bufferTimer?.cancel();
    _audioBuffer.clear();
  }
  
  /// Gère les données audio reçues
  void _handleAudioData(Uint8List audioData) {
    if (_isPlayingActive) {
      _audioBuffer.add(audioData);
      
      if (!_isBuffering) {
        _processAudioBuffer();
      }
    }
  }
  
  /// Processus le buffer audio et joue les données
  Future<void> _processAudioBuffer() async {
    if (_audioBuffer.isEmpty || !_isPlayingActive) return;
    
    try {
      // Combiner tous les chunks du buffer
      final totalLength = _audioBuffer.fold<int>(0, (sum, chunk) => sum + chunk.length);
      final combinedData = Uint8List(totalLength);
      
      int offset = 0;
      for (final chunk in _audioBuffer) {
        combinedData.setRange(offset, offset + chunk.length, chunk);
        offset += chunk.length;
      }
      
      // Vider le buffer
      _audioBuffer.clear();
      
      // Convertir PCM en WAV et jouer
      await _playPCMData(combinedData);
      
    } catch (e) {
      debugPrint('Erreur traitement buffer audio: $e');
    }
  }
  
  /// Convertit les données PCM en format WAV et les joue
  Future<void> _playPCMData(Uint8List pcmData) async {
    try {
      // Créer un fichier WAV temporaire
      final tempDir = await getTemporaryDirectory();
      final tempFile = File('${tempDir.path}/temp_audio_${DateTime.now().millisecondsSinceEpoch}.wav');
      
      // Générer l'en-tête WAV
      final wavData = _createWavFile(pcmData);
      await tempFile.writeAsBytes(wavData);
      
      // Jouer le fichier temporaire
      await _audioPlayer.setFilePath(tempFile.path);
      await _audioPlayer.play();
      
      // Nettoyer le fichier temporaire après lecture
      _audioPlayer.positionStream.listen((position) {
        if (position == _audioPlayer.duration) {
          tempFile.deleteSync();
        }
      });
      
    } catch (e) {
      debugPrint('Erreur lecture données PCM: $e');
    }
  }
  
  /// Crée un fichier WAV à partir de données PCM
  Uint8List _createWavFile(Uint8List pcmData) {
    final int dataSize = pcmData.length;
    final int fileSize = 36 + dataSize;
    
    final ByteData header = ByteData(44);
    
    // RIFF header
    header.setUint32(0, 0x52494646, Endian.big); // "RIFF"
    header.setUint32(4, fileSize, Endian.little);
    header.setUint32(8, 0x57415645, Endian.big); // "WAVE"
    
    // Format chunk
    header.setUint32(12, 0x666d7420, Endian.big); // "fmt "
    header.setUint32(16, 16, Endian.little); // Chunk size
    header.setUint16(20, 1, Endian.little); // Audio format (PCM)
    header.setUint16(22, channels, Endian.little); // Number of channels
    header.setUint32(24, sampleRate, Endian.little); // Sample rate
    header.setUint32(28, sampleRate * channels * 2, Endian.little); // Byte rate
    header.setUint16(32, channels * 2, Endian.little); // Block align
    header.setUint16(34, 16, Endian.little); // Bits per sample
    
    // Data chunk
    header.setUint32(36, 0x64617461, Endian.big); // "data"
    header.setUint32(40, dataSize, Endian.little);
    
    // Combiner l'en-tête et les données
    final result = Uint8List(44 + dataSize);
    result.setRange(0, 44, header.buffer.asUint8List());
    result.setRange(44, 44 + dataSize, pcmData);
    
    return result;
  }
  
  /// Nettoie les ressources audio
  Future<void> _cleanupAudioResources() async {
    _bufferTimer?.cancel();
    _audioBuffer.clear();
    await _audioStreamController?.close();
    _audioStreamController = null;
    
    // Nettoyer les fichiers temporaires
    try {
      final tempDir = await getTemporaryDirectory();
      final tempFiles = tempDir.listSync().where((file) => 
        file.path.contains('temp_audio_') && file.path.endsWith('.wav'));
      
      for (final file in tempFiles) {
        try {
          file.deleteSync();
        } catch (e) {
          debugPrint('Erreur suppression fichier temporaire: $e');
        }
      }
    } catch (e) {
      debugPrint('Erreur nettoyage fichiers temporaires: $e');
    }
  }
  
  /// Calcule et envoie le niveau audio pour la visualisation
  void _calculateAndSendAudioLevel(Uint8List audioData) {
    // Calcul simple du niveau audio (RMS)
    double sum = 0;
    for (int i = 0; i < audioData.length; i += 2) {
      if (i + 1 < audioData.length) {
        final sample = (audioData[i] | (audioData[i + 1] << 8));
        sum += sample * sample;
      }
    }
    
    final rms = sum > 0 ? sqrt(sum / (audioData.length / 2)) : 0.0;
    final normalizedLevel = (rms / 32768.0).clamp(0.0, 1.0);
    
    _audioLevelController.add(normalizedLevel);
  }
  
  void _handleWebSocketError(error) {
    debugPrint('Erreur WebSocket: $error');
    _updateConnectionState(AudioConnectionState.error);
  }
  
  void _handleWebSocketDone() {
    debugPrint('Connexion WebSocket fermée');
    _updateConnectionState(AudioConnectionState.disconnected);
  }
  
  void _updateConnectionState(AudioConnectionState newState) {
    _currentState = newState;
    _connectionStateController.add(newState);
  }
  
  /// Nettoie les ressources
  void dispose() {
    _audioStreamSubscription?.cancel();
    _audioRecorder.dispose();
    _audioPlayer.dispose();
    _webSocketChannel?.sink.close();
    
    _connectionStateController.close();
    _audioLevelController.close();
    _isRecordingController.close();
    _isPlayingController.close();
  }
}

/// États de connexion audio
enum AudioConnectionState {
  disconnected,
  connecting,
  connected,
  ready,
  error,
}

/// Exceptions spécifiques au streaming audio
class AudioStreamingException implements Exception {
  final String message;
  AudioStreamingException(this.message);
  
  @override
  String toString() => 'AudioStreamingException: $message';
}

class AudioPermissionException extends AudioStreamingException {
  AudioPermissionException(super.message);
}
