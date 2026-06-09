import 'package:hive/hive.dart';
import 'package:flutter/foundation.dart';
import '../models/adha_message.dart';
import '../models/adha_context_info.dart';
import '../models/adha_attachment.dart';
import '../services/adha_api_service.dart';

/// Repository pour gérer les interactions avec l'assistant Adha
///
/// Ce repository gère:
/// - Le cache local des conversations (Hive) - isolées par utilisateur
/// - Les appels API vers le backend ADHA
/// - La synchronisation entre local et distant
class AdhaRepository {
  static const _conversationsBoxNamePrefix = 'adha_conversations';
  static const _stateBoxName = 'adha_state';
  static const _activeConversationKey = 'activeConversationId';

  Box<AdhaConversation>? _conversationsBox;
  Box<String>?
  _stateBox; // Box pour stocker l'état (activeConversationId, etc.)

  /// ID de l'utilisateur actuellement connecté (pour isoler les conversations)
  String? _currentUserId;

  /// Service API pour les appels backend (optionnel, peut être null pour le mode offline)
  final AdhaApiService? apiService;

  AdhaRepository({this.apiService});

  /// Retourne le nom de la box Hive pour l'utilisateur actuel
  String _getBoxName(String? userId) {
    if (userId == null || userId.isEmpty) {
      return _conversationsBoxNamePrefix;
    }
    // Nettoyer l'userId pour un nom de box valide (sans caractères spéciaux)
    final sanitizedUserId = userId.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');
    return '${_conversationsBoxNamePrefix}_$sanitizedUserId';
  }

  /// Initialise le repository pour un utilisateur spécifique
  ///
  /// [userId] L'ID de l'utilisateur connecté. Si null, utilise une box globale.
  /// En cas d'erreur de lecture Hive (données corrompues ou format changé),
  /// la box est supprimée et recréée vide.
  /// Retourne true si l'utilisateur a changé (nouvelle initialisation), false sinon.
  Future<bool> init({String? userId}) async {
    final bool userChanged = _currentUserId != userId;

    // Si on change d'utilisateur, fermer l'ancienne box
    if (userChanged && _conversationsBox != null) {
      try {
        await _conversationsBox!.close();
      } catch (e) {
        debugPrint('[AdhaRepository] ⚠️ Erreur fermeture box: $e');
      }
      _conversationsBox = null;
      debugPrint(
        '[AdhaRepository] 📦 Fermeture de la box pour changement d\'utilisateur',
      );
    }

    _currentUserId = userId;
    final boxName = _getBoxName(userId);
    debugPrint('[AdhaRepository] 📦 Ouverture de la box: $boxName');

    try {
      _conversationsBox = await Hive.openBox<AdhaConversation>(boxName);
      debugPrint(
        '[AdhaRepository] ✅ Box ouverte avec ${_conversationsBox!.length} conversations',
      );
    } catch (e) {
      // Erreur de lecture Hive - données corrompues ou format incompatible
      debugPrint(
        '[AdhaRepository] ⚠️ Erreur Hive, suppression de la box corrompue: $e',
      );

      // Supprimer la box corrompue - plusieurs tentatives pour Windows
      bool deleteSuccess = false;
      for (int attempt = 0; attempt < 3 && !deleteSuccess; attempt++) {
        try {
          // Attendre un peu avant de réessayer (le fichier peut être en cours de libération)
          if (attempt > 0) {
            await Future.delayed(Duration(milliseconds: 500 * attempt));
          }
          await Hive.deleteBoxFromDisk(boxName);
          deleteSuccess = true;
          debugPrint(
            '[AdhaRepository] ✅ Box supprimée avec succès (tentative ${attempt + 1})',
          );
        } catch (deleteError) {
          debugPrint(
            '[AdhaRepository] ⚠️ Tentative ${attempt + 1}/3 de suppression échouée: $deleteError',
          );
        }
      }

      // Si la suppression a échoué, on continue avec une box en mémoire temporaire
      // ou on réessaye d'ouvrir la box (peut fonctionner si les données sont accessibles)
      try {
        _conversationsBox = await Hive.openBox<AdhaConversation>(boxName);
        debugPrint('[AdhaRepository] ✅ Nouvelle box créée/ouverte');
      } catch (reopenError) {
        debugPrint('[AdhaRepository] ❌ Échec réouverture: $reopenError');
        // Créer une box en mémoire comme fallback pour ne pas bloquer l'app
        // L'utilisateur perdra l'historique local mais pourra continuer
        debugPrint(
          '[AdhaRepository] ⚠️ Utilisation d\'un cache mémoire temporaire',
        );
        // Note: Hive n'a pas de mode mémoire simple, on va ignorer le cache local
        // et fonctionner uniquement avec l'API
        _conversationsBox = null;
      }
    }

    // Ouvrir la box d'état (partagée entre tous les utilisateurs)
    try {
      if (_stateBox == null || !_stateBox!.isOpen) {
        _stateBox = await Hive.openBox<String>(_stateBoxName);
        debugPrint('[AdhaRepository] ✅ Box d\'état ouverte');
      }
    } catch (e) {
      debugPrint('[AdhaRepository] ⚠️ Erreur ouverture box état: $e');
      await Hive.deleteBoxFromDisk(_stateBoxName);
      _stateBox = await Hive.openBox<String>(_stateBoxName);
    }

    return userChanged;
  }

