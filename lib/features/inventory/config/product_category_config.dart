import '../models/product.dart';

/// Configuration des catégories de produits par secteur d'activité.
///
/// Filtre les catégories pertinentes selon le secteur de l'entreprise
/// et fournit les sous-catégories pour chaque catégorie principale.
class ProductCategoryConfig {
  ProductCategoryConfig._();

  /// Retourne les catégories pertinentes pour un secteur d'activité donné.
  /// [sectorId] correspond à `user.businessSectorId` (ex: 'trade', 'healthcare').
  /// Si le secteur est null ou inconnu, toutes les catégories sont retournées.
  static List<ProductCategory> categoriesForSector(String? sectorId) {
    if (sectorId == null || !_sectorCategories.containsKey(sectorId)) {
      return ProductCategory.values.toList();
    }
    final categories = _sectorCategories[sectorId]!;
    // Toujours inclure 'other' en dernier
    if (!categories.contains(ProductCategory.other)) {
      return [...categories, ProductCategory.other];
    }
    return categories;
  }

  /// Retourne les sous-catégories pour une catégorie donnée.
  /// Inclut toujours 'Autres' en fin de liste.
  static List<String> subcategoriesFor(ProductCategory category) {
    return _subcategories[category] ?? const ['Autres'];
  }

  // ─── Mapping secteur → catégories pertinentes ───

  static const Map<String, List<ProductCategory>> _sectorCategories = {
    // Santé & pharmaceutique
    'healthcare': [
      ProductCategory.pharmaceuticals,
      ProductCategory.hygiene,
      ProductCategory.cosmetics,
      ProductCategory.office,
      ProductCategory.other,
    ],
    // Commerce & distribution (accès à tout)
    'trade': ProductCategory.values,
    // Commerce de détail (accès à tout)
    'retail': ProductCategory.values,
    // Agriculture & agroalimentaire
    'agriculture': [
      ProductCategory.food,
      ProductCategory.drink,
      ProductCategory.vegetables,
      ProductCategory.fruits,
      ProductCategory.meat,
      ProductCategory.dairy,
      ProductCategory.bakery,
      ProductCategory.household,
      ProductCategory.other,
    ],
    // Tourisme & hôtellerie & restauration
    'tourism': [
      ProductCategory.food,
      ProductCategory.drink,
      ProductCategory.bakery,
      ProductCategory.dairy,
      ProductCategory.meat,
      ProductCategory.vegetables,
      ProductCategory.fruits,
      ProductCategory.household,
      ProductCategory.hygiene,
      ProductCategory.cosmetics,
      ProductCategory.other,
    ],
    // Construction & immobilier (quincaillerie)
    'construction': [
      ProductCategory.household,
      ProductCategory.electronics,
      ProductCategory.office,
      ProductCategory.clothing,
      ProductCategory.other,
    ],
    // Industrie manufacturière
    'manufacturing': [
      ProductCategory.electronics,
      ProductCategory.household,
      ProductCategory.clothing,
      ProductCategory.office,
      ProductCategory.food,
      ProductCategory.drink,
      ProductCategory.other,
    ],
    // Textile & habillement
    'textiles': [
      ProductCategory.clothing,
      ProductCategory.cosmetics,
      ProductCategory.hygiene,
      ProductCategory.household,
      ProductCategory.other,
    ],
    // Technologies de l'information
    'ict': [
      ProductCategory.electronics,
      ProductCategory.office,
      ProductCategory.other,
    ],
    // Éducation & formation
    'education': [
      ProductCategory.office,
      ProductCategory.electronics,
      ProductCategory.drink,
      ProductCategory.food,
      ProductCategory.clothing,
      ProductCategory.other,
    ],
    // Services financiers
    'finance': [
      ProductCategory.office,
      ProductCategory.electronics,
      ProductCategory.other,
    ],
    // Énergie
    'energy': [
      ProductCategory.electronics,
      ProductCategory.household,
      ProductCategory.office,
      ProductCategory.other,
    ],
    // Transport & logistique
    'transport': [
      ProductCategory.electronics,
      ProductCategory.household,
      ProductCategory.food,
      ProductCategory.drink,
      ProductCategory.office,
      ProductCategory.other,
    ],
    // Mines & ressources naturelles
    'mining': [
      ProductCategory.electronics,
      ProductCategory.household,
      ProductCategory.clothing,
      ProductCategory.food,
      ProductCategory.drink,
      ProductCategory.other,
    ],
    // Télécommunications
    'telecom': [
      ProductCategory.electronics,
      ProductCategory.office,
      ProductCategory.other,
    ],
    // Arts, médias & divertissement
    'entertainment': [
      ProductCategory.electronics,
      ProductCategory.clothing,
      ProductCategory.household,
      ProductCategory.food,
      ProductCategory.drink,
      ProductCategory.cosmetics,
      ProductCategory.office,
      ProductCategory.other,
    ],
  };

