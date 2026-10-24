import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter/foundation.dart';
import '../models/operation_journal_entry.dart';
import '../models/journal_filter.dart';
import '../repositories/operation_journal_repository.dart';
import 'package:collection/collection.dart'; // For groupBy
import '../../../core/utils/connectivity_service.dart';

part 'operation_journal_event.dart';
part 'operation_journal_state.dart';

/// Lignes du journal retenues par [filter] (période en jours locaux, vue,
/// types, devises, moyens, montants, recherche), triées selon le filtre.
///
/// C'est la SEULE liste que l'écran affiche et que les exports reçoivent :
/// affichage et export ne peuvent plus diverger.
@visibleForTesting
List<OperationJournalEntry> applyJournalFilter(
  Iterable<OperationJournalEntry> entries,
  JournalFilter filter,
) {
  final kept = entries.where(filter.matches).toList();
  int compare(OperationJournalEntry a, OperationJournalEntry b) {
    switch (filter.sortBy) {
      case JournalSortOption.date:
        return a.date.compareTo(b.date);
      case JournalSortOption.amount:
        return a.amount.abs().compareTo(b.amount.abs());
      case JournalSortOption.type:
        return a.type.displayName.compareTo(b.type.displayName);
      case JournalSortOption.description:
        return a.description.compareTo(b.description);
    }
  }

  kept.sort((a, b) => filter.sortAscending ? compare(a, b) : compare(b, a));
  return kept;
}

/// Jour LOCAL d'une ligne (clé de regroupement par jour).
DateTime _localDay(OperationJournalEntry op) {
  final l = op.date.toLocal();
  return DateTime(l.year, l.month, l.day);
}

