import '../models/service_item.dart';

/// Catégories de véhicules d'un garage, utilisées comme COLONNES de tarif.
///
/// Un garage ne facture pas une prestation à un prix unique : il la facture
/// selon ce qu'il répare. Une révision moteur n'a pas le même prix sur une
/// voiture et sur un poids lourd. La grille du garage est donc un tableau à
/// deux entrées : une ligne par prestation, une colonne par catégorie.
///
/// Le modèle des services porte déjà cette grille sans rien changer : chaque
/// prestation est un service, chaque colonne un palier de prix. Ce référentiel
/// sert à ce que les colonnes portent le MÊME code partout, faute de quoi
/// « VOITURE » ici et « Voiture » là deviennent deux colonnes différentes et
/// plus rien ne se compare.
class GarageVehicleCategory {
  /// Code stable, écrit sur la ligne de vente.
  final String code;

  /// Libellé montré à l'écran et sur le ticket.
  final String label;

  /// Aide à la reconnaissance sur le terrain.
  final String hint;

  const GarageVehicleCategory({
    required this.code,
    required this.label,
    required this.hint,
  });

  /// Colonne de tarif vide : la prestation ne s'applique pas à cette
  /// catégorie, ou son prix n'est pas encore fixé.
  ServicePriceTier toTier({double priceCdf = 0, bool isDefault = false}) =>
      ServicePriceTier(
        code: code,
        label: label,
        priceCdf: priceCdf,
        isDefault: isDefault,
        description: hint,
      );
}

/// Les catégories du barème garage, dans l'ordre du plus lourd au plus léger.
///
/// Cette liste correspond aux barèmes utilisés en RDC, où les types de camions
/// sont désignés par leur marque, FUSO et CANTER, plutôt que par un tonnage.
const List<GarageVehicleCategory> kGarageVehicleCategories = [
  GarageVehicleCategory(
    code: 'poids_lourd',
    label: 'Poids lourd',
    hint: 'Camion, remorque, benne',
  ),
  GarageVehicleCategory(
    code: 'poids_moyen',
    label: 'Poids moyen',
    hint: 'Camion porteur intermédiaire',
  ),
  GarageVehicleCategory(
    code: 'fuso',
    label: 'Fuso',
    hint: 'Camion léger Mitsubishi Fuso',
  ),
  GarageVehicleCategory(
    code: 'canter',
    label: 'Canter',
    hint: 'Camionnette Canter',
  ),
  GarageVehicleCategory(
    code: 'camionnette',
    label: 'Camionnette',
    hint: 'Utilitaire, pick-up',
  ),
  GarageVehicleCategory(
    code: 'jeep_4x4',
    label: '4x4 Jeep',
    hint: 'Tout-terrain courant',
  ),
  GarageVehicleCategory(
    code: 'jeep_4x4_speciaux',
    label: '4x4 spéciaux',
    hint: 'Tout-terrain lourd ou blindé',
  ),
  GarageVehicleCategory(
    code: 'voiture',
    label: 'Voiture',
    hint: 'Berline, citadine',
  ),
  GarageVehicleCategory(
    code: 'voiture_plus_40',
    label: 'Voiture > 40',
    hint: 'Véhicule de forte cylindrée ou haut de gamme',
  ),
];

/// Retrouve une catégorie par son code.
GarageVehicleCategory? garageCategoryByCode(String code) {
  for (final c in kGarageVehicleCategories) {
    if (c.code == code) return c;
  }
  return null;
}

/// Prestations courantes d'un garage mécanique, dans l'ordre d'un barème.
/// Servent d'amorçage à la grille : l'utilisateur retire ce qu'il ne fait pas.
const List<String> kGarageStandardWorks = [
  'Moteur révision',
  'Demi-révision',
  'Travaux culasse',
  'Allumage et mise au point',
  'Travaux sur les joints',
  'Remplacer moteur et boîte',
  'Boîte et révision',
  'Remplacer disque',
  'Révision boîte',
  'Pont avant et arrière',
  'Réglage différentiel',
  'Travaux trompette',
  'Travaux arbre de transmission',
  'Travaux sur moyeu',
  'Suspension',
  'Remplacement amortisseur',
  'Remplacement semi-axe',
  'Contrôle de bruit',
  'Révision avant et arrière',
  'Tubes et soudure',
  'Échappement',
  'Carrosserie',
  'Châssis',
];
