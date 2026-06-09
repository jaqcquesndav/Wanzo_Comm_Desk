import 'dart:async';
import 'dart:math';
import 'dart:io';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:record/record.dart';
import 'package:just_audio/just_audio.dart';
import 'package:path_provider/path_provider.dart';

/// Service audio duplex ADHA — Style Gemini Live / OpenAI Realtime
///
/// Architecture v3.0.0 (desktop, mirroir du mobile) :
/// - Audio queue FIFO pour lecture séquentielle des chunks TTS
/// - Client-side VAD (Voice Activity Detection) avec silence timer
/// - Barge-in : interruption de la lecture quand l'utilisateur parle
/// - Single player listener (pas de leak)
/// - Auto-cycle : écoute → envoi REST → processing → Adha parle → écoute
///
/// IMPORTANT : ce service NE gère PAS la connexion WebSocket. L'audio est
/// envoyé via REST POST /commerce/adha/audio/stream depuis le bloc, et les
/// chunks de réponse arrivent via Socket.IO sur le canal /commerce/chat
/// (cf. AdhaStreamService). Ce service ne fait que record + playback.
///
/// Sur Windows/Linux desktop, just_audio nécessite just_audio_media_kit
/// (cf. main.dart pour l'init). Sans ce backend, les chunks TTS ne sortent
/// pas du speaker malgré la file remplie.
class AudioStreamingService {
  static const int sampleRate = 16000;
  static const int channels = 1;
  static const int bitRate = 16;

  // VAD config (similaire à Gemini: silence_duration_ms, start_of_speech_sensitivity)
  static const double vadSilenceThreshold = 0.02;
  static const int vadSilenceDurationMs = 1500;
  static const int vadSpeechMinMs = 300;

  final AudioRecorder _audioRecorder = AudioRecorder();
  final AudioPlayer _audioPlayer = AudioPlayer();

  StreamSubscription<Uint8List>? _audioStreamSubscription;
  StreamSubscription<PlayerState>? _playerStateSubscription;

  final List<Uint8List> _recordedChunks = [];

  // Audio playback queue (FIFO) — style OpenAI response.output_audio.delta
  final List<_AudioQueueItem> _audioQueue = [];
  bool _isProcessingQueue = false;

  // VAD state
  Timer? _silenceTimer;
  DateTime? _speechStartTime;
  bool vadEnabled = true;

  // Playback level simulation (pour ondes réactives pendant TTS)
  Timer? _playbackLevelTimer;
  double _playbackPhase = 0.0;

  final _connectionStateController =
      StreamController<AudioConnectionState>.broadcast();
  final _audioLevelController = StreamController<double>.broadcast();
  final _isRecordingController = StreamController<bool>.broadcast();
  final _isPlayingController = StreamController<bool>.broadcast();
  final _silenceDetectedController = StreamController<void>.broadcast();
  final _playbackCompleteController = StreamController<void>.broadcast();

  Stream<AudioConnectionState> get connectionState =>
      _connectionStateController.stream;
  Stream<double> get audioLevel => _audioLevelController.stream;
  Stream<bool> get isRecording => _isRecordingController.stream;
  Stream<bool> get isPlaying => _isPlayingController.stream;
  Stream<void> get silenceDetected => _silenceDetectedController.stream;
  Stream<void> get playbackComplete => _playbackCompleteController.stream;

  AudioConnectionState _currentState = AudioConnectionState.disconnected;
  bool _isRecordingActive = false;
  bool _isPlayingActive = false;

  AudioStreamingService() {
    _initPlayerListener();
  }

  void _initPlayerListener() {
    _playerStateSubscription = _audioPlayer.playerStateStream.listen(
      (playerState) {
        if (playerState.processingState == ProcessingState.completed) {
          _onChunkPlaybackComplete();
        }
      },
      onError: (error) {
        debugPrint('[AudioStreamingService] Player error: $error');
        _onChunkPlaybackComplete();
      },
    );
  }

