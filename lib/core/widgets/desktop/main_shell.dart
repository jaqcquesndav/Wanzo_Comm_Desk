import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../../features/adha/bloc/adha_bloc.dart';
import '../../../features/adha/widgets/adha_chat_panel.dart';
import '../../platform/platform_service.dart';
import '../../shared_widgets/wanzo_app_bar.dart';
import '../../shared_widgets/wanzo_bottom_navigation_bar.dart';
import '../../modules/module_registry.dart';
import '../../services/business_context_service.dart';
import 'adaptive_scaffold.dart';
import 'desktop_header.dart';
import 'desktop_layout_state.dart';
import 'desktop_sidebar.dart';

/// Shell principal persistant pour la navigation principale.
/// Survit aux changements de route et conserve l'état du layout (sidebar, panneau Adha).
/// Similaire au shell VS Code où la sidebar reste ouverte pendant la navigation.
class MainShell extends StatefulWidget {
  /// Le contenu de la page courante (injecté par go_router)
  final Widget child;

  const MainShell({super.key, required this.child});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  late final DesktopLayoutState _layoutState;

  @override
  void initState() {
    super.initState();
    _layoutState = DesktopLayoutState();
  }

  @override
  void dispose() {
    _layoutState.dispose();
    super.dispose();
  }

  /// Détermine l'index courant basé sur la route actuelle
  int _getCurrentIndex(BuildContext context) {
    final location = GoRouterState.of(context).uri.path;

    if (location.startsWith('/dashboard')) return 0;
    if (location.startsWith('/sales')) return 1;
    if (location.startsWith('/expenses')) return 2;
    if (location.startsWith('/inventory')) return 3;
    if (location.startsWith('/contacts')) return 4;
    if (location.startsWith('/adha')) return 5;
    if (location.startsWith('/settings')) return 6;

    return 0; // Default to dashboard
  }

  /// Récupère le titre basé sur la route actuelle
  String _getTitle(BuildContext context) {
    final location = GoRouterState.of(context).uri.path;

    if (location.startsWith('/dashboard')) return 'Tableau de bord';
    if (location.startsWith('/sales')) return 'Revenus';
    if (location.startsWith('/expenses')) return 'Charges';
    if (location.startsWith('/inventory')) return 'Stock';
    if (location.startsWith('/contacts')) return 'Contacts';
    if (location.startsWith('/adha')) return 'Adha IA';
    if (location.startsWith('/settings')) return 'Paramètres';
    if (location.startsWith('/profile')) return 'Profil';
    if (location.startsWith('/notifications')) return 'Notifications';
    if (location.startsWith('/operations')) return 'Opérations';

    return 'Wanzo';
  }

  /// Items de navigation pour desktop
  // Navigation DÉRIVÉE du registre de modules (source unique), filtrée par
  // mode d'activité + rôle. En mode `retail` (défaut) ces getters reproduisent
  // exactement les listes historiques (mêmes items, même ordre) → aucun
  // changement visuel. Ajouter un onglet = éditer ModuleRegistry.
  List<SidebarNavItem> get _desktopNavItems {
    final ctx = BusinessContextService();
    return [
      for (final m in ModuleRegistry.sidebar(
        ctx.activityMode,
        ctx.currentContext?.userRole,
      ))
        SidebarNavItem(
          icon: m.icon,
          activeIcon: m.activeIcon,
          label: m.label,
          route: m.route,
          isDividerBefore: m.dividerBefore,
          isAdhaPanel: m.isAdhaPanel,
        ),
    ];
  }

  /// Items de navigation pour mobile (dérivés du registre).
  List<BottomNavItem> get _mobileNavItems {
    final ctx = BusinessContextService();
    return [
      for (final m in ModuleRegistry.bottomNav(
        ctx.activityMode,
        ctx.currentContext?.userRole,
      ))
        BottomNavItem(
          icon: m.icon,
          activeIcon: m.activeIcon,
          label: m.label,
          route: m.route,
        ),
    ];
  }

  int _getMobileCurrentIndex(BuildContext context) {
    final location = GoRouterState.of(context).uri.path;

    if (location.startsWith('/dashboard')) return 0;
    if (location.startsWith('/operations') ||
        location.startsWith('/sales') ||
        location.startsWith('/expenses')) {
      return 1;
    }
    if (location.startsWith('/inventory')) return 2;
    if (location.startsWith('/contacts')) return 3;
    if (location.startsWith('/adha')) return 4;

    return 0;
  }

