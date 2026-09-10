import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import '../../../../core/models/currency_settings_model.dart';
import '../../../../core/enums/currency_enum.dart';
import '../../../../core/services/currency_service.dart';
import '../../../company/services/company_api_service.dart';

part 'currency_settings_state.dart';

class CurrencySettingsCubit extends Cubit<CurrencySettingsState> {
  final CurrencyService _currencyService;
  final CompanyApiService _companyApiService;

  CurrencySettingsCubit(
    this._currencyService, {
    CompanyApiService? companyApiService,
  })  : _companyApiService = companyApiService ?? CompanyApiService(),
        super(CurrencySettingsState.initial());

  Future<void> loadSettings() async {
    emit(state.copyWith(status: CurrencySettingsStatus.loading));
    try {
      await _currencyService.loadSettings();
      emit(state.copyWith(
        settings: _currencyService.currentSettings,
        status: CurrencySettingsStatus.loaded,
      ));
    } catch (e) {
      emit(state.copyWith(
        status: CurrencySettingsStatus.error,
        errorMessage: "Failed to load settings: ${e.toString()}",
      ));
    }
  }

  Future<void> updateActiveCurrency(Currency newActiveCurrency) async {
    final newSettings = CurrencySettings(
      activeCurrency: newActiveCurrency,
      usdToCdfRate: state.settings.usdToCdfRate,
      fcfaToCdfRate: state.settings.fcfaToCdfRate,
    );
    await _saveSettings(newSettings);
  }

  Future<void> updateUsdToCdfRate(double rate) async {
    final newSettings = CurrencySettings(
      activeCurrency: state.settings.activeCurrency,
      usdToCdfRate: rate,
      fcfaToCdfRate: state.settings.fcfaToCdfRate,
    );
    await _saveSettings(newSettings);
  }

  Future<void> updateFcfaToCdfRate(double rate) async {
    final newSettings = CurrencySettings(
      activeCurrency: state.settings.activeCurrency,
      usdToCdfRate: state.settings.usdToCdfRate,
      fcfaToCdfRate: rate,
    );
    await _saveSettings(newSettings);
  }
  
  Future<void> updateSettings(CurrencySettings newSettings) async {
    await _saveSettings(newSettings);
  }

  /// Amorce le taux de change depuis le backend (autorité = accounting, exposé
  /// par gestion) au démarrage / à la synchro.
  ///
  /// Le taux central fait référence: on met à jour `usdToCdfRate` (et, si
  /// présent, `fcfaToCdfRate` via XAF/XOF) puis on persiste via le mécanisme
  /// existant. L'utilisateur peut toujours l'ajuster ensuite dans les
  /// paramètres (override local conservé hors ligne). En cas d'échec réseau,
  /// on garde le dernier taux connu et rien n'est écrasé. Un seul appel, pas de
  /// polling.
  Future<void> seedCentralExchangeRates() async {
    final central = await _companyApiService.getCompanyExchangeRates();
    if (central == null) return;

    final rates = central.exchangeRates;
    final usd = rates['USD'];
    final fcfa = rates['XAF'] ?? rates['XOF'];
    if ((usd == null || usd <= 0) && (fcfa == null || fcfa <= 0)) return;

    final current = state.settings;
    final newSettings = current.copyWith(
      usdToCdfRate: (usd != null && usd > 0) ? usd : current.usdToCdfRate,
      fcfaToCdfRate: (fcfa != null && fcfa > 0) ? fcfa : current.fcfaToCdfRate,
    );
    await _saveSettings(newSettings);
  }

  Future<void> _saveSettings(CurrencySettings settingsToSave) async {
    emit(state.copyWith(status: CurrencySettingsStatus.saving));
    try {
      await _currencyService.saveSettings(settingsToSave);
      emit(state.copyWith(
        settings: settingsToSave,
        status: CurrencySettingsStatus.saved,
      ));
      // Optionally reload to confirm or just trust the save
      emit(state.copyWith(status: CurrencySettingsStatus.loaded));
    } catch (e) {
      emit(state.copyWith(
        status: CurrencySettingsStatus.error,
        errorMessage: "Failed to save settings: ${e.toString()}",
      ));
    }
  }
}
