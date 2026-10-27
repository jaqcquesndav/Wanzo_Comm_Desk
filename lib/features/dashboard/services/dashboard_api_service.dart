import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';
import '../../../core/enums/currency_enum.dart';
import '../../../core/models/api_response.dart';
import '../../../core/services/currency_service.dart';
import '../../../core/services/logging_service.dart';
import '../models/dashboard_data.dart';
import '../models/operation_journal_entry.dart';
import '../../sales/repositories/sales_repository.dart';
import '../../customer/repositories/customer_repository.dart';
import '../../transactions/repositories/transaction_repository.dart';
import '../../expenses/repositories/expense_repository.dart';
import '../../expenses/models/expense.dart';

/// Service API pour le Dashboard, standardisant les réponses au format ApiResponse<T>
class DashboardApiService {
  final SalesRepository _salesRepository;
  final CustomerRepository _customerRepository;
  final TransactionRepository _transactionRepository;
  final ExpenseRepository? _expenseRepository;

  /// Service de devise (taux de change local/offline). Optionnel : quand il est
  /// absent, on ne fabrique aucun taux et les montants restent séparés par devise.
  final CurrencyService? _currencyService;

  DashboardApiService({
    required SalesRepository salesRepository,
    required CustomerRepository customerRepository,
    required TransactionRepository transactionRepository,
    ExpenseRepository? expenseRepository,
    CurrencyService? currencyService,
  }) : _salesRepository = salesRepository,
       _customerRepository = customerRepository,
       _transactionRepository = transactionRepository,
       _expenseRepository = expenseRepository,
       _currencyService = currencyService;

  /// Taux enregistrés localement, chargés une fois quand aucun service de
  /// devise n'est injecté.
  CurrencyService? _fallbackRates;

  /// Service de taux à utiliser pour ramener un montant en CDF.
  Future<CurrencyService> _rates() async {
    final injected = _currencyService;
    if (injected != null) return injected;
    if (_fallbackRates == null) {
      final local = CurrencyService();
      await local.loadSettings();
      _fallbackRates = local;
    }
    return _fallbackRates!;
  }

  /// Récupère les données complètes du Dashboard pour une date spécifique
  Future<ApiResponse<DashboardData>> getDashboardData(DateTime date) async {
    try {
      // Préparer les plages de dates pour aujourd'hui
      final todayStart = DateTime(date.year, date.month, date.day);
      final todayEnd = DateTime(date.year, date.month, date.day, 23, 59, 59);

      // Récupérer les ventes du jour
      final sales = await _salesRepository.getSalesByDateRange(
        todayStart,
        todayEnd,
      );

      // Ventilation des ventes par devise à partir du modèle générique
      // (transactionCurrencyCode + totalAmountInTransactionCurrency) : USD si le
      // code vaut 'USD', CDF sinon.
      double salesTodayCdf = 0.0;
      double salesTodayUsd = 0.0;
      for (final sale in sales) {
        // Vente annulée : conservée pour la trace, hors des totaux.
        if (sale.isCancelled) continue;
        if (sale.transactionCurrencyCode == 'USD') {
          salesTodayUsd += sale.totalAmountInTransactionCurrency ?? 0.0;
        } else {
          salesTodayCdf += sale.totalAmountInCdf;
        }
      }

      // Clients servis aujourd'hui
      final clientsServedToday = await _customerRepository
          .getUniqueCustomersCountForDateRange(todayStart, todayEnd);

      // Montants à recevoir
      final receivables = await _salesRepository.getTotalReceivables();

      // Dépenses du jour : sous-totaux par devise d'origine, et total consolidé
      // en CDF où chaque dépense est convertie avec SA devise et son taux.
      final expensesSummary = await _getExpensesSummary(todayStart, todayEnd);
      final expensesCdf = expensesSummary.byCurrency['CDF'] ?? 0.0;
      final expensesUsd = expensesSummary.byCurrency['USD'] ?? 0.0;
      final expenses = expensesSummary.totalCdf;

      // Calculer les flux de trésorerie
      final cashFlowData = await _computeCashFlowData();

      // Assembler les données du Dashboard
      final dashboardData = DashboardData(
        salesTodayCdf: salesTodayCdf,
        salesTodayUsd: salesTodayUsd,
        clientsServedToday: clientsServedToday,
        receivables: receivables,
        expenses: expenses,
        expensesCdf: expensesCdf,
        expensesUsd: expensesUsd,
        cashBalanceCdf: cashFlowData['cashBalanceCdf'] ?? 0.0,
        cashBalanceUsd: cashFlowData['cashBalanceUsd'] ?? 0.0,
        exploitationFlowsCdf: cashFlowData['exploitationFlowsCdf'] ?? 0.0,
        investmentFlowsCdf: cashFlowData['investmentFlowsCdf'] ?? 0.0,
        financingFlowsCdf: cashFlowData['financingFlowsCdf'] ?? 0.0,
        cashInTodayCdf: cashFlowData['cashInTodayCdf'] ?? 0.0,
        cashOutTodayCdf: cashFlowData['cashOutTodayCdf'] ?? 0.0,
        cashInTodayUsd: cashFlowData['cashInTodayUsd'] ?? 0.0,
        cashOutTodayUsd: cashFlowData['cashOutTodayUsd'] ?? 0.0,
      );

      return ApiResponse<DashboardData>(
        success: true,
        data: dashboardData,
        message: 'Données du tableau de bord récupérées avec succès',
        statusCode: 200,
      );
    } catch (e) {
      return ApiResponse<DashboardData>(
        success: false,
        message:
            'Erreur lors de la récupération des données du tableau de bord',
        error: e.toString(),
        statusCode: 500,
      );
    }
  }

