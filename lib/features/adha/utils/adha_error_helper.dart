import 'package:flutter/material.dart';
import '../models/adha_stream_models.dart';

/// Helper pour afficher des messages d'erreur utilisateur-friendly
/// Style ChatGPT/Gemini: messages clairs et orientés action
class AdhaErrorHelper {
  AdhaErrorHelper._();

  /// Transforme un message d'erreur technique en message utilisateur-friendly
  static AdhaFriendlyError parseError(String errorMessage) {
    final lowerError = errorMessage.toLowerCase();

    // Erreurs de quota/abonnement (détection par mots clés dans le message)
    if (lowerError.contains('quota') && lowerError.contains('exhausted') ||
        lowerError.contains('quota épuisé') ||
        lowerError.contains('tokens insuffisants')) {
      return const AdhaFriendlyError(
        type: AdhaErrorType.quotaExhausted,
        title: 'Quota de tokens épuisé',
        message:
            'Votre quota de tokens pour ce mois est épuisé. Renouvelez votre abonnement ou passez à un plan supérieur.',
        icon: Icons.token_rounded,
        actionLabel: 'Renouveler',
        canRetry: false,
        upgradeRequired: true,
      );
    }

    if (lowerError.contains('subscription expired') ||
        lowerError.contains('abonnement expiré')) {
      return const AdhaFriendlyError(
        type: AdhaErrorType.subscriptionExpired,
        title: 'Abonnement expiré',
        message:
            'Votre abonnement a expiré. Renouvelez-le pour continuer à utiliser ADHA.',
        icon: Icons.event_busy_rounded,
        actionLabel: 'Renouveler',
        canRetry: false,
        upgradeRequired: true,
      );
    }

    if (lowerError.contains('past due') ||
        lowerError.contains('paiement en attente') ||
        lowerError.contains('période de grâce')) {
      return const AdhaFriendlyError(
        type: AdhaErrorType.subscriptionPastDue,
        title: 'Paiement en attente',
        message:
            'Votre paiement est en retard. Régularisez votre situation pour éviter la suspension du service.',
        icon: Icons.warning_amber_rounded,
        actionLabel: 'Payer maintenant',
        canRetry: false,
        upgradeRequired: false,
      );
    }

    if (lowerError.contains('feature not available') ||
        lowerError.contains('fonctionnalité non disponible') ||
        lowerError.contains('upgrade required')) {
      return const AdhaFriendlyError(
        type: AdhaErrorType.featureNotAvailable,
        title: 'Fonctionnalité non disponible',
        message:
            'Cette fonctionnalité n\'est pas incluse dans votre plan actuel. Passez à un plan supérieur.',
        icon: Icons.lock_rounded,
        actionLabel: 'Voir les plans',
        canRetry: false,
        upgradeRequired: true,
      );
    }

    // Erreurs de connexion réseau
    if (lowerError.contains('socketexception') ||
        lowerError.contains('connection refused') ||
        lowerError.contains('connection reset') ||
        lowerError.contains('network') ||
        lowerError.contains('no internet') ||
        lowerError.contains('failed host lookup')) {
      return const AdhaFriendlyError(
        type: AdhaErrorType.network,
        title: 'Connexion impossible',
        message:
            'Je ne peux pas me connecter au serveur pour le moment. Vérifiez votre connexion internet et réessayez.',
        icon: Icons.wifi_off_rounded,
        actionLabel: 'Réessayer',
        canRetry: true,
      );
    }

    // Timeout
    if (lowerError.contains('timeout') || lowerError.contains('timed out')) {
      return const AdhaFriendlyError(
        type: AdhaErrorType.timeout,
        title: 'Temps de réponse dépassé',
        message:
            'Le serveur met trop de temps à répondre. Cela peut être dû à une connexion lente. Réessayez dans un moment.',
        icon: Icons.hourglass_empty_rounded,
        actionLabel: 'Réessayer',
        canRetry: true,
      );
    }

    // Authentification
    if (lowerError.contains('401') ||
        lowerError.contains('unauthorized') ||
        lowerError.contains('token') ||
        lowerError.contains('session')) {
      return const AdhaFriendlyError(
        type: AdhaErrorType.auth,
        title: 'Session expirée',
        message:
            'Votre session a expiré. Veuillez vous reconnecter pour continuer notre conversation.',
        icon: Icons.lock_outline_rounded,
        actionLabel: 'Se reconnecter',
        canRetry: false,
        requiresReauth: true,
      );
    }

    // Accès refusé
    if (lowerError.contains('403') || lowerError.contains('forbidden')) {
      return const AdhaFriendlyError(
        type: AdhaErrorType.forbidden,
        title: 'Accès non autorisé',
        message:
            'Vous n\'avez pas accès à cette fonctionnalité. Contactez votre administrateur si nécessaire.',
        icon: Icons.block_rounded,
        actionLabel: null,
        canRetry: false,
      );
    }

    // Service non disponible
    if (lowerError.contains('404') ||
        lowerError.contains('not found') ||
        lowerError.contains('service indisponible')) {
      return const AdhaFriendlyError(
        type: AdhaErrorType.serviceUnavailable,
        title: 'Service temporairement indisponible',
        message:
            'Le service ADHA est momentanément indisponible. Réessayez dans quelques instants.',
        icon: Icons.cloud_off_rounded,
        actionLabel: 'Réessayer plus tard',
        canRetry: true,
      );
    }

    // Erreur serveur
    if (lowerError.contains('500') ||
        lowerError.contains('internal server') ||
        lowerError.contains('server error')) {
      return const AdhaFriendlyError(
        type: AdhaErrorType.server,
        title: 'Problème technique',
        message:
            'Une erreur technique est survenue de notre côté. Notre équipe en est informée. Réessayez dans quelques instants.',
        icon: Icons.error_outline_rounded,
        actionLabel: 'Réessayer',
        canRetry: true,
      );
    }

    // Erreur de streaming
    if (lowerError.contains('streaming') ||
        lowerError.contains('websocket') ||
        lowerError.contains('socket.io')) {
      return const AdhaFriendlyError(
        type: AdhaErrorType.streaming,
        title: 'Connexion interrompue',
        message:
            'La connexion en temps réel a été interrompue. Réessayez votre message.',
        icon: Icons.sync_problem_rounded,
        actionLabel: 'Réessayer',
        canRetry: true,
      );
    }

    // Contexte manquant
    if (lowerError.contains('context') ||
        lowerError.contains('contextinfo') ||
        lowerError.contains('missing_context')) {
      return const AdhaFriendlyError(
        type: AdhaErrorType.context,
        title: 'Information manquante',
        message:
            'Il me manque des informations pour vous répondre. Veuillez reformuler votre demande.',
        icon: Icons.help_outline_rounded,
        actionLabel: 'Nouvelle conversation',
        canRetry: true,
      );
    }

    // Conversation non trouvée
    if (lowerError.contains('conversation non trouvée') ||
        lowerError.contains('conversation not found')) {
      return const AdhaFriendlyError(
        type: AdhaErrorType.conversationNotFound,
        title: 'Conversation introuvable',
        message:
            'Cette conversation n\'existe plus. Démarrons une nouvelle conversation ensemble.',
        icon: Icons.chat_bubble_outline_rounded,
        actionLabel: 'Nouvelle conversation',
        canRetry: false,
        shouldStartNew: true,
      );
    }

    // Circuit breaker ouvert
    if (lowerError.contains('circuit') ||
        lowerError.contains('temporairement désactivé') ||
        lowerError.contains('trop de tentatives')) {
      return const AdhaFriendlyError(
        type: AdhaErrorType.circuitOpen,
        title: 'Service en pause',
        message:
            'Le service est temporairement en pause suite à des difficultés techniques. Veuillez patienter quelques secondes.',
        icon: Icons.pause_circle_outline_rounded,
        actionLabel: 'Réessayer dans 30s',
        canRetry: true,
      );
    }

    // API non configurée
    if (lowerError.contains('api_not_configured') ||
        lowerError.contains('service non configuré')) {
      return const AdhaFriendlyError(
        type: AdhaErrorType.notConfigured,
        title: 'Configuration requise',
        message:
            'Le service ADHA nécessite une connexion. Assurez-vous d\'être connecté à internet.',
        icon: Icons.settings_suggest_rounded,
        actionLabel: 'Vérifier la connexion',
        canRetry: true,
      );
    }

    // Erreur générique par défaut
    return AdhaFriendlyError(
      type: AdhaErrorType.unknown,
      title: 'Oups, quelque chose s\'est mal passé',
      message:
          'Je n\'ai pas pu traiter votre demande. Veuillez réessayer ou reformuler votre question.',
      icon: Icons.sentiment_dissatisfied_rounded,
      actionLabel: 'Réessayer',
      canRetry: true,
      technicalDetails: errorMessage, // Conserver pour debug si nécessaire
    );
  }