  /// Initialise une session audio (vérifie permission micro). N'ouvre AUCUNE
  /// connexion réseau — l'envoi se fait via REST depuis le bloc et la
  /// réception via Socket.IO globale.
  Future<void> startAudioSession({
    required String conversationId,
    Map<String, dynamic>? contextInfo,
  }) async {
    try {
      _updateConnectionState(AudioConnectionState.connecting);

      if (!await _audioRecorder.hasPermission()) {
        throw AudioPermissionException('Permission microphone refusée');
      }

      _updateConnectionState(AudioConnectionState.connected);
      debugPrint(
        '[AudioStreamingService] ✅ Session audio prête: $conversationId',
      );
    } catch (e) {
      _updateConnectionState(AudioConnectionState.error);
      rethrow;
    }
  }

  // ==========================================================================
  // ENREGISTREMENT + VAD
  // ==========================================================================

  Future<void> startRecording() async {
    if (_currentState != AudioConnectionState.connected) {
      throw Exception('Session audio non initialisée');
    }

    try {
      _recordedChunks.clear();
      _speechStartTime = null;
      _silenceTimer?.cancel();

      final config = RecordConfig(
        encoder: AudioEncoder.pcm16bits,
        sampleRate: sampleRate,
        numChannels: channels,
        bitRate: bitRate * 1000,
      );

      final audioStream = await _audioRecorder.startStream(config);

      _isRecordingActive = true;
      _isRecordingController.add(true);

      _audioStreamSubscription = audioStream.listen(
        (audioData) {
          _recordedChunks.add(audioData);
          _calculateAndSendAudioLevel(audioData);
        },
        onError: (error) {
          debugPrint('[AudioStreamingService] Erreur stream audio: $error');
          stopRecording();
        },
      );
    } catch (e) {
      _isRecordingActive = false;
      _isRecordingController.add(false);
      rethrow;
    }
  }

  Future<String?> stopRecordingAndGetBase64() async {
    if (!_isRecordingActive) return null;

    _silenceTimer?.cancel();
    await _audioStreamSubscription?.cancel();
    await _audioRecorder.stop();

    _isRecordingActive = false;
    _isRecordingController.add(false);
    _audioLevelController.add(0.0);

    if (_recordedChunks.isEmpty) {
      debugPrint('[AudioStreamingService] Aucune donnée audio enregistrée');
      return null;
    }

    final totalLength = _recordedChunks.fold<int>(
      0,
      (sum, chunk) => sum + chunk.length,
    );
    final combinedPcm = Uint8List(totalLength);
    int offset = 0;
    for (final chunk in _recordedChunks) {
      combinedPcm.setRange(offset, offset + chunk.length, chunk);
      offset += chunk.length;
    }
    _recordedChunks.clear();

    // Minimum ~0.5s d'audio
    if (combinedPcm.length < 16000) {
      debugPrint(
        '[AudioStreamingService] Trop court (${combinedPcm.length} bytes)',
      );
      return null;
    }

    final wavData = _createWavFile(combinedPcm);
    final base64Audio = base64Encode(wavData);

    debugPrint(
      '[AudioStreamingService] Audio: ${combinedPcm.length}B PCM '
      '→ ${wavData.length}B WAV → ${base64Audio.length} chars b64',
    );

    return base64Audio;
  }

  Future<void> stopRecording() async {
    if (!_isRecordingActive) return;

    _silenceTimer?.cancel();
    await _audioStreamSubscription?.cancel();
    await _audioRecorder.stop();

    _isRecordingActive = false;
    _isRecordingController.add(false);
    _audioLevelController.add(0.0);
    _recordedChunks.clear();
  }

  // ==========================================================================
  // AUDIO QUEUE — Lecture séquentielle style OpenAI delta chunks
  // ==========================================================================

  /// Ajoute un chunk audio à la queue FIFO et démarre la lecture si idle.
  ///
  /// Garde-fou défensif : rejette un base64 vide (cas backend qui envoie un
  /// audio_chunk sans payload, ou une erreur de parsing côté Socket.IO).
  Future<void> playBase64Audio(String base64Audio, String format) async {
    if (base64Audio.isEmpty) {
      debugPrint('[AudioStreamingService] ⚠️ playBase64Audio: base64 vide, skip');
      return;
    }

    _audioQueue.add(_AudioQueueItem(base64Audio: base64Audio, format: format));
    debugPrint(
      '[AudioStreamingService] 📥 Queue: ${_audioQueue.length} chunks (format=$format, b64Len=${base64Audio.length})',
    );

    if (!_isProcessingQueue) {
      _processQueue();
    }
  }

