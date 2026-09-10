import 'package:flutter/material.dart';

/// Une action de la barre d'actions d'une page de détail.
class ActionBarItem {
  final IconData icon;
  final String label;
  final VoidCallback? onPressed;
  final Color? background;
  final Color? foreground;

  /// `true` pour un bouton secondaire (contour) au lieu d'un bouton plein.
  final bool outlined;

  const ActionBarItem({
    required this.icon,
    required this.label,
    this.onPressed,
    this.background,
    this.foreground,
    this.outlined = false,
  });
}

/// Barre d'actions qui ne débordera jamais.
///
/// Remplace les `Row` + `Expanded` de `ElevatedButton.icon` des pages de
/// détail : sur un écran de 360 dp, trois boutons libellés réclament environ
/// 120 dp chacun pour 104 dp disponibles, ce qui provoquait un RenderFlex
/// overflow et des libellés tronqués.
///
/// - Sous [compactBreakpoint] (360 dp par défaut de largeur disponible), on
///   n'affiche que les icônes (avec infobulle) : lisible et tactile.
/// - Au-dessus, on utilise un `Wrap` dont chaque bouton reçoit une largeur
///   calculée, jamais inférieure à [minButtonWidth] : les boutons passent
///   naturellement à la ligne au lieu de déborder, et les libellés sont
///   contraints en une ligne avec ellipse.
class ResponsiveActionBar extends StatelessWidget {
  final List<ActionBarItem> items;
  final double compactBreakpoint;
  final double minButtonWidth;
  final double spacing;

  const ResponsiveActionBar({
    super.key,
    required this.items,
    this.compactBreakpoint = 360,
    this.minButtonWidth = 148,
    this.spacing = 8,
  });

  @override
  Widget build(BuildContext context) {
    final visible = items.where((item) => item.onPressed != null).toList();
    final rendered = visible.isEmpty ? items : visible;
    if (rendered.isEmpty) return const SizedBox.shrink();

    return LayoutBuilder(
      builder: (context, constraints) {
        final available =
            constraints.maxWidth.isFinite
                ? constraints.maxWidth
                : MediaQuery.of(context).size.width;

        if (available < compactBreakpoint) {
          return Wrap(
            alignment: WrapAlignment.spaceEvenly,
            spacing: spacing,
            runSpacing: spacing,
            children: [
              for (final item in rendered) _buildIconOnly(context, item),
            ],
          );
        }

        final count = rendered.length;
        final evenWidth = (available - spacing * (count - 1)) / count;
        final width = evenWidth < minButtonWidth ? minButtonWidth : evenWidth;

        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: [
            for (final item in rendered)
              SizedBox(width: width, child: _buildLabelled(context, item)),
          ],
        );
      },
    );
  }

  Widget _buildIconOnly(BuildContext context, ActionBarItem item) {
    final theme = Theme.of(context);
    final background = item.background ?? theme.colorScheme.primary;
    if (item.outlined) {
      return IconButton(
        onPressed: item.onPressed,
        tooltip: item.label,
        icon: Icon(item.icon),
        style: IconButton.styleFrom(
          foregroundColor: item.foreground ?? background,
          side: BorderSide(color: background),
        ),
      );
    }
    return IconButton(
      onPressed: item.onPressed,
      tooltip: item.label,
      icon: Icon(item.icon),
      style: IconButton.styleFrom(
        backgroundColor: background,
        foregroundColor: item.foreground ?? Colors.white,
        disabledBackgroundColor: theme.disabledColor.withAlpha(40),
      ),
    );
  }

  Widget _buildLabelled(BuildContext context, ActionBarItem item) {
    final label = Text(
      item.label,
      maxLines: 1,
      softWrap: false,
      overflow: TextOverflow.ellipsis,
      textAlign: TextAlign.center,
    );

    if (item.outlined) {
      return OutlinedButton.icon(
        onPressed: item.onPressed,
        icon: Icon(item.icon, size: 18),
        label: label,
        style: OutlinedButton.styleFrom(
          foregroundColor: item.foreground ?? item.background,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
        ),
      );
    }

    return ElevatedButton.icon(
      onPressed: item.onPressed,
      icon: Icon(item.icon, size: 18),
      label: label,
      style: ElevatedButton.styleFrom(
        backgroundColor: item.background,
        foregroundColor: item.foreground ?? Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
      ),
    );
  }
}