  /// Récupère uniquement les ventes du jour en CDF et USD
  Future<ApiResponse<Map<String, double>>> getSalesToday(DateTime date) async {
    try {
      final todayStart = DateTime(date.year, date.month, date.day);
      final todayEnd = DateTime(date.year, date.month, date.day, 23, 59, 59);

      final sales = await _salesRepository.getSalesByDateRange(
        todayStart,
        todayEnd,
      );

      double salesTodayCdf = 0.0;
      double salesTodayUsd = 0.0;
      for (final sale in sales) {
        // Vente annulée : conservée pour la trace, hors des totaux.
        if (sale.isCancelled) continue;
        if (sale.transactionCurrencyCode == 'USD') {
          salesTodayUsd += sale.totalAmountInTransactionCurrency ?? 0.0;
        } else {
          salesTodayCdf += sale.totalAmountInCdf;
        }
      }

      return ApiResponse<Map<String, double>>(
        success: true,
        data: {'cdf': salesTodayCdf, 'usd': salesTodayUsd},
        message: 'Ventes du jour récupérées avec succès',
        statusCode: 200,
      );
    } catch (e) {
      return ApiResponse<Map<String, double>>(
        success: false,
        message: 'Erreur lors de la récupération des ventes du jour',
        error: e.toString(),
        statusCode: 500,
      );
    }
  }

  /// Récupère le nombre de clients servis aujourd'hui
  Future<ApiResponse<int>> getClientsServedToday(DateTime date) async {
    try {
      final todayStart = DateTime(date.year, date.month, date.day);
      final todayEnd = DateTime(date.year, date.month, date.day, 23, 59, 59);

      final clientsServedToday = await _customerRepository
          .getUniqueCustomersCountForDateRange(todayStart, todayEnd);

      return ApiResponse<int>(
        success: true,
        data: clientsServedToday,
        message: 'Nombre de clients servis aujourd\'hui récupéré avec succès',
        statusCode: 200,
      );
    } catch (e) {
      return ApiResponse<int>(
        success: false,
        message: 'Erreur lors de la récupération du nombre de clients servis',
        error: e.toString(),
        statusCode: 500,
      );
    }
  }

  /// Récupère le total des montants à recevoir
  Future<ApiResponse<double>> getTotalReceivables() async {
    try {
      final receivables = await _salesRepository.getTotalReceivables();

      return ApiResponse<double>(
        success: true,
        data: receivables,
        message: 'Total des montants à recevoir récupéré avec succès',
        statusCode: 200,
      );
    } catch (e) {
      return ApiResponse<double>(
        success: false,
        message: 'Erreur lors de la récupération des montants à recevoir',
        error: e.toString(),
        statusCode: 500,
      );
    }
  }

