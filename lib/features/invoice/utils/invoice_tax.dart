/// Règle unique de la TVA sur les pièces de vente (facture A4, reçu PDF,
/// ticket POS, proforma). Ce fichier est IDENTIQUE dans toutes les apps
/// Wanzo (Boutique, Comm_Desk, Assets, Production, AVEC) : une seule décision
/// d'affichage, un seul montant.
///
/// Deux questions séparées :
/// 1. CALCUL et COMPTABILISATION : ils suivent le régime fiscal (source de
///    vérité accounting, propagé à gestion par Kafka, exposé aux apps par
///    `isTaxSubject`). NORMAL : assujetti, TVA RDC collectée et comptabilisée.
///    SMT et FORFAITAIRE : exonérés, aucune TVA.
/// 2. AFFICHAGE : il suit le réglage « Afficher les taxes sur les factures »
///    (`Settings.showTaxes`).
///
/// PROBLÈME RÉSOLU : depuis le 14 oct. les pièces n'imprimaient la TVA que si
/// la vente portait un `taxAmount` enregistré. Or le serveur ne l'enregistre
/// que si l'app l'envoie avec le HT (seul Comm_Desk le fait) : pour presque
/// toutes les ventes il vaut NULL, alors que la comptabilité, elle, extrait
/// bien 16 % du TTC (compte de TVA collectée crédité). La TVA comptabilisée
/// n'apparaissait donc plus sur la facture.
///
/// RÈGLE : le montant imprimé est celui que la comptabilité enregistre
/// (miroir de `AccountingDataBuilder.calculateAmountsFromSale`, service
/// gestion), jamais une estimation locale. Aucune TVA facturée qui ne serait
/// pas comptabilisée, aucune TVA comptabilisée absente de la facture.
library;

/// Taux de TVA RDC appliqué par la comptabilité aux ventes d'un assujetti
/// quand la vente ne porte pas son propre HT (`DEFAULT_TAX_RATE` du service
/// gestion).
const double tvaRateRdc = 16.0;

/// Mention imprimée pour une entreprise non assujettie qui affiche les taxes.
/// ASCII seulement : elle sort aussi sur les imprimantes thermiques.
const String tvaNotApplicableMention =
    'TVA non applicable, entreprise non assujettie';

/// Ce que la pièce montre au sujet de la TVA.
enum InvoiceTaxMode {
  /// Affichage désactivé : aucune ligne ni mention de TVA (inchangé).
  hidden,

  /// Assujetti (régime NORMAL), affichage activé : Total HT, TVA, TTC.
  charged,

  /// Non assujetti (SMT, FORFAITAIRE), affichage activé : mention
  /// [tvaNotApplicableMention], aucun montant de TVA, total inchangé.
  /// Une ligne « TVA 0 % » laisserait croire à une opération taxable au taux
  /// zéro (cas des exportations) et à une TVA déductible pour le client.
  notApplicable,
}

/// Décision d'affichage : le réglage décide SI la TVA apparaît, le régime
/// décide COMMENT (montant ou mention).
InvoiceTaxMode invoiceTaxMode({
  required bool showTaxes,
  required bool isTaxSubject,
}) {
  if (!showTaxes) return InvoiceTaxMode.hidden;
  return isTaxSubject ? InvoiceTaxMode.charged : InvoiceTaxMode.notApplicable;
}

/// Taux de TVA d'une ligne de vente pour le CALCUL (HT et TVA envoyés au
/// serveur par les apps qui les transmettent) : le régime et le taux du
/// produit, jamais le réglage d'affichage.
double saleLineTaxRate({required bool isTaxSubject, double? productRate}) {
  if (!isTaxSubject) return 0;
  if (productRate != null && productRate > 0) return productRate;
  return tvaRateRdc;
}

/// TVA d'une vente telle que la comptabilité l'enregistre, en CDF.
///
/// - Non assujetti : 0.
/// - Vente portant son HT (envoyé par l'app, figé par le serveur) : la TVA
///   figée sur la vente (TTC moins HT à défaut).
/// - Sinon (cas général) : TVA RDC extraite du TTC, les prix étant TVA
///   incluse : TTC x 16 / 116.
///
/// Un `taxAmount` local sans HT est ignoré : il n'est pas transmis au
/// serveur, qui comptabilise alors la TVA extraite du TTC.
double accountedSaleTaxCdf({
  required bool isTaxSubject,
  required double totalTtcCdf,
  double? amountHtCdf,
  double? taxAmountCdf,
}) {
  if (!isTaxSubject) return 0;
  final ht = amountHtCdf ?? 0;
  if (ht > 0) {
    final tva = taxAmountCdf ?? (totalTtcCdf - ht);
    return tva > 0 ? tva : 0;
  }
  if (totalTtcCdf <= 0) return 0;
  return totalTtcCdf - totalTtcCdf / (1 + tvaRateRdc / 100);
}
