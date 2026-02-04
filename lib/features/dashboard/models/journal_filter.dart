import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart';
import 'operation_journal_entry.dart';

/// Modèle pour les filtres du journal des opérations
@immutable
class JournalFilter extends Equatable {
  final DateTime? startDate;
  final DateTime? endDate;
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
      endDate: DateTime(now.year, now.month + 1, 0),
      selectedTypes: OperationType.values.toSet(),
    );
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
      selectedTypes: {
        OperationType.stockIn,
        OperationType.stockOut,
      },
    );
  }

  /// Filtre pour les dépenses uniquement
  factory JournalFilter.expensesOnly({DateTime? startDate, DateTime? endDate}) {
    return JournalFilter(
      startDate: startDate,
      endDate: endDate,
      selectedTypes: {
        OperationType.cashOut,
        OperationType.supplierPayment,
      },
    );
  }

  /// Filtre pour les dettes clients
  factory JournalFilter.customerDebts({DateTime? startDate, DateTime? endDate}) {
    return JournalFilter(
      startDate: startDate,
      endDate: endDate,
      selectedTypes: {
        OperationType.saleCredit,
        OperationType.saleInstallment,
      },
    );
  }

  JournalFilter copyWith({
    DateTime? startDate,
    DateTime? endDate,
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
      selectedTypes: selectedTypes ?? this.selectedTypes,
      selectedCurrencies: selectedCurrencies ?? this.selectedCurrencies,
      selectedPaymentMethods: selectedPaymentMethods ?? this.selectedPaymentMethods,
      minAmount: minAmount ?? this.minAmount,
      maxAmount: maxAmount ?? this.maxAmount,
      searchQuery: searchQuery ?? this.searchQuery,
      sortBy: sortBy ?? this.sortBy,
      sortAscending: sortAscending ?? this.sortAscending,
    );
  }

  /// Vérifie si une entrée du journal correspond aux filtres
  bool matches(OperationJournalEntry entry) {
    // Filtre par dates
    if (startDate != null && entry.date.isBefore(startDate!)) return false;
    if (endDate != null && entry.date.isAfter(endDate!)) return false;

    // Filtre par types d'opérations
    if (selectedTypes.isNotEmpty && !selectedTypes.contains(entry.type)) {
      return false;
    }

    // Filtre par devises
    if (selectedCurrencies.isNotEmpty && 
        !selectedCurrencies.contains(entry.currencyCode)) {
      return false;
    }

    // Filtre par méthodes de paiement
    if (selectedPaymentMethods.isNotEmpty && 
        entry.paymentMethod != null && 
        !selectedPaymentMethods.contains(entry.paymentMethod)) {
      return false;
    }

    // Filtre par montant
    final absAmount = entry.amount.abs();
    if (minAmount != null && absAmount < minAmount!) return false;
    if (maxAmount != null && absAmount > maxAmount!) return false;

    // Filtre par recherche textuelle
    if (searchQuery != null && searchQuery!.isNotEmpty) {
      final query = searchQuery!.toLowerCase();
      if (!entry.description.toLowerCase().contains(query) &&
          !(entry.productName?.toLowerCase().contains(query) ?? false)) {
        return false;
      }
    }

    return true;
  }

  /// Retourne true si le filtre a des critères actifs
  bool get hasActiveFilters {
    return selectedTypes.length != OperationType.values.length ||
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
enum JournalSortOption {
  date,
  amount,
  type,
  description,
}

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
