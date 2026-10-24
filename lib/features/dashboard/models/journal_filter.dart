import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart';
import 'operation_journal_entry.dart';

/// Vue du journal : tout, la CAISSE (espèces seulement) ou la COMPTABILITÉ
/// (toutes les opérations monétaires, tous moyens de paiement, sans les
/// mouvements de stock en quantité).
enum JournalView { all, cash, accounting }

extension JournalViewLabel on JournalView {
  String get label {
    switch (this) {
      case JournalView.all:
        return 'Tout';
      case JournalView.cash:
        return 'Caisse';
      case JournalView.accounting:
        return 'Comptabilité';
    }
  }

  /// Titre des états exportés.
  String get exportTitle {
    switch (this) {
      case JournalView.all:
        return 'Journal des opérations';
      case JournalView.cash:
        return 'Journal de caisse (espèces)';
      case JournalView.accounting:
        return 'Journal comptable';
    }
  }

  String get hint {
    switch (this) {
      case JournalView.all:
        return 'Toutes les opérations, stock compris';
      case JournalView.cash:
        return 'Entrées et sorties d\'espèces uniquement';
      case JournalView.accounting:
        return 'Ventes, encaissements, dépenses et règlements, tous moyens';
    }
  }
}

/// Vrai si le moyen de paiement est des ESPÈCES. Un moyen absent ou « N/A »
/// est compté en espèces : c'est la valeur par défaut des caisses (les
/// anciennes dépenses portent « N/A »).
bool isCashPaymentMethod(String? method) {
  final m = (method ?? '').trim().toLowerCase();
  if (m.isEmpty || m == 'n/a' || m == 'na') return true;
  return m == 'cash' ||
      m.startsWith('esp') ||
      m.startsWith('cash') ||
      m == 'liquide' ||
      m == 'especes';
}

/// Début du jour LOCAL de [d] (00:00:00.000).
DateTime journalDayStart(DateTime d) {
  final l = d.toLocal();
  return DateTime(l.year, l.month, l.day);
}

/// Fin du jour LOCAL de [d] (23:59:59.999) : le jour de fin est compris.
DateTime journalDayEnd(DateTime d) {
  final l = d.toLocal();
  return DateTime(l.year, l.month, l.day, 23, 59, 59, 999);
}

/// Préfixes des lignes construites par le serveur (`journal/operations`).
const _serverIdPrefixes = ['sale-', 'expense-', 'stock-', 'operation-'];

bool isServerJournalEntry(OperationJournalEntry e) =>
    _serverIdPrefixes.any((p) => e.id.startsWith(p));

/// Écarte les lignes LOCALES d'une pièce que le serveur publie déjà.
///
/// L'appareil écrit ses propres lignes (identifiants aléatoires) à chaque
/// vente ou dépense ; une fois la pièce synchronisée, le serveur renvoie les
/// siennes (`sale-<id>`, `expense-<id>`…). Sans ce rapprochement, chaque
/// vente saisie sur l'appareil comptait deux fois dans le journal, ses
/// totaux et son export. Le rapprochement se fait par la pièce : identifiant
/// serveur ou identifiant hors ligne (`sourceLocalId`).
List<OperationJournalEntry> reconcileJournalEntries(
  Iterable<OperationJournalEntry> entries,
) {
  final list = entries.toList();
  final knownDocuments = <String>{};
  for (final e in list) {
    if (!isServerJournalEntry(e)) continue;
    final doc = e.relatedDocumentId;
    if (doc != null && doc.isNotEmpty) knownDocuments.add(doc);
    final local = e.sourceLocalId;
    if (local != null && local.isNotEmpty) knownDocuments.add(local);
  }
  if (knownDocuments.isEmpty) return list;
  return list.where((e) {
    if (isServerJournalEntry(e)) return true;
    final doc = e.relatedDocumentId;
    return doc == null || doc.isEmpty || !knownDocuments.contains(doc);
  }).toList();
}

