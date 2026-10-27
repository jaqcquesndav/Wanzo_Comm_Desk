// Required for jsonDecode if API returns string
import 'dart:async';
import 'package:uuid/uuid.dart';
import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';

import '../models/operation_journal_entry.dart';
import '../models/journal_filter.dart';
import '../utils/journal_reversal.dart';
import '../../../core/services/api_service.dart'; // Import ApiService
import '../../../core/utils/connectivity_service.dart'; // Import ConnectivityService

/// Fonction utilitaire pour extraire une liste d'éléments d'une réponse API imbriquée
/// Gère les formats: {data: [...]}, {data: {items: [...]}}, {data: {operations: [...]}}, etc.
/// Gère aussi la double imbrication: {data: {data: {items: [...]}}}
List<dynamic>? _extractListFromResponse(dynamic data, [List<String>? keys]) {
  keys ??= ['operations', 'data', 'items', 'entries'];

  if (data == null) {
    return null;
  }

  // Cas 1: C'est déjà une liste
  if (data is List) {
    debugPrint('📊 API Response - Direct list (${data.length} items)');
    return data;
  }

  // Cas 2: C'est un Map - chercher récursivement
  if (data is Map<String, dynamic>) {
    // D'abord, chercher une liste directe dans les clés connues
    for (final key in keys) {
      final value = data[key];
      if (value is List) {
        debugPrint(
          '📊 API Response - Extracted list from key: $key (${value.length} items)',
        );
        return value;
      }
    }

    // Ensuite, chercher dans les valeurs Map (imbrication)
    for (final key in keys) {
      final value = data[key];
      if (value is Map<String, dynamic>) {
        // Appel récursif pour gérer la double imbrication
        final nestedList = _extractListFromResponse(value, keys);
        if (nestedList != null) {
          debugPrint('📊 API Response - Found nested list via key: $key');
          return nestedList;
        }
      }
    }
  }

  debugPrint('⚠️ API Response - Could not extract list from response');
  return null;
}

/// Taille de page demandée au backend pour le journal (le DTO
/// ListBusinessOperationsDto vaut 10 par défaut et n'a pas de maximum).
const int kJournalPageSize = 200;

/// Garde-fou contre une boucle sans fin si le backend renvoyait toujours
/// une page pleine.
const int kJournalMaxPages = 100;

/// Nombre total de pages annoncé par la réponse (`totalPages`), cherché à
/// tous les niveaux d'enveloppe ({success, data: {status, data: {...}}}).
int? _totalPagesOf(dynamic data) {
  if (data is! Map) return null;
  final value = data['totalPages'];
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value);
  for (final nested in data.values) {
    final found = _totalPagesOf(nested);
    if (found != null) return found;
  }
  return null;
}

/// Récupère TOUTES les pages d'une liste paginée du journal
/// (`journal/operations` ou `operations`) : `page`, `limit` ajoutés à
/// [baseQuery], arrêt sur une page incomplète ou à `totalPages`.
///
/// Renvoie null si la première page ne contient aucune liste exploitable
/// (l'appelant se rabat alors sur le cache local). Une erreur sur une page
/// suivante remonte à l'appelant : rien n'est écrit en local à partir d'une
/// pagination partielle.
@visibleForTesting
Future<List<dynamic>?> fetchAllJournalPages(
  Future<Map<String, dynamic>> Function(Map<String, dynamic> query) fetchPage,
  Map<String, dynamic> baseQuery, {
  int pageSize = kJournalPageSize,
}) async {
  List<dynamic>? all;
  for (var page = 1; page <= kJournalMaxPages; page++) {
    final response = await fetchPage({
      ...baseQuery,
      'page': page,
      'limit': pageSize,
    });
    final items = _extractListFromResponse(response['data']);
    if (items == null) return all;
    (all ??= <dynamic>[]).addAll(items);
    if (items.length < pageSize) break;
    final totalPages = _totalPagesOf(response['data']);
    if (totalPages != null && page >= totalPages) break;
  }
  return all;
}

class OperationJournalRepository {
  // Cache en mémoire supprimé pour éviter les problèmes de synchronisation
  // final List<OperationJournalEntry> _entries = [];

  Box<OperationJournalEntry>?
  _entriesBox; // Boîte Hive pour la persistance (nullable pour sécurité)
  final ApiService _apiService;
  final ConnectivityService _connectivityService;
  final _uuid = const Uuid();
  bool _isOfflineMode = true; // Par défaut, utiliser le mode hors ligne

  // Constructor with ApiService injection
  OperationJournalRepository({
    ApiService? apiService,
    ConnectivityService? connectivityService,
  }) : _apiService = apiService ?? ApiService(),
       _connectivityService = connectivityService ?? ConnectivityService();

