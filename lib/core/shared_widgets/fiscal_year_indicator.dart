import 'package:flutter/material.dart';

import '../../constants/colors.dart';

/// Indicateur discret de l'exercice fiscal en cours.
///
/// Les applications de gestion commerciale sont synchronisées sur l'exercice
/// fiscal courant : toutes les données entrantes (ventes, stock, dépenses…)
/// y sont rattachées. L'historique des exercices passés reste consultable
/// (paginé) dans les écrans dédiés.
///
/// L'exercice fiscal OHADA/SYSCOHADA correspond à l'année civile
/// (1er janvier – 31 décembre).
class FiscalYearIndicator extends StatelessWidget {
  const FiscalYearIndicator({super.key, this.compact = false});

  /// Rendu compact (icône + année) pour les emplacements étroits (sidebar).
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final year = DateTime.now().year;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final fg = isDark ? WanzoColors.infoLight : WanzoColors.infoDark;
    final bg = (isDark ? WanzoColors.infoDark : WanzoColors.infoLight)
        .withValues(alpha: isDark ? 0.18 : 0.12);

    return Tooltip(
      message:
          'Les données saisies sont rattachées à l\'exercice $year. '
          'L\'historique des exercices précédents reste consultable.',
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: compact ? 10 : 12,
          vertical: compact ? 6 : 8,
        ),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: fg.withValues(alpha: 0.25)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.event_available_outlined, size: compact ? 14 : 16, color: fg),
            const SizedBox(width: 6),
            Text(
              compact ? 'Exercice $year' : 'Exercice fiscal en cours · $year',
              style: TextStyle(
                color: fg,
                fontSize: compact ? 11.5 : 12.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
