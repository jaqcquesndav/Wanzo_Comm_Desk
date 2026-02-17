import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:uuid/uuid.dart';
import 'package:wanzo/core/widgets/desktop/adaptive_modal.dart';
import 'package:wanzo/core/widgets/desktop/form_layout_widgets.dart';
import '../bloc/expense_bloc.dart';
import '../models/expense.dart';

/// Modal pour ajouter une dépense
/// Utilise AdaptiveModal pour une présentation professionnelle desktop
class ExpenseFormModal extends StatefulWidget {
  final VoidCallback? onSuccess;

  const ExpenseFormModal({super.key, this.onSuccess});

  /// Affiche la modal de formulaire dépense
  static Future<bool?> show(BuildContext context, {VoidCallback? onSuccess}) {
    return AdaptiveModal.show<bool>(
      context: context,
      title: 'Nouvelle dépense',
      subtitle: 'Enregistrer une sortie de fonds',
      headerIcon: Icons.remove_circle_outline,
      headerIconColor: Colors.red,
      size: ModalSize.large,
      child: ExpenseFormModal(onSuccess: onSuccess),
    );
  }

  @override
  State<ExpenseFormModal> createState() => _ExpenseFormModalState();
}

class _ExpenseFormModalState extends State<ExpenseFormModal> {
  final _formKey = GlobalKey<FormState>();

  final _motifController = TextEditingController();
  final _amountController = TextEditingController();
  final _paidAmountController = TextEditingController();
  final _beneficiaryController = TextEditingController();
  final _notesController = TextEditingController();

  ExpenseCategory _selectedCategory = ExpenseCategory.other;
  String? _selectedPaymentMethod;
  ExpensePaymentStatus _paymentStatus = ExpensePaymentStatus.paid;
  DateTime _selectedDate = DateTime.now();
  bool _isSubmitting = false;

  static const List<String> _paymentMethods = [
    'Espèce',
    'Mobile Money',
    'Carte Bancaire',
    'Chèque',
    'Virement',
    'Crédit',
  ];

