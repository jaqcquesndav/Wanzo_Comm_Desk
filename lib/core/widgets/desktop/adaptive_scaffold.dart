import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../platform/platform_service.dart';
import 'desktop_header.dart';
import 'desktop_sidebar.dart';
import 'desktop_layout_state.dart';
import '../../../features/adha/widgets/adha_chat_panel.dart';
import '../../../features/adha/bloc/adha_bloc.dart';

/// Item de navigation pour le sidebar desktop
class SidebarNavItem {
  final IconData icon;
  final IconData? activeIcon;
  final String label;
  final String route;
  final List<SidebarNavItem>? children;
  final bool isDividerBefore;
  final bool isAdhaPanel; // Marque si cet item ouvre le panneau Adha

  const SidebarNavItem({
    required this.icon,
    this.activeIcon,
    required this.label,
    required this.route,
    this.children,
    this.isDividerBefore = false,
    this.isAdhaPanel = false,
  });

  /// Convertir en DesktopNavItem
  DesktopNavItem toDesktopNavItem() {
    return DesktopNavItem(
      icon: icon,
      activeIcon: activeIcon,
      label: label,
      route: route,
      isDividerBefore: isDividerBefore,
      isAdhaPanel: isAdhaPanel,
      children: children?.map((c) => c.toDesktopNavItem()).toList(),
    );
  }
}

/// Scaffold adaptatif qui utilise un sidebar sur desktop et une bottom nav sur mobile
/// Supporte un panneau Adha en style VS Code avec redimensionnement
class AdaptiveScaffold extends StatefulWidget {
  final int currentIndex;
  final String title;
  final Widget body;
  final Widget? floatingActionButton;
  final List<Widget>? appBarActions;
  final VoidCallback? onBackPressed;
  final List<SidebarNavItem> navigationItems;

  const AdaptiveScaffold({
    super.key,
    required this.currentIndex,
    required this.title,
    required this.body,
    required this.navigationItems,
    this.floatingActionButton,
    this.appBarActions,
    this.onBackPressed,
  });

  @override
  State<AdaptiveScaffold> createState() => _AdaptiveScaffoldState();
}

class _AdaptiveScaffoldState extends State<AdaptiveScaffold> {
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

    // Convertir les items de navigation
    final desktopNavItems =
        widget.navigationItems.map((item) => item.toDesktopNavItem()).toList();

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
            title: widget.title,
            isSidebarExpanded: effectiveSidebarExpanded,
            onToggleSidebar: () => _layoutState.toggleSidebar(),
            actions: [
              // Bouton pour ouvrir/fermer Adha
              _buildAdhaToggleButton(context, isDark),
              if (widget.appBarActions != null) ...widget.appBarActions!,
            ],
            onBackPressed: widget.onBackPressed,
          ),

          // Contenu en dessous : Sidebar + Main content
          Expanded(
            child: Row(
              children: [
                // Sidebar (sans header - le header est au-dessus)
                DesktopSidebar(
                  currentIndex: widget.currentIndex,
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
                          : widget.body,
                ),
              ],
            ),
          ),
        ],
      ),
      // Cacher le FAB quand le panneau Adha est ouvert pour ne pas bloquer les inputs
      floatingActionButton:
          _layoutState.isAdhaPanelOpen ? null : widget.floatingActionButton,
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
        Expanded(child: widget.body),

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
    if (index >= widget.navigationItems.length) return;

    final item = widget.navigationItems[index];

    // Si c'est l'item Adha, toggle le panneau au lieu de naviguer
    if (item.isAdhaPanel) {
      _layoutState.toggleAdhaPanel();
      return;
    }

    // Navigation normale
    if (index == widget.currentIndex) return;
    context.go(item.route);
  }

  Widget _buildTabletLayout(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

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
            title: widget.title,
            isSidebarExpanded: false, // Tablet = toujours compact
            onToggleSidebar: null, // Pas de toggle en mode tablette
            actions: [
              _buildAdhaToggleButton(context, isDark),
              if (widget.appBarActions != null) ...widget.appBarActions!,
            ],
            onBackPressed: widget.onBackPressed,
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
                    itemCount: widget.navigationItems.length,
                    itemBuilder: (context, index) {
                      final item = widget.navigationItems[index];
                      final isSelected = index == widget.currentIndex;

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
                          : widget.body,
                ),
              ],
            ),
          ),
        ],
      ),
      // Cacher le FAB quand le panneau Adha est ouvert pour ne pas bloquer les inputs
      floatingActionButton:
          _layoutState.isAdhaPanelOpen ? null : widget.floatingActionButton,
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
            onTap: () => _onNavItemTapped(context, index),
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
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        actions: widget.appBarActions,
        leading:
            widget.onBackPressed != null
                ? IconButton(
                  icon: const Icon(Icons.arrow_back),
                  onPressed: widget.onBackPressed,
                )
                : null,
      ),
      body: widget.body,
      bottomNavigationBar: NavigationBar(
        selectedIndex: widget.currentIndex,
        onDestinationSelected: (index) => _onNavItemTapped(context, index),
        destinations:
            widget.navigationItems.map((item) {
              return NavigationDestination(
                icon: Icon(item.icon),
                selectedIcon: Icon(item.activeIcon ?? item.icon),
                label: item.label,
              );
            }).toList(),
      ),
      // Cacher le FAB quand le panneau Adha est ouvert pour ne pas bloquer les inputs
      floatingActionButton:
          _layoutState.isAdhaPanelOpen ? null : widget.floatingActionButton,
    );
  }

  void _onNavItemTapped(BuildContext context, int index) {
    if (index == widget.currentIndex) return;

    final route = widget.navigationItems[index].route;
    context.go(route);
  }
}
