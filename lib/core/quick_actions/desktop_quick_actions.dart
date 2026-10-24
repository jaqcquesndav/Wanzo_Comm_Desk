import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../features/atelier/models/atelier_order.dart';
import '../modules/activity_mode.dart';
import '../modules/module_registry.dart';
import '../services/form_navigation_service.dart';

/// Une action rapide du shell desktop.
///
/// Une action FAIT quelque chose (créer, encaisser) : elle ne doit pas
/// recopier une entrée de la sidebar, qui sert à naviguer.
@immutable
class DesktopQuickAction {
  /// Identifiant stable (tests, clés de widget).
  final String id;

  /// Libellé court, dans le vocabulaire du mode.
  final String label;

  final IconData icon;

  /// Couleur de la pastille de l'action dans le dock.
  final Color color;

  /// Exécution. Le `context` est celui du shell (sous le routeur et les blocs
  /// globaux) : formulaires modaux de [FormNavigationService] ou navigation.
  final void Function(BuildContext context) run;

  /// Routes où l'écran offre DÉJÀ cette action (bouton propre, FAB) : le dock
  /// la masque pour ne jamais la proposer deux fois.
  final Set<String> hiddenOn;

  /// Routes où cette action est l'action principale de l'écran : le dock la
  /// place en premier.
  final Set<String> primaryOn;

  /// Module dont la visibilité conditionne l'action (même gating mode et rôle
  /// que la navigation, via [ModuleRegistry]). `null` = toujours visible.
  final String? moduleId;

  /// Rôles autorisés (mêmes valeurs que `AppModule.roles`). `null` = tous.
  final Set<String>? roles;

  const DesktopQuickAction({
    required this.id,
    required this.label,
    required this.icon,
    required this.color,
    required this.run,
    this.hiddenOn = const {},
    this.primaryOn = const {},
    this.moduleId,
    this.roles,
  });
}

/// Intention transmise à l'écran de destination quand l'action ne peut pas
/// s'exécuter depuis le shell (le cubit du formulaire vit sous la route) :
/// l'action dépose l'intention puis navigue, l'écran la consomme une fois.
abstract final class QuickActionIntents {
  static String? _pending;

  static const atelierNewWork = 'atelier.nouveau';
  static const restaurantNewOrder = 'restaurant.nouvelle-commande';
  static const salonNewService = 'salon.nouvelle-prestation';

  /// Dépose [intent] puis navigue vers [route].
  static void goWith(BuildContext context, String intent, String route) {
    _pending = intent;
    context.go(route);
  }

  /// `true` (une seule fois) si [intent] est en attente.
  static bool take(String intent) {
    if (_pending != intent) return false;
    _pending = null;
    return true;
  }

  @visibleForTesting
  static String? get pending => _pending;
}

/// Résultat pour un écran : actions visibles, la première est l'action mise
/// en avant.
@immutable
class ResolvedQuickActions {
  final List<DesktopQuickAction> actions;
  final String? primaryId;
  const ResolvedQuickActions(this.actions, this.primaryId);
}

/// Configuration UNIQUE des actions rapides desktop, par mode d'activité.
abstract final class DesktopQuickActionsCatalog {
  /// Au plus 6 actions par mode (pas de surcharge).
  static const int maxActions = 6;

  /// Écrans principaux hors sidebar qui portent aussi le dock (la sidebar
  /// fournit les autres).
  static const Set<String> _extraMainRoutes = {
    '/operations',
    '/receivables',
    '/cash-session',
    '/restaurant/orders',
    '/restaurant/menu',
    '/salon/sale',
  };

  /// `true` si [path] est un écran principal du [mode] : une entrée de la
  /// sidebar (route exacte) ou un écran de travail connu. Les fiches et
  /// formulaires (`/inventory/add`, `/sale-detail/…`) n'ont pas le dock.
  static bool isMainRoute(String path, ActivityMode mode, String? role) {
    if (_extraMainRoutes.contains(path)) return true;
    return ModuleRegistry.sidebar(mode, role).any((m) => m.route == path);
  }

  static const _sales = {'/sales', '/operations'};
  static const _expenses = {'/expenses', '/operations'};