  /// Retourne true si le repository est déjà initialisé pour un utilisateur donné
  bool isInitializedForUser(String? userId) {
    return _currentUserId == userId &&
        _conversationsBox != null &&
        _conversationsBox!.isOpen;
  }

  /// Sauvegarde l'ID de la conversation active (persistance entre sessions)
  Future<void> saveActiveConversationId(String? conversationId) async {
    if (_stateBox == null || !_stateBox!.isOpen) {
      debugPrint('[AdhaRepository] ⚠️ State box non initialisée');
      return;
    }

    final key = '${_activeConversationKey}_${_currentUserId ?? 'default'}';
    if (conversationId == null) {
      await _stateBox!.delete(key);
      debugPrint('[AdhaRepository] 🗑️ Active conversation ID supprimé');
    } else {
      await _stateBox!.put(key, conversationId);
      debugPrint(
        '[AdhaRepository] 💾 Active conversation ID sauvegardé: $conversationId',
      );
    }
  }

  /// Récupère l'ID de la conversation active depuis le cache
  String? getActiveConversationId() {
    if (_stateBox == null || !_stateBox!.isOpen) {
      return null;
    }

    final key = '${_activeConversationKey}_${_currentUserId ?? 'default'}';
    final id = _stateBox!.get(key);
    debugPrint('[AdhaRepository] 📖 Active conversation ID lu: $id');
    return id;
  }

  /// Ferme la box et nettoie les ressources (appelé lors de la déconnexion)
  Future<void> close() async {
    if (_conversationsBox != null && _conversationsBox!.isOpen) {
      await _conversationsBox!.close();
      _conversationsBox = null;
      _currentUserId = null;
      debugPrint('[AdhaRepository] 📦 Box fermée');
    }
  }

  /// Vérifie que la box est initialisée
  /// Retourne true si la box est disponible, false si on est en mode fallback
  bool _isBoxAvailable() {
    return _conversationsBox != null && _conversationsBox!.isOpen;
  }

  /// Récupère toutes les conversations (cache local)
  /// Retourne une liste vide si le cache n'est pas disponible
  Future<List<AdhaConversation>> getConversations() async {
    if (!_isBoxAvailable()) {
      debugPrint(
        '[AdhaRepository] ⚠️ Cache indisponible, liste vide retournée',
      );
      return [];
    }
    return _conversationsBox!.values.toList();
  }

