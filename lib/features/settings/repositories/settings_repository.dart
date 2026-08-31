import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';
import '../models/settings.dart';
import '../services/settings_api_service.dart';
import 'package:wanzo/core/enums/currency_enum.dart';

/// Repository pour gérer les paramètres de l'application
/// Supporte la synchronisation avec l'API et le fallback local Hive
class SettingsRepository {
  static const _settingsBoxName = 'settingsBox';
  static const _metadataBoxName = 'settingsMetadataBox';
  static const _settingsKey = 'app_settings';
  static const _lastSyncKey = 'settings_last_sync';

  late Box<Settings> _settingsBox;
  late Box<dynamic> _metadataBox;
  final SettingsApiService? _apiService;
  bool _isInitialized = false;

  /// Constructeur avec service API optionnel pour la synchronisation
  SettingsRepository({SettingsApiService? apiService})
    : _apiService = apiService;

  /// Initialise le repository
  Future<void> init() async {
    if (_isInitialized) return;

    debugPrint('📋 [SettingsRepository] Initializing...');
    _settingsBox = await Hive.openBox<Settings>(_settingsBoxName);
    _metadataBox = await Hive.openBox<dynamic>(_metadataBoxName);

    // Crée les paramètres par défaut s'ils n'existent pas
    if (!_settingsBox.containsKey(_settingsKey)) {
      debugPrint(
        '📋 [SettingsRepository] No local settings found, creating defaults',
      );
      await saveSettingsLocal(const Settings());
    }

    _isInitialized = true;
    debugPrint('📋 [SettingsRepository] Initialized successfully');
  }

  /// Synchronise les paramètres depuis l'API
  /// Retourne true si la sync a réussi, false sinon (fallback local)
  Future<bool> syncFromApi() async {
    if (_apiService == null) {
      debugPrint(
        '📋 [SettingsRepository] No API service configured, using local only',
      );
      return false;
    }

    try {
      debugPrint('📋 [SettingsRepository] Syncing settings from API...');
      final apiData = await _apiService.getSettings();

      debugPrint('📋 [SettingsRepository] API Response structure:');
      debugPrint('📋   Keys: ${apiData.keys.toList()}');
      debugPrint('📋   Raw data: $apiData');

      // Mapper les données API vers le modèle Settings
      final settings = _mapApiToSettings(apiData);

      // Sauvegarder localement
      await saveSettingsLocal(settings);

      // Marquer la date de dernière sync dans la box de métadonnées
      await _metadataBox.put(_lastSyncKey, DateTime.now().toIso8601String());

      debugPrint(
        '📋 [SettingsRepository] Settings synced successfully from API',
      );
      return true;
    } catch (e) {
      debugPrint('📋 [SettingsRepository] API sync failed: $e');
      debugPrint('📋 [SettingsRepository] Using local settings as fallback');
      return false;
    }
  }

  /// Récupère les paramètres actuels (local avec tentative de sync si API disponible)
  Future<Settings> getSettings() async {
    if (!_isInitialized) await init();

    // Retourne les paramètres locaux
    final localSettings = _settingsBox.get(_settingsKey) ?? const Settings();
    debugPrint(
      '📋 [SettingsRepository] Returning local settings: companyName=${localSettings.companyName}',
    );
    return localSettings;
  }

  /// Récupère les paramètres avec sync forcée depuis l'API
  Future<Settings> getSettingsWithSync() async {
    if (!_isInitialized) await init();

    // Tenter de synchroniser depuis l'API
    await syncFromApi();

    return getSettings();
  }

  /// Sauvegarde les paramètres localement uniquement
  Future<void> saveSettingsLocal(Settings settings) async {
    debugPrint('📋 [SettingsRepository] Saving settings locally');
    await _settingsBox.put(_settingsKey, settings);
  }

