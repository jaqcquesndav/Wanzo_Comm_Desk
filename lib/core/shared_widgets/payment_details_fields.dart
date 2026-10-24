import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/payment_method_code.dart';
import '../widgets/operator_logo.dart';

/// Contrôle des détails exigés par le moyen de paiement, avant l'envoi :
/// - Mobile Money : opérateur et référence de la transaction ;
/// - Crédit : date d'échéance.
/// Retourne le message à afficher, ou null si tout est en ordre.
String? paymentDetailsError({
  required String method,
  OperatorBrand? operator,
  String? reference,
  DateTime? dueDate,
}) {
  final code = paymentMethodCode(method);
  if (code == PaymentMethodCode.mobileMoney) {
    if (operator == null) return 'Choisissez l\'opérateur Mobile Money.';
    if ((reference ?? '').trim().isEmpty) {
      return 'Saisissez la référence de la transaction Mobile Money.';
    }
  }
  if (code == PaymentMethodCode.credit && dueDate == null) {
    return 'Choisissez la date d\'échéance du crédit.';
  }
  return null;
}

/// Note ajoutée à la pièce pour garder l'opérateur Mobile Money.
String mobileMoneyNote(OperatorBrand? operator) =>
    operator == null ? '' : 'Mobile Money ${operator.label}';

/// Champs complémentaires du moyen de paiement, partagés par la vente, la
/// caisse du restaurant et la caisse du salon : opérateur et référence pour
/// Mobile Money (obligatoires), échéance pour une vente à crédit (J+30 par
/// défaut, modifiable). Rien n'est affiché pour les autres moyens.
class PaymentDetailsFields extends StatelessWidget {
  const PaymentDetailsFields({
    super.key,
    required this.method,
    required this.operator,
    required this.onOperatorChanged,
    required this.referenceController,
    required this.dueDate,
    required this.onDueDateChanged,
  });

  final String method;
  final OperatorBrand? operator;
  final ValueChanged<OperatorBrand?> onOperatorChanged;
  final TextEditingController referenceController;
  final DateTime? dueDate;
  final ValueChanged<DateTime> onDueDateChanged;

  @override
  Widget build(BuildContext context) {
    final code = paymentMethodCode(method);
    if (code == PaymentMethodCode.mobileMoney) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 12),
          DropdownButtonFormField<OperatorBrand>(
            value: operator,
            isExpanded: true,
            decoration: const InputDecoration(
              labelText: 'Opérateur',
              border: OutlineInputBorder(),
            ),
            items: [
              for (final b in OperatorBrand.values)
                DropdownMenuItem(
                  value: b,
                  child: Row(
                    children: [
                      OperatorLogo(b, size: 22, excludeSemantics: true),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(b.label, overflow: TextOverflow.ellipsis),
                      ),
                    ],
                  ),
                ),
            ],
            validator: (v) => v == null ? 'Choisissez l\'opérateur' : null,
            onChanged: onOperatorChanged,
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: referenceController,
            decoration: const InputDecoration(
              labelText: 'Référence de la transaction',
              hintText: 'Code reçu par SMS',
              border: OutlineInputBorder(),
            ),
            textInputAction: TextInputAction.next,
            validator:
                (v) =>
                    (v == null || v.trim().isEmpty)
                        ? 'Référence obligatoire pour Mobile Money'
                        : null,
          ),
        ],
      );
    }
    if (code == PaymentMethodCode.credit) {
      final d = dueDate ?? defaultCreditDueDate();
      return Padding(
        padding: const EdgeInsets.only(top: 12),
        child: InkWell(
          borderRadius: BorderRadius.circular(4),
          onTap: () async {
            final now = DateTime.now();
            final picked = await showDatePicker(
              context: context,
              initialDate: d,
              firstDate: DateTime(now.year, now.month, now.day),
              lastDate: now.add(const Duration(days: 730)),
              helpText: 'Date d\'échéance',
            );
            if (picked != null) onDueDateChanged(picked);
          },
          child: InputDecorator(
            decoration: const InputDecoration(
              labelText: 'Échéance du crédit',
              border: OutlineInputBorder(),
              suffixIcon: Icon(Icons.event),
            ),
            child: Text(DateFormat('dd/MM/yyyy').format(d)),
          ),
        ),
      );
    }
    return const SizedBox.shrink();
  }
}
