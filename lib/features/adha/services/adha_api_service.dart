import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:wanzo/core/services/api_client.dart';
import '../models/adha_message.dart';
import '../models/adha_context_info.dart';
import '../models/adha_attachment.dart';

/// Service API pour les interactions avec ADHA (Assistant Digital pour Heure d'Affaires)
///
/// Endpoints selon la documentation (Janvier 2026):
/// - POST /api/v1/commerce/adha/message - Envoyer un message
/// - GET /api/v1/commerce/adha/conversations - Récupérer les conversations
/// - GET /api/v1/commerce/adha/conversations/{id}/messages - Historique d'une conversation
class AdhaApiService {
  final ApiClient _apiClient;

  AdhaApiService(this._apiClient);

  /// Envoie un message à ADHA (mode synchrone)
  ///
  /// Endpoint: POST /api/v1/commerce/adha/message
  ///
  /// Corps de la requête (SendMessageDto):
  /// - text: String (requis) - Texte du message
  /// - conversationId: String? (optionnel) - UUID pour conversation existante
  /// - timestamp: String (requis) - ISO8601 datetime
  /// - contextInfo: AdhaContextInfoDto (requis) - Contexte de l'interaction
  /// - attachment: AttachmentDto? (optionnel) - Pièce jointe
  ///
  /// Réponse:
  /// ```json
  /// {
  ///   "success": true,
  ///   "message": "Reply successfully generated.",
  ///   "statusCode": 200,
  ///   "data": {
  ///     "conversationId": "uuid",
  ///     "messages": [{ "id", "text", "sender", "timestamp", "contextInfo" }]
  ///   }
  /// }
  /// ```
  Future<Map<String, dynamic>> sendMessage({
    required String messageText,
    String? conversationId,
    required AdhaContextInfo contextInfo,
    AdhaAttachment? attachment,
    String?
    companyId, // Requis par ADHA AI pour accéder aux données de l'entreprise
    String? userId,
  }) async {
    final body = {
      'text': messageText,
      if (conversationId != null && conversationId.isNotEmpty)
        'conversationId': conversationId,
      'timestamp': DateTime.now().toIso8601String(),
      'contextInfo': contextInfo.toJson(),
      if (attachment != null) 'attachment': attachment.toJson(),
      // companyId et userId sont requis par ADHA AI pour accéder aux données
      if (companyId != null) 'companyId': companyId,
      if (userId != null) 'userId': userId,
    };

    // Debug logging pour voir ce qui est envoyé
    debugPrint('[AdhaApiService] ==========================================');
    debugPrint('[AdhaApiService] Envoi de message à /adha/message');
    debugPrint('[AdhaApiService] conversationId: $conversationId');
    debugPrint(
      '[AdhaApiService] text: ${messageText.length > 50 ? '${messageText.substring(0, 50)}...' : messageText}',
    );
    debugPrint(
      '[AdhaApiService] contextInfo.interactionType: ${contextInfo.interactionContext.interactionType.value}',
    );
    debugPrint(
      '[AdhaApiService] contextInfo.businessProfile.name: ${contextInfo.baseContext.businessProfile.name}',
    );
    debugPrint('[AdhaApiService] FULL BODY JSON:');
    try {
      final jsonString = const JsonEncoder.withIndent('  ').convert(body);
      // Split long logs to avoid truncation
      final lines = jsonString.split('\n');
      for (final line in lines) {
        debugPrint('[AdhaApiService] $line');
      }
    } catch (e) {
      debugPrint('[AdhaApiService] Failed to encode body: $e');
    }
    debugPrint('[AdhaApiService] ==========================================');

    // L'ApiClient ajoute automatiquement le préfixe commerce/api/v1
    // requiresAuth: true pour envoyer le token JWT dans l'en-tête Authorization
    // customTimeoutMs: 120s car ADHA peut prendre du temps pour générer une réponse IA
    // bypassCircuitBreaker: true car les requêtes ADHA sont importantes et peuvent être lentes
    final response = await _apiClient.post(
      'adha/message',
      body: body,
      requiresAuth: true,
      customTimeoutMs: ApiClient.adhaTimeoutMs, // 120 secondes pour ADHA
      bypassCircuitBreaker:
          true, // ADHA ne doit pas être bloqué par le circuit breaker
    );
    return response as Map<String, dynamic>;
  }