  Future<void> init() async {
    try {
      // Initialiser la boîte Hive
      if (Hive.isBoxOpen('operation_journal_entries')) {
        _entriesBox = Hive.box<OperationJournalEntry>(
          'operation_journal_entries',
        );
      } else {
        _entriesBox = await Hive.openBox<OperationJournalEntry>(
          'operation_journal_entries',
        );
      }

      // Plus besoin de charger dans le cache mémoire
      // _entries.clear();
      // _entries.addAll(_entriesBox.values);

      // Détecter si on est en mode en ligne ou hors ligne en utilisant la connectivité réelle
      // CORRECTION: On utilise maintenant le service de connectivité au lieu de !kIsWeb
      _isOfflineMode = !_connectivityService.isConnected;

      // Écouter les changements de connectivité
      _connectivityService.connectionStatus.addListener(_onConnectivityChanged);

      debugPrint(
        "✅ OperationJournalRepository initialized with ${_entriesBox?.length ?? 0} local entries.",
      );

      if (_entriesBox != null) {
        debugPrint(
          "🔑 Hive Box 'operation_journal_entries' has ${_entriesBox!.keys.length} keys",
        );
        debugPrint(
          "📦 Adapter 201 registered: ${Hive.isAdapterRegistered(201)}",
        );
        debugPrint(
          "📦 Adapter 200 (OperationType) registered: ${Hive.isAdapterRegistered(200)}",
        );

        if (_entriesBox!.isNotEmpty) {
          // Afficher des statistiques sur les données présentes
          final entries = _entriesBox!.values.toList();
          final dates = entries.map((e) => e.date).toList()..sort();
          final types = entries.map((e) => e.type.displayName).toSet();

          debugPrint("📊 Box contains ${_entriesBox!.length} operations");
          debugPrint("📅 Date range: ${dates.first} to ${dates.last}");
          debugPrint("🏷️ Operation types: ${types.join(', ')}");

          // Vérifier que les données sont bien persistées
          final compact = _entriesBox!.toMap();
          debugPrint(
            "💾 Compact status: ${compact.length} entries can be read",
          );
        } else {
          debugPrint(
            "⚠️ WARNING: No entries found in Hive box 'operation_journal_entries'",
          );
          debugPrint(
            "💡 This is normal for a fresh installation or after data reset",
          );
        }
      }
    } catch (e) {
      debugPrint("ERROR initializing OperationJournalRepository: $e");
    }
  }

  // Helper to ensure box is open
  Future<Box<OperationJournalEntry>> _getBox() async {
    if (_entriesBox != null && _entriesBox!.isOpen) {
      return _entriesBox!;
    }

    if (Hive.isBoxOpen('operation_journal_entries')) {
      _entriesBox = Hive.box<OperationJournalEntry>(
        'operation_journal_entries',
      );
    } else {
      _entriesBox = await Hive.openBox<OperationJournalEntry>(
        'operation_journal_entries',
      );
    }
    return _entriesBox!;
  }

  /// Lignes du journal de la période [startDate]..[endDate] (bornes
  /// comprises), rapprochées : une pièce déjà publiée par le serveur ne garde
  /// pas sa ligne locale. En ligne, la période est relue sur le serveur (bornes
  /// envoyées en UTC : une vente à 23:30 à Goma reste dans son jour) ; hors
  /// ligne, le cache local fait foi.
  Future<List<OperationJournalEntry>> getOperations(
    DateTime startDate,
    DateTime endDate,
  ) async {
    bool inRange(OperationJournalEntry e) =>
        !e.date.isBefore(startDate) && !e.date.isAfter(endDate);

    Box<OperationJournalEntry> box;
    try {
      box = await _getBox();
    } catch (e) {
      debugPrint("❌ Journal : cache local illisible ($e)");
      return [];
    }

    try {
      // Toutes les pages de la période : le backend pagine à 10 éléments
      // par défaut. Rien n'est écrit en local avant la fin de la pagination.
      final operationsList = await fetchAllJournalPages(
        (query) => _apiService
            .get('journal/operations', queryParams: query)
            .timeout(
              // Le journal est RECONSTRUIT côté backend : un délai trop court
              // faisait retomber sur le cache local, vide sur un nouvel appareil.
              const Duration(seconds: 15),
              onTimeout: () => <String, dynamic>{},
            ),
        {
          'dateFrom': startDate.toUtc().toIso8601String(),
          'dateTo': endDate.toUtc().toIso8601String(),
        },
      );

      if (operationsList != null && operationsList.isNotEmpty) {
        for (final item in operationsList) {
          try {
            final entry = OperationJournalEntry.fromJson(
              Map<String, dynamic>.from(item as Map),
            );
            await box.put(entry.id, entry);
          } catch (e) {
            debugPrint('⚠️ Ligne de journal illisible : $e');
          }
        }
        try {
          await box.flush();
        } catch (_) {}
      }
    } catch (e) {
      debugPrint('📱 Journal hors ligne, cache local utilisé ($e)');
    }

    final entries = reconcileJournalEntries(box.values.where(inRange))
      ..sort((a, b) => b.date.compareTo(a.date));
    return entries;
  }

  Future<Map<String, double>> getOpeningBalances(DateTime forDate) async {
    // Cette méthode permet de récupérer les soldes d'ouverture pour toutes les devises
    try {
      if (!_isOfflineMode) {
        // Note: Pas d'endpoint spécifique pour opening-balances dans la doc API
        // Utiliser les données locales ou dashboard/data pour les KPIs
        final response = await _apiService.get(
          'dashboard/data',
          queryParams: {
            'period': 'day',
            'startDate': forDate.toIso8601String(),
          },
        );

        if (response['balances'] != null && response['balances'] is Map) {
          return Map<String, double>.from(
            (response['balances'] as Map).map(
              (key, value) =>
                  MapEntry(key as String, (value as num).toDouble()),
            ),
          );
        }
      }

      // Si hors ligne ou échec API, calculer depuis les données locales
      return _calculateLocalOpeningBalances(forDate);
    } catch (e) {
      debugPrint("Error fetching opening balances: $e");
      // En cas d'erreur, utiliser les données locales
      return _calculateLocalOpeningBalances(forDate);
    }
  }

