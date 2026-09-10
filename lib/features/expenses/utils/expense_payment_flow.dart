import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:wanzo/core/shared_widgets/record_payment_dialog.dart';
import 'package:wanzo/features/expenses/bloc/expense_bloc.dart';
import 'package:wanzo/features/expenses/models/expense.dart';

/// Parcours complet « régler une dette fournisseur », réutilisable depuis
/// n'importe quel écran (détail dépense, fiche fournisseur, dettes).
///
/// Saisie (montant plafonné au reste à payer, mode, date, référence) puis
/// [RecordExpensePayment], et ON ATTEND la réponse avant d'informer
/// l'utilisateur : un refus serveur ne peut plus passer inaperçu.
///
/// Renvoie la dépense à jour en cas de succès, sinon `null`.
Future<Expense?> startExpensePaymentFlow(
  BuildContext context,
  Expense expense,
) async {
  final remaining = expense.remainingAmount;
  if (remaining <= 0) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Cette dépense est déjà soldée.')),
    );
    return null;
  }

  final draft = await showRecordPaymentDialog(
    context,
    remainingAmount: remaining,
    currencyCode: expense.effectiveCurrencyCode,
    exchangeRate: expense.exchangeRate,
    defaultMethod: expense.paymentMethod,
  );
  if (draft == null || !context.mounted) return null;

  final bloc = context.read<ExpenseBloc>();
  final messenger = ScaffoldMessenger.of(context);
  bloc.add(RecordExpensePayment(expense: expense, payment: draft));

  final state = await bloc.stream
      .firstWhere(
        (candidate) =>
            candidate is ExpensePaymentRecorded || candidate is ExpenseError,
      )
      .timeout(
        const Duration(seconds: 45),
        onTimeout: () => const ExpenseInitial(),
      );

  if (state is ExpensePaymentRecorded) {
    messenger.showSnackBar(
      SnackBar(
        content: Text(state.message),
        backgroundColor: state.synced ? Colors.green : Colors.orange,
      ),
    );
    return state.expense;
  }
  if (state is ExpenseError) {
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
        'Le paiement met du temps à répondre. Vérifiez la dépense avant de le ressaisir.',
      ),
      backgroundColor: Colors.orange,
    ),
  );
  return null;
}

/// Sélecteur de dépense à régler parmi les dettes d'un fournisseur.
Future<Expense?> pickExpenseToSettle(
  BuildContext context,
  List<Expense> unpaidExpenses, {
  String title = 'Quelle dette régler ?',
  String Function(double amount)? formatAmount,
}) async {
  if (unpaidExpenses.isEmpty) return null;
  if (unpaidExpenses.length == 1) return unpaidExpenses.first;

  return showModalBottomSheet<Expense>(
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
                  itemCount: unpaidExpenses.length,
                  itemBuilder: (context, index) {
                    final expense = unpaidExpenses[index];
                    return ListTile(
                      leading: const Icon(Icons.receipt_long),
                      title: Text(expense.motif),
                      subtitle: Text(
                        '${expense.date.day.toString().padLeft(2, '0')}/'
                        '${expense.date.month.toString().padLeft(2, '0')}/'
                        '${expense.date.year}',
                      ),
                      trailing: Text(
                        formatAmount != null
                            ? formatAmount(expense.remainingAmount)
                            : '${expense.remainingAmount.toStringAsFixed(0)} '
                                '${expense.effectiveCurrencyCode}',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      onTap: () => Navigator.pop(sheetContext, expense),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
  );
}