  /// Sauvegarde les paramètres (local + API si disponible)
  Future<void> saveSettings(Settings settings) async {
    // Toujours sauvegarder localement d'abord
    await saveSettingsLocal(settings);

    // Si l'API est disponible, synchroniser
    if (_apiService != null) {
      try {
        debugPrint('📋 [SettingsRepository] Syncing settings to API...');
        final apiData = _mapSettingsToApi(settings);
        debugPrint('📋 [SettingsRepository] Sending to API: $apiData');

        final response = await _apiService.updateSettings(apiData);
        debugPrint('📋 [SettingsRepository] API update response: $response');

        // Marquer la date de dernière sync dans la box de métadonnées
        await _metadataBox.put(_lastSyncKey, DateTime.now().toIso8601String());
      } catch (e) {
        debugPrint('📋 [SettingsRepository] Failed to sync to API: $e');
        // Les données sont déjà sauvées localement, pas d'action supplémentaire
      }
    }
  }

  /// Met à jour une partie des paramètres
  Future<Settings> updateSettings(Settings updates) async {
    final currentSettings = await getSettings();
    final newSettings = currentSettings.copyWith(
      companyName:
          updates.companyName.isNotEmpty
              ? updates.companyName
              : currentSettings.companyName,
      companyAddress:
          updates.companyAddress.isNotEmpty
              ? updates.companyAddress
              : currentSettings.companyAddress,
      companyPhone:
          updates.companyPhone.isNotEmpty
              ? updates.companyPhone
              : currentSettings.companyPhone,
      companyEmail:
          updates.companyEmail.isNotEmpty
              ? updates.companyEmail
              : currentSettings.companyEmail,
      companyLogo:
          updates.companyLogo.isNotEmpty
              ? updates.companyLogo
              : currentSettings.companyLogo,
      activeCurrency:
          updates.activeCurrency != currentSettings.activeCurrency
              ? updates.activeCurrency
              : currentSettings.activeCurrency,
      dateFormat:
          updates.dateFormat.isNotEmpty
              ? updates.dateFormat
              : currentSettings.dateFormat,
      timeFormat:
          updates.timeFormat.isNotEmpty
              ? updates.timeFormat
              : currentSettings.timeFormat,
      themeMode:
          updates.themeMode != currentSettings.themeMode
              ? updates.themeMode
              : currentSettings.themeMode,
      language:
          updates.language.isNotEmpty
              ? updates.language
              : currentSettings.language,
      showTaxes:
          updates.showTaxes != currentSettings.showTaxes
              ? updates.showTaxes
              : currentSettings.showTaxes,
      defaultTaxRate:
          updates.defaultTaxRate != currentSettings.defaultTaxRate
              ? updates.defaultTaxRate
              : currentSettings.defaultTaxRate,
      invoiceNumberFormat:
          updates.invoiceNumberFormat.isNotEmpty
              ? updates.invoiceNumberFormat
              : currentSettings.invoiceNumberFormat,
      invoicePrefix:
          updates.invoicePrefix.isNotEmpty
              ? updates.invoicePrefix
              : currentSettings.invoicePrefix,
      defaultPaymentTerms:
          updates.defaultPaymentTerms.isNotEmpty
              ? updates.defaultPaymentTerms
              : currentSettings.defaultPaymentTerms,
      defaultInvoiceNotes:
          updates.defaultInvoiceNotes.isNotEmpty
              ? updates.defaultInvoiceNotes
              : currentSettings.defaultInvoiceNotes,
      taxIdentificationNumber:
          updates.taxIdentificationNumber.isNotEmpty
              ? updates.taxIdentificationNumber
              : currentSettings.taxIdentificationNumber,
      defaultProductCategory:
          updates.defaultProductCategory.isNotEmpty
              ? updates.defaultProductCategory
              : currentSettings.defaultProductCategory,
      lowStockAlertDays:
          updates.lowStockAlertDays != currentSettings.lowStockAlertDays
              ? updates.lowStockAlertDays
              : currentSettings.lowStockAlertDays,
      backupEnabled:
          updates.backupEnabled != currentSettings.backupEnabled
              ? updates.backupEnabled
              : currentSettings.backupEnabled,
      backupFrequency:
          updates.backupFrequency != currentSettings.backupFrequency
              ? updates.backupFrequency
              : currentSettings.backupFrequency,
      reportEmail:
          updates.reportEmail.isNotEmpty
              ? updates.reportEmail
              : currentSettings.reportEmail,
      rccmNumber:
          updates.rccmNumber.isNotEmpty
              ? updates.rccmNumber
              : currentSettings.rccmNumber,
      idNatNumber:
          updates.idNatNumber.isNotEmpty
              ? updates.idNatNumber
              : currentSettings.idNatNumber,
      pushNotificationsEnabled:
          updates.pushNotificationsEnabled !=
                  currentSettings.pushNotificationsEnabled
              ? updates.pushNotificationsEnabled
              : currentSettings.pushNotificationsEnabled,
      inAppNotificationsEnabled:
          updates.inAppNotificationsEnabled !=
                  currentSettings.inAppNotificationsEnabled
              ? updates.inAppNotificationsEnabled
              : currentSettings.inAppNotificationsEnabled,
      emailNotificationsEnabled:
          updates.emailNotificationsEnabled !=
                  currentSettings.emailNotificationsEnabled
              ? updates.emailNotificationsEnabled
              : currentSettings.emailNotificationsEnabled,
      soundNotificationsEnabled:
          updates.soundNotificationsEnabled !=
                  currentSettings.soundNotificationsEnabled
              ? updates.soundNotificationsEnabled
              : currentSettings.soundNotificationsEnabled,
      socialMediaLinks:
          updates.socialMediaLinks ?? currentSettings.socialMediaLinks,
      maintenanceMode:
          updates.maintenanceMode != currentSettings.maintenanceMode
              ? updates.maintenanceMode
              : currentSettings.maintenanceMode,
    );

    await saveSettings(newSettings);
    return newSettings;
  }

