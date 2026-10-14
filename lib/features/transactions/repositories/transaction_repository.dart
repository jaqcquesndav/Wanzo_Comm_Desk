import 'package:hive/hive.dart';
import 'package:uuid/uuid.dart';
import '../models/transaction.dart';
import '../../expenses/repositories/expense_repository.dart';
import '../../expenses/models/expense.dart';
import '../../../core/enums/currency_enum.dart';
import '../../../core/services/currency_service.dart';

/// Repository pour la gestion des transactions financières
class TransactionRepository {
  static const _transactionsBoxName = 'transactions';
  late final Box<Transaction> _transactionsBox;
  final _uuid = const Uuid();
  final ExpenseRepository? _expenseRepository; // Dépendance optionnelle

  TransactionRepository({ExpenseRepository? expenseRepository})
    : _expenseRepository = expenseRepository;

  /// Initialisation du repository
  Future<void> init() async {
    // Ensure Hive is properly initialized with adapters before opening box
    if (!Hive.isAdapterRegistered(10)) {
      try {
        // Add adapter registration here if needed
        // For now, we'll assume it's registered in hive_setup.dart
      } catch (e) {
        print('Error registering Transaction adapter: $e');
      }
    }

    try {
      _transactionsBox = await Hive.openBox<Transaction>(_transactionsBoxName);
    } catch (e) {
      // Handle box opening error
      print('Error opening transactions box: $e');
      // Try to delete corrupted box if it exists
      await Hive.deleteBoxFromDisk(_transactionsBoxName);
      // Retry opening
      _transactionsBox = await Hive.openBox<Transaction>(_transactionsBoxName);
    }
  }

  /// Récupérer les transactions pour une date donnée
  Future<List<Transaction>> getTransactionsForDate(DateTime date) async {
    final startOfDay = DateTime(date.year, date.month, date.day);
    final endOfDay = DateTime(date.year, date.month, date.day, 23, 59, 59);
    return _transactionsBox.values
        .where((t) => t.date.isAfter(startOfDay) && t.date.isBefore(endOfDay))
        .toList();
  }

  /// Récupérer le nombre de transactions pour une date donnée
  Future<int> getTransactionCountForDate(DateTime date) async {
    final transactionsOnDate = await getTransactionsForDate(date);
    return transactionsOnDate.length;
  }

  /// Ajouter une nouvelle transaction
  Future<Transaction> addTransaction(Transaction transaction) async {
    final newTransactionId = _uuid.v4();
    final newTransaction = transaction.copyWith(id: newTransactionId);

    await _transactionsBox.put(newTransaction.id, newTransaction);
    return newTransaction;
  }

  /// Récupérer les transactions entre deux dates
  Future<List<Transaction>> getTransactionsByDateRange(
    DateTime startDate,
    DateTime endDate,
  ) async {
    return _transactionsBox.values
        .where(
          (t) =>
              t.date.isAfter(startDate) &&
              t.date.isBefore(endDate.add(const Duration(days: 1))),
        )
        .toList();
  }

  /// Récupérer une transaction par son ID
  Future<Transaction?> getTransactionById(String id) async {
    return _transactionsBox.get(id);
  }

  /// Mettre à jour une transaction
  Future<Transaction> updateTransaction(Transaction transaction) async {
    await _transactionsBox.put(transaction.id, transaction);
    return transaction;
  }

  /// Supprimer une transaction
  Future<void> deleteTransaction(String id) async {
    await _transactionsBox.delete(id);
  }

  /// Total des dépenses d'une période, consolidé en CDF : chaque montant est
  /// converti avec SA devise (et le taux figé de la dépense s'il existe)
  /// avant d'être additionné. [currencyService] : taux de la société, sinon
  /// les taux enregistrés localement.
  Future<double> getTotalExpensesForDateRange(
    DateTime startDate,
    DateTime endDate, {
    CurrencyService? currencyService,
  }) async {
    try {
      final rates = currencyService ?? await _loadLocalRates();

      // If expense repository is provided, use it directly for more accurate data
      if (_expenseRepository != null) {
        final expenses = await _expenseRepository.getExpensesByDateRange(
          startDate,
          endDate,
        );
        double total = 0.0;
        for (final expense in expenses) {
          total += _expenseInCdf(expense, rates);
        }
        return total;
      }

      // Fallback to using transactions if expense repository is not available
      final transactions = await getTransactionsByDateRange(startDate, endDate);
      double total = 0.0;
      for (final transaction in transactions) {
        if (transaction.isExpense) {
          total += _amountInCdf(transaction.amount, transaction.currency, rates);
        }
      }
      return total;
    } catch (e) {
      print('Error calculating total expenses: $e');
      // Return 0 as a safe fallback in case of error
      return 0.0;
    }
  }

  /// Taux enregistrés localement (repli quand aucun service n'est fourni).
  Future<CurrencyService> _loadLocalRates() async {
    final local = CurrencyService();
    await local.loadSettings();
    return local;
  }

  /// Montant ramené en CDF avec le taux de SA devise ; devise inconnue exclue
  /// (0) plutôt qu'additionnée telle quelle.
  double _amountInCdf(double amount, String? code, CurrencyService rates) {
    final currency = _currencyOfCode(code);
    if (currency == null) return 0.0;
    return rates.convertToCdf(amount, currency);
  }

  /// Dépense ramenée en CDF : taux figé de la dépense s'il existe, sinon taux
  /// configuré de SA devise.
  double _expenseInCdf(Expense expense, CurrencyService rates) {
    final currency = _currencyOfCode(expense.currencyCode);
    if (currency == Currency.CDF) return expense.amount;
    final frozenRate = expense.exchangeRate;
    // 1.0 est la valeur par défaut, pas un vrai taux d'une devise étrangère
    if (frozenRate != null && frozenRate > 1.0) {
      return expense.amount * frozenRate;
    }
    return _amountInCdf(expense.amount, expense.currencyCode, rates);
  }

  /// Vider le cache local des transactions (à utiliser lors du changement de business unit)
  Future<void> clearLocalCache() async {
    await _transactionsBox.clear();
    print('Cache local des transactions vidé');
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
