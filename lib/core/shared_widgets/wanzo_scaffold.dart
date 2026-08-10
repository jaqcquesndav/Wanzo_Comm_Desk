import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'wanzo_app_bar.dart';
import 'wanzo_bottom_navigation_bar.dart';
import '../platform/platform_service.dart';
import '../modules/module_registry.dart';
import '../services/business_context_service.dart';
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
    // Navigation DÉRIVÉE du registre de modules (source unique), filtrée par
    // mode d'activité + rôle. En mode `retail` (défaut) ces listes reproduisent
    // exactement la navigation historique (mêmes items, même ordre) → aucun
    // changement visuel. Ajouter un onglet = éditer ModuleRegistry.
    final ctx = BusinessContextService();
    final mode = ctx.activityMode;
    final role = ctx.currentContext?.userRole;

    final List<BottomNavItem> mobileNavItems = [
      for (final m in ModuleRegistry.bottomNav(mode, role))
        BottomNavItem(
          icon: m.icon,
          activeIcon: m.activeIcon,
          label: m.label,
          route: m.route,
        ),
    ];

    final List<SidebarNavItem> desktopNavItems = [
      for (final m in ModuleRegistry.sidebar(mode, role))
        SidebarNavItem(
          icon: m.icon,
          activeIcon: m.activeIcon,
          label: m.label,
          route: m.route,
          isDividerBefore: m.dividerBefore,
          isAdhaPanel: m.isAdhaPanel,
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
                      if (index < 0 || index >= mobileNavItems.length) return;
                      context.go(mobileNavItems[index].route);
                    },
                  )
                  : null,
          floatingActionButton: floatingActionButton,
        );
      },
    );
  }
}