  /// Calcule les soldes d'ouverture basés sur la dernière entrée avant la date donnée
  /// DEPRECATED: Utiliser getOpeningBalancesByType pour les soldes séparés
  Future<Map<String, double>> _calculateLocalOpeningBalances(
    DateTime date,
  ) async {
    try {
      final box = await _getBox();
      // Filtrer les entrées avant la date donnée
      final previousEntries =
          box.values.where((e) => e.date.isBefore(date)).toList()
            ..sort((a, b) => b.date.compareTo(a.date)); // Plus récent d'abord

      if (previousEntries.isEmpty) {
        return {'CDF': 0.0, 'USD': 0.0};
      }

      final lastEntry = previousEntries.first;

      // Si l'entrée a déjà les soldes par devise, les utiliser
      if (lastEntry.balancesByCurrency != null &&
          lastEntry.balancesByCurrency!.isNotEmpty) {
        return Map<String, double>.from(lastEntry.balancesByCurrency!);
      }

      // Sinon, essayer d'estimer (fallback basique)
      return {
        lastEntry.currencyCode ?? 'CDF': lastEntry.balanceAfter,
        (lastEntry.currencyCode == 'USD' ? 'CDF' : 'USD'): 0.0,
      };
    } catch (e) {
      debugPrint("Error calculating opening balances: $e");
      return {'CDF': 0.0, 'USD': 0.0};
    }
  }

  /// Soldes d'ouverture par TYPE (caisse, ventes, stock) et par devise au
  /// début de [forDate] : cumul des lignes CONNUES antérieures (rapprochées,
  /// sans double compte) qui satisfont [where] (la vue et les critères du
  /// journal : le solde d'ouverture de la vue Caisse ne compte que les
  /// espèces).
  Future<Map<String, Map<String, double>>> getOpeningBalancesByType(
    DateTime forDate, {
    bool Function(OperationJournalEntry entry)? where,
  }) async {
    final balances = {
      'cash': <String, double>{'CDF': 0.0, 'USD': 0.0},
      'sales': <String, double>{'CDF': 0.0, 'USD': 0.0},
      'stock': <String, double>{'CDF': 0.0, 'USD': 0.0},
    };
    try {
      final box = await _getBox();
      final previous = reconcileJournalEntries(
        box.values.where((e) => e.date.isBefore(forDate)),
      );
      for (final e in previous) {
        if (where != null && !where(e)) continue;
        final bucket =
            e.type.impactsCash
                ? 'cash'
                : e.type.isSalesOperation
                ? 'sales'
                : e.type.impactsStock
                ? 'stock'
                : null;
        if (bucket == null) continue;
        final code = e.currencyCode ?? 'CDF';
        balances[bucket]![code] = (balances[bucket]![code] ?? 0.0) + e.amount;
      }
    } catch (e) {
      debugPrint("Erreur calcul soldes d'ouverture par type: $e");
    }
    return balances;
  }

  Future<double> getOpeningBalance(DateTime forDate) async {
    // Cette méthode restera pour la compatibilité, mais appelle getOpeningBalances et renvoie le total
    final balances = await getOpeningBalances(forDate);
    double total = 0.0;
    // Utiliser une boucle for pour éviter les problèmes potentiels avec FutureOr<double>
    for (final value in balances.values) {
      total += value;
    }
    return total;
  }