  Future<void> _processQueue() async {
    if (_isProcessingQueue || _audioQueue.isEmpty) return;
    _isProcessingQueue = true;

    if (!_isPlayingActive) {
      _isPlayingActive = true;
      _isPlayingController.add(true);
      _startPlaybackLevel();
    }

    final item = _audioQueue.removeAt(0);

    try {
      final audioBytes = base64Decode(item.base64Audio);
      final tempDir = await getTemporaryDirectory();
      final ext = item.format == 'wav' ? 'wav' : 'mp3';
      final tempFile = File(
        '${tempDir.path}/tts_${DateTime.now().millisecondsSinceEpoch}.$ext',
      );
      await tempFile.writeAsBytes(audioBytes);

      await _audioPlayer.setFilePath(tempFile.path);
      await _audioPlayer.play();
    } catch (e) {
      debugPrint('[AudioStreamingService] Erreur lecture chunk: $e');
      _onChunkPlaybackComplete();
    }
  }

  void _onChunkPlaybackComplete() {
    _isProcessingQueue = false;
    _cleanupOldTempFiles();

    if (_audioQueue.isNotEmpty) {
      _processQueue();
    } else {
      _stopPlaybackLevel();
      _isPlayingActive = false;
      _isPlayingController.add(false);
      _playbackCompleteController.add(null);
      debugPrint('[AudioStreamingService] ✅ Queue audio terminée');
    }
  }

  /// Barge-in : interrompt la lecture et vide la queue (style Gemini/OpenAI)
  Future<void> interrupt() async {
    _audioQueue.clear();

    if (_isPlayingActive) {
      await _audioPlayer.stop();
      _stopPlaybackLevel();
      _isPlayingActive = false;
      _isPlayingController.add(false);
      _isProcessingQueue = false;
    }
    debugPrint('[AudioStreamingService] ⛔ Barge-in: queue vidée + stop');
  }

  Future<void> setVolume(double volume) async {
    await _audioPlayer.setVolume(volume.clamp(0.0, 1.0));
  }

  // ==========================================================================
  // SYNTHETIC PLAYBACK LEVEL (ondes réactives pendant TTS)
  // ==========================================================================

  void _startPlaybackLevel() {
    _playbackLevelTimer?.cancel();
    _playbackPhase = 0.0;
    final random = Random();
    _playbackLevelTimer = Timer.periodic(const Duration(milliseconds: 50), (_) {
      _playbackPhase += 0.05;
      final base =
          0.3 +
          0.15 * sin(_playbackPhase * 2 * pi) +
          0.1 * sin(_playbackPhase * 5 * pi);
      final jitter = (random.nextDouble() - 0.5) * 0.15;
      _audioLevelController.add((base + jitter).clamp(0.1, 0.85));
    });
  }

  void _stopPlaybackLevel() {
    _playbackLevelTimer?.cancel();
    _playbackLevelTimer = null;
    _playbackPhase = 0.0;
    _audioLevelController.add(0.0);
  }

  // ==========================================================================
  // SESSION
  // ==========================================================================

  Future<void> endSession() async {
    await stopRecording();
    await interrupt();
    await _cleanupAudioResources();
    _updateConnectionState(AudioConnectionState.disconnected);
  }

  // ==========================================================================
  // VAD — Voice Activity Detection client-side
  // ==========================================================================

