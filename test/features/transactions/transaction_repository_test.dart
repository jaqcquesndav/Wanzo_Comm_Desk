import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:mocktail/mocktail.dart';
import 'package:wanzo/core/services/currency_service.dart';
import 'package:wanzo/features/transactions/repositories/transaction_repository.dart';
import 'package:wanzo/features/expenses/repositories/expense_repository.dart';
import 'package:wanzo/features/expenses/models/expense.dart';

class MockExpenseRepository extends Mock implements ExpenseRepository {}

void main() {
  final debut = DateTime(2025, 6, 1);
  final fin = DateTime(2025, 6, 7);
  // Taux par défaut (sans préférences enregistrées) : 1 USD = 2800 CDF.
  final taux = CurrencyService();

  group('TransactionRepository.getTotalExpensesForDateRange', () {
    late MockExpenseRepository depenses;

    setUp(() => depenses = MockExpenseRepository());

    test('additionne les dépenses, chacune ramenée en CDF', () async {
      when(() => depenses.getExpensesByDateRange(debut, fin)).thenAnswer(
        (_) async => [
          Expense(
            id: '1',
            amount: 1000,
            date: DateTime(2025, 6, 3),
            category: ExpenseCategory.rent,
            motif: 'Loyer',
          ),
          Expense(
            id: '2',
            amount: 2,
            date: DateTime(2025, 6, 5),
            category: ExpenseCategory.utilities,
            motif: 'Electricite',
            currencyCode: 'USD',
          ),
        ],
      );
      final repo = TransactionRepository(expenseRepository: depenses);

      final total = await repo.getTotalExpensesForDateRange(
        debut,
        fin,
        currencyService: taux,
      );

      expect(total, 1000 + 2 * 2800);
    });

    test('une erreur de lecture rend 0, jamais une exception', () async {
      when(
        () => depenses.getExpensesByDateRange(debut, fin),
      ).thenThrow(Exception('Database error'));
      final repo = TransactionRepository(expenseRepository: depenses);

      final total = await repo.getTotalExpensesForDateRange(
        debut,
        fin,
        currencyService: taux,
      );

      expect(total, 0.0);
    });

    test('sans dépôt de dépenses : repli sur les transactions locales', () async {
      final dossier = await Directory.systemTemp.createTemp('transactions_');
      Hive.init(dossier.path);
      addTearDown(() async {
        await Hive.close();
        await dossier.delete(recursive: true);
      });
      final repo = TransactionRepository();
      await repo.init();

      final total = await repo.getTotalExpensesForDateRange(
        debut,
        fin,
        currencyService: taux,
      );

      expect(total, 0.0);
    });
  });
}
