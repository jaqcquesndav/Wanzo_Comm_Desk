import 'package:equatable/equatable.dart';

/// Cycle de vie d'une commande restaurant (ticket de table).
///
/// Différence métier avec la vente au détail : une commande s'ouvre, se
/// complète au fil du service, puis se règle. Le paiement final produit une
/// `Sale` (réutilise toute l'infra vente/synchro existante).
enum RestaurantOrderStatus {
  open, // Commande en cours de saisie
  sent, // Envoyée en cuisine
  served, // Servie, en attente de règlement
  paid, // Réglée (une Sale a été créée)
  cancelled, // Annulée
}

extension RestaurantOrderStatusX on RestaurantOrderStatus {
  String get apiValue => name;

  String get label {
    switch (this) {
      case RestaurantOrderStatus.open:
        return 'En saisie';
      case RestaurantOrderStatus.sent:
        return 'En cuisine';
      case RestaurantOrderStatus.served:
        return 'Servie';
      case RestaurantOrderStatus.paid:
        return 'Réglée';
      case RestaurantOrderStatus.cancelled:
        return 'Annulée';
    }
  }

  static RestaurantOrderStatus fromApiValue(String? value) {
    return RestaurantOrderStatus.values.firstWhere(
      (s) => s.name == value,
      orElse: () => RestaurantOrderStatus.open,
    );
  }

  /// Une commande soldée est CLOSE : réglée (facturée) ou annulée. Plus aucune
  /// ligne ne peut y entrer, sinon le plat ajouté ne figure sur aucune facture.
  bool get isSettled =>
      this == RestaurantOrderStatus.paid ||
      this == RestaurantOrderStatus.cancelled;

  /// Une commande active occupe une table / reste dans la liste de service.
  bool get isActive =>
      this == RestaurantOrderStatus.open ||
      this == RestaurantOrderStatus.sent ||
      this == RestaurantOrderStatus.served;
}

/// Nature du service d'une commande : consommée sur place (à une table) ou
/// emportée. Distingue le flux salle du flux comptoir : une commande à
/// emporter n'occupe JAMAIS une table sur le plan de salle.
enum RestaurantOrderType {
  dineIn, // Sur place (table)
  takeaway, // À emporter
}

extension RestaurantOrderTypeX on RestaurantOrderType {
  String get apiValue => name;

  String get label {
    switch (this) {
      case RestaurantOrderType.dineIn:
        return 'Sur place';
      case RestaurantOrderType.takeaway:
        return 'À emporter';
    }
  }

  /// Vrai si un libellé évoque une commande à emporter (« Emporter »,
  /// « Emporté », « takeaway », « take away »…). Rétro-compatibilité : les
  /// anciennes commandes ne portent pas de `type`, on le dérive du libellé.
  static bool labelLooksTakeaway(String? label) {
    final l = (label ?? '').toLowerCase();
    return l.contains('emport') ||
        l.contains('takeaway') ||
        l.contains('take away') ||
        l.contains('take-away') ||
        l.contains('à emporter');
  }

  /// Résout le type d'une commande en tenant compte, dans l'ordre : d'une valeur
  /// explicite ([raw]), de la présence d'une table ([tableId] → sur place), puis
  /// d'un indice dans le libellé (« Emporter » → à emporter). Défaut : sur place.
  static RestaurantOrderType resolve({
    String? raw,
    String? tableId,
    String? label,
  }) {
    if (raw != null && raw.isNotEmpty) {
      return RestaurantOrderType.values.firstWhere(
        (t) => t.name == raw,
        orElse: () => (tableId != null && tableId.isNotEmpty)
            ? RestaurantOrderType.dineIn
            : (labelLooksTakeaway(label)
                ? RestaurantOrderType.takeaway
                : RestaurantOrderType.dineIn),
      );
    }
    if (tableId != null && tableId.isNotEmpty) return RestaurantOrderType.dineIn;
    return labelLooksTakeaway(label)
        ? RestaurantOrderType.takeaway
        : RestaurantOrderType.dineIn;
  }
}

