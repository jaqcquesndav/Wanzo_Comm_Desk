import 'package:equatable/equatable.dart';
import 'package:hive/hive.dart';

part 'financing_request.g.dart'; // Uncommented for generation

@HiveType(typeId: 16) // Changed typeId to 16
enum FinancingType {
  @HiveField(0)
  cashCredit, // Crédit de trésorerie

  @HiveField(1)
  investmentCredit, // Crédit d'investissement

  @HiveField(2)
  leasing, // Leasing
  
  @HiveField(3)
  productionInputs, // Intrants de production
  
  @HiveField(4)
  merchandise, // Marchandise
}

extension FinancingTypeExtension on FinancingType {
  String get displayName {
    switch (this) {
      case FinancingType.cashCredit:
        return 'Crédit de trésorerie';
      case FinancingType.investmentCredit:
        return 'Crédit d\'investissement';
      case FinancingType.leasing:
        return 'Leasing';
      case FinancingType.productionInputs:
        return 'Intrants de production';
      case FinancingType.merchandise:
        return 'Marchandise';
      // No default needed as all cases are covered
    }
  }
}

@HiveType(typeId: 9) // Changed typeId to 9
enum FinancialInstitution {
  @HiveField(0)
  bonneMoisson,

  @HiveField(1)
  tid,

  @HiveField(2)
  smico,

  @HiveField(3)
  tmb,

  @HiveField(4)
  equitybcdc,

  @HiveField(5) // New entry
  wanzoPass, 
}

extension FinancialInstitutionExtension on FinancialInstitution {
  String get displayName {
    switch (this) {
      case FinancialInstitution.bonneMoisson:
        return 'Bonne Moisson';
      case FinancialInstitution.tid:
        return 'TID';
      case FinancialInstitution.smico:
        return 'SMICO';
      case FinancialInstitution.tmb:
        return 'TMB';
      case FinancialInstitution.equitybcdc:
        return 'EquityBCDC';
      case FinancialInstitution.wanzoPass: // New entry
        return 'Wanzo Pass';
      // No default needed as all cases are covered
    }
  }
}

@HiveType(typeId: 17) // Nouveau type pour les produits financiers
enum FinancialProduct {
  @HiveField(0)
  cashFlow, // Crédit de trésorerie

  @HiveField(1)
  investment, // Crédit d'investissement

  @HiveField(2)
  equipment, // Équipement (leasing)
  
  @HiveField(3)
  agricultural, // Produits agricoles
  
  @HiveField(4)
  commercialGoods, // Marchandises commerciales
}

extension FinancialProductExtension on FinancialProduct {
  String get displayName {
    switch (this) {
      case FinancialProduct.cashFlow:
        return 'Crédit de trésorerie';
      case FinancialProduct.investment:
        return 'Crédit d\'investissement';
      case FinancialProduct.equipment:
        return 'Équipement (leasing)';
      case FinancialProduct.agricultural:
        return 'Produits agricoles';
      case FinancialProduct.commercialGoods:
        return 'Marchandises commerciales';
    }
  }
}

@HiveType(typeId: 8) // Changed typeId to 8
class FinancingRequest extends Equatable {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final double amount;

  @HiveField(2)
  final String currency;

  @HiveField(3)
  final String reason;

  @HiveField(4)
  final FinancingType type;

  @HiveField(5)
  final FinancialInstitution institution;

  @HiveField(6)
  final DateTime requestDate;

  @HiveField(7)
  final String status; // e.g., pending, approved, rejected
  
  @HiveField(8)
  final DateTime? approvalDate;
  
  @HiveField(9)
  final DateTime? disbursementDate;
  
  @HiveField(10)
  final List<DateTime>? scheduledPayments;
  
  @HiveField(11)
  final List<DateTime>? completedPayments;
  
  @HiveField(12)
  final String? notes;
  
  @HiveField(13)
  final double? interestRate;
  
  @HiveField(14)
  final int? termMonths;
  
  @HiveField(15)
  final double? monthlyPayment;
  
