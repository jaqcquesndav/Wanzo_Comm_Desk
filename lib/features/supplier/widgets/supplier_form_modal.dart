import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:wanzo/l10n/app_localizations.dart';
import 'package:wanzo/core/widgets/desktop/adaptive_modal.dart';
import 'package:wanzo/core/widgets/desktop/form_layout_widgets.dart';
import '../bloc/supplier_bloc.dart';
import '../bloc/supplier_event.dart';
import '../bloc/supplier_state.dart';
import '../models/supplier.dart';

/// Modal pour ajouter ou modifier un fournisseur
/// Utilise AdaptiveModal pour une présentation professionnelle desktop
class SupplierFormModal extends StatefulWidget {
  /// Fournisseur à modifier (null pour un nouveau fournisseur)
  final Supplier? supplier;

  /// Callback appelé après succès
  final VoidCallback? onSuccess;

  const SupplierFormModal({super.key, this.supplier, this.onSuccess});

  /// Affiche la modal de formulaire fournisseur
  static Future<bool?> show(
    BuildContext context, {
    Supplier? supplier,
    VoidCallback? onSuccess,
  }) {
    return AdaptiveModal.show<bool>(
      context: context,
      title:
          supplier != null
              ? AppLocalizations.of(context)!.editSupplierTitle
              : AppLocalizations.of(context)!.addSupplierTitle,
      subtitle:
          supplier != null
              ? 'Modifier les informations du fournisseur'
              : 'Créer un nouveau fournisseur',
      headerIcon: Icons.local_shipping,
      headerIconColor: Colors.teal,
      size: ModalSize.large, // Plus grand car plus de champs
      child: SupplierFormModal(supplier: supplier, onSuccess: onSuccess),
    );
  }

  @override
  State<SupplierFormModal> createState() => _SupplierFormModalState();
}

