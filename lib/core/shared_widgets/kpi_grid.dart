import 'package:flutter/material.dart';

import 'kpi_board.dart';

/// Grille des six vignettes du tableau de bord, comme le mode Général de
/// l'app Gestion d'actifs.
///
/// Chaque vignette est complète : un titre, une icône, une valeur et une
/// sous-ligne (et le lien « Voir détails » quand elle mène quelque part).
/// Les vignettes vont par paires (CDF puis USD, par exemple) :
/// - téléphone en portrait : 2 colonnes, une paire par rangée ;
/// - téléphone en paysage, tablette, terminal POS, desktop étroit :
///   3 colonnes, une paire par colonne (rangée CDF au-dessus, USD dessous) ;
/// - desktop large : les 6 sur une seule rangée.
/// Toutes les vignettes ont la même taille, plafonnée : elles ne s'étirent
/// jamais en bandeau sur un grand écran.
class KpiGrid extends StatelessWidget {
  const KpiGrid({
    super.key,
    required this.tiles,
    this.spacing = 8,
    this.maxTileWidth = 300,
    this.detailsLabel = 'Voir détails',
  });

  final List<KpiTile> tiles;
  final double spacing;
  final double maxTileWidth;
  final String detailsLabel;

  /// Nombre de colonnes selon la largeur disponible et l'orientation.
  static int columnsFor(double width, Orientation orientation, int total) {
    int colonnes;
    if (width >= 960) {
      colonnes = 6;
    } else if (width >= 520 ||
        (orientation == Orientation.landscape && width >= 440)) {
      colonnes = 3;
    } else {
      colonnes = 2;
    }
    return colonnes.clamp(1, total < 1 ? 1 : total);
  }

  /// Hauteur d'une vignette : elle suit la taille de police du téléphone
  /// (seule la part texte grandit, pas l'icône).
  static double tileHeightFor(TextScaler scaler) {
    final echelle = scaler.scale(14) / 14;
    final surplus = (echelle - 1).clamp(0.0, 1.5);
    return 104 + 64 * surplus;
  }

  @override
  Widget build(BuildContext context) {
    if (tiles.isEmpty) return const SizedBox.shrink();
    final orientation = MediaQuery.orientationOf(context);
    final hauteur = tileHeightFor(MediaQuery.textScalerOf(context));

    return LayoutBuilder(
      builder: (context, constraints) {
        final largeur = constraints.maxWidth;
        final colonnes = columnsFor(largeur, orientation, tiles.length);
        // Arrondi vers le bas : la somme des vignettes ne dépasse jamais la
        // largeur, même d'une fraction de pixel.
        var largeurTuile =
            ((largeur - spacing * (colonnes - 1)) / colonnes).floorToDouble();
        if (largeurTuile > maxTileWidth) largeurTuile = maxTileWidth;

        final rangees = _rangees(colonnes);
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (var r = 0; r < rangees.length; r++) ...[
              if (r > 0) SizedBox(height: spacing),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (var c = 0; c < rangees[r].length; c++) ...[
                    if (c > 0) SizedBox(width: spacing),
                    SizedBox(
                      width: largeurTuile,
                      height: hauteur,
                      child: _KpiGridCard(
                        tile: rangees[r][c],
                        detailsLabel: detailsLabel,
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ],
        );
      },
    );
  }

  /// Répartit les vignettes en rangées. Quand il y a exactement deux rangées
  /// de vignettes appariées (6 vignettes sur 3 colonnes), chaque colonne porte
  /// une paire, pour que CDF et USD restent l'un contre l'autre.
  List<List<KpiTile>> _rangees(int colonnes) {
    if (colonnes * 2 == tiles.length && colonnes > 2) {
      return [
        [for (var c = 0; c < colonnes; c++) tiles[c * 2]],
        [for (var c = 0; c < colonnes; c++) tiles[c * 2 + 1]],
      ];
    }
    return [
      for (var i = 0; i < tiles.length; i += colonnes)
        tiles.sublist(
          i,
          i + colonnes > tiles.length ? tiles.length : i + colonnes,
        ),
    ];
  }
}

class _KpiGridCard extends StatelessWidget {
  const _KpiGridCard({required this.tile, required this.detailsLabel});

  final KpiTile tile;
  final String detailsLabel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final variation = tile.variation;

    final contenu = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  tile.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    fontSize: 11,
                  ),
                ),
              ),
              if (variation != null) ...[
                _Variation(valeur: variation),
                const SizedBox(width: 4),
              ],
              Icon(tile.icon, color: tile.color, size: 16),
            ],
          ),
          const SizedBox(height: 4),
          // Un grand montant rétrécit plutôt que de déborder.
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              tile.value,
              maxLines: 1,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                fontSize: 18,
                color: tile.color,
              ),
            ),
          ),
          if (tile.secondary != null)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                tile.secondary!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall?.copyWith(
                  fontSize: 10,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          const Spacer(),
          if (tile.onTap != null)
            Text(
              detailsLabel,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall?.copyWith(
                fontSize: 10,
                color: theme.colorScheme.primary,
              ),
            ),
        ],
      ),
    );

    return Card(
      margin: EdgeInsets.zero,
      elevation: 2,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
      child: tile.onTap == null
          ? contenu
          : InkWell(onTap: tile.onTap, child: contenu),
    );
  }
}

class _Variation extends StatelessWidget {
  const _Variation({required this.valeur});

  final double valeur;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hausse = valeur >= 0;
    final couleur = hausse ? const Color(0xFF16A34A) : theme.colorScheme.error;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(hausse ? Icons.arrow_upward : Icons.arrow_downward,
            size: 11, color: couleur),
        Text(
          '${valeur.abs().toStringAsFixed(0)}%',
          style: theme.textTheme.labelSmall?.copyWith(
            color: couleur,
            fontWeight: FontWeight.w700,
            fontSize: 10,
          ),
        ),
      ],
    );
  }
}
