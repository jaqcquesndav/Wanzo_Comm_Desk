import '../../../core/models/api_response.dart';
import '../../../core/services/logging_service.dart';
import '../models/dashboard_data.dart';
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

      // Assembler les données du Dashboard
      final dashboardData = DashboardData(
        salesTodayCdf: salesTodayCdf,
        salesTodayUsd: salesTodayUsd,
        clientsServedToday: clientsServedToday,
        receivables: receivables,
        expenses: expenses,
        expensesCdf: expensesCdf,
        expensesUsd: expensesUsd,
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
}
