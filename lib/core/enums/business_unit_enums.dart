// filepath: lib/core/enums/business_unit_enums.dart
import 'package:hive/hive.dart';
import 'package:flutter/widgets.dart';
import 'package:wanzo/l10n/app_localizations.dart';

part 'business_unit_enums.g.dart';

/// Types d'unités d'affaires - Hiérarchie à 3 niveaux
/// COMPANY (niveau 0) -> BRANCH (niveau 1) -> POS (niveau 2)
@HiveType(typeId: 71)
enum BusinessUnitType {
  /// Entreprise principale - Niveau 0 (racine de la hiérarchie)
  @HiveField(0)
  company,

  /// Succursale/Agence - Niveau 1 (parent: COMPANY uniquement)
  @HiveField(1)
  branch,

  /// Point de Vente - Niveau 2 (parent: COMPANY ou BRANCH)
  @HiveField(2)
  pos,
}

extension BusinessUnitTypeExtension on BusinessUnitType {
  /// Code string pour l'API (alias pour apiValue)
  String get code {
    switch (this) {
      case BusinessUnitType.company:
        return 'company';
      case BusinessUnitType.branch:
        return 'branch';
      case BusinessUnitType.pos:
        return 'pos';
    }
  }

  /// Valeur API (utilisée pour la sérialisation JSON)
  String get apiValue => code;

  /// Niveau dans la hiérarchie (0, 1 ou 2)
  int get hierarchyLevel {
    switch (this) {
      case BusinessUnitType.company:
        return 0;
      case BusinessUnitType.branch:
        return 1;
      case BusinessUnitType.pos:
        return 2;
    }
  }

  /// Nom d'affichage localisé
  String displayName(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    switch (this) {
      case BusinessUnitType.company:
        return l10n.businessUnitTypeCompany;
      case BusinessUnitType.branch:
        return l10n.businessUnitTypeBranch;
      case BusinessUnitType.pos:
        return l10n.businessUnitTypePOS;
    }
  }

  /// Description courte localisée
  String description(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    switch (this) {
      case BusinessUnitType.company:
        return l10n.businessUnitTypeCompanyDesc;
      case BusinessUnitType.branch:
        return l10n.businessUnitTypeBranchDesc;
      case BusinessUnitType.pos:
        return l10n.businessUnitTypePOSDesc;
    }
  }

  /// Icône associée au type
  String get iconName {
    switch (this) {
      case BusinessUnitType.company:
        return 'business_center';
      case BusinessUnitType.branch:
        return 'account_balance';
      case BusinessUnitType.pos:
        return 'storefront';
    }
  }

  /// Conversion depuis une chaîne (alias pour fromApiValue)
  static BusinessUnitType fromString(String value) {
    return fromApiValue(value);
  }

  /// Conversion depuis la valeur API
  static BusinessUnitType fromApiValue(String value) {
    switch (value.toLowerCase()) {
      case 'company':
        return BusinessUnitType.company;
      case 'branch':
        return BusinessUnitType.branch;
      case 'pos':
        return BusinessUnitType.pos;
      default:
        return BusinessUnitType.company;
    }
  }
}

/// Statuts des unités d'affaires
@HiveType(typeId: 72)
enum BusinessUnitStatus {
  /// Unité opérationnelle
  @HiveField(0)
  active,

  /// Unité temporairement désactivée
  @HiveField(1)
  inactive,

  /// Unité suspendue (problème)
  @HiveField(2)
  suspended,

  /// Unité définitivement fermée
  @HiveField(3)
  closed,
}

extension BusinessUnitStatusExtension on BusinessUnitStatus {
  /// Code string pour l'API (alias pour apiValue)
  String get code {
    switch (this) {
      case BusinessUnitStatus.active:
        return 'active';
      case BusinessUnitStatus.inactive:
        return 'inactive';
      case BusinessUnitStatus.suspended:
        return 'suspended';
      case BusinessUnitStatus.closed:
        return 'closed';
    }
  }

  /// Valeur API (utilisée pour la sérialisation JSON)
  String get apiValue => code;

  /// Nom d'affichage localisé
  String displayName(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    switch (this) {
      case BusinessUnitStatus.active:
        return l10n.businessUnitStatusActive;
      case BusinessUnitStatus.inactive:
        return l10n.businessUnitStatusInactive;
      case BusinessUnitStatus.suspended:
        return l10n.businessUnitStatusSuspended;
      case BusinessUnitStatus.closed:
        return l10n.businessUnitStatusClosed;
    }
  }

  /// Conversion depuis une chaîne (alias pour fromApiValue)
  static BusinessUnitStatus fromString(String value) {
    return fromApiValue(value);
  }

  /// Conversion depuis la valeur API
  static BusinessUnitStatus fromApiValue(String value) {
    switch (value.toLowerCase()) {
      case 'active':
        return BusinessUnitStatus.active;
      case 'inactive':
        return BusinessUnitStatus.inactive;
      case 'suspended':
        return BusinessUnitStatus.suspended;
      case 'closed':
        return BusinessUnitStatus.closed;
      default:
        return BusinessUnitStatus.active;
    }
  }
}