/// Modèle pour les filtres du journal des opérations.
///
/// La période est faite de JOURS LOCAUX complets : du début du jour de
/// [startDate] à la fin du jour de [endDate], bornes comprises. Une vente à
/// 23:30 à Goma (21:30 UTC) tombe donc le bon jour.
@immutable
class JournalFilter extends Equatable {
  final DateTime? startDate;
  final DateTime? endDate;
  final JournalView view;
  final Set<OperationType> selectedTypes;
  final Set<String> selectedCurrencies;
  final Set<String> selectedPaymentMethods;
  final double? minAmount;
  final double? maxAmount;
  final String? searchQuery;
  final JournalSortOption sortBy;
  final bool sortAscending;

  const JournalFilter({
    this.startDate,
    this.endDate,
    this.view = JournalView.all,
    this.selectedTypes = const {},
    this.selectedCurrencies = const {},
    this.selectedPaymentMethods = const {},
    this.minAmount,
    this.maxAmount,
    this.searchQuery,
    this.sortBy = JournalSortOption.date,
    this.sortAscending = false,
  });

  /// Filtre par défaut (toutes les opérations du mois courant)
  factory JournalFilter.defaultFilter() {
    final now = DateTime.now();
    return JournalFilter(
      startDate: DateTime(now.year, now.month, 1),
      endDate: journalDayEnd(DateTime(now.year, now.month + 1, 0)),
    );
  }

  /// Une vue (Tout, Caisse, Comptabilité). Période nulle = période en cours.
  factory JournalFilter.forView(
    JournalView view, {
    DateTime? startDate,
    DateTime? endDate,
  }) {
    return JournalFilter(startDate: startDate, endDate: endDate, view: view);
  }

  /// Filtre pour les ventes uniquement
  factory JournalFilter.salesOnly({DateTime? startDate, DateTime? endDate}) {
    return JournalFilter(
      startDate: startDate,
      endDate: endDate,
      selectedTypes: {
        OperationType.saleCash,
        OperationType.saleCredit,
        OperationType.saleInstallment,
        OperationType.customerPayment,
      },
    );
  }

  /// Filtre pour les opérations de stock uniquement
  factory JournalFilter.stockOnly({DateTime? startDate, DateTime? endDate}) {
    return JournalFilter(
      startDate: startDate,
      endDate: endDate,
      selectedTypes: {OperationType.stockIn, OperationType.stockOut},
    );
  }

  /// Filtre pour les dépenses uniquement (payées, à payer, règlements)
  factory JournalFilter.expensesOnly({DateTime? startDate, DateTime? endDate}) {
    return JournalFilter(
      startDate: startDate,
      endDate: endDate,
      selectedTypes: {
        OperationType.cashOut,
        OperationType.supplierPayment,
        OperationType.other,
      },
    );
  }

  /// Filtre pour les dettes clients
  factory JournalFilter.customerDebts({
    DateTime? startDate,
    DateTime? endDate,
  }) {
    return JournalFilter(
      startDate: startDate,
      endDate: endDate,
      selectedTypes: {OperationType.saleCredit, OperationType.saleInstallment},
    );
  }

  /// Vue CAISSE : mouvements d'espèces uniquement.
  factory JournalFilter.cashFlowOnly({DateTime? startDate, DateTime? endDate}) {
    return JournalFilter.forView(
      JournalView.cash,
      startDate: startDate,
      endDate: endDate,
    );
  }

  /// Vue COMPTABLE : toutes les opérations monétaires, tous moyens.
  factory JournalFilter.accountingOnly({
    DateTime? startDate,
    DateTime? endDate,
  }) {
    return JournalFilter.forView(
      JournalView.accounting,
      startDate: startDate,
      endDate: endDate,
    );
  }

  /// Début effectif de la période (début du jour local).
  DateTime? get periodStart => startDate == null ? null : journalDayStart(startDate!);

  /// Fin effective de la période (fin du jour local, jour compris).
  DateTime? get periodEnd => endDate == null ? null : journalDayEnd(endDate!);