  // ─── Sous-catégories par catégorie principale ───
  // Adapté au marché africain (RDC, Afrique centrale & de l'Est)

  static const Map<ProductCategory, List<String>> _subcategories = {
    ProductCategory.food: [
      // Céréales & féculents
      'Riz (local et importé)',
      'Maïs et farine de maïs',
      'Farine de blé',
      'Farine de manioc (fufu)',
      'Semoule et couscous',
      'Pâtes alimentaires',
      'Haricots secs',
      'Lentilles et pois',
      'Arachides',
      // Huiles & matières grasses
      'Huile de palme',
      'Huile végétale (tournesol, soja)',
      'Huile d\'arachide',
      'Huile d\'olive',
      'Margarine et beurre',
      // Conserves & condiments
      'Conserves de tomates',
      'Conserves de poisson (sardines, thon)',
      'Conserves de légumes',
      'Sel de cuisine',
      'Sucre (blanc, roux)',
      'Miel naturel',
      'Épices et piments séchés',
      'Cube bouillon (Maggi, Jumbo)',
      'Sauces et vinaigre',
      'Moutarde et mayonnaise',
      // Snacks & petits déjeuners
      'Biscuits et gâteaux secs',
      'Chips et snacks salés',
      'Céréales petit-déjeuner',
      'Confitures',
      'Chocolat et confiseries',
      // Alimentation spéciale
      'Aliments pour bébé (Cérélac, Blédina)',
      'Produits surgelés',
      'Aliments séchés et fumés',
      'Produits bio et naturels',
      'Compléments alimentaires',
      'Autres',
    ],
    ProductCategory.drink: [
      // Eaux
      'Eau minérale (Ngai, Viva)',
      'Eau en sachet',
      'Eau gazeuse',
      // Jus & sodas
      'Jus de fruits naturels',
      'Jus de fruits industriels',
      'Sodas (Coca-Cola, Fanta, Pepsi)',
      'Boissons gazeuses locales',
      'Boissons énergétiques (Red Bull, Monster)',
      // Boissons chaudes
      'Café moulu et soluble (Nescafé)',
      'Thé (sachets et feuilles)',
      'Chocolat chaud (Milo, Ovaltine)',
      'Infusions et tisanes',
      // Boissons alcoolisées
      'Bières locales (Primus, Turbo King, Skol)',
      'Bières importées',
      'Vins rouges et blancs',
      'Spiritueux et liqueurs',
      'Whisky et vodka',
      // Boissons traditionnelles
      'Lotoko (alcool artisanal)',
      'Munkoyo',
      'Tangawisi (gingembre)',
      'Bissap (hibiscus)',
      'Jus de canne à sucre',
      // Laits
      'Lait UHT',
      'Lait en poudre (Nido, Gloria)',
      'Boissons lactées (yaourt à boire)',
      'Autres',
    ],
    ProductCategory.electronics: [
      // Téléphonie
      'Smartphones',
      'Téléphones basiques (Feature phones)',
      'Coques et protections écran',
      'Écouteurs et casques',
      'Cartes SIM et recharges',
      // Informatique
      'Ordinateurs portables',
      'Ordinateurs de bureau',
      'Tablettes',
      'Clés USB et disques durs',
      'Imprimantes et scanners',
      'Claviers et souris',
      'Routeurs Wi-Fi et modems',
      // Énergie & batteries
      'Batteries et piles',
      'Chargeurs et câbles USB',
      'Powerbanks',
      'Panneaux solaires',
      'Kits solaires complets',
      'Régulateurs et onduleurs',
      'Groupes électrogènes',
      'Stabilisateurs de tension',
      // Audio & vidéo
      'Enceintes Bluetooth',
      'Télévisions (LED, Smart TV)',
      'Décodeurs et antennes',
      'Haut-parleurs et amplificateurs',
      'Caméras et webcams',
      // Électroménager
      'Ventilateurs',
      'Climatiseurs',
      'Réfrigérateurs et congélateurs',
      'Mixeurs et blenders',
      'Fers à repasser',
      'Micro-ondes et fours',
      'Machine à laver',
      'Bouilloire électrique',
      // Éclairage
      'Ampoules LED',
      'Lampes rechargeables',
      'Lampes solaires',
      'Rubans LED et néons',
      'Torches et lampes de poche',
      // Surveillance & sécurité
      'Caméras de surveillance (CCTV)',
      'Systèmes d\'alarme',
      'Interphones',
      // Pièces & câblage
      'Câbles électriques',
      'Prises et interrupteurs',
      'Rallonges et multiprises',
      'Pièces détachées électroniques',
      'Autres',
    ],
    ProductCategory.clothing: [
      // Hommes
      'Chemises hommes',
      'Pantalons hommes',
      'T-shirts et polos hommes',
      'Costumes et vestes hommes',
      'Sous-vêtements hommes',
      // Femmes
      'Robes et jupes',
      'Pantalons et jeans femmes',
      'Blouses et tops femmes',
      'Sous-vêtements femmes',
      'Tenues traditionnelles femmes',
      // Enfants
      'Vêtements bébé (0-2 ans)',
      'Vêtements enfants (3-12 ans)',
      'Vêtements adolescents',
      'Uniformes scolaires',
      // Chaussures
      'Chaussures hommes (ville)',
      'Chaussures femmes (ville)',
      'Chaussures de sport (baskets)',
      'Sandales et claquettes',
      'Bottes et bottines',
      'Chaussures enfants',
      // Tissus & couture
      'Tissus wax (pagnes)',
      'Tissus en soie',
      'Tissus coton et bazin',
      'Tissus synthétiques',
      'Mercerie (fil, boutons, fermetures)',
      'Doublures et intissés',
      // Accessoires
      'Ceintures',
      'Cravates et nœuds papillon',
      'Écharpes et foulards',
      'Chapeaux et casquettes',
      'Bijoux fantaisie',
      'Montres',
      'Lunettes de soleil',
      // Sacs
      'Sacs à main femmes',
      'Sacs à dos',
      'Valises et sacs de voyage',
      'Portefeuilles',
      // Professionnel
      'Uniformes et tenues de travail',
      'Blouses médicales',
      'Tenues de sécurité (gilets, casques)',
      'Vêtements de sport',
      'Autres',
    ],
    ProductCategory.household: [
      // Quincaillerie
      'Quincaillerie générale (vis, clous, boulons)',
      'Serrures et cadenas',
      'Charnières et poignées de porte',
      'Robinets et raccords',
      'Tuyaux et plomberie (PVC, cuivre)',
      'Joints et colles',
      // Outils
      'Marteaux et tournevis',
      'Clés plates et clés à molette',
      'Perceuses et visseuses',
      'Scies et lames',
      'Mètres et niveaux',
      'Pinces et tenailles',
      'Brouettes et pelles',
      // Matériaux de construction
      'Ciment et mortier',
      'Fer à béton (barres)',
      'Tôles et gouttières',
      'Briques et parpaings',
      'Sable et gravier',
      'Carreaux et céramiques',
      'Bois de construction',
      // Peintures & finitions
      'Peintures murales (intérieur)',
      'Peintures extérieures',
      'Vernis et laques',
      'Pinceaux et rouleaux',
      'Enduits et colles murales',
      // Cuisine
      'Casseroles et marmites',
      'Poêles et woks',
      'Assiettes et couverts',
      'Verres et tasses',
      'Thermos et gourdes',
      'Bidons et jerricans',
      // Nettoyage
      'Balais et serpillières',
      'Seaux et bassines',
      'Détergents et lessives',
      'Eau de Javel (Omo, utilisation locale)',
      'Éponges et brosses',
      'Sacs poubelles',
      // Maison
      'Matelas et sommiers',
      'Draps et couvertures',
      'Rideaux et tringles',
      'Tapis et nattes',
      'Moustiquaires',
      // Plastiques & emballages
      'Seaux en plastique',
      'Bassines et cuvettes',
      'Bidons et conteneurs',
      'Sacs plastiques et sachets',
      'Film alimentaire et aluminium',
      'Autres',
    ],
    ProductCategory.hygiene: [
      // Soins corporels
      'Savons de toilette',
      'Savons liquides et gels douche',
      'Savon noir traditionnel',
      'Shampoings',
      'Après-shampoings et masques',
      'Crèmes et lotions corporelles',
      'Lait de beauté',
      'Vaseline et glycérine',
      // Soins visage
      'Crème hydratante visage',
      'Nettoyant visage',
      'Masques faciaux',
      // Soins bucco-dentaires
      'Dentifrice (Colgate, Close-Up)',
      'Brosses à dents',
      'Bains de bouche',
      // Hygiène féminine
      'Serviettes hygiéniques',
      'Tampons',
      'Protège-slips',
      'Culottes menstruelles',
      // Bébé
      'Couches bébé (Pampers, Molfix)',
      'Lingettes bébé',
      'Savon et shampoing bébé',
      'Crème change bébé',
      'Biberon et sucettes',
      // Hygiène quotidienne
      'Papier toilette',
      'Mouchoirs en papier',
      'Déodorants et anti-transpirants',
      'Rasoirs et lames',
      'Mousse et gel à raser',
      'Coton et coton-tige',
      // Désinfection
      'Gel hydroalcoolique',
      'Masques chirurgicaux',
      'Gants jetables',
      'Antiseptiques (Bétadine, alcool)',
      'Autres',
    ],
    ProductCategory.office: [
      // Papeterie courante
      'Cahiers (petit, grand format)',
      'Blocs-notes et post-it',
      'Rames de papier A4',
      'Papier cartonné et Bristol',
      'Enveloppes (toutes tailles)',
      // Écriture
      'Stylos à bille (Bic, Pilot)',
      'Stylos feutres et marqueurs',
      'Crayons et porte-mines',
      'Gommes et correcteurs (Tipp-Ex)',
      'Surligneurs',
      'Encre et recharges',
      // Classement
      'Classeurs et chemises',
      'Dossiers suspendus',
      'Pochettes plastiques transparentes',
      'Étiquettes et rubans',
      'Trombones et pinces',
      'Agrafeuses et agrafes',
      'Perforatrices',
      // Impression
      'Cartouches d\'encre',
      'Toners laser',
      'Papier photo',
      'Rubans d\'imprimante',
      // Fournitures spéciales
      'Tampons encreurs et encre',
      'Règles et équerres',
      'Ciseaux et cutters',
      'Colle et adhésif (scotch)',
      'Calculatrices',
      'Tableaux blancs et marqueurs',
      'Ardoises et craies',
      // Mobilier
      'Chaises de bureau',
      'Bureaux et tables',
      'Étagères et rangements',
      'Armoires de bureau',
      // Scolaire
      'Kits scolaires complets',
      'Sacs d\'école',
      'Trousses',
      'Géométrie (compas, rapporteurs)',
      'Autres',
    ],
    ProductCategory.cosmetics: [
      // Maquillage
      'Fond de teint et poudre',
      'Rouge à lèvres et gloss',
      'Mascara et eye-liner',
      'Fard à paupières',
      'Blush et bronzer',
      'Correcteur et anti-cernes',
      'Crayon à sourcils',
      'Démaquillant',
      // Parfumerie
      'Parfums femmes',
      'Parfums hommes',
      'Eaux de toilette',
      'Déodorants parfumés',
      'Brumes corporelles',
      // Soins capillaires
      'Défrisants et relaxers',
      'Tresses et mèches synthétiques',
      'Perruques naturelles et synthétiques',
      'Huiles capillaires (karité, coco, ricin)',
      'Gel coiffant et cire',
      'Colorations et teintures',
      'Extensions et rajouts',
      'Peignes et brosses à cheveux',
      'Sèche-cheveux et lisseurs',
      // Soins ongles
      'Vernis à ongles',
      'Dissolvant',
      'Faux ongles et capsules',
      'Kit manucure et pédicure',
      'Gel UV et résine',
      // Soins peau
      'Crèmes éclaircissantes',
      'Lotions hydratantes',
      'Huiles essentielles',
      'Beurre de karité',
      'Gommages et exfoliants',
      'Sérums et soins anti-âge',
      'Protection solaire',
      // Accessoires beauté
      'Miroirs et trousses',
      'Pinceaux maquillage',
      'Éponges beauté (Beauty Blender)',
      'Autres',
    ],
    ProductCategory.pharmaceuticals: [
      // Médicaments courants
      'Paracétamol et antidouleurs',
      'Ibuprofène et anti-inflammatoires',
      'Aspirine',
      'Antibiotiques (amoxicilline, ciprofloxacine)',
      'Antipaludéens (ACT, quinine, artéméther)',
      'Antitussifs et sirops contre la toux',
      'Antihistaminiques (allergies)',
      'Antidiarrhéiques (Lopéramide, SRO)',
      'Antiacides et anti-ulcéreux',
      'Laxatifs',
      'Vermifuges (albendazole, mébendazole)',
      // Vitamines & compléments
      'Vitamines C et multivitamines',
      'Fer et acide folique',
      'Calcium et vitamine D',
      'Zinc',
      'Omega 3 et huiles de poisson',
      'Compléments pour enfants',
      // Soins spécialisés
      'Collyres et soins ophtalmologiques',
      'Gouttes auriculaires',
      'Crèmes dermatologiques',
      'Antifongiques (crèmes et comprimés)',
      'Corticoïdes topiques',
      'Pommades et baumes',
      // Pédiatrie
      'Médicaments pédiatriques (sirops)',
      'SRO pédiatrique',
      'Vitamines enfants',
      'Zinc pédiatrique',
      // Chroniques
      'Antihypertenseurs',
      'Antidiabétiques (metformine, insuline)',
      'Antiépileptiques',
      'Antirétroviraux (ARV)',
      'Antituberculeux',
      // Matériel médical
      'Thermomètres',
      'Tensiomètres',
      'Glucomètres et bandelettes',
      'Stéthoscopes',
      'Oxymètres de pouls',
      'Nébuliseurs',
      // Premiers soins
      'Pansements et bandages',
      'Compresses stériles',
      'Sparadrap et ruban adhésif',
      'Coton hydrophile',
      'Alcool 70° et Bétadine',
      'Seringues et aiguilles',
      'Gants d\'examen (latex, nitrile)',
      // Santé reproductive
      'Préservatifs',
      'Contraceptifs oraux',
      'Tests de grossesse',
      // Diagnostic rapide
      'Tests rapides paludisme (TDR)',
      'Tests rapides VIH',
      'Tests rapides hépatite',
      'Bandelettes urinaires',
      // Produits de pharmacie traditionnelle
      'Plantes médicinales',
      'Compléments à base de plantes',
      'Miel thérapeutique',
      'Autres',
    ],
    ProductCategory.bakery: [
      // Pains
      'Pain blanc (baguette)',
      'Pain complet / blé entier',
      'Pain de mie',
      'Pain sucré',
      'Pain tradition / campagne',
      'Petit pain individuel',
      // Viennoiseries
      'Croissants',
      'Pains au chocolat',
      'Brioches',
      'Chaussons aux pommes',
      // Pâtisseries
      'Gâteau au chocolat',
      'Gâteau d\'anniversaire (sur commande)',
      'Éclairs et choux',
      'Tartes et quiches',
      'Macarons',
      'Muffins et cupcakes',
      // Spécialités locales
      'Beignets (mikate)',
      'Mandazi',
      'Chin-chin',
      'Samossa et fataya',
      'Galettes',
      // Ingrédients boulangerie
      'Farine de boulangerie (T55, T65)',
      'Levure fraîche et sèche',
      'Sucre glace et vanillé',
      'Cacao en poudre',
      'Beurre de pâtisserie',
      'Pépites de chocolat',
      'Crème pâtissière (préparation)',
      'Nappage et glaçage',
      // Biscottes & crackers
      'Biscottes',
      'Crackers et gressins',
      'Toasts et pain grillé',
      'Autres',
    ],
    ProductCategory.dairy: [
      // Lait
      'Lait frais pasteurisé',
      'Lait UHT entier',
      'Lait UHT demi-écrémé',
      'Lait en poudre entier (Nido, Gloria)',
      'Lait en poudre écrémé',
      'Lait concentré sucré (Nestlé)',
      'Lait concentré non sucré',
      'Lait de soja / végétal',
      // Yaourts
      'Yaourt nature',
      'Yaourt fruité',
      'Yaourt à boire',
      'Yaourt local artisanal',
      // Fromages
      'Fromage fondu (La Vache qui rit, Kiri)',
      'Fromage râpé (parmesan, mozzarella)',
      'Fromage en tranches',
      'Fromage local (selon région)',
      // Beurre & crème
      'Beurre frais',
      'Beurre salé / doux',
      'Margarine (Blue Band, Jadida)',
      'Crème fraîche',
      'Crème liquide',
      // Desserts lactés
      'Flan et crème dessert',
      'Glaces et sorbets',
      'Lait caillé',
      'Autres',
    ],
    ProductCategory.meat: [
      // Bœuf
      'Bœuf frais (entrecôte, filet, rumsteck)',
      'Bœuf haché',
      'Bœuf en morceaux (ragoût)',
      'Os de bœuf',
      'Foie de bœuf',
      // Volaille
      'Poulet entier',
      'Cuisses et pilons de poulet',
      'Ailes de poulet',
      'Poulet fumé',
      'Dinde et pintade',
      'Œufs de poule',
      'Œufs de caille',
      // Porc
      'Porc frais (côtelettes, rôti)',
      'Porc fumé',
      'Lard et bacon',
      // Chèvre & mouton
      'Viande de chèvre',
      'Viande de mouton (gigot, épaule)',
      'Abats de chèvre',
      // Poisson
      'Poisson frais (tilapia, capitaine, carpe)',
      'Poisson fumé (mbisi, mpiodi)',
      'Poisson salé séché',
      'Crevettes et fruits de mer',
      'Sardines fraîches',
      // Viande transformée
      'Saucisses fraîches',
      'Saucisson et salami',
      'Jambon',
      'Corned beef',
      'Viande séchée (biltong, kilishi)',
      // Abats & divers
      'Tripes et gésiers',
      'Rognons et cœur',
      'Peau de porc (couenne)',
      'Chenilles comestibles (mbinzo)',
      'Gibier (selon disponibilité)',
      'Autres',
    ],
    ProductCategory.vegetables: [
      // Légumes feuilles
      'Feuilles de manioc (pondu/sombe)',
      'Amarante (lenga-lenga)',
      'Épinards',
      'Feuilles de patate douce',
      'Laitue et salade verte',
      'Chou frisé (kale)',
      'Morelle noire (bilolo)',
      'Feuilles de citrouille',
      // Tubercules & racines
      'Manioc frais',
      'Manioc séché (cossettes)',
      'Patate douce',
      'Pomme de terre',
      'Igname',
      'Taro',
      'Gingembre frais',
      'Ail',
      // Légumes fruits
      'Tomates fraîches',
      'Oignons',
      'Oignons verts (ciboule)',
      'Piments frais (pilipili)',
      'Poivrons (vert, rouge, jaune)',
      'Aubergines',
      'Concombres',
      'Courges et courgettes',
      'Gombo (okra)',
      'Maïs frais (épis)',
      // Légumineuses fraîches
      'Haricots verts',
      'Petits pois frais',
      'Fèves',
      // Champignons
      'Champignons cultivés',
      'Champignons sauvages (selon saison)',
      // Condiments frais
      'Persil et coriandre',
      'Céleri',
      'Basilic',
      'Citronnelle',
      'Piment végétarien',
      'Autres',
    ],
    ProductCategory.fruits: [
      // Fruits tropicaux courants
      'Bananes (plantain)',
      'Bananes douces',
      'Mangues',
      'Papayes',
      'Ananas',
      'Avocats',
      'Noix de coco',
      'Goyaves',
      'Fruit de la passion (maracuja)',
      'Corossol',
      // Agrumes
      'Oranges',
      'Mandarines et clémentines',
      'Citrons et citrons verts',
      'Pamplemousses',
      // Fruits secs & transformés
      'Cacahuètes grillées',
      'Noix de cajou',
      'Dattes',
      'Raisins secs',
      'Fruits confits',
      'Chips de banane plantain',
      // Fruits importés
      'Pommes',
      'Poires',
      'Raisins frais',
      'Fraises',
      'Pastèques',
      'Melons',
      // Fruits sauvages locaux
      'Safou (prune africaine)',
      'Jujube (mabuyu)',
      'Tamarin',
      'Baobab (pulpe)',
      'Autres',
    ],
    ProductCategory.other: [
      // Jouets & cadeaux
      'Jouets pour enfants',
      'Jeux de société',
      'Cadeaux et articles souvenirs',
      'Articles de fête et décoration',
      'Bougies et bougeoirs',
      // Tabac & associés
      'Cigarettes',
      'Tabac à chiquer',
      'Briquets et allumettes',
      // Articles religieux
      'Articles religieux',
      'Bougies de prière',
      // Animaux
      'Alimentation animale (chien, chat)',
      'Alimentation volaille et bétail',
      'Produits vétérinaires',
      'Accessoires pour animaux',
      // Jardinage
      'Semences et graines',
      'Engrais et fertilisants',
      'Pesticides et insecticides',
      'Outils de jardinage',
      'Pots et jardinières',
      // Emballages & sachets
      'Sacs en papier kraft',
      'Sachets plastiques',
      'Emballages cadeaux',
      'Cartons et boîtes',
      // Services & divers
      'Cartes de recharge téléphonique',
      'Cartes cadeaux',
      'Services divers',
      'Produits artisanaux locaux',
      'Articles de voyage',
      'Parapluies et imperméables',
      'Autres',
    ],
  };
}
