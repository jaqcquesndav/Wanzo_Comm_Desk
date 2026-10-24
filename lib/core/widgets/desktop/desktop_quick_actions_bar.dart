import 'package:flutter/material.dart';

import '../../modules/activity_mode.dart';
import '../../quick_actions/desktop_quick_actions.dart';

/// Barre d'actions rapides du shell desktop (sous l'en-tête, au-dessus du
/// contenu), présente sur tous les écrans principaux.
///
/// Compacte : icône et libellé, action principale en bouton plein ; ce qui ne
/// tient pas dans la largeur passe dans le menu « Plus ».
class DesktopQuickActionsBar extends StatelessWidget {
  final ResolvedQuickActions resolved;

  const DesktopQuickActionsBar({super.key, required this.resolved});

  static const double height = 52;
  static const double _gap = 8;

  /// Barre de l'écran [path], ou `null` si ce n'est pas un écran principal ou
  /// si aucune action ne s'y applique.
  static Widget? forRoute({
    required ActivityMode mode,
    required String? role,
    required String path,
  }) {
    if (!DesktopQuickActionsCatalog.isMainRoute(path, mode, role)) return null;
    final resolved = DesktopQuickActionsCatalog.resolve(
      mode: mode,
      role: role,
      path: path,
    );
    if (resolved.actions.isEmpty) return null;
    return DesktopQuickActionsBar(resolved: resolved);
  }

  /// Largeur d'un bouton : icône (18), espace (8), libellé et marges
  /// internes (32).
  static double _buttonWidth(BuildContext context, String label) =>
      _textWidth(context, label) + 18 + 8 + 32;

  /// Largeur du bouton « Plus » : icône, espace, libellé, marges.
  static double _moreWidth(BuildContext context) =>
      _textWidth(context, 'Plus') + 18 + 6 + 24 + 8;

  static double _textWidth(BuildContext context, String label) {
    final style = Theme.of(context).textTheme.labelLarge;
    final painter = TextPainter(
      text: TextSpan(text: label, style: style),
      maxLines: 1,
      textDirection: TextDirection.ltr,
      textScaler: MediaQuery.textScalerOf(context),
    )..layout();
    return painter.width;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Semantics(
      container: true,
      label: 'Actions rapides',
      child: Container(
        key: const ValueKey('desktop-quick-actions-bar'),
        height: height,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          border: Border(
            bottom: BorderSide(color: theme.colorScheme.outlineVariant),
          ),
        ),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final actions = resolved.actions;
            final widths = [
              for (final a in actions) _buttonWidth(context, a.label),
            ];
            final total = widths.fold<double>(0, (s, w) => s + w + _gap);
            var visibleCount = actions.length;
            if (total > constraints.maxWidth) {
              // Place pour le bouton « Plus », puis autant d'actions que
              // possible ; l'action principale reste toujours visible.
              var used = _moreWidth(context);
              visibleCount = 0;
              for (final w in widths) {
                if (used + w + _gap > constraints.maxWidth) break;
                used += w + _gap;
                visibleCount++;
              }
              if (visibleCount == 0) visibleCount = 1;
            }
            final visible = actions.take(visibleCount).toList();
            final overflow = actions.skip(visibleCount).toList();
            return ClipRect(
              child: Row(
                children: [
                  for (final a in visible) ...[
                    Flexible(
                      child: _QuickActionButton(
                        action: a,
                        primary: a.id == resolved.primaryId,
                      ),
                    ),
                    const SizedBox(width: _gap),
                  ],
                  if (overflow.isNotEmpty) _MoreMenu(actions: overflow),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _QuickActionButton extends StatelessWidget {
  final DesktopQuickAction action;
  final bool primary;
  const _QuickActionButton({required this.action, required this.primary});

  @override
  Widget build(BuildContext context) {
    final key = ValueKey('quick-action-${action.id}');
    final scheme = Theme.of(context).colorScheme;
    final label = Text(
      action.label,
      maxLines: 1,
      softWrap: false,
      overflow: TextOverflow.ellipsis,
    );
    // Action mise en avant : icône et libellé en couleur primaire, sans fond
    // coloré derrière (même règle que l'élément actif de la navigation).
    return TextButton.icon(
      key: key,
      onPressed: () => action.run(context),
      style: TextButton.styleFrom(
        foregroundColor: primary ? scheme.primary : scheme.onSurface,
        textStyle: primary
            ? const TextStyle(fontWeight: FontWeight.w700)
            : null,
      ),
      icon: Icon(
        action.icon,
        size: 18,
        color: primary ? scheme.primary : action.color,
      ),
      label: label,
    );
  }
}

class _MoreMenu extends StatelessWidget {
  final List<DesktopQuickAction> actions;
  const _MoreMenu({required this.actions});

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<DesktopQuickAction>(
      key: const ValueKey('quick-actions-more'),
      tooltip: 'Autres actions',
      position: PopupMenuPosition.under,
      onSelected: (a) => a.run(context),
      itemBuilder: (_) => [
        for (final a in actions)
          PopupMenuItem<DesktopQuickAction>(
            key: ValueKey('quick-action-menu-${a.id}'),
            value: a,
            child: Row(
              children: [
                Icon(a.icon, size: 18, color: a.color),
                const SizedBox(width: 12),
                Flexible(
                  child: Text(a.label, overflow: TextOverflow.ellipsis),
                ),
              ],
            ),
          ),
      ],
      child: const Padding(
        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.more_horiz, size: 18),
            SizedBox(width: 6),
            Text('Plus'),
          ],
        ),
      ),
    );
  }
}
