import 'dart:math' as math;

import 'package:uuid/uuid.dart';

import '../../cash_session/models/cash_session.dart' show cashRound;
import '../../sales/models/sale.dart';
import '../../sales/models/sale_item.dart';
import '../models/atelier_order.dart';

/// Avance à ENCAISSER à l'enregistrement d'une commande atelier, pressing ou
/// garage : la nouvelle avance moins celle déjà encaissée. Une commande
/// rouverte sans changer l'avance n'encaisse rien (jamais deux fois).
double atelierAdvanceToCollect({
  required double newAdvance,
  double previousAdvance = 0,
}) {
  final delta = cashRound(newAdvance - previousAdvance);
  return delta > 0 ? delta : 0;
}

/// Identifiant local de la vente d'avance : déduit de la commande et du
/// cumul d'avance encaissé, il est le même à chaque nouvel essai (double
/// appui, reprise hors ligne). Le serveur déduplique sur ce localId : la même
/// avance n'est jamais encaissée deux fois.
String atelierAdvanceLocalId(AtelierOrder order, double cumulativeAdvance) =>
    const Uuid().v5(
      Namespace.url.value,
      'wanzo:atelier-advance:${order.id}:${(cumulativeAdvance * 100).round()}',
    );

/// Vente de l'avance : une prestation payée en entier, par le moyen choisi
/// (espèces, Mobile Money...). Elle passe par la voie normale des ventes
/// (caisse, journal, comptabilité du serveur). Le règlement final ne
/// facture ensuite que le reste.
Sale atelierAdvanceSale({
  required AtelierOrder order,
  required double amount,
  required String paymentMethod,
  DateTime? at,
  // Identifiant local fixe (voir [atelierAdvanceLocalId]).
  String? localId,
}) {
  final code = order.currencyCode.toUpperCase();
  final rate = code == 'CDF' ? 1.0 : order.exchangeRate;
  final value = cashRound(amount);
  final line = SaleItem.withCalculatedTotal(
    // UUID de la commande (pas un produit du stock), comme le règlement.
    productId: order.id,
    productName: 'Avance : ${order.label}',
    quantity: 1,
    unitPrice: value,
    currencyCode: code,
    exchangeRate: rate,
    itemType: SaleItemType.service,
    notes: '[Atelier] Avance (commande ${order.id})',
  );
  return Sale(
    id: '',
    localId: localId ?? atelierAdvanceLocalId(order, order.advanceAmount),
    date: at ?? DateTime.now(),
    customerId: order.customerId.isEmpty ? null : order.customerId,
    customerName: (order.customerName ?? '').trim().isEmpty ? 'Client' : order.customerName!,
    customerPhoneNumber: order.customerPhone,
    items: [line],
    totalAmountInCdf: value * rate,
    paidAmountInCdf: value * rate,
    transactionCurrencyCode: code,
    transactionExchangeRate: rate,
    totalAmountInTransactionCurrency: value,
    paidAmountInTransactionCurrency: value,
    paymentMethod: paymentMethod,
    status: SaleStatus.completed,
    notes: 'Avance commande « ${order.label} »',
  );
}

/// Montant à facturer au règlement : le reste de la commande, avance
/// déduite. Zéro si l'avance couvre déjà tout (rien à facturer en double).
double atelierAmountToBill(AtelierOrder order) {
  if (order.remainingAmount > 0) return order.remainingAmount;
  return math.max(0, cashRound(order.totalAmount - order.advanceAmount));
}
