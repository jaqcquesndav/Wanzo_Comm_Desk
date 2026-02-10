import 'package:equatable/equatable.dart';
import '../models/adha_message.dart';

/// États pour le bloc Adha
abstract class AdhaState extends Equatable {
  const AdhaState();

  @override
  List<Object?> get props => [];
}

/// État initial du bloc Adha
class AdhaInitial extends AdhaState {
  const AdhaInitial();
}

/// Chargement en cours
class AdhaLoading extends AdhaState {
  const AdhaLoading();
}

/// Erreur durant une opération
class AdhaError extends AdhaState {
  /// Message d'erreur
  final String message;

  const AdhaError(this.message);

  @override
  List<Object?> get props => [message];
}

/// Conversation active avec Adha
class AdhaConversationActive extends AdhaState {
  /// Conversation en cours
  final AdhaConversation conversation;

  /// Indique si l'assistant est en train de répondre
  final bool isProcessing;

  /// Indique si la reconnaissance vocale est active (mode texte)
  final bool isVoiceActive;

  /// Indique si une session audio streaming est active
  final bool isAudioStreamingActive;

  /// État de la connexion audio
  final AudioConnectionState audioConnectionState;

  /// Indique si l'utilisateur enregistre actuellement
  final bool isRecording;

  /// Indique si Adha parle actuellement
  final bool isAdhaPlaying;

  /// Niveau audio actuel (0.0 à 1.0)
  final double audioLevel;

  const AdhaConversationActive({
    required this.conversation,
    this.isProcessing = false,
    this.isVoiceActive = false,
    this.isAudioStreamingActive = false,
    this.audioConnectionState = AudioConnectionState.disconnected,
    this.isRecording = false,
    this.isAdhaPlaying = false,
    this.audioLevel = 0.0,
  });

  /// Crée une copie de l'état avec des valeurs modifiées
  AdhaConversationActive copyWith({
    AdhaConversation? conversation,
    bool? isProcessing,
    bool? isVoiceActive,
    bool? isAudioStreamingActive,
    AudioConnectionState? audioConnectionState,
    bool? isRecording,
    bool? isAdhaPlaying,
    double? audioLevel,
  }) {
    return AdhaConversationActive(
      conversation: conversation ?? this.conversation,
      isProcessing: isProcessing ?? this.isProcessing,
      isVoiceActive: isVoiceActive ?? this.isVoiceActive,
      isAudioStreamingActive:
          isAudioStreamingActive ?? this.isAudioStreamingActive,
      audioConnectionState: audioConnectionState ?? this.audioConnectionState,
      isRecording: isRecording ?? this.isRecording,
      isAdhaPlaying: isAdhaPlaying ?? this.isAdhaPlaying,
      audioLevel: audioLevel ?? this.audioLevel,
    );
  }

  @override
  List<Object?> get props => [
    conversation,
    isProcessing,
    isVoiceActive,
    isAudioStreamingActive,
    audioConnectionState,
    isRecording,
    isAdhaPlaying,
    audioLevel,
  ];
}

/// États de connexion audio
enum AudioConnectionState { disconnected, connecting, connected, ready, error }

/// Liste des conversations disponibles
class AdhaConversationsList extends AdhaState {
  /// Liste des conversations
  final List<AdhaConversation> conversations;

  const AdhaConversationsList(this.conversations);

  @override
  List<Object?> get props => [conversations];
}

// ============================================================================
// ÉTATS DE STREAMING (Janvier 2026)
// ============================================================================

/// État de streaming: une réponse est en cours de réception progressive
class AdhaStreaming extends AdhaState {
  /// Conversation en cours
  final AdhaConversation conversation;

  /// Contenu accumulé jusqu'à présent
  final String partialContent;

  /// Numéro du dernier chunk reçu
  final int currentChunkId;

  /// ID du message en cours de streaming
  final String requestMessageId;

  /// ID de la conversation
  /// Note: Si isPendingConversationId est true, cet ID est temporaire et local.
  /// Le vrai conversationId sera fourni par le backend.
  final String conversationId;

  /// Indique si le streaming est actif
  final bool isStreaming;

  /// Indique si le conversationId est un ID temporaire local en attente
  /// de confirmation par le backend. Lorsque true, ne pas utiliser cet ID
  /// pour des opérations côté serveur (ex: annulation, subscription).
  final bool isPendingConversationId;

  const AdhaStreaming({
    required this.conversation,
    required this.partialContent,
    required this.currentChunkId,
    required this.requestMessageId,
    required this.conversationId,
    this.isStreaming = true,
    this.isPendingConversationId = false,
  });