  /// Obtient un message d'accueil après une erreur récupérée
  static String getRecoveryMessage(AdhaErrorType errorType) {
    switch (errorType) {
      case AdhaErrorType.network:
      case AdhaErrorType.timeout:
        return 'Connexion rétablie ! Je suis de nouveau disponible.';
      case AdhaErrorType.auth:
        return 'Vous êtes reconnecté. Comment puis-je vous aider ?';
      case AdhaErrorType.server:
        return 'Le service est de nouveau opérationnel.';
      case AdhaErrorType.quotaExhausted:
      case AdhaErrorType.subscriptionExpired:
      case AdhaErrorType.subscriptionPastDue:
      case AdhaErrorType.featureNotAvailable:
        return 'Votre abonnement a été mis à jour. Comment puis-je vous aider ?';
      default:
        return 'Tout est rentré dans l\'ordre. Comment puis-je vous aider ?';
    }
  }

  /// Crée une erreur friendly à partir des métadonnées de streaming backend
  static AdhaFriendlyError parseFromMetadata(
    AdhaStreamMetadata metadata,
    String fallbackMessage,
  ) {
    if (metadata.isQuotaExhausted) {
      return AdhaFriendlyError(
        type: AdhaErrorType.quotaExhausted,
        title: 'Quota de tokens épuisé',
        message: _buildQuotaMessage(metadata),
        icon: Icons.token_rounded,
        actionLabel: 'Renouveler mon abonnement',
        canRetry: false,
        upgradeRequired: metadata.upgradeRequired ?? true,
        subscriptionRenewalUrl: metadata.subscriptionRenewalUrl,
        feature: metadata.feature,
        currentUsage: metadata.currentUsage,
        limit: metadata.limit,
        gracePeriodDaysRemaining: metadata.gracePeriodDaysRemaining,
      );
    }

    if (metadata.isSubscriptionExpired) {
      return AdhaFriendlyError(
        type: AdhaErrorType.subscriptionExpired,
        title: 'Abonnement expiré',
        message:
            'Votre abonnement a expiré. Renouvelez-le pour continuer à utiliser ADHA AI.',
        icon: Icons.event_busy_rounded,
        actionLabel: 'Renouveler mon abonnement',
        canRetry: false,
        upgradeRequired: true,
        subscriptionRenewalUrl: metadata.subscriptionRenewalUrl,
        gracePeriodDaysRemaining: metadata.gracePeriodDaysRemaining,
      );
    }

    if (metadata.isSubscriptionPastDue) {
      return AdhaFriendlyError(
        type: AdhaErrorType.subscriptionPastDue,
        title: 'Paiement en attente',
        message: _buildGracePeriodMessage(metadata),
        icon: Icons.warning_amber_rounded,
        actionLabel: 'Payer maintenant',
        canRetry: false,
        upgradeRequired: false,
        subscriptionRenewalUrl: metadata.subscriptionRenewalUrl,
        gracePeriodDaysRemaining: metadata.gracePeriodDaysRemaining,
      );
    }

    if (metadata.isFeatureNotAvailable) {
      return AdhaFriendlyError(
        type: AdhaErrorType.featureNotAvailable,
        title: 'Fonctionnalité non disponible',
        message: _buildFeatureMessage(metadata),
        icon: Icons.lock_rounded,
        actionLabel: 'Voir les plans disponibles',
        canRetry: false,
        upgradeRequired: true,
        subscriptionRenewalUrl: metadata.subscriptionRenewalUrl,
        feature: metadata.feature,
      );
    }

    // Erreur générique si le type n'est pas reconnu
    return AdhaFriendlyError(
      type: AdhaErrorType.unknown,
      title: 'Oups, quelque chose s\'est mal passé',
      message: fallbackMessage,
      icon: Icons.sentiment_dissatisfied_rounded,
      actionLabel: 'Réessayer',
      canRetry: true,
    );
  }

