import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'wanzo_app_bar.dart';
import 'wanzo_bottom_navigation_bar.dart';
import '../platform/platform_service.dart';
import '../widgets/desktop/adaptive_scaffold.dart';

/// Structure de base pour les écrans principaux de l'application
/// Intègre l'AppBar commun et la barre de navigation (bottom sur mobile, sidebar sur desktop)
class WanzoScaffold extends StatelessWidget {
  /// L'index actif dans la navigation
  final int currentIndex;

  /// Le titre à afficher dans l'AppBar
  final String title;

  /// Le contenu principal de l'écran
  final Widget body;

  /// Bouton d'action flottant (optionnel)
  final Widget? floatingActionButton;

  /// Actions additionnelles pour l'AppBar
  final List<Widget>? appBarActions;

  /// Callback pour le bouton de retour (null = pas de bouton)
  final VoidCallback? onBackPressed;

  /// Constructeur
  const WanzoScaffold({
    super.key,
    required this.currentIndex,
    required this.title,
    required this.body,
    this.floatingActionButton,
    this.appBarActions,
    this.onBackPressed,
  });

  @override
  Widget build(BuildContext context) {
    // Items de navigation utilisés pour mobile et desktop
    final List<BottomNavItem> mobileNavItems = [
      BottomNavItem(
        icon: Icons.dashboard,
        activeIcon: Icons.dashboard_outlined,
        label: 'Tableau de bord',
        route: '/dashboard',
      ),
      BottomNavItem(
        icon: Icons.swap_horiz,
        activeIcon: Icons.swap_horiz_outlined,
        label: 'Opérations',
        route: '/operations',
      ),
      BottomNavItem(
        icon: Icons.inventory,
        activeIcon: Icons.inventory_outlined,
        label: 'Stock',
        route: '/inventory',
      ),
      BottomNavItem(
        icon: Icons.groups,
        activeIcon: Icons.groups_outlined,
        label: 'Contacts',
        route: '/contacts',
      ),
      BottomNavItem(
        icon: Icons.smart_toy,
        activeIcon: Icons.smart_toy_outlined,
        label: 'Adha',
        route: '/adha',
      ),
    ];

    // Items de navigation pour desktop (avec plus d'options)
    // Organisation: Dashboard, Ventes, Dépenses, Stock, Financement, Contacts, Adha, Paramètres
    final List<SidebarNavItem> desktopNavItems = [
      const SidebarNavItem(
        icon: Icons.dashboard_outlined,
        activeIcon: Icons.dashboard,
        label: 'Tableau de bord',
        route: '/dashboard',
      ),
      const SidebarNavItem(
        icon: Icons.point_of_sale_outlined,
        activeIcon: Icons.point_of_sale,
        label:
            'Revenus', // Terminologie comptable : ventes = revenus / chiffre d'affaires
        route: '/sales', // Route directe vers la page des revenus
      ),
      const SidebarNavItem(
        icon: Icons.receipt_long_outlined,
        activeIcon: Icons.receipt_long,
        label: 'Charges', // Terminologie comptable : dépenses = charges
        route: '/expenses', // Route directe vers la page des charges
      ),
      const SidebarNavItem(
        icon: Icons.inventory_2_outlined,
        activeIcon: Icons.inventory_2,
        label: 'Stock',
        route: '/inventory',
      ),
      const SidebarNavItem(
        icon: Icons.account_balance_outlined,
        activeIcon: Icons.account_balance,
        label: 'Financement',
        route: '/financing', // Route directe vers la page de financement
        isDividerBefore: true,
      ),
      const SidebarNavItem(
        icon: Icons.groups_outlined,
        activeIcon: Icons.groups,
        label: 'Contacts',
        route: '/contacts',
      ),
      const SidebarNavItem(
        icon: Icons.chat_bubble_outline, // Icône de chat pour Adha
        activeIcon: Icons.chat_bubble,
        label: 'Adha IA',
        route: '/adha',
        isDividerBefore: true,
        isAdhaPanel: true, // Marque comme panneau Adha
      ),
      const SidebarNavItem(
        icon: Icons.settings_outlined,
        activeIcon: Icons.settings,
        label: 'Paramètres',
        route: '/settings',
        isDividerBefore: true,
      ),
    ];

    // Utiliser LayoutBuilder pour détecter la taille de l'écran
    return LayoutBuilder(
      builder: (context, constraints) {
        final platform = PlatformService.instance;
        final isDesktopSize = constraints.maxWidth >= platform.desktopMinWidth;
        final isTabletSize =
            constraints.maxWidth >= platform.tabletMinWidth &&
            constraints.maxWidth < platform.desktopMinWidth;

        // Sur desktop et tablette, utiliser AdaptiveScaffold avec sidebar
        if (isDesktopSize || isTabletSize) {
          return AdaptiveScaffold(
            currentIndex: currentIndex,
            title: title,
            body: body,
            navigationItems: desktopNavItems,
            floatingActionButton: floatingActionButton,
            appBarActions: appBarActions,
            onBackPressed: onBackPressed,
          );
        }

        // Sur mobile, utiliser le layout traditionnel avec bottom navigation
        return Scaffold(
          appBar: WanzoAppBar(
            title: title,
            additionalActions: appBarActions,
            onBackPressed: onBackPressed,
          ),
          body: body,
          bottomNavigationBar:
              currentIndex >= 0 && currentIndex < mobileNavItems.length
                  ? WanzoBottomNavigationBar(
                    currentIndex: currentIndex,
                    items: mobileNavItems,
                    onTap: (index) {
                      if (index == currentIndex) return;
                      switch (index) {
                        case 0:
                          context.go('/dashboard');
                          break;
                        case 1:
                          context.go('/operations');
                          break;
                        case 2:
                          context.go('/inventory');
                          break;
                        case 3:
                          context.go('/contacts');
                          break;
                        case 4:
                          context.go('/adha');
                          break;
                        default:
                          context.go('/dashboard');
                      }
                    },
                  )
                  : null,
          floatingActionButton: floatingActionButton,
        );
      },
    );
  }
}
