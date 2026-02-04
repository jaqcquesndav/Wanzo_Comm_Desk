import 'package:equatable/equatable.dart';
import 'package:hive/hive.dart';
import 'package:json_annotation/json_annotation.dart';
import 'package:flutter/material.dart'; // Ajout pour IconData et Icons
import 'package:wanzo/core/enums/business_unit_enums.dart';

part 'product.g.dart';

/// Catégorie de produit
@HiveType(typeId: 20)
@JsonEnum()
enum ProductCategory {
  @HiveField(0)
  food, // Alimentation

  @HiveField(1)
  drink, // Boissons

  @HiveField(2)
  electronics, // Électronique

  @HiveField(3)
  clothing, // Vêtements

  @HiveField(4)
  household, // Articles ménagers

  @HiveField(5)
  hygiene, // Hygiène et beauté

  @HiveField(6)
  office, // Fournitures de bureau

  @HiveField(7)
  cosmetics, // Produits cosmétiques

  @HiveField(8)
  pharmaceuticals, // Produits pharmaceutiques

  @HiveField(9)
  bakery, // Boulangerie

  @HiveField(10)
  dairy, // Produits laitiers

  @HiveField(11)
  meat, // Viande

  @HiveField(12)
  vegetables, // Légumes

  @HiveField(13)
  fruits, // Fruits

  @HiveField(14)
  other, // Autres
}

/// Unité de mesure d'un produit
@HiveType(typeId: 21)
@JsonEnum()
enum ProductUnit {
  @HiveField(0)
  piece, // Pièce

  @HiveField(1)
  kg, // Kilogramme

  @HiveField(2)
  g, // Gramme

  @HiveField(3)
  l, // Litre

  @HiveField(4)
  ml, // Millilitre

  @HiveField(5)
  package, // Paquet

  @HiveField(6)
  box, // Boîte

  @HiveField(7)
  other, // Autre
}

/// Extension pour faciliter l'utilisation des catégories de produits
extension ProductCategoryExtension on ProductCategory {
  String get displayName {
    switch (this) {
      case ProductCategory.food:
        return 'Alimentation';
      case ProductCategory.drink:
        return 'Boissons';
      case ProductCategory.electronics:
        return 'Électronique';
      case ProductCategory.clothing:
        return 'Vêtements';
      case ProductCategory.household:
        return 'Articles ménagers';
      case ProductCategory.hygiene:
        return 'Hygiène et beauté';
      case ProductCategory.office:
        return 'Fournitures de bureau';
      case ProductCategory.cosmetics:
        return 'Produits cosmétiques';
      case ProductCategory.pharmaceuticals:
        return 'Produits pharmaceutiques';
      case ProductCategory.bakery:
        return 'Boulangerie';
      case ProductCategory.dairy:
        return 'Produits laitiers';
      case ProductCategory.meat:
        return 'Viande';
      case ProductCategory.vegetables:
        return 'Légumes';
      case ProductCategory.fruits:
        return 'Fruits';
      case ProductCategory.other:
        return 'Autres';
    }
  }

  IconData get icon {
    switch (this) {
      case ProductCategory.food:
        return Icons.restaurant;
      case ProductCategory.drink:
        return Icons.local_drink;
      case ProductCategory.electronics:
        return Icons.devices;
      case ProductCategory.clothing:
        return Icons.checkroom;
      case ProductCategory.household:
        return Icons.home;
      case ProductCategory.hygiene:
        return Icons.wash;
      case ProductCategory.office:
        return Icons.business_center;
      case ProductCategory.cosmetics:
        return Icons.face;
      case ProductCategory.pharmaceuticals:
        return Icons.medication;
      case ProductCategory.bakery:
        return Icons.bakery_dining;
      case ProductCategory.dairy:
        return Icons.egg;
      case ProductCategory.meat:
        return Icons.restaurant_menu;
      case ProductCategory.vegetables:
        return Icons.grass;
      case ProductCategory.fruits:
        return Icons.apple;
      case ProductCategory.other:
        return Icons.category;
    }
  }
}