  Future<void> addOperation(OperationJournalEntry entry) async {
    // Assurer que l'ID est généré si non fourni
    var entryToSave = entry.id.isEmpty ? entry.copyWith(id: _uuid.v4()) : entry;

    debugPrint(
      "Adding operation: ${entryToSave.description}, Amount: ${entryToSave.amount}, Date: ${entryToSave.date}",
    );

    // Récupérer les soldes d'ouverture PAR TYPE (caisse, ventes, stock)
    final openingBalances = await getOpeningBalancesByType(entryToSave.date);
    final currency = entryToSave.currencyCode ?? 'CDF';

    // Initialiser les nouveaux soldes à partir des soldes d'ouverture
    final newCashBalances = Map<String, double>.from(openingBalances['cash']!);
    final newSalesBalances = Map<String, double>.from(
      openingBalances['sales']!,
    );
    final newStockBalances = Map<String, double>.from(
      openingBalances['stock']!,
    );

    // Variables pour les soldes spécifiques de cette entrée
    double? cashBalance;
    double? salesBalance;
    double? stockValue;

    // === TRAITEMENT SELON LE TYPE D'OPÉRATION ===

    // 1. Opérations de TRÉSORERIE (impact caisse)
    if (entryToSave.type.impactsCash) {
      debugPrint('💰 Opération de trésorerie: ${entryToSave.type.displayName}');

      // Calculer l'impact sur la caisse
      final currentCash = newCashBalances[currency] ?? 0.0;
      final cashImpact =
          entryToSave.amount; // Positif = entrée, Négatif = sortie

      newCashBalances[currency] = currentCash + cashImpact;
      cashBalance = newCashBalances[currency];

      debugPrint('   Solde caisse $currency: $currentCash → $cashBalance');
    }
    // 2. Opérations de VENTES (chiffre d'affaires)
    else if (entryToSave.type.isSalesOperation) {
      debugPrint('📊 Opération de vente: ${entryToSave.type.displayName}');

      // Cumuler les ventes (les corrections négatives sont soustraites)
      // NOTE: On n'utilise PAS abs() car une correction de vente doit être soustraite
      final currentSales = newSalesBalances[currency] ?? 0.0;
      newSalesBalances[currency] = currentSales + entryToSave.amount;
      salesBalance = newSalesBalances[currency];

      debugPrint('   Total ventes $currency: $currentSales → $salesBalance');
    }
    // 3. Opérations de STOCK (inventaire)
    else if (entryToSave.type.impactsStock) {
      debugPrint('📦 Opération de stock: ${entryToSave.type.displayName}');

      // Calculer la valeur du stock (positif = entrée, négatif = sortie)
      final currentStock = newStockBalances[currency] ?? 0.0;
      final stockImpact = entryToSave.amount; // Peut être négatif (sortie)

      newStockBalances[currency] = currentStock + stockImpact;
      stockValue = newStockBalances[currency];

      debugPrint('   Valeur stock $currency: $currentStock → $stockValue');
    }
    // 4. Opérations de FINANCEMENT (pas d'impact direct)
    else if (entryToSave.type.isFinancingOperation) {
      debugPrint('⚠️ Opération de financement exclue du calcul des soldes');
      // Pas d'impact sur les soldes
    }

    // Calculer un solde global pour rétrocompatibilité (DEPRECATED)
    double totalBalance = 0.0;
    newCashBalances.forEach((_, value) => totalBalance += value);

    // 5. Mettre à jour l'entrée avec les nouveaux soldes
    entryToSave = entryToSave.copyWith(
      balanceAfter: totalBalance, // DEPRECATED mais conservé
      balancesByCurrency:
          newCashBalances, // DEPRECATED - maintenant on utilise les 3 maps ci-dessous
      cashBalance: cashBalance,
      salesBalance: salesBalance,
      stockValue: stockValue,
      cashBalancesByCurrency: newCashBalances,
      salesBalancesByCurrency: newSalesBalances,
      stockValuesByCurrency: newStockBalances,
    );

    // D'abord, ajouter au cache local et à Hive pour une réactivité immédiate
    try {
      final box = await _getBox();
      await box.put(entryToSave.id, entryToSave);
      // Force flush to ensure data is written to disk (optional but good for debugging)
      await box.flush();
      debugPrint("Operation saved to Hive: ${entryToSave.id}");
    } catch (e) {
      debugPrint("ERROR saving operation to Hive: $e");
    }

    // NOTE: Le journal des opérations est généré CÔTÉ SERVEUR automatiquement
    // lorsque les entités (ventes, dépenses, etc.) sont synchronisées via leurs APIs respectives.
    // Il n'y a PAS d'endpoint POST pour créer des entrées de journal directement.
    // Les données locales servent uniquement pour l'affichage offline.
    debugPrint(
      '💾 Opération enregistrée localement: ${entryToSave.id} (${entryToSave.type.name})',
    );
    debugPrint(
      '📝 Note: Le journal backend sera mis à jour lors de la sync des entités (sales, expenses, etc.)',
    );
  }

  Future<void> addOperationEntries(List<OperationJournalEntry> entries) async {
    if (entries.isEmpty) {
      debugPrint("No operation entries to add.");
      return;
    }

    debugPrint("📝 Ajout de ${entries.length} opérations en batch");

    // Trier les entrées par date pour assurer un calcul séquentiel correct des soldes
    final sortedEntries = List<OperationJournalEntry>.from(entries)
      ..sort((a, b) => a.date.compareTo(b.date));

    final processedEntries = <OperationJournalEntry>[];
    final box = await _getBox();

    // Récupérer les soldes d'ouverture une seule fois pour la première entrée
    var currentBalances = await getOpeningBalancesByType(
      sortedEntries.first.date,
    );

    for (final entry in sortedEntries) {
      var entryToProcess =
          entry.id.isEmpty ? entry.copyWith(id: _uuid.v4()) : entry;

      final currency = entryToProcess.currencyCode ?? 'CDF';

      // Copier les balances actuelles
      final cashBalances = Map<String, double>.from(currentBalances['cash']!);
      final salesBalances = Map<String, double>.from(currentBalances['sales']!);
      final stockBalances = Map<String, double>.from(currentBalances['stock']!);

      double? cashBalance;
      double? salesBalance;
      double? stockValue;

      // Traiter selon le type d'opération
      if (entryToProcess.type.impactsCash) {
        final currentCash = cashBalances[currency] ?? 0.0;
        cashBalances[currency] = currentCash + entryToProcess.amount;
        cashBalance = cashBalances[currency];
      } else if (entryToProcess.type.isSalesOperation) {
        final currentSales = salesBalances[currency] ?? 0.0;
        // NOTE: On n'utilise PAS abs() car une correction de vente doit être soustraite
        salesBalances[currency] = currentSales + entryToProcess.amount;
        salesBalance = salesBalances[currency];
      } else if (entryToProcess.type.impactsStock) {
        final currentStock = stockBalances[currency] ?? 0.0;
        stockBalances[currency] = currentStock + entryToProcess.amount;
        stockValue = stockBalances[currency];
      }

      // Calculer solde global (DEPRECATED)
      double totalBalance = 0.0;
      cashBalances.forEach((_, value) => totalBalance += value);

      entryToProcess = entryToProcess.copyWith(
        balanceAfter: totalBalance,
        balancesByCurrency: cashBalances,
        cashBalance: cashBalance,
        salesBalance: salesBalance,
        stockValue: stockValue,
        cashBalancesByCurrency: cashBalances,
        salesBalancesByCurrency: salesBalances,
        stockValuesByCurrency: stockBalances,
      );

      // Mettre à jour les balances pour la prochaine itération
      currentBalances = {
        'cash': cashBalances,
        'sales': salesBalances,
        'stock': stockBalances,
      };

      // Ajouter localement immédiatement pour que la prochaine itération le voie
      await box.put(entryToProcess.id, entryToProcess);
      processedEntries.add(entryToProcess);
    }

    // Forcer l'écriture sur disque pour garantir la persistance
    try {
      await box.flush();
      debugPrint(
        '💾 Batch de ${processedEntries.length} opérations persisté avec succès',
      );
    } catch (e) {
      debugPrint('⚠️ Erreur lors du flush du batch: $e');
    }

    // NOTE: Le journal des opérations est généré CÔTÉ SERVEUR automatiquement
    // lorsque les entités (ventes, dépenses, etc.) sont synchronisées via leurs APIs respectives.
    // Il n'y a PAS d'endpoint POST pour créer des entrées de journal directement.
    debugPrint(
      '💾 Batch de ${processedEntries.length} opérations enregistré localement',
    );
    debugPrint(
      '📝 Note: Le journal backend sera mis à jour lors de la sync des entités (sales, expenses, etc.)',
    );
  }