  /// Réinitialise les paramètres à leurs valeurs par défaut
  Future<Settings> resetSettings() async {
    const defaultSettings = Settings();
    await saveSettings(defaultSettings);
    return defaultSettings;
  }

  /// Mapper les données API vers le modèle Settings
  Settings _mapApiToSettings(Map<String, dynamic> apiData) {
    debugPrint('📋 [SettingsRepository] Mapping API data to Settings model...');

    // Log each field mapping
    final companyName = apiData['companyName'] as String? ?? '';
    final companyLogoUrl =
        (apiData['companyLogoUrl'] ?? apiData['logoUrl']) as String? ?? '';
    // Identifiants légaux (NIF/Id Nat/RCCM) : accepter plusieurs clés API
    final taxId =
        (apiData['taxId'] ??
                apiData['companyTaxId'] ??
                apiData['taxIdentificationNumber'])
            as String? ??
        '';
    final idNat =
        (apiData['nationalId'] ??
                apiData['companyNationalId'] ??
                apiData['idNatNumber'])
            as String? ??
        '';
    final rccm =
        (apiData['registrationNumber'] ??
                apiData['companyRccm'] ??
                apiData['rccmNumber'])
            as String? ??
        '';
    final defaultLanguage = apiData['defaultLanguage'] as String? ?? 'fr';
    final currency = apiData['currency'] as String? ?? 'CDF';
    final dateFormat = apiData['dateFormat'] as String? ?? 'DD/MM/YYYY';
    final timeFormat = apiData['timeFormat'] as String? ?? 'HH:mm';
    final contactEmail = apiData['contactEmail'] as String? ?? '';
    final contactPhone = apiData['contactPhone'] as String? ?? '';
    final companyAddress = apiData['companyAddress'] as String? ?? '';
    final maintenanceMode = apiData['maintenanceMode'] as bool? ?? false;

    // Social media links
    Map<String, String>? socialMediaLinks;
    if (apiData['socialMediaLinks'] != null) {
      try {
        socialMediaLinks = Map<String, String>.from(
          apiData['socialMediaLinks'] as Map,
        );
      } catch (e) {
        debugPrint(
          '📋 [SettingsRepository] Error parsing socialMediaLinks: $e',
        );
      }
    }

    debugPrint('📋 [SettingsRepository] Mapped fields:');
    debugPrint('📋   companyName: $companyName');
    debugPrint('📋   companyLogoUrl: $companyLogoUrl');
    debugPrint('📋   defaultLanguage: $defaultLanguage');
    debugPrint('📋   currency: $currency');
    debugPrint('📋   contactEmail: $contactEmail');
    debugPrint('📋   contactPhone: $contactPhone');

    // Mapper la devise
    Currency activeCurrency;
    try {
      activeCurrency = Currency.values.firstWhere(
        (c) => c.name.toUpperCase() == currency.toUpperCase(),
        orElse: () => Currency.CDF,
      );
    } catch (e) {
      activeCurrency = Currency.CDF;
    }

    // Récupérer les paramètres locaux actuels pour préserver les champs non-API
    final currentLocal = _settingsBox.get(_settingsKey) ?? const Settings();

    // Régime fiscal (source de vérité = accounting, propagé par le backend) :
    // NORMAL ⇒ assujetti TVA ; SMT/FORFAITAIRE ⇒ exonéré (pas de TVA affichée).
    final isTaxSubject =
        apiData['isTaxSubject'] as bool? ?? currentLocal.isTaxSubject;

    return currentLocal.copyWith(
      isTaxSubject: isTaxSubject,
      companyName: companyName.isNotEmpty ? companyName : null,
      companyLogo: companyLogoUrl.isNotEmpty ? companyLogoUrl : null,
      language: defaultLanguage.isNotEmpty ? defaultLanguage : null,
      activeCurrency: activeCurrency,
      dateFormat: dateFormat.isNotEmpty ? dateFormat : null,
      timeFormat: timeFormat.isNotEmpty ? timeFormat : null,
      companyEmail: contactEmail.isNotEmpty ? contactEmail : null,
      companyPhone: contactPhone.isNotEmpty ? contactPhone : null,
      companyAddress: companyAddress.isNotEmpty ? companyAddress : null,
      taxIdentificationNumber: taxId.isNotEmpty ? taxId : null,
      idNatNumber: idNat.isNotEmpty ? idNat : null,
      rccmNumber: rccm.isNotEmpty ? rccm : null,
      maintenanceMode: maintenanceMode,
      socialMediaLinks: socialMediaLinks,
    );
  }

