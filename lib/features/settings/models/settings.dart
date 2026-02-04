import 'package:equatable/equatable.dart';
import 'package:hive/hive.dart';
import 'package:json_annotation/json_annotation.dart';
import 'package:wanzo/core/enums/currency_enum.dart';
import 'package:wanzo/core/enums/business_unit_enums.dart';

part 'settings.g.dart';

/// Modèle pour les paramètres de l'application
@HiveType(typeId: 26) // Existing typeId for Settings
@JsonSerializable(explicitToJson: true)
class Settings extends Equatable {
  /// Nom de l'entreprise
  @HiveField(0)
  final String companyName;

  /// Adresse de l'entreprise
  @HiveField(1)
  final String companyAddress;

  /// Numéro de téléphone de l'entreprise
  @HiveField(2)
  final String companyPhone;

  /// Email de l'entreprise
  @HiveField(3)
  final String companyEmail;

  /// Logo de l'entreprise (chemin du fichier)
  @HiveField(4)
  final String companyLogo;

  /// Format de date préféré
  @HiveField(6)
  final String dateFormat;

  /// Format d'heure préféré (conformément à l'API documentation)
  @HiveField(33)
  final String timeFormat;

  /// Thème de l'application
  @HiveField(7)
  final AppThemeMode themeMode;

  /// Langue de l'application
  @HiveField(8)
  final String language;

  /// Afficher les taxes sur les factures
  @HiveField(9)
  final bool showTaxes;

  /// Taux de taxe par défaut (en pourcentage)
  @HiveField(10)
  final double defaultTaxRate;

  /// Format de numéro de facture
  @HiveField(11)
  final String invoiceNumberFormat;

  /// Préfixe pour les numéros de facture
  @HiveField(12)
  final String invoicePrefix;

  /// Conditions de paiement par défaut pour les factures
  @HiveField(13)
  final String defaultPaymentTerms;

  /// Notes par défaut à afficher sur les factures
  @HiveField(14)
  final String defaultInvoiceNotes;

  /// Numéro d'identification fiscale
  @HiveField(15)
  final String taxIdentificationNumber;

  /// Catégorie de stock par défaut pour les nouveaux produits
  @HiveField(16)
  final String defaultProductCategory;

  /// Nombre de jours pour les alertes de stock bas
  @HiveField(17)
  final int lowStockAlertDays;

  /// Options de sauvegarde activées
  @HiveField(18)
  final bool backupEnabled;

  /// Fréquence de sauvegarde automatique (en jours)
  @HiveField(19)
  final int backupFrequency;

  /// Email pour les rapports automatiques
  @HiveField(20)
  final String reportEmail;

  /// Numéro RCCM (Registre du Commerce et du Crédit Mobilier)
  @HiveField(21)
  final String rccmNumber;

  /// Numéro d'identification nationale
  @HiveField(22)
  final String idNatNumber;

  /// Notifications push activées
  @HiveField(23)
  final bool pushNotificationsEnabled;

  /// Notifications in-app activées
  @HiveField(24)
  final bool inAppNotificationsEnabled;

  /// Notifications par email activées
  @HiveField(25)
  final bool emailNotificationsEnabled;

  /// Notifications sonores activées
  @HiveField(26)
  final bool soundNotificationsEnabled;

  /// Devise active pour l'application
  @HiveField(27)
  final Currency activeCurrency;

  /// ID de l'unité d'affaires courante (business unit)
  /// Null signifie niveau entreprise par défaut
  @HiveField(28)
  final String? businessUnitId;

  /// Code de l'unité d'affaires courante (ex: BRN-001, POS-002)
  @HiveField(29)
  final String? businessUnitCode;

  /// Type de l'unité d'affaires (company, branch, pos)
  @HiveField(30)
  final BusinessUnitType businessUnitType;

  /// Nom de l'unité d'affaires courante
  @HiveField(31)
  final String? businessUnitName;

  /// DEPRECATED: Remplacé par businessUnitType
  /// Conservé pour la migration des données existantes
  @HiveField(32)
  @Deprecated('Utiliser businessUnitType à la place')
  final bool isRetailStore;

  /// Liens vers les réseaux sociaux (conformément à l'API documentation)
  @HiveField(34)
  final Map<String, String>? socialMediaLinks;

  /// Mode maintenance (conformément à l'API documentation)
  @HiveField(35)
  final bool maintenanceMode;

  const Settings({
    this.companyName = '',
    this.companyAddress = '',
    this.companyPhone = '',
    this.companyEmail = '',
    this.companyLogo = '',
    this.dateFormat = 'DD/MM/YYYY',
    this.timeFormat = 'HH:mm',
    this.themeMode = AppThemeMode.light,
    this.language = 'fr',
    this.showTaxes = true,
    this.defaultTaxRate = 16.0,
    this.invoiceNumberFormat = 'INV-{YEAR}-{SEQ}',
    this.invoicePrefix = 'INV',
    this.defaultPaymentTerms = 'Paiement sous 30 jours',
    this.defaultInvoiceNotes = 'Merci pour votre confiance !',
    this.taxIdentificationNumber = '',
    this.defaultProductCategory = 'Général',
    this.lowStockAlertDays = 7,
    this.backupEnabled = false,
    this.backupFrequency = 7,
    this.reportEmail = '',
    this.rccmNumber = '',
    this.idNatNumber = '',
    this.pushNotificationsEnabled = true,
    this.inAppNotificationsEnabled = true,
    this.emailNotificationsEnabled = false,
    this.soundNotificationsEnabled = true,
    this.activeCurrency = Currency.CDF,
    this.businessUnitId,
    this.businessUnitCode,
    this.businessUnitType =
        BusinessUnitType.company, // Par défaut: niveau entreprise
    this.businessUnitName,
    this.isRetailStore = false, // DEPRECATED - conservé pour migration
    this.socialMediaLinks,
    this.maintenanceMode = false,
  });