  /// Récupère les dépenses du jour
  Future<ApiResponse<double>> getExpensesToday(DateTime date) async {
    try {
      final todayStart = DateTime(date.year, date.month, date.day);
      final todayEnd = DateTime(date.year, date.month, date.day, 23, 59, 59);

      // Total consolidé en CDF (jamais une somme brute de devises)
      final expenses =
          (await _getExpensesSummary(todayStart, todayEnd)).totalCdf;

      return ApiResponse<double>(
        success: true,
        data: expenses,
        message: 'Dépenses du jour récupérées avec succès',
        statusCode: 200,
      );
    } catch (e) {
      return ApiResponse<double>(
        success: false,
        message: 'Erreur lors de la récupération des dépenses du jour',
        error: e.toString(),
        statusCode: 500,
      );
    }
  }

  /// Dépenses d'une période : sous-totaux par devise d'origine et total
  /// consolidé en CDF (chaque dépense convertie avec sa propre devise).
  Future<({Map<String, double> byCurrency, double totalCdf})>
  _getExpensesSummary(DateTime startDate, DateTime endDate) async {
    try {
      final byCurrency = <String, double>{'CDF': 0.0, 'USD': 0.0};
      double totalCdf = 0.0;

      // Essayer d'abord avec le ExpenseRepository si disponible
      if (_expenseRepository != null) {
        final expenses = await _expenseRepository.getExpensesByDateRange(
          startDate,
          endDate,
        );
        final rates = await _rates();
        for (final expense in expenses) {
          // Dépense annulée : hors des totaux.
          if (expense.isCancelled) continue;
          final currency = (expense.currencyCode ?? 'CDF').toUpperCase();
          byCurrency[currency] = (byCurrency[currency] ?? 0.0) + expense.amount;
          totalCdf += _expenseAmountInCdf(expense, rates);
        }
        return (byCurrency: byCurrency, totalCdf: totalCdf);
      }

      // Repli sur le TransactionRepository : total consolidé en CDF avec les
      // mêmes taux
      final total = await _transactionRepository.getTotalExpensesForDateRange(
        startDate,
        endDate,
        currencyService: await _rates(),
      );
      byCurrency['CDF'] = total;
      return (byCurrency: byCurrency, totalCdf: total);
    } catch (e) {
      LoggingService.instance.error(
        'Erreur lors du calcul des dépenses',
        error: e,
      );
      // Valeur sûre en cas d'erreur
      return (
        byCurrency: <String, double>{'CDF': 0.0, 'USD': 0.0},
        totalCdf: 0.0,
      );
    }
  }

  /// Montant d'une dépense ramené en CDF : taux figé de la dépense s'il existe,
  /// sinon taux configuré de SA devise. Devise inconnue : exclue (0), jamais
  /// additionnée telle quelle.
  double _expenseAmountInCdf(Expense expense, CurrencyService rates) {
    final currency = _currencyOfCode(expense.currencyCode);
    if (currency == Currency.CDF) return expense.amount;
    final frozenRate = expense.exchangeRate;
    // 1.0 est la valeur par défaut, pas un vrai taux d'une devise étrangère
    if (frozenRate != null && frozenRate > 1.0) {
      return expense.amount * frozenRate;
    }
    if (currency == null) return 0.0;
    return rates.convertToCdf(expense.amount, currency);
  }

  /// Montant d'une opération du journal ramené en CDF avec SA devise.
  double _entryAmountInCdf(OperationJournalEntry entry, CurrencyService rates) {
    final currency = _currencyOfCode(entry.currencyCode);
    if (currency == null) return 0.0;
    return rates.convertToCdf(entry.amount, currency);
  }

  /// Calcule les données de flux de trésorerie à partir du journal d'opérations Hive
  Future<Map<String, double>> _computeCashFlowData() async {
    try {
      // IMPORTANT : la synchro écrit dans 'operation_journal_entries'
      // (cf. OperationJournalRepository). L'ancien nom 'offline_operation_journal'
      // n'était jamais alimenté → trésorerie/graphiques toujours à zéro.
      // La box est ouverte par OperationJournalRepository au démarrage ;
      // tant qu'elle ne l'est pas, la trésorerie reste à zéro.
      const boxName = 'operation_journal_entries';
      if (!Hive.isBoxOpen(boxName)) {
        return computeCashFlow(const [], DateTime.now(), (_) => 0);
      }
      final box = Hive.box<OperationJournalEntry>(boxName);
      if (box.isEmpty) return computeCashFlow(const [], DateTime.now(), (_) => 0);
      final rates = await _rates();
      return computeCashFlow(
        box.values,
        DateTime.now(),
        (entry) => _entryAmountInCdf(entry, rates),
      );
    } catch (e) {
      LoggingService.instance.error(
        'Erreur calcul flux de trésorerie',
        error: e,
      );
      return computeCashFlow(const [], DateTime.now(), (_) => 0);
    }
  }

