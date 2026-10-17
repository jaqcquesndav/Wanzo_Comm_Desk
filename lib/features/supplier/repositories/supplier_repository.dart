import 'package:wanzo/core/exceptions/api_exceptions.dart' as api;
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';
import 'package:uuid/uuid.dart';
import '../models/supplier.dart';
import '../services/supplier_api_service.dart';
import '../utils/supplier_purchases.dart';
import '../../expenses/repositories/expense_repository.dart';

/// Refus définitif du serveur (4xx) sur une fiche fournisseur : rien n'est
/// gardé sur l'appareil. [toString] donne le motif lisible.
class SupplierRefusedException implements Exception {
  final String message;
  const SupplierRefusedException(this.message);

  @override
  String toString() => message;
}

/// Repository pour la gestion des fournisseurs (API-First + Offline Fallback)
class SupplierRepository {
  static const _suppliersBoxName =
      'suppliersBox'; // Correspond à hive_setup.dart et sync_service.dart
  late Box<Supplier> _suppliersBox;
  final _uuid = const Uuid();
  final SupplierApiService? _apiService;

  /// Dépenses : source des achats par fournisseur (classement).
  final ExpenseRepository? _expenseRepository;

  SupplierRepository({
    SupplierApiService? apiService,
    ExpenseRepository? expenseRepository,
  }) : _apiService = apiService,
       _expenseRepository = expenseRepository;

  /// Initialise le repository
  Future<void> init() async {
    _suppliersBox = await Hive.openBox<Supplier>(_suppliersBoxName);
    // Note: Plus de données mock - on utilise uniquement les vraies données API
  }

  /// Récupère tous les fournisseurs (API-First avec fallback local)
  Future<List<Supplier>> getSuppliers({bool forceLocal = false}) async {
    // Si forceLocal, retourner uniquement les données locales
    if (forceLocal) {
      return _suppliersBox.values.toList();
    }

    // Essayer d'abord l'API
    if (_apiService != null) {
      try {
        final apiResponse = await _apiService.getSuppliers().timeout(
          const Duration(seconds: 10),
        );

        if (apiResponse.success &&
            apiResponse.data != null &&
            apiResponse.data!.isNotEmpty) {
          debugPrint(
            '📦 [SupplierRepository] API: ${apiResponse.data!.length} fournisseurs récupérés',
          );
          // Fusionner avec le cache local, puis renvoyer TOUT le cache : la
          // réponse n'est qu'une page (10 par défaut) et ne contient pas les
          // fiches créées hors ligne (`pending`).
          await _mergeSuppliers(apiResponse.data!);
          return _suppliersBox.values.toList();
        }
      } catch (e) {
        debugPrint(
          '⚠️ [SupplierRepository] Erreur API, fallback sur cache local: $e',
        );
      }
    }

    // Fallback sur données locales
    final localSuppliers = _suppliersBox.values.toList();
    debugPrint(
      '📦 [SupplierRepository] Cache local: ${localSuppliers.length} fournisseurs',
    );
    return localSuppliers;
  }

  /// Récupère un fournisseur spécifique
  Future<Supplier?> getSupplier(String id) async {
    // D'abord vérifier le cache local
    final localSupplier = _suppliersBox.get(id);

    // Essayer l'API pour avoir les données les plus récentes
    if (_apiService != null) {
      try {
        final apiResponse = await _apiService
            .getSupplierById(id)
            .timeout(const Duration(seconds: 5));
        if (apiResponse.success && apiResponse.data != null) {
          // Mettre à jour le cache
          await _suppliersBox.put(id, apiResponse.data!);
          return apiResponse.data;
        }
      } catch (e) {
        debugPrint('⚠️ [SupplierRepository] Erreur API getSupplier: $e');
      }
    }

    return localSupplier;
  }

