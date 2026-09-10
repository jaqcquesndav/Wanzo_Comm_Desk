import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:wanzo/core/shared_widgets/record_payment_dialog.dart';
import 'package:wanzo/features/sales/bloc/sales_bloc.dart';
import 'package:wanzo/features/sales/models/sale.dart';

/// Parcours complet « régler une créance client », réutilisable depuis
/// n'importe quel écran (détail vente, créances, fiche client).
///
/// 1. Ouvre le dialogue de saisie (montant plafonné au reste à payer, mode,
///    date, référence).
/// 2. Dispatche [RecordSalePayment] sur le [SalesBloc].
/// 3. ATTEND la réponse et affiche le résultat. L'écran ne se ferme jamais
///    avant l'issue de l'appel : un échec serveur ne peut plus passer
///    inaperçu.
///
/// Renvoie la vente à jour en cas de succès, sinon `null`.
Future<Sale?> startSalePaymentFlow(BuildContext context, Sale sale) async {
  final total = sale.totalAmountInTransactionCurrency ?? sale.totalAmountInCdf;
  final paid = sale.paidAmountInTransactionCurrency ?? sale.paidAmountInCdf;
  final remaining = total - paid;
  final currencyCode = sale.transactionCurrencyCode ?? 'CDF';

  if (remaining <= 0) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Cette vente est déjà soldée.')),
    );
    return null;
  }

  final draft = await showRecordPaymentDialog(
    context,
    remainingAmount: remaining,
    currencyCode: currencyCode,
    exchangeRate: sale.transactionExchangeRate,
    defaultMethod: sale.paymentMethod,
  );
  if (draft == null || !context.mounted) return null;

  final bloc = context.read<SalesBloc>();
  final messenger = ScaffoldMessenger.of(context);
  bloc.add(RecordSalePayment(sale: sale, payment: draft));

  final state = await bloc.stream
      .firstWhere(
        (candidate) =>
            candidate is SalePaymentRecorded || candidate is SalesError,
      )
      .timeout(
        const Duration(seconds: 45),
        onTimeout: () => const SalesInitial(),
      );

  if (state is SalePaymentRecorded) {
    messenger.showSnackBar(
      SnackBar(
        content: Text(state.message),
        backgroundColor: state.synced ? Colors.green : Colors.orange,
      ),
    );
    return state.sale;
  }
  if (state is SalesError) {
    messenger.showSnackBar(
      SnackBar(
        content: Text(state.message),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 5),
      ),
    );
    return null;
  }
  messenger.showSnackBar(
    const SnackBar(
      content: Text(
        'Le paiement met du temps à répondre. Vérifiez la vente avant de le ressaisir.',
      ),
      backgroundColor: Colors.orange,
    ),
  );
  return null;
}

/// Sélecteur de pièce à régler parmi les ventes impayées d'un client.
///
/// Renvoie directement l'unique vente s'il n'y en a qu'une : aucune étape
/// inutile pour le cas courant.
Future<Sale?> pickSaleToSettle(
  BuildContext context,
  List<Sale> outstandingSales, {
  String title = 'Quelle pièce régler ?',
  String Function(double amountInCdf)? formatAmount,
}) async {
  if (outstandingSales.isEmpty) return null;
  if (outstandingSales.length == 1) return outstandingSales.first;

  return showModalBottomSheet<Sale>(
    context: context,
    showDragHandle: true,
    builder:
        (sheetContext) => SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Fermer',
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(sheetContext),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: outstandingSales.length,
                  itemBuilder: (context, index) {
                    final sale = outstandingSales[index];
                    final due = sale.totalAmountInCdf - sale.paidAmountInCdf;
                    final reference =
                        (sale.invoiceNumber != null &&
                                sale.invoiceNumber!.isNotEmpty)
                            ? sale.invoiceNumber!
                            : (sale.id.length >= 8
                                ? sale.id.substring(0, 8)
                                : sale.id);
                    return ListTile(
                      leading: const Icon(Icons.receipt_long),
                      title: Text('Pièce $reference'),
                      subtitle: Text(
                        'Vente du ${sale.date.day.toString().padLeft(2, '0')}/'
                        '${sale.date.month.toString().padLeft(2, '0')}/${sale.date.year}',
                      ),
                      trailing: Text(
                        formatAmount != null
                            ? formatAmount(due)
                            : '${due.toStringAsFixed(0)} CDF',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      onTap: () => Navigator.pop(sheetContext, sale),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
  );
}
