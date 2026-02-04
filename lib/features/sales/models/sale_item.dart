import 'package:equatable/equatable.dart';
import 'package:hive/hive.dart';
import 'package:json_annotation/json_annotation.dart';

part 'sale_item.g.dart';

@HiveType(typeId: 50) // New unique typeId for SaleItemType enum
enum SaleItemType {
  @HiveField(0)
  product,

  @HiveField(1)
  service,
}

/// Modèle représentant un élément de vente (un produit ou service vendu avec sa quantité et son prix)
@HiveType(typeId: 41) // Unique typeId for SaleItem
@JsonSerializable(explicitToJson: true)
class SaleItem extends Equatable {
  /// Identifiant unique de l'article de vente
  @HiveField(10)
  final String? id;

  /// Identifiant du produit ou service (peut être null pour les produits non référencés)
  @HiveField(0)
  final String? productId;

  /// Nom du produit ou service
  @HiveField(1)
  final String productName;

  /// Quantité vendue
  @HiveField(2)
  final int quantity;

  /// Prix unitaire (in transaction currency)
  @HiveField(3)
  final double unitPrice;

  /// Remise appliquée à cet article (optionnel)
  @HiveField(11)
  final double? discount;

  /// Montant total pour cet article (prix unitaire * quantité, in transaction currency)
  @HiveField(4)
  final double totalPrice;

  /// Code de la devise de la transaction (par exemple, "USD", "CDF")
  @HiveField(5)
  final String currencyCode;

  /// Taux de change vers CDF au moment de la transaction
  /// (Si currencyCode est "CDF", exchangeRate est 1.0)
  @HiveField(6)
  final double exchangeRate;

  /// Prix unitaire en CDF
  @HiveField(7)
  final double unitPriceInCdf;

  /// Montant total pour cet article en CDF
  @HiveField(8)
  final double totalPriceInCdf;

  /// Type d'élément (produit ou service)
  @HiveField(9) // New HiveField index
  final SaleItemType itemType;

  /// Taux de taxe applicable en pourcentage (optionnel)
  @HiveField(12)
  final double? taxRate;

  /// Montant de la taxe calculé (optionnel)
  @HiveField(13)
  final double? taxAmount;

  /// Notes additionnelles pour cet article (optionnel)
  @HiveField(14)
  final String? notes;

  /// Constructeur
  const SaleItem({
    this.id,
    this.productId,
    required this.productName,
    required this.quantity,
    required this.unitPrice,
    this.discount,
    required this.totalPrice,
    required this.currencyCode,
    required this.exchangeRate,
    required this.unitPriceInCdf,
    required this.totalPriceInCdf,
    required this.itemType,
    this.taxRate,
    this.taxAmount,
    this.notes,
  });

  factory SaleItem.fromJson(Map<String, dynamic> json) =>
      _$SaleItemFromJson(json);
  Map<String, dynamic> toJson() => _$SaleItemToJson(this);

  /// Méthode pour créer un item avec le total calculé automatiquement
  factory SaleItem.withCalculatedTotal({
    String? id,
    String? productId,
    required String productName,
    required int quantity,
    required double unitPrice,
    double? discount,
    required String currencyCode,
    required double exchangeRate, // Rate to convert currencyCode to CDF
    required SaleItemType itemType,
    double? taxRate,
    String? notes,
  }) {
    // Calcul du prix total avec remise
    final discountAmount = discount ?? 0.0;
    final calculatedTotalPrice = (quantity * unitPrice) - discountAmount;

    // Calcul du montant de taxe si taxRate est fourni
    final calculatedTaxAmount =
        taxRate != null ? (calculatedTotalPrice * taxRate / 100) : null;

    return SaleItem(
      id: id,
      productId: productId,
      productName: productName,
      quantity: quantity,
      unitPrice: unitPrice,
      discount: discount,
      totalPrice: calculatedTotalPrice,
      currencyCode: currencyCode,
      exchangeRate: exchangeRate,
      unitPriceInCdf: unitPrice * exchangeRate,
      totalPriceInCdf: calculatedTotalPrice * exchangeRate,
      itemType: itemType,
      taxRate: taxRate,
      taxAmount: calculatedTaxAmount,
      notes: notes,
    );
  }

  /// Méthode pour créer une copie de cet item avec des valeurs modifiées
  SaleItem copyWith({
    String? id,
    String? productId,
    String? productName,
    int? quantity,
    double? unitPrice,
    double? discount,
    double? totalPrice,
    String? currencyCode,
    double? exchangeRate,
    double? unitPriceInCdf,
    double? totalPriceInCdf,
    SaleItemType? itemType,
    double? taxRate,
    double? taxAmount,
    String? notes,
  }) {
    return SaleItem(
      id: id ?? this.id,
      productId: productId ?? this.productId,
      productName: productName ?? this.productName,
      quantity: quantity ?? this.quantity,
      unitPrice: unitPrice ?? this.unitPrice,
      discount: discount ?? this.discount,
      totalPrice: totalPrice ?? this.totalPrice,
      currencyCode: currencyCode ?? this.currencyCode,
      exchangeRate: exchangeRate ?? this.exchangeRate,
      unitPriceInCdf: unitPriceInCdf ?? this.unitPriceInCdf,
      totalPriceInCdf: totalPriceInCdf ?? this.totalPriceInCdf,
      itemType: itemType ?? this.itemType,
      taxRate: taxRate ?? this.taxRate,
      taxAmount: taxAmount ?? this.taxAmount,
      notes: notes ?? this.notes,
    );
  }

  @override
  List<Object?> get props => [
    id,
    productId,
    productName,
    quantity,
    unitPrice,
    discount,
    totalPrice,
    currencyCode,
    exchangeRate,
    unitPriceInCdf,
    totalPriceInCdf,
    itemType,
    taxRate,
    taxAmount,
    notes,
  ];
}