  /// Construit le message pour le quota épuisé
  static String _buildQuotaMessage(AdhaStreamMetadata metadata) {
    final buffer = StringBuffer(
      'Votre quota de tokens pour ce mois est épuisé.',
    );

    if (metadata.currentUsage != null && metadata.limit != null) {
      buffer.write(
        ' (${metadata.currentUsage}/${metadata.limit} tokens utilisés)',
      );
    }

    buffer.write(
      ' Pour continuer à utiliser ADHA AI, vous pouvez renouveler votre abonnement ou passer à un plan supérieur.',
    );

    return buffer.toString();
  }

  /// Construit le message pour la période de grâce
  static String _buildGracePeriodMessage(AdhaStreamMetadata metadata) {
    if (metadata.gracePeriodDaysRemaining != null) {
      return 'Votre paiement est en retard. Il vous reste ${metadata.gracePeriodDaysRemaining} jour(s) avant la suspension du service. Régularisez votre situation.';
    }
    return 'Votre paiement est en retard. Régularisez votre situation pour éviter la suspension du service.';
  }

  /// Construit le message pour une fonctionnalité non disponible
  static String _buildFeatureMessage(AdhaStreamMetadata metadata) {
    if (metadata.feature != null) {
      return 'La fonctionnalité "${metadata.feature}" n\'est pas incluse dans votre plan actuel. Passez à un plan supérieur pour y accéder.';
    }
    return 'Cette fonctionnalité n\'est pas incluse dans votre plan actuel. Passez à un plan supérieur.';
  }
}

