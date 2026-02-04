import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../repositories/settings_repository.dart';
import '../models/settings.dart'; // Added import for Settings model
import 'settings_event.dart';
import 'settings_state.dart';

/// BLoC pour gérer les paramètres de l'application
class SettingsBloc extends Bloc<SettingsEvent, SettingsState> {
  /// Repository pour accéder aux paramètres
  final SettingsRepository settingsRepository;

  SettingsBloc({required this.settingsRepository})
    : super(const SettingsInitial()) {
    on<LoadSettings>(_onLoadSettings);
    on<LoadSettingsWithSync>(_onLoadSettingsWithSync);
    on<SyncSettings>(_onSyncSettings);
    on<UpdateSettings>(_onUpdateSettings);
    on<UpdateCompanyInfo>(_onUpdateCompanyInfo);
    on<UpdateInvoiceSettings>(_onUpdateInvoiceSettings);
    on<UpdateDisplaySettings>(_onUpdateDisplaySettings);
    on<UpdateInventorySettings>(_onUpdateInventorySettings);
    on<UpdateBackupSettings>(_onUpdateBackupSettings);
    on<UpdateNotificationSettings>(_onUpdateNotificationSettings);
    on<ResetSettings>(_onResetSettings);
  }

  /// Gère le chargement des paramètres (local uniquement)
  Future<void> _onLoadSettings(
    LoadSettings event,
    Emitter<SettingsState> emit,
  ) async {
    emit(const SettingsLoading());

    try {
      debugPrint('📋 [SettingsBloc] Loading settings (local)...');
      final settings = await settingsRepository.getSettings();
      debugPrint(
        '📋 [SettingsBloc] Settings loaded: companyName=${settings.companyName}',
      );
      emit(SettingsLoaded(settings));
    } catch (e) {
      debugPrint('📋 [SettingsBloc] Error loading settings: $e');
      emit(SettingsError('Erreur lors du chargement des paramètres: $e'));
    }
  }

  /// Gère le chargement des paramètres avec synchronisation API
  Future<void> _onLoadSettingsWithSync(
    LoadSettingsWithSync event,
    Emitter<SettingsState> emit,
  ) async {
    emit(const SettingsLoading());

    try {
      debugPrint('📋 [SettingsBloc] Loading settings with API sync...');
      final settings = await settingsRepository.getSettingsWithSync();
      debugPrint(
        '📋 [SettingsBloc] Settings synced: companyName=${settings.companyName}',
      );
      emit(SettingsLoaded(settings));
    } catch (e) {
      debugPrint('📋 [SettingsBloc] Error syncing settings: $e');
      // Fallback vers les paramètres locaux en cas d'erreur
      try {
        final localSettings = await settingsRepository.getSettings();
        emit(SettingsLoaded(localSettings));
      } catch (_) {
        emit(SettingsError('Erreur lors du chargement des paramètres: $e'));
      }
    }
  }

  /// Gère la synchronisation manuelle avec l'API
  Future<void> _onSyncSettings(
    SyncSettings event,
    Emitter<SettingsState> emit,
  ) async {
    // Garder l'état actuel pendant la sync pour éviter le flicker
    final currentState = state;

    try {
      debugPrint(
        '📋 [SettingsBloc] Syncing settings from API (force=${event.force})...',
      );
      final synced = await settingsRepository.syncFromApi();

      if (synced) {
        debugPrint('📋 [SettingsBloc] Sync successful, reloading settings...');
        final settings = await settingsRepository.getSettings();
        emit(
          SettingsUpdated(
            settings: settings,
            message: 'Paramètres synchronisés avec succès',
          ),
        );
        emit(SettingsLoaded(settings));
      } else {
        debugPrint(
          '📋 [SettingsBloc] Sync not available, keeping local settings',
        );
        if (currentState is SettingsLoaded) {
          emit(
            SettingsUpdated(
              settings: currentState.settings,
              message: 'Mode hors ligne - paramètres locaux conservés',
            ),
          );
          emit(currentState);
        }
      }
    } catch (e) {
      debugPrint('📋 [SettingsBloc] Error syncing settings: $e');
      if (currentState is SettingsLoaded) {
        emit(SettingsError('Erreur de synchronisation: $e'));
        emit(currentState); // Restaurer l'état précédent
      }
    }
  }

