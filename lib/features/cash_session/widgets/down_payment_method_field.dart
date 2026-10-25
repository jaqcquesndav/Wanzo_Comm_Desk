import 'package:flutter/material.dart';

import '../../../core/models/payment_method_code.dart';

/// Moyens possibles pour un acompte (jamais « crédit »).
const kDownPaymentMethods = [
  PaymentMethodCode.cash,
  PaymentMethodCode.mobileMoney,
  PaymentMethodCode.card,
  PaymentMethodCode.bankTransfer,
];

/// Choix du moyen de paiement d'un ACOMPTE (vente à crédit, avance d'une
/// commande atelier, pressing ou garage). Espèces par défaut : un acompte
/// payé en Mobile Money n'entre pas dans le tiroir de la caisse.
class DownPaymentMethodField extends StatelessWidget {
  const DownPaymentMethodField({
    super.key,
    required this.value,
    required this.onChanged,
    this.label = 'Acompte payé par',
  });

  final String value;
  final ValueChanged<String> onChanged;
  final String label;

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<String>(
      value: kDownPaymentMethods.contains(value) ? value : PaymentMethodCode.cash,
      isExpanded: true,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
      ),
      items: [
        for (final code in kDownPaymentMethods)
          DropdownMenuItem(
            value: code,
            child: Text(paymentMethodLabel(code), overflow: TextOverflow.ellipsis),
          ),
      ],
      onChanged: (v) {
        if (v != null) onChanged(v);
      },
    );
  }
}