class OperationJournalBloc
    extends Bloc<OperationJournalEvent, OperationJournalState> {
  final OperationJournalRepository _repository;
  final ConnectivityService _connectivityService;
  StreamSubscription? _connectivitySubscription;

  /// Filtre en vigueur (période comprise). Il survit aux rechargements : un
  /// changement de période garde la vue et les types choisis, et un filtre
  /// rapide garde la période affichée.
  JournalFilter _filter = JournalFilter.defaultFilter();
  JournalFilter get currentFilter => _filter;

  // Getter public pour accéder au repository depuis l'extérieur
  OperationJournalRepository get repository => _repository;

  OperationJournalBloc({
    required OperationJournalRepository repository,
    ConnectivityService? connectivityService,
  }) : _repository = repository,
       _connectivityService = connectivityService ?? ConnectivityService(),
       super(const OperationJournalInitial()) {
    on<LoadOperations>(_onLoadOperations);
    on<LoadOperationsWithFilter>(_onLoadOperationsWithFilter);
    on<FilterPeriodChanged>(_onFilterPeriodChanged);
    on<RefreshJournal>(_onRefreshJournal);
    on<AddOperationJournalEntry>(_onAddOperationJournalEntry);
    on<AddMultipleOperationJournalEntries>(
      _onAddMultipleOperationJournalEntries,
    );

    // Écouter les changements de connectivité pour synchroniser automatiquement
    _setupConnectivityListener();
  }

  void _setupConnectivityListener() {
    _connectivitySubscription = Stream.periodic(
      const Duration(milliseconds: 500),
      (_) => _connectivityService.isConnected,
    ).distinct().listen((isConnected) {
      if (isConnected && !isClosed) add(const RefreshJournal());
    });
  }

  @override
  Future<void> close() {
    _connectivitySubscription?.cancel();
    return super.close();
  }

  Future<void> _onLoadOperations(
    LoadOperations event,
    Emitter<OperationJournalState> emit,
  ) async {
    _filter = _filter.copyWith(
      startDate: event.startDate,
      endDate: event.endDate,
    );
    await _load(emit);
  }

  Future<void> _onLoadOperationsWithFilter(
    LoadOperationsWithFilter event,
    Emitter<OperationJournalState> emit,
  ) async {
    // Un filtre sans période garde la période affichée.
    final f = event.filter;
    _filter = JournalFilter(
      startDate: f.startDate ?? _filter.startDate,
      endDate: f.endDate ?? _filter.endDate,
      view: f.view,
      selectedTypes: f.selectedTypes,
      selectedCurrencies: f.selectedCurrencies,
      selectedPaymentMethods: f.selectedPaymentMethods,
      minAmount: f.minAmount,
      maxAmount: f.maxAmount,
      searchQuery: f.searchQuery,
      sortBy: f.sortBy,
      sortAscending: f.sortAscending,
    );
    await _load(emit);
  }

  Future<void> _onFilterPeriodChanged(
    FilterPeriodChanged event,
    Emitter<OperationJournalState> emit,
  ) async {
    _filter = _filter.copyWith(
      startDate: event.newStartDate,
      endDate: event.newEndDate,
    );
    await _load(emit);
  }

  Future<void> _onRefreshJournal(
    RefreshJournal event,
    Emitter<OperationJournalState> emit,
  ) async {
    await _load(emit);
  }

  /// Charge la période du filtre, applique TOUS les critères et calcule les
  /// soldes sur les seules lignes retenues.
  Future<void> _load(Emitter<OperationJournalState> emit) async {
    final filter = _filter;
    final start = filter.periodStart ?? journalDayStart(DateTime.now());
    final end = filter.periodEnd ?? journalDayEnd(DateTime.now());
    emit(const OperationJournalLoading());
    try {
      final raw = await _repository.getOperations(start, end);
      final kept = applyJournalFilter(raw, filter);

      final opening = await _repository.getOpeningBalancesByType(
        start,
        where: filter.matchesScope,
      );
      final openingCash = opening['cash']!;
      final openingSales = opening['sales']!;
      final openingStock = opening['stock']!;

      final processed = _withBalances(
        kept,
        openingCash,
        openingSales,
        openingStock,
      );
      // Ordre demandé par le filtre (le calcul des soldes, lui, est
      // chronologique).
      final ordered = applyJournalFilter(processed, filter);
      final grouped = groupBy(ordered, _localDay);

      emit(
        OperationJournalLoaded(
          operations: ordered,
          filteredOperations: ordered,
          startDate: start,
          endDate: end,
          groupedOperations: grouped,
          openingBalance: openingCash.values.fold(0.0, (a, b) => a + b),
          openingBalancesByCurrency: openingCash,
          openingCashBalances: openingCash,
          openingSalesBalances: openingSales,
          openingStockValues: openingStock,
          dailyBalances: _computeDailyBalances(
            grouped,
            openingCash,
            openingSales,
            openingStock,
          ),
          activeFilter: filter,
        ),
      );
    } catch (e) {
      emit(
        OperationJournalError(
          'Erreur de chargement des opérations: ${e.toString()}',
        ),
      );
    }
  }

  // Handler for adding a new journal entry
  Future<void> _onAddOperationJournalEntry(
    AddOperationJournalEntry event,
    Emitter<OperationJournalState> emit,
  ) async {
    try {
      await _repository.addOperation(event.entry);
      await _load(emit);
    } catch (e) {
      if (kDebugMode) {
        print('Erreur lors de l\'ajout à l\'operation journal: $e');
      }
      emit(
        OperationJournalError(
          'Erreur lors de l\'ajout de l\'entrée au journal: ${e.toString()}',
        ),
      );
    }
  }

  // Handler for adding multiple journal entries
  Future<void> _onAddMultipleOperationJournalEntries(
    AddMultipleOperationJournalEntries event,
    Emitter<OperationJournalState> emit,
  ) async {
    if (event.entries.isEmpty) return;
    try {
      await _repository.addOperationEntries(event.entries);
      await _load(emit);
    } catch (e) {
      emit(
        OperationJournalError(
          'Erreur lors de l\'ajout des entrées au journal: ${e.toString()}',
        ),
      );
      Future.delayed(const Duration(seconds: 2), () {
        if (!isClosed) add(const RefreshJournal());
      });
    }
  }

  /// Soldes d'ouverture et de fermeture de chaque journée (jours locaux).
  Map<DateTime, DailyBalanceSummary> _computeDailyBalances(
    Map<DateTime, List<OperationJournalEntry>> groupedOperations,
    Map<String, double> openingCashBalances,
    Map<String, double> openingSalesBalances,
    Map<String, double> openingStockValues,
  ) {
    final dailyBalances = <DateTime, DailyBalanceSummary>{};
    final sortedDays = groupedOperations.keys.toList()..sort();

    final runningCash = Map<String, double>.from(openingCashBalances);
    final runningSales = Map<String, double>.from(openingSalesBalances);
    final runningStock = Map<String, double>.from(openingStockValues);

    for (final day in sortedDays) {
      final dayOpeningCash = Map<String, double>.from(runningCash);
      final dayOpeningSales = Map<String, double>.from(runningSales);
      final dayOpeningStock = Map<String, double>.from(runningStock);

      for (final op in groupedOperations[day] ?? const <OperationJournalEntry>[]) {
        final currencyCode = op.currencyCode ?? 'CDF';
        if (op.type.impactsCash) {
          runningCash[currencyCode] =
              (runningCash[currencyCode] ?? 0.0) + op.amount;
        } else if (op.type.isSalesOperation) {
          runningSales[currencyCode] =
              (runningSales[currencyCode] ?? 0.0) + op.amount;
        } else if (op.type.impactsStock) {
          runningStock[currencyCode] =
              (runningStock[currencyCode] ?? 0.0) + op.amount;
        }
      }

      dailyBalances[day] = DailyBalanceSummary(
        openingCash: dayOpeningCash,
        closingCash: Map<String, double>.from(runningCash),
        openingSales: dayOpeningSales,
        closingSales: Map<String, double>.from(runningSales),
        openingStock: dayOpeningStock,
        closingStock: Map<String, double>.from(runningStock),
      );
    }

    return dailyBalances;
  }

  /// Soldes courants par devise et débit/crédit, dans l'ordre chronologique.
  List<OperationJournalEntry> _withBalances(
    List<OperationJournalEntry> operations,
    Map<String, double> openingCashBalances,
    Map<String, double> openingSalesBalances,
    Map<String, double> openingStockValues,
  ) {
    final cash = Map<String, double>.from(openingCashBalances)
      ..putIfAbsent('CDF', () => 0.0)
      ..putIfAbsent('USD', () => 0.0);
    final sales = Map<String, double>.from(openingSalesBalances);
    final stock = Map<String, double>.from(openingStockValues);
    double total = cash.values.fold(0.0, (a, b) => a + b); // DEPRECATED

    final sorted = List<OperationJournalEntry>.from(operations)
      ..sort((a, b) => a.date.compareTo(b.date));

    return [
      for (final op in sorted)
        () {
          final currencyCode = op.currencyCode ?? 'CDF';
          double? cashBalance;
          double? salesBalance;
          double? stockValue;
          if (op.type.impactsCash) {
            cash[currencyCode] = (cash[currencyCode] ?? 0.0) + op.amount;
            cashBalance = cash[currencyCode];
            total += op.amount;
          } else if (op.type.isSalesOperation) {
            sales[currencyCode] = (sales[currencyCode] ?? 0.0) + op.amount;
            salesBalance = sales[currencyCode];
          } else if (op.type.impactsStock) {
            stock[currencyCode] = (stock[currencyCode] ?? 0.0) + op.amount;
            stockValue = stock[currencyCode];
          }
          return op.copyWith(
            isDebit: op.amount < 0,
            isCredit: op.amount > 0,
            balanceAfter: total, // DEPRECATED
            balancesByCurrency: Map<String, double>.from(cash), // DEPRECATED
            cashBalance: cashBalance,
            salesBalance: salesBalance,
            stockValue: stockValue,
            cashBalancesByCurrency: Map<String, double>.from(cash),
            salesBalancesByCurrency: Map<String, double>.from(sales),
            stockValuesByCurrency: Map<String, double>.from(stock),
          );
        }(),
    ];
  }
}
