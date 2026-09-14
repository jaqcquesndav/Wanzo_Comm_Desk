import 'package:equatable/equatable.dart';

/// Palier de prix d'un service (« Basic », « Premium », « Express »…).
/// Prix en CDF (base monétaire de l'app). L'ordre de la liste est l'ordre
/// d'affichage ; `isDefault` désigne le palier proposé en premier au ticket.
class ServicePriceTier extends Equatable {
  final String code;
  final String label;
  final double priceCdf;
  final bool isDefault;
  final String? description;

  const ServicePriceTier({
    required this.code,
    required this.label,
    required this.priceCdf,
    this.isDefault = false,
    this.description,
  });

  factory ServicePriceTier.fromJson(Map<String, dynamic> json) {
    return ServicePriceTier(
      code: (json['code'] ?? '').toString(),
      label: (json['label'] ?? '').toString(),
      priceCdf: _toDouble(json['priceCdf']),
      isDefault: json['isDefault'] == true,
      description: json['description']?.toString(),
    );
  }

  Map<String, dynamic> toJson() => {
        'code': code,
        'label': label,
        'priceCdf': priceCdf,
        'isDefault': isDefault,
        if (description != null && description!.isNotEmpty)
          'description': description,
      };

  ServicePriceTier copyWith({
    String? code,
    String? label,
    double? priceCdf,
    bool? isDefault,
    String? description,
  }) {
    return ServicePriceTier(
      code: code ?? this.code,
      label: label ?? this.label,
      priceCdf: priceCdf ?? this.priceCdf,
      isDefault: isDefault ?? this.isDefault,
      description: description ?? this.description,
    );
  }

  /// Code stable dérivé d'un libellé (« Premium + » → `premium_`).
  static String codeFromLabel(String label) {
    final normalized = label
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'[àâä]'), 'a')
        .replaceAll(RegExp(r'[éèêë]'), 'e')
        .replaceAll(RegExp(r'[îï]'), 'i')
        .replaceAll(RegExp(r'[ôö]'), 'o')
        .replaceAll(RegExp(r'[ùûü]'), 'u')
        .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
        .replaceAll(RegExp(r'^_+|_+$'), '');
    return normalized.isEmpty ? 'standard' : normalized;
  }

  @override
  List<Object?> get props => [code, label, priceCdf, isDefault, description];
}

/// Service vendu par l'entreprise (prestation, forfait, main d'œuvre) avec un
/// ou plusieurs paliers de prix. Catalogue commun à tous les modes : `metier`
/// isole les ateliers entre eux, `activityModes` restreint l'affichage.
///
/// Persisté en JSON dans une box Hive `String` (`ServiceRepository`), comme la
/// carte du restaurant et les prestations du salon : pas de TypeAdapter, pas
/// de migration Hive. Aligné sur le contrat backend `/services`.
class ServiceItem extends Equatable {
  final String id;
  final String name;
  final String? description;
  final String? category;
  final int? durationMinutes;
  final List<ServicePriceTier> priceTiers;
  final List<String> activityModes;
  final String? metier;
  final double? taxRate;
  final double? commissionPct;
  final String? imageUrl;
  final bool isPublic;
  final bool active;
  final int position;

  /// Vrai quand la dernière écriture n'a pas encore atteint le backend
  /// (hors ligne) ; republié au prochain chargement en ligne.
  final bool pendingSync;

  const ServiceItem({
    required this.id,
    required this.name,
    this.description,
    this.category,
    this.durationMinutes,
    required this.priceTiers,
    this.activityModes = const [],
    this.metier,
    this.taxRate,
    this.commissionPct,
    this.imageUrl,
    this.isPublic = false,
    this.active = true,
    this.position = 0,
    this.pendingSync = false,
  });

  /// Palier proposé par défaut (flag `isDefault`, sinon le premier).
  ServicePriceTier? get defaultTier {
    if (priceTiers.isEmpty) return null;
    return priceTiers.firstWhere((t) => t.isDefault, orElse: () => priceTiers.first);
  }

  ServicePriceTier? tierByCode(String? code) {
    if (code == null) return defaultTier;
    for (final t in priceTiers) {
      if (t.code == code) return t;
    }
    return defaultTier;
  }

  bool get hasMultipleTiers => priceTiers.length > 1;

