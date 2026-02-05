import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:wanzo/constants/spacing.dart';
import 'package:wanzo/l10n/app_localizations.dart';
import 'package:wanzo/core/services/form_navigation_service.dart';

/// Widget dock style macOS pour les opérations rapides.
/// Toujours visible en bas de l'écran avec possibilité de réduire/agrandir.
class OperationsDock extends StatefulWidget {
  const OperationsDock({super.key});

  @override
  State<OperationsDock> createState() => _OperationsDockState();
}

class _OperationsDockState extends State<OperationsDock>
    with SingleTickerProviderStateMixin {
  bool _isExpanded = true;
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
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _toggleExpanded() {
    setState(() {
      _isExpanded = !_isExpanded;
    });
    if (_isExpanded) {
      _animationController.forward();
    } else {
      _animationController.reverse();
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.only(bottom: WanzoSpacing.md),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Dock principal
          AnimatedContainer(
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
                firstChild: _buildExpandedDock(context, l10n, theme),
                secondChild: _buildCollapsedDock(context, theme),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExpandedDock(
    BuildContext context,
    AppLocalizations l10n,
    ThemeData theme,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: WanzoSpacing.md,
        vertical:
            WanzoSpacing.md, // Plus d'espace vertical pour l'animation de hover
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Bouton de réduction
            _buildDockItem(
              context: context,
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
            // Actions rapides
            _buildDockItem(
              context: context,
              icon: Icons.add_shopping_cart,
              label: l10n.dashboardQuickActionsNewInvoice,
              onTap: () => context.push('/sales/add'),
              color: Colors.green,
            ),
            _buildDockItem(
              context: context,
              icon: Icons.inventory_2,
              label: l10n.addProductTitle,
              onTap: () => context.push('/inventory/add'),
              color: Colors.orange,
            ),
            _buildDockItem(
              context: context,
              icon: Icons.monetization_on,
              label: l10n.dashboardQuickActionsNewFinancing,
              onTap: () => context.push('/financing/add'),
              color: Colors.teal,
            ),
            _buildDockItem(
              context: context,
              icon: Icons.receipt_long,
              label: l10n.dashboardQuickActionsNewExpense,
              onTap: () => context.push('/expenses/add'),
              color: Colors.redAccent,
            ),
            _buildDockItem(
              context: context,
              icon: Icons.person_add_alt_1,
              label: l10n.dashboardQuickActionsNewClient,
              onTap:
                  () =>
                      FormNavigationService.instance.openCustomerForm(context),
              color: Colors.blueAccent,
            ),
            _buildDockItem(
              context: context,
              icon: Icons.store,
              label: l10n.dashboardQuickActionsNewSupplier,
              onTap:
                  () =>
                      FormNavigationService.instance.openSupplierForm(context),
              color: Colors.purpleAccent,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCollapsedDock(BuildContext context, ThemeData theme) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
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
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    required Color color,
    bool isCollapseButton = false,
  }) {
    return Tooltip(
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
