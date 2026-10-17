import 'package:flutter_test/flutter_test.dart';
import 'package:wanzo/features/dashboard/models/operation_journal_entry.dart';
import 'package:wanzo/features/dashboard/services/dashboard_api_service.dart';

/// Agrégation de trésorerie du tableau de bord : multi-devises, caisse
/// comptée une seule fois, dernier solde pris par date.
void main() {
  const usdRate = 2800.0;
  double toCdf(OperationJournalEntry e) =>
      (e.currencyCode ?? 'CDF') == 'USD' ? e.amount * usdRate : e.amount;

  OperationJournalEntry entry({
    required String id,
    required DateTime date,
    required OperationType type,
    required double amount,
    String currency = 'CDF',
    Map<String, double>? cashBalances,
  }) {
    return OperationJournalEntry(
      id: id,
      date: date,
      description: id,
      type: type,
      amount: amount,
      currencyCode: currency,
      isDebit: amount < 0,
      isCredit: amount > 0,
      // ignore: deprecated_member_use_from_same_package
      balanceAfter: 0,
      cashBalancesByCurrency: cashBalances,
    );
  }

  final now = DateTime(2026, 10, 17, 15);
  final today = DateTime(2026, 10, 17, 10);

  test('une vente au comptant et son encaissement ne comptent qu\'une fois '
      'en caisse', () {
    final result = DashboardApiService.computeCashFlow(
      [
        // La vente (chiffre d'affaires) et l'encaissement (caisse) sont deux
        // lignes du journal pour la même transaction.
        entry(
          id: 'vente',
          date: today,
          type: OperationType.saleCash,
          amount: 50000,
        ),
        entry(
          id: 'encaissement',
          date: today,
          type: OperationType.cashIn,
          amount: 50000,
        ),
      ],
      now,
      toCdf,
    );

    expect(result['cashInTodayCdf'], 50000);
    expect(result['cashBalanceCdf'], 50000);
  });

  test('chaque devise garde ses propres flux, consolidés en CDF par catégorie',
      () {
    final result = DashboardApiService.computeCashFlow(
      [
        entry(
          id: 'in-cdf',
          date: today,
          type: OperationType.cashIn,
          amount: 10000,
        ),
        entry(
          id: 'in-usd',
          date: today,
          type: OperationType.cashIn,
          amount: 20,
          currency: 'USD',
        ),
        entry(
          id: 'out-usd',
          date: today,
          type: OperationType.cashOut,
          amount: -5,
          currency: 'USD',
        ),
      ],
      now,
      toCdf,
    );

    expect(result['cashInTodayCdf'], 10000);
    expect(result['cashInTodayUsd'], 20);
    expect(result['cashOutTodayUsd'], 5);
    expect(result['cashBalanceUsd'], 15);
    // 10 000 + 20 x 2800 - 5 x 2800 : jamais 10 000 + 20 - 5.
    expect(result['exploitationFlowsCdf'], 10000 + 15 * usdRate);
  });

  test('une devise inconnue n\'est jamais rangée sous USD', () {
    final result = DashboardApiService.computeCashFlow(
      [
        entry(
          id: 'eur',
          date: today,
          type: OperationType.cashIn,
          amount: 100,
          currency: 'EUR',
        ),
      ],
      now,
      (_) => 0,
    );
    expect(result['cashInTodayUsd'], 0);
    expect(result['cashBalanceUsd'], 0);
  });

  test('une vente à crédit ne touche ni la caisse ni les flux d\'exploitation',
      () {
    final result = DashboardApiService.computeCashFlow(
      [
        entry(
          id: 'credit',
          date: today,
          type: OperationType.saleCredit,
          amount: 30000,
        ),
      ],
      now,
      toCdf,
    );
    expect(result['cashBalanceCdf'], 0);
    expect(result['exploitationFlowsCdf'], 0);
  });

  test('le solde final est le dernier instantané PAR DATE, pas le dernier '
      'inséré', () {
    final result = DashboardApiService.computeCashFlow(
      [
        // Ordre d'insertion inversé (synchro) : le plus récent arrive d'abord.
        entry(
          id: 'recent',
          date: DateTime(2026, 10, 16),
          type: OperationType.cashIn,
          amount: 1000,
          cashBalances: {'CDF': 9000, 'USD': 40},
        ),
        entry(
          id: 'ancien',
          date: DateTime(2026, 10, 1),
          type: OperationType.cashIn,
          amount: 8000,
          cashBalances: {'CDF': 8000, 'USD': 40},
        ),
      ],
      now,
      toCdf,
    );
    expect(result['cashBalanceCdf'], 9000);
    expect(result['cashBalanceUsd'], 40);
    // Aucune opération du jour.
    expect(result['cashInTodayCdf'], 0);
  });

  test('journal vide : tout à zéro', () {
    final result = DashboardApiService.computeCashFlow(const [], now, toCdf);
    expect(result.values.every((v) => v == 0), isTrue);
  });
}
