import 'package:flutter/material.dart';

/// Classe utilitaire contenant les ombres utilisées dans l'application
class WanzoShadows {
  // Empêche l'instanciation
  WanzoShadows._();

  /// Ombre légère
  static List<BoxShadow> get small => [
        BoxShadow(
          color: Colors.black.withOpacity(0.1),
          blurRadius: 2,
          offset: const Offset(0, 1),
        ),
      ];

  /// Ombre moyenne
  static List<BoxShadow> get medium => [
        BoxShadow(
          color: Colors.black.withOpacity(0.1),
          blurRadius: 4,
          offset: const Offset(0, 2),
        ),
      ];

  /// Ombre forte
  static List<BoxShadow> get large => [
        BoxShadow(
          color: Colors.black.withOpacity(0.15),
          blurRadius: 6,
          offset: const Offset(0, 4),
        ),
      ];
}