  /// Mapper le modèle Settings vers les données API
  Map<String, dynamic> _mapSettingsToApi(Settings settings) {
    debugPrint('📋 [SettingsRepository] Mapping Settings model to API data...');

    final apiData = <String, dynamic>{};

    // Ne pas envoyer les champs vides
    if (settings.companyName.isNotEmpty) {
      apiData['companyName'] = settings.companyName;
    }
    if (settings.companyLogo.isNotEmpty) {
      apiData['companyLogoUrl'] = settings.companyLogo;
    }
    if (settings.language.isNotEmpty) {
      apiData['defaultLanguage'] = settings.language;
    }
    apiData['currency'] = settings.activeCurrency.name.toUpperCase();
    if (settings.dateFormat.isNotEmpty) {
      apiData['dateFormat'] = settings.dateFormat;
    }
    if (settings.timeFormat.isNotEmpty) {
      apiData['timeFormat'] = settings.timeFormat;
    }
    if (settings.companyEmail.isNotEmpty) {
      apiData['contactEmail'] = settings.companyEmail;
    }
    if (settings.companyPhone.isNotEmpty) {
      apiData['contactPhone'] = settings.companyPhone;
    }
    if (settings.companyAddress.isNotEmpty) {
      apiData['companyAddress'] = settings.companyAddress;
    }
    // Identifiants légaux (NIF/Id Nat/RCCM) : round-trip vers l'API
    if (settings.taxIdentificationNumber.isNotEmpty) {
      apiData['taxId'] = settings.taxIdentificationNumber;
    }
    if (settings.idNatNumber.isNotEmpty) {
      apiData['nationalId'] = settings.idNatNumber;
    }
    if (settings.rccmNumber.isNotEmpty) {
      apiData['registrationNumber'] = settings.rccmNumber;
    }
    apiData['maintenanceMode'] = settings.maintenanceMode;
    if (settings.socialMediaLinks != null &&
        settings.socialMediaLinks!.isNotEmpty) {
      apiData['socialMediaLinks'] = settings.socialMediaLinks;
    }

    debugPrint('📋 [SettingsRepository] Mapped API data: $apiData');
    return apiData;
  }

  /// Obtenir la date de dernière synchronisation
  DateTime? getLastSyncDate() {
    final lastSyncStr = _metadataBox.get(_lastSyncKey);
    if (lastSyncStr is String) {
      try {
        return DateTime.parse(lastSyncStr);
      } catch (e) {
        return null;
      }
    }
    return null;
  }

  /// Fermer le repository
  Future<void> close() async {
    if (_isInitialized) {
      await _settingsBox.close();
      await _metadataBox.close();
      _isInitialized = false;
    }
  }
}
