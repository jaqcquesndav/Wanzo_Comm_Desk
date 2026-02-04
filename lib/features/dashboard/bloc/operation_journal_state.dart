part of 'operation_journal_bloc.dart';

@immutable
abstract class OperationJournalState {
  const OperationJournalState();
}

class OperationJournalInitial extends OperationJournalState {
  const OperationJournalInitial();
}

class OperationJournalLoading extends OperationJournalState {
  const OperationJournalLoading();
}

class OperationJournalLoaded extends OperationJournalState {
  final List<OperationJournalEntry> operations;
  final List<OperationJournalEntry> filteredOperations;
  final DateTime startDate;
  final DateTime endDate;
  final Map<DateTime, List<OperationJournalEntry>> groupedOperations;
  @Deprecated(
    'Utiliser openingCashBalances, openingSalesBalances ou openingStockValues',
  )
  final double openingBalance; // Maintenu pour compatibilité
  @Deprecated('Utiliser les maps spécifiques par type')
  final Map<String, double> openingBalancesByCurrency;

  // Nouveaux champs pour les soldes séparés
  final Map<String, double>
  openingCashBalances; // Soldes de trésorerie d'ouverture
  final Map<String, double> openingSalesBalances; // Cumul ventes d'ouverture
  final Map<String, double> openingStockValues; // Valeur stock d'ouverture

  final JournalFilter? activeFilter;

  const OperationJournalLoaded({
    required this.operations,
    required this.filteredOperations,
    required this.startDate,
    required this.endDate,
    required this.groupedOperations,
    @Deprecated('Utiliser openingCashBalances') required this.openingBalance,
    @Deprecated('Utiliser les maps spécifiques')
    required this.openingBalancesByCurrency,
    required this.openingCashBalances,
    required this.openingSalesBalances,
    required this.openingStockValues,
    this.activeFilter,
  });

  OperationJournalLoaded copyWith({
    List<OperationJournalEntry>? operations,
    List<OperationJournalEntry>? filteredOperations,
    DateTime? startDate,
    DateTime? endDate,
    Map<DateTime, List<OperationJournalEntry>>? groupedOperations,
    double? openingBalance,
    Map<String, double>? openingBalancesByCurrency,
    Map<String, double>? openingCashBalances,
    Map<String, double>? openingSalesBalances,
    Map<String, double>? openingStockValues,
    JournalFilter? activeFilter,
  }) {
    return OperationJournalLoaded(
      operations: operations ?? this.operations,
      filteredOperations: filteredOperations ?? this.filteredOperations,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      groupedOperations: groupedOperations ?? this.groupedOperations,
      openingBalance: openingBalance ?? this.openingBalance,
      openingBalancesByCurrency:
          openingBalancesByCurrency ?? this.openingBalancesByCurrency,
      openingCashBalances: openingCashBalances ?? this.openingCashBalances,
      openingSalesBalances: openingSalesBalances ?? this.openingSalesBalances,
      openingStockValues: openingStockValues ?? this.openingStockValues,
      activeFilter: activeFilter ?? this.activeFilter,
    );
  }
}

class OperationJournalError extends OperationJournalState {
  final String message;
  const OperationJournalError(this.message);
}
