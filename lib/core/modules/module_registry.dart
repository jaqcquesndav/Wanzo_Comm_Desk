import 'package:flutter/material.dart';
import 'activity_mode.dart';
import 'app_module.dart';

/// Registre central des modules (façon « catalogue d'apps » Odoo).
/// Source UNIQUE des deux surfaces de navigation du desktop :
///  - la sidebar desktop  → [sidebar]
///  - la bottom-nav mobile → [bottomNav]
///
/// En mode `retail` (défaut), chaque surface reproduit exactement la
/// navigation historique (même items, même ordre) → aucun changement visuel.
/// Ajouter un module = ajouter une entrée ici, sans toucher au shell.
class ModuleRegistry {
  const ModuleRegistry._();

  static const Set<ActivityMode> _allModes = {
    ActivityMode.retail,
    ActivityMode.restaurant,
    ActivityMode.hotel,
    ActivityMode.services,
  };

  static const List<AppModule> all = [
    // ── Socle commun (sidebar + bottom-nav) ────────────────────────────
    AppModule(
      id: 'dashboard',
      label: 'Tableau de bord',
      icon: Icons.dashboard_outlined,
      activeIcon: Icons.dashboard,
      route: '/dashboard',
      modes: _allModes,
      primary: true,
      order: 0,
      inSidebar: true,
      sidebarOrder: 0,
    ),
    // Revenus / Charges : deux entrées distinctes en sidebar desktop,
    // fusionnées en un seul onglet « Opérations » sur la bottom-nav mobile.
    AppModule(
      id: 'sales',
      label: 'Revenus',
      icon: Icons.point_of_sale_outlined,
      activeIcon: Icons.point_of_sale,
      route: '/sales',
      modes: _allModes,
      inSidebar: true,
      sidebarOrder: 1,
    ),
    AppModule(
      id: 'expenses',
      label: 'Charges',
      icon: Icons.receipt_long_outlined,
      activeIcon: Icons.receipt_long,
      route: '/expenses',
      modes: _allModes,
      inSidebar: true,
      sidebarOrder: 2,
    ),
    AppModule(
      id: 'operations',
      label: 'Opérations',
      icon: Icons.swap_horiz,
      activeIcon: Icons.swap_horiz_outlined,
      route: '/operations',
      modes: _allModes,
      primary: true,
      order: 1,
    ),
    AppModule(
      id: 'inventory',
      label: 'Stock',
      icon: Icons.inventory_2_outlined,
      activeIcon: Icons.inventory_2,
      route: '/inventory',
      modes: _allModes,
      primary: true,
      order: 2,
      inSidebar: true,
      sidebarOrder: 3,
    ),
    AppModule(
      id: 'contacts',
      label: 'Contacts',
      icon: Icons.groups_outlined,
      activeIcon: Icons.groups,
      route: '/contacts',
      modes: _allModes,
      primary: true,
      order: 3,
      inSidebar: true,
      sidebarOrder: 4,
      dividerBefore: true,
    ),
    AppModule(
      id: 'adha',
      label: 'Adha IA',
      icon: Icons.chat_bubble_outline,
      activeIcon: Icons.chat_bubble,
      route: '/adha',
      modes: _allModes,
      primary: true,
      order: 4,
      inSidebar: true,
      sidebarOrder: 5,
      dividerBefore: true,
      isAdhaPanel: true,
    ),
    AppModule(
      id: 'settings',
      label: 'Paramètres',
      icon: Icons.settings_outlined,
      activeIcon: Icons.settings,
      route: '/settings',
      modes: _allModes,
      inSidebar: true,
      sidebarOrder: 6,
      dividerBefore: true,
    ),

    // ── Modules métier futurs (déclarés, écrans à venir → available:false).
    AppModule(
      id: 'restaurant_orders',
      label: 'Commandes',
      icon: Icons.restaurant_menu,
      activeIcon: Icons.restaurant,
      route: '/restaurant/orders',
      modes: {ActivityMode.restaurant},
      primary: true,
      order: 1,
      inSidebar: true,
      sidebarOrder: 1,
      available: false,
    ),
    AppModule(
      id: 'restaurant_tables',
      label: 'Salle',
      icon: Icons.table_restaurant,
      activeIcon: Icons.table_bar,
      route: '/restaurant/tables',
      modes: {ActivityMode.restaurant},
      primary: true,
      order: 2,
      inSidebar: true,
      sidebarOrder: 2,
      available: false,
    ),
    AppModule(
      id: 'hotel_rooms',
      label: 'Chambres',
      icon: Icons.hotel,
      activeIcon: Icons.king_bed,
      route: '/hotel/rooms',
      modes: {ActivityMode.hotel},
      primary: true,
      order: 1,
      inSidebar: true,
      sidebarOrder: 1,
      available: false,
    ),
    AppModule(
      id: 'hotel_reservations',
      label: 'Réservations',
      icon: Icons.event_available,
      activeIcon: Icons.event,
      route: '/hotel/reservations',
      modes: {ActivityMode.hotel},
      primary: true,
      order: 2,
      inSidebar: true,
      sidebarOrder: 2,
      available: false,
    ),
  ];

  /// Items de la sidebar desktop pour un [mode]/[role], triés.
  static List<AppModule> sidebar(ActivityMode mode, String? role) =>
      all.where((m) => m.inSidebar && m.visibleFor(mode, role)).toList()
        ..sort((a, b) => a.sidebarOrder.compareTo(b.sidebarOrder));

  /// Items de la bottom-nav (layout mobile du desktop), max 5, triés.
  static List<AppModule> bottomNav(ActivityMode mode, String? role) {
    final items =
        all.where((m) => m.primary && m.visibleFor(mode, role)).toList()
          ..sort((a, b) => a.order.compareTo(b.order));
    return items.length > 5 ? items.sublist(0, 5) : items;
  }
}
