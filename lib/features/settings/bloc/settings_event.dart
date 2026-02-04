import 'package:equatable/equatable.dart';
import 'package:wanzo/core/enums/business_unit_enums.dart';
import '../models/settings.dart';

/// Événements pour le bloc Settings
abstract class SettingsEvent extends Equatable {
  const SettingsEvent();

  @override
  List<Object?> get props => [];
}

/// Chargement des paramètres
class LoadSettings extends SettingsEvent {
  const LoadSettings();
}

/// Mise à jour des paramètres
class UpdateSettings extends SettingsEvent {
  /// Paramètres mis à jour
  final Settings settings;

  const UpdateSettings(this.settings);

  @override
  List<Object?> get props => [settings];
}

/// Mise à jour des informations de l'entreprise
class UpdateCompanyInfo extends SettingsEvent {
  /// Nom de l'entreprise
  final String? companyName;

  /// Adresse de l'entreprise
  final String? companyAddress;

  /// Numéro de téléphone de l'entreprise
  final String? companyPhone;

  /// Email de l'entreprise
  final String? companyEmail;

  /// Logo de l'entreprise
  final String? companyLogo;

  /// Numéro d'identification fiscale
  final String? taxIdentificationNumber;

  /// Numéro RCCM (Registre du Commerce et du Crédit Mobilier)
  final String? rccmNumber;

  /// Numéro d'identification nationale
  final String? idNatNumber;

  /// ID de l'unité d'affaires
  final String? businessUnitId;

  /// Code de l'unité d'affaires
  final String? businessUnitCode;

  /// Type d'unité d'affaires
  final BusinessUnitType? businessUnitType;

  /// Nom de l'unité d'affaires
  final String? businessUnitName;

  /// DEPRECATED: Indique si c'est un point de vente (retail store)
  @Deprecated('Utiliser businessUnitType à la place')
  final bool? isRetailStore;

  const UpdateCompanyInfo({
    this.companyName,
    this.companyAddress,
    this.companyPhone,
    this.companyEmail,
    this.companyLogo,
    this.taxIdentificationNumber,
    this.rccmNumber,
    this.idNatNumber,
    this.businessUnitId,
    this.businessUnitCode,
    this.businessUnitType,
    this.businessUnitName,
    this.isRetailStore,
  });
  @override
  List<Object?> get props => [
    companyName,
    companyAddress,
    companyPhone,
    companyEmail,
    companyLogo,
    taxIdentificationNumber,
    rccmNumber,
    idNatNumber,
    businessUnitId,
    businessUnitCode,
    businessUnitType,
    businessUnitName,
    isRetailStore,
  ];
}

/// Mise à jour des paramètres de facture
class UpdateInvoiceSettings extends SettingsEvent {
  /// Format de numéro de facture
  final String? invoiceNumberFormat;

  /// Préfixe pour les numéros de facture
  final String? invoicePrefix;

  /// Conditions de paiement par défaut
  final String? defaultPaymentTerms;

  /// Notes par défaut
  final String? defaultInvoiceNotes;

  /// Afficher les taxes
  final bool? showTaxes;

  /// Taux de taxe par défaut
  final double? defaultTaxRate;

  const UpdateInvoiceSettings({
    this.invoiceNumberFormat,
    this.invoicePrefix,
    this.defaultPaymentTerms,
    this.defaultInvoiceNotes,
    this.showTaxes,
    this.defaultTaxRate,
  });

  @override
  List<Object?> get props => [
    invoiceNumberFormat,
    invoicePrefix,
    defaultPaymentTerms,
    defaultInvoiceNotes,
    showTaxes,
    defaultTaxRate,
  ];
}

/// Mise à jour des paramètres d'affichage
class UpdateDisplaySettings extends SettingsEvent {
  /// Thème de l'application
  final AppThemeMode? themeMode;

  /// Langue de l'application
  final String? language;

  /// Format de date
  final String? dateFormat;

  const UpdateDisplaySettings({this.themeMode, this.language, this.dateFormat});

  @override
  List<Object?> get props => [themeMode, language, dateFormat];
}

/// Mise à jour des paramètres de stock
class UpdateInventorySettings extends SettingsEvent {
  /// Catégorie de produit par défaut
  final String? defaultProductCategory;

  /// Jours pour les alertes de stock bas
  final int? lowStockAlertDays;

  const UpdateInventorySettings({
    this.defaultProductCategory,
    this.lowStockAlertDays,
  });

  @override
  List<Object?> get props => [defaultProductCategory, lowStockAlertDays];
}

/// Mise à jour des paramètres de sauvegarde
class UpdateBackupSettings extends SettingsEvent {
  /// Sauvegarde activée
  final bool? backupEnabled;

  /// Fréquence de sauvegarde
  final int? backupFrequency;

  /// Email pour les rapports
  final String? reportEmail;

  const UpdateBackupSettings({
    this.backupEnabled,
    this.backupFrequency,
    this.reportEmail,
  });

  @override
  List<Object?> get props => [backupEnabled, backupFrequency, reportEmail];
}

/// Mise à jour des paramètres de notification
class UpdateNotificationSettings extends SettingsEvent {
  /// Notifications push activées
  final bool pushNotificationsEnabled;

  /// Notifications in-app activées
  final bool inAppNotificationsEnabled;

  /// Notifications par email activées
  final bool emailNotificationsEnabled;

  /// Notifications sonores activées
  final bool soundNotificationsEnabled;

  const UpdateNotificationSettings({
    required this.pushNotificationsEnabled,
    required this.inAppNotificationsEnabled,
    required this.emailNotificationsEnabled,
    required this.soundNotificationsEnabled,
  });

  @override
  List<Object?> get props => [
    pushNotificationsEnabled,
    inAppNotificationsEnabled,
    emailNotificationsEnabled,
    soundNotificationsEnabled,
  ];
}

/// Réinitialisation des paramètres
class ResetSettings extends SettingsEvent {
  const ResetSettings();
}

/// Synchronisation des paramètres avec l'API
class SyncSettings extends SettingsEvent {
  /// Force la synchronisation même si les données sont récentes
  final bool force;

  const SyncSettings({this.force = false});

  @override
  List<Object?> get props => [force];
}

/// Synchronisation des paramètres avec l'API (chargement initial avec sync)
class LoadSettingsWithSync extends SettingsEvent {
  const LoadSettingsWithSync();
}