  /// Récupère le journal des opérations depuis le backend pour mettre à jour le cache local.
  /// Le journal est GÉNÉRÉ côté serveur à partir des entités synchronisées (ventes, dépenses, etc.).
  Future<bool> pullJournalFromBackend() async {
    // Vérifier la connectivité en temps réel
    final isOnline = _connectivityService.isConnected;
    if (!isOnline) {
      debugPrint('📵 Pas de connexion - synchronisation annulée');
      return false;
    }

    try {
      debugPrint(
        '🔄 Récupération du journal des opérations depuis le backend...',
      );

      // Récupérer les opérations des 30 derniers jours depuis le backend
      final now = DateTime.now();
      final thirtyDaysAgo = now.subtract(const Duration(days: 30));

      // Toutes les pages (le backend pagine à 10 par défaut) ; le cache local
      // n'est complété qu'une fois la pagination terminée, jamais purgé.
      final operationsList = await fetchAllJournalPages(
        (query) => _apiService
            .get('journal/operations', queryParams: query)
            .timeout(const Duration(seconds: 10)),
        {
          'dateFrom': thirtyDaysAgo.toUtc().toIso8601String(),
          'dateTo': now.toUtc().toIso8601String(),
        },
      );

      if (operationsList != null && operationsList.isNotEmpty) {
        final box = await _getBox();
        int updatedCount = 0;

        for (final item in operationsList) {
          try {
            final entry = OperationJournalEntry.fromJson(
              item as Map<String, dynamic>,
            );
            await box.put(entry.id, entry);
            updatedCount++;
          } catch (e) {
            debugPrint('⚠️ Erreur parsing opération: $e');
          }
        }

        await box.flush();
        debugPrint(
          '✅ $updatedCount opérations récupérées et mises en cache depuis le backend',
        );
        return true;
      } else {
        debugPrint('ℹ️ Aucune opération récupérée du backend');
        return true;
      }
    } catch (e) {
      debugPrint('⚠️ Erreur lors de la récupération du journal: $e');
      return false;
    }
  }

  /// Handler nommé pour les changements de connectivité (permet removeListener)
  void _onConnectivityChanged() {
    _isOfflineMode = !_connectivityService.isConnected;
    debugPrint(
      '🔄 Mode offline mis à jour: $_isOfflineMode (connecté: ${_connectivityService.isConnected})',
    );
  }

  /// Active ou désactive le mode hors ligne
  void setOfflineMode(bool isOffline) {
    _isOfflineMode = isOffline;
    debugPrint('🔄 Mode ${isOffline ? "hors ligne" : "en ligne"} activé');
  }

  /// Vérifie si le mode hors ligne est actif
  bool get isOfflineMode => _isOfflineMode;

  // Méthodes pour récupérer les opérations par type

  /// Récupère les opérations de vente uniquement
  Future<List<OperationJournalEntry>> getSalesOperations(
    DateTime startDate,
    DateTime endDate,
  ) async {
    try {
      final box = await _getBox();
      // D'abord, récupérer les données locales qui correspondent aux critères
      final localEntries =
          box.values
              .where(
                (entry) =>
                    entry.date.isAfter(
                      startDate.subtract(const Duration(days: 1)),
                    ) &&
                    entry.date.isBefore(endDate.add(const Duration(days: 1))) &&
                    (entry.type == OperationType.saleCash ||
                        entry.type == OperationType.saleCredit ||
                        entry.type == OperationType.saleInstallment),
              )
              .toList()
            ..sort((a, b) => b.date.compareTo(a.date));

      if (_isOfflineMode) {
        return localEntries;
      }

      // Essayer de récupérer les données de l'API
      // Toutes les pages de la période (pagination backend à 10 par défaut).
      final operationsList = await fetchAllJournalPages(
        (query) => _apiService.get('operations', queryParams: query),
        {
          'dateFrom': startDate.toIso8601String(),
          'dateTo': endDate.toIso8601String(),
          'type': 'sale',
        },
      );
      if (operationsList != null && operationsList.isNotEmpty) {
        final apiEntries =
            operationsList
                .map(
                  (item) => OperationJournalEntry.fromJson(
                    item as Map<String, dynamic>,
                  ),
                )
                .toList();

        // Fusionner et synchroniser comme dans getOperations
        final mergedEntries = <OperationJournalEntry>[];
        final seenIds = <String>{};

        for (final entry in apiEntries) {
          mergedEntries.add(entry);
          seenIds.add(entry.id);

          // Mettre à jour le cache local
          await box.put(entry.id, entry);
        }

        for (final entry in localEntries) {
          if (!seenIds.contains(entry.id)) {
            mergedEntries.add(entry);
          }
        }

        mergedEntries.sort((a, b) => b.date.compareTo(a.date));
        return mergedEntries;
      }

      return localEntries;
    } catch (e) {
      debugPrint("Error fetching sales operations: $e");
      // En cas d'erreur, utiliser les données locales
      try {
        final box = await _getBox();
        return box.values
            .where(
              (entry) =>
                  entry.date.isAfter(
                    startDate.subtract(const Duration(days: 1)),
                  ) &&
                  entry.date.isBefore(endDate.add(const Duration(days: 1))) &&
                  (entry.type == OperationType.saleCash ||
                      entry.type == OperationType.saleCredit ||
                      entry.type == OperationType.saleInstallment),
            )
            .toList()
          ..sort((a, b) => b.date.compareTo(a.date));
      } catch (e2) {
        return [];
      }
    }
  }