  factory Settings.fromJson(Map<String, dynamic> json) =>
      _$SettingsFromJson(json);
  Map<String, dynamic> toJson() => _$SettingsToJson(this);

  Settings copyWith({
    String? companyName,
    String? companyAddress,
    String? companyPhone,
    String? companyEmail,
    String? companyLogo,
    String? dateFormat,
    String? timeFormat,
    AppThemeMode? themeMode,
    String? language,
    bool? showTaxes,
    double? defaultTaxRate,
    String? invoiceNumberFormat,
    String? invoicePrefix,
    String? defaultPaymentTerms,
    String? defaultInvoiceNotes,
    String? taxIdentificationNumber,
    String? defaultProductCategory,
    int? lowStockAlertDays,
    bool? backupEnabled,
    int? backupFrequency,
    String? reportEmail,
    String? rccmNumber,
    String? idNatNumber,
    bool? pushNotificationsEnabled,
    bool? inAppNotificationsEnabled,
    bool? emailNotificationsEnabled,
    bool? soundNotificationsEnabled,
    Currency? activeCurrency,
    String? businessUnitId,
    String? businessUnitCode,
    BusinessUnitType? businessUnitType,
    String? businessUnitName,
    bool? isRetailStore,
    Map<String, String>? socialMediaLinks,
    bool? maintenanceMode,
  }) {
    return Settings(
      companyName: companyName ?? this.companyName,
      companyAddress: companyAddress ?? this.companyAddress,
      companyPhone: companyPhone ?? this.companyPhone,
      companyEmail: companyEmail ?? this.companyEmail,
      companyLogo: companyLogo ?? this.companyLogo,
      dateFormat: dateFormat ?? this.dateFormat,
      timeFormat: timeFormat ?? this.timeFormat,
      themeMode: themeMode ?? this.themeMode,
      language: language ?? this.language,
      showTaxes: showTaxes ?? this.showTaxes,
      defaultTaxRate: defaultTaxRate ?? this.defaultTaxRate,
      invoiceNumberFormat: invoiceNumberFormat ?? this.invoiceNumberFormat,
      invoicePrefix: invoicePrefix ?? this.invoicePrefix,
      defaultPaymentTerms: defaultPaymentTerms ?? this.defaultPaymentTerms,
      defaultInvoiceNotes: defaultInvoiceNotes ?? this.defaultInvoiceNotes,
      taxIdentificationNumber:
          taxIdentificationNumber ?? this.taxIdentificationNumber,
      defaultProductCategory:
          defaultProductCategory ?? this.defaultProductCategory,
      lowStockAlertDays: lowStockAlertDays ?? this.lowStockAlertDays,
      backupEnabled: backupEnabled ?? this.backupEnabled,
      backupFrequency: backupFrequency ?? this.backupFrequency,
      reportEmail: reportEmail ?? this.reportEmail,
      rccmNumber: rccmNumber ?? this.rccmNumber,
      idNatNumber: idNatNumber ?? this.idNatNumber,
      pushNotificationsEnabled:
          pushNotificationsEnabled ?? this.pushNotificationsEnabled,
      inAppNotificationsEnabled:
          inAppNotificationsEnabled ?? this.inAppNotificationsEnabled,
      emailNotificationsEnabled:
          emailNotificationsEnabled ?? this.emailNotificationsEnabled,
      soundNotificationsEnabled:
          soundNotificationsEnabled ?? this.soundNotificationsEnabled,
      activeCurrency: activeCurrency ?? this.activeCurrency,
      businessUnitId: businessUnitId ?? this.businessUnitId,
      businessUnitCode: businessUnitCode ?? this.businessUnitCode,
      businessUnitType: businessUnitType ?? this.businessUnitType,
      businessUnitName: businessUnitName ?? this.businessUnitName,
      isRetailStore: isRetailStore ?? this.isRetailStore,
      socialMediaLinks: socialMediaLinks ?? this.socialMediaLinks,
      maintenanceMode: maintenanceMode ?? this.maintenanceMode,
    );
  }

  @override
  List<Object?> get props => [
    companyName,
    companyAddress,
    companyPhone,
    companyEmail,
    companyLogo,
    dateFormat,
    timeFormat,
    themeMode,
    language,
    showTaxes,
    defaultTaxRate,
    invoiceNumberFormat,
    invoicePrefix,
    defaultPaymentTerms,
    defaultInvoiceNotes,
    taxIdentificationNumber,
    defaultProductCategory,
    lowStockAlertDays,
    backupEnabled,
    backupFrequency,
    reportEmail,
    rccmNumber,
    idNatNumber,
    pushNotificationsEnabled,
    inAppNotificationsEnabled,
    emailNotificationsEnabled,
    soundNotificationsEnabled,
    activeCurrency,
    businessUnitId,
    businessUnitCode,
    businessUnitType,
    businessUnitName,
    isRetailStore,
    socialMediaLinks,
    maintenanceMode,
  ];
}

/// Modes de thème pour l'application
@HiveType(typeId: 27) // Existing typeId for AppThemeMode
@JsonEnum()
enum AppThemeMode {
  @HiveField(0)
  light,
  @HiveField(1)
  dark,
  @HiveField(2)
  system,
}
