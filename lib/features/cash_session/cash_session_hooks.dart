import 'package:flutter/foundation.dart';

import '../../core/models/operation_payment.dart';
import '../expenses/models/expense.dart';
import '../sales/models/sale.dart';
import 'models/cash_session.dart';
import 'services/cash_session_service.dart';

/// Montant CDF exprimé dans la devise de la pièce, au taux figé de la pièce.
/// Sans taux exploitable, on reste en CDF (jamais un taux 1 silencieux).
({String currency, double amount}) _inOwnCurrency(
  String? currency,
  double? rate,
  double amountCdf,
) {
  final code = (currency ?? 'CDF').toUpperCase();
  if (code == 'CDF' || rate == null || rate <= 0) {
    return (currency: 'CDF', amount: cashRound(amountCdf));
  }
  return (currency: code, amount: cashRound(amountCdf / rate));
}

/// Mouvement de caisse d'une vente (montant payé à la vente). Null si rien
/// n'a été payé. L'acompte d'une vente à crédit est compté en espèces.
@visibleForTesting
CashMovement? cashMovementForSale(Sale sale) {
  if (sale.paidAmountInCdf <= 0) return null;
  final pm = (sale.paymentMethod ?? '').toLowerCase();
  final isCredit = pm.contains('crédit') || pm.contains('credit') || pm.contains('échel') || pm.contains('echel');
  final own = _inOwnCurrency(
    sale.transactionCurrencyCode,
    sale.transactionExchangeRate,
    sale.paidAmountInCdf,
  );
  return CashMovement(
    at: sale.date,
    kind: CashMovementKind.sale,
    method: isCredit ? 'cash' : sale.paymentMethod,
    currency: own.currency,
    amount: own.amount,
    label: 'Vente #${sale.id.length >= 6 ? sale.id.substring(0, 6) : sale.id}',
    ref: sale.id,
  );
}

/// Mouvement d'une dépense payée à la création (part payée seulement).
@visibleForTesting
CashMovement? cashMovementForExpense(Expense expense) {
  final total = expense.amount.abs();
  final paid =
      expense.paymentStatus == ExpensePaymentStatus.paid
          ? total
          : (expense.paidAmount ?? 0).abs().clamp(0.0, total).toDouble();
  if (paid <= 0) return null;
  return CashMovement(
    at: expense.date,
    kind: CashMovementKind.expense,
    method: expense.paymentMethod,
    currency: expense.effectiveCurrencyCode,
    amount: -cashRound(paid),
    label: 'Dépense : ${expense.motif}',
    ref: expense.id,
  );
}

CashMovement _forPayment(
  PaymentDraft p, {
  required bool incoming,
  required String label,
  required String ref,
}) => CashMovement(
  at: p.paidAt,
  kind: incoming ? CashMovementKind.customerPayment : CashMovementKind.expense,
  method: p.method,
  currency: p.currencyCode.toUpperCase(),
  amount: incoming ? cashRound(p.amount) : -cashRound(p.amount),
  label: label,
  ref: ref,
);

/// Points d'accroche appelés par les blocs : la caisse ouverte reçoit le
/// mouvement ; sans caisse ouverte, rien n'est bloqué.
class CashSessionHooks {
  static Future<void> onSale(Sale sale) => _safe(cashMovementForSale(sale));

  static Future<void> onSalePayment(Sale sale, PaymentDraft payment) => _safe(
    _forPayment(
      payment,
      incoming: true,
      label: 'Règlement ${sale.customerName}',
      ref: sale.id,
    ),
  );

  static Future<void> onExpense(Expense expense) => _safe(cashMovementForExpense(expense));

  static Future<void> onExpensePayment(Expense expense, PaymentDraft payment) => _safe(
    _forPayment(
      payment,
      incoming: false,
      label: 'Règlement : ${expense.motif}',
      ref: expense.id,
    ),
  );

  static Future<void> _safe(CashMovement? m) async {
    if (m == null) return;
    try {
      await CashSessionService.instance.recordMovement(m);
    } catch (e) {
      debugPrint('⚠️ Caisse : mouvement non rattaché ($e)');
    }
  }
}
