import 'package:equatable/equatable.dart';
import 'package:hive/hive.dart';

part 'adha_stream_models.g.dart';

/// Types de chunks de streaming ADHA (v2.4.0)
///
/// Selon la documentation (Janvier 2026):
/// - chunk: Fragment de texte (multiple par réponse)
/// - end: Fin du stream (1 par réponse)
/// - error: Erreur de traitement (0-1 par réponse)
/// - tool_call: L'IA appelle une fonction (0-N par réponse)
/// - tool_result: Résultat de fonction (0-N par réponse)
/// - cancelled: Stream annulé par l'utilisateur (0-1 par réponse)
/// - heartbeat: Signal de connexion active (toutes les 30s)
@HiveType(typeId: 104)
enum AdhaStreamType {
  /// Fragment de texte de la réponse
  @HiveField(0)
  chunk,

  /// Fin du stream avec contenu complet
  @HiveField(1)
  end,

  /// Erreur pendant le traitement
  @HiveField(2)
  error,

  /// L'IA appelle une fonction
  @HiveField(3)
  toolCall,

  /// Résultat d'un appel de fonction
  @HiveField(4)
  toolResult,

  /// Stream annulé par l'utilisateur (v2.4.0)
  @HiveField(5)
  cancelled,

  /// Signal de connexion active - heartbeat toutes les 30s (v2.4.0)
  @HiveField(6)
  heartbeat;

  /// Convertit une chaîne en AdhaStreamType
  static AdhaStreamType fromString(String value) {
    switch (value) {
      case 'chunk':
        return AdhaStreamType.chunk;
      case 'end':
        return AdhaStreamType.end;
      case 'error':
        return AdhaStreamType.error;
      case 'tool_call':
        return AdhaStreamType.toolCall;
      case 'tool_result':
        return AdhaStreamType.toolResult;
      case 'cancelled':
        return AdhaStreamType.cancelled;
      case 'heartbeat':
        return AdhaStreamType.heartbeat;
      default:
        return AdhaStreamType.chunk;
    }
  }

  /// Convertit en chaîne pour JSON
  String toJsonString() {
    switch (this) {
      case AdhaStreamType.chunk:
        return 'chunk';
      case AdhaStreamType.end:
        return 'end';
      case AdhaStreamType.error:
        return 'error';
      case AdhaStreamType.toolCall:
        return 'tool_call';
      case AdhaStreamType.toolResult:
        return 'tool_result';
      case AdhaStreamType.cancelled:
        return 'cancelled';
      case AdhaStreamType.heartbeat:
        return 'heartbeat';
    }
  }
}

/// Action suggérée par l'IA (v2.4.0)
///
/// Types d'actions:
/// - navigate: Navigation vers une page
/// - action: Action à effectuer
/// - query: Requête à exécuter
/// - info: Information à afficher
@HiveType(typeId: 107)
class AdhaSuggestedAction extends Equatable {
  /// Type de l'action (navigate, action, query, info)
  @HiveField(0)
  final String type;

  /// Libellé affichable (optionnel)
  @HiveField(1)
  final String? label;

  /// Données de l'action
  @HiveField(2)
  final dynamic payload;

  const AdhaSuggestedAction({
    required this.type,
    this.label,
    required this.payload,
  });

  factory AdhaSuggestedAction.fromJson(Map<String, dynamic> json) {
    return AdhaSuggestedAction(
      type: json['type'] as String? ?? 'info',
      label: json['label'] as String?,
      payload: json['payload'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'type': type,
      if (label != null) 'label': label,
      'payload': payload,
    };
  }

  @override
  List<Object?> get props => [type, label, payload];
}

/// Métadonnées associées à un chunk de streaming
@HiveType(typeId: 105)
class AdhaStreamMetadata extends Equatable {
  /// Source du stream (ex: 'adha_ai_service')
  @HiveField(0)
  final String source;

  /// Version du protocole de streaming
  @HiveField(1)
  final String streamVersion;

  /// Indique si le stream est complet (true pour type 'end')
  @HiveField(2)
  final bool? streamComplete;

  /// Indique s'il y a une erreur (true pour type 'error')
  @HiveField(3)
  final bool? error;

  const AdhaStreamMetadata({
    required this.source,
    required this.streamVersion,
    this.streamComplete,
    this.error,
  });

  factory AdhaStreamMetadata.fromJson(Map<String, dynamic> json) {
    return AdhaStreamMetadata(
      source: json['source'] as String? ?? 'unknown',
      streamVersion: json['streamVersion'] as String? ?? '1.0.0',
      streamComplete: json['streamComplete'] as bool?,
      error: json['error'] as bool?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'source': source,
      'streamVersion': streamVersion,
      if (streamComplete != null) 'streamComplete': streamComplete,
      if (error != null) 'error': error,
    };
  }

  @override
  List<Object?> get props => [source, streamVersion, streamComplete, error];
}

/// Représente un chunk de réponse en streaming (v2.4.0)
@HiveType(typeId: 106)
class AdhaStreamChunkEvent extends Equatable {
  /// UUID unique du chunk
  @HiveField(0)
  final String id;

  /// ID du message original de l'utilisateur
  @HiveField(1)
  final String requestMessageId;

  /// ID de la conversation
  @HiveField(2)
  final String conversationId;