  static DesktopQuickAction _expense() => DesktopQuickAction(
        id: 'expense',
        label: 'Nouvelle dépense',
        icon: Icons.receipt_long,
        color: Colors.redAccent,
        hiddenOn: _expenses,
        primaryOn: const {'/expenses'},
        run: (c) => FormNavigationService.instance.openExpenseForm(c),
      );

  static DesktopQuickAction _customer() => DesktopQuickAction(
        id: 'customer',
        label: 'Nouveau client',
        icon: Icons.person_add_alt_1,
        color: Colors.blueAccent,
        hiddenOn: const {'/contacts'},
        primaryOn: const {'/receivables'},
        run: (c) => FormNavigationService.instance.openCustomerForm(c),
      );

  static DesktopQuickAction _supplier() => DesktopQuickAction(
        id: 'supplier',
        label: 'Nouveau fournisseur',
        icon: Icons.local_shipping_outlined,
        color: Colors.purpleAccent,
        hiddenOn: const {'/contacts'},
        run: (c) => FormNavigationService.instance.openSupplierForm(c),
      );

  static DesktopQuickAction _sale(String label, {String id = 'sale'}) =>
      DesktopQuickAction(
        id: id,
        label: label,
        icon: Icons.add_shopping_cart,
        color: Colors.green,
        hiddenOn: _sales,
        run: (c) => FormNavigationService.instance.openSaleForm(c),
      );

  static DesktopQuickAction _item(String label) => DesktopQuickAction(
        id: 'item',
        label: label,
        icon: Icons.inventory_2_outlined,
        color: Colors.orange,
        hiddenOn: const {'/inventory'},
        run: (c) => FormNavigationService.instance.openProductForm(c),
      );

  static DesktopQuickAction _restaurantNewOrder() => DesktopQuickAction(
        id: 'restaurant_new_order',
        label: 'Nouvelle commande',
        icon: Icons.add_shopping_cart,
        color: const Color(0xFF0EA5E9),
        moduleId: 'restaurant_orders',
        // La caisse et le plan de salle ont leur propre bouton de création.
        hiddenOn: const {'/restaurant/orders', '/restaurant/board'},
        primaryOn: const {'/restaurant/tables', '/dashboard'},
        run: (c) => QuickActionIntents.goWith(
          c,
          QuickActionIntents.restaurantNewOrder,
          '/restaurant/orders',
        ),
      );

  static DesktopQuickAction _restaurantCheckout() => DesktopQuickAction(
        id: 'restaurant_checkout',
        label: 'Encaisser',
        icon: Icons.point_of_sale,
        color: const Color(0xFF16A34A),
        moduleId: 'restaurant_orders',
        // Le plan de salle a « Ouvrir la caisse » ; la caisse, c'est ici.
        hiddenOn: const {'/restaurant/orders', '/restaurant/board'},
        primaryOn: const {'/restaurant/kitchen'},
        run: (c) => c.go('/restaurant/orders'),
      );

  /// Caisse du jour : ouverture, suivi, clôture et rapport.
  static DesktopQuickAction _cashSession() => DesktopQuickAction(
        id: 'cash_session',
        label: 'Caisse',
        icon: Icons.point_of_sale_outlined,
        color: const Color(0xFF0D9488),
        hiddenOn: const {'/cash-session'},
        run: (c) => c.push('/cash-session'),
      );

  static DesktopQuickAction _restaurantMenu() => DesktopQuickAction(
        id: 'restaurant_menu',
        label: 'Carte',
        icon: Icons.menu_book,
        color: const Color(0xFF8B5CF6),
        moduleId: 'restaurant_orders',
        // La caisse a déjà « Composer la carte ».
        hiddenOn: const {'/restaurant/menu', '/restaurant/orders'},
        run: (c) => c.push('/restaurant/menu'),
      );

