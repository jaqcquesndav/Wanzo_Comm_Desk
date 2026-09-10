// filepath: c:\\Users\\DevSpace\\Flutter\\wanzo\\lib\\core\\services\\currency_service.dart
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../enums/currency_enum.dart';
import '../models/currency_settings_model.dart';
import '../utils/currency_formatter.dart';
import 'dart:convert';

class CurrencyService {
  static const String _settingsKey = 'currency_settings';
  CurrencySettings _currentSettings = CurrencySettings.defaultSettings();

  CurrencySettings get currentSettings => _currentSettings;

  Future<void> loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final String? settingsString = prefs.getString(_settingsKey);
    if (settingsString != null && settingsString.isNotEmpty) {
      try {
        _currentSettings = CurrencySettings.fromJson(
          jsonDecode(settingsString),
        );
      } catch (e) {
        debugPrint(
          'Error loading currency settings: $e. Using default settings.',
        );
        _currentSettings = CurrencySettings.defaultSettings();
        // Optionally, clear the corrupted setting
        // await prefs.remove(_settingsKey);
      }
    } else {
      _currentSettings = CurrencySettings.defaultSettings();
    }
  }

  Future<void> saveSettings(CurrencySettings settings) async {
    final prefs = await SharedPreferences.getInstance();
    _currentSettings = settings;
    await prefs.setString(_settingsKey, jsonEncode(settings.toJson()));
  }

  // Private helper method that performs conversion using provided settings
  double _convert(
    double amount,
    Currency fromCurrency,
    Currency toCurrency,
    CurrencySettings settings,
  ) {
    if (fromCurrency == toCurrency) {
      return amount;
    }

    // Convert 'fromCurrency' to CDF first
    double amountInCdf;
    switch (fromCurrency) {
      case Currency.USD:
        amountInCdf = amount * settings.usdToCdfRate;
        break;
      case Currency.FCFA:
        amountInCdf = amount * settings.fcfaToCdfRate;
        break;
      case Currency.CDF:
        amountInCdf = amount;
        break;
      // No default needed as all enum values are covered.
    }

    // Convert from CDF to 'toCurrency'
    switch (toCurrency) {
      case Currency.USD:
        // Avoid division by zero if rate is 0, though settings validation should prevent this.
        return settings.usdToCdfRate == 0
            ? amountInCdf
            : amountInCdf / settings.usdToCdfRate;
      case Currency.FCFA:
        return settings.fcfaToCdfRate == 0
            ? amountInCdf
            : amountInCdf / settings.fcfaToCdfRate;
      case Currency.CDF:
        return amountInCdf;
      // No default needed as all enum values are covered.
    }
  }

  /// Converts an amount from a specified currency to CDF using current settings.
  double convertToCdf(double amount, Currency fromCurrency) {
    return _convert(amount, fromCurrency, Currency.CDF, _currentSettings);
  }

  /// Converts an amount from CDF to a specified target currency using current settings.
  double convertFromCdf(double amountInCdf, Currency toCurrency) {
    return _convert(amountInCdf, Currency.CDF, toCurrency, _currentSettings);
  }

  String formatAmount(double amount, {Currency? displayCurrency}) {
    final targetCurrency = displayCurrency ?? _currentSettings.activeCurrency;

    // 'amount' est exprimé en CDF : on le convertit dans la devise d'affichage,
    // puis on délègue le formatage (décimales/locale/symbole) à la règle unique
    // de currency_formatter.dart (CDF = 0 décimale suffixe « CDF », USD = 2
    // décimales symbole « $ »).
    final displayAmount = convertFromCdf(amount, targetCurrency);
    return formatCurrency(displayAmount, targetCurrency.code);
  }

  // Helper to get a specific exchange rate to CDF
  double getRateToCdf(Currency currency) {
    switch (currency) {
      case Currency.USD:
        return _currentSettings.usdToCdfRate;
      case Currency.FCFA:
        return _currentSettings.fcfaToCdfRate;
      case Currency.CDF:
        return 1.0;
      // No default needed as all enum values are covered.
    }
  }
}

// How to use (conceptual):
// 1. In your main.dart or an initialization service:
//    CurrencyService currencyService = CurrencyService();
//    await currencyService.loadSettings();
//
// 2. When displaying an amount (assuming amountInCdf is stored in CDF):
//    String displayPrice = currencyService.formatAmount(amountInCdf);
//
// 3. When user saves a new transaction amount (e.g., input in USD):
//    double amountInUsd = 50.0;
//    double amountInCdf = currencyService.convertAmount(amountInUsd, Currency.USD, Currency.CDF);
//    // Save amountInCdf to database
//
// 4. In settings screen:
//    await currencyService.saveSettings(
//      CurrencySettings(
//        activeCurrency: Currency.USD,
//        usdToCdfRate: 2850.0,
//        fcfaToCdfRate: 4.6,
//      )
//    );
