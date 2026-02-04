// filepath: c:\Users\DevSpace\Flutter\wanzo\lib\core\enums\currency_enum.dart
import 'package:flutter/widgets.dart';
import 'package:hive/hive.dart'; // Added Hive import
import 'package:wanzo/l10n/app_localizations.dart'; // Updated import

part 'currency_enum.g.dart'; // Added for generated adapter

@HiveType(
  typeId: 70,
) // Changed from 12 to 70 to avoid conflict with BusinessSector
enum Currency {
  @HiveField(0) // Added HiveField annotation
  CDF, // Congolese Franc
  @HiveField(1) // Added HiveField annotation
  USD, // US Dollar
  @HiveField(2) // Added HiveField annotation
  FCFA, // Central African CFA franc
}

extension CurrencyExtension on Currency {
  String get code {
    switch (this) {
      case Currency.CDF:
        return 'CDF';
      case Currency.USD:
        return 'USD';
      case Currency.FCFA:
        return 'FCFA';
    }
  }

  String get symbol {
    switch (this) {
      case Currency.CDF:
        return 'FC'; // Or CDF
      case Currency.USD:
        return '\$';
      case Currency.FCFA:
        return 'FCFA'; // Or XAF
    }
  }

  String displayName(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    switch (this) {
      case Currency.CDF:
        return l10n.currencyCDF;
      case Currency.USD:
        return l10n.currencyUSD;
      case Currency.FCFA:
        return l10n.currencyFCFA;
    }
  }
}
