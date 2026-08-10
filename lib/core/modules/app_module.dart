import 'package:flutter/material.dart';
import 'activity_mode.dart';

/// Descripteur d'un module fonctionnel (façon « apps » Odoo).
///
/// Variante desktop : porte en plus les attributs propres à la sidebar
/// (`inSidebar`, `sidebarOrder`, `dividerBefore`, `isAdhaPanel`) afin
/// d'alimenter à la fois la sidebar desktop ET la bottom-nav mobile depuis
/// une seule source de vérité.
@immutable
class AppModule {
  final String id;
  final String label;
  final IconData icon;
  final IconData activeIcon;
  final String route;

  /// Modes d'activité où ce module est proposé.
  final Set<ActivityMode> modes;

  /// Rôles autorisés. `null` = tous.
  final Set<String>? roles;

  /// Candidat à la bottom-nav (layout mobile du desktop).
  final bool primary;

  /// Ordre en bottom-nav.
  final int order;

  /// Présent dans la sidebar desktop.
  final bool inSidebar;

  /// Ordre dans la sidebar.
  final int sidebarOrder;

  /// Séparateur visuel avant cet item (sidebar).
  final bool dividerBefore;

  /// Ouvre le panneau Adha au lieu d'une route classique.
  final bool isAdhaPanel;

  /// `false` = déclaré mais écran non livré ⇒ masqué. Passer à `true` une
  /// fois la route implémentée : c'est le seul changement requis.
  final bool available;

  const AppModule({
    required this.id,
    required this.label,
    required this.icon,
    required this.activeIcon,
    required this.route,
    required this.modes,
    this.roles,
    this.primary = false,
    this.order = 0,
    this.inSidebar = false,
    this.sidebarOrder = 0,
    this.dividerBefore = false,
    this.isAdhaPanel = false,
    this.available = true,
  });

  bool visibleFor(ActivityMode mode, String? role) {
    if (!available) return false;
    if (!modes.contains(mode)) return false;
    if (roles == null) return true;
    if (role == null) return false;
    return roles!.contains(role);
  }
}