/// Ligne de commande : un article (produit du catalogue) et sa quantité.
///
/// Le montant est porté en CDF (`double`, base monétaire de l'app, cf.
/// `Product.sellingPriceInCdf` et `Sale.totalAmountInCdf`). Les totaux sont
/// arrondis au centime pour éviter la dérive des flottants.
class RestaurantOrderLine extends Equatable {
  final String productId;
  final String productName;
  final double unitPriceCdf;
  final int quantity;
  final String? note; // Ex. « sans oignon », cuisson…

  /// `true` quand la ligne est un ARTICLE DU STOCK (jus, bière, eau) et non un
  /// plat préparé. C'est ce qui décide, à l'encaissement, si la vente
  /// décrémente le stock ou enregistre une prestation de cuisine.
  final bool fromStock;

  const RestaurantOrderLine({
    required this.productId,
    required this.productName,
    required this.unitPriceCdf,
    required this.quantity,
    this.note,
    this.fromStock = false,
  });

  double get totalCdf => _round2(unitPriceCdf * quantity);

  RestaurantOrderLine copyWith({int? quantity, String? note}) {
    return RestaurantOrderLine(
      productId: productId,
      productName: productName,
      unitPriceCdf: unitPriceCdf,
      quantity: quantity ?? this.quantity,
      note: note ?? this.note,
      fromStock: fromStock,
    );
  }

  Map<String, dynamic> toJson() => {
    'productId': productId,
    'productName': productName,
    'unitPriceCdf': unitPriceCdf,
    'quantity': quantity,
    if (note != null) 'note': note,
    if (fromStock) 'fromStock': true,
  };

  factory RestaurantOrderLine.fromJson(Map<String, dynamic> json) {
    return RestaurantOrderLine(
      productId: json['productId'] as String,
      productName: json['productName'] as String,
      unitPriceCdf: (json['unitPriceCdf'] as num).toDouble(),
      quantity: (json['quantity'] as num).toInt(),
      note: json['note'] as String?,
      fromStock: json['fromStock'] as bool? ?? false,
    );
  }

  @override
  List<Object?> get props =>
      [productId, productName, unitPriceCdf, quantity, note, fromStock];
}

/// Commande restaurant (ticket rattaché à une table ou un client).
class RestaurantOrder extends Equatable {
  final String id;

  /// Libellé lisible : « Table 4 », « Emporter », un nom de client…
  final String label;
  final List<RestaurantOrderLine> lines;
  final RestaurantOrderStatus status;
  final DateTime createdAt;
  final String? notes;

  /// Lien FORT vers la table du plan de salle (`RestaurantTable.id`). Prioritaire
  /// sur le rapprochement par libellé (fragile). `null` pour une commande libre
  /// ou à emporter. Rétro-compatible : clé absente en JSON → `null`.
  final String? tableId;

  /// Nature du service (sur place / à emporter). Rétro-compatible : clé absente
  /// en JSON → dérivée du `tableId` puis du libellé (cf. [RestaurantOrderTypeX]).
  final RestaurantOrderType type;

  /// Client ENREGISTRÉ rattaché à la commande, quand il est connu (surtout à
  /// emporter). `null` = client de passage : le libellé suffit. C'est ce lien
  /// qui donne à la vente son vrai client, donc l'historique et la créance.
  final String? customerId;

  /// Nom du client retenu, pour l'afficher sans relire la fiche.
  final String? customerName;

  /// Historique horodaté des étapes [{status, at}] — KPI de temps de service
  /// (prestation), base de la future cote crédit.
  final List<Map<String, dynamic>> stageHistory;