/// Types d'erreurs ADHA
enum AdhaErrorType {
  network,
  timeout,
  auth,
  forbidden,
  serviceUnavailable,
  server,
  streaming,
  context,
  conversationNotFound,
  circuitOpen,
  notConfigured,
  unknown,
  // Types d'erreurs d'abonnement/quota (v2.7.0)
  quotaExhausted,
  subscriptionExpired,
  subscriptionPastDue,
  featureNotAvailable,
}

/// Représente une erreur formatée de manière user-friendly
class AdhaFriendlyError {
  final AdhaErrorType type;
  final String title;
  final String message;
  final IconData icon;
  final String? actionLabel;
  final bool canRetry;
  final bool requiresReauth;
  final bool shouldStartNew;
  final String? technicalDetails;

  // Champs pour les erreurs d'abonnement (v2.7.0)
  final String? subscriptionRenewalUrl;
  final bool upgradeRequired;
  final String? feature;
  final int? currentUsage;
  final int? limit;
  final int? gracePeriodDaysRemaining;

  const AdhaFriendlyError({
    required this.type,
    required this.title,
    required this.message,
    required this.icon,
    this.actionLabel,
    this.canRetry = false,
    this.requiresReauth = false,
    this.shouldStartNew = false,
    this.technicalDetails,
    this.subscriptionRenewalUrl,
    this.upgradeRequired = false,
    this.feature,
    this.currentUsage,
    this.limit,
    this.gracePeriodDaysRemaining,
  });

  /// Vérifie si l'erreur est liée à l'abonnement
  bool get isSubscriptionRelated =>
      type == AdhaErrorType.quotaExhausted ||
      type == AdhaErrorType.subscriptionExpired ||
      type == AdhaErrorType.subscriptionPastDue ||
      type == AdhaErrorType.featureNotAvailable;
}