  /// Actions du [mode], avant filtrage par écran.
  static List<DesktopQuickAction> forMode(ActivityMode mode) {
    switch (mode) {
      case ActivityMode.retail:
        return [
          _sale('Nouvelle vente'),
          _item('Nouveau produit'),
          _expense(),
          _customer(),
          _supplier(),
          _cashSession(),
        ];
      case ActivityMode.services:
        return [
          _sale('Nouvelle prestation'),
          DesktopQuickAction(
            id: 'service',
            label: 'Nouveau service',
            icon: Icons.design_services_outlined,
            color: Colors.orange,
            hiddenOn: const {'/inventory'},
            run: (c) => FormNavigationService.instance.openServiceForm(c),
          ),
          _expense(),
          _customer(),
          _supplier(),
          _cashSession(),
        ];
      case ActivityMode.restaurant:
        return [
          _restaurantNewOrder(),
          _restaurantCheckout(),
          // Un restaurant vend aussi des produits hors carte (boissons…).
          _sale('Vente directe', id: 'direct_sale'),
          _restaurantMenu(),
          _expense(),
          _cashSession(),
        ];
      case ActivityMode.salon:
        return [
          DesktopQuickAction(
            id: 'salon_ticket',
            label: 'Nouveau ticket',
            icon: Icons.receipt_long,
            color: const Color(0xFF0EA5E9),
            moduleId: 'salon_prestations',
            hiddenOn: const {'/salon/sale'},
            primaryOn: const {'/dashboard', '/salon/stylists'},
            run: (c) => c.go('/salon/sale'),
          ),
          DesktopQuickAction(
            id: 'salon_service',
            label: 'Nouvelle prestation',
            icon: Icons.content_cut,
            color: const Color(0xFF8B5CF6),
            moduleId: 'salon_prestations',
            hiddenOn: const {'/salon/prestations'},
            run: (c) => QuickActionIntents.goWith(
              c,
              QuickActionIntents.salonNewService,
              '/salon/prestations',
            ),
          ),
          _customer(),
          _expense(),
          _cashSession(),
        ];
      case ActivityMode.atelier:
      case ActivityMode.atelierMaintenance:
      case ActivityMode.imprimerie:
      case ActivityMode.pressing:
      case ActivityMode.garage:
        final metier = atelierMetierForMode(mode);
        return [
          DesktopQuickAction(
            id: 'atelier_new_work',
            label: metier.newWorkLabel,
            icon: Icons.add_task,
            color: const Color(0xFF0EA5E9),
            hiddenOn: const {'/atelier/board'},
            primaryOn: const {'/dashboard', '/garage/parc'},
            run: (c) => QuickActionIntents.goWith(
              c,
              QuickActionIntents.atelierNewWork,
              '/atelier/board',
            ),
          ),
          _customer(),
          _item(_newItemLabel(mode)),
          _expense(),
        ];
    }
  }

  static String _newItemLabel(ActivityMode mode) {
    switch (mode) {
      case ActivityMode.atelier:
        return 'Nouvel intrant';
      case ActivityMode.atelierMaintenance:
      case ActivityMode.garage:
        return 'Nouvelle pièce';
      case ActivityMode.imprimerie:
      case ActivityMode.pressing:
        return 'Nouveau consommable';
      default:
        return 'Nouveau produit';
    }
  }

  static bool _matches(Set<String> routes, String path) =>
      routes.any((r) => path == r || path.startsWith('$r/'));

  /// Actions visibles sur [path] pour [mode] et [role] : gating par module et
  /// rôle, sans les actions que l'écran offre déjà, action principale en tête.
  static ResolvedQuickActions resolve({
    required ActivityMode mode,
    required String? role,
    required String path,
  }) {
    final visibleModules = {
      for (final m in ModuleRegistry.all)
        if (m.visibleFor(mode, role)) m.id,
    };
    final actions = [
      for (final a in forMode(mode))
        if ((a.moduleId == null || visibleModules.contains(a.moduleId)) &&
            (a.roles == null || (role != null && a.roles!.contains(role))) &&
            !_matches(a.hiddenOn, path))
          a,
    ];
    if (actions.isEmpty) return const ResolvedQuickActions([], null);
    final primary = actions.firstWhere(
      (a) => _matches(a.primaryOn, path),
      orElse: () => actions.first,
    );
    final ordered = [primary, ...actions.where((a) => a != primary)];
    return ResolvedQuickActions(
      ordered.take(maxActions).toList(),
      primary.id,
    );
  }

  /// Actions du dock flottant pour l'écran [path] : vide hors écran
  /// principal (fiches, formulaires), le shell ne pose alors pas de dock.
  static List<DesktopQuickAction> forScreen({
    required ActivityMode mode,
    required String? role,
    required String path,
  }) {
    if (!isMainRoute(path, mode, role)) return const [];
    return resolve(
      mode: mode,
      role: role,
      path: path,
    ).actions;
  }
}