  /// Crée une copie avec du contenu ajouté
  AdhaStreaming appendContent(String additionalContent, int newChunkId) {
    return AdhaStreaming(
      conversation: conversation,
      partialContent: partialContent + additionalContent,
      currentChunkId: newChunkId,
      requestMessageId: requestMessageId,
      conversationId: conversationId,
      isStreaming: isStreaming,
      isPendingConversationId: isPendingConversationId,
    );
  }

  /// Crée une copie avec un conversationId mis à jour du backend
  AdhaStreaming withBackendConversationId(
    String backendConversationId,
    AdhaConversation updatedConversation,
  ) {
    return AdhaStreaming(
      conversation: updatedConversation,
      partialContent: partialContent,
      currentChunkId: currentChunkId,
      requestMessageId: requestMessageId,
      conversationId: backendConversationId,
      isStreaming: isStreaming,
      isPendingConversationId: false, // Le backend a confirmé l'ID
    );
  }

  @override
  List<Object?> get props => [
    conversation,
    partialContent,
    currentChunkId,
    requestMessageId,
    conversationId,
    isStreaming,
    isPendingConversationId,
  ];
}

/// États de connexion au service de streaming
enum StreamConnectionState {
  disconnected,
  connecting,
  connected,
  reconnecting,
  error,
}

/// État indiquant la connexion au service de streaming
///
/// Selon la documentation ADHA (Janvier 2026):
/// - La connexion est établie via Socket.IO à l'API Gateway
/// - L'authentification se fait via token JWT
class AdhaStreamConnected extends AdhaState {
  /// État de la connexion au service de streaming
  final StreamConnectionState connectionState;

  /// Message d'erreur éventuel
  final String? errorMessage;

  const AdhaStreamConnected({required this.connectionState, this.errorMessage});

  @override
  List<Object?> get props => [connectionState, errorMessage];
}

// ============================================================================
// ÉTATS D'ERREUR D'ABONNEMENT (v2.7.0)
// ============================================================================

/// Types d'erreurs liées à l'abonnement
enum SubscriptionErrorType {
  /// Quota de tokens épuisé
  quotaExhausted,

  /// Abonnement expiré
  subscriptionExpired,

  /// Paiement en retard (période de grâce)
  subscriptionPastDue,

  /// Fonctionnalité non disponible dans le plan actuel
  featureNotAvailable;

  /// Convertit un type d'erreur backend en SubscriptionErrorType
  static SubscriptionErrorType? fromBackendType(String? errorType) {
    if (errorType == null) return null;
    switch (errorType) {
      case 'quota_exhausted':
        return SubscriptionErrorType.quotaExhausted;
      case 'subscription_expired':
        return SubscriptionErrorType.subscriptionExpired;
      case 'subscription_past_due':
        return SubscriptionErrorType.subscriptionPastDue;
      case 'feature_not_available':
        return SubscriptionErrorType.featureNotAvailable;
      default:
        return null;
    }
  }
}

/// État spécifique pour les erreurs liées à l'abonnement/quota
///
/// Cet état est émis lorsque le backend renvoie une erreur de type:
/// - quota_exhausted: Quota de tokens épuisé
/// - subscription_expired: Abonnement expiré
/// - subscription_past_due: Paiement en retard
/// - feature_not_available: Fonctionnalité non disponible
class AdhaSubscriptionError extends AdhaState {
  /// Type d'erreur d'abonnement
  final SubscriptionErrorType errorType;

  /// Message d'erreur lisible
  final String message;

  /// URL de renouvellement d'abonnement (fournie par le backend)
  final String? renewalUrl;

  /// Indique si un upgrade de plan est nécessaire
  final bool upgradeRequired;

  /// Fonctionnalité refusée (pour featureNotAvailable)
  final String? feature;

  /// Nombre de tokens/unités utilisés
  final int? currentUsage;

  /// Limite du plan actuel
  final int? limit;

  /// Jours restants de la période de grâce
  final int? gracePeriodDaysRemaining;

  const AdhaSubscriptionError({
    required this.errorType,
    required this.message,
    this.renewalUrl,
    this.upgradeRequired = false,
    this.feature,
    this.currentUsage,
    this.limit,
    this.gracePeriodDaysRemaining,
  });

  @override
  List<Object?> get props => [
    errorType,
    message,
    renewalUrl,
    upgradeRequired,
    feature,
    currentUsage,
    limit,
    gracePeriodDaysRemaining,
  ];
}
