import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:wanzo/l10n/app_localizations.dart'; // Import AppLocalizations
import '../bloc/customer_bloc.dart';
import '../bloc/customer_event.dart';
import '../bloc/customer_state.dart';
import '../models/customer.dart';

/// Écran pour ajouter ou modifier un client
class AddCustomerScreen extends StatefulWidget {
  /// Client à modifier (null pour un nouveau client)
  final Customer? customer;

  const AddCustomerScreen({super.key, this.customer});

  @override
  State<AddCustomerScreen> createState() => _AddCustomerScreenState();
}

class _AddCustomerScreenState extends State<AddCustomerScreen> {
  final _formKey = GlobalKey<FormState>();
  
  late final TextEditingController _nameController;
  late final TextEditingController _phoneController;
  late final TextEditingController _emailController;
  late final TextEditingController _addressController;
  late final TextEditingController _notesController;
  
  late CustomerCategory _selectedCategory;
  
  bool get _isEditing => widget.customer != null;

  @override
  void initState() {
    super.initState();
    
    // Initialise les contrôleurs avec les valeurs du client si on est en mode édition
    _nameController = TextEditingController(text: widget.customer?.name ?? '');
    _phoneController = TextEditingController(text: widget.customer?.phoneNumber ?? '');
    _emailController = TextEditingController(text: widget.customer?.email ?? '');
    _addressController = TextEditingController(text: widget.customer?.address ?? '');
    _notesController = TextEditingController(text: widget.customer?.notes ?? '');
    
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
    final localizations = AppLocalizations.of(context)!; // Add localizations instance

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? localizations.editCustomerTitle : localizations.addCustomerTitle), // Localized
      ),
      body: BlocListener<CustomerBloc, CustomerState>(
        listener: (context, state) {
          if (state is CustomerOperationSuccess) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(state.message)), // Keep dynamic message from BLoC
            );
            context.pop(); 
          } else if (state is CustomerError) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.message), // Keep dynamic message from BLoC
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
                Text(
                  localizations.customerInformation, // Localized
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                
                TextFormField(
                  controller: _nameController,
                  decoration: InputDecoration(
                    labelText: localizations.customerNameLabel, // Localized
                    border: const OutlineInputBorder(),
                    prefixIcon: const Icon(Icons.person),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return localizations.customerNameValidationError; // Localized
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                
                TextFormField(
                  controller: _phoneController,
                  decoration: InputDecoration(
                    labelText: localizations.customerPhoneLabel, // Localized
                    border: const OutlineInputBorder(),
                    prefixIcon: const Icon(Icons.phone),
                    hintText: localizations.customerPhoneHint, // Localized
                  ),
                  keyboardType: TextInputType.phone,
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[0-9+\s-]')),
                  ],
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return localizations.customerPhoneValidationError; // Localized
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                
                TextFormField(
                  controller: _emailController,
                  decoration: InputDecoration(
                    labelText: localizations.customerEmailLabel, // Localized
                    border: const OutlineInputBorder(),
                    prefixIcon: const Icon(Icons.email),
                  ),
                  keyboardType: TextInputType.emailAddress,
                  validator: (value) {
                    if (value != null && value.isNotEmpty) {
                      final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
                      if (!emailRegex.hasMatch(value)) {
                        return localizations.customerEmailValidationError; // Localized
                      }
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                
                TextFormField(
                  controller: _addressController,
                  decoration: InputDecoration(
                    labelText: localizations.customerAddressLabel, // Localized
                    border: const OutlineInputBorder(),
                    prefixIcon: const Icon(Icons.location_on),
                  ),
                  maxLines: 2,
                ),
                const SizedBox(height: 16),
                
                Text(
                  localizations.customerCategoryLabel, // Localized
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
                    child: DropdownButton<CustomerCategory>(
                      isExpanded: true,
                      value: _selectedCategory,
                      items: CustomerCategory.values.map((category) {
                        return DropdownMenuItem<CustomerCategory>(
                          value: category,
                          child: Row(
                            children: [
                              Container(
                                width: 16,
                                height: 16,
                                decoration: BoxDecoration(
                                  color: _getCategoryColor(category), // Theme colors will be handled in a follow-up if needed
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
                
                TextFormField(
                  controller: _notesController,
                  decoration: InputDecoration(
                    labelText: localizations.customerNotesLabel, // Localized
                    border: const OutlineInputBorder(),
                    prefixIcon: const Icon(Icons.note),
                  ),
                  maxLines: 3,
                ),
                const SizedBox(height: 24),
                
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: _saveCustomer,
                    child: Text(_isEditing ? localizations.updateButtonLabel : localizations.addButtonLabel), // Localized
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Sauvegarde le client (ajout ou mise à jour)
  void _saveCustomer() {
    if (_formKey.currentState?.validate() ?? false) {
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

  /// Retourne la couleur associée à une catégorie de client
  Color _getCategoryColor(CustomerCategory category) {
    // This will be updated to use Theme.of(context).colorScheme if not already done in customers_screen
    // For now, keeping existing colors to avoid breaking changes before full theme integration review
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
      // No default needed as CustomerCategory.values are used in dropdown
    }
  }

  /// Retourne le nom d\'une catégorie de client
  String _getCategoryName(BuildContext context, CustomerCategory category) { // Add context
    final localizations = AppLocalizations.of(context)!; // Add localizations instance
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
      // No default needed as CustomerCategory.values are used in dropdown
    }
  }
}
