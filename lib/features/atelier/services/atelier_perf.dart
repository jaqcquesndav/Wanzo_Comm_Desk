import '../models/atelier_order.dart';

/// KPI de performance de prestation d'un atelier (durées d'étapes), calculés à
/// partir de l'historique horodaté des commandes. Destinés à l'affichage sur le
/// board et, à terme, à alimenter la COTE CRÉDIT de l'entreprise.
class AtelierPerfSummary {
  final int completed; // commandes terminées (livrées/réglées)
  final int inProgress; // commandes actives
  final double avgCycleDays; // délai moyen création → terminé (jours)
  final double onTimeRate; // part des commandes livrées à temps (0..1)

  const AtelierPerfSummary({
    required this.completed,
    required this.inProgress,
    required this.avgCycleDays,
    required this.onTimeRate,
  });

  bool get hasData => completed > 0 || inProgress > 0;
}

const _doneStatuses = {AtelierOrderStatus.delivered, AtelierOrderStatus.paid};

AtelierPerfSummary computeAtelierPerf(List<AtelierOrder> orders) {
  int completed = 0, inProgress = 0, onTime = 0, onTimeEligible = 0;
  double cycleSum = 0;
  int cycleN = 0;

  for (final o in orders) {
    if (o.status.isActive) inProgress++;
    if (!_doneStatuses.contains(o.status)) continue;
    completed++;

    final start = o.stageHistory.isNotEmpty
        ? o.stageHistory.first.at
        : (o.entryDate ?? o.createdAt);
    final end = o.stageHistory.isNotEmpty
        ? o.stageHistory.last.at
        : (o.lastActionAt ?? o.exitDate);

    if (start != null && end != null && end.isAfter(start)) {
      cycleSum += end.difference(start).inHours / 24.0;
      cycleN++;
    }
    // Respect du délai : terminé au plus tard à la date de sortie prévue.
    if (o.exitDate != null && end != null) {
      onTimeEligible++;
      if (!end.isAfter(o.exitDate!)) onTime++;
    }
  }

  return AtelierPerfSummary(
    completed: completed,
    inProgress: inProgress,
    avgCycleDays: cycleN > 0 ? cycleSum / cycleN : 0,
    onTimeRate: onTimeEligible > 0 ? onTime / onTimeEligible : 0,
  );
}
