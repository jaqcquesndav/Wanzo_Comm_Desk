import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;
import '../../../core/config/env_config.dart';
import '../models/adha_stream_models.dart';

/// États de connexion du service de streaming
enum AdhaStreamConnectionState {
  disconnected,
  connecting,
  connected,
  reconnecting,
  error,
}

/// États du Circuit Breaker pour la résilience (v2.4.0)
enum CircuitBreakerState {
  closed, // Normal, requêtes passent
  open, // Bloqué après échecs, requêtes rejetées
  halfOpen, // Test après timeout
}

/// Service gérant la connexion Socket.IO et le streaming des réponses ADHA
///
/// Architecture selon la documentation (Janvier 2026 - v2.4.0):
/// - Connexion via Socket.IO à l'API Gateway (/commerce/chat)
/// - Authentification via token JWT (auth object, query param ou header)
/// - Événements client→serveur: subscribe_conversation, unsubscribe_conversation
/// - Événements serveur→client:
///   * adha.stream.chunk - Fragment de texte
///   * adha.stream.end - Fin du streaming
///   * adha.stream.error - Erreur pendant traitement
///   * adha.stream.tool - Appel/résultat de fonction IA
///   * adha.stream.cancelled - Stream annulé
///   * adha.stream.heartbeat - Signal de connexion active (30s)
class AdhaStreamService {
  IO.Socket? _socket;

  /// Controller pour les chunks reçus en streaming
  final StreamController<AdhaStreamChunkEvent> _chunkController =
      StreamController<AdhaStreamChunkEvent>.broadcast();

  /// Controller pour l'état de connexion
  final StreamController<AdhaStreamConnectionState> _connectionStateController =
      StreamController<AdhaStreamConnectionState>.broadcast();

  /// Stream des chunks de réponse reçus en temps réel
  Stream<AdhaStreamChunkEvent> get chunkStream => _chunkController.stream;

  /// Stream de l'état de connexion
  Stream<AdhaStreamConnectionState> get connectionState =>
      _connectionStateController.stream;

  /// État de connexion actuel
  AdhaStreamConnectionState _currentState =
      AdhaStreamConnectionState.disconnected;
  AdhaStreamConnectionState get currentConnectionState => _currentState;

  /// Token d'authentification
  String? _authToken;

  /// ID de la conversation actuellement abonnée
  String? _currentConversationId;

  /// Compteur de tentatives de reconnexion
  int _reconnectAttempts = 0;
  static const int _maxReconnectAttempts = 3;

  // ========================================================================
  // Circuit Breaker (v2.4.0)
  // ========================================================================
  CircuitBreakerState _circuitState = CircuitBreakerState.closed;
  int _failureCount = 0;
  static const int _failureThreshold = 5;
  static const Duration _circuitTimeout = Duration(seconds: 60);
  DateTime? _lastFailureTime;
  Timer? _circuitResetTimer;

  /// État actuel du circuit breaker
  CircuitBreakerState get circuitBreakerState => _circuitState;

  // ========================================================================
  // Heartbeat (v2.4.0)
  // ========================================================================
  Timer? _heartbeatTimer;
  DateTime? _lastHeartbeat;
  static const Duration _heartbeatTimeout = Duration(
    seconds: 45,
  ); // 30s + marge

  /// Configure le service avec le token d'authentification
  void configure({required String authToken}) {
    _authToken = authToken;
    debugPrint('[AdhaStreamService] Token configuré');
  }

  /// S'assure que la connexion WebSocket est active
  ///
  /// Reconecte automatiquement si nécessaire.
  /// Retourne true si la connexion est active, false sinon.
  Future<bool> ensureConnected() async {
    if (isConnected) {
      debugPrint('[AdhaStreamService] ✅ Connexion déjà active');
      return true;
    }

    if (_authToken == null || _authToken!.isEmpty) {
      debugPrint('[AdhaStreamService] ❌ Pas de token pour reconnecter');
      return false;
    }

    debugPrint('[AdhaStreamService] 🔄 Reconnexion nécessaire...');
    await connect(_authToken!);

    // Attendre un peu pour que la connexion soit établie
    int attempts = 0;
    while (!isConnected && attempts < 10) {
      await Future.delayed(const Duration(milliseconds: 200));
      attempts++;
    }

    if (isConnected) {
      debugPrint('[AdhaStreamService] ✅ Reconnexion réussie');
      return true;
    } else {
      debugPrint('[AdhaStreamService] ❌ Échec de la reconnexion');
      return false;
    }
  }