  @override
  Widget build(BuildContext context) {
    return DesktopLayoutProvider(
      state: _layoutState,
      child: ListenableBuilder(
        listenable: _layoutState,
        builder: (context, _) {
          return LayoutBuilder(
            builder: (context, constraints) {
              final platform = PlatformService.instance;
              final isDesktopSize =
                  constraints.maxWidth >= platform.desktopMinWidth;
              final isTabletSize =
                  constraints.maxWidth >= platform.tabletMinWidth &&
                  constraints.maxWidth < platform.desktopMinWidth;

              if (isDesktopSize) {
                return _buildDesktopLayout(context, constraints);
              } else if (isTabletSize) {
                return _buildTabletLayout(context);
              } else {
                return _buildMobileLayout(context);
              }
            },
          );
        },
      ),
    );
  }

  Widget _buildDesktopLayout(BuildContext context, BoxConstraints constraints) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final currentIndex = _getCurrentIndex(context);
    final title = _getTitle(context);

    // Convertir les items de navigation
    final desktopNavItems =
        _desktopNavItems.map((item) => item.toDesktopNavItem()).toList();

    // Si Adha est en fullscreen, montrer uniquement le panneau Adha
    if (_layoutState.isAdhaPanelFullscreen) {
      return Scaffold(
        body: _buildAdhaPanelContent(context, isFullscreen: true),
      );
    }

    // Calculer la largeur du sidebar (auto-collapse si Adha est ouvert et espace limité)
    final bool shouldAutoCollapseSidebar =
        _layoutState.isAdhaPanelOpen &&
        constraints.maxWidth < 1200 &&
        _layoutState.isSidebarExpanded;

    final bool effectiveSidebarExpanded =
        shouldAutoCollapseSidebar ? false : _layoutState.isSidebarExpanded;

