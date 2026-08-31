import 'package:equatable/equatable.dart';

/// Parse tolérant : TypeORM renvoie les colonnes Postgres `numeric` comme des
/// CHAÎNES JSON (ex. "50.00"). Accepte donc un [num] OU une chaîne numérique.
double _numToDouble(dynamic v) =>
    v is num ? v.toDouble() : double.tryParse(v?.toString() ?? '') ?? 0;

/// Variante nullable : `null` si la valeur est absente/illisible (ne force pas 0).
double? _numToDoubleOrNull(dynamic v) =>
    v == null ? null : (v is num ? v.toDouble() : double.tryParse(v.toString()));

/// Modèle de rémunération d'un coiffeur/coiffeuse.
///
/// - [commission] : payé au pourcentage du chiffre qu'il/elle réalise
///   (prestations + éventuellement produits de détail).
/// - [boothRent] : loue son fauteuil (« booth rent ») pour un montant fixe ;
///   dans ce cas la commission est généralement nulle et le salon perçoit le
///   loyer. Les deux modèles coexistent dans un même salon.
enum StylistPayModel {
  commission,
  boothRent,
}

extension StylistPayModelX on StylistPayModel {
  /// Valeur stable persistée/échangée avec le backend (`commission` /
  /// `booth_rent`).
  String get apiValue {
    switch (this) {
      case StylistPayModel.commission:
        return 'commission';
      case StylistPayModel.boothRent:
        return 'booth_rent';
    }
  }

  /// Libellé affiché (FR).
  String get label {
    switch (this) {
      case StylistPayModel.commission:
        return 'Commission';
      case StylistPayModel.boothRent:
        return 'Location de fauteuil';
    }
  }

  /// Résout un modèle depuis sa valeur stockée (repli : `commission`).
  static StylistPayModel fromValue(String? value) {
    switch (value) {
      case 'booth_rent':
        return StylistPayModel.boothRent;
      case 'commission':
      default:
        return StylistPayModel.commission;
    }
  }
}

/// Un COIFFEUR / COIFFEUSE (exécutant d'une prestation), avec son modèle de
/// rémunération. Persisté côté backend (`/salon/stylists`) — multi-appareils,
/// suivi de performance sur la durée. La liste locale sert de cache d'affichage
/// et de repli hors-ligne.
///
/// Aligné sur le contrat backend
/// `{id,name,phone?,payModel(commission|booth_rent),serviceCommissionPct,retailCommissionPct,boothRentAmount?,active}`.
class Stylist extends Equatable {
  final String id;
  final String name;
  final String? phone;
  final StylistPayModel payModel;

  /// Taux de commission par défaut sur les PRESTATIONS, en pourcentage
  /// (ex. 30.0). Utilisé si la prestation n'a pas d'override.
  final double serviceCommissionPct;

  /// Taux de commission sur les PRODUITS de détail vendus par ce coiffeur, en
  /// pourcentage.
  final double retailCommissionPct;

  /// Montant du loyer de fauteuil (mode `booth_rent`) — facultatif.
  final double? boothRentAmount;

  /// Coiffeur actif (proposable à la sélection sur un ticket).
  final bool active;

  const Stylist({
    required this.id,
    required this.name,
    this.phone,
    this.payModel = StylistPayModel.commission,
    this.serviceCommissionPct = 0,
    this.retailCommissionPct = 0,
    this.boothRentAmount,
    this.active = true,
  });

  Stylist copyWith({
    String? id,
    String? name,
    String? phone,
    StylistPayModel? payModel,
    double? serviceCommissionPct,
    double? retailCommissionPct,
    double? boothRentAmount,
    bool? active,
  }) {
    return Stylist(
      id: id ?? this.id,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      payModel: payModel ?? this.payModel,
      serviceCommissionPct: serviceCommissionPct ?? this.serviceCommissionPct,
      retailCommissionPct: retailCommissionPct ?? this.retailCommissionPct,
      boothRentAmount: boothRentAmount ?? this.boothRentAmount,
      active: active ?? this.active,
    );
  }

  /// Charge utile de création/mise à jour (sans l'`id`, attribué par le
  /// backend à la création).
  Map<String, dynamic> toCreateJson() => {
    'name': name,
    if (phone != null && phone!.isNotEmpty) 'phone': phone,
    'payModel': payModel.apiValue,
    'serviceCommissionPct': serviceCommissionPct,
    'retailCommissionPct': retailCommissionPct,
    if (boothRentAmount != null) 'boothRentAmount': boothRentAmount,
    'active': active,
  };

  factory Stylist.fromJson(Map<String, dynamic> json) {
    return Stylist(
      id: (json['id'] ?? '').toString(),
      name: (json['name'] ?? '').toString(),
      phone: json['phone'] as String?,
      payModel: StylistPayModelX.fromValue(json['payModel'] as String?),
      serviceCommissionPct: _numToDouble(json['serviceCommissionPct']),
      retailCommissionPct: _numToDouble(json['retailCommissionPct']),
      boothRentAmount: _numToDoubleOrNull(json['boothRentAmount']),
      active: json['active'] as bool? ?? true,
    );
  }

  @override
  List<Object?> get props => [
    id,
    name,
    phone,
    payModel,
    serviceCommissionPct,
    retailCommissionPct,
    boothRentAmount,
    active,
  ];
}