  /// Établit la connexion Socket.IO pour le streaming
  ///
  /// URLs selon la documentation:
  /// - Production: wss://api.wanzo.io/commerce/chat
  /// - Développement: ws://localhost:8000/commerce/chat
  /// - L'API Gateway route /commerce/chat vers :3006/socket.io
  ///
  /// [authToken] - Token JWT pour l'authentification
  Future<void> connect(String authToken) async {
    // Vérifier le circuit breaker
    if (!_canMakeRequest()) {
      debugPrint(
        '[AdhaStreamService] Circuit breaker ouvert, connexion refusée',
      );
      _updateConnectionState(AdhaStreamConnectionState.error);
      return;
    }

    if (_currentState == AdhaStreamConnectionState.connecting ||
        _currentState == AdhaStreamConnectionState.connected) {
      debugPrint('[AdhaStreamService] Déjà connecté ou en cours de connexion');
      return;
    }

    _authToken = authToken;
    _updateConnectionState(AdhaStreamConnectionState.connecting);

    try {
      // Construire l'URL Socket.IO via API Gateway
      // L'API Gateway route /commerce/chat vers :3006/socket.io
      final baseUrl = _getSocketIOBaseUrl();
      final socketUrl = '$baseUrl/commerce/chat';

      debugPrint(
        '[AdhaStreamService] ==========================================',
      );
      debugPrint('[AdhaStreamService] Connexion Socket.IO à: $socketUrl');
      debugPrint('[AdhaStreamService] Base URL: $baseUrl');
      debugPrint(
        '[AdhaStreamService] Token (premiers 20 chars): ${authToken.length > 20 ? authToken.substring(0, 20) : authToken}...',
      );
      debugPrint(
        '[AdhaStreamService] ==========================================',
      );

      // Créer la connexion Socket.IO selon la documentation
      // L'API Gateway route /commerce/chat → :3006/socket.io (pathRewrite côté proxy)
      // Donc on spécifie UNIQUEMENT /commerce/chat (PAS /socket.io !)
      // C'est le même pattern que l'app React avec /accounting/chat
      //
      // IMPORTANT: Configuration pour maintenir la connexion active :
      // - pingInterval: Intervalle d'envoi des pings (25s par défaut côté serveur)
      // - pingTimeout: Temps d'attente avant déconnexion si pas de pong (20s)
      // - forceNew: Force une nouvelle connexion à chaque connect()
      _socket = IO.io(
        baseUrl, // URL de base sans le path
        IO.OptionBuilder()
            .setTransports(['websocket']) // WebSocket uniquement (comme React)
            .enableAutoConnect()
            .enableForceNew() // Force nouvelle connexion pour éviter les connexions zombies
            .setAuth({'token': authToken})
            .setPath(
              '/commerce/chat',
            ) // Path du proxy API Gateway (PAS /socket.io !)
            .setReconnectionAttempts(_maxReconnectAttempts)
            .setReconnectionDelay(1000)
            .setReconnectionDelayMax(5000)
            .setExtraHeaders({
              'Authorization': 'Bearer $authToken',
            }) // Header d'auth en backup
            .build(),
      );

      _setupSocketEventListeners();

      _socket!.connect();

      // Démarrer la surveillance du heartbeat
      _startHeartbeatMonitor();
    } catch (e) {
      debugPrint('[AdhaStreamService] Erreur de connexion: $e');
      _recordFailure();
      _updateConnectionState(AdhaStreamConnectionState.error);
    }
  }