  double get minPriceCdf => priceTiers.isEmpty
      ? 0
      : priceTiers.map((t) => t.priceCdf).reduce((a, b) => a < b ? a : b);

  double get maxPriceCdf => priceTiers.isEmpty
      ? 0
      : priceTiers.map((t) => t.priceCdf).reduce((a, b) => a > b ? a : b);

  factory ServiceItem.fromJson(Map<String, dynamic> json) {
    final rawTiers = json['priceTiers'];
    final tiers = <ServicePriceTier>[];
    if (rawTiers is List) {
      for (final t in rawTiers) {
        if (t is Map) tiers.add(ServicePriceTier.fromJson(Map<String, dynamic>.from(t)));
      }
    }
    final rawModes = json['activityModes'];
    final modes = <String>[];
    if (rawModes is List) {
      modes.addAll(rawModes.map((m) => m.toString()));
    } else if (rawModes is String && rawModes.isNotEmpty) {
      modes.addAll(rawModes.split(',').where((m) => m.trim().isNotEmpty));
    }
    return ServiceItem(
      id: (json['id'] ?? '').toString(),
      name: (json['name'] ?? '').toString(),
      description: json['description']?.toString(),
      category: json['category']?.toString(),
      durationMinutes: json['durationMinutes'] == null
          ? null
          : int.tryParse(json['durationMinutes'].toString()),
      priceTiers: tiers,
      activityModes: modes,
      metier: json['metier']?.toString(),
      taxRate: json['taxRate'] == null ? null : _toDouble(json['taxRate']),
      commissionPct:
          json['commissionPct'] == null ? null : _toDouble(json['commissionPct']),
      imageUrl: json['imageUrl']?.toString(),
      isPublic: json['isPublic'] == true,
      active: json['active'] != false,
      position: int.tryParse((json['position'] ?? 0).toString()) ?? 0,
      pendingSync: json['pendingSync'] == true,
    );
  }

  /// JSON envoyé au backend (`pendingSync` est un état local, jamais envoyé).
  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        if (description != null && description!.isNotEmpty)
          'description': description,
        if (category != null && category!.isNotEmpty) 'category': category,
        if (durationMinutes != null) 'durationMinutes': durationMinutes,
        'priceTiers': priceTiers.map((t) => t.toJson()).toList(),
        if (activityModes.isNotEmpty) 'activityModes': activityModes,
        if (metier != null && metier!.isNotEmpty) 'metier': metier,
        if (taxRate != null) 'taxRate': taxRate,
        if (commissionPct != null) 'commissionPct': commissionPct,
        if (imageUrl != null && imageUrl!.isNotEmpty) 'imageUrl': imageUrl,
        'isPublic': isPublic,
        'active': active,
        'position': position,
      };

  /// JSON du cache local (garde l'état de synchronisation).
  Map<String, dynamic> toLocalJson() => {...toJson(), 'pendingSync': pendingSync};

  ServiceItem copyWith({
    String? id,
    String? name,
    String? description,
    String? category,
    int? durationMinutes,
    List<ServicePriceTier>? priceTiers,
    List<String>? activityModes,
    String? metier,
    double? taxRate,
    double? commissionPct,
    String? imageUrl,
    bool? isPublic,
    bool? active,
    int? position,
    bool? pendingSync,
  }) {
    return ServiceItem(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      category: category ?? this.category,
      durationMinutes: durationMinutes ?? this.durationMinutes,
      priceTiers: priceTiers ?? this.priceTiers,
      activityModes: activityModes ?? this.activityModes,
      metier: metier ?? this.metier,
      taxRate: taxRate ?? this.taxRate,
      commissionPct: commissionPct ?? this.commissionPct,
      imageUrl: imageUrl ?? this.imageUrl,
      isPublic: isPublic ?? this.isPublic,
      active: active ?? this.active,
      position: position ?? this.position,
      pendingSync: pendingSync ?? this.pendingSync,
    );
  }

  @override
  List<Object?> get props => [
        id, name, description, category, durationMinutes, priceTiers,
        activityModes, metier, taxRate, commissionPct, imageUrl, isPublic,
        active, position, pendingSync,
      ];
}

double _toDouble(dynamic v) {
  if (v is num) return v.toDouble();
  return double.tryParse((v ?? '0').toString()) ?? 0;
}
