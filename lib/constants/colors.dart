import 'package:flutter/material.dart';

/// Classe contenant les constantes de couleurs utilisées dans l'application
class WanzoColors {
  // Empêche l'instanciation
  WanzoColors._();

  // Couleurs primaires
  static const Color primary = Color(0xFF197CA8);
  static const Color primaryLight = Color(0xFF2089B7);
  static const Color primaryDark = Color(0xFF156D93);

  // Accent color (added)
  static const Color accent = Color(0xFFFFA500); // Example: Orange accent

  // Couleurs interactives
  static const Color interactive = Color(0xFF1E90C3);
  static const Color interactiveLight = Color(0xFF2F9FCF);
  static const Color interactiveDark = Color(0xFF1B81AF);

  // Couleurs de succès
  static const Color success = Color(0xFF015730);
  static const Color successLight = Color(0xFF026B3A);
  static const Color successDark = Color(0xFF014426);

  // Couleurs d'avertissement
  static const Color warning = Color(0xFFEE872B);
  static const Color warningLight = Color(0xFFF09642);
  static const Color warningDark = Color(0xFFE67816);

  // Couleurs d'erreur
  static const Color error = Color(0xFFDC2626);
  static const Color danger = Color(0xFFDC2626); // Alias pour error

  // Couleurs d'information
  static const Color info = Color(0xFF3B82F6);
  static const Color infoLight = Color(0xFF60A5FA);
  static const Color infoDark = Color(0xFF2563EB);

  // Couleurs de fond - thème clair
  static const Color backgroundPrimaryLight = Color(0xFFFFFFFF);
  static const Color backgroundSecondaryLight = Color(0xFFF3F4F6);
  static const Color backgroundTertiaryLight = Color(0xFFE5E7EB);

  // Couleurs de texte - thème clair
  static const Color textPrimaryLight = Color(0xFF111827);
  static const Color textSecondaryLight = Color(0xFF4B5563);
  static const Color textTertiaryLight = Color(0xFF9CA3AF);

  // Couleurs de bordure - thème clair
  static const Color borderLightThemeLight = Color(0xFFE5E7EB);
  static const Color borderMediumThemeLight = Color(0xFFD1D5DB);
  static const Color borderDarkThemeLight = Color(0xFF9CA3AF);

  // Couleurs de fond - thème sombre
  static const Color backgroundPrimaryDark = Color(0xFF1A1B1E);
  static const Color backgroundSecondaryDark = Color(0xFF2C2E33);
  static const Color backgroundTertiaryDark = Color(0xFF3B3D42);

  // Couleurs de texte - thème sombre
  static const Color textPrimaryDark = Color(0xFFF3F4F6);
  static const Color textSecondaryDark = Color(0xFFD1D5DB);
  static const Color textTertiaryDark = Color(0xFF9CA3AF);

  // Couleurs de bordure - thème sombre
  static const Color borderLightThemeDark = Color(0xFF3B3D42);
  static const Color borderMediumThemeDark = Color(0xFF4B5563);
  static const Color borderDarkThemeDark = Color(0xFF6B7280);
}