class _SupplierFormModalState extends State<SupplierFormModal> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _nameController;
  late final TextEditingController _phoneController;
  late final TextEditingController _emailController;
  late final TextEditingController _addressController;
  late final TextEditingController _contactPersonController;
  late final TextEditingController _notesController;
  late final TextEditingController _deliveryTimeController;
  late final TextEditingController _paymentTermsController;

  late SupplierCategory _selectedCategory;
  bool _isSubmitting = false;

  bool get _isEditing => widget.supplier != null;

  @override
  void initState() {
    super.initState();

    _nameController = TextEditingController(text: widget.supplier?.name ?? '');
    _phoneController = TextEditingController(
      text: widget.supplier?.phoneNumber ?? '',
    );
    _emailController = TextEditingController(
      text: widget.supplier?.email ?? '',
    );
    _addressController = TextEditingController(
      text: widget.supplier?.address ?? '',
    );
    _contactPersonController = TextEditingController(
      text: widget.supplier?.contactPerson ?? '',
    );
    _notesController = TextEditingController(
      text: widget.supplier?.notes ?? '',
    );
    _deliveryTimeController = TextEditingController(
      text: widget.supplier?.deliveryTimeInDays.toString() ?? '0',
    );
    _paymentTermsController = TextEditingController(
      text: widget.supplier?.paymentTerms ?? '',
    );

    _selectedCategory = widget.supplier?.category ?? SupplierCategory.regular;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _addressController.dispose();
    _contactPersonController.dispose();
    _notesController.dispose();
    _deliveryTimeController.dispose();
    _paymentTermsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;

    return BlocListener<SupplierBloc, SupplierState>(
      listener: (context, state) {
        if (state is SupplierOperationSuccess) {
          setState(() => _isSubmitting = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(state.message),
              backgroundColor: Colors.green,
            ),
          );
          widget.onSuccess?.call();
          Navigator.of(context).pop(true);
        } else if (state is SupplierError) {
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
              title: localizations.supplierInformation,
              description: 'Informations de contact du fournisseur',
              icon: Icons.business,
              iconColor: Colors.teal,
              child: FormGridLayout(
                desktopColumns: 2,
                children: [
                  // Nom
                  FormFieldContainer(
                    label: localizations.supplierNameLabel,
                    isRequired: true,
                    child: TextFormField(
                      controller: _nameController,
                      decoration: InputDecoration(
                        hintText: 'Ex: Fournisseur ABC',
                        prefixIcon: const Icon(Icons.business_outlined),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return localizations.supplierNameValidationError;
                        }
                        return null;
                      },
                    ),
                  ),

                  // Téléphone
                  FormFieldContainer(
                    label: localizations.supplierPhoneLabel,
                    isRequired: true,
                    child: TextFormField(
                      controller: _phoneController,
                      decoration: InputDecoration(
                        hintText: localizations.supplierPhoneHint,
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
                          return localizations.supplierPhoneValidationError;
                        }
                        return null;
                      },
                    ),
                  ),

                  // Email
                  FormFieldContainer(
                    label: localizations.supplierEmailLabel,
                    helpText: 'Optionnel',
                    child: TextFormField(
                      controller: _emailController,
                      decoration: InputDecoration(
                        hintText: 'fournisseur@example.com',
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
                            return localizations.supplierEmailValidationError;
                          }
                        }
                        return null;
                      },
                    ),
                  ),

                  // Personne de contact
                  FormFieldContainer(
                    label: localizations.supplierContactPersonLabel,
                    child: TextFormField(
                      controller: _contactPersonController,
                      decoration: InputDecoration(
                        hintText: 'Nom du contact',
                        prefixIcon: const Icon(Icons.person_outline),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ),

                  // Adresse (pleine largeur)
                  FormFieldContainer(
                    label: localizations.supplierAddressLabel,
                    child: TextFormField(
                      controller: _addressController,
                      decoration: InputDecoration(
                        hintText: 'Adresse complète du fournisseur',
                        prefixIcon: const Icon(Icons.location_on_outlined),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      maxLines: 2,
                    ),
                  ),

                  // Catégorie
                  FormFieldContainer(
                    label: localizations.supplierCategoryLabel,
                    isRequired: true,
                    child: DropdownButtonFormField<SupplierCategory>(
                      value: _selectedCategory,
                      decoration: InputDecoration(
                        prefixIcon: const Icon(Icons.category_outlined),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      items:
                          SupplierCategory.values.map((category) {
                            return DropdownMenuItem<SupplierCategory>(
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

            // Section Informations commerciales
            FormSection(
              title: localizations.commercialInformation,
              description: 'Délais et conditions',
              icon: Icons.receipt_long,
              iconColor: Colors.orange,
              child: FormGridLayout(
                desktopColumns: 2,
                children: [
                  // Délai de livraison
                  FormFieldContainer(
                    label: localizations.deliveryTimeLabel,
                    helpText: 'En jours ouvrés',
                    child: TextFormField(
                      controller: _deliveryTimeController,
                      decoration: InputDecoration(
                        hintText: '0',
                        prefixIcon: const Icon(Icons.timer_outlined),
                        suffixText: 'jours',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    ),
                  ),

                  // Conditions de paiement
                  FormFieldContainer(
                    label: localizations.paymentTermsLabel,
                    helpText: localizations.paymentTermsHint,
                    child: TextFormField(
                      controller: _paymentTermsController,
                      decoration: InputDecoration(
                        hintText: 'Ex: Net 30',
                        prefixIcon: const Icon(Icons.payment_outlined),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // Section Notes
            FormSection(
              title: 'Notes',
              icon: Icons.note_outlined,
              iconColor: Colors.grey,
              showHeaderDivider: false,
              child: FormFieldContainer(
                label: localizations.supplierNotesLabel,
                child: TextFormField(
                  controller: _notesController,
                  decoration: InputDecoration(
                    hintText: 'Notes ou remarques sur ce fournisseur...',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    alignLabelWithHint: true,
                  ),
                  maxLines: 3,
                ),
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
              onConfirm: _saveSupplier,
            ),
          ],
        ),
      ),
    );
  }

  void _saveSupplier() {
    if (_formKey.currentState?.validate() ?? false) {
      setState(() => _isSubmitting = true);

      final supplier = Supplier(
        id: widget.supplier?.id ?? '',
        name: _nameController.text.trim(),
        phoneNumber: _phoneController.text.trim(),
        email: _emailController.text.trim(),
        address: _addressController.text.trim(),
        contactPerson: _contactPersonController.text.trim(),
        createdAt: widget.supplier?.createdAt ?? DateTime.now(),
        notes: _notesController.text.trim(),
        totalPurchases: widget.supplier?.totalPurchases ?? 0.0,
        lastPurchaseDate: widget.supplier?.lastPurchaseDate,
        category: _selectedCategory,
        deliveryTimeInDays: int.tryParse(_deliveryTimeController.text) ?? 0,
        paymentTerms: _paymentTermsController.text.trim(),
      );

      if (_isEditing) {
        context.read<SupplierBloc>().add(UpdateSupplier(supplier));
      } else {
        context.read<SupplierBloc>().add(AddSupplier(supplier));
      }
    }
  }

  Color _getCategoryColor(SupplierCategory category) {
    switch (category) {
      case SupplierCategory.strategic:
        return Colors.purple;
      case SupplierCategory.regular:
        return Colors.blue;
      case SupplierCategory.newSupplier:
        return Colors.green;
      case SupplierCategory.occasional:
        return Colors.orange;
      case SupplierCategory.international:
        return Colors.indigo;
      case SupplierCategory.local:
        return Colors.teal;
      case SupplierCategory.online:
        return Colors.cyan;
    }
  }

  String _getCategoryName(BuildContext context, SupplierCategory category) {
    final localizations = AppLocalizations.of(context)!;
    switch (category) {
      case SupplierCategory.strategic:
        return localizations.supplierCategoryStrategic;
      case SupplierCategory.regular:
        return localizations.supplierCategoryRegular;
      case SupplierCategory.newSupplier:
        return localizations.supplierCategoryNew;
      case SupplierCategory.occasional:
        return localizations.supplierCategoryOccasional;
      case SupplierCategory.international:
        return localizations.supplierCategoryInternational;
      case SupplierCategory.local:
        return localizations.supplierCategoryLocal;
      case SupplierCategory.online:
        return localizations.supplierCategoryOnline;
    }
  }
}