  /// Récupère une conversation spécifique (cache local)
  /// Retourne null si le cache n'est pas disponible
  Future<AdhaConversation?> getConversation(String conversationId) async {
    if (!_isBoxAvailable()) {
      debugPrint('[AdhaRepository] ⚠️ Cache indisponible, null retourné');
      return null;
    }
    return _conversationsBox!.get(conversationId);
  }

  /// Sauvegarde une conversation (cache local)
  /// Ne fait rien si le cache n'est pas disponible
  Future<void> saveConversation(AdhaConversation conversation) async {
    if (!_isBoxAvailable()) {
      debugPrint('[AdhaRepository] ⚠️ Cache indisponible, sauvegarde ignorée');
      return;
    }
    await _conversationsBox!.put(conversation.id, conversation);
  }

  /// Supprime une conversation (cache local)
  /// Ne fait rien si le cache n'est pas disponible
  Future<void> deleteConversation(String conversationId) async {
    if (!_isBoxAvailable()) {
      debugPrint('[AdhaRepository] ⚠️ Cache indisponible, suppression ignorée');
      return;
    }
    await _conversationsBox!.delete(conversationId);
  }

  /// Récupère les conversations depuis le serveur et synchronise le cache
  Future<List<AdhaConversationSummary>> fetchConversationsFromServer({
    int page = 1,
    int limit = 10,
  }) async {
    if (apiService == null) {
      debugPrint('[AdhaRepository] API service non configuré, mode offline');
      return [];
    }

    try {
      final response = await apiService!.getConversations(
        page: page,
        limit: limit,
      );
      return response.conversations;
    } catch (e) {
      debugPrint(
        '[AdhaRepository] Erreur lors de la récupération des conversations: $e',
      );
      rethrow;
    }
  }

  /// Récupère l'historique d'une conversation depuis le serveur
  Future<List<AdhaMessage>> fetchConversationHistoryFromServer(
    String conversationId, {
    int page = 1,
    int limit = 20,
  }) async {
    if (apiService == null) {
      debugPrint('[AdhaRepository] API service non configuré, mode offline');
      return [];
    }

    try {
      final response = await apiService!.getConversationHistory(
        conversationId,
        page: page,
        limit: limit,
      );
      return response.messages;
    } catch (e) {
      debugPrint(
        '[AdhaRepository] Erreur lors de la récupération de l\'historique: $e',
      );
      rethrow;
    }
  }

