// filepath: lib/core/services/api_circuit_breaker.dart

import 'dart:async';
import 'package:flutter/foundation.dart';

/// États du circuit breaker
enum CircuitState {
  /// Circuit fermé - les requêtes passent normalement
  closed,

  /// Circuit ouvert - les requêtes sont bloquées
  open,

  /// Circuit semi-ouvert - test de reconnexion en cours
  halfOpen,
}

/// Service Circuit Breaker pour éviter les requêtes inutiles vers un backend indisponible
///
/// Pattern recommandé par l'industrie pour:
/// - Éviter les requêtes répétées vers un service défaillant
/// - Permettre au service de récupérer
/// - Améliorer l'expérience utilisateur en évitant les attentes inutiles
class ApiCircuitBreaker {
  static final ApiCircuitBreaker _instance = ApiCircuitBreaker._internal();
  static ApiCircuitBreaker get instance => _instance;

  ApiCircuitBreaker._internal();

  /// Nombre d'échecs avant ouverture du circuit (augmenté pour plus de tolérance)
  static const int _failureThreshold = 5;

  /// Durée pendant laquelle le circuit reste ouvert (en secondes) - réduit pour récupération plus rapide
  static const int _resetTimeoutSeconds = 15;

  /// Durée du timeout pour les requêtes de test en mode semi-ouvert (en secondes)
  /// Utilisé pour les requêtes de health check pendant la phase de recovery
  static const int halfOpenTimeoutSeconds = 5;

  /// Fenêtre de temps pour compter les échecs (en secondes)
  /// Les échecs en dehors de cette fenêtre sont ignorés
  static const int _failureWindowSeconds = 60;

  /// État actuel du circuit
  CircuitState _state = CircuitState.closed;

  /// Nombre d'échecs consécutifs
  int _failureCount = 0;

  /// Moment du dernier échec
  DateTime? _lastFailureTime;

  /// Moment du premier échec dans la fenêtre actuelle
  DateTime? _firstFailureTime;

  /// Compteur de succès en mode semi-ouvert
  int _halfOpenSuccessCount = 0;

  /// Nombre de succès requis pour fermer le circuit depuis semi-ouvert
  static const int _halfOpenSuccessThreshold = 2;

  /// Listeners pour notifier les changements d'état
  final List<void Function(CircuitState)> _listeners = [];

  /// Getter pour l'état actuel
  CircuitState get state => _state;

  /// Vérifie si le circuit est ouvert
  bool get isOpen => _state == CircuitState.open;

  /// Vérifie si les requêtes peuvent passer
  bool get canExecute {
    _checkStateTransition();
    return _state != CircuitState.open;
  }

  /// Temps restant avant la prochaine tentative (en secondes)
  int get timeUntilRetry {
    if (_state != CircuitState.open || _lastFailureTime == null) return 0;
    final elapsed = DateTime.now().difference(_lastFailureTime!).inSeconds;
    final remaining = _resetTimeoutSeconds - elapsed;
    return remaining > 0 ? remaining : 0;
  }

  /// Ajoute un listener pour les changements d'état
  void addListener(void Function(CircuitState) listener) {
    _listeners.add(listener);
  }

  /// Supprime un listener
  void removeListener(void Function(CircuitState) listener) {
    _listeners.remove(listener);
  }

  /// Notifie tous les listeners d'un changement d'état
  void _notifyListeners() {
    for (final listener in _listeners) {
      listener(_state);
    }
  }

  /// Vérifie et effectue les transitions d'état automatiques
  void _checkStateTransition() {
    if (_state == CircuitState.open && _lastFailureTime != null) {
      final elapsed = DateTime.now().difference(_lastFailureTime!).inSeconds;
      if (elapsed >= _resetTimeoutSeconds) {
        _transitionTo(CircuitState.halfOpen);
        debugPrint(
          '🔄 Circuit Breaker: Passage en mode semi-ouvert (test de reconnexion)',
        );
      }
    }
  }

  /// Effectue une transition d'état
  void _transitionTo(CircuitState newState) {
    if (_state != newState) {
      final oldState = _state;
      _state = newState;
      debugPrint('⚡ Circuit Breaker: $oldState -> $newState');
      _notifyListeners();
    }
  }

  /// Enregistre un succès
  void recordSuccess() {
    if (_state == CircuitState.halfOpen) {
      _halfOpenSuccessCount++;
      debugPrint(
        '✅ Circuit Breaker: Succès en mode semi-ouvert ($_halfOpenSuccessCount/$_halfOpenSuccessThreshold)',
      );

      if (_halfOpenSuccessCount >= _halfOpenSuccessThreshold) {
        _reset();
        debugPrint('🟢 Circuit Breaker: Circuit fermé - Backend opérationnel');
      }
    } else if (_state == CircuitState.closed) {
      // Réinitialiser le compteur d'échecs après un succès
      if (_failureCount > 0) {
        _failureCount = 0;
        debugPrint('✅ Circuit Breaker: Compteur d\'échecs réinitialisé');
      }
    }
  }

