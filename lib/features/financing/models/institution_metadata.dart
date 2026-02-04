import 'package:equatable/equatable.dart';
import 'package:hive/hive.dart';
import 'financing_request.dart';

part 'institution_metadata.g.dart';

/// Métadonnées des produits financiers par institution
@HiveType(typeId: 18)
class InstitutionMetadata extends Equatable {
  @HiveField(0)
  final FinancialInstitution institution;
  
  @HiveField(1)
  final String portfolioId;
  
  @HiveField(2)
  final String institutionName;
  
  @HiveField(3)
  final List<FinancialProductInfo> availableProducts;
  
  @HiveField(4)
  final Map<String, dynamic> institutionConfig;
  
  @HiveField(5)
  final DateTime lastUpdated;

  const InstitutionMetadata({
    required this.institution,
    required this.portfolioId,
    required this.institutionName,
    required this.availableProducts,
    required this.institutionConfig,
    required this.lastUpdated,
  });

  @override
  List<Object?> get props => [
    institution,
    portfolioId,
    institutionName,
    availableProducts,
    institutionConfig,
    lastUpdated,
  ];

  InstitutionMetadata copyWith({
    FinancialInstitution? institution,
    String? portfolioId,
    String? institutionName,
    List<FinancialProductInfo>? availableProducts,
    Map<String, dynamic>? institutionConfig,
    DateTime? lastUpdated,
  }) {
    return InstitutionMetadata(
      institution: institution ?? this.institution,
      portfolioId: portfolioId ?? this.portfolioId,
      institutionName: institutionName ?? this.institutionName,
      availableProducts: availableProducts ?? this.availableProducts,
      institutionConfig: institutionConfig ?? this.institutionConfig,
      lastUpdated: lastUpdated ?? this.lastUpdated,
    );
  }

  factory InstitutionMetadata.fromJson(Map<String, dynamic> json) {
    return InstitutionMetadata(
      institution: _parseFinancialInstitution(json['institution']),
      portfolioId: json['portfolio_id'] as String,
      institutionName: json['institution_name'] as String,
      availableProducts: (json['available_products'] as List)
          .map((p) => FinancialProductInfo.fromJson(p))
          .toList(),
      institutionConfig: json['institution_config'] as Map<String, dynamic>? ?? {},
      lastUpdated: DateTime.parse(json['last_updated'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'institution': institution.toString().split('.').last,
      'portfolio_id': portfolioId,
      'institution_name': institutionName,
      'available_products': availableProducts.map((p) => p.toJson()).toList(),
      'institution_config': institutionConfig,
      'last_updated': lastUpdated.toIso8601String(),
    };
  }

  static FinancialInstitution _parseFinancialInstitution(dynamic value) {
    if (value is FinancialInstitution) return value;
    
    final String strValue = value.toString().toLowerCase();
    for (var institution in FinancialInstitution.values) {
      if (institution.toString().split('.').last.toLowerCase() == strValue) {
        return institution;
      }
    }
    return FinancialInstitution.bonneMoisson;
  }
}

/// Informations sur un produit financier spécifique
@HiveType(typeId: 19)
class FinancialProductInfo extends Equatable {
  @HiveField(0)
  final String productId;
  
  @HiveField(1)
  final String productType;
  
  @HiveField(2)
  final String productName;
  
  @HiveField(3)
  final String description;
  
  @HiveField(4)
  final double minAmount;
  
  @HiveField(5)
  final double maxAmount;
  
  @HiveField(6)
  final int minDurationMonths;
  
  @HiveField(7)
  final int maxDurationMonths;
  
  @HiveField(8)
  final double baseInterestRate;
  
  @HiveField(9)
  final List<String> requiredDocuments;
  
  @HiveField(10)
  final Map<String, dynamic> productConfig;

  const FinancialProductInfo({
    required this.productId,
    required this.productType,
    required this.productName,
    required this.description,
    required this.minAmount,
    required this.maxAmount,
    required this.minDurationMonths,
    required this.maxDurationMonths,
    required this.baseInterestRate,
    required this.requiredDocuments,
    required this.productConfig,
  });

  @override
  List<Object?> get props => [
    productId,
    productType,
    productName,
    description,
    minAmount,
    maxAmount,
    minDurationMonths,
    maxDurationMonths,
    baseInterestRate,
    requiredDocuments,
    productConfig,
  ];

  factory FinancialProductInfo.fromJson(Map<String, dynamic> json) {
    return FinancialProductInfo(
      productId: json['product_id'] as String,
      productType: json['product_type'] as String,
      productName: json['product_name'] as String,
      description: json['description'] as String? ?? '',
      minAmount: (json['min_amount'] as num).toDouble(),
      maxAmount: (json['max_amount'] as num).toDouble(),
      minDurationMonths: json['min_duration_months'] as int,
      maxDurationMonths: json['max_duration_months'] as int,
      baseInterestRate: (json['base_interest_rate'] as num).toDouble(),
      requiredDocuments: (json['required_documents'] as List?)
          ?.map((d) => d.toString()).toList() ?? [],
      productConfig: json['product_config'] as Map<String, dynamic>? ?? {},
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'product_id': productId,
      'product_type': productType,
      'product_name': productName,
      'description': description,
      'min_amount': minAmount,
      'max_amount': maxAmount,
      'min_duration_months': minDurationMonths,
      'max_duration_months': maxDurationMonths,
      'base_interest_rate': baseInterestRate,
      'required_documents': requiredDocuments,
      'product_config': productConfig,
    };
  }

  /// Vérifie si un montant est dans la fourchette autorisée
  bool isAmountValid(double amount) {
    return amount >= minAmount && amount <= maxAmount;
  }

  /// Vérifie si une durée est dans la fourchette autorisée
  bool isDurationValid(int durationMonths) {
    return durationMonths >= minDurationMonths && durationMonths <= maxDurationMonths;
  }

  /// Formatage du nom d'affichage avec les limites
  String get displayNameWithLimits {
    return '$productName (${minAmount.toStringAsFixed(0)} - ${maxAmount.toStringAsFixed(0)}, $minDurationMonths-$maxDurationMonths mois)';
  }
}
