import 'package:flutter/material.dart';

/// Périodes disponibles pour l'affichage des graphiques
enum ChartPeriod {
  day, // Heures de la journée
  week, // Jours de la semaine
  month, // Jours du mois
  quarter, // Mois du trimestre
  year, // Mois de l'année
}

extension ChartPeriodExtension on ChartPeriod {
  String get displayName {
    switch (this) {
      case ChartPeriod.day:
        return 'Aujourd\'hui';
      case ChartPeriod.week:
        return 'Semaine';
      case ChartPeriod.month:
        return 'Mois';
      case ChartPeriod.quarter:
        return 'Trimestre';
      case ChartPeriod.year:
        return 'Année';
    }
  }

  IconData get icon {
    switch (this) {
      case ChartPeriod.day:
        return Icons.schedule;
      case ChartPeriod.week:
        return Icons.view_week;
      case ChartPeriod.month:
        return Icons.calendar_month;
      case ChartPeriod.quarter:
        return Icons.calendar_view_month;
      case ChartPeriod.year:
        return Icons.calendar_today;
    }
  }

  /// Obtient les dates de début et fin pour la période
  DateTimeRange getDateRange(DateTime referenceDate) {
    final now = referenceDate;

    switch (this) {
      case ChartPeriod.day:
        // Aujourd'hui de 00:00 à 23:59
        return DateTimeRange(
          start: DateTime(now.year, now.month, now.day, 0, 0, 0),
          end: DateTime(now.year, now.month, now.day, 23, 59, 59),
        );

      case ChartPeriod.week:
        // Derniers 7 jours
        return DateTimeRange(
          start: DateTime(now.year, now.month, now.day - 6, 0, 0, 0),
          end: DateTime(now.year, now.month, now.day, 23, 59, 59),
        );

      case ChartPeriod.month:
        // Mois actuel
        return DateTimeRange(
          start: DateTime(now.year, now.month, 1, 0, 0, 0),
          end: DateTime(now.year, now.month + 1, 0, 23, 59, 59),
        );

      case ChartPeriod.quarter:
        // Trimestre actuel
        final quarterStartMonth = ((now.month - 1) ~/ 3) * 3 + 1;
        return DateTimeRange(
          start: DateTime(now.year, quarterStartMonth, 1, 0, 0, 0),
          end: DateTime(now.year, quarterStartMonth + 3, 0, 23, 59, 59),
        );

      case ChartPeriod.year:
        // Année actuelle
        return DateTimeRange(
          start: DateTime(now.year, 1, 1, 0, 0, 0),
          end: DateTime(now.year, 12, 31, 23, 59, 59),
        );
    }
  }

  /// Nombre de points à afficher sur le graphique
  int get dataPoints {
    switch (this) {
      case ChartPeriod.day:
        return 24; // 24 heures
      case ChartPeriod.week:
        return 7; // 7 jours
      case ChartPeriod.month:
        return 30; // ~30 jours
      case ChartPeriod.quarter:
        return 3; // 3 mois
      case ChartPeriod.year:
        return 12; // 12 mois
    }
  }
}