  /// Gère la mise à jour complète des paramètres
  Future<void> _onUpdateSettings(
    UpdateSettings event,
    Emitter<SettingsState> emit,
  ) async {
    emit(const SettingsLoading());

    try {
      debugPrint('📋 [SettingsBloc] Updating settings...');
      await settingsRepository.saveSettings(event.settings);
      debugPrint('📋 [SettingsBloc] Settings saved successfully');
      emit(
        SettingsUpdated(
          settings: event.settings,
          message: 'Paramètres mis à jour avec succès',
        ),
      );
      emit(SettingsLoaded(event.settings)); // Emit SettingsLoaded
    } catch (e) {
      emit(SettingsError('Erreur lors de la mise à jour des paramètres: $e'));
      if (state is SettingsLoaded) {
        emit(SettingsLoaded((state as SettingsLoaded).settings));
      } else {
        add(const LoadSettings());
      }
    }
  }

  /// Gère la mise à jour des informations de l'entreprise
  Future<void> _onUpdateCompanyInfo(
    UpdateCompanyInfo event,
    Emitter<SettingsState> emit,
  ) async {
    emit(const SettingsLoading());

    try {
      final currentSettings = await settingsRepository.getSettings();
      final updatedSettings = currentSettings.copyWith(
        companyName: event.companyName,
        companyAddress: event.companyAddress,
        companyPhone: event.companyPhone,
        companyEmail: event.companyEmail,
        companyLogo: event.companyLogo,
        taxIdentificationNumber: event.taxIdentificationNumber,
        rccmNumber: event.rccmNumber,
        idNatNumber: event.idNatNumber,
        businessUnitId: event.businessUnitId,
        businessUnitCode: event.businessUnitCode,
        businessUnitType: event.businessUnitType,
        businessUnitName: event.businessUnitName,
        // ignore: deprecated_member_use_from_same_package
        isRetailStore: event.isRetailStore,
      );

      await settingsRepository.saveSettings(updatedSettings);
      emit(
        SettingsUpdated(
          settings: updatedSettings,
          message: 'Informations de l\'entreprise mises à jour',
        ),
      );
      emit(SettingsLoaded(updatedSettings)); // Emit SettingsLoaded
    } catch (e) {
      emit(
        SettingsError(
          'Erreur lors de la mise à jour des informations de l\'entreprise: $e',
        ),
      );
      if (state is SettingsLoaded) {
        emit(SettingsLoaded((state as SettingsLoaded).settings));
      } else {
        add(const LoadSettings());
      }
    }
  }

  /// Gère la mise à jour des paramètres de facture
  Future<void> _onUpdateInvoiceSettings(
    UpdateInvoiceSettings event,
    Emitter<SettingsState> emit,
  ) async {
    emit(const SettingsLoading());

    try {
      final currentSettings = await settingsRepository.getSettings();
      final updatedSettings = currentSettings.copyWith(
        invoiceNumberFormat: event.invoiceNumberFormat,
        invoicePrefix: event.invoicePrefix,
        defaultPaymentTerms: event.defaultPaymentTerms,
        defaultInvoiceNotes: event.defaultInvoiceNotes,
        showTaxes: event.showTaxes,
        defaultTaxRate: event.defaultTaxRate,
      );

      await settingsRepository.saveSettings(updatedSettings);
      emit(
        SettingsUpdated(
          settings: updatedSettings,
          message: 'Paramètres de facturation mis à jour',
        ),
      );
      emit(SettingsLoaded(updatedSettings)); // Emit SettingsLoaded
    } catch (e) {
      emit(
        SettingsError(
          'Erreur lors de la mise à jour des paramètres de facturation: $e',
        ),
      );
      if (state is SettingsLoaded) {
        emit(SettingsLoaded((state as SettingsLoaded).settings));
      } else {
        add(const LoadSettings());
      }
    }
  }

  /// Gère la mise à jour des paramètres d'affichage
  Future<void> _onUpdateDisplaySettings(
    UpdateDisplaySettings event,
    Emitter<SettingsState> emit,
  ) async {
    emit(const SettingsLoading());

    try {
      final currentSettings = await settingsRepository.getSettings();
      final updatedSettings = currentSettings.copyWith(
        themeMode: event.themeMode,
        language: event.language,
        dateFormat: event.dateFormat,
      );

      await settingsRepository.saveSettings(updatedSettings);
      emit(
        SettingsUpdated(
          settings: updatedSettings,
          message: 'Paramètres d\'affichage mis à jour',
        ),
      );
      emit(SettingsLoaded(updatedSettings)); // Emit SettingsLoaded
    } catch (e) {
      emit(
        SettingsError(
          'Erreur lors de la mise à jour des paramètres d\'affichage: $e',
        ),
      );
      if (state is SettingsLoaded) {
        emit(SettingsLoaded((state as SettingsLoaded).settings));
      } else {
        add(const LoadSettings());
      }
    }
  }