  /// Enregistre un échec
  void recordFailure({String? reason}) {
    final now = DateTime.now();

    // Vérifier si le premier échec est en dehors de la fenêtre de temps
    // Si oui, réinitialiser le compteur (les anciens échecs sont "oubliés")
    if (_firstFailureTime != null) {
      final elapsed = now.difference(_firstFailureTime!).inSeconds;
      if (elapsed > _failureWindowSeconds) {
        // La fenêtre est expirée, réinitialiser le compteur
        _failureCount = 0;
        _firstFailureTime = null;
        debugPrint(
          '🔄 Circuit Breaker: Fenêtre d\'échecs expirée, compteur réinitialisé',
        );
      }
    }

    // Premier échec de la fenêtre
    _firstFailureTime ??= now;

    _failureCount++;
    _lastFailureTime = now;

    debugPrint(
      '❌ Circuit Breaker: Échec enregistré ($_failureCount/$_failureThreshold) ${reason != null ? "- $reason" : ""}',
    );

    if (_state == CircuitState.halfOpen) {
      // Un échec en mode semi-ouvert réouvre le circuit
      _transitionTo(CircuitState.open);
      _halfOpenSuccessCount = 0;
      debugPrint(
        '🔴 Circuit Breaker: Circuit réouvert après échec en mode semi-ouvert',
      );
    } else if (_failureCount >= _failureThreshold) {
      _transitionTo(CircuitState.open);
      debugPrint(
        '🔴 Circuit Breaker: Circuit ouvert - Backend indisponible (${_resetTimeoutSeconds}s avant retry)',
      );
    }
  }

  /// Réinitialise le circuit breaker
  void _reset() {
    _state = CircuitState.closed;
    _failureCount = 0;
    _lastFailureTime = null;
    _firstFailureTime = null;
    _halfOpenSuccessCount = 0;
    _notifyListeners();
  }

  /// Force la réinitialisation du circuit (pour tests ou reconnexion manuelle)
  void forceReset() {
    debugPrint('🔧 Circuit Breaker: Réinitialisation forcée');
    _reset();
  }

  /// Exécute une fonction avec protection du circuit breaker
  ///
  /// Retourne null si le circuit est ouvert, sinon exécute la fonction
  /// et enregistre le succès/échec automatiquement
  Future<T?> execute<T>(
    Future<T> Function() action, {
    T? Function()? fallback,
    bool recordOnSuccess = true,
  }) async {
    _checkStateTransition();

    if (_state == CircuitState.open) {
      debugPrint(
        '⛔ Circuit Breaker: Requête bloquée (circuit ouvert, retry dans ${timeUntilRetry}s)',
      );
      return fallback?.call();
    }

    try {
      final result = await action();
      if (recordOnSuccess) {
        recordSuccess();
      }
      return result;
    } catch (e) {
      final errorMessage = e.toString().toLowerCase();

      // Ne pas ouvrir le circuit pour les erreurs d'authentification ou validation
      if (errorMessage.contains('401') ||
          errorMessage.contains('403') ||
          errorMessage.contains('400') ||
          errorMessage.contains('validation')) {
        // Ces erreurs ne sont pas des problèmes de disponibilité du backend
        debugPrint(
          '⚠️ Circuit Breaker: Erreur métier ignorée (pas un problème de disponibilité)',
        );
        rethrow;
      }

      // Erreurs réseau/serveur qui indiquent une indisponibilité
      if (errorMessage.contains('connection') ||
          errorMessage.contains('timeout') ||
          errorMessage.contains('socket') ||
          errorMessage.contains('500') ||
          errorMessage.contains('502') ||
          errorMessage.contains('503') ||
          errorMessage.contains('504') ||
          errorMessage.contains('closed before')) {
        recordFailure(
          reason: e.toString().substring(
            0,
            (e.toString().length > 50) ? 50 : e.toString().length,
          ),
        );
      }

      rethrow;
    }
  }

  /// Retourne les statistiques du circuit breaker
  Map<String, dynamic> getStats() {
    return {
      'state': _state.name,
      'failureCount': _failureCount,
      'failureThreshold': _failureThreshold,
      'lastFailureTime': _lastFailureTime?.toIso8601String(),
      'timeUntilRetry': timeUntilRetry,
      'halfOpenSuccessCount': _halfOpenSuccessCount,
    };
  }

  @override
  String toString() {
    return 'ApiCircuitBreaker(state: $_state, failures: $_failureCount/$_failureThreshold, timeUntilRetry: ${timeUntilRetry}s)';
  }
}