  void _calculateAndSendAudioLevel(Uint8List audioData) {
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

    if (!vadEnabled || !_isRecordingActive) return;

    if (normalizedLevel > vadSilenceThreshold) {
      _speechStartTime ??= DateTime.now();
      _silenceTimer?.cancel();
      _silenceTimer = null;
    } else {
      if (_speechStartTime != null && _silenceTimer == null) {
        final speechDurationAtSilence =
            DateTime.now().difference(_speechStartTime!).inMilliseconds;
        _silenceTimer = Timer(
          const Duration(milliseconds: vadSilenceDurationMs),
          () {
            if (_isRecordingActive &&
                speechDurationAtSilence > vadSpeechMinMs) {
              debugPrint(
                '[AudioStreamingService] 🔇 VAD: silence détecté après '
                '${speechDurationAtSilence}ms de parole → auto-stop',
              );
              _silenceDetectedController.add(null);
            } else {
              debugPrint(
                '[AudioStreamingService] 🔇 VAD: bruit court ignoré '
                '(${speechDurationAtSilence}ms < ${vadSpeechMinMs}ms)',
              );
            }
            _speechStartTime = null;
          },
        );
      }
    }
  }

  // ==========================================================================
  // UTILITAIRES
  // ==========================================================================

  Uint8List _createWavFile(Uint8List pcmData) {
    final int dataSize = pcmData.length;
    final int fileSize = 36 + dataSize;

    final ByteData header = ByteData(44);

    header.setUint32(0, 0x52494646, Endian.big); // "RIFF"
    header.setUint32(4, fileSize, Endian.little);
    header.setUint32(8, 0x57415645, Endian.big); // "WAVE"

    header.setUint32(12, 0x666d7420, Endian.big); // "fmt "
    header.setUint32(16, 16, Endian.little);
    header.setUint16(20, 1, Endian.little); // PCM
    header.setUint16(22, channels, Endian.little);
    header.setUint32(24, sampleRate, Endian.little);
    header.setUint32(28, sampleRate * channels * 2, Endian.little);
    header.setUint16(32, channels * 2, Endian.little);
    header.setUint16(34, 16, Endian.little);

    header.setUint32(36, 0x64617461, Endian.big); // "data"
    header.setUint32(40, dataSize, Endian.little);

    final result = Uint8List(44 + dataSize);
    result.setRange(0, 44, header.buffer.asUint8List());
    result.setRange(44, 44 + dataSize, pcmData);

    return result;
  }

  void _cleanupOldTempFiles() {
    getTemporaryDirectory().then((tempDir) {
      try {
        final now = DateTime.now();
        final tempFiles = tempDir.listSync().where(
          (file) =>
              file.path.contains('tts_') &&
              (file.path.endsWith('.wav') || file.path.endsWith('.mp3')),
        );
        for (final file in tempFiles) {
          try {
            final stat = file.statSync();
            if (now.difference(stat.modified).inSeconds > 30) {
              file.deleteSync();
            }
          } catch (_) {}
        }
      } catch (_) {}
    });
  }

  Future<void> _cleanupAudioResources() async {
    _recordedChunks.clear();
    _audioQueue.clear();
    _silenceTimer?.cancel();

    try {
      final tempDir = await getTemporaryDirectory();
      final tempFiles = tempDir.listSync().where(
        (file) =>
            (file.path.contains('temp_audio_') || file.path.contains('tts_')) &&
            (file.path.endsWith('.wav') || file.path.endsWith('.mp3')),
      );
      for (final file in tempFiles) {
        try {
          file.deleteSync();
        } catch (_) {}
      }
    } catch (_) {}
  }

  void _updateConnectionState(AudioConnectionState newState) {
    _currentState = newState;
    _connectionStateController.add(newState);
  }

  void dispose() {
    _playbackLevelTimer?.cancel();
    _silenceTimer?.cancel();
    _audioStreamSubscription?.cancel();
    _playerStateSubscription?.cancel();
    _audioRecorder.dispose();
    _audioPlayer.dispose();

    _connectionStateController.close();
    _audioLevelController.close();
    _isRecordingController.close();
    _isPlayingController.close();
    _silenceDetectedController.close();
    _playbackCompleteController.close();
  }
}

class _AudioQueueItem {
  final String base64Audio;
  final String format;
  _AudioQueueItem({required this.base64Audio, required this.format});
}

/// États de connexion audio
enum AudioConnectionState { disconnected, connecting, connected, ready, error }

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
