import 'package:equatable/equatable.dart';

/// Parse tolérant : TypeORM renvoie les colonnes Postgres `numeric` comme des
/// CHAÎNES JSON (ex. "50.00"). Accepte donc un [num] OU une chaîne numérique.
double _numToDouble(dynamic v) =>
    v is num ? v.toDouble() : double.tryParse(v?.toString() ?? '') ?? 0;

int _numToInt(dynamic v) =>
    v is num ? v.toInt() : int.tryParse(v?.toString() ?? '') ?? 0;

/// Variante nullable : `null` si la valeur est absente/illisible (ne force pas 0).
double? _numToDoubleOrNull(dynamic v) =>
    v == null ? null : (v is num ? v.toDouble() : double.tryParse(v.toString()));

int? _numToIntOrNull(dynamic v) => v == null
    ? null
    : (v is num ? v.toInt() : int.tryParse(v.toString().split('.').first));

/// Catégorie d'une PRESTATION de salon de coiffure.
///
/// Deux familles se côtoient : le PUBLIC visé (Homme / Femme / Enfant) et le
/// TYPE de geste technique (Coupe, Couleur, Coiffage, Tresses, Défrisage,
/// Soins) ainsi que la beauté des mains/pieds (Manucure / Pédicure). Sert à
/// regrouper la carte lors de la prise de ticket, exactement comme les
/// « services » (`MenuCourse`) regroupent la carte d'un restaurant.
///
/// Valeur stable persistée/échangée avec le backend via [apiValue].
enum SalonServiceCategory {
  homme,
  femme,
  enfant,
  coupe,
  couleur,
  coiffage,
  tresses,
  defrisage,
  soins,
  manucure,
  pedicure,
  autre,
}

extension SalonServiceCategoryX on SalonServiceCategory {
  /// Valeur stable persistée/échangée avec le backend (= nom de l'enum).
  String get apiValue => name;

  /// Libellé affiché (FR).
  String get label {
    switch (this) {
      case SalonServiceCategory.homme:
        return 'Homme';
      case SalonServiceCategory.femme:
        return 'Femme';
      case SalonServiceCategory.enfant:
        return 'Enfant';
      case SalonServiceCategory.coupe:
        return 'Coupe';
      case SalonServiceCategory.couleur:
        return 'Couleur';
      case SalonServiceCategory.coiffage:
        return 'Coiffage';
      case SalonServiceCategory.tresses:
        return 'Tresses';
      case SalonServiceCategory.defrisage:
        return 'Défrisage';
      case SalonServiceCategory.soins:
        return 'Soins';
      case SalonServiceCategory.manucure:
        return 'Manucure';
      case SalonServiceCategory.pedicure:
        return 'Pédicure';
      case SalonServiceCategory.autre:
        return 'Autres';
    }
  }

  /// Ordre d'affichage dans la carte (public visé d'abord, puis techniques,
  /// puis mains/pieds, puis « autres »).
  int get order {
    switch (this) {
      case SalonServiceCategory.homme:
        return 0;
      case SalonServiceCategory.femme:
        return 1;
      case SalonServiceCategory.enfant:
        return 2;
      case SalonServiceCategory.coupe:
        return 3;
      case SalonServiceCategory.couleur:
        return 4;
      case SalonServiceCategory.coiffage:
        return 5;
      case SalonServiceCategory.tresses:
        return 6;
      case SalonServiceCategory.defrisage:
        return 7;
      case SalonServiceCategory.soins:
        return 8;
      case SalonServiceCategory.manucure:
        return 9;
      case SalonServiceCategory.pedicure:
        return 10;
      case SalonServiceCategory.autre:
        return 11;
    }
  }

  /// Résout une catégorie depuis sa valeur stockée (repli sûr : `autre`).
  static SalonServiceCategory fromValue(String? value) {
    return SalonServiceCategory.values.firstWhere(
      (c) => c.name == value,
      orElse: () => SalonServiceCategory.autre,
    );
  }
}

/// Une PRESTATION (service tarifé) de la carte du salon — entité authorée
/// directement, distincte du stock : une coupe/couleur/tresses n'est pas un
/// `Product`. Persistée en JSON dans une box Hive `String` (cf.
/// `SalonServiceRepository`), comme la carte du restaurant — pas de
/// `TypeAdapter`, pas de migration Hive.
///
/// Aligné sur le contrat backend `/salon/services`
/// `{id,name,category,priceCdf,durationMinutes?,targetGender?,serviceCommissionPct?,active,position}`.
class SalonService extends Equatable {
  final String id;
  final String name;
  final SalonServiceCategory category;

  /// Prix de la prestation en CDF (base monétaire de l'app).
  final double priceCdf;

  /// Durée indicative de la prestation en minutes (facultatif) — repère de
  /// planning, non facturé au temps.
  final int? durationMinutes;

  /// Public ciblé libre (ex. « homme », « femme », « mixte ») — facultatif.
  final String? targetGender;

  /// Taux de commission SPÉCIFIQUE à cette prestation, en pourcentage (ex.
  /// 30.0). `null` = pas d'override : on retombe sur le taux de la fiche
  /// coiffeur au moment de la vente.
  final double? serviceCommissionPct;

  /// Disponible à la vente. `false` = retirée de la carte sans être supprimée.
  final bool active;

  /// Position d'affichage/tri conservée côté backend.
  final int position;

  const SalonService({
    required this.id,
    required this.name,
    required this.category,
    required this.priceCdf,
    this.durationMinutes,
    this.targetGender,
    this.serviceCommissionPct,
    this.active = true,
    this.position = 0,
  });

  SalonService copyWith({
    String? id,
    String? name,
    SalonServiceCategory? category,
    double? priceCdf,
    int? durationMinutes,
    String? targetGender,
    double? serviceCommissionPct,
    bool? active,
    int? position,
  }) {
    return SalonService(
      id: id ?? this.id,
      name: name ?? this.name,
      category: category ?? this.category,
      priceCdf: priceCdf ?? this.priceCdf,
      durationMinutes: durationMinutes ?? this.durationMinutes,
      targetGender: targetGender ?? this.targetGender,
      serviceCommissionPct: serviceCommissionPct ?? this.serviceCommissionPct,
      active: active ?? this.active,
      position: position ?? this.position,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'category': category.apiValue,
    'priceCdf': priceCdf,
    if (durationMinutes != null) 'durationMinutes': durationMinutes,
    if (targetGender != null && targetGender!.isNotEmpty)
      'targetGender': targetGender,
    if (serviceCommissionPct != null)
      'serviceCommissionPct': serviceCommissionPct,
    'active': active,
    'position': position,
  };

  factory SalonService.fromJson(Map<String, dynamic> json) {
    return SalonService(
      id: (json['id'] ?? '').toString(),
      name: (json['name'] ?? '').toString(),
      category: SalonServiceCategoryX.fromValue(json['category'] as String?),
      priceCdf: _numToDouble(json['priceCdf']),
      durationMinutes: _numToIntOrNull(json['durationMinutes']),
      targetGender: json['targetGender'] as String?,
      serviceCommissionPct: _numToDoubleOrNull(json['serviceCommissionPct']),
      active: json['active'] as bool? ?? true,
      position: _numToInt(json['position']),
    );
  }

  @override
  List<Object?> get props => [
    id,
    name,
    category,
    priceCdf,
    durationMinutes,
    targetGender,
    serviceCommissionPct,
    active,
    position,
  ];
}
