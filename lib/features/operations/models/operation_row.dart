import '../../expenses/models/expense.dart';
import '../../invoice/utils/invoice_money.dart';
import '../../sales/models/sale.dart';

/// Délai de paiement par défaut (jours) d'une vente à crédit sans échéance
/// explicite : même terme que le mobile (sale_credit.dart).
const int kOperationsDefaultPaymentTermDays = 30;

/// Une ligne de la table des opérations (vente ou dépense), avec ses montants
/// déjà présentés dans la devise de SA pièce.
///
/// Règle devises : une vente est présentée dans sa devise de transaction, par
/// conversion depuis la base CDF au taux figé de la vente
/// ([InvoiceMoney.forSale]) ; sans taux exploitable elle reste en CDF. Une
/// dépense garde sa propre devise. Jamais un montant CDF sous un symbole USD.
class OperationRow {
  final Sale? sale;
  final Expense? expense;
  final DateTime date;
  final String description;

  /// Montant signé : positif pour une vente, négatif pour une dépense.
  final double amount;

  /// Montant déjà encaissé (ventes) dans la devise de la pièce.
  final double paid;
  final String currencyCode;
  final bool isOverdue;

  const OperationRow._({
    this.sale,
    this.expense,
    required this.date,
    required this.description,
    required this.amount,
    required this.paid,
    required this.currencyCode,
    required this.isOverdue,
  });

  bool get isSale => sale != null;

  factory OperationRow.fromSale(Sale sale, {DateTime? now}) {
    final money = InvoiceMoney.forSale(sale);
    return OperationRow._(
      sale: sale,
      date: sale.date,
      description: sale.customerName,
      amount: money.fromCdf(sale.totalAmountInCdf),
      paid: money.fromCdf(sale.paidAmountInCdf),
      currencyCode: money.currencyCode,
      isOverdue: isSaleOverdue(sale, now: now),
    );
  }

  factory OperationRow.fromExpense(Expense expense) {
    return OperationRow._(
      expense: expense,
      date: expense.date,
      description: expense.motif,
      amount: -expense.amount,
      paid: expense.paidAmount ?? expense.amount,
      currencyCode: expense.effectiveCurrencyCode,
      isOverdue: false,
    );
  }

  /// Ventes et dépenses fusionnées, les plus récentes d'abord.
  static List<OperationRow> merge(
    List<Sale> sales,
    List<Expense> expenses, {
    DateTime? now,
  }) {
    final rows = <OperationRow>[
      ...sales.map((s) => OperationRow.fromSale(s, now: now)),
      ...expenses.map(OperationRow.fromExpense),
    ]..sort((a, b) => b.date.compareTo(a.date));
    return rows;
  }

  /// Créance échue : vente impayée ou partielle dont l'échéance (explicite,
  /// sinon date de vente + [kOperationsDefaultPaymentTermDays]) est passée.
  static bool isSaleOverdue(Sale sale, {DateTime? now}) {
    final outstanding =
        (sale.status == SaleStatus.pending ||
            sale.status == SaleStatus.partiallyPaid) &&
        sale.remainingAmountInCdf > 0;
    if (!outstanding) return false;
    final due =
        sale.dueDate ??
        sale.date.add(const Duration(days: kOperationsDefaultPaymentTermDays));
    return (now ?? DateTime.now()).isAfter(due);
  }
}