  @HiveField(16) // Modified for multiple attachments
  final List<String>? attachmentPaths;
  
  @HiveField(17) // Produit financier (crédit d'investissement ou de trésorerie)
  final FinancialProduct? financialProduct;
  
  @HiveField(18) // Code de leasing pour Wanzo Store
  final String? leasingCode;
  
  @HiveField(19) // ID du portefeuille (backend)
  final String? portfolioId;
  
  @HiveField(20) // ID du client (backend)
  final String? clientId;
  
  @HiveField(21) // Nom de l'entreprise
  final String? companyName;
  
  @HiveField(22) // Type de produit (backend)
  final String? productType;
  
  @HiveField(23) // Durée en mois
  final int? duration;
  
  @HiveField(24) // Unité de durée
  final String? durationUnit;
  
  @HiveField(25) // Date de début proposée
  final DateTime? proposedStartDate;
  
  @HiveField(26) // Données financières structurées
  final Map<String, dynamic>? financialData;
  
  @HiveField(27) // Garanties structurées
  final List<Map<String, dynamic>>? guarantees;
  
  @HiveField(28) // Numéro de demande généré par le backend
  final String? requestNumber;
  
  @HiveField(29) // Date de dernier changement de statut
  final DateTime? statusDate;
  
  // ============================================================
  // XGBOOST CREDIT SCORING SYSTEM - Machine Learning Integration
  // ============================================================
  
  @HiveField(30) // Score de crédit calculé par le modèle XGBoost (0-1000)
  final int? creditScore;
  
  @HiveField(31) // Date et heure de calcul du score
  final DateTime? creditScoreCalculatedAt;
  
  @HiveField(32) // Date de validité du score (généralement 30-90 jours)
  final DateTime? creditScoreValidUntil;
  
  @HiveField(33) // Version du modèle XGBoost utilisé (ex: "v1.2.3")
  final String? creditScoreModelVersion;
  
  @HiveField(34) // Niveau de risque: LOW, MEDIUM, HIGH, VERY_HIGH
  final String? riskLevel;
  
  @HiveField(35) // Score de confiance du modèle (0.0-1.0)
  final double? confidenceScore;
  
  @HiveField(36) // Source des données: TRANSACTION_HISTORY, BUSINESS_PROFILE, HYBRID
  final String? creditScoreDataSource;
  
  @HiveField(37) // Composants du score avec leurs poids (ex: {payment_history: 350, debt_ratio: 200, ...})
  final Map<String, int>? creditScoreComponents;
  
  @HiveField(38) // Explications détaillées des facteurs influençant le score
  final List<String>? creditScoreExplanation;
  
  @HiveField(39) // Recommandations pour améliorer le score
  final List<String>? creditScoreRecommendations;

  const FinancingRequest({
    required this.id,
    required this.amount,
    required this.currency,
    required this.reason,
    required this.type,
    required this.institution,
    required this.requestDate,
    this.status = 'pending',
    this.approvalDate,
    this.disbursementDate,
    this.scheduledPayments,
    this.completedPayments,
    this.notes,
    this.interestRate,
    this.termMonths,
    this.monthlyPayment,
    this.attachmentPaths, // Modified for multiple attachments
    this.financialProduct, // Produit financier
    this.leasingCode, // Code de leasing
    this.portfolioId, // ID du portefeuille
    this.clientId, // ID du client
    this.companyName, // Nom de l'entreprise
    this.productType, // Type de produit
    this.duration, // Durée
    this.durationUnit, // Unité de durée
    this.proposedStartDate, // Date de début proposée
    this.financialData, // Données financières
    this.guarantees, // Garanties
    this.requestNumber, // Numéro de demande
    this.statusDate, // Date de changement de statut
    // XGBoost Credit Scoring parameters
    this.creditScore,
    this.creditScoreCalculatedAt,
    this.creditScoreValidUntil,
    this.creditScoreModelVersion,
    this.riskLevel,
    this.confidenceScore,
    this.creditScoreDataSource,
    this.creditScoreComponents,
    this.creditScoreExplanation,
    this.creditScoreRecommendations,
  });

