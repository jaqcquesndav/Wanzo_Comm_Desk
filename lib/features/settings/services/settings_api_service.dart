// filepath: lib/features/settings/services/settings_api_service.dart
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:wanzo/config/environment.dart';
import 'package:wanzo/features/auth/services/auth0_service.dart';

/// Service API pour la gestion des paramètres
/// Conformité: Aligné avec Settings API documentation
class SettingsApiService {
  final String _baseUrl = Environment.commerceApiBaseUrl;
  final Auth0Service _auth0Service;

  SettingsApiService({required Auth0Service auth0Service})
    : _auth0Service = auth0Service;

  /// Headers avec authentification
  Future<Map<String, String>> get _authHeaders async {
    final token = await _auth0Service.getAccessToken();
    return {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  /// Utilitaire pour extraire les données de la réponse API (gère les structures imbriquées)
  dynamic _extractData(Map<String, dynamic> responseBody) {
    debugPrint('🔧 [SettingsApiService] Extracting data from response...');
    debugPrint(
      '🔧 [SettingsApiService] Response keys: ${responseBody.keys.toList()}',
    );

    // Cas 1: {data: {...}} ou {data: [...]}
    if (responseBody.containsKey('data')) {
      final data = responseBody['data'];
      debugPrint(
        '🔧 [SettingsApiService] Found "data" key, type: ${data.runtimeType}',
      );

      // Cas 1.1: {data: {data: {...}}} - double imbrication
      if (data is Map<String, dynamic> && data.containsKey('data')) {
        debugPrint(
          '🔧 [SettingsApiService] Found nested "data.data", extracting...',
        );
        return data['data'];
      }
      return data;
    }

    // Cas 2: Réponse directe sans wrapper
    debugPrint(
      '🔧 [SettingsApiService] No "data" wrapper, returning raw response',
    );
    return responseBody;
  }

  // ============= SETTINGS GENERAUX =============

  /// Récupère les paramètres actuels
  /// GET /settings-user-profile/application-settings
  Future<Map<String, dynamic>> getSettings() async {
    final uri = Uri.parse(
      '$_baseUrl/settings-user-profile/application-settings',
    );

    debugPrint('📋 [SettingsApiService] GET $uri');
    final response = await http.get(uri, headers: await _authHeaders);

    debugPrint(
      '📋 [SettingsApiService] Response status: ${response.statusCode}',
    );
    debugPrint('📋 [SettingsApiService] Response body: ${response.body}');

    if (response.statusCode == 200) {
      final decodedBody = json.decode(response.body);
      debugPrint(
        '📋 [SettingsApiService] Decoded body type: ${decodedBody.runtimeType}',
      );

      final data = _extractData(decodedBody as Map<String, dynamic>);
      debugPrint(
        '📋 [SettingsApiService] Extracted data type: ${data.runtimeType}',
      );
      debugPrint('📋 [SettingsApiService] Extracted data: $data');

      if (data is Map<String, dynamic>) {
        return data;
      } else {
        debugPrint(
          '📋 [SettingsApiService] WARNING: Expected Map but got ${data.runtimeType}',
        );
        return <String, dynamic>{};
      }
    } else {
      debugPrint(
        '📋 [SettingsApiService] ERROR: ${response.statusCode} - ${response.body}',
      );
      throw Exception(
        'Erreur lors de la récupération des paramètres: ${response.statusCode}',
      );
    }
  }

  /// Met à jour les paramètres
  /// PATCH /settings-user-profile/application-settings
  Future<Map<String, dynamic>> updateSettings(
    Map<String, dynamic> settings,
  ) async {
    final uri = Uri.parse(
      '$_baseUrl/settings-user-profile/application-settings',
    );

    debugPrint('📋 [SettingsApiService] PATCH $uri');
    debugPrint(
      '📋 [SettingsApiService] Request body: ${json.encode(settings)}',
    );

    final response = await http.patch(
      uri,
      headers: await _authHeaders,
      body: json.encode(settings),
    );

    debugPrint(
      '📋 [SettingsApiService] Response status: ${response.statusCode}',
    );
    debugPrint('📋 [SettingsApiService] Response body: ${response.body}');

    if (response.statusCode == 200) {
      final decodedBody = json.decode(response.body);
      final data = _extractData(decodedBody as Map<String, dynamic>);

      if (data is Map<String, dynamic>) {
        return data;
      } else {
        return <String, dynamic>{};
      }
    } else {
      debugPrint(
        '📋 [SettingsApiService] ERROR: ${response.statusCode} - ${response.body}',
      );
      throw Exception(
        'Erreur lors de la mise à jour des paramètres: ${response.statusCode}',
      );
    }
  }

  // ============= INSTITUTIONS BANCAIRES =============

  /// Récupère la liste des institutions bancaires disponibles
  /// GET /api/v1/settings/bank-institutions
  Future<List<Map<String, dynamic>>> getBankInstitutions() async {
    final uri = Uri.parse('$_baseUrl/settings/bank-institutions');

    debugPrint('🏦 [SettingsApiService] GET $uri');
    final response = await http.get(uri, headers: await _authHeaders);

    debugPrint(
      '🏦 [SettingsApiService] Response status: ${response.statusCode}',
    );
    debugPrint('🏦 [SettingsApiService] Response body: ${response.body}');

    if (response.statusCode == 200) {
      final decodedBody = json.decode(response.body);
      final data = _extractData(decodedBody as Map<String, dynamic>);

      if (data is List) {
        debugPrint(
          '🏦 [SettingsApiService] Found ${data.length} bank institutions',
        );
        return data.cast<Map<String, dynamic>>();
      } else {
        debugPrint(
          '🏦 [SettingsApiService] WARNING: Expected List but got ${data.runtimeType}',
        );
        return [];
      }
    } else {
      debugPrint(
        '🏦 [SettingsApiService] ERROR: ${response.statusCode} - ${response.body}',
      );
      throw Exception(
        'Erreur lors de la récupération des institutions: ${response.statusCode}',
      );
    }
  }

  // ============= COMPTES FINANCIERS =============

  /// Récupère la liste des comptes financiers
  /// GET /api/v1/settings/financial-accounts
  Future<List<Map<String, dynamic>>> getFinancialAccounts({
    String? type, // bankAccount, mobileMoney
    bool? isDefault,
    bool? isActive,
  }) async {
    final queryParams = <String, String>{};
    if (type != null) queryParams['type'] = type;
    if (isDefault != null) queryParams['isDefault'] = isDefault.toString();
    if (isActive != null) queryParams['isActive'] = isActive.toString();

    final uri = Uri.parse(
      '$_baseUrl/settings/financial-accounts',
    ).replace(queryParameters: queryParams.isNotEmpty ? queryParams : null);

    debugPrint('💳 [SettingsApiService] GET $uri');
    final response = await http.get(uri, headers: await _authHeaders);

    debugPrint(
      '💳 [SettingsApiService] Response status: ${response.statusCode}',
    );
    debugPrint('💳 [SettingsApiService] Response body: ${response.body}');

    if (response.statusCode == 200) {
      final decodedBody = json.decode(response.body);
      final data = _extractData(decodedBody as Map<String, dynamic>);

      if (data is List) {
        debugPrint(
          '💳 [SettingsApiService] Found ${data.length} financial accounts',
        );
        return data.cast<Map<String, dynamic>>();
      } else if (data is Map<String, dynamic>) {
        // Peut-être que les comptes sont dans une sous-clé
        final accounts = data['accounts'] ?? data['items'] ?? data['data'];
        if (accounts is List) {
          debugPrint(
            '💳 [SettingsApiService] Found ${accounts.length} accounts in nested structure',
          );
          return accounts.cast<Map<String, dynamic>>();
        }
      }

      debugPrint(
        '💳 [SettingsApiService] WARNING: Unexpected data format: ${data.runtimeType}',
      );
      return [];
    } else {
      debugPrint(
        '💳 [SettingsApiService] ERROR: ${response.statusCode} - ${response.body}',
      );
      throw Exception(
        'Erreur lors de la récupération des comptes: ${response.statusCode}',
      );
    }
  }

  /// Récupère un compte financier par ID
  /// GET /api/v1/settings/financial-accounts/:id
  Future<Map<String, dynamic>> getFinancialAccountById(String id) async {
    final uri = Uri.parse('$_baseUrl/settings/financial-accounts/$id');

    debugPrint('💳 [SettingsApiService] GET $uri');
    final response = await http.get(uri, headers: await _authHeaders);

    debugPrint(
      '💳 [SettingsApiService] Response status: ${response.statusCode}',
    );
    debugPrint('💳 [SettingsApiService] Response body: ${response.body}');

    if (response.statusCode == 200) {
      final decodedBody = json.decode(response.body);
      final data = _extractData(decodedBody as Map<String, dynamic>);

      if (data is Map<String, dynamic>) {
        return data;
      } else {
        return <String, dynamic>{};
      }
    } else if (response.statusCode == 404) {
      throw Exception('Compte financier non trouvé');
    } else {
      throw Exception(
        'Erreur lors de la récupération du compte: ${response.statusCode}',
      );
    }
  }

  /// Crée un nouveau compte financier
  /// POST /api/v1/settings/financial-accounts
  Future<Map<String, dynamic>> createFinancialAccount({
    required String type, // bankAccount, mobileMoney
    required String name,
    String? accountNumber,
    String? bankName,
    String? bankCode,
    String? branchName,
    String? branchCode,
    String? swiftCode,
    String? iban,
    String? currency,
    String? mobileMoneyProvider,
    String? phoneNumber,
    bool isDefault = false,
    bool isActive = true,
  }) async {
    final uri = Uri.parse('$_baseUrl/settings/financial-accounts');
    final body = {
      'type': type,
      'name': name,
      'isDefault': isDefault,
      'isActive': isActive,
      if (accountNumber != null) 'accountNumber': accountNumber,
      if (bankName != null) 'bankName': bankName,
      if (bankCode != null) 'bankCode': bankCode,
      if (branchName != null) 'branchName': branchName,
      if (branchCode != null) 'branchCode': branchCode,
      if (swiftCode != null) 'swiftCode': swiftCode,
      if (iban != null) 'iban': iban,
      if (currency != null) 'currency': currency,
      if (mobileMoneyProvider != null)
        'mobileMoneyProvider': mobileMoneyProvider,
      if (phoneNumber != null) 'phoneNumber': phoneNumber,
    };

    debugPrint('💳 [SettingsApiService] POST $uri');
    debugPrint('💳 [SettingsApiService] Request body: ${json.encode(body)}');

    final response = await http.post(
      uri,
      headers: await _authHeaders,
      body: json.encode(body),
    );

    debugPrint(
      '💳 [SettingsApiService] Response status: ${response.statusCode}',
    );
    debugPrint('💳 [SettingsApiService] Response body: ${response.body}');

    if (response.statusCode == 201) {
      final decodedBody = json.decode(response.body);
      final data = _extractData(decodedBody as Map<String, dynamic>);

      if (data is Map<String, dynamic>) {
        return data;
      } else {
        return <String, dynamic>{};
      }
    } else {
      debugPrint(
        '💳 [SettingsApiService] ERROR: ${response.statusCode} - ${response.body}',
      );
      throw Exception(
        'Erreur lors de la création du compte: ${response.statusCode}',
      );
    }
  }

  /// Met à jour un compte financier
  /// PUT /api/v1/settings/financial-accounts/:id
  Future<Map<String, dynamic>> updateFinancialAccount(
    String id, {
    String? name,
    String? accountNumber,
    String? bankName,
    String? bankCode,
    String? branchName,
    String? branchCode,
    String? swiftCode,
    String? iban,
    String? currency,
    String? mobileMoneyProvider,
    String? phoneNumber,
    bool? isActive,
  }) async {
    final uri = Uri.parse('$_baseUrl/settings/financial-accounts/$id');
    final body = <String, dynamic>{};

    if (name != null) body['name'] = name;
    if (accountNumber != null) body['accountNumber'] = accountNumber;
    if (bankName != null) body['bankName'] = bankName;
    if (bankCode != null) body['bankCode'] = bankCode;
    if (branchName != null) body['branchName'] = branchName;
    if (branchCode != null) body['branchCode'] = branchCode;
    if (swiftCode != null) body['swiftCode'] = swiftCode;
    if (iban != null) body['iban'] = iban;
    if (currency != null) body['currency'] = currency;
    if (mobileMoneyProvider != null) {
      body['mobileMoneyProvider'] = mobileMoneyProvider;
    }
    if (phoneNumber != null) body['phoneNumber'] = phoneNumber;
    if (isActive != null) body['isActive'] = isActive;

    debugPrint('💳 [SettingsApiService] PUT $uri');
    debugPrint('💳 [SettingsApiService] Request body: ${json.encode(body)}');

    final response = await http.put(
      uri,
      headers: await _authHeaders,
      body: json.encode(body),
    );

    debugPrint(
      '💳 [SettingsApiService] Response status: ${response.statusCode}',
    );
    debugPrint('💳 [SettingsApiService] Response body: ${response.body}');

    if (response.statusCode == 200) {
      final decodedBody = json.decode(response.body);
      final data = _extractData(decodedBody as Map<String, dynamic>);

      if (data is Map<String, dynamic>) {
        return data;
      } else {
        return <String, dynamic>{};
      }
    } else if (response.statusCode == 404) {
      throw Exception('Compte financier non trouvé');
    } else {
      throw Exception(
        'Erreur lors de la mise à jour du compte: ${response.statusCode}',
      );
    }
  }

  /// Supprime un compte financier
  /// DELETE /api/v1/settings/financial-accounts/:id
  Future<void> deleteFinancialAccount(String id) async {
    final uri = Uri.parse('$_baseUrl/settings/financial-accounts/$id');

    debugPrint('💳 [SettingsApiService] DELETE $uri');
    final response = await http.delete(uri, headers: await _authHeaders);

    debugPrint(
      '💳 [SettingsApiService] Response status: ${response.statusCode}',
    );
    debugPrint('💳 [SettingsApiService] Response body: ${response.body}');

    if (response.statusCode == 200 || response.statusCode == 204) {
      debugPrint('💳 [SettingsApiService] Account deleted successfully');
      return;
    } else if (response.statusCode == 404) {
      throw Exception('Compte financier non trouvé');
    } else {
      throw Exception(
        'Erreur lors de la suppression du compte: ${response.statusCode}',
      );
    }
  }

  /// Définit un compte comme compte par défaut
  /// PUT /api/v1/settings/financial-accounts/:id/set-default
  Future<Map<String, dynamic>> setDefaultFinancialAccount(String id) async {
    final uri = Uri.parse(
      '$_baseUrl/settings/financial-accounts/$id/set-default',
    );

    debugPrint('💳 [SettingsApiService] PUT $uri');
    final response = await http.put(uri, headers: await _authHeaders);

    debugPrint(
      '💳 [SettingsApiService] Response status: ${response.statusCode}',
    );
    debugPrint('💳 [SettingsApiService] Response body: ${response.body}');

    if (response.statusCode == 200) {
      final decodedBody = json.decode(response.body);
      final data = _extractData(decodedBody as Map<String, dynamic>);

      if (data is Map<String, dynamic>) {
        return data;
      } else {
        return <String, dynamic>{};
      }
    } else if (response.statusCode == 404) {
      throw Exception('Compte financier non trouvé');
    } else {
      throw Exception(
        'Erreur lors de la définition du compte par défaut: ${response.statusCode}',
      );
    }
  }
}
