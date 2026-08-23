import 'package:hive/hive.dart';
import '../../../core/models/api_response.dart';
import '../../../core/services/logging_service.dart';
import '../models/dashboard_data.dart';
import '../models/operation_journal_entry.dart';
import '../../sales/repositories/sales_repository.dart';
import '../../customer/repositories/customer_repository.dart';
import '../../transactions/repositories/transaction_repository.dart';
import '../../expenses/repositories/expense_repository.dart';

/// Service API pour le Dashboard, standardisant les réponses au format ApiResponse<T>
class DashboardApiService {
  final SalesRepository _salesRepository;
  final CustomerRepository _customerRepository;
  final TransactionRepository _transactionRepository;
  final ExpenseRepository? _expenseRepository;

  DashboardApiService({
    required SalesRepository salesRepository,
    required CustomerRepository customerRepository,
    required TransactionRepository transactionRepository,
    ExpenseRepository? expenseRepository,
  }) : _salesRepository = salesRepository,
       _customerRepository = customerRepository,
       _transactionRepository = transactionRepository,
       _expenseRepository = expenseRepository;

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

      // Calculer les montants en CDF et USD
      double salesTodayCdf = 0.0;
      double salesTodayUsd = 0.0;
      for (final sale in sales) {
        // Ventes en CDF
        if (sale.transactionCurrencyCode == 'CDF' ||
            sale.transactionCurrencyCode == null) {
          salesTodayCdf += sale.totalAmountInCdf;
        }

        // Ventes en USD
        if (sale.transactionCurrencyCode == 'USD') {
          salesTodayUsd += sale.totalAmountInTransactionCurrency ?? 0.0;
        } else if (sale.totalAmountInUsd != null &&
            sale.transactionCurrencyCode == 'USD') {
          salesTodayUsd += sale.totalAmountInUsd!;
        }
      }

      // Clients servis aujourd'hui
      final clientsServedToday = await _customerRepository
          .getUniqueCustomersCountForDateRange(todayStart, todayEnd);

      // Montants à recevoir
      final receivables = await _salesRepository.getTotalReceivables();

      // Dépenses du jour par devise
      final expensesByDevise = await _getTotalExpensesByDevise(
        todayStart,
        todayEnd,
      );
      double expensesCdf = expensesByDevise['CDF'] ?? 0.0;
      double expensesUsd = expensesByDevise['USD'] ?? 0.0;
      double expenses =
          expensesCdf + (expensesUsd * 2800); // Total approximatif en CDF

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
        if (sale.transactionCurrencyCode == 'CDF' ||
            sale.transactionCurrencyCode == null) {
          salesTodayCdf += sale.totalAmountInCdf;
        }

