/// Référentiel véhicules pour le mode garage : marques, modèles courants en
/// RDC et pièces fréquentes. PROPOSITIONS d'autocomplétion : l'utilisateur
/// peut toujours saisir une valeur absente de ces listes.
class VehicleCatalog {
  VehicleCatalog._();

  /// Marques et leurs modèles les plus rencontrés (ordre = fréquence estimée).
  static const Map<String, List<String>> models = {
    'Toyota': ['Land Cruiser', 'Prado', 'Hilux', 'Fortuner', 'RAV4', 'Corolla', 'Camry', 'Yaris', 'Hiace', 'Coaster', 'Avensis', 'Harrier', 'Wish', 'Noah', 'Ractis', 'Vitz', 'IST', 'Mark X', 'Crown', 'Dyna'],
    'Nissan': ['Patrol', 'Navara', 'X-Trail', 'Qashqai', 'Sunny', 'Almera', 'Tiida', 'Note', 'March', 'Hardbody', 'Urvan', 'Civilian', 'Juke', 'Pathfinder'],
    'Mitsubishi': ['Pajero', 'L200', 'Outlander', 'Lancer', 'Canter', 'Fuso', 'ASX', 'Montero'],
    'Hyundai': ['Tucson', 'Santa Fe', 'Elantra', 'Accent', 'Sonata', 'i10', 'i20', 'H1', 'H100', 'Creta', 'Kona'],
    'Kia': ['Sportage', 'Sorento', 'Rio', 'Picanto', 'Cerato', 'Optima', 'Carnival', 'Seltos'],
    'Mercedes-Benz': ['Classe C', 'Classe E', 'Classe S', 'ML', 'GLE', 'GLK', 'Sprinter', 'Vito', 'Actros', 'Atego', 'Classe A', 'Classe G'],
    'BMW': ['Série 3', 'Série 5', 'Série 7', 'X1', 'X3', 'X5', 'X6'],
    'Suzuki': ['Vitara', 'Grand Vitara', 'Swift', 'Alto', 'Jimny', 'Ertiga', 'Dzire', 'Carry'],
    'Honda': ['CR-V', 'Civic', 'Accord', 'Fit', 'HR-V', 'Pilot'],
    'Ford': ['Ranger', 'Everest', 'Focus', 'Fiesta', 'Explorer', 'Transit', 'F-150'],
    'Isuzu': ['D-Max', 'MU-X', 'NPR', 'NQR', 'FRR', 'Trooper'],
    'Volkswagen': ['Golf', 'Polo', 'Passat', 'Tiguan', 'Touareg', 'Amarok', 'Jetta'],
    'Peugeot': ['206', '207', '208', '307', '308', '3008', '406', '407', '508', 'Partner', 'Boxer'],
    'Renault': ['Duster', 'Logan', 'Sandero', 'Clio', 'Mégane', 'Kangoo', 'Master'],
    'Land Rover': ['Defender', 'Discovery', 'Range Rover', 'Range Rover Sport', 'Evoque', 'Freelander'],
    'Jeep': ['Wrangler', 'Grand Cherokee', 'Cherokee', 'Compass'],
    'Chevrolet': ['Cruze', 'Aveo', 'Spark', 'Captiva', 'Trailblazer', 'Silverado'],
    'Mazda': ['CX-5', 'Demio', 'Axela', 'BT-50', 'Mazda 3', 'Mazda 6'],
    'Lexus': ['LX', 'GX', 'RX', 'ES', 'IS'],
    'Daihatsu': ['Terios', 'Hijet', 'Mira'],
    'Iveco': ['Daily', 'Eurocargo', 'Trakker'],
    'MAN': ['TGS', 'TGX', 'TGM'],
    'Scania': ['P-series', 'R-series', 'G-series'],
    'Volvo': ['XC60', 'XC90', 'FH', 'FM'],
    'Tata': ['Xenon', 'LPT', 'Indica'],
    'Mahindra': ['Scorpio', 'Bolero', 'Pik-Up'],
    'Chery': ['Tiggo', 'QQ'],
    'Haval': ['H6', 'Jolion'],
    'TVS': ['Star', 'HLX', 'Apache', 'King'],
    'Bajaj': ['Boxer', 'Pulsar', 'RE'],
    'Haojue': ['HJ125', 'HJ150', 'DK150'],
    'Yamaha': ['AG 100', 'Crux', 'YBR 125', 'DT 125'],
    'Honda Moto': ['CG 125', 'Ace 125', 'XL 125'],
    'Lifan': ['LF125', 'LF150'],
  };

  static List<String> get brands => models.keys.toList();

  static List<String> modelsFor(String? brand) {
    if (brand == null) return const [];
    for (final entry in models.entries) {
      if (entry.key.toLowerCase() == brand.trim().toLowerCase()) return entry.value;
    }
    return const [];
  }

  static const List<String> fuelTypes = ['Essence', 'Diesel', 'Hybride', 'Électrique', 'GPL'];

  static const List<String> transmissions = ['Manuelle', 'Automatique', 'Semi-automatique'];

  static const List<String> bodyTypes = ['Berline', 'SUV / 4x4', 'Pick-up', 'Minibus', 'Camion', 'Utilitaire', 'Moto', 'Tricycle', 'Bus', 'Engin'];

  static const List<String> colors = ['Blanc', 'Noir', 'Gris', 'Argent', 'Bleu', 'Rouge', 'Vert', 'Beige', 'Marron', 'Jaune', 'Orange'];

  /// Pièces et consommables fréquents (autocomplétion des pièces remplacées).
  static const List<String> parts = [
    'Filtre à huile', 'Filtre à air', 'Filtre à carburant', 'Filtre d\'habitacle', 'Huile moteur', 'Huile de boîte',
    'Liquide de frein', 'Liquide de refroidissement', 'Plaquettes de frein avant', 'Plaquettes de frein arrière',
    'Disques de frein', 'Tambours', 'Mâchoires', 'Batterie', 'Alternateur', 'Démarreur', 'Bougies', 'Bobine d\'allumage',
    'Courroie de distribution', 'Courroie d\'accessoires', 'Pompe à eau', 'Thermostat', 'Radiateur', 'Durite',
    'Amortisseur avant', 'Amortisseur arrière', 'Rotule', 'Biellette', 'Triangle de suspension', 'Silentbloc',
    'Roulement de roue', 'Cardan', 'Embrayage (kit)', 'Volant moteur', 'Pneu', 'Jante', 'Pare-brise', 'Rétroviseur',
    'Phare', 'Feu arrière', 'Ampoule', 'Essuie-glace', 'Compresseur de climatisation', 'Condenseur', 'Gaz réfrigérant',
    'Pot d\'échappement', 'Catalyseur', 'Injecteur', 'Pompe à injection', 'Turbo', 'Joint de culasse', 'Culasse',
    'Pare-chocs avant', 'Pare-chocs arrière', 'Capot', 'Aile', 'Portière', 'Peinture',
  ];
}
