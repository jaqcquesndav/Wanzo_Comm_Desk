import 'package:flutter/material.dart';

/// Place prise par la barre commune, pour décider ce qui passe dans le menu
/// 3 points sur un écran étroit ou avec une grande police. Le titre garde
/// toujours quelques lettres, puis se termine par des points de suspension.
///
/// Le profil reste toujours affiché, tout à droite. Les autres éléments sont
/// rangés par priorité (notifications, Adha, actions de la page, pastille du
/// mode) : on garde le plus long début de cette liste qui tient, le reste
/// passe dans le menu 3 points, dans le même ordre.
class AppBarFit {
  AppBarFit._();

  /// Bouton icône (notifications, Adha, menu, actions de l'écran).
  static const double iconAction = 48;

  /// Avatar du compte : 36 dp et 8 dp de marge de chaque côté.
  static const double avatar = 52;

  /// Largeur d'une pastille : libellé mesuré à la police de l'utilisateur,
  /// plus les icônes et marges fixes ([chrome]). [maxLabel] borne le libellé
  /// quand la pastille le tronque elle-même.
  static double pillWidth(
    BuildContext context,
    String label,
    TextStyle style, {
    required double chrome,
    double? maxLabel,
  }) {
    final painter = TextPainter(
      text: TextSpan(text: label, style: style),
      textDirection: TextDirection.ltr,
      textScaler: MediaQuery.textScalerOf(context),
      maxLines: 1,
    )..layout();
    final w = painter.width;
    painter.dispose();
    return chrome + (maxLabel != null && w > maxLabel ? maxLabel : w);
  }

  /// Nombre d'éléments de [widths] (rangés par priorité) qui tiennent dans la
  /// barre. Si tout ne tient pas, la place du menu 3 points est réservée.
  static int fitCount(
    BuildContext context, {
    required bool hasBack,
    required bool hasLogo,
    required List<double> widths,
    double reserved = 0,

    /// Le menu 3 points est déjà affiché (et compté dans [reserved]).
    bool menuShown = false,
    double? width,
  }) {
    final available = width ?? MediaQuery.sizeOf(context).width;
    final scaler = MediaQuery.textScalerOf(context);
    // Titre minimal : environ trois lettres, à la police de l'utilisateur.
    final base = (hasBack ? 56.0 : 0.0) +
        NavigationToolbar.kMiddleSpacing +
        (hasLogo ? 32.0 : 0.0) +
        scaler.scale(20) * 3 +
        avatar +
        reserved;
    final all = widths.fold<double>(0, (a, b) => a + b);
    if (base + all <= available) return widths.length;
    var used = base + (menuShown ? 0 : iconAction);
    var n = 0;
    for (final w in widths) {
      if (used + w > available) break;
      used += w;
      n++;
    }
    return n;
  }
}