  /// Récupère les opérations de caisse uniquement (entrées et sorties d'espèces)
  Future<List<OperationJournalEntry>> getCashOperations(
    DateTime startDate,
    DateTime endDate,
  ) async {
    try {
      final box = await _getBox();
      // D'abord, récupérer les données locales qui correspondent aux critères
      final localEntries =
          box.values
              .where(
                (entry) =>
                    entry.date.isAfter(
                      startDate.subtract(const Duration(days: 1)),
                    ) &&
                    entry.date.isBefore(endDate.add(const Duration(days: 1))) &&
                    (entry.type == OperationType.cashIn ||
                        entry.type == OperationType.cashOut),
              )
              .toList()
            ..sort((a, b) => b.date.compareTo(a.date));

      if (_isOfflineMode) {
        return localEntries;
      }

      // Essayer de récupérer les données de l'API
      // Toutes les pages de la période (pagination backend à 10 par défaut).
      final operationsList = await fetchAllJournalPages(
        (query) => _apiService.get('operations', queryParams: query),
        {
          'dateFrom': startDate.toIso8601String(),
          'dateTo': endDate.toIso8601String(),
          'type': 'expense',
        },
      );
      if (operationsList != null && operationsList.isNotEmpty) {
        final apiEntries =
            operationsList
                .map(
                  (item) => OperationJournalEntry.fromJson(
                    item as Map<String, dynamic>,
                  ),
                )
                .toList();

        // Fusionner et synchroniser comme dans getOperations
        final mergedEntries = <OperationJournalEntry>[];
        final seenIds = <String>{};

        for (final entry in apiEntries) {
          mergedEntries.add(entry);
          seenIds.add(entry.id);

          // Mettre à jour le cache local
          await box.put(entry.id, entry);
        }

        for (final entry in localEntries) {
          if (!seenIds.contains(entry.id)) {
            mergedEntries.add(entry);
          }
        }

        mergedEntries.sort((a, b) => b.date.compareTo(a.date));
        return mergedEntries;
      }

      return localEntries;
    } catch (e) {
      debugPrint("Error fetching cash operations: $e");
      // En cas d'erreur, utiliser les données locales
      try {
        final box = await _getBox();
        return box.values
            .where(
              (entry) =>
                  entry.date.isAfter(
                    startDate.subtract(const Duration(days: 1)),
                  ) &&
                  entry.date.isBefore(endDate.add(const Duration(days: 1))) &&
                  (entry.type == OperationType.cashIn ||
                      entry.type == OperationType.cashOut),
            )
            .toList()
          ..sort((a, b) => b.date.compareTo(a.date));
      } catch (e2) {
        return [];
      }
    }
  }

  /// Récupère les opérations de stock uniquement (entrées et sorties de stock)
  Future<List<OperationJournalEntry>> getInventoryOperations(
    DateTime startDate,
    DateTime endDate,
  ) async {
    try {
      final box = await _getBox();
      // D'abord, récupérer les données locales qui correspondent aux critères
      final localEntries =
          box.values
              .where(
                (entry) =>
                    entry.date.isAfter(
                      startDate.subtract(const Duration(days: 1)),
                    ) &&
                    entry.date.isBefore(endDate.add(const Duration(days: 1))) &&
                    (entry.type == OperationType.stockIn ||
                        entry.type == OperationType.stockOut),
              )
              .toList()
            ..sort((a, b) => b.date.compareTo(a.date));

      if (_isOfflineMode) {
        return localEntries;
      }

      // Essayer de récupérer les données de l'API
      // Toutes les pages de la période (pagination backend à 10 par défaut).
      final operationsList = await fetchAllJournalPages(
        (query) => _apiService.get('operations', queryParams: query),
        {
          'dateFrom': startDate.toIso8601String(),
          'dateTo': endDate.toIso8601String(),
          'type': 'adjustment',
        },
      );
      if (operationsList != null && operationsList.isNotEmpty) {
        final apiEntries =
            operationsList
                .map(
                  (item) => OperationJournalEntry.fromJson(
                    item as Map<String, dynamic>,
                  ),
                )
                .toList();

        // Fusionner et synchroniser comme dans getOperations
        final mergedEntries = <OperationJournalEntry>[];
        final seenIds = <String>{};

        for (final entry in apiEntries) {
          mergedEntries.add(entry);
          seenIds.add(entry.id);

          // Mettre à jour le cache local
          await box.put(entry.id, entry);
        }

        for (final entry in localEntries) {
          if (!seenIds.contains(entry.id)) {
            mergedEntries.add(entry);
          }
        }

        mergedEntries.sort((a, b) => b.date.compareTo(a.date));
        return mergedEntries;
      }

      return localEntries;
    } catch (e) {
      debugPrint("Error fetching inventory operations: $e");
      // En cas d'erreur, utiliser les données locales
      try {
        final box = await _getBox();
        return box.values
            .where(
              (entry) =>
                  entry.date.isAfter(
                    startDate.subtract(const Duration(days: 1)),
                  ) &&
                  entry.date.isBefore(endDate.add(const Duration(days: 1))) &&
                  (entry.type == OperationType.stockIn ||
                      entry.type == OperationType.stockOut),
            )
            .toList()
          ..sort((a, b) => b.date.compareTo(a.date));
      } catch (e2) {
        return [];
      }
    }
  }

