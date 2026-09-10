import '../../sales/models/sale.dart';
import '../../sales/models/sale_item.dart';

/// Règle de présentation monétaire d'un état de sortie (facture, reçu, ticket).
///
/// PROBLÈME RÉSOLU : une facture en USD affichait le bon total mais des prix
/// unitaires d'ordre CDF sous le symbole USD. La cause n'était pas le total,
/// elle était structurelle : le document appliquait UNE devise (celle de
/// l'en-tête, ou pire la devise d'affichage de l'app) à des montants de lignes
/// qui, eux, sont libellés dans la devise PROPRE à chaque ligne. Dès que les
/// deux diffèrent, un montant s'imprime sous le symbole d'une autre devise.
///
/// Les lignes peuvent légitimement porter une autre devise que l'en-tête :
/// le POS permet de saisir une ligne dans une devise choisie, et les chaînes
/// de facturation métier (restaurant, atelier, réservations) posent des lignes
/// de service en CDF.
///
/// RÈGLE : un état de sortie a UNE devise de présentation, et TOUT montant
/// imprimé est obtenu par conversion depuis sa base CDF, qui est la seule
/// donnée de référence. Aucun montant n'est jamais réétiqueté sans conversion.
/// Si aucun taux exploitable n'existe, le document est présenté en CDF, ce qui
/// est la lecture honnête des montants stockés, au lieu d'afficher un nombre
/// CDF sous un symbole étranger.
class InvoiceMoney {
  /// Devise de présentation du document.
  final String currencyCode;

  /// Taux figé : 1 unité de [currencyCode] = [rateToBase] CDF. Vaut 1 en CDF.
  final double rateToBase;

  const InvoiceMoney._(this.currencyCode, this.rateToBase);

  /// Déduit la devise de présentation de la VENTE elle-même, jamais de la
  /// préférence d'affichage de l'application : une facture est une pièce, elle
  /// reste libellée dans la devise de la transaction.
  factory InvoiceMoney.forSale(Sale sale) {
    final code = (sale.transactionCurrencyCode ?? 'CDF').toUpperCase();
    if (code == 'CDF') return const InvoiceMoney._('CDF', 1.0);

    var rate = sale.transactionExchangeRate ?? 0.0;

    // Repli : si le taux n'a pas été figé sur la vente, on le déduit du couple
    // de totaux déjà cohérents (base CDF et total en devise).
    final totalTx = sale.totalAmountInTransactionCurrency ?? 0.0;
    if (rate <= 0 && totalTx > 0 && sale.totalAmountInCdf > 0) {
      rate = sale.totalAmountInCdf / totalTx;
    }

    // Aucun taux exploitable : on présente en CDF plutôt que d'étiqueter des
    // montants CDF dans une devise étrangère.
    if (rate <= 0) return const InvoiceMoney._('CDF', 1.0);

    return InvoiceMoney._(code, rate);
  }

  bool get isBase => rateToBase == 1.0;

  /// Convertit un montant en base CDF vers la devise du document.
  double fromCdf(double amountInCdf) =>
      isBase ? amountInCdf : amountInCdf / rateToBase;

  /// Base CDF d'un montant de ligne. `*InCdf` est la donnée de référence ;
  /// s'il est absent (enregistrements anciens), on le reconstitue avec le taux
  /// propre à la ligne.
  double _baseOf(double amountInCdf, double amount, double lineRate) {
    if (amountInCdf > 0) return amountInCdf;
    final r = lineRate > 0 ? lineRate : 1.0;
    return amount * r;
  }

  /// Prix unitaire de la ligne, exprimé dans la devise du document.
  double lineUnit(SaleItem item) => fromCdf(
        _baseOf(item.unitPriceInCdf, item.unitPrice, item.exchangeRate),
      );

  /// Total de la ligne, exprimé dans la devise du document.
  double lineTotal(SaleItem item) => fromCdf(
        _baseOf(item.totalPriceInCdf, item.totalPrice, item.exchangeRate),
      );

  /// Somme des lignes dans la devise du document : garantit que le détail
  /// imprimé et les totaux du pied de page racontent la même histoire.
  double linesTotal(Iterable<SaleItem> items) =>
      items.fold<double>(0.0, (sum, it) => sum + lineTotal(it));
}
