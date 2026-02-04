import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:wanzo/l10n/app_localizations.dart'; // Import AppLocalizations
import '../bloc/supplier_bloc.dart';
import '../bloc/supplier_event.dart';
import '../bloc/supplier_state.dart';
import '../models/supplier.dart';

/// Écran pour ajouter ou modifier un fournisseur
class AddSupplierScreen extends StatefulWidget {
  /// Fournisseur à modifier (null pour un nouveau fournisseur)
  final Supplier? supplier;

  const AddSupplierScreen({super.key, this.supplier});

  @override
  State<AddSupplierScreen> createState() => _AddSupplierScreenState();
}

class _AddSupplierScreenState extends State<AddSupplierScreen> {
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
  
  bool get _isEditing => widget.supplier != null;

  @override
  void initState() {
    super.initState();
    
    // Initialise les contrôleurs avec les valeurs du fournisseur si on est en mode édition
    _nameController = TextEditingController(text: widget.supplier?.name ?? '');
    _phoneController = TextEditingController(text: widget.supplier?.phoneNumber ?? '');
    _emailController = TextEditingController(text: widget.supplier?.email ?? '');
    _addressController = TextEditingController(text: widget.supplier?.address ?? '');
    _contactPersonController = TextEditingController(text: widget.supplier?.contactPerson ?? '');
    _notesController = TextEditingController(text: widget.supplier?.notes ?? '');
    _deliveryTimeController = TextEditingController(
      text: widget.supplier?.deliveryTimeInDays.toString() ?? '0'
    );
    _paymentTermsController = TextEditingController(text: widget.supplier?.paymentTerms ?? '');
    
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
    final localizations = AppLocalizations.of(context)!; // Add localizations instance

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? localizations.editSupplierTitle : localizations.addSupplierTitle), // Localized
      ),
      body: BlocListener<SupplierBloc, SupplierState>(
        listener: (context, state) {
          if (state is SupplierOperationSuccess) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(state.message)),
            );
            context.pop();
          } else if (state is SupplierError) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.message),
                backgroundColor: Colors.red,
              ),
            );
          }
        },
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Informations principales
                Text(
                  localizations.supplierInformation, // Localized
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                
                // Nom du fournisseur
                TextFormField(
                  controller: _nameController,
                  decoration: InputDecoration(
                    labelText: localizations.supplierNameLabel, // Localized
                    border: const OutlineInputBorder(),
                    prefixIcon: const Icon(Icons.business),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return localizations.supplierNameValidationError; // Localized
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                
                // Numéro de téléphone
                TextFormField(
                  controller: _phoneController,
                  decoration: InputDecoration(
                    labelText: localizations.supplierPhoneLabel, // Localized
                    border: const OutlineInputBorder(),
                    prefixIcon: const Icon(Icons.phone),
                    hintText: localizations.supplierPhoneHint, // Localized
                  ),
                  keyboardType: TextInputType.phone,
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[0-9+\s-]')),
                  ],
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return localizations.supplierPhoneValidationError; // Localized
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                
                // Email
                TextFormField(
                  controller: _emailController,
                  decoration: InputDecoration(
                    labelText: localizations.supplierEmailLabel, // Localized
                    border: const OutlineInputBorder(),
                    prefixIcon: const Icon(Icons.email),
                  ),
                  keyboardType: TextInputType.emailAddress,
                  validator: (value) {
                    if (value != null && value.isNotEmpty) {
                      final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
                      if (!emailRegex.hasMatch(value)) {
                        return localizations.supplierEmailValidationError; // Localized
                      }
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                
                // Personne à contacter
                TextFormField(
                  controller: _contactPersonController,
                  decoration: InputDecoration(
                    labelText: localizations.supplierContactPersonLabel, // Localized
                    border: const OutlineInputBorder(),
                    prefixIcon: const Icon(Icons.person),
                  ),
                ),
                const SizedBox(height: 16),
                
                // Adresse
                TextFormField(
                  controller: _addressController,
                  decoration: InputDecoration(
                    labelText: localizations.supplierAddressLabel, // Localized
                    border: const OutlineInputBorder(),
                    prefixIcon: const Icon(Icons.location_on),
                  ),
                  maxLines: 2,
                ),
                const SizedBox(height: 16),
                
                // Informations commerciales
                Text(
                  localizations.commercialInformation, // Localized
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                
                // Délai de livraison
                TextFormField(
                  controller: _deliveryTimeController,
                  decoration: InputDecoration(
                    labelText: localizations.deliveryTimeLabel, // Localized
                    border: const OutlineInputBorder(),
                    prefixIcon: const Icon(Icons.timer),
                  ),
                  keyboardType: TextInputType.number,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                  ],
                ),
                const SizedBox(height: 16),
                
                // Conditions de paiement
                TextFormField(
                  controller: _paymentTermsController,
                  decoration: InputDecoration(
                    labelText: localizations.paymentTermsLabel, // Localized
                    border: const OutlineInputBorder(),
                    prefixIcon: const Icon(Icons.payment),
                    hintText: localizations.paymentTermsHint, // Localized
                  ),
                ),
                const SizedBox(height: 16),
                
                // Catégorie de fournisseur
                Text(
                  localizations.supplierCategoryLabel, // Localized
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<SupplierCategory>(
                      isExpanded: true,
                      value: _selectedCategory,
                      items: SupplierCategory.values.map((category) {
                        return DropdownMenuItem<SupplierCategory>(
                          value: category,
                          child: Row(
                            children: [
                              Container(
                                width: 16,
                                height: 16,
                                decoration: BoxDecoration(
                                  color: _getCategoryColor(category),
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(_getCategoryName(context, category)), // Pass context
                            ],
                          ),
                        );
                      }).toList(),
                      onChanged: (value) {
                        if (value != null) {
                          setState(() {
                            _selectedCategory = value;
                          });
                        }
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                
                // Notes
                TextFormField(
                  controller: _notesController,
                  decoration: InputDecoration(
                    labelText: localizations.supplierNotesLabel, // Localized
                    border: const OutlineInputBorder(),
                    prefixIcon: const Icon(Icons.note),
                  ),
                  maxLines: 3,
                ),
                const SizedBox(height: 24),
                
                // Bouton de sauvegarde
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: _saveSupplier,
                    child: Text(_isEditing ? localizations.updateSupplierButton : localizations.addSupplierButton), // Localized
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Sauvegarde le fournisseur (ajout ou mise à jour)
  void _saveSupplier() {
    if (_formKey.currentState?.validate() ?? false) {
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

  /// Retourne la couleur associée à une catégorie de fournisseur
  Color _getCategoryColor(SupplierCategory category) {
    switch (category) {      
      case SupplierCategory.strategic:
        return Colors.indigo;
      case SupplierCategory.regular:
        return Colors.blue;
      case SupplierCategory.newSupplier:
        return Colors.green;
      case SupplierCategory.occasional:
        return Colors.orange;
      case SupplierCategory.international:
        return Colors.purple;
      case SupplierCategory.local:
        return Colors.teal;
      case SupplierCategory.online: // Add case for online
        return Colors.cyan; // Or any color you prefer
    }
  }

  /// Retourne le nom d'une catégorie de fournisseur
  String _getCategoryName(BuildContext context, SupplierCategory category) { // Add context
    final localizations = AppLocalizations.of(context)!; // Add localizations instance
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
      case SupplierCategory.online: // Add case for online
        return localizations.supplierCategoryOnline;
    }
  }
}
