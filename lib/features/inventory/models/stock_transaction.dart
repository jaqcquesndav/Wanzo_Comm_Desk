import 'package:hive/hive.dart';
import 'package:equatable/equatable.dart';
import 'package:json_annotation/json_annotation.dart';
import 'package:wanzo/core/enums/business_unit_enums.dart';

part 'stock_transaction.g.dart';

@HiveType(typeId: 32)
@JsonEnum() // Added JsonEnum
enum StockTransactionType {
  @HiveField(0)
  purchase, // Entrée de stock suite à un achat

  @HiveField(1)
  sale, // Sortie de stock suite à une vente

  @HiveField(2)
  adjustment, // Ajustement manuel (positif ou négatif)

  @HiveField(3)
  transferIn, // Entrée de stock suite à un transfert interne

  @HiveField(4)
  transferOut, // Sortie de stock suite à un transfert interne

  @HiveField(5)
  returned, // Retour de marchandise par un client (entrée)

  @HiveField(6)
  damaged, // Marchandise endommagée (sortie)

  @HiveField(7)
  lost, // Marchandise perdue (sortie)

  @HiveField(8)
  initialStock, // Stock initial lors de la création du produit
}

@HiveType(typeId: 33)
@JsonSerializable() // Added JsonSerializable
class StockTransaction extends Equatable {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String productId;

  @HiveField(2)
  final StockTransactionType type;

  @HiveField(3)
  final double quantity; // Peut être négatif pour les sorties

  @HiveField(4)
  final DateTime date;

  @HiveField(5)
  final String? referenceId; // ID de la vente, achat, ou autre document lié

  @HiveField(6)
  final String? notes;

  @HiveField(7)
  final double unitCostInCdf; // Coût unitaire du produit en CDF au moment de la transaction
  @HiveField(8)
  final double totalValueInCdf; // Valeur totale de la transaction en CDF (quantité * coût unitaire en CDF)

  @HiveField(9)
  final String? currencyCode; // Code de la devise de la transaction (USD, CDF, etc.)

  @HiveField(10)
  final String? createdBy; // ID de l'utilisateur qui a créé la transaction

  @HiveField(11)
  final String? locationId; // ID de l'emplacement/magasin où la transaction a eu lieu

  // === Champs Business Unit (Multi-Tenant) ===
  @HiveField(12)
  @JsonKey(name: 'companyId')
  final String? companyId; // ID de l'entreprise principale

  @HiveField(13)
  @JsonKey(name: 'businessUnitId')
  final String? businessUnitId; // ID de l'unité commerciale

  @HiveField(14)
  @JsonKey(name: 'businessUnitCode')
  final String? businessUnitCode; // Code unique de l'unité (ex: POS-001)

  @HiveField(15)
  @JsonKey(name: 'businessUnitType')
  final BusinessUnitType? businessUnitType; // Type: company, branch, pos

  // productName and unitCost are not part of this model as per InventoryRepository
  // If needed, they should be fetched from the Product model using productId

  const StockTransaction({
    required this.id,
    required this.productId,
    required this.type,
    required this.quantity,
    required this.date,
    this.referenceId,
    this.notes,
    required this.unitCostInCdf,
    required this.totalValueInCdf,
    this.currencyCode,
    this.createdBy,
    this.locationId,
    this.companyId,
    this.businessUnitId,
    this.businessUnitCode,
    this.businessUnitType,
  });
  factory StockTransaction.fromJson(Map<String, dynamic> json) =>
      _$StockTransactionFromJson(json);
  Map<String, dynamic> toJson() => _$StockTransactionToJson(this);

  /// Types qui font SORTIR du stock (le sens vient du type, pas du signe).
  static const Set<StockTransactionType> sortieTypes = {
    StockTransactionType.sale,
    StockTransactionType.transferOut,
    StockTransactionType.damaged,
    StockTransactionType.lost,
  };

  /// Variation du stock portée par ce mouvement, avec la même règle que le
  /// serveur : seul l'ajustement garde son signe ; sinon le type décide.
  double get stockDelta {
    if (type == StockTransactionType.adjustment) return quantity;
    return sortieTypes.contains(type) ? -quantity.abs() : quantity.abs();
  }