  const RestaurantOrder({
    required this.id,
    required this.label,
    required this.lines,
    required this.status,
    required this.createdAt,
    this.notes,
    this.tableId,
    this.type = RestaurantOrderType.dineIn,
    this.customerId,
    this.customerName,
    this.stageHistory = const [],
  });

  /// La commande est close : elle a été facturée ou annulée, on n'y touche plus.
  bool get isSettled => status.isSettled;

  /// Temps de préparation/service : de la création au passage « servie ».
  Duration? get serviceTime {
    DateTime? servedAt;
    for (final e in stageHistory) {
      if (e['status'] == RestaurantOrderStatus.served.apiValue) {
        servedAt = DateTime.tryParse('${e['at']}');
      }
    }
    if (servedAt == null) return null;
    return servedAt.difference(createdAt);
  }

  /// Total de la commande en CDF (arrondi au centime).
  double get totalCdf =>
      _round2(lines.fold<double>(0, (sum, l) => sum + l.totalCdf));

  int get itemCount => lines.fold<int>(0, (sum, l) => sum + l.quantity);

  bool get isEmpty => lines.isEmpty;

  RestaurantOrder copyWith({
    String? label,
    List<RestaurantOrderLine>? lines,
    RestaurantOrderStatus? status,
    String? notes,
    String? tableId,
    RestaurantOrderType? type,
    String? customerId,
    String? customerName,
    List<Map<String, dynamic>>? stageHistory,
  }) {
    return RestaurantOrder(
      id: id,
      label: label ?? this.label,
      lines: lines ?? this.lines,
      status: status ?? this.status,
      createdAt: createdAt,
      notes: notes ?? this.notes,
      tableId: tableId ?? this.tableId,
      type: type ?? this.type,
      customerId: customerId ?? this.customerId,
      customerName: customerName ?? this.customerName,
      stageHistory: stageHistory ?? this.stageHistory,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'label': label,
    'lines': lines.map((l) => l.toJson()).toList(),
    'status': status.apiValue,
    'createdAt': createdAt.toIso8601String(),
    if (notes != null) 'notes': notes,
    if (tableId != null) 'tableId': tableId,
    'type': type.apiValue,
    if (customerId != null) 'customerId': customerId,
    if (customerName != null) 'customerName': customerName,
    if (stageHistory.isNotEmpty) 'stageHistory': stageHistory,
  };

  factory RestaurantOrder.fromJson(Map<String, dynamic> json) {
    final tableId = (json['tableId'] as String?)?.trim();
    final label = json['label'] as String;
    return RestaurantOrder(
      id: json['id'] as String,
      label: label,
      lines: (json['lines'] as List<dynamic>)
          .map((e) => RestaurantOrderLine.fromJson(e as Map<String, dynamic>))
          .toList(),
      status: RestaurantOrderStatusX.fromApiValue(json['status'] as String?),
      createdAt:
          DateTime.tryParse(json['createdAt'] as String? ?? '') ??
          DateTime.now(),
      notes: json['notes'] as String?,
      tableId: (tableId != null && tableId.isNotEmpty) ? tableId : null,
      // Lecture défensive : les anciennes commandes n'ont pas de `type`, on le
      // dérive du tableId puis du libellé (rétro-compatible, sans migration).
      type: RestaurantOrderTypeX.resolve(
        raw: json['type'] as String?,
        tableId: tableId,
        label: label,
      ),
      customerId: (json['customerId'] as String?)?.trim().isEmpty ?? true
          ? null
          : (json['customerId'] as String).trim(),
      customerName: json['customerName'] as String?,
      stageHistory: (json['stageHistory'] as List<dynamic>?)
              ?.whereType<Map<String, dynamic>>()
              .toList() ??
          const [],
    );
  }

  @override
  List<Object?> get props =>
      [id, label, lines, status, createdAt, notes, tableId, type, customerId,
       customerName, stageHistory];
}

/// Arrondi bancaire au centime — centralisé pour tout le module.
double _round2(double v) => (v * 100).roundToDouble() / 100;