  /// Type de chunk (chunk, end, error, tool_call, tool_result, cancelled, heartbeat)
  @HiveField(3)
  final AdhaStreamType type;

  /// Contenu du chunk
  @HiveField(4)
  final String content;

  /// Numéro de séquence du chunk
  @HiveField(5)
  final int chunkId;

  /// Horodatage du chunk
  @HiveField(6)
  final DateTime timestamp;

  /// ID de l'utilisateur
  @HiveField(7)
  final String userId;

  /// ID de la compagnie
  @HiveField(8)
  final String companyId;

  /// Nombre total de chunks (présent uniquement pour 'end')
  @HiveField(9)
  final int? totalChunks;

  /// Détails de traitement (présent pour 'end')
  @HiveField(10)
  final Map<String, dynamic>? processingDetails;

  /// Métadonnées du stream
  @HiveField(11)
  final AdhaStreamMetadata? metadata;

  /// Actions suggérées par l'IA (v2.4.0) - présent pour 'end'
  @HiveField(12)
  final List<AdhaSuggestedAction>? suggestedActions;

  const AdhaStreamChunkEvent({
    required this.id,
    required this.requestMessageId,
    required this.conversationId,
    required this.type,
    required this.content,
    required this.chunkId,
    required this.timestamp,
    required this.userId,
    required this.companyId,
    this.totalChunks,
    this.processingDetails,
    this.metadata,
    this.suggestedActions,
  });

  factory AdhaStreamChunkEvent.fromJson(Map<String, dynamic> json) {
    return AdhaStreamChunkEvent(
      id: json['id'] as String? ?? '',
      requestMessageId: json['requestMessageId'] as String? ?? '',
      conversationId: json['conversationId'] as String? ?? '',
      type: AdhaStreamType.fromString(json['type'] as String? ?? 'chunk'),
      content: json['content'] as String? ?? '',
      chunkId: json['chunkId'] as int? ?? 0,
      timestamp:
          json['timestamp'] != null
              ? DateTime.parse(json['timestamp'] as String)
              : DateTime.now(),
      userId: json['userId'] as String? ?? '',
      companyId: json['companyId'] as String? ?? '',
      totalChunks: json['totalChunks'] as int?,
      processingDetails: json['processingDetails'] as Map<String, dynamic>?,
      metadata:
          json['metadata'] != null
              ? AdhaStreamMetadata.fromJson(
                json['metadata'] as Map<String, dynamic>,
              )
              : null,
      suggestedActions:
          json['suggestedActions'] != null
              ? (json['suggestedActions'] as List<dynamic>)
                  .map(
                    (a) =>
                        AdhaSuggestedAction.fromJson(a as Map<String, dynamic>),
                  )
                  .toList()
              : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'requestMessageId': requestMessageId,
      'conversationId': conversationId,
      'type': type.toJsonString(),
      'content': content,
      'chunkId': chunkId,
      'timestamp': timestamp.toIso8601String(),
      'userId': userId,
      'companyId': companyId,
      if (totalChunks != null) 'totalChunks': totalChunks,
      if (processingDetails != null) 'processingDetails': processingDetails,
      if (metadata != null) 'metadata': metadata!.toJson(),
      if (suggestedActions != null)
        'suggestedActions': suggestedActions!.map((a) => a.toJson()).toList(),
    };
  }

  /// Vérifie si le chunk indique la fin du stream
  bool get isEndOfStream => type == AdhaStreamType.end;

  /// Vérifie si le chunk indique une erreur
  bool get isError => type == AdhaStreamType.error;

  /// Vérifie si le chunk est un fragment de texte normal
  bool get isTextChunk => type == AdhaStreamType.chunk;

  /// Vérifie si le chunk est lié à un appel de fonction
  bool get isToolRelated =>
      type == AdhaStreamType.toolCall || type == AdhaStreamType.toolResult;

  /// Vérifie si le stream a été annulé
  bool get isCancelled => type == AdhaStreamType.cancelled;

  /// Vérifie si c'est un heartbeat
  bool get isHeartbeat => type == AdhaStreamType.heartbeat;

  @override
  List<Object?> get props => [
    id,
    requestMessageId,
    conversationId,
    type,
    content,
    chunkId,
    timestamp,
    userId,
    companyId,
    totalChunks,
    processingDetails,
    metadata,
    suggestedActions,
  ];
}

/// Configuration pour le streaming ADHA
class AdhaStreamConfig {
  /// URL du WebSocket
  final String websocketUrl;

  /// Timeout de connexion en secondes
  final int connectionTimeout;

  /// Timeout de réponse en secondes
  final int responseTimeout;

  /// Nombre maximum de tentatives de reconnexion
  final int maxReconnectAttempts;

  /// Délai entre les tentatives de reconnexion en millisecondes
  final int reconnectDelayMs;

  const AdhaStreamConfig({
    required this.websocketUrl,
    this.connectionTimeout = 10,
    this.responseTimeout = 30,
    this.maxReconnectAttempts = 3,
    this.reconnectDelayMs = 1000,
  });

  /// Configuration par défaut
  factory AdhaStreamConfig.defaultConfig(String companyId) {
    return AdhaStreamConfig(
      websocketUrl: 'wss://api.wanzo.com/ws/adha-chat/$companyId',
    );
  }
}