  @override
  List<Object?> get props => [
        id,
        amount,
        currency,
        reason,
        type,
        institution,
        requestDate,
        status,
        approvalDate,
        disbursementDate,
        scheduledPayments,
        completedPayments,
        notes,
        interestRate,
        termMonths,
        monthlyPayment,
        attachmentPaths,
        financialProduct,
        leasingCode,
        portfolioId,
        clientId,
        companyName,
        productType,
        duration,
        durationUnit,
        proposedStartDate,
        financialData,
        guarantees,
        requestNumber,
        statusDate,
        // XGBoost Credit Scoring
        creditScore,
        creditScoreCalculatedAt,
        creditScoreValidUntil,
        creditScoreModelVersion,
        riskLevel,
        confidenceScore,
        creditScoreDataSource,
        creditScoreComponents,
        creditScoreExplanation,
        creditScoreRecommendations,
      ];

  FinancingRequest copyWith({
    String? id,
    double? amount,
    String? currency,
    String? reason,
    FinancingType? type,
    FinancialInstitution? institution,
    DateTime? requestDate,
    String? status,
    DateTime? approvalDate,
    DateTime? disbursementDate,
    List<DateTime>? scheduledPayments,
    List<DateTime>? completedPayments,
    String? notes,
    double? interestRate,
    int? termMonths,
    double? monthlyPayment,
    List<String>? attachmentPaths,
    FinancialProduct? financialProduct,
    String? leasingCode,
    String? portfolioId,
    String? clientId,
    String? companyName,
    String? productType,
    int? duration,
    String? durationUnit,
    DateTime? proposedStartDate,
    Map<String, dynamic>? financialData,
    List<Map<String, dynamic>>? guarantees,
    String? requestNumber,
    DateTime? statusDate,
    // XGBoost Credit Scoring parameters
    int? creditScore,
    DateTime? creditScoreCalculatedAt,
    DateTime? creditScoreValidUntil,
    String? creditScoreModelVersion,
    String? riskLevel,
    double? confidenceScore,
    String? creditScoreDataSource,
    Map<String, int>? creditScoreComponents,
    List<String>? creditScoreExplanation,
    List<String>? creditScoreRecommendations,
  }) {
    return FinancingRequest(
      id: id ?? this.id,
      amount: amount ?? this.amount,
      currency: currency ?? this.currency,
      reason: reason ?? this.reason,
      type: type ?? this.type,
      institution: institution ?? this.institution,
      requestDate: requestDate ?? this.requestDate,
      status: status ?? this.status,
      approvalDate: approvalDate ?? this.approvalDate,
      disbursementDate: disbursementDate ?? this.disbursementDate,
      scheduledPayments: scheduledPayments ?? this.scheduledPayments,
      completedPayments: completedPayments ?? this.completedPayments,
      notes: notes ?? this.notes,
      interestRate: interestRate ?? this.interestRate,
      termMonths: termMonths ?? this.termMonths,
      monthlyPayment: monthlyPayment ?? this.monthlyPayment,
      attachmentPaths: attachmentPaths ?? this.attachmentPaths,
      financialProduct: financialProduct ?? this.financialProduct,
      leasingCode: leasingCode ?? this.leasingCode,
      portfolioId: portfolioId ?? this.portfolioId,
      clientId: clientId ?? this.clientId,
      companyName: companyName ?? this.companyName,
      productType: productType ?? this.productType,
      duration: duration ?? this.duration,
      durationUnit: durationUnit ?? this.durationUnit,
      proposedStartDate: proposedStartDate ?? this.proposedStartDate,
      financialData: financialData ?? this.financialData,
      guarantees: guarantees ?? this.guarantees,
      requestNumber: requestNumber ?? this.requestNumber,
      statusDate: statusDate ?? this.statusDate,
      // XGBoost Credit Scoring
      creditScore: creditScore ?? this.creditScore,
      creditScoreCalculatedAt: creditScoreCalculatedAt ?? this.creditScoreCalculatedAt,
      creditScoreValidUntil: creditScoreValidUntil ?? this.creditScoreValidUntil,
      creditScoreModelVersion: creditScoreModelVersion ?? this.creditScoreModelVersion,
      riskLevel: riskLevel ?? this.riskLevel,
      confidenceScore: confidenceScore ?? this.confidenceScore,
      creditScoreDataSource: creditScoreDataSource ?? this.creditScoreDataSource,
      creditScoreComponents: creditScoreComponents ?? this.creditScoreComponents,
      creditScoreExplanation: creditScoreExplanation ?? this.creditScoreExplanation,
      creditScoreRecommendations: creditScoreRecommendations ?? this.creditScoreRecommendations,
    );
  }

