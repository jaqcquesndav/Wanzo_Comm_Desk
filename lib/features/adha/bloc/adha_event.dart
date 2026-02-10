import 'package:equatable/equatable.dart';
import '../models/adha_context_info.dart'; // Importation ajoutée
import '../models/adha_attachment.dart'; // Importation pour les pièces jointes
import 'adha_state.dart'; // Pour AudioConnectionState

/// Événements pour le bloc Adha
abstract class AdhaEvent extends Equatable {
  const AdhaEvent();

  @override
  List<Object?> get props => [];
}

/// Envoi d'un nouveau message à Adha
class SendMessage extends AdhaEvent {
  /// Contenu du message
  final String message;
  final String? conversationId; // Peut être null pour une nouvelle conversation
  final AdhaContextInfo? contextInfo; // Ajouté pour le contexte

  const SendMessage(this.message, {this.conversationId, this.contextInfo});

  @override
  List<Object?> get props => [message, conversationId, contextInfo];
}

/// Chargement de l'historique des conversations
class LoadConversations extends AdhaEvent {
  const LoadConversations();
}

/// Chargement d'une conversation spécifique
class LoadConversation extends AdhaEvent {
  /// ID de la conversation à charger
  final String conversationId;

  const LoadConversation(this.conversationId);

  @override
  List<Object?> get props => [conversationId];
}

/// Création d'une nouvelle conversation
class NewConversation extends AdhaEvent {
  final String initialMessage;
  final AdhaContextInfo
  contextInfo; // Contexte requis pour une nouvelle conversation

  const NewConversation(this.initialMessage, this.contextInfo);

  @override
  List<Object?> get props => [initialMessage, contextInfo];
}

/// Suppression d'une conversation
class DeleteConversation extends AdhaEvent {
  /// ID de la conversation à supprimer
  final String conversationId;

  const DeleteConversation(this.conversationId);

  @override
  List<Object?> get props => [conversationId];
}

/// Activation de la reconnaissance vocale pour interagir avec Adha
class StartVoiceRecognition extends AdhaEvent {
  const StartVoiceRecognition();
}

/// Arrêt de la reconnaissance vocale
class StopVoiceRecognition extends AdhaEvent {
  const StopVoiceRecognition();
}

/// Modification d'un message existant par l'utilisateur
class EditMessage extends AdhaEvent {
  /// ID du message à modifier
  final String messageId;

  /// Nouveau contenu du message
  final String newContent;

  /// Informations de contexte pour la modification
  final AdhaContextInfo contextInfo;

  const EditMessage(this.messageId, this.newContent, this.contextInfo);

  @override
  List<Object?> get props => [messageId, newContent, contextInfo];
}

/// Démarre une session audio full-duplex avec Adha
class StartAudioSession extends AdhaEvent {
  final String? conversationId;
  final AdhaContextInfo? contextInfo;

  const StartAudioSession({this.conversationId, this.contextInfo});

  @override
  List<Object?> get props => [conversationId, contextInfo];
}

/// Termine la session audio actuelle
class EndAudioSession extends AdhaEvent {
  const EndAudioSession();
}

/// Active/désactive l'enregistrement audio (push-to-talk)
class ToggleRecording extends AdhaEvent {
  final bool enabled;

  const ToggleRecording(this.enabled);

  @override
  List<Object?> get props => [enabled];
}

/// Interrompt Adha pendant qu'il parle
class InterruptAdha extends AdhaEvent {
  const InterruptAdha();
}

/// Ajuste le volume de lecture
class SetAudioVolume extends AdhaEvent {
  final double volume;

  const SetAudioVolume(this.volume);

  @override
  List<Object?> get props => [volume];
}

/// Événement pour les mises à jour d'état audio du service
class AudioStateUpdate extends AdhaEvent {
  final AudioConnectionState connectionState;
  final bool isRecording;
  final bool isPlaying;
  final double audioLevel;

  const AudioStateUpdate({
    required this.connectionState,
    required this.isRecording,
    required this.isPlaying,
    required this.audioLevel,
  });

  @override
  List<Object?> get props => [
    connectionState,
    isRecording,
    isPlaying,
    audioLevel,
  ];
}

// ============================================================================
// ÉVÉNEMENTS DE STREAMING (Janvier 2026)
// ============================================================================

