import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:wanzo/core/models/operation_payment.dart';
import 'package:wanzo/core/utils/currency_formatter.dart';

/// Historique des tranches de règlement d'une opération (vente ou dépense).
///
/// Alimenté par `GET sales/:id/payments` ou `GET expenses/:id/payments`. Le
/// chargement est volontairement tolérant : si le serveur est injoignable ou
/// que l'historique détaillé n'est pas disponible, la section se contente
/// d'afficher le cumul déjà connu localement plutôt que de casser la page.
class PaymentHistorySection extends StatefulWidget {
  /// Chargeur des tranches (retourne une liste vide si indisponible).
  final Future<List<OperationPayment>> Function() loader;

  /// Devise de l'opération, pour formater les montants sans tranche connue.
  final String currencyCode;

  /// Cumul déjà réglé, utilisé en repli lorsque le détail est indisponible.
  final double fallbackPaidAmount;

  final String title;

  /// Jeton qui change à chaque règlement enregistré pour forcer le rechargement.
  final Object? refreshToken;

  const PaymentHistorySection({
    super.key,
    required this.loader,
    required this.currencyCode,
    this.fallbackPaidAmount = 0,
    this.title = 'Historique des règlements',
    this.refreshToken,
  });

  @override
  State<PaymentHistorySection> createState() => _PaymentHistorySectionState();
}

class _PaymentHistorySectionState extends State<PaymentHistorySection> {
  late Future<List<OperationPayment>> _future;

  @override
  void initState() {
    super.initState();
    _future = widget.loader();
  }

  @override
  void didUpdateWidget(PaymentHistorySection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.refreshToken != widget.refreshToken) {
      setState(() {
        _future = widget.loader();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.receipt_long, color: Theme.of(context).primaryColor),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    widget.title,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            FutureBuilder<List<OperationPayment>>(
              future: _future,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    child: Center(
                      child: SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    ),
                  );
                }
                final payments = snapshot.data ?? const <OperationPayment>[];
                if (payments.isEmpty) {
                  return _buildFallback(context);
                }
                return Column(
                  children: [
                    for (var i = 0; i < payments.length; i++) ...[
                      if (i > 0) const Divider(height: 12),
                      _buildTile(context, payments[i]),
                    ],
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFallback(BuildContext context) {
    if (widget.fallbackPaidAmount > 0) {
      return Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Expanded(child: Text('Total déjà réglé')),
          Text(
            formatCurrency(widget.fallbackPaidAmount, widget.currencyCode),
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ],
      );
    }
    return Text(
      'Aucun règlement enregistré pour le moment.',
      style: TextStyle(color: Colors.grey.shade600),
    );
  }

  Widget _buildTile(BuildContext context, OperationPayment payment) {
    final subtitleParts = <String>[
      if (payment.isOpening) 'Cumul antérieur',
      if (payment.paidAt != null)
        DateFormat('dd/MM/yyyy').format(payment.paidAt!),
      if (payment.method != null && payment.method!.isNotEmpty) payment.method!,
      if (payment.reference != null && payment.reference!.isNotEmpty)
        'Réf. ${payment.reference}',
    ];

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(Icons.payments_outlined, size: 18),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            subtitleParts.isEmpty ? 'Règlement' : subtitleParts.join(' · '),
            style: const TextStyle(fontSize: 13),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          formatCurrency(payment.amount, payment.currencyCode),
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
      ],
    );
  }
}