  /// Envoie un message à ADHA (mode streaming v2.5.0)
  ///
  /// Endpoint: POST /api/v1/commerce/adha/stream
  ///
  /// Ce nouvel endpoint déclenche le streaming via WebSocket.
  /// La réponse arrive en temps réel via les événements Socket.IO.
  ///
  /// Corps de la requête (SendMessageDto):
  /// - text: String (requis) - Texte du message
  /// - conversationId: String? (optionnel) - UUID pour conversation existante
  /// - timestamp: String (requis) - ISO8601 datetime
  /// - contextInfo: AdhaContextInfoDto (requis) - Contexte de l'interaction
  /// - attachment: AttachmentDto? (optionnel) - Pièce jointe
  ///
  /// Réponse (200):
  /// ```json
  /// {
  ///   "success": true,
  ///   "message": "Streaming initiated.",
  ///   "statusCode": 200,
  ///   "data": {
  ///     "conversationId": "uuid",
  ///     "requestMessageId": "uuid"
  ///   }
  /// }
  /// ```
  Future<Map<String, dynamic>> sendStreamingMessage({
    required String messageText,
    String? conversationId,
    required AdhaContextInfo contextInfo,
    AdhaAttachment? attachment,
    String?
    companyId, // Requis par ADHA AI pour accéder aux données de l'entreprise
    String? userId,
  }) async {
    final body = {
      'text': messageText,
      if (conversationId != null) 'conversationId': conversationId,
      'timestamp': DateTime.now().toIso8601String(),
      'contextInfo': contextInfo.toJson(),
      if (attachment != null) 'attachment': attachment.toJson(),
      // companyId et userId sont requis par ADHA AI pour accéder aux données
      if (companyId != null) 'companyId': companyId,
      if (userId != null) 'userId': userId,
    };

    // Utilise le nouvel endpoint /stream pour le mode streaming (v2.5.0)
    // requiresAuth: true pour envoyer le token JWT dans l'en-tête Authorization
    // Note: Le streaming retourne rapidement avec conversationId et requestMessageId
    // Les chunks arrivent via WebSocket, donc un timeout court suffit
    final response = await _apiClient.post(
      'adha/stream',
      body: body,
      requiresAuth: true,
      customTimeoutMs: 30000, // 30 secondes suffit car la réponse est rapide
      bypassCircuitBreaker:
          true, // ADHA ne doit pas être bloqué par le circuit breaker
    );
    return response as Map<String, dynamic>;
  }

  /// Récupère la liste des conversations
  ///
  /// Endpoint: GET /api/v1/commerce/adha/conversations
  ///
  /// Query params:
  /// - page: number (défaut: 1)
  /// - limit: number (défaut: 10)
  /// - sortBy: string (défaut: lastMessageTimestamp)
  /// - sortOrder: string (défaut: desc)
  ///
  /// Réponse:
  /// ```json
  /// {
  ///   "success": true,
  ///   "data": [{ "id", "userId", "title", "lastMessageTimestamp", "createdAt", "updatedAt" }],
  ///   "pagination": { "total", "page", "limit", "totalPages" }
  /// }
  /// ```
  Future<AdhaConversationsResponse> getConversations({
    int page = 1,
    int limit = 10,
    String sortBy = 'lastMessageTimestamp',
    String sortOrder = 'desc',
  }) async {
    final queryParams = {
      'page': page.toString(),
      'limit': limit.toString(),
      'sortBy': sortBy,
      'sortOrder': sortOrder,
    };

    final response = await _apiClient.get(
      'adha/conversations',
      queryParameters: queryParams,
      requiresAuth: true,
      bypassCircuitBreaker:
          true, // ADHA ne doit pas être bloqué par le circuit breaker
    );

    return AdhaConversationsResponse.fromJson(response as Map<String, dynamic>);
  }

  /// Récupère l'historique d'une conversation
  ///
  /// Endpoint: GET /api/v1/commerce/adha/conversations/{conversationId}/messages
  ///
  /// Query params:
  /// - page: number (défaut: 1)
  /// - limit: number (défaut: 20)
  ///
  /// Réponse:
  /// ```json
  /// {
  ///   "success": true,
  ///   "data": [{ "id", "conversationId", "text", "sender", "timestamp", "contextInfo" }],
  ///   "pagination": { "total", "page", "limit", "totalPages" }
  /// }
  /// ```
  Future<AdhaMessagesResponse> getConversationHistory(
    String conversationId, {
    int page = 1,
    int limit = 20,
  }) async {
    final queryParams = {'page': page.toString(), 'limit': limit.toString()};

    final response = await _apiClient.get(
      'adha/conversations/$conversationId/messages',
      queryParameters: queryParams,
      requiresAuth: true,
      bypassCircuitBreaker:
          true, // ADHA ne doit pas être bloqué par le circuit breaker
    );

    return AdhaMessagesResponse.fromJson(response as Map<String, dynamic>);
  }
}

