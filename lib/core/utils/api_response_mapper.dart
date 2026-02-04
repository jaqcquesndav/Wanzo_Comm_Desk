import 'package:flutter/foundation.dart';

/// Classe utilitaire pour mapper correctement les réponses API
/// Gère les différentes structures de réponse du backend
class ApiResponseMapper {
  /// Extrait une liste d'éléments d'une réponse API imbriquée
  ///
  /// Gère les formats courants:
  /// - Liste directe: [...]
  /// - Réponse paginée: {data: [...], total: X, ...}
  /// - Réponse avec clé spécifique: {customers: [...], ...}, {products: [...], ...}
  /// - Double enveloppe: {success: true, data: {data: [...], ...}}
  ///
  /// [data] - Les données de la réponse (response['data'])
  /// [possibleKeys] - Liste des clés possibles contenant la liste (par défaut: data, items, etc.)
  /// [logPrefix] - Préfixe pour les logs de debug
  static List<dynamic>? extractList(
    dynamic data, {
    List<String>? possibleKeys,
    String? logPrefix,
  }) {
    possibleKeys ??= [
      'data',
      'items',
      'customers',
      'products',
      'sales',
      'operations',
      'expenses',
      'suppliers',
      'transactions',
      'accounts',
      'notifications',
      'documents',
      'entries',
    ];

    if (data == null) {
      return null;
    }

    // Cas 1: C'est déjà une liste
    if (data is List) {
      if (logPrefix != null) {
        debugPrint('$logPrefix Direct list with ${data.length} items');
      }
      return data;
    }

    // Cas 2: C'est un Map
    if (data is Map<String, dynamic>) {
      // Vérifier si c'est une double enveloppe {success, data: {...}}
      if (data.containsKey('success') && data.containsKey('data')) {
        final innerData = data['data'];
        if (innerData is List) {
          if (logPrefix != null) {
            debugPrint(
              '$logPrefix Double envelope - inner list with ${innerData.length} items',
            );
          }
          return innerData;
        } else if (innerData is Map<String, dynamic>) {
          // Chercher dans l'enveloppe intérieure
          for (final key in possibleKeys) {
            if (innerData[key] is List) {
              final list = innerData[key] as List;
              if (logPrefix != null) {
                debugPrint(
                  '$logPrefix Double envelope - found key "$key" with ${list.length} items',
                );
              }
              return list;
            }
          }
        }
      }

      // Chercher directement dans le Map
      for (final key in possibleKeys) {
        if (data[key] is List) {
          final list = data[key] as List;
          if (logPrefix != null) {
            debugPrint('$logPrefix Found key "$key" with ${list.length} items');
          }
          return list;
        }
      }
    }

    if (logPrefix != null) {
      debugPrint('$logPrefix Could not extract list from response');
    }
    return null;
  }

  /// Extrait un objet unique d'une réponse API
  /// Utile pour les réponses de type getById, create, update
  static Map<String, dynamic>? extractObject(
    dynamic data, {
    String? logPrefix,
  }) {
    if (data == null) {
      return null;
    }

    // Cas 1: C'est déjà un Map
    if (data is Map<String, dynamic>) {
      // Vérifier si c'est une double enveloppe
      if (data.containsKey('success') && data.containsKey('data')) {
        final innerData = data['data'];
        if (innerData is Map<String, dynamic> &&
            !innerData.containsKey('success')) {
          if (logPrefix != null) {
            debugPrint('$logPrefix Double envelope - extracted inner object');
          }
          return innerData;
        }
      }
      if (logPrefix != null) {
        debugPrint('$logPrefix Direct object');
      }
      return data;
    }

    if (logPrefix != null) {
      debugPrint('$logPrefix Could not extract object from response');
    }
    return null;
  }
}
