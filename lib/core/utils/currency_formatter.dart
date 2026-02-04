import 'package:intl/intl.dart';
import 'package:wanzo/core/enums/currency_enum.dart'; // Updated import

String formatCurrency(double amount, String currencyCode) {
  Currency currency = Currency.values.firstWhere(
    (c) => c.code == currencyCode,
    orElse: () => Currency.CDF,
  ); // Fallback to CDF

  String symbol = currency.symbol;
  int decimalDigits;
  String locale;

  switch (currency) {
    case Currency.USD:
      decimalDigits = 2;
      locale = 'en_US'; // Common locale for USD
      break;
    case Currency.CDF:
      decimalDigits = 0; // CDF often shown with no decimals
      locale = 'fr_CD'; // Locale for Congolese Franc
      break;
    case Currency.FCFA:
      decimalDigits =
          0; // FCFA often shown with no decimals, XAF is 0 by default with NumberFormat
      locale =
          'fr_CM'; // Example locale for FCFA (Cameroon), adjust as needed for target region
      break;
  }

  // Specific formatting for CDF and FCFA to place symbol after the amount with a space.
  if (currency == Currency.CDF || currency == Currency.FCFA) {
    final String pattern =
        "#,##0${decimalDigits > 0 ? '.${''.padRight(decimalDigits, '0')}' : ''}";
    final NumberFormat numberFormatter = NumberFormat(pattern, locale);
    return '${numberFormatter.format(amount)} $symbol'; // Changed \u00A0 to a regular space
  }

  // Default formatting (e.g., for USD)
  final NumberFormat formatter = NumberFormat.currency(
    locale: locale,
    symbol: symbol,
    decimalDigits: decimalDigits,
  );
  return formatter.format(amount);
}

// Example of a more generic number formatter if needed elsewhere
String formatNumber(
  double number, {
  int decimalDigits = 2,
  String locale = 'en_US',
}) {
  final NumberFormat formatter = NumberFormat(
    "#,##0${decimalDigits > 0 ? '.${''.padRight(decimalDigits, '0')}' : ''}",
    locale,
  );
  return formatter.format(number);
}