  // Méthode pour convertir un JSON en FinancingRequest
  factory FinancingRequest.fromJson(Map<String, dynamic> json) {
    return FinancingRequest(
      id: json['id'] as String,
      amount: (json['amount'] is int) ? (json['amount'] as int).toDouble() : json['amount'] as double,
      currency: json['currency'] as String,
      reason: json['reason'] as String,
      type: _parseFinancingType(json['type']),
      institution: _parseFinancialInstitution(json['institution']),
      requestDate: DateTime.parse(json['requestDate'] as String),
      status: json['status'] as String? ?? 'pending',
      approvalDate: json['approvalDate'] != null ? DateTime.parse(json['approvalDate'] as String) : null,
      disbursementDate: json['disbursementDate'] != null ? DateTime.parse(json['disbursementDate'] as String) : null,
      scheduledPayments: json['scheduledPayments'] != null
          ? (json['scheduledPayments'] as List).map((e) => DateTime.parse(e as String)).toList()
          : null,
      completedPayments: json['completedPayments'] != null
          ? (json['completedPayments'] as List).map((e) => DateTime.parse(e as String)).toList()
          : null,
      notes: json['notes'] as String?,
      interestRate: json['interestRate'] != null 
          ? (json['interestRate'] is int) 
              ? (json['interestRate'] as int).toDouble() 
              : json['interestRate'] as double 
          : null,
      termMonths: json['termMonths'] as int?,
      monthlyPayment: json['monthlyPayment'] != null 
          ? (json['monthlyPayment'] is int) 
              ? (json['monthlyPayment'] as int).toDouble() 
              : json['monthlyPayment'] as double 
          : null,
      attachmentPaths: json['attachmentPaths'] != null
          ? (json['attachmentPaths'] as List).map((e) => e as String).toList()
          : null,
      financialProduct: json['financialProduct'] != null 
          ? _parseFinancialProduct(json['financialProduct']) 
          : null,
      leasingCode: json['leasingCode'] as String?,
      // XGBoost Credit Scoring fields
      creditScore: json['creditScore'] as int?,
      creditScoreCalculatedAt: json['creditScoreCalculatedAt'] != null 
          ? DateTime.parse(json['creditScoreCalculatedAt'] as String) 
          : null,
      creditScoreValidUntil: json['creditScoreValidUntil'] != null 
          ? DateTime.parse(json['creditScoreValidUntil'] as String) 
          : null,
      creditScoreModelVersion: json['creditScoreModelVersion'] as String?,
      riskLevel: json['riskLevel'] as String?,
      confidenceScore: json['confidenceScore'] != null 
          ? (json['confidenceScore'] is int) 
              ? (json['confidenceScore'] as int).toDouble() 
              : json['confidenceScore'] as double 
          : null,
      creditScoreDataSource: json['creditScoreDataSource'] as String?,
      creditScoreComponents: json['creditScoreComponents'] != null
          ? Map<String, int>.from(json['creditScoreComponents'] as Map)
          : null,
      creditScoreExplanation: json['creditScoreExplanation'] != null
          ? (json['creditScoreExplanation'] as List).map((e) => e as String).toList()
          : null,
      creditScoreRecommendations: json['creditScoreRecommendations'] != null
          ? (json['creditScoreRecommendations'] as List).map((e) => e as String).toList()
          : null,
    );
  }