/// Connecte au service de streaming avec le token d'authentification
///
/// Selon la documentation ADHA (Janvier 2026):
/// - La connexion utilise le token JWT pour l'authentification
/// - Le token est passé via l'objet auth de Socket.IO
class ConnectToStreamService extends AdhaEvent {
  /// Token JWT d'authentification (optionnel, sera récupéré automatiquement si null)
  final String? authToken;

  const ConnectToStreamService({this.authToken});

  @override
  List<Object?> get props => [authToken];
}

/// Déconnecte du service de streaming
class DisconnectFromStreamService extends AdhaEvent {
  const DisconnectFromStreamService();
}

/// Envoie un message avec streaming activé
class SendStreamingMessage extends AdhaEvent {
  /// Contenu du message
  final String message;

  /// ID de la conversation (peut être null pour une nouvelle conversation)
  final String? conversationId;

  /// Contexte pour le message
  final AdhaContextInfo? contextInfo;

  /// Activer le streaming (défaut: true)
  final bool streaming;

  /// Pièces jointes à envoyer avec le message (v2.5.0)
  final List<AdhaAttachment>? attachments;

  const SendStreamingMessage(
    this.message, {
    this.conversationId,
    this.contextInfo,
    this.streaming = true,
    this.attachments,
  });

  @override
  List<Object?> get props => [
    message,
    conversationId,
    contextInfo,
    streaming,
    attachments,
  ];
}

/// Événement interne: un chunk de streaming a été reçu
class StreamChunkReceived extends AdhaEvent {
  final String conversationId;
  final String content;
  final int chunkId;
  final String requestMessageId;

  const StreamChunkReceived({
    required this.conversationId,
    required this.content,
    required this.chunkId,
    required this.requestMessageId,
  });

  @override
  List<Object?> get props => [
    conversationId,
    content,
    chunkId,
    requestMessageId,
  ];
}

/// Événement interne: le streaming est terminé
class StreamCompleted extends AdhaEvent {
  final String conversationId;
  final String fullContent;
  final String requestMessageId;
  final int totalChunks;
  final Map<String, dynamic>? processingDetails;

  const StreamCompleted({
    required this.conversationId,
    required this.fullContent,
    required this.requestMessageId,
    required this.totalChunks,
    this.processingDetails,
  });

  @override
  List<Object?> get props => [
    conversationId,
    fullContent,
    requestMessageId,
    totalChunks,
    processingDetails,
  ];
}

/// Événement interne: erreur lors du streaming
class StreamError extends AdhaEvent {
  final String conversationId;
  final String errorMessage;
  final String? requestMessageId;

  // Champs pour les erreurs d'abonnement/quota (v2.7.0)
  final String? errorType;
  final String? subscriptionRenewalUrl;
  final bool? requiresAction;
  final bool? upgradeRequired;
  final String? feature;
  final int? currentUsage;
  final int? limit;
  final int? gracePeriodDaysRemaining;

  const StreamError({
    required this.conversationId,
    required this.errorMessage,
    this.requestMessageId,
    this.errorType,
    this.subscriptionRenewalUrl,
    this.requiresAction,
    this.upgradeRequired,
    this.feature,
    this.currentUsage,
    this.limit,
    this.gracePeriodDaysRemaining,
  });

  /// Vérifie si l'erreur est liée à l'abonnement
  bool get isSubscriptionRelated =>
      errorType == 'quota_exhausted' ||
      errorType == 'subscription_expired' ||
      errorType == 'subscription_past_due' ||
      errorType == 'feature_not_available';

  @override
  List<Object?> get props => [
    conversationId,
    errorMessage,
    requestMessageId,
    errorType,
    subscriptionRenewalUrl,
    requiresAction,
    upgradeRequired,
    feature,
    currentUsage,
    limit,
    gracePeriodDaysRemaining,
  ];
}

/// Annule le streaming en cours
class CancelStreaming extends AdhaEvent {
  final String? conversationId;

  const CancelStreaming({this.conversationId});

  @override
  List<Object?> get props => [conversationId];
}

/// Réinitialise l'état pour démarrer une nouvelle conversation
/// Utilisé quand l'utilisateur veut repartir à zéro
class ClearCurrentConversation extends AdhaEvent {
  const ClearCurrentConversation();
}

/// Initialise le repository avec l'ID de l'utilisateur connecté
/// Appelé après la connexion pour isoler les conversations par utilisateur
class InitializeForUser extends AdhaEvent {
  final String? userId;

  const InitializeForUser({this.userId});

  @override
  List<Object?> get props => [userId];
}
