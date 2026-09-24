import 'package:wanzo/features/sales/models/sale.dart';

/// Séries journalières bâties sur des ventes RÉELLES.
///
/// Les vignettes de pilotage portent une courbe de tendance ; cette courbe doit
/// venir des ventes enregistrées, jamais d'un jeu de valeurs de démonstration.
/// Quand il n'y a rien à tracer, on retourne une liste vide et la vignette
/// s'affiche sans courbe.
class DailySeries {
  const DailySeries._();

  /// Chiffre d'affaires par jour sur les [jours] derniers jours, du plus ancien
  /// au plus récent, en CDF. Les jours sans vente valent zéro : c'est une
  /// information, pas un trou.
  static List<double> revenue(List<Sale> ventes, {int jours = 7}) {
    if (ventes.isEmpty || jours < 2) return const [];

    final maintenant = DateTime.now();
    final aujourdhui =
        DateTime(maintenant.year, maintenant.month, maintenant.day);
    final debut = aujourdhui.subtract(Duration(days: jours - 1));

    final parJour = List<double>.filled(jours, 0);
    for (final v in ventes) {
      final jour = DateTime(v.date.year, v.date.month, v.date.day);
      if (jour.isBefore(debut) || jour.isAfter(aujourdhui)) continue;
      parJour[jour.difference(debut).inDays] += v.totalAmountInCdf;
    }

    // Aucune vente dans la fenêtre : pas de courbe plutôt qu'une ligne à zéro.
    return parJour.any((v) => v != 0) ? parJour : const [];
  }
}
