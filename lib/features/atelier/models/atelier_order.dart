import 'package:equatable/equatable.dart';

/// Statuts de fabrication d'une commande d'atelier (miroir du backend
/// `AtelierOrderStatus`). C'est le mode Atelier qui donne du sens à ce workflow
/// de production ; le board Kanban affiche une colonne par statut.
enum AtelierOrderStatus {
  draft, // Enregistrée
  measured, // Mesures prises
  cutting, // Coupe
  sewing, // Couture / assemblage
  ready, // Prête
  delivered, // Livrée
  paid, // Réglée (facturation auto → une Sale existe)
  cancelled, // Annulée
}

extension AtelierOrderStatusX on AtelierOrderStatus {
  String get apiValue => name;

  String get label {
    switch (this) {
      case AtelierOrderStatus.draft:
        return 'Enregistrée';
      case AtelierOrderStatus.measured:
        return 'Mesures prises';
      case AtelierOrderStatus.cutting:
        return 'Coupe';
      case AtelierOrderStatus.sewing:
        return 'Couture';
      case AtelierOrderStatus.ready:
        return 'Prête';
      case AtelierOrderStatus.delivered:
        return 'Livrée';
      case AtelierOrderStatus.paid:
        return 'Réglée';
      case AtelierOrderStatus.cancelled:
        return 'Annulée';
    }
  }

  static AtelierOrderStatus fromApiValue(String? value) {
    return AtelierOrderStatus.values.firstWhere(
      (s) => s.name == value,
      orElse: () => AtelierOrderStatus.draft,
    );
  }

  /// Une commande active est en cours de production (pas encore réglée/annulée).
  bool get isActive =>
      this != AtelierOrderStatus.paid && this != AtelierOrderStatus.cancelled;
}

/// Qui fournit le tissu de la confection.
enum FabricProvidedBy { client, atelier }

extension FabricProvidedByX on FabricProvidedBy {
  String get apiValue => name;
  String get label => this == FabricProvidedBy.client ? 'Client' : 'Atelier';
  static FabricProvidedBy? fromApiValue(String? v) {
    if (v == null) return null;
    return FabricProvidedBy.values.firstWhere(
      (e) => e.name == v,
      orElse: () => FabricProvidedBy.client,
    );
  }
}

/// Commande de confection (persistée côté backend, multi-appareils).
class AtelierOrder extends Equatable {
  final String id;
  final String customerId;
  final String? customerName;
  final String label;
  final String? modelDetails;
  final DateTime? entryDate;
  final DateTime? exitDate;
  final double totalAmount;
  final double advanceAmount;
  final double remainingAmount;
  final String currencyCode;
  final double exchangeRate;
  final FabricProvidedBy? fabricProvidedBy;
  final AtelierOrderStatus status;
  final String? saleId;
  final String? notes;
  final DateTime? createdAt;
  // ── Attribution (façon Trello : qui a fait quoi) ──
  final String? createdByName;
  final String? lastAction;
  final String? lastActionByName;
  final String? lastActionByAvatar;
  final DateTime? lastActionAt;

  const AtelierOrder({
    required this.id,
    required this.customerId,
    this.customerName,
    required this.label,
    this.modelDetails,
    this.entryDate,
    this.exitDate,
    this.totalAmount = 0,
    this.advanceAmount = 0,
    this.remainingAmount = 0,
    this.currencyCode = 'CDF',
    this.exchangeRate = 1,
    this.fabricProvidedBy,
    this.status = AtelierOrderStatus.draft,
    this.saleId,
    this.notes,
    this.createdAt,
    this.createdByName,
    this.lastAction,
    this.lastActionByName,
    this.lastActionByAvatar,
    this.lastActionAt,
  });

  static double _toDouble(dynamic v) =>
      v == null ? 0 : (v is num ? v.toDouble() : double.tryParse('$v') ?? 0);

  static DateTime? _toDate(dynamic v) =>
      v == null ? null : DateTime.tryParse('$v');

