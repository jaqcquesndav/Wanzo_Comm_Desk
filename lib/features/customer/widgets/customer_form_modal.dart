import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:wanzo/l10n/app_localizations.dart';
import 'package:wanzo/core/widgets/desktop/adaptive_modal.dart';
import 'package:wanzo/core/widgets/desktop/form_layout_widgets.dart';
import '../bloc/customer_bloc.dart';
import '../bloc/customer_event.dart';
import '../bloc/customer_state.dart';
import '../models/customer.dart';

/// Modal pour ajouter ou modifier un client
/// Utilise AdaptiveModal pour une présentation professionnelle desktop
class CustomerFormModal extends StatefulWidget {
  /// Client à modifier (null pour un nouveau client)
  final Customer? customer;

  /// Callback appelé après succès
  final VoidCallback? onSuccess;

  const CustomerFormModal({super.key, this.customer, this.onSuccess});

  /// Affiche la modal de formulaire client
  static Future<bool?> show(
    BuildContext context, {
    Customer? customer,
    VoidCallback? onSuccess,
  }) {
    return AdaptiveModal.show<bool>(
      context: context,
      title:
          customer != null
              ? AppLocalizations.of(context)!.editCustomerTitle
              : AppLocalizations.of(context)!.addCustomerTitle,
      subtitle:
          customer != null
              ? 'Modifier les informations du client'
              : 'Créer un nouveau client',
      headerIcon: Icons.person_add,
      headerIconColor: Colors.blue,
      size: ModalSize.medium,
      child: CustomerFormModal(customer: customer, onSuccess: onSuccess),
    );
  }

  @override
  State<CustomerFormModal> createState() => _CustomerFormModalState();
}