  // Méthode pour convertir un FinancingRequest en JSON
  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{
      'id': id,
      'amount': amount,
      'currency': currency,
      'reason': reason,
      'type': type.toString().split('.').last,
      'institution': institution.toString().split('.').last,
      'requestDate': requestDate.toIso8601String(),
      'status': status,
    };

    if (approvalDate != null) {
      data['approvalDate'] = approvalDate!.toIso8601String();
    }
    if (disbursementDate != null) {
      data['disbursementDate'] = disbursementDate!.toIso8601String();
    }
    if (scheduledPayments != null) {
      data['scheduledPayments'] = scheduledPayments!.map((date) => date.toIso8601String()).toList();
    }
    if (completedPayments != null) {
      data['completedPayments'] = completedPayments!.map((date) => date.toIso8601String()).toList();
    }
    if (notes != null) {
      data['notes'] = notes;
    }
    if (interestRate != null) {
      data['interestRate'] = interestRate;
    }
    if (termMonths != null) {
      data['termMonths'] = termMonths;
    }
    if (monthlyPayment != null) {
      data['monthlyPayment'] = monthlyPayment;
    }
    if (attachmentPaths != null) {
      data['attachmentPaths'] = attachmentPaths;
    }
    if (financialProduct != null) {
      data['financialProduct'] = financialProduct.toString().split('.').last;
    }
    if (leasingCode != null) {
      data['leasingCode'] = leasingCode;
    }
    // XGBoost Credit Scoring fields
    if (creditScore != null) {
      data['creditScore'] = creditScore;
    }
    if (creditScoreCalculatedAt != null) {
      data['creditScoreCalculatedAt'] = creditScoreCalculatedAt!.toIso8601String();
    }
    if (creditScoreValidUntil != null) {
      data['creditScoreValidUntil'] = creditScoreValidUntil!.toIso8601String();
    }
    if (creditScoreModelVersion != null) {
      data['creditScoreModelVersion'] = creditScoreModelVersion;
    }
    if (riskLevel != null) {
      data['riskLevel'] = riskLevel;
    }
    if (confidenceScore != null) {
      data['confidenceScore'] = confidenceScore;
    }
    if (creditScoreDataSource != null) {
      data['creditScoreDataSource'] = creditScoreDataSource;
    }
    if (creditScoreComponents != null) {
      data['creditScoreComponents'] = creditScoreComponents;
    }
    if (creditScoreExplanation != null) {
      data['creditScoreExplanation'] = creditScoreExplanation;
    }
    if (creditScoreRecommendations != null) {
      data['creditScoreRecommendations'] = creditScoreRecommendations;
    }

    return data;
  }

  // Méthodes d'aide pour analyser les énumérations à partir de chaînes
  static FinancingType _parseFinancingType(dynamic value) {
    if (value is FinancingType) {
      return value;
    }
    
    final String strValue = value.toString().toLowerCase();
    
    for (var type in FinancingType.values) {
      if (type.toString().split('.').last.toLowerCase() == strValue) {
        return type;
      }
    }
    
    // Valeur par défaut si non trouvée
    return FinancingType.cashCredit;
  }

  static FinancialInstitution _parseFinancialInstitution(dynamic value) {
    if (value is FinancialInstitution) {
      return value;
    }
    
    final String strValue = value.toString().toLowerCase();
    
    for (var institution in FinancialInstitution.values) {
      if (institution.toString().split('.').last.toLowerCase() == strValue) {
        return institution;
      }
    }
    
    // Valeur par défaut si non trouvée
    return FinancialInstitution.bonneMoisson;
  }
  
  static FinancialProduct _parseFinancialProduct(dynamic value) {
    if (value is FinancialProduct) {
      return value;
    }
    
    final String strValue = value.toString().toLowerCase();
    
    for (var product in FinancialProduct.values) {
      if (product.toString().split('.').last.toLowerCase() == strValue) {
        return product;
      }
    }
    
    // Valeur par défaut si non trouvée
    return FinancialProduct.cashFlow;
  }
}
