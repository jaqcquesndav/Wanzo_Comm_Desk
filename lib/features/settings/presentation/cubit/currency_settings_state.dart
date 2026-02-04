part of 'currency_settings_cubit.dart';

enum CurrencySettingsStatus { initial, loading, loaded, error, saving, saved }

class CurrencySettingsState extends Equatable {
  final CurrencySettings settings;
  final CurrencySettingsStatus status;
  final String? errorMessage;

  const CurrencySettingsState({
    required this.settings,
    this.status = CurrencySettingsStatus.initial,
    this.errorMessage,
  });

  factory CurrencySettingsState.initial() {
    return CurrencySettingsState(
      settings: CurrencySettings.defaultSettings(),
      status: CurrencySettingsStatus.initial,
    );
  }

  CurrencySettingsState copyWith({
    CurrencySettings? settings,
    CurrencySettingsStatus? status,
    String? errorMessage,
  }) {
    return CurrencySettingsState(
      settings: settings ?? this.settings,
      status: status ?? this.status,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }

  @override
  List<Object?> get props => [settings, status, errorMessage];
}