// ============================================================================
// MODÈLES DE RÉPONSE API
// ============================================================================

/// Informations de pagination
class PaginationInfo {
  final int total;
  final int page;
  final int limit;
  final int totalPages;

  const PaginationInfo({
    required this.total,
    required this.page,
    required this.limit,
    required this.totalPages,
  });

  factory PaginationInfo.fromJson(Map<String, dynamic> json) {
    return PaginationInfo(
      total: json['total'] as int? ?? 0,
      page: json['page'] as int? ?? 1,
      limit: json['limit'] as int? ?? 10,
      totalPages: json['totalPages'] as int? ?? 1,
    );
  }
}

/// Réponse de la liste des conversations
class AdhaConversationsResponse {
  final bool success;
  final String? message;
  final List<AdhaConversationSummary> conversations;
  final PaginationInfo? pagination;

  const AdhaConversationsResponse({
    required this.success,
    this.message,
    required this.conversations,
    this.pagination,
  });

  factory AdhaConversationsResponse.fromJson(Map<String, dynamic> json) {
    final dataList = json['data'] as List<dynamic>? ?? [];

    return AdhaConversationsResponse(
      success: json['success'] as bool? ?? true,
      message: json['message'] as String?,
      conversations:
          dataList
              .map(
                (item) => AdhaConversationSummary.fromJson(
                  item as Map<String, dynamic>,
                ),
              )
              .toList(),
      pagination:
          json['pagination'] != null
              ? PaginationInfo.fromJson(
                json['pagination'] as Map<String, dynamic>,
              )
              : null,
    );
  }
}

/// Résumé d'une conversation (sans les messages)
class AdhaConversationSummary {
  final String id;
  final String userId;
  final String? title;
  final DateTime? lastMessageTimestamp;
  final DateTime createdAt;
  final DateTime updatedAt;

  const AdhaConversationSummary({
    required this.id,
    required this.userId,
    this.title,
    this.lastMessageTimestamp,
    required this.createdAt,
    required this.updatedAt,
  });

  factory AdhaConversationSummary.fromJson(Map<String, dynamic> json) {
    return AdhaConversationSummary(
      id: json['id'] as String,
      userId: json['userId'] as String,
      title: json['title'] as String?,
      lastMessageTimestamp:
          json['lastMessageTimestamp'] != null
              ? DateTime.parse(json['lastMessageTimestamp'] as String)
              : null,
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
    );
  }
}

/// Réponse de l'historique des messages
class AdhaMessagesResponse {
  final bool success;
  final String? message;
  final List<AdhaMessage> messages;
  final PaginationInfo? pagination;

  const AdhaMessagesResponse({
    required this.success,
    this.message,
    required this.messages,
    this.pagination,
  });

  factory AdhaMessagesResponse.fromJson(Map<String, dynamic> json) {
    final dataList = json['data'] as List<dynamic>? ?? [];

    return AdhaMessagesResponse(
      success: json['success'] as bool? ?? true,
      message: json['message'] as String?,
      messages:
          dataList
              .map((item) => AdhaMessage.fromJson(item as Map<String, dynamic>))
              .toList(),
      pagination:
          json['pagination'] != null
              ? PaginationInfo.fromJson(
                json['pagination'] as Map<String, dynamic>,
              )
              : null,
    );
  }
}

/// Réponse de l'envoi d'un message
class AdhaSendMessageResponse {
  final bool success;
  final String? message;
  final String conversationId;
  final List<AdhaMessage> messages;

  const AdhaSendMessageResponse({
    required this.success,
    this.message,
    required this.conversationId,
    required this.messages,
  });

  factory AdhaSendMessageResponse.fromJson(Map<String, dynamic> json) {
    final data = json['data'] as Map<String, dynamic>? ?? {};
    final messagesList = data['messages'] as List<dynamic>? ?? [];

    return AdhaSendMessageResponse(
      success: json['success'] as bool? ?? true,
      message: json['message'] as String?,
      conversationId: data['conversationId'] as String? ?? '',
      messages:
          messagesList
              .map((item) => AdhaMessage.fromJson(item as Map<String, dynamic>))
              .toList(),
    );
  }
}
