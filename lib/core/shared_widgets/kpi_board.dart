import 'dart:ui' as ui;

import 'package:flutter/material.dart';

/// Poids d'un indicateur dans la lecture de l'écran.
///
/// Un tableau de bord où tout a la même taille ne dit rien : l'œil doit tomber
/// d'abord sur les deux ou trois chiffres qui font piloter, le reste est du
/// contrôle. On ne trie donc pas par ordre d'arrivée mais par importance.
enum KpiWeight {
  /// Ce qu'on regarde en premier le matin. Grande vignette, courbe, écart.
  pilote,

  /// Ce qu'on vérifie ensuite. Vignette compacte, chiffre seul.
  suivi,
}

/// Un indicateur : ce qu'il vaut, et éventuellement d'où il vient.
class KpiTile {
  const KpiTile({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    this.weight = KpiWeight.suivi,
    this.secondary,
    this.trend,
    this.trendLabel,
    this.onTap,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color color;
  final KpiWeight weight;

  /// Montant d'appoint, par exemple la part en USD d'une journée.
  final String? secondary;

  /// Série RÉELLE, du plus ancien au plus récent. Nulle quand on n'a pas
  /// d'historique : on préfère une vignette sans courbe à une courbe inventée.
  final List<double>? trend;

  /// Ce que la courbe couvre, par exemple « 7 derniers jours ».
  final String? trendLabel;

  final VoidCallback? onTap;

  /// Écart entre le dernier point et le précédent, en pourcentage. Nul quand la
  /// série est trop courte ou que le point de départ est zéro (une progression
  /// depuis rien n'a pas de pourcentage qui veuille dire quelque chose).
  double? get variation {
    final t = trend;
    if (t == null || t.length < 2) return null;
    final avant = t[t.length - 2];
    if (avant == 0) return null;
    return ((t.last - avant) / avant.abs()) * 100;
  }
}

/// Tableau d'indicateurs, hiérarchisé et non étirable.
///
/// Sur téléphone les vignettes occupent la largeur ; sur tablette et sur
/// desktop elles gardent leur taille et se multiplient en colonnes, au lieu de
/// s'étirer jusqu'à devenir des bandeaux vides. C'est la même règle partout,
/// donc un seul endroit pour la corriger.
class KpiBoard extends StatelessWidget {
  const KpiBoard({super.key, required this.tiles, this.spacing = 12});

  final List<KpiTile> tiles;
  final double spacing;

  @override
  Widget build(BuildContext context) {
    final pilotes = tiles.where((t) => t.weight == KpiWeight.pilote).toList();
    final suivis = tiles.where((t) => t.weight == KpiWeight.suivi).toList();

    return LayoutBuilder(
      builder: (context, constraints) {
        final largeur = constraints.maxWidth;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (pilotes.isNotEmpty)
              _rangee(
                largeur: largeur,
                tuiles: pilotes,
                minLargeur: 240,
                maxLargeur: 380,
                hauteur: 148,
              ),
            if (pilotes.isNotEmpty && suivis.isNotEmpty)
              SizedBox(height: spacing),
            if (suivis.isNotEmpty)
              _rangee(
                largeur: largeur,
                tuiles: suivis,
                minLargeur: 148,
                maxLargeur: 220,
                hauteur: 98,
              ),
          ],
        );
      },
    );
  }

  Widget _rangee({
    required double largeur,
    required List<KpiTile> tuiles,
    required double minLargeur,
    required double maxLargeur,
    required double hauteur,
  }) {
    final colonnes = _colonnes(largeur, minLargeur, tuiles.length);
    var largeurTuile = (largeur - spacing * (colonnes - 1)) / colonnes;
    // Le plafond est ce qui empêche l'étirement : au-delà, on laisse du vide
    // plutôt que d'agrandir une vignette qui n'a rien de plus à montrer.
    if (largeurTuile > maxLargeur) largeurTuile = maxLargeur;

    return Wrap(
      spacing: spacing,
      runSpacing: spacing,
      children: [
        for (final t in tuiles)
          SizedBox(
            width: largeurTuile,
            height: hauteur,
            child: _KpiCardView(tile: t),
          ),
      ],
    );
  }

  /// Combien de vignettes tiennent côte à côte sans passer sous leur largeur
  /// minimale, sans jamais dépasser le nombre d'indicateurs à montrer.
  int _colonnes(double largeur, double minLargeur, int total) {
    final tiennent = ((largeur + spacing) / (minLargeur + spacing)).floor();
    return tiennent.clamp(1, total);
  }
}

