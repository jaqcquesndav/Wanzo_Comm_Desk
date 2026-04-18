part of 'operation_journal_bloc.dart';

/// Résumé des soldes d'ouverture et de fermeture pour une journée donnée.
/// Chaque map est indexée par code devise (ex: 'CDF', 'USD').
class DailyBalanceSummary {
  final Map<String, double> openingCash;
  final Map<String, double> closingCash;
  final Map<String, double> openingSales;
  final Map<String, double> closingSales;
  final Map<String, double> openingStock;
  final Map<String, double> closingStock;

  const DailyBalanceSummary({
    required this.openingCash,
    required this.closingCash,
    required this.openingSales,
    required this.closingSales,
    required this.openingStock,
    required this.closingStock,
  });
}

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

  /// Soldes d'ouverture et de fermeture par jour
  /// La clé est la date tronquée au jour (DateTime(y, m, d))
  final Map<DateTime, DailyBalanceSummary> dailyBalances;

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
    this.dailyBalances = const {},
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
    Map<DateTime, DailyBalanceSummary>? dailyBalances,
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
      dailyBalances: dailyBalances ?? this.dailyBalances,
      activeFilter: activeFilter ?? this.activeFilter,
    );
  }
}

class OperationJournalError extends OperationJournalState {
  final String message;
  const OperationJournalError(this.message);
}
