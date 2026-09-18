import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:uuid/uuid.dart';

import 'package:wanzo/core/enums/currency_enum.dart';
import 'package:wanzo/features/expenses/bloc/expense_bloc.dart';
import 'package:wanzo/features/expenses/models/expense.dart';

import '../models/stylist.dart';

/// Verser une AVANCE à un coiffeur.
///
/// Une avance est de l'argent qui sort de la caisse : c'est une dépense, pas
/// une écriture à part. Elle est simplement rattachée au coiffeur, pour venir
/// en déduction de ses commissions dans son relevé. Le formulaire reste court :
/// un montant, une date, un motif, parce que c'est un geste de comptoir.
Future<bool?> showAdvanceForm(BuildContext context, Stylist stylist) {
  return showDialog<bool>(
    context: context,
    builder: (_) => _AdvanceDialog(stylist: stylist),
  );
}

class _AdvanceDialog extends StatefulWidget {
  const _AdvanceDialog({required this.stylist});

  final Stylist stylist;

  @override
  State<_AdvanceDialog> createState() => _AdvanceDialogState();
}

class _AdvanceDialogState extends State<_AdvanceDialog> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _motifController = TextEditingController();
  DateTime _date = DateTime.now();
  Currency _currency = Currency.CDF;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _motifController.text = 'Avance ${widget.stylist.name}';
  }

  @override
  void dispose() {
    _amountController.dispose();
    _motifController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final d = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 1)),
      locale: const Locale('fr', 'FR'),
    );
    if (d != null) setState(() => _date = d);
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;
    final amount = double.tryParse(_amountController.text.trim()) ?? 0;
    if (amount <= 0) return;

    setState(() => _saving = true);
    final expense = Expense(
      id: const Uuid().v4(),
      date: _date,
      motif: _motifController.text.trim(),
      amount: amount,
      // Une avance relève de la masse salariale, précisée pour que les
      // rapports la distinguent d'une paie ou d'un journalier.
      category: ExpenseCategory.salaries,
      subCategory: 'Avance prestataire',
      performerId: widget.stylist.id,
      performerName: widget.stylist.name,
      beneficiary: widget.stylist.name,
      paymentMethod: 'cash',
      currencyCode: _currency.code,
      paidAmount: amount,
      paymentStatus: ExpensePaymentStatus.paid,
      attachmentUrls: const [],
    );
    context.read<ExpenseBloc>().add(AddExpense(expense));
    Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AlertDialog(
      title: Text('Avance à ${widget.stylist.name}'),
      content: SizedBox(
        width: 420,
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 3,
                    child: TextFormField(
                      controller: _amountController,
                      autofocus: true,
                      keyboardType: TextInputType.number,
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(
                            RegExp(r'^\d+\.?\d{0,2}')),
                      ],
                      decoration: InputDecoration(
                        labelText: 'Montant (${_currency.code}) *',
                        border: const OutlineInputBorder(),
                        prefixIcon: const Icon(Icons.payments_outlined),
                      ),
                      validator: (v) {
                        final a = double.tryParse((v ?? '').trim());
                        if (a == null || a <= 0) return 'Montant invalide';
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: DropdownButtonFormField<Currency>(
                      value: _currency,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'Devise',
                        border: OutlineInputBorder(),
                      ),
                      items: const [
                        DropdownMenuItem(
                            value: Currency.CDF, child: Text('CDF')),
                        DropdownMenuItem(
                            value: Currency.USD, child: Text('USD')),
                      ],
                      onChanged: (c) {
                        if (c != null) setState(() => _currency = c);
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _motifController,
                decoration: const InputDecoration(
                  labelText: 'Motif',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.notes_outlined),
                ),
              ),
              const SizedBox(height: 12),
              InkWell(
                onTap: _pickDate,
                child: InputDecorator(
                  decoration: const InputDecoration(
                    labelText: 'Date',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.event_outlined),
                  ),
                  child: Text(
                    '${_date.day.toString().padLeft(2, '0')}/'
                    '${_date.month.toString().padLeft(2, '0')}/${_date.year}',
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Text(
                "Enregistrée comme une dépense, et retranchée des commissions "
                "de ${widget.stylist.name} dans son relevé.",
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.pop(context, false),
          child: const Text('Annuler'),
        ),
        FilledButton.icon(
          onPressed: _saving ? null : _save,
          icon: const Icon(Icons.check),
          label: const Text('Verser'),
        ),
      ],
    );
  }
}