  factory AtelierOrder.fromJson(Map<String, dynamic> json) {
    final customer = json['customer'];
    return AtelierOrder(
      id: json['id'] as String,
      customerId: json['customerId'] as String? ?? '',
      customerName: (customer is Map<String, dynamic>)
          ? customer['fullName'] as String?
          : json['customerName'] as String?,
      label: json['label'] as String? ?? '',
      modelDetails: json['modelDetails'] as String?,
      entryDate: _toDate(json['entryDate']),
      exitDate: _toDate(json['exitDate']),
      totalAmount: _toDouble(json['totalAmount']),
      advanceAmount: _toDouble(json['advanceAmount']),
      remainingAmount: _toDouble(json['remainingAmount']),
      currencyCode: json['currencyCode'] as String? ?? 'CDF',
      exchangeRate: json['exchangeRate'] == null ? 1 : _toDouble(json['exchangeRate']),
      fabricProvidedBy: FabricProvidedByX.fromApiValue(json['fabricProvidedBy'] as String?),
      status: AtelierOrderStatusX.fromApiValue(json['status'] as String?),
      saleId: json['saleId'] as String?,
      notes: json['notes'] as String?,
      createdAt: _toDate(json['createdAt']),
      createdByName: json['createdByName'] as String?,
      lastAction: json['lastAction'] as String?,
      lastActionByName: json['lastActionByName'] as String?,
      lastActionByAvatar: json['lastActionByAvatar'] as String?,
      lastActionAt: _toDate(json['lastActionAt']),
    );
  }

  /// Sérialisation COMPLÈTE (pour le cache local offline). Émet les mêmes clés
  /// que [fromJson] sait relire, afin d'un aller-retour fidèle.
  Map<String, dynamic> toJson() => {
    'id': id,
    'customerId': customerId,
    if (customerName != null) 'customerName': customerName,
    'label': label,
    if (modelDetails != null) 'modelDetails': modelDetails,
    if (entryDate != null) 'entryDate': entryDate!.toIso8601String(),
    if (exitDate != null) 'exitDate': exitDate!.toIso8601String(),
    'totalAmount': totalAmount,
    'advanceAmount': advanceAmount,
    'remainingAmount': remainingAmount,
    'currencyCode': currencyCode,
    'exchangeRate': exchangeRate,
    if (fabricProvidedBy != null) 'fabricProvidedBy': fabricProvidedBy!.apiValue,
    'status': status.apiValue,
    if (saleId != null) 'saleId': saleId,
    if (notes != null) 'notes': notes,
    if (createdAt != null) 'createdAt': createdAt!.toIso8601String(),
    if (createdByName != null) 'createdByName': createdByName,
    if (lastAction != null) 'lastAction': lastAction,
    if (lastActionByName != null) 'lastActionByName': lastActionByName,
    if (lastActionByAvatar != null) 'lastActionByAvatar': lastActionByAvatar,
    if (lastActionAt != null) 'lastActionAt': lastActionAt!.toIso8601String(),
  };

  /// Payload de création/mise à jour (les champs null sont omis).
  Map<String, dynamic> toCreateJson() => {
    'customerId': customerId,
    'label': label,
    if (modelDetails != null) 'modelDetails': modelDetails,
    if (entryDate != null) 'entryDate': entryDate!.toIso8601String(),
    if (exitDate != null) 'exitDate': exitDate!.toIso8601String(),
    'totalAmount': totalAmount,
    'advanceAmount': advanceAmount,
    'currencyCode': currencyCode,
    'exchangeRate': exchangeRate,
    if (fabricProvidedBy != null) 'fabricProvidedBy': fabricProvidedBy!.apiValue,
    if (notes != null) 'notes': notes,
  };

  AtelierOrder copyWith({
    AtelierOrderStatus? status,
    double? remainingAmount,
    double? advanceAmount,
    String? saleId,
  }) {
    return AtelierOrder(
      id: id,
      customerId: customerId,
      customerName: customerName,
      label: label,
      modelDetails: modelDetails,
      entryDate: entryDate,
      exitDate: exitDate,
      totalAmount: totalAmount,
      advanceAmount: advanceAmount ?? this.advanceAmount,
      remainingAmount: remainingAmount ?? this.remainingAmount,
      currencyCode: currencyCode,
      exchangeRate: exchangeRate,
      fabricProvidedBy: fabricProvidedBy,
      status: status ?? this.status,
      saleId: saleId ?? this.saleId,
      notes: notes,
      createdAt: createdAt,
      createdByName: createdByName,
      lastAction: lastAction,
      lastActionByName: lastActionByName,
      lastActionByAvatar: lastActionByAvatar,
      lastActionAt: lastActionAt,
    );
  }

  @override
  List<Object?> get props => [
    id, customerId, label, status, totalAmount, advanceAmount,
    remainingAmount, currencyCode, saleId,
  ];
}