  /// Configure les écouteurs d'événements Socket.IO
  void _setupSocketEventListeners() {
    if (_socket == null) return;

    // Événements de connexion
    _socket!.onConnect((_) {
      debugPrint('[AdhaStreamService] ✅ Connecté à ADHA streaming');
      _updateConnectionState(AdhaStreamConnectionState.connected);
      _reconnectAttempts = 0;
      _resetCircuitBreaker(); // Réinitialiser sur connexion réussie
    });

    _socket!.onConnectError((error) {
      debugPrint('[AdhaStreamService] ❌ Erreur de connexion: $error');
      _recordFailure();
      _updateConnectionState(AdhaStreamConnectionState.error);
    });

    _socket!.onDisconnect((_) {
      debugPrint('[AdhaStreamService] ⚠️ Déconnecté de ADHA streaming');
      _updateConnectionState(AdhaStreamConnectionState.disconnected);
      _stopHeartbeatMonitor();
    });

    _socket!.onReconnecting((_) {
      _reconnectAttempts++;
      debugPrint(
        '[AdhaStreamService] 🔄 Reconnexion en cours (tentative $_reconnectAttempts/$_maxReconnectAttempts)',
      );
      _updateConnectionState(AdhaStreamConnectionState.reconnecting);
    });

    _socket!.onReconnect((_) {
      debugPrint('[AdhaStreamService] ✅ Reconnecté avec succès');
      _updateConnectionState(AdhaStreamConnectionState.connected);
      _reconnectAttempts = 0;
      _resetCircuitBreaker();

      // Re-abonner à la conversation si nécessaire
      if (_currentConversationId != null) {
        subscribeToConversation(_currentConversationId!);
      }

      // Redémarrer la surveillance du heartbeat
      _startHeartbeatMonitor();
    });

    _socket!.onReconnectFailed((_) {
      debugPrint(
        '[AdhaStreamService] ❌ Échec de la reconnexion après $_maxReconnectAttempts tentatives',
      );
      _recordFailure();
      _updateConnectionState(AdhaStreamConnectionState.error);
    });

    // ========================================================================
    // Événements de streaming ADHA selon la documentation (v2.4.0)
    // ========================================================================

    // Fragment de texte de la réponse
    _socket!.on('adha.stream.chunk', (data) {
      _handleStreamEvent(data, 'chunk');
    });

    // Fin du streaming avec contenu complet
    _socket!.on('adha.stream.end', (data) {
      _handleStreamEvent(data, 'end');
    });

    // Erreur pendant le traitement
    _socket!.on('adha.stream.error', (data) {
      _handleStreamEvent(data, 'error');
    });

    // Appel/résultat de fonction IA (tool calling)
    _socket!.on('adha.stream.tool', (data) {
      _handleStreamEvent(data, 'tool');
    });

    // Stream annulé (v2.4.0)
    _socket!.on('adha.stream.cancelled', (data) {
      _handleStreamEvent(data, 'cancelled');
    });

    // Heartbeat - signal de connexion active (v2.4.0)
    _socket!.on('adha.stream.heartbeat', (data) {
      _handleHeartbeat(data);
    });

    // Événement d'erreur générique Socket.IO
    _socket!.on('error', (data) {
      debugPrint('[AdhaStreamService] Erreur Socket.IO: $data');
      _recordFailure();
      _chunkController.addError(Exception('Erreur Socket.IO: $data'));
    });
  }

  /// Gère les heartbeats reçus (v2.4.0)
  void _handleHeartbeat(dynamic data) {
    _lastHeartbeat = DateTime.now();
    debugPrint('[AdhaStreamService] 💓 Heartbeat reçu');

    // Émettre aussi comme événement pour que le BLoC puisse suivre
    try {
      Map<String, dynamic> json;
      if (data is Map<String, dynamic>) {
        json = data;
      } else if (data is Map) {
        json = Map<String, dynamic>.from(data);
      } else {
        // Créer un heartbeat minimal
        json = {
          'id': 'heartbeat-${DateTime.now().millisecondsSinceEpoch}',
          'requestMessageId': '',
          'conversationId': _currentConversationId ?? '',
          'type': 'heartbeat',
          'content': '',
          'chunkId': -1,
          'timestamp': DateTime.now().toIso8601String(),
          'userId': '',
          'companyId': '',
        };
      }

      final chunk = AdhaStreamChunkEvent.fromJson(json);
      _chunkController.add(chunk);
    } catch (e) {
      debugPrint('[AdhaStreamService] Erreur parsing heartbeat: $e');
    }
  }

