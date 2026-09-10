import 'package:flutter/material.dart';

import '../models/restaurant_order.dart';

/// Badge clair distinguant une commande SUR PLACE (table) d'une commande À
/// EMPORTER, posé sur les cartes de commande et l'aperçu rapide.
///
/// Sur place = accent bleu (service en salle) ; à emporter = accent violet
/// (comptoir). Purement présentationnel.
class OrderTypeBadge extends StatelessWidget {
  final RestaurantOrderType type;
  final bool compact;

  const OrderTypeBadge({super.key, required this.type, this.compact = false});

  @override
  Widget build(BuildContext context) {
    final dineIn = type == RestaurantOrderType.dineIn;
    final color =
        dineIn ? const Color(0xFF0EA5E9) : const Color(0xFF8B5CF6);
    final icon = dineIn ? Icons.restaurant : Icons.takeout_dining;
    return Container(
      padding: EdgeInsets.symmetric(horizontal: compact ? 6 : 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            type.label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
