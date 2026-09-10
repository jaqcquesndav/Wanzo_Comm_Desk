import 'package:flutter/material.dart';
import '../../core/modules/activity_mode.dart';

/// Suggestion de départ Adha : une icône, un libellé court affiché sur la puce
/// et le prompt réellement envoyé à Adha quand l'utilisateur la choisit.
class AdhaSuggestion {
  final IconData icon;
  final String title;
  final String prompt;
  const AdhaSuggestion({
    required this.icon,
    required this.title,
    required this.prompt,
  });
}

/// Jeu de suggestions DÉRIVÉ du métier actif ([ActivityMode]) plutôt que codé
/// en dur pour la boutique. Chaque mode n'expose que des raccourcis pertinents
/// pour son activité (mêmes suggestions mobile et desktop, source unique).
List<AdhaSuggestion> suggestionsFor(ActivityMode mode) {
  switch (mode) {
    case ActivityMode.restaurant:
      return const [
        AdhaSuggestion(
          icon: Icons.restaurant_menu,
          title: 'Plats les plus vendus',
          prompt: 'Quels sont mes plats les plus vendus ce mois-ci ?',
        ),
        AdhaSuggestion(
          icon: Icons.table_restaurant_outlined,
          title: 'Rotation des tables',
          prompt: 'Analyse la rotation de mes tables et mes heures de pointe',
        ),
        AdhaSuggestion(
          icon: Icons.trending_up_outlined,
          title: 'Chiffre du jour',
          prompt: 'Comment se portent mes ventes aujourd\'hui ?',
        ),
        AdhaSuggestion(
          icon: Icons.receipt_long_outlined,
          title: 'Dépenses du mois',
          prompt: 'Résume mes dépenses du mois',
        ),
      ];
    case ActivityMode.salon:
      return const [
        AdhaSuggestion(
          icon: Icons.content_cut_outlined,
          title: 'Prestations rentables',
          prompt: 'Quelles prestations sont les plus rentables ?',
        ),
        AdhaSuggestion(
          icon: Icons.people_outline,
          title: 'Commissions coiffeurs',
          prompt: 'Calcule les commissions de mes coiffeurs ce mois-ci',
        ),
        AdhaSuggestion(
          icon: Icons.event_available_outlined,
          title: 'Affluence',
          prompt: 'Quels sont mes jours et heures les plus chargés ?',
        ),
        AdhaSuggestion(
          icon: Icons.trending_up_outlined,
          title: 'Performance',
          prompt: 'Comment se porte mon salon ce mois-ci ?',
        ),
      ];
    case ActivityMode.atelier:
    case ActivityMode.atelierMaintenance:
    case ActivityMode.imprimerie:
      return const [
        AdhaSuggestion(
          icon: Icons.build_circle_outlined,
          title: 'Commandes en fabrication',
          prompt: 'Quelles commandes sont en cours de fabrication ?',
        ),
        AdhaSuggestion(
          icon: Icons.schedule_outlined,
          title: 'Commandes en retard',
          prompt: 'Quelles commandes sont en retard de livraison ?',
        ),
        AdhaSuggestion(
          icon: Icons.trending_up_outlined,
          title: 'Charge de l\'atelier',
          prompt: 'Analyse la charge de travail de mon atelier',
        ),
        AdhaSuggestion(
          icon: Icons.receipt_long_outlined,
          title: 'Dépenses du mois',
          prompt: 'Résume mes dépenses du mois',
        ),
      ];
    case ActivityMode.hotel:
      return const [
        AdhaSuggestion(
          icon: Icons.hotel_outlined,
          title: 'Taux d\'occupation',
          prompt: 'Quel est mon taux d\'occupation des chambres ?',
        ),
        AdhaSuggestion(
          icon: Icons.event_available_outlined,
          title: 'Réservations à venir',
          prompt: 'Quelles sont mes réservations à venir ?',
        ),
        AdhaSuggestion(
          icon: Icons.trending_up_outlined,
          title: 'Performance',
          prompt: 'Comment se porte mon établissement ce mois-ci ?',
        ),
        AdhaSuggestion(
          icon: Icons.receipt_long_outlined,
          title: 'Dépenses du mois',
          prompt: 'Résume mes dépenses du mois',
        ),
      ];
    case ActivityMode.services:
      return const [
        AdhaSuggestion(
          icon: Icons.handyman_outlined,
          title: 'Prestations rentables',
          prompt: 'Quelles prestations sont les plus rentables ?',
        ),
        AdhaSuggestion(
          icon: Icons.assignment_outlined,
          title: 'Interventions en cours',
          prompt: 'Quelles interventions sont en cours ?',
        ),
        AdhaSuggestion(
          icon: Icons.trending_up_outlined,
          title: 'Performance',
          prompt: 'Comment se porte mon activité ce mois-ci ?',
        ),
        AdhaSuggestion(
          icon: Icons.receipt_long_outlined,
          title: 'Dépenses du mois',
          prompt: 'Résume mes dépenses du mois',
        ),
      ];
    case ActivityMode.retail:
      return const [
        AdhaSuggestion(
          icon: Icons.analytics_outlined,
          title: 'Analyser mes ventes',
          prompt: 'Analyse mes ventes de cette semaine',
        ),
        AdhaSuggestion(
          icon: Icons.inventory_2_outlined,
          title: 'État du stock',
          prompt: 'Montre-moi les produits en faible stock',
        ),
        AdhaSuggestion(
          icon: Icons.calculate_outlined,
          title: 'Marge brute',
          prompt: 'Calcule ma marge brute sur les ventes récentes',
        ),
        AdhaSuggestion(
          icon: Icons.receipt_long_outlined,
          title: 'Dépenses du mois',
          prompt: 'Résume mes dépenses du mois',
        ),
      ];
  }
}
