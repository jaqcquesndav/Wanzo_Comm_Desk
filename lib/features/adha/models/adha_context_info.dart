import 'package:hive/hive.dart';

part 'adha_context_info.g.dart';

// Enum for the type of interaction
// ⚠️ Important: Seuls ces deux types sont supportés par le backend selon la documentation
@HiveType(typeId: 107)
enum AdhaInteractionType {
  /// Analyse générique (pour les interactions initiales ou cartes)
  @HiveField(0)
  genericCardAnalysis,

  /// Suivi de conversation (pour les messages de suivi)
  @HiveField(1)
  followUp,
}

extension AdhaInteractionTypeExtension on AdhaInteractionType {
  String get value {
    switch (this) {
      case AdhaInteractionType.genericCardAnalysis:
        return 'generic_card_analysis';
      case AdhaInteractionType.followUp:
        return 'follow_up';
    }
  }

  static AdhaInteractionType fromString(String? value) {
    switch (value) {
      case 'generic_card_analysis':
        return AdhaInteractionType.genericCardAnalysis;
      case 'follow_up':
        return AdhaInteractionType.followUp;
      default:
        // Par défaut, retourner followUp pour les conversations existantes
        return AdhaInteractionType.followUp;
    }
  }
}

// ============================================================================
// MODÈLES DÉTAILLÉS SELON LA DOCUMENTATION BACKEND (Janvier 2026)
// ============================================================================

/// Entrée du journal des opérations
@HiveType(typeId: 108)
class AdhaOperationJournalEntry {
  @HiveField(0)
  final String timestamp;
  @HiveField(1)
  final String description;
  @HiveField(2)
  final String operationType;
  @HiveField(3)
  final Map<String, dynamic>? details;

  const AdhaOperationJournalEntry({
    required this.timestamp,
    required this.description,
    required this.operationType,
    this.details,
  });

  Map<String, dynamic> toJson() => {
    'timestamp': timestamp,
    'description': description,
    'operationType': operationType,
    if (details != null) 'details': details,
  };

  factory AdhaOperationJournalEntry.fromJson(Map<String, dynamic> json) {
    return AdhaOperationJournalEntry(
      timestamp: json['timestamp'] as String,
      description: json['description'] as String,
      operationType: json['operationType'] as String,
      details: json['details'] as Map<String, dynamic>?,
    );
  }
}

/// Résumé du journal des opérations
@HiveType(typeId: 110)
class AdhaOperationJournalSummary {
  @HiveField(0)
  final List<AdhaOperationJournalEntry> recentEntries;

  const AdhaOperationJournalSummary({required this.recentEntries});

  Map<String, dynamic> toJson() => {
    'recentEntries': recentEntries.map((e) => e.toJson()).toList(),
  };

  factory AdhaOperationJournalSummary.fromJson(Map<String, dynamic> json) {
    return AdhaOperationJournalSummary(
      recentEntries:
          (json['recentEntries'] as List<dynamic>?)
              ?.map(
                (e) => AdhaOperationJournalEntry.fromJson(
                  e as Map<String, dynamic>,
                ),
              )
              .toList() ??
          [],
    );
  }
}

/// Profil de l'entreprise
@HiveType(typeId: 109)
class AdhaBusinessProfile {
  @HiveField(0)
  final String name;
  @HiveField(1)
  final String? sector;
  @HiveField(2)
  final String? address;
  @HiveField(3)
  final Map<String, dynamic>? additionalInfo;

  const AdhaBusinessProfile({
    required this.name,
    this.sector,
    this.address,
    this.additionalInfo,
  });

  /// Convertit en JSON pour l'API
  /// Note: sector doit TOUJOURS être inclus comme string (même vide) car le backend l'exige
  Map<String, dynamic> toJson() => {
    'name': name,
    'sector':
        sector ??
        '', // Toujours inclure sector comme string (requis par le backend)
    if (address != null) 'address': address,
    if (additionalInfo != null) 'additionalInfo': additionalInfo,
  };

  factory AdhaBusinessProfile.fromJson(Map<String, dynamic> json) {
    return AdhaBusinessProfile(
      name: json['name'] as String? ?? 'Unknown Business',
      sector: json['sector'] as String?,
      address: json['address'] as String?,
      additionalInfo: json['additionalInfo'] as Map<String, dynamic>?,
    );
  }
}

// ============================================================================
// MODÈLES DE CONTEXTE PRINCIPAUX
// ============================================================================

// Represents the base context (always present)
@HiveType(typeId: 111)
class AdhaBaseContext {
  @HiveField(0)
  final AdhaOperationJournalSummary operationJournalSummary;
  @HiveField(1)
  final AdhaBusinessProfile businessProfile;

  AdhaBaseContext({
    required this.operationJournalSummary,
    required this.businessProfile,
  });

  Map<String, dynamic> toJson() {
    return {
      'operationJournalSummary': operationJournalSummary.toJson(),
      'businessProfile': businessProfile.toJson(),
    };
  }

  factory AdhaBaseContext.fromJson(Map<String, dynamic> json) {
    return AdhaBaseContext(
      operationJournalSummary: AdhaOperationJournalSummary.fromJson(
        json['operationJournalSummary'] as Map<String, dynamic>? ??
            {'recentEntries': []},
      ),
      businessProfile: AdhaBusinessProfile.fromJson(
        json['businessProfile'] as Map<String, dynamic>? ?? {'name': 'Unknown'},
      ),
    );
  }
}

// Represents the interaction-specific context
@HiveType(typeId: 112)
class AdhaInteractionContext {
  @HiveField(0)
  final AdhaInteractionType interactionType;
  @HiveField(1)
  final String? sourceIdentifier; // e.g., 'sales_analysis_card', 'user_direct_input'
  @HiveField(2)
  final Map<String, dynamic>? interactionData; // Optional data specific to the interaction

  AdhaInteractionContext({
    required this.interactionType,
    this.sourceIdentifier,
    this.interactionData,
  });

  Map<String, dynamic> toJson() {
    return {
      'interactionType': interactionType.value,
      if (sourceIdentifier != null) 'sourceIdentifier': sourceIdentifier,
      if (interactionData != null) 'interactionData': interactionData,
    };
  }

  factory AdhaInteractionContext.fromJson(Map<String, dynamic> json) {
    return AdhaInteractionContext(
      interactionType: AdhaInteractionTypeExtension.fromString(
        json['interactionType'] as String?,
      ),
      sourceIdentifier: json['sourceIdentifier'] as String?,
      interactionData: json['interactionData'] as Map<String, dynamic>?,
    );
  }
}

// Main context info class sent with each message
@HiveType(typeId: 113)
class AdhaContextInfo {
  @HiveField(0)
  final AdhaBaseContext baseContext;
  @HiveField(1)
  final AdhaInteractionContext interactionContext;

  AdhaContextInfo({
    required this.baseContext,
    required this.interactionContext,
  });

  Map<String, dynamic> toJson() {
    return {
      'baseContext': baseContext.toJson(),
      'interactionContext': interactionContext.toJson(),
    };
  }

  factory AdhaContextInfo.fromJson(Map<String, dynamic> json) {
    return AdhaContextInfo(
      baseContext: AdhaBaseContext.fromJson(
        json['baseContext'] as Map<String, dynamic>,
      ),
      interactionContext: AdhaInteractionContext.fromJson(
        json['interactionContext'] as Map<String, dynamic>,
      ),
    );
  }
}
