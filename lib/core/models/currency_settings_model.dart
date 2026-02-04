// filepath: c:\Users\DevSpace\Flutter\wanzo\lib\core\models\currency_settings_model.dart
import '../enums/currency_enum.dart';

class CurrencySettings {
  final Currency activeCurrency;
  final double usdToCdfRate;
  final double fcfaToCdfRate;

  CurrencySettings({
    required this.activeCurrency,
    required this.usdToCdfRate,
    required this.fcfaToCdfRate,
  });

  // Default settings
  factory CurrencySettings.defaultSettings() {
    return CurrencySettings(
      activeCurrency: Currency.CDF,
      usdToCdfRate: 2800.0, // Placeholder, user should configure
      fcfaToCdfRate: 4.5, // Placeholder, user should configure
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'activeCurrency': activeCurrency.name,
      'usdToCdfRate': usdToCdfRate,
      'fcfaToCdfRate': fcfaToCdfRate,
    };
  }

  factory CurrencySettings.fromJson(Map<String, dynamic> json) {
    return CurrencySettings(
      activeCurrency: Currency.values.firstWhere(
        (e) => e.name == json['activeCurrency'],
        orElse: () => Currency.CDF,
      ),
      usdToCdfRate: (json['usdToCdfRate'] as num?)?.toDouble() ?? 2800.0,
      fcfaToCdfRate: (json['fcfaToCdfRate'] as num?)?.toDouble() ?? 4.5,
    );
  }

  CurrencySettings copyWith({
    Currency? activeCurrency,
    double? usdToCdfRate,
    double? fcfaToCdfRate,
  }) {
    return CurrencySettings(
      activeCurrency: activeCurrency ?? this.activeCurrency,
      usdToCdfRate: usdToCdfRate ?? this.usdToCdfRate,
      fcfaToCdfRate: fcfaToCdfRate ?? this.fcfaToCdfRate,
    );
  }
}
