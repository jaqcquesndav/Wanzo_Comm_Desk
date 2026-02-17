import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:uuid/uuid.dart';
import 'package:wanzo/core/widgets/desktop/adaptive_modal.dart';
import 'package:wanzo/core/widgets/desktop/form_layout_widgets.dart';
import '../bloc/financing_bloc.dart';
import '../models/financing_request.dart';

/// Modal pour ajouter une demande de financement
/// Utilise AdaptiveModal pour une présentation professionnelle desktop
class FinancingFormModal extends StatefulWidget {
  final VoidCallback? onSuccess;

  const FinancingFormModal({super.key, this.onSuccess});

  /// Affiche la modal de formulaire financement
  static Future<bool?> show(BuildContext context, {VoidCallback? onSuccess}) {
    return AdaptiveModal.show<bool>(
      context: context,
      title: 'Nouvelle demande de financement',
      subtitle: 'Soumettre une demande de crédit ou financement',
      headerIcon: Icons.account_balance,
      headerIconColor: Colors.purple,
      size: ModalSize.large,
      child: FinancingFormModal(onSuccess: onSuccess),
    );
  }

  @override
  State<FinancingFormModal> createState() => _FinancingFormModalState();
}

class _FinancingFormModalState extends State<FinancingFormModal> {
  final _formKey = GlobalKey<FormState>();

  final _amountController = TextEditingController();
  final _reasonController = TextEditingController();
  final _durationController = TextEditingController(text: '6');

  FinancingType _selectedType = FinancingType.cashCredit;
  FinancialInstitution _selectedInstitution = FinancialInstitution.bonneMoisson;
  String _currency = 'USD';
  DateTime _proposedStartDate = DateTime.now().add(const Duration(days: 7));
  bool _isSubmitting = false;

  @override
  void dispose() {
    _amountController.dispose();
    _reasonController.dispose();
    _durationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<FinancingBloc, FinancingState>(
      listener: (context, state) {
        if (state is FinancingOperationSuccess) {
          widget.onSuccess?.call();
          Navigator.of(context).pop(true);
        } else if (state is FinancingError) {
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
            // Section: Type de financement
            FormSection(
              title: 'Type de financement',
              description: 'Choisissez le type et l\'institution',
              icon: Icons.category,
              iconColor: Colors.purple,
              child: FormGridLayout(
                desktopColumns: 2,
                children: [
                  // Type
                  FormFieldContainer(
                    label: 'Type',
                    isRequired: true,
                    child: DropdownButtonFormField<FinancingType>(
                      value: _selectedType,
                      decoration: InputDecoration(
                        prefixIcon: const Icon(Icons.type_specimen),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      items:
                          FinancingType.values.map((type) {
                            return DropdownMenuItem(
                              value: type,
                              child: Text(type.displayName),
                            );
                          }).toList(),
                      onChanged: (value) {
                        if (value != null) {
                          setState(() => _selectedType = value);
                        }
                      },
                    ),
                  ),

                  // Institution financière
                  FormFieldContainer(
                    label: 'Institution financière',
                    isRequired: true,
                    child: DropdownButtonFormField<FinancialInstitution>(
                      value: _selectedInstitution,
                      decoration: InputDecoration(
                        prefixIcon: const Icon(Icons.business),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      items:
                          FinancialInstitution.values.map((inst) {
                            return DropdownMenuItem(
                              value: inst,
                              child: Text(inst.displayName),
                            );
                          }).toList(),
                      onChanged: (value) {
                        if (value != null) {
                          setState(() => _selectedInstitution = value);
                        }
                      },
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // Section: Montant et conditions
            FormSection(
              title: 'Montant et conditions',
              description: 'Montant demandé et durée du financement',
              icon: Icons.attach_money,
              iconColor: Colors.green,
              child: FormGridLayout(
                desktopColumns: 2,
                children: [
                  // Montant demandé
                  FormFieldContainer(
                    label: 'Montant demandé',
                    isRequired: true,
                    child: TextFormField(
                      controller: _amountController,
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

                  // Devise
                  FormFieldContainer(
                    label: 'Devise',
                    child: DropdownButtonFormField<String>(
                      value: _currency,
                      decoration: InputDecoration(
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      items: const [
                        DropdownMenuItem(value: 'USD', child: Text('USD')),
                        DropdownMenuItem(value: 'CDF', child: Text('CDF')),
                        DropdownMenuItem(value: 'EUR', child: Text('EUR')),
                      ],
                      onChanged: (value) {
                        if (value != null) {
                          setState(() => _currency = value);
                        }
                      },
                    ),
                  ),

                  // Durée (mois)
                  FormFieldContainer(
                    label: 'Durée (mois)',
                    isRequired: true,
                    child: TextFormField(
                      controller: _durationController,
                      decoration: InputDecoration(
                        prefixIcon: const Icon(Icons.timer),
                        suffixText: 'mois',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'La durée est requise';
                        }
                        final duration = int.tryParse(value);
                        if (duration == null || duration <= 0) {
                          return 'Durée invalide';
                        }
                        return null;
                      },
                    ),
                  ),

                  // Date de début souhaitée
                  FormFieldContainer(
                    label: 'Date de début souhaitée',
                    child: InkWell(
                      onTap: _pickStartDate,
                      child: InputDecorator(
                        decoration: InputDecoration(
                          prefixIcon: const Icon(Icons.calendar_today),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: Text(
                          '${_proposedStartDate.day.toString().padLeft(2, '0')}/${_proposedStartDate.month.toString().padLeft(2, '0')}/${_proposedStartDate.year}',
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // Section: Justification
            FormSection(
              title: 'Justification',
              description: 'Décrivez le besoin de financement',
              icon: Icons.description,
              iconColor: Colors.blue,
              child: FormFieldContainer(
                label: 'Motif de la demande',
                isRequired: true,
                child: TextFormField(
                  controller: _reasonController,
                  decoration: InputDecoration(
                    hintText: 'Décrivez le besoin de financement...',
                    prefixIcon: const Icon(Icons.edit_note),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    alignLabelWithHint: true,
                  ),
                  maxLines: 4,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Le motif est requis';
                    }
                    return null;
                  },
                ),
              ),
            ),

            const SizedBox(height: 24),

            // Footer avec boutons
            ModalFormFooter(
              onCancel: () => Navigator.of(context).pop(false),
              onConfirm: _submitForm,
              confirmText: 'Soumettre la demande',
              confirmIcon: Icons.send,
              isLoading: _isSubmitting,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickStartDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _proposedStartDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) {
      setState(() => _proposedStartDate = picked);
    }
  }

  void _submitForm() {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);

    final request = FinancingRequest(
      id: const Uuid().v4(),
      amount: double.parse(_amountController.text),
      currency: _currency,
      reason: _reasonController.text.trim(),
      type: _selectedType,
      institution: _selectedInstitution,
      requestDate: DateTime.now(),
      status: 'pending',
      duration: int.parse(_durationController.text),
      durationUnit: 'months',
      proposedStartDate: _proposedStartDate,
    );

    context.read<FinancingBloc>().add(AddFinancingRequest(request));
  }
}