  /// Récupère les opérations par type d'opération spécifique
  Future<List<OperationJournalEntry>> getOperationsByType(
    DateTime startDate,
    DateTime endDate,
    OperationType type,
  ) async {
    try {
      final box = await _getBox();
      // D'abord, récupérer les données locales qui correspondent aux critères
      final localEntries =
          box.values
              .where(
                (entry) =>
                    entry.date.isAfter(
                      startDate.subtract(const Duration(days: 1)),
                    ) &&
                    entry.date.isBefore(endDate.add(const Duration(days: 1))) &&
                    entry.type == type,
              )
              .toList()
            ..sort((a, b) => b.date.compareTo(a.date));

      if (_isOfflineMode) {
        return localEntries;
      }

      // Essayer de récupérer les données de l'API
      // Toutes les pages de la période (pagination backend à 10 par défaut).
      final operationsList = await fetchAllJournalPages(
        (query) => _apiService.get('operations', queryParams: query),
        {
          'dateFrom': startDate.toIso8601String(),
          'dateTo': endDate.toIso8601String(),
          'type': type.name,
        },
      );
      if (operationsList != null && operationsList.isNotEmpty) {
        final apiEntries =
            operationsList
                .map(
                  (item) => OperationJournalEntry.fromJson(
                    item as Map<String, dynamic>,
                  ),
                )
                .toList();

        // Fusionner et synchroniser comme dans getOperations
        final mergedEntries = <OperationJournalEntry>[];
        final seenIds = <String>{};

        for (final entry in apiEntries) {
          mergedEntries.add(entry);
          seenIds.add(entry.id);

          // Mettre à jour le cache local
          await box.put(entry.id, entry);
        }

        for (final entry in localEntries) {
          if (!seenIds.contains(entry.id)) {
            mergedEntries.add(entry);
          }
        }

        mergedEntries.sort((a, b) => b.date.compareTo(a.date));
        return mergedEntries;
      }

      return localEntries;
    } catch (e) {
      debugPrint("Error fetching operations by type: $e");
      // En cas d'erreur, utiliser les données locales
      try {
        final box = await _getBox();
        return box.values
            .where(
              (entry) =>
                  entry.date.isAfter(
                    startDate.subtract(const Duration(days: 1)),
                  ) &&
                  entry.date.isBefore(endDate.add(const Duration(days: 1))) &&
                  entry.type == type,
            )
            .toList()
          ..sort((a, b) => b.date.compareTo(a.date));
      } catch (e2) {
        return [];
      }
    }
  }

  // Updated for AdhaBloc integration - uses local data with API fallback
  Future<List<Map<String, dynamic>>> getRecentEntries({int limit = 5}) async {
    try {
      final box = await _getBox();
      // D'abord, récupérer les entrées récentes du cache local
      final localEntries =
          box.values.toList()..sort((a, b) => b.date.compareTo(a.date));

      final recentLocalEntries =
          localEntries.take(limit).map((e) => e.toContextMap()).toList();

      if (_isOfflineMode) {
        return recentLocalEntries;
      }

      // En mode en ligne, essayer de récupérer les données de l'API
      // GET /operations/timeline - Timeline des opérations récentes
      final response = await _apiService.get(
        'journal/operations/timeline',
        queryParams: {'limit': limit},
      );

      final operationsList = _extractListFromResponse(response['data']);
      if (operationsList != null && operationsList.isNotEmpty) {
        final apiEntries =
            operationsList
                .map((item) {
                  if (item is Map<String, dynamic>) {
                    return OperationJournalEntry.fromJson(item).toContextMap();
                  } else {
                    debugPrint(
                      "Skipping non-map item in recent journal entries: $item",
                    );
                    return <String, dynamic>{};
                  }
                })
                .where((map) => map.isNotEmpty)
                .toList();

        // Si l'API a réussi, mettre à jour les entrées locales et retourner les données de l'API
        if (apiEntries.isNotEmpty) {
          // On pourrait mettre à jour le cache local ici, mais ce n'est pas essentiel
          // car getRecentEntries est principalement utilisé pour l'affichage
          return apiEntries;
        }
      }

      // Si l'API a échoué, retourner les données locales
      return recentLocalEntries;
    } catch (e) {
      debugPrint("Error fetching recent journal entries from API: $e");
      // Retourner les données locales en cas d'erreur
      try {
        final box = await _getBox();
        final localEntries =
            box.values.toList()..sort((a, b) => b.date.compareTo(a.date));

        return localEntries.take(limit).map((e) => e.toContextMap()).toList();
      } catch (e2) {
        return [];
      }
    }
  }