  /// Gère la mise à jour des paramètres de stock
  Future<void> _onUpdateInventorySettings(
    UpdateInventorySettings event,
    Emitter<SettingsState> emit,
  ) async {
    emit(const SettingsLoading());

    try {
      final currentSettings = await settingsRepository.getSettings();
      final updatedSettings = currentSettings.copyWith(
        defaultProductCategory: event.defaultProductCategory,
        lowStockAlertDays: event.lowStockAlertDays,
      );

      await settingsRepository.saveSettings(updatedSettings);
      emit(
        SettingsUpdated(
          settings: updatedSettings,
          message: 'Paramètres de stock mis à jour',
        ),
      );
      emit(SettingsLoaded(updatedSettings)); // Emit SettingsLoaded
    } catch (e) {
      emit(
        SettingsError(
          'Erreur lors de la mise à jour des paramètres de stock: $e',
        ),
      );
      if (state is SettingsLoaded) {
        emit(SettingsLoaded((state as SettingsLoaded).settings));
      } else {
        add(const LoadSettings());
      }
    }
  }

  /// Gère la mise à jour des paramètres de sauvegarde
  Future<void> _onUpdateBackupSettings(
    UpdateBackupSettings event,
    Emitter<SettingsState> emit,
  ) async {
    emit(const SettingsLoading());

    try {
      final currentSettings = await settingsRepository.getSettings();
      final updatedSettings = currentSettings.copyWith(
        backupEnabled: event.backupEnabled,
        backupFrequency: event.backupFrequency,
        reportEmail: event.reportEmail,
      );

      await settingsRepository.saveSettings(updatedSettings);
      emit(
        SettingsUpdated(
          settings: updatedSettings,
          message: 'Paramètres de sauvegarde mis à jour',
        ),
      );
      emit(SettingsLoaded(updatedSettings)); // Emit SettingsLoaded
    } catch (e) {
      emit(
        SettingsError(
          'Erreur lors de la mise à jour des paramètres de sauvegarde: $e',
        ),
      );
      if (state is SettingsLoaded) {
        emit(SettingsLoaded((state as SettingsLoaded).settings));
      } else {
        add(const LoadSettings());
      }
    }
  }

  /// Gère la mise à jour des paramètres de notification
  Future<void> _onUpdateNotificationSettings(
    UpdateNotificationSettings event,
    Emitter<SettingsState> emit,
  ) async {
    // Get current settings from state if possible, otherwise load them.
    Settings currentSettings;
    if (state is SettingsLoaded) {
      currentSettings = (state as SettingsLoaded).settings;
    } else if (state is SettingsUpdated) {
      // Also consider SettingsUpdated as a source of current settings
      currentSettings = (state as SettingsUpdated).settings;
    } else {
      // If settings are not loaded, emit loading and fetch them.
      emit(const SettingsLoading());
      try {
        currentSettings = await settingsRepository.getSettings();
        emit(SettingsLoaded(currentSettings));
      } catch (e) {
        emit(
          SettingsError(
            'Erreur lors du chargement des paramètres avant mise à jour: $e',
          ),
        );
        return;
      }
    }

    final updatedSettings = currentSettings.copyWith(
      pushNotificationsEnabled: event.pushNotificationsEnabled,
      inAppNotificationsEnabled: event.inAppNotificationsEnabled,
      emailNotificationsEnabled: event.emailNotificationsEnabled,
      soundNotificationsEnabled: event.soundNotificationsEnabled,
    );

    // Emit loading before the save operation for this specific update
    emit(const SettingsLoading());

    try {
      await settingsRepository.saveSettings(updatedSettings);
      emit(
        SettingsUpdated(
          settings: updatedSettings,
          message: 'Paramètres de notification mis à jour avec succès',
        ),
      );
      emit(SettingsLoaded(updatedSettings)); // Emit SettingsLoaded
    } catch (e) {
      emit(
        SettingsError(
          'Erreur lors de la mise à jour des paramètres de notification: $e',
        ),
      );
      // Revert to previously known good settings on error
      emit(SettingsLoaded(currentSettings));
    }
  }

  /// Gère la réinitialisation des paramètres
  Future<void> _onResetSettings(
    ResetSettings event,
    Emitter<SettingsState> emit,
  ) async {
    emit(const SettingsLoading());

    try {
      final defaultSettings = await settingsRepository.resetSettings();
      emit(
        SettingsUpdated(
          settings: defaultSettings,
          message: 'Paramètres réinitialisés aux valeurs par défaut',
        ),
      );
      emit(SettingsLoaded(defaultSettings)); // Emit SettingsLoaded
    } catch (e) {
      emit(
        SettingsError('Erreur lors de la réinitialisation des paramètres: $e'),
      );
      if (state is SettingsLoaded) {
        emit(SettingsLoaded((state as SettingsLoaded).settings));
      } else {
        add(const LoadSettings());
      }
    }
  }
}