  /// Agrégation pure de la trésorerie (testable) :
  /// - la caisse ne compte QUE les opérations qui la touchent
  ///   ([OperationType.impactsCash]) : une vente au comptant produit aussi un
  ///   encaissement, l'additionner deux fois gonflerait la caisse ;
  /// - soldes et flux du jour tenus par devise, une devise autre que CDF ou
  ///   USD n'est jamais rangée sous USD ;
  /// - flux par catégorie consolidés en CDF via [toCdf] (SA devise) ;
  /// - solde final : dernier instantané par devise PAR DATE (l'ordre
  ///   d'insertion Hive n'est pas chronologique après une synchro).
  @visibleForTesting
  static Map<String, double> computeCashFlow(
    Iterable<OperationJournalEntry> entries,
    DateTime now,
    double Function(OperationJournalEntry entry) toCdf,
  ) {
    final result = <String, double>{
      'cashBalanceCdf': 0.0,
      'cashBalanceUsd': 0.0,
      'exploitationFlowsCdf': 0.0,
      'investmentFlowsCdf': 0.0,
      'financingFlowsCdf': 0.0,
      'cashInTodayCdf': 0.0,
      'cashOutTodayCdf': 0.0,
      'cashInTodayUsd': 0.0,
      'cashOutTodayUsd': 0.0,
    };
    final todayStart = DateTime(now.year, now.month, now.day);

    double cashBalanceCdf = 0.0;
    double cashBalanceUsd = 0.0;
    OperationJournalEntry? latestSnapshot;

    for (final entry in entries) {
      final currencyCode = (entry.currencyCode ?? 'CDF').toUpperCase();
      final isCdf = currencyCode == 'CDF';
      final isUsd = currencyCode == 'USD';
      final amount = entry.amount;

      if (entry.type.impactsCash) {
        if (isCdf) {
          cashBalanceCdf += amount;
        } else if (isUsd) {
          cashBalanceUsd += amount;
        }
        final snapshot = entry.cashBalancesByCurrency;
        if (snapshot != null &&
            snapshot.isNotEmpty &&
            (latestSnapshot == null ||
                !entry.date.isBefore(latestSnapshot.date))) {
          latestSnapshot = entry;
        }
      }

      if (!entry.date.isBefore(todayStart)) {
        if (entry.type.impactsCash) {
          final key =
              amount > 0
                  ? (isCdf ? 'cashInTodayCdf' : (isUsd ? 'cashInTodayUsd' : null))
                  : (isCdf ? 'cashOutTodayCdf' : (isUsd ? 'cashOutTodayUsd' : null));
          if (key != null) result[key] = result[key]! + amount.abs();
        }

        final amountCdf = toCdf(entry);
        switch (entry.type.cashFlowCategory) {
          case CashFlowCategory.exploitation:
            result['exploitationFlowsCdf'] =
                result['exploitationFlowsCdf']! + amountCdf;
            break;
          case CashFlowCategory.investissement:
            result['investmentFlowsCdf'] =
                result['investmentFlowsCdf']! + amountCdf;
            break;
          case CashFlowCategory.financement:
            result['financingFlowsCdf'] =
                result['financingFlowsCdf']! + amountCdf;
            break;
          case CashFlowCategory.nonApplicable:
            break;
        }
      }
    }

    final snapshot = latestSnapshot?.cashBalancesByCurrency;
    if (snapshot != null) {
      cashBalanceCdf = snapshot['CDF'] ?? cashBalanceCdf;
      cashBalanceUsd = snapshot['USD'] ?? cashBalanceUsd;
    }

    result['cashBalanceCdf'] = cashBalanceCdf;
    result['cashBalanceUsd'] = cashBalanceUsd;
    return result;
  }
}

/// Devise d'un code (absent = CDF), null si inconnue.
Currency? _currencyOfCode(String? code) {
  switch ((code ?? 'CDF').trim().toUpperCase()) {
    case '':
    case 'CDF':
    case 'FC':
      return Currency.CDF;
    case 'USD':
    case r'$':
      return Currency.USD;
    case 'FCFA':
    case 'XAF':
      return Currency.FCFA;
    default:
      return null;
  }
}