  // Updated for AdhaBloc integration - uses local data with API fallback
  Future<Map<String, dynamic>> getSummaryMetrics() async {
    try {
      final box = await _getBox();
      // Calculer les métriques locales à partir du cache en mémoire
      double totalRevenue = 0.0;
      double totalExpenses = 0.0;
      int numberOfTransactions = box.length;

      for (final entry in box.values) {
        if (entry.isCredit) {
          totalRevenue += entry.amount;
        } else if (entry.isDebit) {
          totalExpenses += entry.amount;
        }
      }

      final localMetrics = {
        'totalRevenue': totalRevenue,
        'totalExpenses': totalExpenses,
        'netFlow': totalRevenue - totalExpenses,
        'numberOfTransactions': numberOfTransactions,
        'summaryPeriod': 'local_data',
      };

      if (_isOfflineMode) {
        return localMetrics;
      }

      // En mode en ligne, essayer de récupérer les données de l'API
      // GET /operations/summary - Résumé des opérations par période
      final response = await _apiService.get(
        'journal/operations/summary',
        queryParams: {'period': 'month'},
      );

      if (response['data'] != null &&
          response['data'] is Map<String, dynamic>) {
        // Utiliser les métriques de l'API
        final metrics = response['data'] as Map<String, dynamic>;
        return {
          'totalRevenue': (metrics['totalRevenue'] as num?)?.toDouble() ?? 0.0,
          'totalExpenses':
              (metrics['totalExpenses'] as num?)?.toDouble() ?? 0.0,
          'netFlow': (metrics['netFlow'] as num?)?.toDouble() ?? 0.0,
          'numberOfTransactions':
              (metrics['numberOfTransactions'] as int?) ?? 0,
          'summaryPeriod': metrics['summaryPeriod'] as String? ?? 'api_data',
        };
      } else if (response.containsKey('totalRevenue')) {
        // Si la réponse est directement la carte des métriques
        return {
          'totalRevenue': (response['totalRevenue'] as num?)?.toDouble() ?? 0.0,
          'totalExpenses':
              (response['totalExpenses'] as num?)?.toDouble() ?? 0.0,
          'netFlow': (response['netFlow'] as num?)?.toDouble() ?? 0.0,
          'numberOfTransactions':
              (response['numberOfTransactions'] as int?) ?? 0,
          'summaryPeriod': response['summaryPeriod'] as String? ?? 'api_data',
        };
      }

      // Si l'API a échoué, retourner les métriques locales
      return localMetrics;
    } catch (e) {
      debugPrint("Error fetching summary metrics from API: $e");
      // Calculer les métriques locales en cas d'erreur
      try {
        final box = await _getBox();
        double totalRevenue = 0.0;
        double totalExpenses = 0.0;
        int numberOfTransactions = box.length;

        for (final entry in box.values) {
          if (entry.isCredit) {
            totalRevenue += entry.amount;
          } else if (entry.isDebit) {
            totalExpenses += entry.amount;
          }
        }

        return {
          'totalRevenue': totalRevenue,
          'totalExpenses': totalExpenses,
          'netFlow': totalRevenue - totalExpenses,
          'numberOfTransactions': numberOfTransactions,
          'summaryPeriod': 'local_data_fallback',
        };
      } catch (e2) {
        // Ni le serveur ni le journal local : le resume est INDISPONIBLE.
        // Des zeros feraient croire a une periode sans aucune operation.
        return journalSummaryUnavailable();
      }
    }
  }

  /// Resume du journal quand aucune source ne repond : montants nuls (null,
  /// jamais 0) et libelle « indisponible », pour que l'ecran et Adha disent
  /// « indisponible » au lieu d'afficher une periode a zero.
  static Map<String, dynamic> journalSummaryUnavailable() => const {
        'available': false,
        'totalRevenue': null,
        'totalExpenses': null,
        'netFlow': null,
        'numberOfTransactions': null,
        'summaryPeriod': 'indisponible',
      };

  /// Écritures du journal rattachées à une pièce (vente, dépense), sous son
  /// identifiant serveur ou local (une pièce saisie hors ligne change
  /// d'identifiant à l'envoi).
  Future<List<OperationJournalEntry>> entriesForDocument(
    Iterable<String?> documentIds,
  ) async {
    final ids = {
      for (final id in documentIds)
        if (id != null && id.isNotEmpty) id,
    };
    if (ids.isEmpty) return const [];
    try {
      final box = await _getBox();
      return box.values
          .where((e) => ids.contains(e.relatedDocumentId))
          .toList();
    } catch (e) {
      debugPrint('Journal illisible pour la pièce $ids: $e');
      return const [];
    }
  }

  /// Pièce annulée : ses écritures sont contre-passées (caisse, ventes,
  /// stock reviennent à zéro pour elle). Sans effet si c'est déjà fait.
  /// Renvoie le nombre d'écritures ajoutées.
  Future<int> reverseDocument(Iterable<String?> documentIds) async {
    final entries = await entriesForDocument(documentIds);
    final reversals = journalReversalEntries(
      entries,
      at: DateTime.now(),
      newId: _uuid.v4,
    );
    if (reversals.isNotEmpty) await addOperationEntries(reversals);
    return reversals.length;
  }

  /// Pièce rétablie : ses écritures d'origine sont reprises. Sans effet si
  /// elle n'était pas contre-passée.
  Future<int> reinstateDocument(Iterable<String?> documentIds) async {
    final entries = await entriesForDocument(documentIds);
    final again = journalReinstatementEntries(
      entries,
      at: DateTime.now(),
      newId: _uuid.v4,
    );
    if (again.isNotEmpty) await addOperationEntries(again);
    return again.length;
  }

  /// Vider le cache local des entrées de journal (à utiliser lors du changement de business unit)
  Future<void> clearLocalCache() async {
    try {
      final box = await _getBox();
      await box.clear();
      debugPrint('Cache local du journal des opérations vidé');
    } catch (e) {
      debugPrint('Erreur lors du vidage du cache du journal: $e');
    }
  }

  /// Libère les ressources (retire le listener de connectivité)
  void dispose() {
    _connectivityService.connectionStatus.removeListener(
      _onConnectivityChanged,
    );
  }
}
