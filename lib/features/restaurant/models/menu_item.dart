import 'package:equatable/equatable.dart';

import 'menu_course.dart';

/// Lecture tolerante d'un montant : le serveur renvoie ses colonnes `decimal`
/// sous forme de TEXTE (« 8000.00 »). Un `as num` strict faisait echouer la
/// lecture de CHAQUE plat, ecarte en silence : la carte du serveur arrivait
/// toujours vide dans l'app, alors que le lien de table la montrait.
double _montant(dynamic v) =>
    v is num ? v.toDouble() : double.tryParse(v?.toString() ?? '') ?? 0;

double? _montantOuNul(dynamic v) =>
    v == null ? null : (v is num ? v.toDouble() : double.tryParse(v.toString()));

/// Une OPTION de modificateur (ex. « Bien cuit », « + Fromage »).
///
/// [priceDeltaCdf] est un DELTA appliqué au prix de base du plat (0 = sans
/// surcoût, valeur positive = supplément). Persisté en JSON, comme le reste de
/// la carte — pas de `TypeAdapter`, pas d'impact backend.
class ModifierOption extends Equatable {
  final String name;

  /// Écart de prix en CDF ajouté au prix de base du plat (0 par défaut).
  final double priceDeltaCdf;

  /// Supplement tel que saisi, dans la devise de saisie du plat. Nul pour une
  /// option ancienne (saisie en CDF).
  final double? priceDeltaInInputCurrency;

  const ModifierOption({
    required this.name,
    this.priceDeltaCdf = 0,
    this.priceDeltaInInputCurrency,
  });

  ModifierOption copyWith({
    String? name,
    double? priceDeltaCdf,
    double? priceDeltaInInputCurrency,
  }) {
    return ModifierOption(
      name: name ?? this.name,
      priceDeltaCdf: priceDeltaCdf ?? this.priceDeltaCdf,
      priceDeltaInInputCurrency:
          priceDeltaInInputCurrency ?? this.priceDeltaInInputCurrency,
    );
  }

  Map<String, dynamic> toJson() => {
    'name': name,
    'priceDeltaCdf': priceDeltaCdf,
    if (priceDeltaInInputCurrency != null)
      'priceDeltaInInputCurrency': priceDeltaInInputCurrency,
  };

  factory ModifierOption.fromJson(Map<String, dynamic> json) {
    return ModifierOption(
      name: (json['name'] ?? '').toString(),
      priceDeltaCdf: _montant(json['priceDeltaCdf']),
      priceDeltaInInputCurrency: _montantOuNul(json['priceDeltaInInputCurrency']),
    );
  }

  @override
  List<Object?> get props => [name, priceDeltaCdf, priceDeltaInInputCurrency];
}

/// Un GROUPE de modificateurs à demander au client quand le plat est commandé
/// (le motif « qu'est-ce qu'on demande au client ? » à la Toast/Square).
///
/// Ex. « Cuisson » (obligatoire, choix unique : Saignant / À point / Bien cuit)
/// ou « Suppléments » (choix multiple avec surcoûts).
///
/// [required] + choix unique → un radio (une réponse imposée). Sinon des cases
/// à cocher, bornées par [minSelect] / [maxSelect] quand ils sont définis.
class ModifierGroup extends Equatable {
  final String name;

  /// Le client DOIT répondre (au moins un choix).
  final bool required;

  /// Nombre minimum de choix (null = pas de plancher explicite ; [required]
  /// impose alors au moins 1).
  final int? minSelect;

  /// Nombre maximum de choix. `1` = choix unique (radio). null = illimité.
  final int? maxSelect;

  final List<ModifierOption> options;

  const ModifierGroup({
    required this.name,
    this.required = false,
    this.minSelect,
    this.maxSelect,
    this.options = const [],
  });

  /// Choix unique quand au plus une option est sélectionnable.
  bool get isSingleChoice => maxSelect == 1;

  ModifierGroup copyWith({
    String? name,
    bool? required,
    int? minSelect,
    int? maxSelect,
    List<ModifierOption>? options,
  }) {
    return ModifierGroup(
      name: name ?? this.name,
      required: required ?? this.required,
      minSelect: minSelect ?? this.minSelect,
      maxSelect: maxSelect ?? this.maxSelect,
      options: options ?? this.options,
    );
  }

  Map<String, dynamic> toJson() => {
    'name': name,
    'required': required,
    if (minSelect != null) 'minSelect': minSelect,
    if (maxSelect != null) 'maxSelect': maxSelect,
    'options': options.map((o) => o.toJson()).toList(),
  };

  factory ModifierGroup.fromJson(Map<String, dynamic> json) {
    return ModifierGroup(
      name: (json['name'] ?? '').toString(),
      required: json['required'] as bool? ?? false,
      minSelect: (json['minSelect'] as num?)?.toInt(),
      maxSelect: (json['maxSelect'] as num?)?.toInt(),
      options: (json['options'] as List<dynamic>?)
              ?.whereType<Map>()
              .map((e) => ModifierOption.fromJson(Map<String, dynamic>.from(e)))
              .toList() ??
          const [],
    );
  }