  /// Ajoute un nouveau fournisseur (API + Local)
  Future<Supplier> addSupplier(Supplier supplier) async {
    final newSupplier = supplier.copyWith(
      id: supplier.id.isEmpty ? _uuid.v4() : supplier.id,
      createdAt: DateTime.now(),
    );

    // Essayer d'abord l'API
    if (_apiService != null) {
      try {
        final apiResponse = await _apiService
            .createSupplier(newSupplier)
            .timeout(const Duration(seconds: 10));
        if (apiResponse.success && apiResponse.data != null) {
          // Sauvegarder la version serveur localement
          final cree = apiResponse.data!.copyWith(syncStatus: 'synced');
          await _suppliersBox.put(cree.id, cree);
          debugPrint(
            '✅ [SupplierRepository] Fournisseur créé via API: ${cree.id}',
          );
          return cree;
        }
        // Refus (4xx : téléphone invalide, doublon) : dit à l'utilisateur.
        // Avant, la fiche était gardée « synced » sur l'appareil et n'existait
        // jamais sur le serveur.
        _throwIfRefused(apiResponse.statusCode, apiResponse.message);
      } on SupplierRefusedException {
        rethrow;
      } catch (e) {
        debugPrint(
          '⚠️ [SupplierRepository] Erreur API create, sauvegarde locale: $e',
        );
      }
    }

    // Hors ligne ou serveur indisponible : gardée `pending`, la
    // synchronisation la crée au retour du réseau.
    final enAttente = newSupplier.copyWith(syncStatus: 'pending');
    await _suppliersBox.put(enAttente.id, enAttente);
    return enAttente;
  }

  /// Lève [SupplierRefusedException] pour un refus définitif du serveur.
  static void _throwIfRefused(int? statusCode, String? message) {
    final code = statusCode ?? 0;
    if (code >= 400 && code < 500 && code != 408 && code != 429) {
      final motif = (message ?? '').replaceFirst('Exception: ', '').trim();
      throw SupplierRefusedException(
        motif.isEmpty ? 'Le serveur a refusé la fiche fournisseur.' : motif,
      );
    }
  }

  /// Met à jour un fournisseur existant (API + Local)
  Future<Supplier> updateSupplier(Supplier supplier) async {
    // Essayer d'abord l'API
    if (_apiService != null) {
      try {
        final apiResponse = await _apiService
            .updateSupplier(supplier.id, supplier)
            .timeout(const Duration(seconds: 10));
        if (apiResponse.success && apiResponse.data != null) {
          final misAJour = apiResponse.data!.copyWith(syncStatus: 'synced');
          await _suppliersBox.put(misAJour.id, misAJour);
          debugPrint(
            '✅ [SupplierRepository] Fournisseur mis à jour via API: ${misAJour.id}',
          );
          return misAJour;
        }
        _throwIfRefused(apiResponse.statusCode, apiResponse.message);
      } on SupplierRefusedException {
        rethrow;
      } catch (e) {
        debugPrint(
          '⚠️ [SupplierRepository] Erreur API update, sauvegarde locale: $e',
        );
      }
    }

    // Hors ligne : gardée à renvoyer (`pending` si jamais envoyée, sinon
    // `pending_update`) ; la synchronisation l'envoie au retour du réseau.
    final existante = _suppliersBox.get(supplier.id);
    final dejaEnAttente =
        existante?.syncStatus == 'pending' || supplier.syncStatus == 'pending';
    final updatedSupplier = supplier.copyWith(
      syncStatus: dejaEnAttente ? 'pending' : 'pending_update',
    );
    await _suppliersBox.put(updatedSupplier.id, updatedSupplier);
    return updatedSupplier;
  }

  /// Supprime un fournisseur (API + Local)
  Future<void> deleteSupplier(String id) async {
    // Le serveur D'ABORD : un refus (historique de ventes ou de dépenses) ou
    // une coupure doit être dit à l'utilisateur. Avant, l'erreur était avalée
    // et la fiche supprimée localement réapparaissait au prochain sync.
    if (_apiService != null) {
      try {
        await _apiService.deleteSupplier(id).timeout(const Duration(seconds: 10));
      } on api.ApiException catch (e) {
        // 404 : fiche jamais envoyée au serveur (créée hors ligne).
        if (e.statusCode != 404) {
          if (e is api.NetworkException || e is api.TimeoutException || e.statusCode == null) {
            throw Exception('Connexion requise pour supprimer un fournisseur.');
          }
          throw Exception(e.message);
        }
      } on TimeoutException {
        throw Exception('Connexion requise pour supprimer un fournisseur.');
      }
    }
    await _suppliersBox.delete(id);
  }

