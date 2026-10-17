import 'package:flutter_test/flutter_test.dart';
import 'package:wanzo/features/expenses/models/expense.dart';
import 'package:wanzo/features/operations/models/operation_row.dart';
import 'package:wanzo/features/sales/models/sale.dart';

/// Table des opérations : devise de la pièce, créances échues, tri.
void main() {
  final now = DateTime(2026, 10, 17);

  Sale sale({
    required String id,
    required DateTime date,
    required double totalCdf,
    double paidCdf = 0,
    SaleStatus status = SaleStatus.completed,
    String? currency,
    double? rate,
    DateTime? dueDate,
  }) {
    return Sale(
      id: id,
      date: date,
      customerName: 'Client $id',
      items: const [],
      totalAmountInCdf: totalCdf,
      paidAmountInCdf: paidCdf,
      status: status,
      transactionCurrencyCode: currency,
      transactionExchangeRate: rate,
      dueDate: dueDate,
    );
  }

  test('une vente en USD est présentée en USD depuis la base CDF au taux '
      'figé', () {
    final row = OperationRow.fromSale(
      sale(
        id: 'usd',
        date: now,
        totalCdf: 280000,
        paidCdf: 140000,
        currency: 'USD',
        rate: 2800,
      ),
      now: now,
    );
    expect(row.currencyCode, 'USD');
    expect(row.amount, 100);
    expect(row.paid, 50);
  });

  test('sans taux exploitable, la vente reste en CDF (jamais un montant CDF '
      'sous le symbole USD)', () {
    final row = OperationRow.fromSale(
      sale(id: 'x', date: now, totalCdf: 280000, currency: 'USD'),
      now: now,
    );
    expect(row.currencyCode, 'CDF');
    expect(row.amount, 280000);
  });

  test('créance échue : impayée au-delà de l\'échéance', () {
    final overdue = sale(
      id: 'a',
      date: now.subtract(const Duration(days: 45)),
      totalCdf: 1000,
      status: SaleStatus.pending,
    );
    final recent = sale(
      id: 'b',
      date: now.subtract(const Duration(days: 5)),
      totalCdf: 1000,
      status: SaleStatus.pending,
    );
    final paid = sale(
      id: 'c',
      date: now.subtract(const Duration(days: 90)),
      totalCdf: 1000,
      paidCdf: 1000,
    );
    final explicitDue = sale(
      id: 'd',
      date: now.subtract(const Duration(days: 45)),
      totalCdf: 1000,
      paidCdf: 200,
      status: SaleStatus.partiallyPaid,
      dueDate: now.add(const Duration(days: 3)),
    );
    expect(OperationRow.isSaleOverdue(overdue, now: now), isTrue);
    expect(OperationRow.isSaleOverdue(recent, now: now), isFalse);
    expect(OperationRow.isSaleOverdue(paid, now: now), isFalse);
    expect(OperationRow.isSaleOverdue(explicitDue, now: now), isFalse);
  });

  test('dépense : montant négatif dans SA devise, fusion triée par date', () {
    final expense = Expense(
      id: 'e1',
      date: DateTime(2026, 10, 10),
      motif: 'Loyer',
      amount: 50,
      category: ExpenseCategory.rent,
      currencyCode: 'USD',
    );
    final rows = OperationRow.merge(
      [sale(id: 's1', date: DateTime(2026, 10, 12), totalCdf: 5000)],
      [expense],
      now: now,
    );
    expect(rows.map((r) => r.description), ['Client s1', 'Loyer']);
    expect(rows.last.amount, -50);
    expect(rows.last.currencyCode, 'USD');
    expect(rows.last.isSale, isFalse);
  });
}