  @override
  void dispose() {
    _motifController.dispose();
    _amountController.dispose();
    _paidAmountController.dispose();
    _beneficiaryController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<ExpenseBloc, ExpenseState>(
      listener: (context, state) {
        if (state is ExpenseOperationSuccess) {
          widget.onSuccess?.call();
          Navigator.of(context).pop(true);
        } else if (state is ExpenseError) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Erreur: ${state.message}'),
              backgroundColor: Colors.red,
            ),
          );
          setState(() => _isSubmitting = false);
        }
      },
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Section: Informations principales
            FormSection(
              title: 'Informations principales',
              description: 'Catégorie, description et montant',
              icon: Icons.info_outline,
              iconColor: Colors.red,
              child: FormGridLayout(
                desktopColumns: 2,
                children: [
                  // Catégorie
                  FormFieldContainer(
                    label: 'Catégorie',
                    isRequired: true,
                    child: DropdownButtonFormField<ExpenseCategory>(
                      value: _selectedCategory,
                      decoration: InputDecoration(
                        prefixIcon: const Icon(Icons.category),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      items:
                          ExpenseCategory.values.map((cat) {
                            return DropdownMenuItem(
                              value: cat,
                              child: Text(cat.displayName),
                            );
                          }).toList(),
                      onChanged: (value) {
                        if (value != null) {
                          setState(() => _selectedCategory = value);
                        }
                      },
                    ),
                  ),

                  // Date
                  FormFieldContainer(
                    label: 'Date',
                    isRequired: true,
                    child: InkWell(
                      onTap: _pickDate,
                      child: InputDecorator(
                        decoration: InputDecoration(
                          prefixIcon: const Icon(Icons.calendar_today),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: Text(
                          '${_selectedDate.day.toString().padLeft(2, '0')}/${_selectedDate.month.toString().padLeft(2, '0')}/${_selectedDate.year}',
                        ),
                      ),
                    ),
                  ),

                  // Motif
                  FormFieldContainer(
                    label: 'Motif / Description',
                    isRequired: true,
                    child: TextFormField(
                      controller: _motifController,
                      decoration: InputDecoration(
                        hintText: 'Ex: Achat fournitures bureau',
                        prefixIcon: const Icon(Icons.description),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Le motif est requis';
                        }
                        return null;
                      },
                    ),
                  ),

                  // Montant
                  FormFieldContainer(
                    label: 'Montant (CDF)',
                    isRequired: true,
                    child: TextFormField(
                      controller: _amountController,
                      decoration: InputDecoration(
                        prefixIcon: const Icon(Icons.attach_money),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                      ],
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Le montant est requis';
                        }
                        final amount = double.tryParse(value);
                        if (amount == null || amount <= 0) {
                          return 'Montant invalide';
                        }
                        return null;
                      },
                    ),
                  ),

                  // Méthode de paiement
                  FormFieldContainer(
                    label: 'Moyen de paiement',
                    child: DropdownButtonFormField<String>(
                      value: _selectedPaymentMethod,
                      decoration: InputDecoration(
                        prefixIcon: const Icon(Icons.payment),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      items:
                          _paymentMethods.map((method) {
                            return DropdownMenuItem(
                              value: method,
                              child: Text(method),
                            );
                          }).toList(),
                      onChanged: (value) {
                        setState(() => _selectedPaymentMethod = value);
                      },
                    ),
                  ),

                  // Statut de décaissement
                  FormFieldContainer(
                    label: 'Statut de décaissement',
                    child: DropdownButtonFormField<ExpensePaymentStatus>(
                      value: _paymentStatus,
                      decoration: InputDecoration(
                        prefixIcon: const Icon(Icons.receipt_long),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      items:
                          ExpensePaymentStatus.values.map((status) {
                            return DropdownMenuItem(
                              value: status,
                              child: Text(status.displayName),
                            );
                          }).toList(),
                      onChanged: (value) {
                        if (value != null) {
                          setState(() => _paymentStatus = value);
                        }
                      },
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // Montant payé (conditionnel)
            if (_paymentStatus == ExpensePaymentStatus.partial) ...[
              FormSection(
                title: 'Paiement partiel',
                icon: Icons.money,
                iconColor: Colors.orange,
                child: FormFieldContainer(
                  label: 'Montant payé (CDF)',
                  child: TextFormField(
                    controller: _paidAmountController,
                    decoration: InputDecoration(
                      prefixIcon: const Icon(Icons.money),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
            ],

            // Section: Informations complémentaires
            FormSection(
              title: 'Informations complémentaires',
              description: 'Bénéficiaire et notes',
              icon: Icons.note_add,
              iconColor: Colors.grey,
              child: FormGridLayout(
                desktopColumns: 2,
                children: [
                  FormFieldContainer(
                    label: 'Bénéficiaire',
                    helpText: 'Optionnel',
                    child: TextFormField(
                      controller: _beneficiaryController,
                      decoration: InputDecoration(
                        hintText: 'Nom du bénéficiaire',
                        prefixIcon: const Icon(Icons.person_outline),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ),
                  FormFieldContainer(
                    label: 'Notes',
                    helpText: 'Optionnel',
                    child: TextFormField(
                      controller: _notesController,
                      decoration: InputDecoration(
                        hintText: 'Remarques ou détails additionnels...',
                        prefixIcon: const Icon(Icons.note),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      maxLines: 3,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Footer avec boutons
            ModalFormFooter(
              onCancel: () => Navigator.of(context).pop(false),
              onConfirm: _submitForm,
              confirmText: 'Enregistrer la dépense',
              confirmIcon: Icons.save,
              isLoading: _isSubmitting,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 30)),
    );
    if (picked != null) {
      setState(() => _selectedDate = picked);
    }
  }

  void _submitForm() {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);

    final amount = double.parse(_amountController.text);
    final paidAmount =
        _paymentStatus == ExpensePaymentStatus.paid
            ? amount
            : _paymentStatus == ExpensePaymentStatus.partial
            ? double.tryParse(_paidAmountController.text) ?? 0.0
            : 0.0;

    final expense = Expense(
      id: const Uuid().v4(),
      date: _selectedDate,
      motif: _motifController.text.trim(),
      amount: amount,
      category: _selectedCategory,
      paymentMethod: _selectedPaymentMethod,
      currencyCode: 'CDF',
      notes:
          _notesController.text.trim().isNotEmpty
              ? _notesController.text.trim()
              : null,
      beneficiary:
          _beneficiaryController.text.trim().isNotEmpty
              ? _beneficiaryController.text.trim()
              : null,
      paidAmount: paidAmount,
      paymentStatus: _paymentStatus,
    );

    context.read<ExpenseBloc>().add(AddExpense(expense));
  }
}
