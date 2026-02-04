import 'package:hive/hive.dart';
import 'package:uuid/uuid.dart';
import '../models/transaction.dart';
import '../../expenses/repositories/expense_repository.dart';

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
    final newTransaction = transaction.copyWith(
      id: newTransactionId,
    );
    
    await _transactionsBox.put(newTransaction.id, newTransaction);
    return newTransaction;
  }

  /// Récupérer les transactions entre deux dates
  Future<List<Transaction>> getTransactionsByDateRange(
      DateTime startDate, DateTime endDate) async {
    return _transactionsBox.values
        .where((t) =>
            t.date.isAfter(startDate) &&
            t.date.isBefore(endDate.add(const Duration(days: 1))))
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

  // Get total expenses for a date range
  Future<double> getTotalExpensesForDateRange(
      DateTime startDate, DateTime endDate) async {
    try {      // If expense repository is provided, use it directly for more accurate data
      if (_expenseRepository != null) {
        final expenses =
            await _expenseRepository.getExpensesByDateRange(startDate, endDate);
        double total = 0.0;
        for (final expense in expenses) {
          total += expense.amount;
        }
        return total;
      }

      // Fallback to using transactions if expense repository is not available
      final transactions = await getTransactionsByDateRange(startDate, endDate);
      double total = 0.0;
      for (final transaction in transactions) {
        if (transaction.isExpense) {
          total += transaction.amount;
        }
      }
      return total;
    } catch (e) {
      print('Error calculating total expenses: $e');
      // Return 0 as a safe fallback in case of error
      return 0.0;
    }
  }
}
