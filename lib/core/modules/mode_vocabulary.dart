import 'package:wanzo/core/services/business_context_service.dart';

import 'activity_mode.dart';

/// Vocabulaire du journal des opérations et de ses états de sortie selon le
/// mode d'activité : un garage parle d'interventions et de pièces, un pressing
/// de dépôts et de consommables, une boutique de ventes et de stock.
///
/// Même principe que [EntityVocabularyService] : aucune logique ne change,
/// seuls les mots affichés (écrans, filtres, PDF, CSV) sont remplacés.
class ModeVocabulary {
  /// Une opération de vente : « Vente », « Prestation », « Intervention »...
  final String sale;

  /// Pluriel, pour les onglets et filtres : « Ventes », « Interventions »...
  final String sales;

  /// Titre de l'indicateur de produits encaissés : « Revenus », « Recettes »...
  final String revenue;

  /// Le stock au sens du métier : « Stock », « Pièces », « Consommables »...
  final String stock;

  /// Un article stocké : « Produit », « Pièce », « Consommable »...
  final String item;

  /// Genre grammatical de [sale], pour les libellés construits (« Ajouter une
  /// prestation », « Ajouter un séjour »). Féminin par défaut : c'est le cas de
  /// la vente, de la commande, de la prestation et de l'intervention.
  final bool saleIsFeminine;

  const ModeVocabulary({
    required this.sale,
    required this.sales,
    required this.revenue,
    required this.stock,
    required this.item,
    this.saleIsFeminine = true,
  });

  /// « Ajouter une prestation », « Ajouter un dépôt » : libellé de création
  /// accordé, pour les écrans qui enregistrent une opération de recette.
  String get addSaleLabel =>
      'Ajouter ${saleIsFeminine ? 'une' : 'un'} ${sale.toLowerCase()}';

  /// « Mouvements de stock », « Mouvements de pièces »...
  String get stockMovements => 'Mouvements de ${stock.toLowerCase()}';

  /// « Entrée stock » / « Sortie stock » (libellés des types d'opération).
  String get stockIn => 'Entrée ${stock.toLowerCase()}';
  String get stockOut => 'Sortie ${stock.toLowerCase()}';

  static const ModeVocabulary _retail = ModeVocabulary(
      sale: 'Vente', sales: 'Ventes', revenue: 'Revenus', stock: 'Stock', item: 'Produit');

  static ModeVocabulary of(ActivityMode mode) {
    switch (mode) {
      case ActivityMode.restaurant:
        return const ModeVocabulary(
            sale: 'Commande', sales: 'Commandes', revenue: 'Recettes', stock: 'Stock', item: 'Article');
      case ActivityMode.hotel:
        return const ModeVocabulary(
            sale: 'Séjour', sales: 'Séjours', revenue: 'Revenus', stock: 'Stock', item: 'Article', saleIsFeminine: false);
      case ActivityMode.services:
      case ActivityMode.salon:
        return const ModeVocabulary(
            sale: 'Prestation', sales: 'Prestations', revenue: 'Revenus', stock: 'Stock', item: 'Produit');
      case ActivityMode.atelier:
        return const ModeVocabulary(
            sale: 'Commande', sales: 'Commandes', revenue: 'Revenus', stock: 'Intrants', item: 'Intrant');
      case ActivityMode.atelierMaintenance:
      case ActivityMode.garage:
        return const ModeVocabulary(
            sale: 'Intervention', sales: 'Interventions', revenue: 'Revenus', stock: 'Pièces', item: 'Pièce');
      case ActivityMode.imprimerie:
        return const ModeVocabulary(
            sale: 'Travail', sales: 'Travaux', revenue: 'Revenus', stock: 'Consommables', item: 'Consommable', saleIsFeminine: false);
      case ActivityMode.pressing:
        return const ModeVocabulary(
            sale: 'Dépôt', sales: 'Dépôts', revenue: 'Revenus', stock: 'Consommables', item: 'Consommable', saleIsFeminine: false);
      case ActivityMode.retail:
        return _retail;
    }
  }

  /// Vocabulaire du mode courant de l'appareil (contexte business résolu).
  static ModeVocabulary get current => of(BusinessContextService().activityMode);
}
