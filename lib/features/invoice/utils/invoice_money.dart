import '../../sales/models/sale.dart';
import '../../sales/models/sale_item.dart';
import 'invoice_tax.dart';

export 'invoice_tax.dart';

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

  /// Chiffres du pied d'une pièce (ticket, reçu, facture), TOUS dérivés de la
  /// base CDF au taux figé de la vente. Avant, le total et le montant reçu
  /// étaient lus bruts (champ en devise, repli sur la base CDF) sous
  /// l'étiquette de la devise : un montant en francs sortait avec « $ » et la
  /// monnaie se calculait entre deux devises (ticket « Espèces 126 $ ;
  /// Monnaie 125,95 $ » pour un total de 0,05 $).
  ///
  /// TVA (voir invoice_tax.dart) : [showTax] est le réglage « Afficher les
  /// taxes sur les factures », [isTaxSubject] le régime fiscal. Le montant
  /// imprimé est celui que la comptabilité enregistre, jamais une estimation.
  SaleFigures figures(
    Sale sale, {
    required bool showTax,
    bool isTaxSubject = true,
  }) {
    final mode = invoiceTaxMode(showTaxes: showTax, isTaxSubject: isTaxSubject);
    final lignes = linesTotal(sale.items);
    final total = fromCdf(sale.totalAmountInCdf);
    final recu = fromCdf(sale.paidAmountInCdf);
    final tva = mode == InvoiceTaxMode.charged
        ? fromCdf(
            accountedSaleTaxCdf(
              isTaxSubject: true,
              totalTtcCdf: sale.totalAmountInCdf,
              amountHtCdf: sale.amountHT,
              taxAmountCdf: sale.taxAmount,
            ),
          )
        : 0.0;
    final remise = lignes - total;
    return SaleFigures(
      lines: lignes,
      discount: remise > _seuil ? remise : 0,
      total: total,
      tax: tva > _seuil ? tva : 0,
      taxMode: mode,
      received: recu,
      change: recu - total > _seuil ? recu - total : 0,
      due: total - recu > _seuil ? total - recu : 0,
    );
  }

  /// Écart imprimable minimal dans la devise du document.
  double get _seuil => isBase ? 0.5 : 0.005;

  /// Le prix unitaire arrondi reproduit-il la ligne ? Sinon (prix à fractions
  /// de centime) il faut l'imprimer plus précisément : « 5 x 0,01 $ = 0,04 $ ».
  bool unitIsExact(SaleItem item) {
    final pas = isBase ? 1.0 : 0.01;
    final arrondi = (lineUnit(item) / pas).round() * pas;
    return (arrondi * item.quantity - lineTotal(item)).abs() < pas / 2 + 1e-9;
  }
}

/// Pied de pièce, dans la devise du document.
class SaleFigures {
  const SaleFigures({
    required this.lines,
    required this.discount,
    required this.total,
    required this.tax,
    required this.received,
    required this.change,
    required this.due,
    this.taxMode = InvoiceTaxMode.hidden,
  });

  /// Somme des lignes, avant remise.
  final double lines;
  final double discount;

  /// Total à payer, remise déduite, TVA incluse.
  final double total;

  /// TVA incluse dans le total (0 si non assujetti ou non affichée).
  final double tax;
  final double received;
  final double change;
  final double due;

  double get totalHt => total - tax;

  /// Ce que la pièce montre de la TVA (voir invoice_tax.dart).
  final InvoiceTaxMode taxMode;

  /// Lignes « Total HT » et « TVA » à imprimer (assujetti, affichage activé).
  bool get showsTax => taxMode == InvoiceTaxMode.charged;

  /// Mention à imprimer sous le total (non assujetti, affichage activé).
  String? get taxNote => taxMode == InvoiceTaxMode.notApplicable
      ? tvaNotApplicableMention
      : null;

  /// Taux imprimé, arrondi au centième : « 16 » et non « 15.999 ».
  String get taxRateLabel {
    final taux = tax > 0 && totalHt > 0
        ? (tax / totalHt * 10000).round() / 100
        : tvaRateRdc;
    return taux == taux.roundToDouble()
        ? taux.toStringAsFixed(0)
        : taux.toStringAsFixed(2);
  }
}

/// Libellé imprimé du règlement selon le mode réel (ASCII pour les
/// imprimantes thermiques). « Especes » était imprimé pour tout paiement.
String receiptPaymentLabel(String? paymentMethod) {
  final pm = (paymentMethod ?? '').toLowerCase();
  if (pm.contains('mobile') || pm.contains('momo')) return 'Mobile Money';
  if (pm.contains('carte') || pm.contains('card')) return 'Carte';
  if (pm.contains('virement') || pm.contains('transfer')) return 'Virement';
  if (pm.contains('cheque') || pm.contains('chèque')) return 'Cheque';
  if (pm.contains('cr') && pm.contains('dit')) return 'Acompte';
  if (pm.isEmpty || pm.contains('esp') || pm == 'cash') return 'Especes';
  return 'Recu';
}