        if (sale.transactionCurrencyCode == 'USD') {
          salesTodayUsd += sale.totalAmountInTransactionCurrency ?? 0.0;
        } else if (sale.totalAmountInUsd != null &&
            sale.transactionCurrencyCode == 'USD') {
          salesTodayUsd += sale.totalAmountInUsd!;
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

      final expenses = await _getTotalExpenses(todayStart, todayEnd);

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

  /// Méthode helper pour récupérer les dépenses par devise
  Future<Map<String, double>> _getTotalExpensesByDevise(
    DateTime startDate,
    DateTime endDate,
  ) async {
    try {
      Map<String, double> expensesByDevise = {'CDF': 0.0, 'USD': 0.0};

      // Essayer d'abord avec le ExpenseRepository si disponible
      if (_expenseRepository != null) {
        final expenses = await _expenseRepository.getExpensesByDateRange(
          startDate,
          endDate,
        );
        for (final expense in expenses) {
          final currency = expense.currencyCode ?? 'CDF';
          expensesByDevise[currency] =
              (expensesByDevise[currency] ?? 0.0) + expense.amount;
        }
        return expensesByDevise;
      }

      // Fallback sur le TransactionRepository - retourne uniquement le total en CDF
      final total = await _transactionRepository.getTotalExpensesForDateRange(
        startDate,
        endDate,
      );
      expensesByDevise['CDF'] = total;
      return expensesByDevise;
    } catch (e) {
      LoggingService.instance.error(
        'Erreur lors du calcul des dépenses',
        error: e,
      );
      return {'CDF': 0.0, 'USD': 0.0}; // Valeur sûre en cas d'erreur
    }
  }

  /// Méthode helper pour récupérer les dépenses, avec gestion des erreurs
  Future<double> _getTotalExpenses(DateTime startDate, DateTime endDate) async {
    try {
      // Essayer d'abord avec le ExpenseRepository si disponible
      if (_expenseRepository != null) {
        final expenses = await _expenseRepository.getExpensesByDateRange(
          startDate,
          endDate,
        );
        double total = 0.0;
        for (final expense in expenses) {
          total += expense.amount;
        }
        return total;
      }

      // Fallback sur le TransactionRepository
      return await _transactionRepository.getTotalExpensesForDateRange(
        startDate,
        endDate,
      );
    } catch (e) {
      LoggingService.instance.error(
        'Erreur lors du calcul des dépenses',
        error: e,
      );
      return 0.0; // Valeur sûre en cas d'erreur
    }
  }

  /// Calcule les données de flux de trésorerie à partir du journal d'opérations Hive
  Future<Map<String, double>> _computeCashFlowData() async {
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

    try {
      // IMPORTANT : la synchro écrit dans 'operation_journal_entries'
      // (cf. OperationJournalRepository). L'ancien nom 'offline_operation_journal'
      // n'était jamais alimenté → trésorerie/graphiques toujours à zéro.
      const boxName = 'operation_journal_entries';
      if (!Hive.isBoxOpen(boxName)) {
        return result;
      }

      final box = Hive.box<OperationJournalEntry>(boxName);
      if (box.isEmpty) return result;

      final now = DateTime.now();
      final todayStart = DateTime(now.year, now.month, now.day);

      double cashBalanceCdf = 0.0;
      double cashBalanceUsd = 0.0;

      for (final entry in box.values) {
        final isCdf = (entry.currencyCode ?? 'CDF') == 'CDF';
        final amount = entry.amount;

        // Solde de caisse global (toutes les opérations impactant la trésorerie)
        if (entry.type.impactsCash) {
          if (isCdf) {
            cashBalanceCdf += amount;
          } else {
            cashBalanceUsd += amount;
          }
        }

        // Flux du jour uniquement
        if (entry.date.isAfter(todayStart) ||
            entry.date.isAtSameMomentAs(todayStart)) {
          // Encaissements / décaissements du jour
          if (entry.type.impactsCash) {
            if (amount > 0) {
              if (isCdf) {
                result['cashInTodayCdf'] = result['cashInTodayCdf']! + amount;
              } else {
                result['cashInTodayUsd'] = result['cashInTodayUsd']! + amount;
              }
            } else {
              if (isCdf) {
                result['cashOutTodayCdf'] =
                    result['cashOutTodayCdf']! + amount.abs();
              } else {
                result['cashOutTodayUsd'] =
                    result['cashOutTodayUsd']! + amount.abs();
              }
            }
          }

          // Flux par catégorie (en CDF)
          final amountCdf =
              isCdf ? amount : amount * 2800;
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

      // Utiliser les soldes calculés depuis cashBalances si l'entry les a
      final lastEntry = box.values.last;
      if (lastEntry.cashBalancesByCurrency != null &&
          lastEntry.cashBalancesByCurrency!.isNotEmpty) {
        cashBalanceCdf =
            lastEntry.cashBalancesByCurrency!['CDF'] ?? cashBalanceCdf;
        cashBalanceUsd =
            lastEntry.cashBalancesByCurrency!['USD'] ?? cashBalanceUsd;
      }

      result['cashBalanceCdf'] = cashBalanceCdf;
      result['cashBalanceUsd'] = cashBalanceUsd;
    } catch (e) {
      LoggingService.instance.error(
        'Erreur calcul flux de trésorerie',
        error: e,
      );
    }

    return result;
  }
}
