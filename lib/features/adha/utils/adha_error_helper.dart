import 'package:flutter/material.dart';

/// Helper pour afficher des messages d'erreur utilisateur-friendly
/// Style ChatGPT/Gemini: messages clairs et orientés action
class AdhaErrorHelper {
  AdhaErrorHelper._();

  /// Transforme un message d'erreur technique en message utilisateur-friendly
  static AdhaFriendlyError parseError(String errorMessage) {
    final lowerError = errorMessage.toLowerCase();

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
      default:
        return 'Tout est rentré dans l\'ordre. Comment puis-je vous aider ?';
    }
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
  });
}
