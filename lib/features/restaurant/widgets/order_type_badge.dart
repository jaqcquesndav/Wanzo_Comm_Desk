import 'package:flutter/material.dart';

import '../models/restaurant_order.dart';
import '../../proforma/models/proforma.dart';
import '../../proforma/widgets/proforma_sheet.dart';
import 'new_order_dialog.dart' show orderTypeIcon;

/// Lignes de proforma d'une commande du restaurant : un article du stock
/// reste un produit (il sortira du stock à la facture), un plat est un
/// service. Prix en base CDF, comme la carte.
List<ProformaLine> lignesProformaCommande(RestaurantOrder order) => [
      for (final l in order.lines)
        if (l.quantity > 0)
          ProformaLine(
            label: (l.note != null && l.note!.trim().isNotEmpty)
                ? '${l.productName} (${l.note!.trim()})'
                : l.productName,
            quantity: l.quantity.toDouble(),
            unitPriceCdf: l.unitPriceCdf,
            itemType: l.fromStock ? 'product' : 'service',
            productId: l.fromStock ? l.productId : null,
          ),
    ];

/// Émet la proforma d'une commande (client, lieu de service).
Future<void> proformaDeCommande(BuildContext context, RestaurantOrder order,
        {VoidCallback? onCheckoutOrder}) =>
    issueProforma(
      context,
      sourceType: ProformaSource.restaurantOrder,
      sourceId: order.id,
      customerId: order.customerId,
      customerName: order.customerName ??
          (order.type == RestaurantOrderType.takeaway ? order.label : null),
      lines: lignesProformaCommande(order),
      notes: order.placeLabel,
      onCheckoutOrder: onCheckoutOrder,
    );

/// Badge clair distinguant une commande SUR PLACE (table) d'une commande À
/// EMPORTER, posé sur les cartes de commande et l'aperçu rapide.
///
/// Sur place = accent bleu (service en salle) ; à emporter = accent violet
/// (comptoir) ; sur réservation = accent sarcelle (folio). Le badge dit où part
/// la commande : « Table 4 », « À emporter », « Chambre 12 », « Salle Lualaba ».
/// Purement présentationnel.
class OrderTypeBadge extends StatelessWidget {
  final RestaurantOrderType type;
  final bool compact;

  /// Texte affiché (« Table 4 », « Chambre 12 », « Salle Lualaba »). Par
  /// défaut, la nature du service.
  final String? text;

  /// Salle plutôt que chambre (icône), pour une commande sur réservation.
  final bool hall;

  const OrderTypeBadge({
    super.key,
    required this.type,
    this.compact = false,
    this.text,
    this.hall = false,
  });

  /// Badge d'une commande : où elle part, en clair. Posé à côté du libellé
  /// de la commande, il ne le répète pas (« Table 4 » + « Sur place »,
  /// « 12 » + « Chambre 12 », « Chambre 12 » + « Chambre »).
  factory OrderTypeBadge.of(RestaurantOrder order, {bool compact = false}) {
    final lieu = order.placeLabel;
    final repete = lieu.trim().toLowerCase() == order.label.trim().toLowerCase();
    return OrderTypeBadge(
      type: order.type,
      compact: compact,
      text: !repete
          ? lieu
          : (order.type == RestaurantOrderType.reservation
              ? (order.isHall ? 'Salle' : 'Chambre')
              : order.type.label),
      hall: order.isHall,
    );
  }

  @override
  Widget build(BuildContext context) {
    final color = switch (type) {
      RestaurantOrderType.dineIn => const Color(0xFF0EA5E9),
      RestaurantOrderType.takeaway => const Color(0xFF8B5CF6),
      RestaurantOrderType.reservation => const Color(0xFF0D9488),
    };
    final icon = type == RestaurantOrderType.reservation
        ? (hall ? Icons.meeting_room : Icons.hotel)
        : orderTypeIcon(type);
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
            text ?? type.label,
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
