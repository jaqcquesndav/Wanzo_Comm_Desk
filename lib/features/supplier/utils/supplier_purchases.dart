import '../../../core/utils/currency_formatter.dart';
import '../../expenses/models/expense.dart';
import '../../expenses/repositories/expense_repository.dart';

/// Achats auprès d'un fournisseur, tirés de ses dépenses : un total par
/// devise (jamais additionnées entre elles) et la date du dernier achat.
///
/// Source unique de la fiche et de la liste. Les champs `totalPurchases` et
/// `lastPurchaseDate` du fournisseur ne sont tenus à jour nulle part (ni
/// ici ni sur le serveur) : ils ne sont pas affichés.
class SupplierPurchases {
  final Map<String, double> parDevise;
  final DateTime? dernierAchat;

  /// Total ramené en CDF au taux figé de chaque dépense (classement). Une
  /// dépense étrangère sans taux en est exclue, jamais comptée au taux 1.
  final double totalCdf;

  const SupplierPurchases(this.parDevise, this.dernierAchat, [this.totalCdf = 0]);

  factory SupplierPurchases.fromExpenses(Iterable<Expense> depenses) {
    final parDevise = <String, double>{};
    DateTime? dernier;
    double totalCdf = 0;
    for (final e in depenses) {
      final code = e.effectiveCurrencyCode;
      parDevise[code] = (parDevise[code] ?? 0) + e.amount;
      final taux = e.exchangeRate;
      if (code.toUpperCase() == 'CDF') {
        totalCdf += e.amount;
      } else if (taux != null && taux > 0) {
        totalCdf += e.amount * taux;
      }
      if (dernier == null || e.date.isAfter(dernier)) dernier = e.date;
    }
    return SupplierPurchases(parDevise, dernier, totalCdf);
  }

  static Future<SupplierPurchases> load(
    ExpenseRepository depenses,
    String supplierId,
  ) async =>
      SupplierPurchases.fromExpenses(
        await depenses.getExpensesBySupplier(supplierId),
      );

  /// Totaux formatés, un par devise ; aucun achat : 0 CDF.
  String totalLabel({String separator = '\n'}) => parDevise.isEmpty
      ? formatCurrency(0, 'CDF')
      : parDevise.entries
          .map((entry) => formatCurrency(entry.value, entry.key))
          .join(separator);
}