class _CustomerFormModalState extends State<CustomerFormModal> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _nameController;
  late final TextEditingController _phoneController;
  late final TextEditingController _emailController;
  late final TextEditingController _addressController;
  late final TextEditingController _notesController;

  late CustomerCategory _selectedCategory;
  bool _isSubmitting = false;

  bool get _isEditing => widget.customer != null;

  @override
  void initState() {
    super.initState();

    _nameController = TextEditingController(text: widget.customer?.name ?? '');
    _phoneController = TextEditingController(
      text: widget.customer?.phoneNumber ?? '',
    );
    _emailController = TextEditingController(
      text: widget.customer?.email ?? '',
    );
    _addressController = TextEditingController(
      text: widget.customer?.address ?? '',
    );
    _notesController = TextEditingController(
      text: widget.customer?.notes ?? '',
    );

    _selectedCategory = widget.customer?.category ?? CustomerCategory.regular;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _addressController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;

    return BlocListener<CustomerBloc, CustomerState>(
      listener: (context, state) {
        if (state is CustomerOperationSuccess) {
          setState(() => _isSubmitting = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(state.message),
              backgroundColor: Colors.green,
            ),
          );
          widget.onSuccess?.call();
          Navigator.of(context).pop(true);
        } else if (state is CustomerError) {
          setState(() => _isSubmitting = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(state.message), backgroundColor: Colors.red),
          );
        }
      },
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Section Informations principales
            FormSection(
              title: localizations.customerInformation,
              description: 'Informations de base du client',
              icon: Icons.badge,
              iconColor: Colors.blue,
              child: FormGridLayout(
                desktopColumns: 2,
                children: [
                  // Nom
                  FormFieldContainer(
                    label: localizations.customerNameLabel,
                    isRequired: true,
                    child: TextFormField(
                      controller: _nameController,
                      decoration: InputDecoration(
                        hintText: 'Ex: Jean Dupont',
                        prefixIcon: const Icon(Icons.person_outline),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return localizations.customerNameValidationError;
                        }
                        return null;
                      },
                    ),
                  ),

                  // Téléphone
                  FormFieldContainer(
                    label: localizations.customerPhoneLabel,
                    isRequired: true,
                    child: TextFormField(
                      controller: _phoneController,
                      decoration: InputDecoration(
                        hintText: localizations.customerPhoneHint,
                        prefixIcon: const Icon(Icons.phone_outlined),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      keyboardType: TextInputType.phone,
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp(r'[0-9+\s-]')),
                      ],
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return localizations.customerPhoneValidationError;
                        }
                        return null;
                      },
                    ),
                  ),

                  // Email
                  FormFieldContainer(
                    label: localizations.customerEmailLabel,
                    helpText: 'Optionnel',
                    child: TextFormField(
                      controller: _emailController,
                      decoration: InputDecoration(
                        hintText: 'client@example.com',
                        prefixIcon: const Icon(Icons.email_outlined),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      keyboardType: TextInputType.emailAddress,
                      validator: (value) {
                        if (value != null && value.isNotEmpty) {
                          final emailRegex = RegExp(
                            r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$',
                          );
                          if (!emailRegex.hasMatch(value)) {
                            return localizations.customerEmailValidationError;
                          }
                        }
                        return null;
                      },
                    ),
                  ),

                  // Catégorie
                  FormFieldContainer(
                    label: localizations.customerCategoryLabel,
                    isRequired: true,
                    child: DropdownButtonFormField<CustomerCategory>(
                      value: _selectedCategory,
                      decoration: InputDecoration(
                        prefixIcon: const Icon(Icons.category_outlined),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      items:
                          CustomerCategory.values.map((category) {
                            return DropdownMenuItem<CustomerCategory>(
                              value: category,
                              child: Row(
                                children: [
                                  Container(
                                    width: 12,
                                    height: 12,
                                    decoration: BoxDecoration(
                                      color: _getCategoryColor(category),
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Text(_getCategoryName(context, category)),
                                ],
                              ),
                            );
                          }).toList(),
                      onChanged: (value) {
                        if (value != null) {
                          setState(() => _selectedCategory = value);
                        }
                      },
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // Section Adresse et notes
            FormSection(
              title: 'Informations complémentaires',
              description: 'Adresse et notes',
              icon: Icons.info_outline,
              iconColor: Colors.grey,
              child: Column(
                children: [
                  // Adresse
                  FormFieldContainer(
                    label: localizations.customerAddressLabel,
                    child: TextFormField(
                      controller: _addressController,
                      decoration: InputDecoration(
                        hintText: 'Adresse complète du client',
                        prefixIcon: const Icon(Icons.location_on_outlined),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      maxLines: 2,
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Notes
                  FormFieldContainer(
                    label: localizations.customerNotesLabel,
                    child: TextFormField(
                      controller: _notesController,
                      decoration: InputDecoration(
                        hintText: 'Notes ou remarques sur ce client...',
                        prefixIcon: const Icon(Icons.note_outlined),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        alignLabelWithHint: true,
                      ),
                      maxLines: 3,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Boutons d'action
            ModalFormFooter(
              cancelText: 'Annuler',
              confirmText:
                  _isEditing
                      ? localizations.updateButtonLabel
                      : localizations.addButtonLabel,
              confirmIcon: _isEditing ? Icons.save : Icons.add,
              isLoading: _isSubmitting,
              isConfirmEnabled: !_isSubmitting,
              onCancel: () => Navigator.of(context).pop(false),
              onConfirm: _saveCustomer,
            ),
          ],
        ),
      ),
    );
  }

  void _saveCustomer() {
    if (_formKey.currentState?.validate() ?? false) {
      setState(() => _isSubmitting = true);

      final customer = Customer(
        id: widget.customer?.id ?? '',
        name: _nameController.text.trim(),
        phoneNumber: _phoneController.text.trim(),
        email: _emailController.text.trim(),
        address: _addressController.text.trim(),
        createdAt: widget.customer?.createdAt ?? DateTime.now(),
        notes: _notesController.text.trim(),
        totalPurchases: widget.customer?.totalPurchases ?? 0.0,
        lastPurchaseDate: widget.customer?.lastPurchaseDate,
        category: _selectedCategory,
      );

      if (_isEditing) {
        context.read<CustomerBloc>().add(UpdateCustomer(customer));
      } else {
        context.read<CustomerBloc>().add(AddCustomer(customer));
      }
    }
  }

  Color _getCategoryColor(CustomerCategory category) {
    switch (category) {
      case CustomerCategory.vip:
        return Colors.purple;
      case CustomerCategory.regular:
        return Colors.blue;
      case CustomerCategory.new_customer:
        return Colors.green;
      case CustomerCategory.occasional:
        return Colors.orange;
      case CustomerCategory.business:
        return Colors.indigo;
    }
  }

  String _getCategoryName(BuildContext context, CustomerCategory category) {
    final localizations = AppLocalizations.of(context)!;
    switch (category) {
      case CustomerCategory.vip:
        return localizations.customerCategoryVip;
      case CustomerCategory.regular:
        return localizations.customerCategoryRegular;
      case CustomerCategory.new_customer:
        return localizations.customerCategoryNew;
      case CustomerCategory.occasional:
        return localizations.customerCategoryOccasional;
      case CustomerCategory.business:
        return localizations.customerCategoryBusiness;
    }
  }
}
