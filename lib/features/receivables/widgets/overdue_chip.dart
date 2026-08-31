import 'package:flutter/material.dart';

/// Puce « En retard » affichée sur les ventes dont l'échéance est dépassée.
///
/// Cohérente avec les chips de statut existantes (bordure + fond teinté).
class OverdueChip extends StatelessWidget {
  /// Nombre de jours de retard (optionnel : ajouté au libellé si > 0).
  final int days;

  const OverdueChip({super.key, this.days = 0});

  @override
  Widget build(BuildContext context) {
    final label = days > 0 ? 'En retard ($days j)' : 'En retard';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.red.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.red.withValues(alpha: 0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.schedule, size: 12, color: Colors.red),
          const SizedBox(width: 4),
          Text(
            label,
            style: const TextStyle(
              color: Colors.red,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
