import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import '../../../../core/models/currency_settings_model.dart';
import '../../../../core/enums/currency_enum.dart';
import '../../../../core/services/currency_service.dart';

part 'currency_settings_state.dart';

class CurrencySettingsCubit extends Cubit<CurrencySettingsState> {
  final CurrencyService _currencyService;

  CurrencySettingsCubit(this._currencyService) : super(CurrencySettingsState.initial());

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
