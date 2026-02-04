import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../constants/colors.dart';

/// Item de navigation pour le sidebar desktop
class DesktopNavItem {
  final IconData icon;
  final IconData? activeIcon;
  final String label;
  final String route;
  final List<DesktopNavItem>? children;
  final bool isDividerBefore;
  final bool isAdhaPanel; // Si cet item ouvre le panneau Adha

  const DesktopNavItem({
    required this.icon,
    this.activeIcon,
    required this.label,
    required this.route,
    this.children,
    this.isDividerBefore = false,
    this.isAdhaPanel = false,
  });
}

/// Sidebar élégant pour desktop avec fond bleu primaire
class DesktopSidebar extends StatefulWidget {
  /// Index de navigation actuel
  final int currentIndex;

  /// Liste des items de navigation
  final List<DesktopNavItem> items;

  /// Callback quand un item est sélectionné
  final Function(int index)? onItemSelected;

  /// Si le sidebar est étendu ou réduit
  final bool isExpanded;

  /// Callback pour toggler l'expansion
  final VoidCallback? onToggleExpand;

  const DesktopSidebar({
    super.key,
    required this.currentIndex,
    required this.items,
    this.onItemSelected,
    this.isExpanded = true,
    this.onToggleExpand,
  });

  @override
  State<DesktopSidebar> createState() => _DesktopSidebarState();
}

class _DesktopSidebarState extends State<DesktopSidebar>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _widthAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    _widthAnimation = Tween<double>(begin: 72, end: 260).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );

    if (widget.isExpanded) {
      _animationController.value = 1.0;
    }
  }

  @override
  void didUpdateWidget(DesktopSidebar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isExpanded != oldWidget.isExpanded) {
      if (widget.isExpanded) {
        _animationController.forward();
      } else {
        _animationController.reverse();
      }
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    // Couleurs adaptatives pour light/dark mode
    final backgroundColor =
        isDark ? WanzoColors.backgroundSecondaryDark : WanzoColors.primary;
    final textColor = isDark ? WanzoColors.textPrimaryDark : Colors.white;
    final activeItemBg =
        isDark
            ? WanzoColors.primary.withValues(alpha: 0.3)
            : Colors.white.withValues(alpha: 0.2);
    final hoverColor =
        isDark
            ? WanzoColors.primary.withValues(alpha: 0.15)
            : Colors.white.withValues(alpha: 0.1);

    return AnimatedBuilder(
      animation: _widthAnimation,
      builder: (context, child) {
        final isExpanded = _widthAnimation.value > 150;

        return Container(
          width: _widthAnimation.value,
          decoration: BoxDecoration(
            color: backgroundColor,
            // Pas de shadow - le header est au-dessus
          ),
          child: Column(
            children: [
              // Navigation items (plus de header - il est dans le header principal)
              Expanded(
                child: _buildNavItems(
                  context,
                  isExpanded,
                  textColor,
                  activeItemBg,
                  hoverColor,
                  isDark,
                ),
              ),

              // Footer
              _buildFooter(context, isExpanded, textColor, isDark),
            ],
          ),
        );
      },
    );
  }

  Widget _buildNavItems(
    BuildContext context,
    bool isExpanded,
    Color textColor,
    Color activeItemBg,
    Color hoverColor,
    bool isDark,
  ) {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
      itemCount: widget.items.length,
      itemBuilder: (context, index) {
        final item = widget.items[index];
        final isSelected = index == widget.currentIndex;

        // Divider avant l'item si demandé
        if (item.isDividerBefore) {
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Divider(
                  color: textColor.withValues(alpha: 0.2),
                  thickness: 1,
                  indent: isExpanded ? 16 : 8,
                  endIndent: isExpanded ? 16 : 8,
                ),
              ),
              _buildNavItem(
                context,
                item,
                index,
                isSelected,
                isExpanded,
                textColor,
                activeItemBg,
                hoverColor,
                isDark,
              ),
            ],
          );
        }

        return _buildNavItem(
          context,
          item,
          index,
          isSelected,
          isExpanded,
          textColor,
          activeItemBg,
          hoverColor,
          isDark,
        );
      },
    );
  }

  Widget _buildNavItem(
    BuildContext context,
    DesktopNavItem item,
    int index,
    bool isSelected,
    bool isExpanded,
    Color textColor,
    Color activeItemBg,
    Color hoverColor,
    bool isDark,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: () {
            if (widget.onItemSelected != null) {
              widget.onItemSelected!(index);
            } else {
              context.go(item.route);
            }
          },
          borderRadius: BorderRadius.circular(12),
          hoverColor: hoverColor,
          splashColor: activeItemBg,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: EdgeInsets.symmetric(
              horizontal: isExpanded ? 16 : 12,
              vertical: 12,
            ),
            decoration: BoxDecoration(
              color: isSelected ? activeItemBg : Colors.transparent,
              borderRadius: BorderRadius.circular(12),
              border:
                  isSelected
                      ? Border.all(
                        color:
                            isDark
                                ? WanzoColors.primary
                                : Colors.white.withValues(alpha: 0.3),
                        width: 1,
                      )
                      : null,
            ),
            child: Row(
              mainAxisAlignment:
                  isExpanded
                      ? MainAxisAlignment.start
                      : MainAxisAlignment.center,
              children: [
                // Icône
                Icon(
                  isSelected ? (item.activeIcon ?? item.icon) : item.icon,
                  color:
                      isSelected
                          ? (isDark ? WanzoColors.primary : Colors.white)
                          : textColor.withValues(alpha: 0.7),
                  size: 22,
                ),

                // Label (uniquement si étendu)
                if (isExpanded) ...[
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(
                      item.label,
                      style: TextStyle(
                        color:
                            isSelected
                                ? (isDark ? WanzoColors.primary : Colors.white)
                                : textColor.withValues(alpha: 0.85),
                        fontWeight:
                            isSelected ? FontWeight.w600 : FontWeight.w500,
                        fontSize: 14,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],

                // Indicateur de sélection
                if (isExpanded && isSelected)
                  Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: isDark ? WanzoColors.primary : Colors.white,
                      shape: BoxShape.circle,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFooter(
    BuildContext context,
    bool isExpanded,
    Color textColor,
    bool isDark,
  ) {
    return Container(
      padding: EdgeInsets.all(isExpanded ? 16 : 8),
      child: Column(
        children: [
          Divider(color: textColor.withValues(alpha: 0.2), thickness: 1),
          const SizedBox(height: 8),
          if (isExpanded)
            Text(
              'Wanzo Desktop v1.0.0',
              style: TextStyle(
                color: textColor.withValues(alpha: 0.5),
                fontSize: 11,
              ),
            )
          else
            Tooltip(
              message: 'Wanzo Desktop v1.0.0',
              child: Icon(
                Icons.info_outline,
                color: textColor.withValues(alpha: 0.5),
                size: 16,
              ),
            ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}
