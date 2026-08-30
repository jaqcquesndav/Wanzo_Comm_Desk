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
    ActivityMode.atelier,
    ActivityMode.atelierMaintenance,
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
      // La vue « Commandes » est le board Kanban (aperçu par statut, façon
      // Trello) ; la caisse reste à un tap via le bouton dédié du board.
      route: '/restaurant/board',
      // Restauration/bar en mode restaurant ET hôtellerie (les hôtels
      // combinent F&B/bar/salle) → prise de commande sur carte disponible.
      modes: {ActivityMode.restaurant, ActivityMode.hotel},
      primary: true,
      order: 1,
      inSidebar: true,
      sidebarOrder: 1,
      available: true,
    ),
    // Écran cuisine (KDS) — plein écran des commandes envoyées en préparation.
    AppModule(
      id: 'restaurant_kitchen',
      label: 'Cuisine',
      icon: Icons.soup_kitchen_outlined,
      activeIcon: Icons.soup_kitchen,
      route: '/restaurant/kitchen',
      modes: {ActivityMode.restaurant, ActivityMode.hotel},
      primary: true,
      order: 2,
      inSidebar: true,
      sidebarOrder: 2,
      available: true,
    ),
    // ── Mode Atelier (couture/cordonnerie) ──────────────────────────────
    // Deux entrées pour la MÊME route : icône adaptée au métier (une seule est
    // visible à la fois selon le mode) — plus de ciseaux en mode maintenance.
    AppModule(
      id: 'atelier_orders',
      label: 'Commandes',
      icon: Icons.content_cut_outlined,
      activeIcon: Icons.content_cut,
      route: '/atelier/board',
      modes: {ActivityMode.atelier},
      primary: true,
      order: 1,
      inSidebar: true,
      sidebarOrder: 1,
      available: true,
    ),
    AppModule(
      id: 'atelier_maintenance_orders',
      label: 'Commandes',
      icon: Icons.handyman_outlined,
      activeIcon: Icons.handyman,
      route: '/atelier/board',
      modes: {ActivityMode.atelierMaintenance},
      primary: true,
      order: 1,
      inSidebar: true,
      sidebarOrder: 1,
      available: true,
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
  ///
  /// Tri DÉTERMINISTE : à `sidebarOrder` égal (ex. `sales` et
  /// `restaurant_orders` valent 1), le module spécialisé du métier passe avant
  /// le module commun — sinon l'ordre relatif serait indéfini (`List.sort`
  /// n'est pas stable en Dart).
  static List<AppModule> sidebar(ActivityMode mode, String? role) =>
      all.where((m) => m.inSidebar && m.visibleFor(mode, role)).toList()
        ..sort((a, b) {
          final byOrder = a.sidebarOrder.compareTo(b.sidebarOrder);
          if (byOrder != 0) return byOrder;
          final aSpec = !a.modes.contains(ActivityMode.retail);
          final bSpec = !b.modes.contains(ActivityMode.retail);
          if (aSpec == bSpec) return a.id.compareTo(b.id);
          return aSpec ? -1 : 1;
        });

  /// Items de la bottom-nav (layout mobile du desktop), max 5.
  ///
  /// Comme sur mobile, les modules SPÉCIALISÉS d'un métier (non-`retail`, ex.
  /// Commandes en restaurant) ne sont jamais évincés par la troncature ; les
  /// communs remplissent le reste. En `retail` le résultat est identique à
  /// l'historique (aucun module spécialisé).
  static List<AppModule> bottomNav(ActivityMode mode, String? role) {
    const maxSlots = 5;
    final visible =
        all.where((m) => m.primary && m.visibleFor(mode, role)).toList();
    final specialized =
        visible.where((m) => !m.modes.contains(ActivityMode.retail)).toList()
          ..sort((a, b) => a.order.compareTo(b.order));
    final common =
        visible.where((m) => m.modes.contains(ActivityMode.retail)).toList()
          ..sort((a, b) => a.order.compareTo(b.order));
    final kept = <AppModule>[
      ...specialized.take(maxSlots),
      ...common.take((maxSlots - specialized.length).clamp(0, maxSlots)),
    ]..sort((a, b) {
        final byOrder = a.order.compareTo(b.order);
        if (byOrder != 0) return byOrder;
        final aSpec = !a.modes.contains(ActivityMode.retail);
        final bSpec = !b.modes.contains(ActivityMode.retail);
        if (aSpec == bSpec) return 0;
        return aSpec ? -1 : 1;
      });
    return kept;
  }

  /// Index d'une route dans la sidebar (pour `currentIndex` du scaffold desktop).
  static int indexOfSidebarRoute(ActivityMode mode, String? role, String route) =>
      sidebar(mode, role).indexWhere((m) => m.route == route);
}