class _KpiCardView extends StatelessWidget {
  const _KpiCardView({required this.tile});

  final KpiTile tile;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final pilote = tile.weight == KpiWeight.pilote;
    // La courbe et son écart vont ensemble : un pourcentage isolé sur chaque
    // vignette surcharge la lecture sans rien apprendre de plus.
    final courbe = pilote && _serieLisible(tile.trend);
    final variation = courbe ? tile.variation : null;

    final contenu = Padding(
      padding: EdgeInsets.all(pilote ? 14 : 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: pilote ? 15 : 14,
                backgroundColor: tile.color.withValues(alpha: 0.16),
                child: Icon(tile.icon,
                    color: tile.color, size: pilote ? 17 : 16),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  tile.label,
                  maxLines: pilote ? 1 : 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                ),
              ),
              if (variation != null) _Variation(valeur: variation),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            tile.value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: (pilote
                    ? theme.textTheme.headlineSmall
                    : theme.textTheme.titleMedium)
                ?.copyWith(
              fontWeight: FontWeight.bold,
              fontFeatures: const [ui.FontFeature.tabularFigures()],
            ),
          ),
          if (tile.secondary != null)
            Text(
              tile.secondary!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                fontFeatures: const [ui.FontFeature.tabularFigures()],
              ),
            ),
          const Spacer(),
          if (courbe)
            SizedBox(
              height: 28,
              width: double.infinity,
              child: CustomPaint(
                painter: _SparklinePainter(
                  points: tile.trend!,
                  couleur: tile.color,
                ),
              ),
            )
          else if (pilote && tile.trendLabel != null)
            Text(
              tile.trendLabel!,
              style: theme.textTheme.labelSmall
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
        ],
      ),
    );

    return Card(
      margin: EdgeInsets.zero,
      elevation: pilote ? 1.5 : 0.5,
      child: tile.onTap == null
          ? contenu
          : InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: tile.onTap,
              child: contenu,
            ),
    );
  }

  /// Une courbe ne se dessine que s'il y a vraiment quelque chose à voir :
  /// deux points au moins, et pas une ligne plate à zéro.
  static bool _serieLisible(List<double>? serie) {
    if (serie == null || serie.length < 2) return false;
    return serie.any((v) => v != 0);
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
            size: 12, color: couleur),
        Text(
          '${valeur.abs().toStringAsFixed(0)}%',
          style: theme.textTheme.labelSmall
              ?.copyWith(color: couleur, fontWeight: FontWeight.w700),
        ),
      ],
    );
  }
}

/// Courbe de tendance discrète, dessinée dans la vignette elle-même.
///
/// Elle ne porte ni axe ni graduation : son rôle n'est pas de donner une
/// valeur, c'est de dire d'un coup d'œil si ça monte ou si ça descend.
class _SparklinePainter extends CustomPainter {
  _SparklinePainter({required this.points, required this.couleur});

  final List<double> points;
  final Color couleur;

  @override
  void paint(Canvas canvas, Size size) {
    if (points.length < 2 || size.width <= 0 || size.height <= 0) return;

    final min = points.reduce((a, b) => a < b ? a : b);
    final max = points.reduce((a, b) => a > b ? a : b);
    final amplitude = max - min;
    final pas = size.width / (points.length - 1);

    Offset position(int i) {
      // Série plate : on la pose au milieu plutôt que collée à un bord.
      final ratio = amplitude == 0 ? 0.5 : (points[i] - min) / amplitude;
      return Offset(pas * i, size.height - ratio * (size.height - 3) - 1.5);
    }

    final trace = Path()..moveTo(position(0).dx, position(0).dy);
    for (var i = 1; i < points.length; i++) {
      final p = position(i);
      trace.lineTo(p.dx, p.dy);
    }

    final remplissage = Path.from(trace)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();

    canvas.drawPath(
      remplissage,
      Paint()
        ..shader = ui.Gradient.linear(
          Offset(0, 0),
          Offset(0, size.height),
          [couleur.withValues(alpha: 0.22), couleur.withValues(alpha: 0.02)],
        ),
    );

    canvas.drawPath(
      trace,
      Paint()
        ..color = couleur.withValues(alpha: 0.85)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );

    // Le dernier point marqué : c'est là qu'on en est.
    final fin = position(points.length - 1);
    canvas.drawCircle(fin, 2.4, Paint()..color = couleur);
  }

  @override
  bool shouldRepaint(_SparklinePainter old) =>
      old.points != points || old.couleur != couleur;
}