  /// Corps EXACT de `POST stock-transactions` : le serveur retire en silence
  /// tout champ hors liste (l'ancien `toJson` envoyait `unitCostInCdf`, perdu,
  /// au lieu de `unitCostPrice`). Un coût nul est omis : le serveur prend
  /// alors le coût de l'article au lieu d'enregistrer 0.
  Map<String, dynamic> toApiPayload({String? expenseId}) {
    final note = notes?.trim();
    return {
      'productId': productId,
      'type': type.name,
      'quantity':
          type == StockTransactionType.adjustment ? quantity : quantity.abs(),
      'date': date.toUtc().toIso8601String(),
      if (referenceId != null && referenceId!.isNotEmpty)
        'referenceId': referenceId,
      if (note != null && note.isNotEmpty) 'notes': note,
      if (unitCostInCdf > 0) 'unitCostPrice': unitCostInCdf,
      if (locationId != null && locationId!.isNotEmpty)
        'locationId': locationId,
      if (expenseId != null && expenseId.isNotEmpty) 'expenseId': expenseId,
    };
  }

  /// Mouvement tel que renvoyé par le serveur (entité, décimaux en texte,
  /// coût dans `unitCostPrice`).
  factory StockTransaction.fromApi(Map<String, dynamic> json) {
    double nombre(dynamic v) =>
        v is num ? v.toDouble() : double.tryParse('${v ?? ''}') ?? 0;
    final type = StockTransactionType.values.firstWhere(
      (t) => t.name == json['type'],
      orElse: () => StockTransactionType.adjustment,
    );
    final quantity = nombre(json['quantity']);
    final unitCost = nombre(json['unitCostPrice'] ?? json['unitCostInCdf']);
    return StockTransaction(
      id: '${json['id'] ?? ''}',
      productId: '${json['productId'] ?? ''}',
      type: type,
      quantity: quantity,
      date: DateTime.tryParse('${json['date'] ?? ''}') ?? DateTime.now(),
      referenceId: json['referenceId']?.toString(),
      notes: json['notes']?.toString(),
      unitCostInCdf: unitCost,
      totalValueInCdf: unitCost * quantity.abs(),
      currencyCode: 'CDF',
      createdBy: json['createdBy']?.toString(),
      locationId: json['locationId']?.toString(),
    );
  }

  @override
  List<Object?> get props => [
    id,
    productId,
    type,
    quantity,
    date,
    referenceId,
    notes,
    unitCostInCdf,
    totalValueInCdf,
    currencyCode,
    createdBy,
    locationId,
    companyId,
    businessUnitId,
    businessUnitCode,
    businessUnitType,
  ];

  StockTransaction copyWith({
    String? id,
    String? productId,
    StockTransactionType? type,
    double? quantity,
    DateTime? date,
    String? referenceId,
    String? notes,
    double? unitCostInCdf,
    double? totalValueInCdf,
    String? currencyCode,
    String? createdBy,
    String? locationId,
    String? companyId,
    String? businessUnitId,
    String? businessUnitCode,
    BusinessUnitType? businessUnitType,
  }) {
    return StockTransaction(
      id: id ?? this.id,
      productId: productId ?? this.productId,
      type: type ?? this.type,
      quantity: quantity ?? this.quantity,
      date: date ?? this.date,
      referenceId: referenceId ?? this.referenceId,
      notes: notes ?? this.notes,
      unitCostInCdf: unitCostInCdf ?? this.unitCostInCdf,
      totalValueInCdf: totalValueInCdf ?? this.totalValueInCdf,
      currencyCode: currencyCode ?? this.currencyCode,
      createdBy: createdBy ?? this.createdBy,
      locationId: locationId ?? this.locationId,
      companyId: companyId ?? this.companyId,
      businessUnitId: businessUnitId ?? this.businessUnitId,
      businessUnitCode: businessUnitCode ?? this.businessUnitCode,
      businessUnitType: businessUnitType ?? this.businessUnitType,
    );
  }
}

// Extension pour faciliter l'accès à la devise
extension StockTransactionExtension on StockTransaction {
  /// Obtient le code de devise effectif pour cette transaction (CDF par défaut)
  String get effectiveCurrencyCode => currencyCode ?? 'CDF';
}