  /// Met à jour le total des achats auprès d'un fournisseur
  Future<Supplier> updateSupplierPurchaseTotal(
    String supplierId,
    double amount,
  ) async {
    final supplier = await getSupplier(supplierId);
    if (supplier == null) {
      throw Exception('Fournisseur non trouvé');
    }

    final updatedSupplier = supplier.copyWith(
      totalPurchases: supplier.totalPurchases + amount,
      lastPurchaseDate: DateTime.now(),
    );

    await _suppliersBox.put(supplierId, updatedSupplier);
    return updatedSupplier;
  }

  /// Recherche des fournisseurs par nom ou numéro de téléphone (API + Local)
  Future<List<Supplier>> searchSuppliers(String query) async {
    // Essayer d'abord l'API
    if (_apiService != null && query.length >= 2) {
      try {
        final apiResponse = await _apiService
            .getSuppliers(searchQuery: query)
            .timeout(const Duration(seconds: 5));

        if (apiResponse.success && apiResponse.data != null) {
          debugPrint(
            '🔍 [SupplierRepository] Recherche API: ${apiResponse.data!.length} résultats',
          );
          return apiResponse.data!;
        }
      } catch (e) {
        debugPrint(
          '⚠️ [SupplierRepository] Erreur recherche API, fallback local: $e',
        );
      }
    }

    // Fallback sur recherche locale
    final lowercaseQuery = query.toLowerCase();
    return _suppliersBox.values.where((supplier) {
      return supplier.name.toLowerCase().contains(lowercaseQuery) ||
          supplier.phoneNumber.contains(query) ||
          supplier.contactPerson.toLowerCase().contains(lowercaseQuery);
    }).toList();
  }

  /// Principaux fournisseurs : classés par achats (leurs dépenses) ramenés
  /// en CDF au taux figé de chaque dépense. Le champ `totalPurchases` n'est
  /// tenu à jour nulle part : il ne sert pas.
  Future<List<Supplier>> getTopSuppliers({int limit = 5}) async {
    final suppliers = _suppliersBox.values.toList();
    final depenses = _expenseRepository;
    if (depenses == null) return suppliers.take(limit).toList();
    final totaux = <String, double>{
      for (final s in suppliers)
        s.id: (await SupplierPurchases.load(depenses, s.id)).totalCdf,
    };
    suppliers.sort((a, b) => totaux[b.id]!.compareTo(totaux[a.id]!));
    return suppliers.take(limit).toList();
  }

  /// Récupère les fournisseurs récemment ajoutés
  Future<List<Supplier>> getRecentSuppliers({int limit = 5}) async {
    final suppliers =
        _suppliersBox.values.toList()
          ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

    return suppliers.take(limit).toList();
  }

  /// Récupère l'historique des achats d'un fournisseur
  Future<List<Map<String, dynamic>>> getSupplierPurchases(
    String supplierId,
  ) async {
    if (_apiService == null) {
      debugPrint("API Service not available for supplier purchases");
      return [];
    }

    try {
      final response = await _apiService.getSupplierPurchases(supplierId);
      if (response.success && response.data != null) {
        debugPrint(
          "Fetched ${response.data!.length} purchases for supplier $supplierId",
        );
        return response.data!;
      }
      debugPrint("Failed to fetch supplier purchases: ${response.message}");
      return [];
    } catch (e) {
      debugPrint("Error fetching supplier purchases: $e");
      return [];
    }
  }

  /// Fusionne les fournisseurs API avec le cache local
  Future<void> _mergeSuppliers(List<Supplier> apiSuppliers) async {
    for (final apiSupplier in apiSuppliers) {
      // Une modification locale pas encore envoyée n'est pas écrasée.
      final local = _suppliersBox.get(apiSupplier.id);
      if (local != null &&
          (local.syncStatus == 'pending' ||
              local.syncStatus == 'pending_update')) {
        continue;
      }
      await _suppliersBox.put(apiSupplier.id, apiSupplier);
    }
    await _suppliersBox.flush();
    debugPrint(
      '💾 [SupplierRepository] Cache mis à jour avec ${apiSuppliers.length} fournisseurs',
    );
  }

  /// Vide le cache local des fournisseurs
  Future<void> clearLocalCache() async {
    await _suppliersBox.clear();
    debugPrint('🗑️ [SupplierRepository] Cache local vidé');
  }
}
