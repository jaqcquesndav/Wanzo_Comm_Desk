/// Mode d'activité de l'entreprise — pilote l'affichage modulaire de l'app
/// (à la manière des « apps » Odoo installées par entreprise).
///
/// C'est le pendant, pour le TYPE de métier, de ce que `companyVariant`
/// (standard/coopérative) fait pour le vocabulaire : un seul axe de config,
/// résolu depuis le contexte business, qui décide quels modules sont visibles.
/// `retail` est le défaut et reproduit exactement le comportement historique.
enum ActivityMode {
  /// Boutique / commerce de détail / point de vente (défaut).
  retail,

  /// Restaurant, fast-food, bar (commandes, tables, service).
  restaurant,

  /// Hôtellerie (chambres, réservations, séjours).
  hotel,

  /// Prestations de services (interventions, forfaits).
  services,

  /// Atelier de confection (couture, cordonnerie) : fonctionne en open shop
  /// comme le restaurant — logique de commande + notion de fabrication, avec
  /// fiche client à mesures. Le mode définit l'état (workflow de production).
  atelier,

  /// Atelier de maintenance / réparation (électronique, électroménager, garage
  /// auto…) : même moteur de commandes que l'atelier, mais fiche APPAREIL/panne
  /// à la place des mensurations, et workflow diagnostic → réparation → test.
  atelierMaintenance;

  /// Vrai pour tout atelier (confection OU maintenance) — sert au gating des
  /// modules et écrans communs à l'atelier.
  bool get isAtelier =>
      this == ActivityMode.atelier || this == ActivityMode.atelierMaintenance;

  /// Valeur stable persistée/échangée avec le backend.
  String get apiValue => name;

  /// Résout un mode depuis une valeur API/persistée, avec repli sûr sur
  /// [ActivityMode.retail] (rétrocompatibilité : une valeur absente ou
  /// inconnue = comportement historique boutique).
  static ActivityMode fromString(String? value) {
    switch (value) {
      case 'restaurant':
        return ActivityMode.restaurant;
      case 'hotel':
        return ActivityMode.hotel;
      case 'services':
        return ActivityMode.services;
      case 'atelier':
        return ActivityMode.atelier;
      case 'atelierMaintenance':
        return ActivityMode.atelierMaintenance;
      case 'retail':
      default:
        return ActivityMode.retail;
    }
  }

  /// Libellé affichable (FR).
  String get label {
    switch (this) {
      case ActivityMode.retail:
        return 'Boutique / Point de vente';
      case ActivityMode.restaurant:
        return 'Restaurant / Fast-food';
      case ActivityMode.hotel:
        return 'Hôtellerie';
      case ActivityMode.services:
        return 'Services';
      case ActivityMode.atelier:
        return 'Atelier (Couture / Cordonnerie)';
      case ActivityMode.atelierMaintenance:
        return 'Atelier de Maintenance / Réparation';
    }
  }

  /// Libellé court pour le badge de mode dans l'app bar.
  String get shortLabel {
    switch (this) {
      case ActivityMode.retail:
        return 'Boutique';
      case ActivityMode.restaurant:
        return 'Resto';
      case ActivityMode.hotel:
        return 'Hôtel';
      case ActivityMode.services:
        return 'Services';
      case ActivityMode.atelier:
        return 'Atelier';
      case ActivityMode.atelierMaintenance:
        return 'Maintenance';
    }
  }

  /// Description courte pour l'écran de sélection.
  String get description {
    switch (this) {
      case ActivityMode.retail:
        return 'Ventes, stock et caisse pour un commerce de détail.';
      case ActivityMode.restaurant:
        return 'Commandes par table, service en salle et cuisine.';
      case ActivityMode.hotel:
        return 'Chambres, réservations et séjours clients.';
      case ActivityMode.services:
        return 'Prestations, interventions et forfaits.';
      case ActivityMode.atelier:
        return 'Confection sur mesure : commandes, mesures client, fabrication.';
      case ActivityMode.atelierMaintenance:
        return 'Réparation d\'appareils / garage : fiche appareil, panne, diagnostic, réparation.';
    }
  }
}
