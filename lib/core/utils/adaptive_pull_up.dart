import 'package:flutter/material.dart';

import 'desktop_modal.dart';

/// Conteneur de saisie ou de choix contextuel de Wanzo. Dans l'app desktop,
/// c'est toujours une MODALE centrée (plus de feuille du bas), quelle que
/// soit la largeur de la fenêtre : en-tête avec bouton Fermer, Échap pour
/// fermer. Les apps mobiles gardent leur pull-up.
Future<T?> showAdaptivePullUp<T>(
  BuildContext context, {
  required String title,
  required WidgetBuilder builder,
  IconData? icon,
  double maxWidth = kModalFormWidth,
  bool isDismissible = true,

  /// Marge autour du contenu. Sans elle, les champs touchent les bords du
  /// cadre. Une liste qui porte déjà sa propre marge passe `EdgeInsets.zero`.
  EdgeInsets contentPadding = const EdgeInsets.fromLTRB(16, 12, 16, 16),
}) {
  return showDesktopModal<T>(
    context,
    title: title,
    icon: icon,
    builder: builder,
    maxWidth: maxWidth,
    isDismissible: isDismissible,
    // Le contenu gère lui-même son défilement (listes, formulaires).
    scrollable: false,
    contentPadding: contentPadding,
  );
}
