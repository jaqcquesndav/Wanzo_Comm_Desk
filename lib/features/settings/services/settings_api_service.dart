import 'package:flutter/foundation.dart';
import 'package:wanzo/core/services/api_client.dart';
import 'package:wanzo/features/auth/services/auth0_service.dart';

/// Paramètres de l'application (`settings-user-profile/application-settings`).
///
/// Passe par [ApiClient] : jeton, disjoncteur et surtout FILE HORS LIGNE.
/// L'ancien service appelait `http` directement, sans file : un réglage
/// modifié hors ligne n'atteignait jamais le serveur. Les méthodes de comptes
/// financiers de ce service (route `settings/financial-accounts`, inexistante)
/// n'étaient appelées par personne et ont été retirées :
/// `FinancialAccountApiService` porte ce domaine.
class SettingsApiService {
  final ApiClient _apiClient;

  SettingsApiService({Auth0Service? auth0Service, ApiClient? apiClient})
    : _apiClient = apiClient ?? ApiClient();

  static const String _endpoint = 'settings-user-profile/application-settings';

  /// Données utiles d'une réponse enveloppée (une ou deux fois).
  @visibleForTesting
  static Map<String, dynamic> extractData(dynamic body) {
    dynamic data = body;
    if (data is Map && data.containsKey('data')) data = data['data'];
    if (data is Map && data.containsKey('data') && data['data'] is Map) {
      data = data['data'];
    }
    return data is Map ? Map<String, dynamic>.from(data) : <String, dynamic>{};
  }

  /// Récupère les paramètres actuels.
  Future<Map<String, dynamic>> getSettings() async {
    final response = await _apiClient.get(_endpoint, requiresAuth: true);
    return extractData(response);
  }

  /// Met à jour les paramètres. Hors ligne : la modification est mise en file
  /// et [OfflineQueuedException] est levée (jamais un faux succès).
  Future<Map<String, dynamic>> updateSettings(
    Map<String, dynamic> settings,
  ) async {
    final response = await _apiClient.patch(
      _endpoint,
      body: settings,
      requiresAuth: true,
    );
    return extractData(response);
  }
}
