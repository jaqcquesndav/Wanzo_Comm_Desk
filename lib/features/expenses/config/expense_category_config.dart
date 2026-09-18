import '../../../core/modules/activity_mode.dart';
import '../models/expense.dart';

/// Catégories de dépense pertinentes selon le métier, et sous-catégories.
///
/// Le formulaire proposait les vingt-cinq catégories à tout le monde : un salon
/// devait faire défiler « Production et Fabrication » ou « Recherche et
/// Développement » pour trouver « Salaires ». On garde l'énumération, source
/// unique des libellés et des icônes, mais on ne montre que ce qui parle au
/// métier, avec un repli explicite vers la liste complète.
///
/// Même intention que [ProductCategoryConfig] pour le stock : filtrer d'abord,
/// préciser ensuite avec une sous-catégorie.
class ExpenseCategoryConfig {
  ExpenseCategoryConfig._();

  /// Le socle commun : ce que toute entreprise paie, quel que soit son métier.
  static const List<ExpenseCategory> _common = [
    ExpenseCategory.rent,
    ExpenseCategory.utilities,
    ExpenseCategory.salaries,
    ExpenseCategory.supplies,
    ExpenseCategory.transport,
    ExpenseCategory.maintenance,
    ExpenseCategory.taxes,
    ExpenseCategory.communication,
  ];

  /// Ce que le métier ajoute au socle, dans l'ordre où il y pense.
  static const Map<ActivityMode, List<ExpenseCategory>> _byMode = {
    ActivityMode.retail: [
      ExpenseCategory.inventory,
      ExpenseCategory.equipment,
      ExpenseCategory.advertising,
      ExpenseCategory.insurance,
    ],
    ActivityMode.restaurant: [
      ExpenseCategory.inventory,
      ExpenseCategory.equipment,
      ExpenseCategory.fuel,
      ExpenseCategory.advertising,
    ],
    ActivityMode.hotel: [
      ExpenseCategory.inventory,
      ExpenseCategory.equipment,
      ExpenseCategory.insurance,
      ExpenseCategory.advertising,
    ],
    ActivityMode.services: [
      ExpenseCategory.equipment,
      ExpenseCategory.software,
      ExpenseCategory.consulting,
      ExpenseCategory.travel,
    ],
    ActivityMode.atelier: [
      ExpenseCategory.inventory,
      ExpenseCategory.equipment,
      ExpenseCategory.manufacturing,
    ],
    ActivityMode.atelierMaintenance: [
      ExpenseCategory.inventory,
      ExpenseCategory.equipment,
      ExpenseCategory.training,
    ],
    ActivityMode.salon: [
      ExpenseCategory.inventory,
      ExpenseCategory.equipment,
      ExpenseCategory.advertising,
    ],
    ActivityMode.imprimerie: [
      ExpenseCategory.inventory,
      ExpenseCategory.equipment,
      ExpenseCategory.software,
      ExpenseCategory.manufacturing,
    ],
    ActivityMode.pressing: [
      ExpenseCategory.inventory,
      ExpenseCategory.equipment,
    ],
    ActivityMode.garage: [
      ExpenseCategory.inventory,
      ExpenseCategory.equipment,
      ExpenseCategory.fuel,
      ExpenseCategory.insurance,
    ],
  };

  /// Catégories proposées d'emblée pour un métier. « Autre » ferme toujours la
  /// liste : c'est la porte de sortie quand rien ne colle.
  static List<ExpenseCategory> forMode(ActivityMode mode) {
    final specific = _byMode[mode] ?? const <ExpenseCategory>[];
    final seen = <ExpenseCategory>{};
    final result = <ExpenseCategory>[];
    for (final c in [..._common, ...specific]) {
      if (seen.add(c)) result.add(c);
    }
    result.add(ExpenseCategory.other);
    return result;
  }

  /// Toutes les catégories, pour qui veut sortir de la liste courte.
  static List<ExpenseCategory> get all => ExpenseCategory.values.toList();

  /// Sous-catégories d'une catégorie : le détail que l'exploitant écrirait de
  /// toute façon dans le motif, proposé d'un tap pour que les rapports
  /// regroupent au lieu d'accumuler des libellés uniques.
  static List<String> subcategoriesFor(ExpenseCategory category) {
    return _subcategories[category] ?? const ['Autre'];
  }