/// Modèle représentant un produit dans l'inventaire
@HiveType(typeId: 22)
@JsonSerializable(explicitToJson: true)
class Product extends Equatable {
  /// Identifiant unique du produit
  @HiveField(0)
  final String id;

  /// Nom du produit
  @HiveField(1)
  final String name;

  /// Description du produit
  @HiveField(2)
  final String description;

  /// Code barres ou référence
  @HiveField(3)
  final String barcode;

  /// Catégorie du produit
  @HiveField(4)
  final ProductCategory category;

  /// Prix d'achat en CDF
  @HiveField(5)
  final double costPriceInCdf;

  /// Prix de vente en CDF
  @HiveField(6)
  final double sellingPriceInCdf;

  /// Quantité en stock
  @HiveField(7)
  final double stockQuantity;

  /// Unité de mesure
  @HiveField(8)
  final ProductUnit unit;

  /// Niveau d'alerte de stock bas
  @HiveField(9)
  final double alertThreshold;

  /// Date d'ajout dans l'inventaire
  @HiveField(10)
  final DateTime createdAt;

  /// Date de dernière mise à jour
  @HiveField(11)
  final DateTime updatedAt;

  /// Chemin de l'image du produit en local (optionnel)
  @HiveField(12)
  final String? imagePath;

  /// URL de l'image du produit sur le serveur (Cloudinary) après synchronisation
  @HiveField(21)
  final String? imageUrl;

  /// Devise dans laquelle les prix ont été saisis
  @HiveField(13)
  final String inputCurrencyCode;

  /// Taux de change utilisé lors de la saisie (par rapport au CDF)
  @HiveField(14)
  final double inputExchangeRate;

  /// Prix d'achat dans la devise de saisie
  @HiveField(15)
  final double costPriceInInputCurrency;

  /// Prix de vente dans la devise de saisie
  @HiveField(16)
  final double sellingPriceInInputCurrency;

  /// Liste des IDs de fournisseurs associés à ce produit
  @HiveField(17)
  final List<String>? supplierIds;

  /// Tags/étiquettes pour faciliter la recherche et le filtrage
  @HiveField(18)
  final List<String>? tags;

  /// Taux de taxe applicable (en pourcentage, ex: 16.0 pour 16%)
  @HiveField(19)
  final double? taxRate;

  /// SKU (Stock Keeping Unit) - Code unique d'identification
  @HiveField(20)
  final String? sku;

  // ============= BUSINESS UNIT FIELDS =============

  /// ID de l'entreprise associée
  @HiveField(22)
  final String? companyId;

  /// ID de l'unité commerciale
  @HiveField(23)
  final String? businessUnitId;

  /// Code de l'unité (ex: POS-001)
  @HiveField(24)
  final String? businessUnitCode;

  /// Type d'unité: company, branch ou pos
  @HiveField(25)
  @JsonKey(fromJson: _businessUnitTypeFromJson, toJson: _businessUnitTypeToJson)
  final BusinessUnitType? businessUnitType;

  // ============= SYNC FIELDS =============

  /// Statut de synchronisation: 'pending' ou 'synced'
  @HiveField(26)
  final String syncStatus;

  /// Identifiant local pour la synchronisation
  @HiveField(27)
  final String? localId;

  /// Constructeur
  const Product({
    required this.id,
    required this.name,
    this.description = '',
    this.barcode = '',
    required this.category,
    required this.costPriceInCdf,
    required this.sellingPriceInCdf,
    required this.stockQuantity,
    required this.unit,
    this.alertThreshold = 5,
    required this.createdAt,
    required this.updatedAt,
    this.imagePath,
    this.imageUrl,
    required this.inputCurrencyCode,
    required this.inputExchangeRate,
    required this.costPriceInInputCurrency,
    required this.sellingPriceInInputCurrency,
    this.supplierIds,
    this.tags,
    this.taxRate,
    this.sku,
    // Business Unit fields
    this.companyId,
    this.businessUnitId,
    this.businessUnitCode,
    this.businessUnitType,
    // Sync fields
    this.syncStatus = 'pending',
    this.localId,
  });