    return Scaffold(
      body: Column(
        children: [
          // Header en haut, sur toute la largeur
          DesktopHeader(
            title: title,
            isSidebarExpanded: effectiveSidebarExpanded,
            onToggleSidebar: () => _layoutState.toggleSidebar(),
            actions: [
              // Bouton pour ouvrir/fermer Adha
              _buildAdhaToggleButton(context, isDark),
            ],
          ),

          // Contenu en dessous : Sidebar + Main content
          Expanded(
            child: Row(
              children: [
                // Sidebar (sans header - le header est au-dessus)
                DesktopSidebar(
                  currentIndex: currentIndex,
                  items: desktopNavItems,
                  isExpanded: effectiveSidebarExpanded,
                  onToggleExpand: () => _layoutState.toggleSidebar(),
                  onItemSelected:
                      (index) => _handleNavItemTapped(context, index),
                ),

                // Zone principale (content + panneau Adha optionnel)
                Expanded(
                  child:
                      _layoutState.isAdhaPanelOpen
                          ? _buildSplitView(context, isDark)
                          : widget.child,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Bouton pour toggle le panneau Adha dans le header
  Widget _buildAdhaToggleButton(BuildContext context, bool isDark) {
    final isOpen = _layoutState.isAdhaPanelOpen;

    return Tooltip(
      message: isOpen ? 'Fermer Adha IA' : 'Ouvrir Adha IA',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _layoutState.toggleAdhaPanel(),
          borderRadius: BorderRadius.circular(6),
          child: Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color:
                  isOpen
                      ? Theme.of(
                        context,
                      ).colorScheme.primary.withValues(alpha: 0.15)
                      : Colors.transparent,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Icon(
              Icons.chat_bubble_outline,
              size: 20,
              color:
                  isOpen
                      ? Theme.of(context).colorScheme.primary
                      : (isDark ? Colors.grey[400] : Colors.grey[600]),
            ),
          ),
        ),
      ),
    );
  }

  /// Vue split avec contenu principal + panneau Adha
  Widget _buildSplitView(BuildContext context, bool isDark) {
    return Row(
      children: [
        // Contenu principal
        Expanded(child: widget.child),

        // Divider redimensionnable VS Code style
        ResizableDivider(
          onDragUpdate: (delta) {
            // Delta négatif = agrandir le panneau (vers la gauche)
            final newWidth = _layoutState.adhaPanelWidth - delta;
            _layoutState.setAdhaPanelWidth(newWidth);
          },
        ),

        // Panneau Adha
        SizedBox(
          width: _layoutState.adhaPanelWidth,
          child: _buildAdhaPanelContent(context, isFullscreen: false),
        ),
      ],
    );
  }

  /// Contenu du panneau Adha avec header
  Widget _buildAdhaPanelContent(
    BuildContext context, {
    required bool isFullscreen,
  }) {
    return AdhaPanelContainer(
      isFullscreen: isFullscreen,
      onToggleFullscreen: () => _layoutState.toggleAdhaFullscreen(),
      onClose: () => _layoutState.closeAdhaPanel(),
      child: BlocProvider.value(
        value: context.read<AdhaBloc>(),
        child: const AdhaChatPanel(),
      ),
    );
  }

  /// Gère la navigation et le toggle du panneau Adha
  void _handleNavItemTapped(BuildContext context, int index) {
    if (index >= _desktopNavItems.length) return;

    final item = _desktopNavItems[index];

    // Si c'est l'item Adha, toggle le panneau au lieu de naviguer
    if (item.isAdhaPanel) {
      _layoutState.toggleAdhaPanel();
      return;
    }

    // Navigation normale
    final currentIndex = _getCurrentIndex(context);
    if (index == currentIndex) return;
    context.go(item.route);
  }

  Widget _buildTabletLayout(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final currentIndex = _getCurrentIndex(context);
    final title = _getTitle(context);

    // Si Adha est en fullscreen, montrer uniquement le panneau Adha
    if (_layoutState.isAdhaPanelFullscreen) {
      return Scaffold(
        body: _buildAdhaPanelContent(context, isFullscreen: true),
      );
    }

    return Scaffold(
      body: Column(
        children: [
          // Header en haut sur toute la largeur
          DesktopHeader(
            title: title,
            isSidebarExpanded: false,
            onToggleSidebar: null,
            actions: [_buildAdhaToggleButton(context, isDark)],
          ),

          // Contenu en dessous : Nav rail + Main content
          Expanded(
            child: Row(
              children: [
                // Navigation rail compact avec style amélioré
                Container(
                  width: 72,
                  decoration: BoxDecoration(
                    color:
                        isDark
                            ? theme.colorScheme.surface
                            : theme.colorScheme.primary,
                  ),
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    itemCount: _desktopNavItems.length,
                    itemBuilder: (context, index) {
                      final item = _desktopNavItems[index];
                      final isSelected = index == currentIndex;

                      return _buildTabletNavItem(
                        context,
                        item,
                        index,
                        isSelected,
                        isDark,
                      );
                    },
                  ),
                ),

                // Contenu principal
                Expanded(
                  child:
                      _layoutState.isAdhaPanelOpen
                          ? _buildSplitView(context, isDark)
                          : widget.child,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabletNavItem(
    BuildContext context,
    SidebarNavItem item,
    int index,
    bool isSelected,
    bool isDark,
  ) {
    final theme = Theme.of(context);
    final activeColor = isDark ? theme.colorScheme.primary : Colors.white;
    final inactiveColor =
        isDark
            ? theme.colorScheme.onSurfaceVariant
            : Colors.white.withValues(alpha: 0.7);

    return Tooltip(
      message: item.label,
      preferBelow: false,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          child: InkWell(
            onTap: () => _handleNavItemTapped(context, index),
            borderRadius: BorderRadius.circular(12),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color:
                    isSelected
                        ? (isDark
                            ? theme.colorScheme.primary.withValues(alpha: 0.2)
                            : Colors.white.withValues(alpha: 0.2))
                        : Colors.transparent,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    isSelected ? (item.activeIcon ?? item.icon) : item.icon,
                    color: isSelected ? activeColor : inactiveColor,
                    size: 24,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    item.label,
                    style: TextStyle(
                      color: isSelected ? activeColor : inactiveColor,
                      fontSize: 10,
                      fontWeight:
                          isSelected ? FontWeight.w600 : FontWeight.normal,
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMobileLayout(BuildContext context) {
    final title = _getTitle(context);
    final currentIndex = _getMobileCurrentIndex(context);

    return Scaffold(
      appBar: WanzoAppBar(title: title),
      body: widget.child,
      bottomNavigationBar:
          currentIndex >= 0 && currentIndex < _mobileNavItems.length
              ? WanzoBottomNavigationBar(
                currentIndex: currentIndex,
                items: _mobileNavItems,
                onTap: (index) {
                  if (index == currentIndex) return;
                  final items = _mobileNavItems;
                  if (index < 0 || index >= items.length) return;
                  context.go(items[index].route);
                },
              )
              : null,
    );
  }
}
