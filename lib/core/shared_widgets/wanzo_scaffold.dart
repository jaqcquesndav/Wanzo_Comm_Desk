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
    // Le shell écoute BusinessContextService : changer de mode d'activité
    // recompose immédiatement la navigation (sidebar / bottom-nav) sans
    // redémarrage ni navigation manuelle.
    return ListenableBuilder(
      listenable: BusinessContextService(),
      builder: (context, _) {
        // Navigation DÉRIVÉE du registre de modules (source unique), filtrée
        // par mode + rôle. En mode `retail` (défaut) : navigation historique
        // identique → aucun changement visuel.
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

    // En-tête de section porté par le PREMIER item de chaque groupe (le shell
    // le dérive du champ `section` du module) : regroupement visuel clair sans
    // décaler l'index de navigation.
    final sidebarModules = ModuleRegistry.sidebar(mode, role);
    String? previousSection;
    final List<SidebarNavItem> desktopNavItems = [
      for (final m in sidebarModules)
        () {
          final header = (m.section != null && m.section != previousSection)
              ? m.section
              : null;
          previousSection = m.section;
          return SidebarNavItem(
            icon: m.icon,
            activeIcon: m.activeIcon,
            label: m.label,
            route: m.route,
            isDividerBefore: m.dividerBefore,
            isAdhaPanel: m.isAdhaPanel,
            sectionHeader: header,
          );
        }(),
    ];

    // L'élément actif est DÉRIVÉ de la route courante (pas d'un index codé en
    // dur par l'écran) : la surbrillance reste correcte quel que soit le mode,
    // sidebar et bottom-nav ayant des ordres différents. Repli sur currentIndex
    // pour les écrans hors nav (ex. -1).
    final loc = GoRouterState.of(context).uri.path;
    final sidebarDerived = desktopNavItems.indexWhere(
      (m) => loc == m.route || loc.startsWith('${m.route}/'),
    );
    final bottomDerived = mobileNavItems.indexWhere(
      (m) => loc == m.route || loc.startsWith('${m.route}/'),
    );
    // Purement route-dérivé : si la route courante n'est pas un élément de la
    // surface (ex. /operations absent de la sidebar, /settings absent de la
    // bottom-nav), on ne surligne RIEN (-1) plutôt que de retomber sur un
    // index d'une autre surface qui surlignerait le mauvais élément.
    final sidebarActive = sidebarDerived;
    final bottomActive = bottomDerived;

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
            currentIndex: sidebarActive,
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
              bottomActive >= 0 && bottomActive < mobileNavItems.length
                  ? WanzoBottomNavigationBar(
                    currentIndex: bottomActive,
                    items: mobileNavItems,
                    onTap: (index) {
                      if (index == bottomActive) return;
                      if (index < 0 || index >= mobileNavItems.length) return;
                      context.go(mobileNavItems[index].route);
                    },
                  )
                  : null,
          floatingActionButton: floatingActionButton,
        );
      },
    );
      },
    );
  }
}
