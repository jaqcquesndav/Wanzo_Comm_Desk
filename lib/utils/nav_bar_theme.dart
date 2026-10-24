import 'package:flutter/material.dart';

/// Style de l'élément actif de TOUTES les barres de navigation, aligné sur la
/// barre principale : aucun fond derrière l'élément actif (pas de pastille),
/// icône et libellé actifs dans la couleur primaire du thème (son équivalent
/// clair en mode sombre), inactifs en couleur secondaire.
///
/// Appliqué une seule fois aux thèmes clair et sombre (`WanzoTheme`), il
/// couvre les `NavigationBar` (barre interne du wallet, shells), les
/// `NavigationRail`, les `NavigationDrawer` et les `BottomNavigationBar` qui
/// ne fixent pas leurs propres couleurs.
ThemeData withWanzoNavStyle(ThemeData base) {
  final scheme = base.colorScheme;
  final active = scheme.primary;
  final inactive = scheme.onSurfaceVariant;

  bool isActive(Set<WidgetState> s) => s.contains(WidgetState.selected);

  final icon = WidgetStateProperty.resolveWith<IconThemeData?>(
    (s) => IconThemeData(color: isActive(s) ? active : inactive),
  );
  final label = WidgetStateProperty.resolveWith<TextStyle?>(
    (s) => TextStyle(
      fontSize: 12,
      color: isActive(s) ? active : inactive,
      fontWeight: isActive(s) ? FontWeight.w600 : FontWeight.w500,
    ),
  );

  return base.copyWith(
    navigationBarTheme: base.navigationBarTheme.copyWith(
      indicatorColor: Colors.transparent,
      iconTheme: icon,
      labelTextStyle: label,
    ),
    navigationRailTheme: base.navigationRailTheme.copyWith(
      indicatorColor: Colors.transparent,
      selectedIconTheme: IconThemeData(color: active),
      unselectedIconTheme: IconThemeData(color: inactive),
      selectedLabelTextStyle: TextStyle(
        color: active,
        fontWeight: FontWeight.w600,
      ),
      unselectedLabelTextStyle: TextStyle(color: inactive),
    ),
    navigationDrawerTheme: base.navigationDrawerTheme.copyWith(
      indicatorColor: Colors.transparent,
      iconTheme: icon,
      labelTextStyle: label,
    ),
    bottomNavigationBarTheme: base.bottomNavigationBarTheme.copyWith(
      selectedItemColor: active,
      unselectedItemColor: inactive,
    ),
  );
}