  JournalFilter copyWith({
    DateTime? startDate,
    DateTime? endDate,
    JournalView? view,
    Set<OperationType>? selectedTypes,
    Set<String>? selectedCurrencies,
    Set<String>? selectedPaymentMethods,
    double? minAmount,
    double? maxAmount,
    String? searchQuery,
    JournalSortOption? sortBy,
    bool? sortAscending,
  }) {
    return JournalFilter(
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      view: view ?? this.view,
      selectedTypes: selectedTypes ?? this.selectedTypes,
      selectedCurrencies: selectedCurrencies ?? this.selectedCurrencies,
      selectedPaymentMethods:
          selectedPaymentMethods ?? this.selectedPaymentMethods,
      minAmount: minAmount ?? this.minAmount,
      maxAmount: maxAmount ?? this.maxAmount,
      searchQuery: searchQuery ?? this.searchQuery,
      sortBy: sortBy ?? this.sortBy,
      sortAscending: sortAscending ?? this.sortAscending,
    );
  }

  /// La ligne tombe-t-elle dans la période (jours locaux, bornes comprises) ?
  bool matchesPeriod(OperationJournalEntry entry) {
    final t = entry.date.toLocal();
    final start = periodStart;
    final end = periodEnd;
    if (start != null && t.isBefore(start)) return false;
    if (end != null && t.isAfter(end)) return false;
    return true;
  }

  /// Tous les critères SAUF la période (sert aussi aux soldes d'ouverture).
  bool matchesScope(OperationJournalEntry entry) {
    switch (view) {
      case JournalView.all:
        break;
      case JournalView.cash:
        if (!entry.type.impactsCash) return false;
        if (!isCashPaymentMethod(entry.paymentMethod)) return false;
        break;
      case JournalView.accounting:
        if (entry.type.impactsStock) return false;
        break;
    }

    if (selectedTypes.isNotEmpty && !selectedTypes.contains(entry.type)) {
      return false;
    }

    if (selectedCurrencies.isNotEmpty &&
        !selectedCurrencies.contains(entry.currencyCode ?? 'CDF')) {
      return false;
    }

    // Un filtre de moyen de paiement écarte les lignes sans moyen.
    if (selectedPaymentMethods.isNotEmpty) {
      final method = entry.paymentMethod?.trim().toLowerCase();
      final wanted = selectedPaymentMethods.map((m) => m.trim().toLowerCase());
      if (method == null || !wanted.contains(method)) return false;
    }

    final absAmount = entry.amount.abs();
    if (minAmount != null && absAmount < minAmount!) return false;
    if (maxAmount != null && absAmount > maxAmount!) return false;

    final query = searchQuery?.trim().toLowerCase();
    if (query != null && query.isNotEmpty) {
      final haystack = [
        entry.description,
        entry.productName,
        entry.customerName,
        entry.supplierName,
      ].whereType<String>().map((s) => s.toLowerCase());
      if (!haystack.any((s) => s.contains(query))) return false;
    }

    return true;
  }

  /// Vérifie si une entrée du journal correspond aux filtres
  bool matches(OperationJournalEntry entry) =>
      matchesPeriod(entry) && matchesScope(entry);

  /// Retourne true si le filtre a des critères actifs (hors période)
  bool get hasActiveFilters {
    return view != JournalView.all ||
        (selectedTypes.isNotEmpty &&
            selectedTypes.length != OperationType.values.length) ||
        selectedCurrencies.isNotEmpty ||
        selectedPaymentMethods.isNotEmpty ||
        minAmount != null ||
        maxAmount != null ||
        searchQuery?.isNotEmpty == true;
  }

  @override
  List<Object?> get props => [
    startDate,
    endDate,
    view,
    selectedTypes,
    selectedCurrencies,
    selectedPaymentMethods,
    minAmount,
    maxAmount,
    searchQuery,
    sortBy,
    sortAscending,
  ];
}

/// Options de tri pour le journal
enum JournalSortOption { date, amount, type, description }

extension JournalSortOptionExtension on JournalSortOption {
  String get displayName {
    switch (this) {
      case JournalSortOption.date:
        return 'Date';
      case JournalSortOption.amount:
        return 'Montant';
      case JournalSortOption.type:
        return 'Type';
      case JournalSortOption.description:
        return 'Description';
    }
  }
}