  /// Envoie un message à l'API Adha et retourne la réponse
  ///
  /// Cette méthode:
  /// 1. Appelle l'API backend si disponible
  /// 2. Retourne le contenu de la réponse d'ADHA et le conversationId
  /// 3. En mode offline, informe l'utilisateur que la connexion est nécessaire
  ///
  /// Note: En production, les réponses arrivent via WebSocket streaming.
  /// Cette méthode REST est utilisée comme déclencheur de la conversation,
  /// la réponse finale arrive via le stream.
  ///
  /// Returns: Un record avec (content, conversationId)
  /// - content: Le texte de la réponse d'ADHA (peut être vide si streaming)
  /// - conversationId: L'ID de la conversation créée/utilisée par le backend
  Future<({String content, String conversationId})> sendMessage({
    String? conversationId, // Null pour une nouvelle conversation
    required String message,
    AdhaContextInfo? contextInfo,
    String? companyId, // Requis par ADHA AI pour accéder aux données
    String? userId,
  }) async {
    // Vérifier si le service API est disponible
    if (apiService == null) {
      debugPrint('[AdhaRepository] API service non configuré');
      throw AdhaServiceException(
        code: 'API_NOT_CONFIGURED',
        message:
            'Le service ADHA n\'est pas configuré. Veuillez vérifier votre connexion.',
      );
    }

    // Vérifier si le contexte est fourni
    if (contextInfo == null) {
      throw AdhaServiceException(
        code: 'MISSING_CONTEXT',
        message:
            'Le contexte de l\'interaction est requis pour envoyer un message.',
      );
    }

    try {
      final response = await apiService!.sendMessage(
        messageText: message,
        conversationId:
            conversationId, // Peut être null pour nouvelle conversation
        contextInfo: contextInfo,
        companyId: companyId,
        userId: userId,
      );

      // Extraire la réponse de l'IA et le conversationId depuis la structure de réponse
      final data = response['data'] as Map<String, dynamic>?;
      String responseContent = '';
      String backendConversationId = conversationId ?? '';

      if (data != null) {
        // Récupérer le conversationId retourné par le backend (important pour les nouvelles conversations)
        backendConversationId =
            data['conversationId'] as String? ?? conversationId ?? '';

        final messages = data['messages'] as List<dynamic>?;
        if (messages != null && messages.isNotEmpty) {
          // Prendre le dernier message (la réponse de l'IA)
          final lastMessage = messages.last as Map<String, dynamic>;
          responseContent = lastMessage['text'] as String? ?? '';
        }
      }

      debugPrint(
        '[AdhaRepository] conversationId retourné par backend: $backendConversationId',
      );

      return (content: responseContent, conversationId: backendConversationId);
    } on AdhaServiceException {
      rethrow;
    } catch (e) {
      debugPrint('[AdhaRepository] Erreur lors de l\'envoi du message: $e');
      debugPrint('[AdhaRepository] Type d\'erreur: ${e.runtimeType}');

      // Si c'est une BadRequestException, afficher les détails de validation
      if (e.toString().contains('BadRequest') || e.toString().contains('400')) {
        debugPrint('[AdhaRepository] Détails de l\'erreur 400: $e');
      }

      // Analyser l'erreur pour donner un message approprié
      final errorMessage = _parseApiError(e);
      throw AdhaServiceException(
        code: 'API_ERROR',
        message: errorMessage,
        originalError: e,
      );
    }
  }

  /// Envoie un message en mode streaming (v2.5.0)
  ///
  /// Utilise le nouvel endpoint POST /api/v1/commerce/adha/stream
  /// La réponse arrive en temps réel via WebSocket (événements Socket.IO)
  ///
  /// [conversationId] est optionnel - null pour une nouvelle conversation
  ///
  /// Returns: Un record avec conversationId et requestMessageId
  Future<({String conversationId, String requestMessageId})>
  sendStreamingMessage({
    String? conversationId, // Null pour une nouvelle conversation
    required String message,
    AdhaContextInfo? contextInfo,
    List<AdhaAttachment>? attachments,
    String? companyId, // Requis par ADHA AI pour accéder aux données
    String? userId,
  }) async {
    // Vérifier si le service API est disponible
    if (apiService == null) {
      debugPrint('[AdhaRepository] API service non configuré');
      throw AdhaServiceException(
        code: 'API_NOT_CONFIGURED',
        message:
            'Le service ADHA n\'est pas configuré. Veuillez vérifier votre connexion.',
      );
    }

    // Vérifier si le contexte est fourni
    if (contextInfo == null) {
      throw AdhaServiceException(
        code: 'MISSING_CONTEXT',
        message:
            'Le contexte de l\'interaction est requis pour envoyer un message.',
      );
    }

    try {
      // Utiliser la première pièce jointe si disponible (l'API supporte une seule pièce jointe)
      final attachment =
          attachments?.isNotEmpty == true ? attachments!.first : null;

      final response = await apiService!.sendStreamingMessage(
        messageText: message,
        conversationId: conversationId,
        contextInfo: contextInfo,
        attachment: attachment,
        companyId: companyId,
        userId: userId,
      );

      // Extraire conversationId et requestMessageId de la réponse
      final data = response['data'] as Map<String, dynamic>?;
      if (data != null) {
        final responseConversationId =
            data['conversationId'] as String? ?? conversationId ?? '';
        final requestMessageId = data['requestMessageId'] as String? ?? '';
        return (
          conversationId: responseConversationId,
          requestMessageId: requestMessageId,
        );
      }

      // Fallback
      return (conversationId: conversationId ?? '', requestMessageId: '');
    } on AdhaServiceException {
      rethrow;
    } catch (e) {
      debugPrint('[AdhaRepository] Erreur lors de l\'envoi streaming: $e');

      // Analyser l'erreur pour donner un message approprié
      final errorMessage = _parseApiError(e);
      throw AdhaServiceException(
        code: 'API_ERROR',
        message: errorMessage,
        originalError: e,
      );
    }
  }

