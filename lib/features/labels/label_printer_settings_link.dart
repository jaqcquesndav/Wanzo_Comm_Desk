import 'package:flutter/material.dart';
import 'package:wanzo/features/settings/screens/printer_settings_screen.dart';

/// Raccourci vers Réglages, Imprimante, proposé quand l'impression des
/// étiquettes échoue (imprimante non configurée ou injoignable).
Future<void> openLabelPrinterSettings(BuildContext context) {
  return Navigator.of(context).push<void>(
    MaterialPageRoute(builder: (_) => const PrinterSettingsScreen()),
  );
}
