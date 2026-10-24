import 'package:flutter/material.dart';

import '../../../constants/spacing.dart';
import '../../quick_actions/desktop_quick_actions.dart';

/// Widget dock style macOS pour les opérations rapides.
/// Toujours visible en bas de l'écran avec possibilité de réduire/agrandir.
///
/// Porté une seule fois par le shell desktop ([OperationsDockHost]) sur les
/// écrans principaux ; ses actions viennent du catalogue du mode
/// ([DesktopQuickActionsCatalog]).
class OperationsDock extends StatefulWidget {
  /// Actions du mode pour l'écran courant (déjà filtrées par le catalogue).
  final List<DesktopQuickAction> actions;

  const OperationsDock({super.key, required this.actions});

  /// Déplié ou replié : partagé entre les écrans (le choix de l'utilisateur
  /// suit la navigation).
  static final ValueNotifier<bool> expanded = ValueNotifier<bool>(true);

  /// Largeur d'une action du dock (marges, padding et pastille de 42).
  static const double itemExtent = 66;

  /// Largeur fixe en tête du dock : bouton de réduction et séparateur.
  static const double leadingExtent = 77;

  @override
  State<OperationsDock> createState() => _OperationsDockState();
}

class _OperationsDockState extends State<OperationsDock>
    with SingleTickerProviderStateMixin {
  bool get _isExpanded => OperationsDock.expanded.value;
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 250),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOutBack),
    );
    if (_isExpanded) {
      _animationController.value = 1.0;
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _toggleExpanded() {
    setState(() {
      OperationsDock.expanded.value = !_isExpanded;
    });
    if (_isExpanded) {
      _animationController.forward();
    } else {
      _animationController.reverse();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.only(bottom: WanzoSpacing.md),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Dock principal
          AnimatedContainer(
            key: const ValueKey('operations-dock'),
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeInOut,
            child: Container(
              decoration: BoxDecoration(
                color:
                    isDark
                        ? Colors.grey[900]?.withValues(alpha: 0.95)
                        : Colors.white.withValues(alpha: 0.95),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.15),
                    blurRadius: 20,
                    offset: const Offset(0, 5),
                    spreadRadius: 2,
                  ),
                  BoxShadow(
                    color: theme.colorScheme.primary.withValues(alpha: 0.1),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ],
                border: Border.all(
                  color:
                      isDark
                          ? Colors.white.withValues(alpha: 0.1)
                          : Colors.grey.withValues(alpha: 0.2),
                  width: 0.5,
                ),
              ),
              child: AnimatedCrossFade(
                duration: const Duration(milliseconds: 200),
                crossFadeState:
                    _isExpanded
                        ? CrossFadeState.showFirst
                        : CrossFadeState.showSecond,
                firstChild: _buildExpandedDock(context, theme),
                secondChild: _buildCollapsedDock(context, theme),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExpandedDock(BuildContext context, ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: WanzoSpacing.md,
        vertical:
            WanzoSpacing.md, // Plus d'espace vertical pour l'animation de hover
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          // Fenêtre étroite : ce qui ne tient pas passe dans « Plus ».
          final actions = widget.actions;
          var visible = actions;
          var overflow = const <DesktopQuickAction>[];
          final needed =
              OperationsDock.leadingExtent +
              OperationsDock.itemExtent * actions.length;
          if (constraints.hasBoundedWidth && needed > constraints.maxWidth) {
            final room =
                constraints.maxWidth -
                OperationsDock.leadingExtent -
                OperationsDock.itemExtent; // place du bouton « Plus »
            final fit = (room / OperationsDock.itemExtent).floor().clamp(
              0,
              actions.length,
            );
            visible = actions.take(fit).toList();
            overflow = actions.skip(fit).toList();
          }
          return SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Bouton de réduction
                _buildDockItem(
                  context: context,
                  key: const ValueKey('operations-dock-collapse'),
                  icon: Icons.keyboard_arrow_down,
                  label: '',
                  onTap: _toggleExpanded,
                  color: theme.colorScheme.outline,
                  isCollapseButton: true,
                ),
                const SizedBox(width: WanzoSpacing.xs),
                Container(
                  width: 1,
                  height: 40,
                  color: theme.colorScheme.outline.withValues(alpha: 0.3),
                ),
                const SizedBox(width: WanzoSpacing.sm),
                // Actions rapides du mode
                for (final a in visible)
                  _buildDockItem(
                    context: context,
                    key: ValueKey('dock-action-${a.id}'),
                    icon: a.icon,
                    label: a.label,
                    onTap: () => a.run(context),
                    color: a.color,
                  ),
                if (overflow.isNotEmpty)
                  Builder(
                    builder:
                        (itemContext) => _buildDockItem(
                          context: itemContext,
                          key: const ValueKey('operations-dock-more'),
                          icon: Icons.more_horiz,
                          label: 'Plus',
                          onTap: () => _showMore(itemContext, overflow),
                          color: Colors.blueGrey,
                        ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  Future<void> _showMore(
    BuildContext itemContext,
    List<DesktopQuickAction> overflow,
  ) async {
    final box = itemContext.findRenderObject() as RenderBox?;
    final overlay =
        Overlay.of(itemContext).context.findRenderObject() as RenderBox?;
    if (box == null || overlay == null) return;
    final topLeft = box.localToGlobal(Offset.zero, ancestor: overlay);
    final position = RelativeRect.fromRect(
      topLeft & box.size,
      Offset.zero & overlay.size,
    );
    final picked = await showMenu<DesktopQuickAction>(
      context: itemContext,
      position: position,
      items: [
        for (final a in overflow)
          PopupMenuItem<DesktopQuickAction>(
            key: ValueKey('dock-menu-${a.id}'),
            value: a,
            child: Row(
              children: [
                Icon(a.icon, size: 18, color: a.color),
                const SizedBox(width: 12),
                Flexible(child: Text(a.label, overflow: TextOverflow.ellipsis)),
              ],
            ),
          ),
      ],
    );
    if (picked != null && mounted) picked.run(context);
  }

  Widget _buildCollapsedDock(BuildContext context, ThemeData theme) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        key: const ValueKey('operations-dock-expand'),
        onTap: _toggleExpanded,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: WanzoSpacing.lg,
            vertical: WanzoSpacing.sm,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.add_circle,
                color: theme.colorScheme.primary,
                size: 24,
              ),
              const SizedBox(width: WanzoSpacing.xs),
              Icon(
                Icons.keyboard_arrow_up,
                color: theme.colorScheme.outline,
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDockItem({
    required BuildContext context,
    required Key key,
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    required Color color,
    bool isCollapseButton = false,
  }) {
    return Tooltip(
      key: key,
      message: label.isEmpty ? 'Réduire' : label,
      waitDuration: const Duration(milliseconds: 500),
      child: AnimatedBuilder(
        animation: _scaleAnimation,
        builder: (context, child) {
          return Transform.scale(
            scale: isCollapseButton ? 1.0 : _scaleAnimation.value,
            child: child,
          );
        },
        child: _DockItemWidget(
          icon: icon,
          label: label,
          onTap: onTap,
          color: color,
          isCollapseButton: isCollapseButton,
        ),
      ),
    );
  }
}

class _DockItemWidget extends StatefulWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color color;
  final bool isCollapseButton;

  const _DockItemWidget({
    required this.icon,
    required this.label,
    required this.onTap,
    required this.color,
    this.isCollapseButton = false,
  });

  @override
  State<_DockItemWidget> createState() => _DockItemWidgetState();
}

class _DockItemWidgetState extends State<_DockItemWidget>
    with SingleTickerProviderStateMixin {
  bool _isHovered = false;
  late AnimationController _hoverController;
  late Animation<double> _hoverAnimation;

  @override
  void initState() {
    super.initState();
    _hoverController = AnimationController(
      duration: const Duration(milliseconds: 150),
      vsync: this,
    );
    _hoverAnimation = Tween<double>(begin: 1.0, end: 1.2).animate(
      CurvedAnimation(parent: _hoverController, curve: Curves.easeOutBack),
    );
  }

  @override
  void dispose() {
    _hoverController.dispose();
    super.dispose();
  }

  void _onHoverChanged(bool isHovered) {
    setState(() {
      _isHovered = isHovered;
    });
    if (isHovered) {
      _hoverController.forward();
    } else {
      _hoverController.reverse();
    }
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => _onHoverChanged(true),
      onExit: (_) => _onHoverChanged(false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedBuilder(
          animation: _hoverAnimation,
          builder: (context, child) {
            return Transform.scale(scale: _hoverAnimation.value, child: child);
          },
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: WanzoSpacing.xs),
            padding: const EdgeInsets.all(WanzoSpacing.sm),
            decoration: BoxDecoration(
              color:
                  _isHovered
                      ? widget.color.withValues(alpha: 0.15)
                      : Colors.transparent,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    gradient:
                        widget.isCollapseButton
                            ? null
                            : LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                widget.color.withValues(alpha: 0.8),
                                widget.color,
                              ],
                            ),
                    color:
                        widget.isCollapseButton
                            ? Theme.of(
                              context,
                            ).colorScheme.surfaceContainerHighest
                            : null,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow:
                        widget.isCollapseButton
                            ? null
                            : [
                              BoxShadow(
                                color: widget.color.withValues(alpha: 0.4),
                                blurRadius: _isHovered ? 12 : 6,
                                offset: const Offset(0, 3),
                              ),
                            ],
                  ),
                  child: Icon(
                    widget.icon,
                    color:
                        widget.isCollapseButton
                            ? Theme.of(context).colorScheme.outline
                            : Colors.white,
                    size: widget.isCollapseButton ? 20 : 22,
                  ),
                ),
                // Point indicateur style macOS
                if (!widget.isCollapseButton) ...[
                  const SizedBox(height: 4),
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    width: _isHovered ? 6 : 4,
                    height: _isHovered ? 6 : 4,
                    decoration: BoxDecoration(
                      color:
                          _isHovered
                              ? widget.color
                              : widget.color.withValues(alpha: 0.5),
                      shape: BoxShape.circle,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Porte le dock sous le contenu d'un écran principal du shell desktop.
///
/// Le contenu s'arrête au-dessus de la zone du dock (padding bas égal à sa
/// hauteur, déplié ou replié) : la dernière ligne d'une liste n'est jamais
/// masquée. Avec un bouton flottant à droite, le dock s'écarte de lui.
class OperationsDockHost extends StatelessWidget {
  final Widget child;
  final List<DesktopQuickAction> actions;
  final bool hasFloatingActionButton;

  const OperationsDockHost({
    super.key,
    required this.child,
    required this.actions,
    this.hasFloatingActionButton = false,
  });

  /// Hauteur réservée sous le contenu, dock déplié (dock et marge basse).
  static const double reserveExpanded = 112;

  /// Hauteur réservée sous le contenu, dock replié.
  static const double reserveCollapsed = 60;

  /// Écart latéral laissé au bouton flottant (56 + marges).
  static const double fabClearance = 88;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: OperationsDock.expanded,
      builder: (context, expanded, _) {
        final reserve = expanded ? reserveExpanded : reserveCollapsed;
        final side = hasFloatingActionButton ? fabClearance : 0.0;
        return Stack(
          children: [
            Positioned.fill(
              child: Padding(
                padding: EdgeInsets.only(bottom: reserve),
                child: KeyedSubtree(
                  key: const ValueKey('operations-dock-content'),
                  child: child,
                ),
              ),
            ),
            Positioned(
              left: side,
              right: side,
              bottom: 0,
              child: Center(child: OperationsDock(actions: actions)),
            ),
          ],
        );
      },
    );
  }
}