  factory Product.fromJson(Map<String, dynamic> json) =>
      _$ProductFromJson(json);
  Map<String, dynamic> toJson() => _$ProductToJson(this);

  // Helpers pour la sérialisation des enums
  static BusinessUnitType? _businessUnitTypeFromJson(String? value) =>
      value != null ? BusinessUnitTypeExtension.fromApiValue(value) : null;

  static String? _businessUnitTypeToJson(BusinessUnitType? type) =>
      type?.apiValue;

  /// Vérifie si le stock est bas
  bool get isLowStock => stockQuantity <= alertThreshold;

  /// Marge bénéficiaire en CDF
  double get profitMarginInCdf => sellingPriceInCdf - costPriceInCdf;

  /// Pourcentage de marge en CDF
  double get profitPercentageInCdf =>
      costPriceInCdf > 0 ? (profitMarginInCdf / costPriceInCdf) * 100 : 0;

  /// Valeur totale du stock pour ce produit en CDF
  double get stockValueInCdf => stockQuantity * costPriceInCdf;

  /// Crée une copie du produit avec des attributs modifiés
  Product copyWith({
    String? id,
    String? name,
    String? description,
    String? barcode,
    ProductCategory? category,
    double? costPriceInCdf,
    double? sellingPriceInCdf,
    double? stockQuantity,
    ProductUnit? unit,
    double? alertThreshold,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? imagePath,
    String? imageUrl,
    String? inputCurrencyCode,
    double? inputExchangeRate,
    double? costPriceInInputCurrency,
    double? sellingPriceInInputCurrency,
    List<String>? supplierIds,
    List<String>? tags,
    double? taxRate,
    String? sku,
    String? companyId,
    String? businessUnitId,
    String? businessUnitCode,
    BusinessUnitType? businessUnitType,
    String? syncStatus,
    String? localId,
  }) {
    return Product(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      barcode: barcode ?? this.barcode,
      category: category ?? this.category,
      costPriceInCdf: costPriceInCdf ?? this.costPriceInCdf,
      sellingPriceInCdf: sellingPriceInCdf ?? this.sellingPriceInCdf,
      stockQuantity: stockQuantity ?? this.stockQuantity,
      unit: unit ?? this.unit,
      alertThreshold: alertThreshold ?? this.alertThreshold,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      imagePath: imagePath ?? this.imagePath,
      imageUrl: imageUrl ?? this.imageUrl,
      inputCurrencyCode: inputCurrencyCode ?? this.inputCurrencyCode,
      inputExchangeRate: inputExchangeRate ?? this.inputExchangeRate,
      costPriceInInputCurrency:
          costPriceInInputCurrency ?? this.costPriceInInputCurrency,
      sellingPriceInInputCurrency:
          sellingPriceInInputCurrency ?? this.sellingPriceInInputCurrency,
      supplierIds: supplierIds ?? this.supplierIds,
      tags: tags ?? this.tags,
      taxRate: taxRate ?? this.taxRate,
      sku: sku ?? this.sku,
      companyId: companyId ?? this.companyId,
      businessUnitId: businessUnitId ?? this.businessUnitId,
      businessUnitCode: businessUnitCode ?? this.businessUnitCode,
      businessUnitType: businessUnitType ?? this.businessUnitType,
      syncStatus: syncStatus ?? this.syncStatus,
      localId: localId ?? this.localId,
    );
  }

  @override
  List<Object?> get props => [
    id,
    name,
    description,
    barcode,
    category,
    costPriceInCdf,
    sellingPriceInCdf,
    stockQuantity,
    unit,
    alertThreshold,
    createdAt,
    updatedAt,
    imagePath,
    imageUrl,
    inputCurrencyCode,
    inputExchangeRate,
    costPriceInInputCurrency,
    sellingPriceInInputCurrency,
    supplierIds,
    tags,
    taxRate,
    sku,
    companyId,
    businessUnitId,
    businessUnitCode,
    businessUnitType,
    syncStatus,
    localId,
  ];
}
