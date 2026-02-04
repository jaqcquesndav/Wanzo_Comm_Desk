/// Module ADHA - Exports pour le streaming
///
/// Ce fichier exporte tous les composants nécessaires pour le streaming
/// des réponses ADHA (Janvier 2026)
library;

// Modèles de streaming
export 'models/adha_stream_models.dart';

// Service de streaming
export 'services/adha_stream_service.dart';

// Widget de streaming
export 'screens/streaming_message_widget.dart';

// Événements et états (déjà dans les fichiers existants)
// - StreamChunkReceived, StreamCompleted, StreamError, etc. dans adha_event.dart
// - AdhaStreaming, AdhaStreamConnected, etc. dans adha_state.dart