  @override
  List<Object?> get props => [name, required, minSelect, maxSelect, options];
}

/// Un PLAT de la carte du restaurant — une entité à part entière, authoré
/// directement (nom, prix, photo, description, catégorie).
///
/// La carte n'est PAS une surcouche du stock : un plat n'est pas un `Product`.
/// C'est ce qui distingue la CARTE (ce que le client commande et qui est servi)
/// du STOCK (ingrédients, consommables). Persisté en JSON dans une box Hive
/// `String` (cf. `MenuRepository`), comme les commandes — pas de `TypeAdapter`,
/// pas de migration, pas d'impact backend.
class MenuItem extends Equatable {
  final String id;
  final String name;

  /// Prix de vente en CDF (base monétaire de l'app).
  final double priceCdf;

  /// Devise dans laquelle le prix a ete saisi, et montant saisi. Le CDF reste
  /// la base ; conserver l'origine evite qu'une carte tarifee en dollars ne
  /// derive avec le taux. Nuls pour un plat ancien (saisi en CDF).
  final String? priceInputCurrencyCode;
  final double? priceInInputCurrency;

  /// Prix tel qu'il a ete fixe, et sa devise : ce qu'on affiche sur la carte.
  /// Un plat tarife 3 USD s'affiche 3 USD, et non sa contre-valeur du jour.
  double get prixSaisi => priceInInputCurrency ?? priceCdf;
  String get deviseSaisie => priceInputCurrencyCode ?? 'CDF';
  final String? description;

  /// Chemin local de la photo du plat (image_picker → fichier copié).
  final String? photoPath;

  /// URL réseau éventuelle (Cloudinary…), prioritaire sur [photoPath] à
  /// l'affichage (cf. `SmartImage`).
  final String? photoUrl;
  final MenuCourse course;

  /// Disponible à la vente. `false` = « épuisé » (reste à la carte mais non
  /// commandable).
  final bool available;

  /// Groupes de modificateurs à demander au client à la commande (cuisson,
  /// suppléments…). Vide = plat sans options (ajout direct). Rétro-compatible :
  /// clé absente en JSON → liste vide.
  final List<ModifierGroup> modifierGroups;

  const MenuItem({
    required this.id,
    required this.name,
    required this.priceCdf,
    this.priceInputCurrencyCode,
    this.priceInInputCurrency,
    this.description,
    this.photoPath,
    this.photoUrl,
    required this.course,
    this.available = true,
    this.modifierGroups = const [],
  });

  MenuItem copyWith({
    String? id,
    String? name,
    double? priceCdf,
    String? priceInputCurrencyCode,
    double? priceInInputCurrency,
    String? description,
    String? photoPath,
    String? photoUrl,
    MenuCourse? course,
    bool? available,
    List<ModifierGroup>? modifierGroups,
  }) {
    return MenuItem(
      id: id ?? this.id,
      name: name ?? this.name,
      priceCdf: priceCdf ?? this.priceCdf,
      priceInputCurrencyCode:
          priceInputCurrencyCode ?? this.priceInputCurrencyCode,
      priceInInputCurrency: priceInInputCurrency ?? this.priceInInputCurrency,
      description: description ?? this.description,
      photoPath: photoPath ?? this.photoPath,
      photoUrl: photoUrl ?? this.photoUrl,
      course: course ?? this.course,
      available: available ?? this.available,
      modifierGroups: modifierGroups ?? this.modifierGroups,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'priceCdf': priceCdf,
    if (priceInputCurrencyCode != null)
      'priceInputCurrencyCode': priceInputCurrencyCode,
    if (priceInInputCurrency != null)
      'priceInInputCurrency': priceInInputCurrency,
    if (description != null) 'description': description,
    if (photoPath != null) 'photoPath': photoPath,
    if (photoUrl != null) 'photoUrl': photoUrl,
    'course': course.apiValue,
    'available': available,
    if (modifierGroups.isNotEmpty)
      'modifierGroups': modifierGroups.map((g) => g.toJson()).toList(),
  };

  factory MenuItem.fromJson(Map<String, dynamic> json) {
    return MenuItem(
      id: json['id'] as String,
      name: json['name'] as String,
      priceCdf: _montant(json['priceCdf']),
      priceInputCurrencyCode: json['priceInputCurrencyCode'] as String?,
      priceInInputCurrency: _montantOuNul(json['priceInInputCurrency']),
      description: json['description'] as String?,
      photoPath: json['photoPath'] as String?,
      photoUrl: json['photoUrl'] as String?,
      course: MenuCourseX.fromValue(json['course'] as String?),
      available: json['available'] as bool? ?? true,
      modifierGroups: (json['modifierGroups'] as List<dynamic>?)
              ?.whereType<Map>()
              .map((e) => ModifierGroup.fromJson(Map<String, dynamic>.from(e)))
              .toList() ??
          const [],
    );
  }

  @override
  List<Object?> get props => [
    id,
    name,
    priceCdf,
    priceInputCurrencyCode,
    priceInInputCurrency,
    description,
    photoPath,
    photoUrl,
    course,
    available,
    modifierGroups,
  ];
}
