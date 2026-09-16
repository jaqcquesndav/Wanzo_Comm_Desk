import '../../../core/modules/activity_mode.dart';
import '../models/service_item.dart';
import 'garage_vehicle_categories.dart';

/// Suggestions de saisie pour le catalogue des services, par mode d'activité :
/// catégories, intitulés fréquents et paliers de prix par défaut. Ce sont des
/// PROPOSITIONS (autocomplétion) : l'utilisateur garde la saisie libre.
class ServiceSuggestions {
  ServiceSuggestions._();

  /// Paliers proposés à la création d'un service selon le mode.
  static List<ServicePriceTier> defaultTiers(ActivityMode mode) {
    switch (mode) {
      case ActivityMode.garage:
        // Un garage tarifie par CATEGORIE DE VEHICULE, pas par niveau de
        // gamme : la prestation n'a pas le meme prix sur une voiture et sur un
        // poids lourd. Les colonnes laissees vides ne sont pas enregistrees.
        return [
          for (var i = 0; i < kGarageVehicleCategories.length; i++)
            kGarageVehicleCategories[i].toTier(isDefault: i == 0),
        ];
      case ActivityMode.pressing:
        return const [
          ServicePriceTier(code: 'standard', label: 'Standard', priceCdf: 0, isDefault: true,
              description: 'Retrait sous 48 h'),
          ServicePriceTier(code: 'express', label: 'Express', priceCdf: 0,
              description: 'Retrait le jour même'),
        ];
      case ActivityMode.salon:
        return const [
          ServicePriceTier(code: 'standard', label: 'Standard', priceCdf: 0, isDefault: true),
          ServicePriceTier(code: 'premium', label: 'Premium', priceCdf: 0),
        ];
      default:
        return const [
          ServicePriceTier(code: 'standard', label: 'Standard', priceCdf: 0, isDefault: true),
        ];
    }
  }

  /// Catégories suggérées selon le mode (saisie libre possible).
  static List<String> categories(ActivityMode mode) {
    switch (mode) {
      case ActivityMode.garage:
        return const ['Entretien', 'Freinage', 'Moteur', 'Boîte et transmission', 'Suspension et direction',
          'Électricité et batterie', 'Climatisation', 'Pneumatiques', 'Carrosserie et peinture',
          'Vitrage', 'Diagnostic', 'Contrôle technique', 'Dépannage et remorquage', 'Lavage et esthétique'];
      case ActivityMode.pressing:
        return const ['Nettoyage à sec', 'Lavage', 'Repassage', 'Détachage', 'Retouche et couture',
          'Cuir et daim', 'Linge de maison', 'Tapis et rideaux', 'Teinture', 'Livraison'];
      case ActivityMode.atelier:
        return const ['Confection', 'Retouche', 'Réparation', 'Broderie', 'Cordonnerie', 'Ressemelage', 'Teinture'];
      case ActivityMode.atelierMaintenance:
        return const ['Diagnostic', 'Réparation', 'Remplacement de pièce', 'Nettoyage', 'Mise à jour logicielle',
          'Installation', 'Maintenance préventive', 'Déplacement'];
      case ActivityMode.imprimerie:
        return const ['Impression numérique', 'Offset', 'Grand format', 'Finition', 'Reliure', 'Conception graphique', 'Livraison'];
      case ActivityMode.salon:
        return const ['Coupe', 'Coiffage', 'Couleur', 'Tresses', 'Défrisage', 'Soins', 'Manucure', 'Pédicure', 'Maquillage'];
      case ActivityMode.restaurant:
        return const ['Service traiteur', 'Livraison', 'Location de salle', 'Animation'];
      case ActivityMode.hotel:
        return const ['Blanchisserie', 'Restauration', 'Transfert', 'Excursion', 'Spa'];
      case ActivityMode.services:
      case ActivityMode.retail:
        return const ['Prestation', 'Main d\'œuvre', 'Installation', 'Livraison', 'Location', 'Conseil', 'Formation', 'Maintenance'];
    }
  }

  /// Intitulés de services fréquents selon le mode (autocomplétion du nom).
  static List<String> serviceNames(ActivityMode mode) {
    switch (mode) {
      case ActivityMode.garage:
        return const ['Vidange moteur', 'Vidange + filtres', 'Révision complète', 'Remplacement plaquettes de frein',
          'Remplacement disques de frein', 'Purge de freins', 'Remplacement batterie', 'Diagnostic électronique',
          'Recharge climatisation', 'Remplacement compresseur clim', 'Parallélisme et géométrie', 'Équilibrage',
          'Montage pneus', 'Remplacement amortisseurs', 'Remplacement embrayage', 'Remplacement courroie de distribution',
          'Remplacement alternateur', 'Remplacement démarreur', 'Remplacement radiateur', 'Réparation boîte de vitesses',
          'Réfection moteur', 'Carrosserie : redressage', 'Peinture complète', 'Peinture élément', 'Remplacement pare-brise',
          'Remplacement essuie-glaces', 'Lavage complet', 'Polissage', 'Remorquage', 'Contrôle avant achat'];
      case ActivityMode.pressing:
        return const ['Chemise', 'Pantalon', 'Costume 2 pièces', 'Costume 3 pièces', 'Veste', 'Robe', 'Robe de soirée',
          'Robe de mariée', 'Jupe', 'Manteau', 'Pagne et boubou', 'Abacost', 'Cravate', 'Pull', 'Jeans', 'T-shirt',
          'Couette', 'Couverture', 'Drap', 'Rideau', 'Tapis', 'Nappe', 'Veste en cuir', 'Chaussures', 'Sac', 'Repassage seul'];
      case ActivityMode.atelier:
        return const ['Robe sur mesure', 'Costume sur mesure', 'Chemise sur mesure', 'Pantalon sur mesure', 'Boubou', 'Pagne cousu',
          'Retouche ourlet', 'Retouche taille', 'Remplacement fermeture', 'Ressemelage', 'Talon', 'Couture cuir'];
      case ActivityMode.atelierMaintenance:
        return const ['Diagnostic', 'Remplacement écran', 'Remplacement batterie', 'Réparation carte mère', 'Nettoyage interne',
          'Réinstallation système', 'Récupération de données', 'Réparation climatiseur', 'Réparation réfrigérateur',
          'Réparation groupe électrogène', 'Installation panneau solaire', 'Maintenance préventive'];
      case ActivityMode.imprimerie:
        return const ['Cartes de visite', 'Flyers', 'Affiches', 'Banderoles', 'Roll-up', 'Reliure', 'Photocopie',
          'Impression photo', 'Conception logo', 'Mise en page', 'Impression sur textile', 'Stickers'];
      case ActivityMode.salon:
        return const ['Coupe homme', 'Coupe femme', 'Brushing', 'Tresses', 'Tissage', 'Défrisage', 'Coloration',
          'Soin capillaire', 'Manucure', 'Pédicure', 'Maquillage', 'Barbe'];
      default:
        return const ['Prestation', 'Main d\'œuvre', 'Installation', 'Livraison', 'Conseil', 'Formation'];
    }
  }
}
