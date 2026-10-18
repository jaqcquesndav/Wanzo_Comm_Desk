import '../../../core/exceptions/api_exceptions.dart';
import '../../../core/services/account_block_notifier.dart';
import '../../../core/services/api_client.dart';
import '../models/join_request.dart';

/// Appels du serveur pour les demandes de rattachement par code.
///
/// Ces actions exigent le réseau : aucune n'est mise en file hors ligne
/// (`queueOffline: false`). Une décision rejouée plus tard, à l'insu de
/// l'utilisateur, n'aurait pas de sens.
class JoinRequestService {
  static const String _base = 'settings-user-profile/company/join-requests';

  final ApiClient _apiClient;

  JoinRequestService({ApiClient? apiClient})
    : _apiClient = apiClient ?? ApiClient();

  /// Ma dernière demande (null si aucune).
  Future<JoinRequest?> fetchMine() async {
    final response = await _apiClient.get('$_base/mine', requiresAuth: true);
    final data = unwrapGestionData(response);
    if (data is Map) return JoinRequest.fromJson(Map<String, dynamic>.from(data));
    return null;
  }

  /// Annule ma demande en attente (404 si aucune).
  Future<JoinRequest?> cancelMine() async {
    final response = await _apiClient.delete(
      '$_base/mine',
      requiresAuth: true,
      queueOffline: false,
    );
    final data = unwrapGestionData(response);
    if (data is Map) return JoinRequest.fromJson(Map<String, dynamic>.from(data));
    return null;
  }

  /// Demandes de l'entreprise (administrateur ou propriétaire).
  Future<JoinRequestPage> list({
    String status = JoinRequestStatus.pending,
    int page = 1,
    int limit = 20,
  }) async {
    final safeLimit = limit.clamp(1, 100);
    final response = await _apiClient.get(
      _base,
      requiresAuth: true,
      queryParameters: {
        'status': status,
        'page': '$page',
        'limit': '$safeLimit',
      },
    );
    final data = unwrapGestionData(response);
    if (data is Map) {
      return JoinRequestPage.fromJson(
        Map<String, dynamic>.from(data),
        fallbackLimit: safeLimit,
      );
    }
    return JoinRequestPage(items: const [], total: 0, page: page, limit: safeLimit);
  }

  /// Nombre de demandes en attente (badge).
  Future<int> pendingCount() async {
    final page = await list(status: JoinRequestStatus.pending, limit: 1);
    return page.total;
  }

  /// Accepte une demande avec un rôle (défaut : employé).
  Future<JoinRequest?> accept(String id, {String role = kDefaultGrantedRole}) async {
    final response = await _apiClient.post(
      '$_base/$id/accept',
      body: {'role': role},
      requiresAuth: true,
      queueOffline: false,
    );
    final data = unwrapGestionData(response);
    if (data is Map) return JoinRequest.fromJson(Map<String, dynamic>.from(data));
    return null;
  }

  /// Refuse une demande, avec un motif facultatif.
  Future<JoinRequest?> refuse(String id, {String? reason}) async {
    final trimmed = reason?.trim();
    final response = await _apiClient.post(
      '$_base/$id/refuse',
      body: {if (trimmed != null && trimmed.isNotEmpty) 'reason': trimmed},
      requiresAuth: true,
      queueOffline: false,
    );
    final data = unwrapGestionData(response);
    if (data is Map) return JoinRequest.fromJson(Map<String, dynamic>.from(data));
    return null;
  }
}

/// Message générique de l'intercepteur de gestion, à ne jamais afficher.
const String _genericInterceptorMessage = 'Operation successful';

/// Déballe la réponse de gestion_commerciale.
///
/// L'intercepteur global ré-enveloppe ce que renvoie le contrôleur :
/// `{success, message, data: {success, message, data: <résultat>}}`. Lire
/// `response['data']` une seule fois rendait l'enveloppe intérieure au lieu
/// du résultat. On déballe tant que la forme `{success, data}` se répète.
dynamic unwrapGestionData(dynamic response) {
  var current = response;
  var guard = 0;
  while (current is Map &&
      current.containsKey('success') &&
      current.containsKey('data') &&
      guard < 4) {
    current = current['data'];
    guard++;
  }
  return current;
}

/// Message le plus précis de la réponse (enveloppe intérieure d'abord).
String? unwrapGestionMessage(dynamic response) {
  String? found;
  var current = response;
  var guard = 0;
  while (current is Map && guard < 4) {
    final m = current['message'];
    if (m is String && m.trim().isNotEmpty && m != _genericInterceptorMessage) {
      found = m.trim();
    }
    if (!(current.containsKey('success') && current.containsKey('data'))) break;
    current = current['data'];
    guard++;
  }
  return found;
}

/// Texte affichable pour une erreur des demandes de rattachement.
///
/// Le serveur rédige des messages précis en français : on les affiche tels
/// quels. Les textes par défaut du client HTTP (en anglais) sont remplacés par
/// un message par code d'état.
String joinRequestErrorMessage(Object error) {
  if (error is OfflineQueuedException || error is NetworkException) {
    return "Pas de connexion internet. Cette action demande le réseau : "
        'reconnectez-vous puis réessayez.';
  }
  if (error is ApiException) {
    // Codes stables du serveur : un texte clair plutôt que le message brut.
    if (AccountBlockNotifier.codeErreur(error.responseBody) ==
        'ALREADY_MEMBER_ELSEWHERE') {
      return "Ce compte est déjà membre d'une autre entreprise.";
    }
    final server = _serverMessage(error.responseBody);
    if (server != null) return server;
    switch (error.statusCode) {
      case 400:
        return "Cette unité d'affaires est inactive ou la demande est incomplète.";
      case 403:
        return "Ce code appartient à une autre entreprise, ou vous n'avez pas le droit de faire cette action.";
      case 404:
        return "Code inconnu. Vérifiez-le auprès de votre administrateur.";
      case 409:
        return "Ce code désigne plusieurs entreprises. Demandez à votre "
            "administrateur le code de l'entreprise (COMP-...).";
      case 429:
        return "Trop d'essais. Patientez un moment avant de réessayer.";
      case 503:
        return 'Service momentanément indisponible. Réessayez dans quelques instants.';
    }
    if ((error.statusCode ?? 0) >= 500) {
      return 'Le serveur a rencontré un problème. Réessayez dans quelques instants.';
    }
  }
  return "L'action n'a pas abouti. Réessayez dans quelques instants.";
}

/// Message rédigé par le serveur dans un corps d'erreur, s'il y en a un.
String? _serverMessage(dynamic body) {
  if (body is! Map) return null;
  final message = body['message'];
  if (message is String && message.trim().isNotEmpty) {
    if (message == 'Validation failed') {
      final detail = body['error'];
      if (detail is String && detail.trim().isNotEmpty) return detail.trim();
      return null;
    }
    return message.trim();
  }
  if (message is List && message.isNotEmpty) {
    return message.map((e) => e.toString()).join(', ');
  }
  return null;
}