  static const Map<ExpenseCategory, List<String>> _subcategories = {
    ExpenseCategory.rent: [
      'Loyer du local',
      'Loyer entrepôt',
      'Charges locatives',
      'Caution',
      'Autre',
    ],
    ExpenseCategory.utilities: [
      'Électricité (SNEL)',
      'Eau (REGIDESO)',
      'Groupe électrogène',
      'Gaz',
      'Enlèvement des ordures',
      'Autre',
    ],
    ExpenseCategory.salaries: [
      'Salaire mensuel',
      'Journalier',
      'Avance sur salaire',
      // Un salon avance de l'argent à son coiffeur : c'est une sortie de fonds
      // qui se retient ensuite sur ses commissions.
      'Avance prestataire',
      'Prime',
      'Cotisations sociales (CNSS)',
      'Autre',
    ],
    ExpenseCategory.supplies: [
      'Emballages',
      'Produits d\'entretien',
      'Petit matériel',
      'Autre',
    ],
    ExpenseCategory.transport: [
      'Taxi, moto',
      'Livraison',
      'Entretien véhicule',
      'Péage, parking',
      'Autre',
    ],
    ExpenseCategory.maintenance: [
      'Réparation équipement',
      'Entretien du local',
      'Pièces de rechange',
      'Contrat de maintenance',
      'Autre',
    ],
    ExpenseCategory.taxes: [
      'Patente',
      'Impôt sur le revenu',
      'TVA',
      'Taxe communale',
      'Autre',
    ],
    ExpenseCategory.communication: [
      'Forfait téléphone',
      'Internet',
      'Crédit de communication',
      'Autre',
    ],
    ExpenseCategory.inventory: [
      'Achat de marchandises',
      'Matières premières',
      'Boissons',
      'Produits d\'exploitation',
      'Transport sur achats',
      'Autre',
    ],
    ExpenseCategory.equipment: [
      'Achat de matériel',
      'Mobilier',
      'Informatique',
      'Outillage',
      'Autre',
    ],
    ExpenseCategory.fuel: [
      'Carburant véhicule',
      'Carburant groupe',
      'Gaz de cuisson',
      'Lubrifiants',
      'Autre',
    ],
    ExpenseCategory.advertising: [
      'Affiches, banderoles',
      'Publicité en ligne',
      'Radio, télévision',
      'Autre',
    ],
    ExpenseCategory.marketing: [
      'Promotion',
      'Événement',
      'Échantillons',
      'Autre',
    ],
    ExpenseCategory.insurance: [
      'Assurance du local',
      'Assurance véhicule',
      'Assurance santé',
      'Autre',
    ],
    ExpenseCategory.loan: [
      'Échéance de prêt',
      'Intérêts',
      'Frais bancaires',
      'Autre',
    ],
    ExpenseCategory.office: [
      'Papeterie',
      'Cartouches, impression',
      'Mobilier de bureau',
      'Autre',
    ],
    ExpenseCategory.training: [
      'Formation du personnel',
      'Certification',
      'Documentation',
      'Autre',
    ],
    ExpenseCategory.travel: [
      'Transport',
      'Hébergement',
      'Restauration en mission',
      'Autre',
    ],
    ExpenseCategory.software: [
      'Abonnement logiciel',
      'Licence',
      'Hébergement, nom de domaine',
      'Autre',
    ],
    ExpenseCategory.legal: [
      'Honoraires avocat',
      'Notaire',
      'Frais de dossier',
      'Autre',
    ],
    ExpenseCategory.manufacturing: [
      'Sous-traitance',
      'Consommables de production',
      'Énergie de production',
      'Autre',
    ],
    ExpenseCategory.consulting: [
      'Honoraires comptable',
      'Conseil',
      'Audit',
      'Autre',
    ],
    ExpenseCategory.research: [
      'Prototypage',
      'Étude de marché',
      'Autre',
    ],
    ExpenseCategory.entertainment: [
      'Réception client',
      'Cadeau',
      'Autre',
    ],
    ExpenseCategory.other: [
      'Autre',
    ],
  };
}
