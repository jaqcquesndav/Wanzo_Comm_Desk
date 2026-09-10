import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:wanzo/core/models/operation_payment.dart';
import 'package:wanzo/core/utils/currency_formatter.dart';

/// Dialogue « Enregistrer un paiement » commun aux créances clients et aux
/// dettes fournisseurs.
///
/// Le montant est pré-rempli au reste à payer et ne peut pas le dépasser. Le
/// mode de règlement, la date et la référence (optionnelle) accompagnent la
/// tranche pour que le journal reste traçable.
///
/// Renvoie `null` si l'utilisateur annule.
Future<PaymentDraft?> showRecordPaymentDialog(
  BuildContext context, {
  required double remainingAmount,
  required String currencyCode,
  double? exchangeRate,
  String title = 'Enregistrer un paiement',
  String? defaultMethod,
}) {
  return showDialog<PaymentDraft>(
    context: context,
    barrierDismissible: false,
    builder: (dialogContext) => _RecordPaymentDialog(
      remainingAmount: remainingAmount,
      currencyCode: currencyCode,
      exchangeRate: exchangeRate,
      title: title,
      defaultMethod: defaultMethod,
    ),
  );
}

class _RecordPaymentDialog extends StatefulWidget {
  final double remainingAmount;
  final String currencyCode;
  final double? exchangeRate;
  final String title;
  final String? defaultMethod;

  const _RecordPaymentDialog({
    required this.remainingAmount,
    required this.currencyCode,
    required this.title,
    this.exchangeRate,
    this.defaultMethod,
  });

  @override
  State<_RecordPaymentDialog> createState() => _RecordPaymentDialogState();
}

class _RecordPaymentDialogState extends State<_RecordPaymentDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _amountController;
  late final TextEditingController _referenceController;
  late String _method;
  late DateTime _paidAt;

  @override
  void initState() {
    super.initState();
    // Pré-remplissage au reste à payer : le cas le plus fréquent est le solde
    // complet, l'utilisateur n'a plus qu'à réduire pour une tranche.
    final initial = widget.remainingAmount > 0 ? widget.remainingAmount : 0.0;
    _amountController = TextEditingController(
      text: initial > 0 ? _formatPlain(initial) : '',
    );
    _referenceController = TextEditingController();
    final proposed = widget.defaultMethod;
    _method =
        (proposed != null && kPaymentMethodOptions.contains(proposed))
            ? proposed
            : kPaymentMethodOptions.first;
    _paidAt = DateTime.now();
  }

  @override
  void dispose() {
    _amountController.dispose();
    _referenceController.dispose();
    super.dispose();
  }

  String _formatPlain(double value) {
    // Saisie numérique brute (pas de séparateur de milliers) pour que le champ
    // reste parsable quelle que soit la locale du clavier.
    if (value == value.roundToDouble()) return value.toStringAsFixed(0);
    return value.toStringAsFixed(2);
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _paidAt,
      firstDate: DateTime(now.year - 5),
      lastDate: now,
      helpText: 'Date du règlement',
    );
    if (picked != null && mounted) {
      setState(() {
        _paidAt = DateTime(
          picked.year,
          picked.month,
          picked.day,
          _paidAt.hour,
          _paidAt.minute,
        );
      });
    }
  }

  void _submit() {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final amount = double.parse(_amountController.text.replaceAll(',', '.'));
    Navigator.of(context).pop(
      PaymentDraft(
        amount: amount,
        currencyCode: widget.currencyCode,
        exchangeRate: widget.exchangeRate,
        method: _method,
        paidAt: _paidAt,
        reference: _referenceController.text,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final remainingLabel = formatCurrency(
      widget.remainingAmount,
      widget.currencyCode,
    );

    return AlertDialog(
      title: Text(widget.title),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Reste à payer : $remainingLabel',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.error,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _amountController,
                autofocus: true,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: InputDecoration(
                  labelText: 'Montant',
                  prefixText: '${widget.currencyCode} ',
                  border: const OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Saisissez le montant du règlement';
                  }
                  final parsed = double.tryParse(
                    value.trim().replaceAll(',', '.'),
                  );
                  if (parsed == null || parsed <= 0) return 'Montant invalide';
                  // Tolérance d'arrondi d'un centième pour ne pas bloquer le
                  // solde complet à cause d'une décimale.
                  if (parsed > widget.remainingAmount + 0.01) {
                    return 'Le montant dépasse le reste à payer ($remainingLabel)';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: _method,
                decoration: const InputDecoration(
                  labelText: 'Mode de paiement',
                  border: OutlineInputBorder(),
                ),
                items: [
                  for (final option in kPaymentMethodOptions)
                    DropdownMenuItem(value: option, child: Text(option)),
                ],
                onChanged: (value) {
                  if (value != null) setState(() => _method = value);
                },
              ),
              const SizedBox(height: 12),
              InkWell(
                onTap: _pickDate,
                borderRadius: BorderRadius.circular(4),
                child: InputDecorator(
                  decoration: const InputDecoration(
                    labelText: 'Date du règlement',
                    border: OutlineInputBorder(),
                    suffixIcon: Icon(Icons.calendar_today, size: 18),
                  ),
                  child: Text(DateFormat('dd/MM/yyyy').format(_paidAt)),
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _referenceController,
                textCapitalization: TextCapitalization.characters,
                decoration: const InputDecoration(
                  labelText: 'Référence (optionnelle)',
                  hintText: 'Numéro de bordereau, transaction mobile...',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Annuler'),
        ),
        ElevatedButton.icon(
          onPressed: _submit,
          icon: const Icon(Icons.check, size: 18),
          label: const Text('Enregistrer'),
        ),
      ],
    );
  }
}