  /// Envoie un message audio en mode streaming (v2.6.0)
  ///
  /// Utilise l'endpoint POST /api/v1/commerce/adha/audio/stream
  /// L'audio base64 est transcrit et traité via le même pipeline Kafka que le texte.
  /// La réponse arrive via Socket.IO (text chunks + audio chunks TTS).
  Future<({String conversationId, String requestMessageId})>
  sendAudioStreamingMessage({
    String? conversationId,
    required String audioBase64,
    String filename = 'recording.wav',
    String? voice,
    String? language,
    AdhaContextInfo? contextInfo,
    String? companyId,
    String? userId,
  }) async {
    if (apiService == null) {
      throw AdhaServiceException(
        code: 'API_NOT_CONFIGURED',
        message: 'Le service ADHA n\'est pas configuré.',
      );
    }

    try {
      final response = await apiService!.sendAudioStreamingMessage(
        audioBase64: audioBase64,
        filename: filename,
        conversationId: conversationId,
        voice: voice,
        language: language,
        contextInfo: contextInfo,
        companyId: companyId,
        userId: userId,
      );

      final data = response['data'] as Map<String, dynamic>?;
      if (data != null) {
        return (
          conversationId:
              data['conversationId'] as String? ?? conversationId ?? '',
          requestMessageId: data['requestMessageId'] as String? ?? '',
        );
      }
      return (conversationId: conversationId ?? '', requestMessageId: '');
    } on AdhaServiceException {
      rethrow;
    } catch (e) {
      debugPrint('[AdhaRepository] Erreur envoi audio streaming: $e');
      throw AdhaServiceException(
        code: 'API_ERROR',
        message: _parseApiError(e),
        originalError: e,
      );
    }
  }

  /// Analyse une erreur API et retourne un message utilisateur approprié
  String _parseApiError(dynamic error) {
    final errorString = error.toString().toLowerCase();

    if (errorString.contains('socketexception') ||
        errorString.contains('connection refused') ||
        errorString.contains('network')) {
      return 'Impossible de se connecter au serveur. Vérifiez votre connexion internet.';
    }

    if (errorString.contains('401') || errorString.contains('unauthorized')) {
      return 'Votre session a expiré. Veuillez vous reconnecter.';
    }

    if (errorString.contains('403') || errorString.contains('forbidden')) {
      return 'Vous n\'avez pas accès à cette fonctionnalité.';
    }

    if (errorString.contains('404') || errorString.contains('not found')) {
      return 'Le service ADHA n\'est pas disponible actuellement.';
    }

    if (errorString.contains('500') ||
        errorString.contains('internal server')) {
      return 'Une erreur serveur est survenue. Veuillez réessayer plus tard.';
    }

    if (errorString.contains('timeout')) {
      return 'Le serveur met trop de temps à répondre. Veuillez réessayer.';
    }

    return 'Une erreur est survenue lors de la communication avec ADHA. Veuillez réessayer.';
  }
}

/// Exception personnalisée pour les erreurs du service ADHA
class AdhaServiceException implements Exception {
  final String code;
  final String message;
  final dynamic originalError;

  const AdhaServiceException({
    required this.code,
    required this.message,
    this.originalError,
  });

  @override
  String toString() => 'AdhaServiceException[$code]: $message';
}