  /// Démarre la surveillance du heartbeat et le ping client
  void _startHeartbeatMonitor() {
    _stopHeartbeatMonitor();
    _lastHeartbeat = DateTime.now();

    // Vérifier le heartbeat toutes les 15 secondes
    _heartbeatTimer = Timer.periodic(const Duration(seconds: 15), (_) {
      _checkHeartbeat();
      _sendClientPing(); // Envoyer un ping pour maintenir la connexion
    });
  }

  /// Envoie un ping client pour maintenir la connexion active
  void _sendClientPing() {
    if (_socket != null && isConnected) {
      // Socket.IO gère automatiquement les pings, mais on peut envoyer
      // un événement custom pour s'assurer que la connexion est active
      _socket!.emit('ping_client', {
        'timestamp': DateTime.now().toIso8601String(),
        'conversationId': _currentConversationId,
      });
      debugPrint('[AdhaStreamService] 📤 Ping client envoyé');
    }
  }

  /// Arrête la surveillance du heartbeat
  void _stopHeartbeatMonitor() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
  }

  /// Vérifie si le dernier heartbeat est trop vieux
  void _checkHeartbeat() {
    if (_lastHeartbeat == null) return;

    final timeSinceLastHeartbeat = DateTime.now().difference(_lastHeartbeat!);
    if (timeSinceLastHeartbeat > _heartbeatTimeout) {
      debugPrint(
        '[AdhaStreamService] ⚠️ Heartbeat timeout - connexion peut-être perdue',
      );
      // Ne pas déconnecter automatiquement, laisser Socket.IO gérer
    }
  }

  // ========================================================================
  // Circuit Breaker Methods (v2.4.0)
  // ========================================================================

  /// Vérifie si une requête peut être effectuée
  bool _canMakeRequest() {
    switch (_circuitState) {
      case CircuitBreakerState.closed:
        return true;
      case CircuitBreakerState.open:
        // Vérifier si le timeout est passé
        if (_lastFailureTime != null) {
          final elapsed = DateTime.now().difference(_lastFailureTime!);
          if (elapsed >= _circuitTimeout) {
            _circuitState = CircuitBreakerState.halfOpen;
            debugPrint('[AdhaStreamService] Circuit breaker -> HALF-OPEN');
            return true;
          }
        }
        return false;
      case CircuitBreakerState.halfOpen:
        return true;
    }
  }

  /// Enregistre un échec
  void _recordFailure() {
    _failureCount++;
    _lastFailureTime = DateTime.now();

    if (_circuitState == CircuitBreakerState.halfOpen) {
      // Échec en mode test -> retour à OPEN
      _circuitState = CircuitBreakerState.open;
      debugPrint(
        '[AdhaStreamService] Circuit breaker -> OPEN (échec en half-open)',
      );
    } else if (_failureCount >= _failureThreshold) {
      _circuitState = CircuitBreakerState.open;
      debugPrint(
        '[AdhaStreamService] Circuit breaker -> OPEN (seuil atteint: $_failureCount échecs)',
      );
    }
  }

  /// Réinitialise le circuit breaker après succès
  void _resetCircuitBreaker() {
    _failureCount = 0;
    _lastFailureTime = null;
    _circuitState = CircuitBreakerState.closed;
    debugPrint('[AdhaStreamService] Circuit breaker -> CLOSED');
  }

  /// Gère les événements de streaming reçus
  ///
  /// Structure des données selon la documentation:
  /// ```json
  /// {
  ///   "id": "chunk-uuid-123",
  ///   "requestMessageId": "msg-456",
  ///   "conversationId": "conv-789",
  ///   "type": "chunk|end|error|tool_call|tool_result",
  ///   "content": "...",
  ///   "chunkId": 1,
  ///   "timestamp": "2026-01-09T12:00:01.123Z",
  ///   "userId": "user-abc",
  ///   "companyId": "company-xyz",
  ///   "metadata": { "source": "adha_ai_service", "streamVersion": "1.0.0" }
  /// }
  /// ```
  void _handleStreamEvent(dynamic data, String eventType) {
    try {
      Map<String, dynamic> json;

      if (data is Map<String, dynamic>) {
        json = data;
      } else if (data is Map) {
        json = Map<String, dynamic>.from(data);
      } else {
        debugPrint(
          '[AdhaStreamService] Type de données non supporté: ${data.runtimeType}',
        );
        return;
      }

      final chunk = AdhaStreamChunkEvent.fromJson(json);
      _chunkController.add(chunk);

      debugPrint(
        '[AdhaStreamService] 📩 $eventType reçu: conversationId=${chunk.conversationId}, '
        'chunkId=${chunk.chunkId}, type=${chunk.type.toJsonString()}',
      );
    } catch (e, stackTrace) {
      debugPrint('[AdhaStreamService] Erreur de parsing ($eventType): $e');
      debugPrint('[AdhaStreamService] StackTrace: $stackTrace');
      debugPrint('[AdhaStreamService] Données brutes: $data');
    }
  }

  /// S'abonner aux mises à jour d'une conversation
  ///
  /// Événement client→serveur: subscribe_conversation
  /// Payload: { conversationId: string }
  void subscribeToConversation(String conversationId) {
    if (_socket == null || !isConnected) {
      debugPrint('[AdhaStreamService] Impossible de s\'abonner: non connecté');
      return;
    }

    _currentConversationId = conversationId;
    _socket!.emit('subscribe_conversation', {'conversationId': conversationId});
    debugPrint(
      '[AdhaStreamService] 📝 Abonné à la conversation: $conversationId',
    );
  }

  /// Se désabonner d'une conversation
  ///
  /// Événement client→serveur: unsubscribe_conversation
  /// Payload: { conversationId: string }
  void unsubscribeFromConversation(String conversationId) {
    if (_socket == null) return;

    _socket!.emit('unsubscribe_conversation', {
      'conversationId': conversationId,
    });

    if (_currentConversationId == conversationId) {
      _currentConversationId = null;
    }

    debugPrint(
      '[AdhaStreamService] 📝 Désabonné de la conversation: $conversationId',
    );
  }

  /// Retourne l'URL de base pour Socket.IO
  ///
  /// Le client Socket.IO utilise HTTP/HTTPS pour la connexion initiale,
  /// puis upgrade automatiquement vers WebSocket si disponible.
  String _getSocketIOBaseUrl() {
    String baseUrl = EnvConfig.apiGatewayUrl;
    baseUrl = EnvConfig.getDeviceCompatibleUrl(baseUrl);
    return baseUrl;
  }

  /// Met à jour l'état de connexion
  void _updateConnectionState(AdhaStreamConnectionState newState) {
    if (_currentState != newState) {
      _currentState = newState;
      _connectionStateController.add(newState);
      debugPrint('[AdhaStreamService] État: ${newState.name}');
    }
  }

  /// Déconnecte du service de streaming
  Future<void> disconnect() async {
    debugPrint('[AdhaStreamService] Déconnexion...');

    _stopHeartbeatMonitor();

    if (_currentConversationId != null) {
      unsubscribeFromConversation(_currentConversationId!);
    }

    _socket?.disconnect();
    _socket?.dispose();
    _socket = null;

    _currentConversationId = null;
    _reconnectAttempts = 0;

    _updateConnectionState(AdhaStreamConnectionState.disconnected);
  }

  /// Ferme le service et libère les ressources
  void dispose() {
    debugPrint('[AdhaStreamService] Dispose...');

    _stopHeartbeatMonitor();
    _circuitResetTimer?.cancel();

    disconnect();

    if (!_chunkController.isClosed) {
      _chunkController.close();
    }
    if (!_connectionStateController.isClosed) {
      _connectionStateController.close();
    }
  }

  /// Vérifie si le service est connecté
  bool get isConnected => _currentState == AdhaStreamConnectionState.connected;

  /// Retourne l'ID de la conversation actuellement abonnée
  String? get currentConversationId => _currentConversationId;

  /// Retourne le token d'authentification
  String? get authToken => _authToken;
}
