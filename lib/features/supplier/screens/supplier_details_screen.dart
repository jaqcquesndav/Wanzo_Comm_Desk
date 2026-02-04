import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:wanzo/l10n/app_localizations.dart';
import 'package:wanzo/core/services/currency_service.dart';
import 'package:intl/intl.dart';
import '../bloc/supplier_bloc.dart';
import '../bloc/supplier_event.dart';
import '../bloc/supplier_state.dart';
import '../models/supplier.dart';
import 'add_supplier_screen.dart';

/// Écran de détails d'un fournisseur
class SupplierDetailsScreen extends StatelessWidget {
  /// Fournisseur à afficher
  final Supplier? supplier;
  
  /// ID du fournisseur
  final String supplierId;

  const SupplierDetailsScreen({
    super.key, 
    this.supplier,
    this.supplierId = '',
  });
  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!; 
    if (supplier == null && supplierId.isNotEmpty) {
      context.read<SupplierBloc>().add(LoadSupplier(supplierId));
      
      return Scaffold(
        appBar: AppBar(
          title: Text(localizations.supplierDetailsTitle), 
        ),
        body: BlocBuilder<SupplierBloc, SupplierState>(
          builder: (context, state) {
            if (state is SupplierLoading) {
              return const Center(child: CircularProgressIndicator());
            } else if (state is SupplierLoaded) {
              return _buildSupplierDetails(context, state.supplier);
            } else if (state is SupplierError) {
              return Center(child: Text(localizations.supplierErrorLoading(state.message))); // Corrected
            }
            return Center(child: Text(localizations.supplierNotFound)); 
          },
        ),
      );
    }
    
    return _buildSupplierDetails(context, supplier!);
  }
  
  Widget _buildSupplierDetails(BuildContext context, Supplier supplier) {
    final localizations = AppLocalizations.of(context)!; 
    final currencyService = context.read<CurrencyService>(); 

    return Scaffold(
      appBar: AppBar(
        title: Text(localizations.supplierDetailsTitle), 
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            tooltip: localizations.edit, 
            onPressed: () => _navigateToEditSupplier(context, supplier),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Column(
                children: [
                  CircleAvatar(
                    radius: 50,
                    backgroundColor: _getCategoryColor(supplier.category),
                    child: Text(
                      supplier.name.isNotEmpty ? supplier.name[0].toUpperCase() : '?',
                      style: const TextStyle(
                        fontSize: 36,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    supplier.name,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 4),                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: _getCategoryColor(supplier.category).withOpacity(0.2), // Corrected
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Text(
                      _getCategoryName(context, supplier.category), 
                      style: TextStyle(
                        color: _getCategoryColor(supplier.category),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            
            Card(
              elevation: 2,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      localizations.contactInformationSectionTitle, 
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Divider(),
                    const SizedBox(height: 8),
                    
                    if (supplier.contactPerson.isNotEmpty) ...[
                      _buildInfoRow(
                        Icons.person,
                        localizations.contactLabel, 
                        supplier.contactPerson,
                      ),
                      const SizedBox(height: 12),
                    ],
                    
                    _buildInfoRow(
                      Icons.phone,
                      localizations.phoneLabel, 
                      supplier.phoneNumber,
                      onTap: () => _makePhoneCall(context, supplier.phoneNumber),
                    ),
                    const SizedBox(height: 12),
                    
                    if (supplier.email.isNotEmpty) ...[
                      _buildInfoRow(
                        Icons.email,
                        localizations.emailLabel, 
                        supplier.email,
                        onTap: () => _sendEmail(context, supplier.email),
                      ),
                      const SizedBox(height: 12),
                    ],
                    
                    if (supplier.address.isNotEmpty) ...[
                      _buildInfoRow(
                        Icons.location_on,
                        localizations.addressLabel, 
                        supplier.address,
                        onTap: () => _openMap(context, supplier.address),
                      ),
                      const SizedBox(height: 12),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            
            Card(
              elevation: 2,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      localizations.commercialInformationSectionTitle, 
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Divider(),
                    const SizedBox(height: 8),
                    
                    _buildInfoRow(
                      Icons.attach_money,
                      localizations.totalPurchasesLabel, 
                      currencyService.formatAmount(supplier.totalPurchases), // Corrected
                    ),
                    const SizedBox(height: 12),
                    
                    _buildInfoRow(
                      Icons.calendar_today,
                      localizations.lastPurchaseLabel, 
                      supplier.lastPurchaseDate != null
                          ? _formatDate(supplier.lastPurchaseDate!, context) 
                          : localizations.noPurchaseRecorded, 
                    ),
                    const SizedBox(height: 12),
                    
                    _buildInfoRow(
                      Icons.timer,
                      localizations.deliveryTimeLabel, 
                      localizations.deliveryTimeInDays(supplier.deliveryTimeInDays), // Corrected
                    ),
                    const SizedBox(height: 12),
                    
                    if (supplier.paymentTerms.isNotEmpty) ...[
                      _buildInfoRow(
                        Icons.payment,
                        localizations.paymentTermsLabel, 
                        supplier.paymentTerms,
                      ),
                      const SizedBox(height: 12),
                    ],
                    
                    _buildInfoRow(
                      Icons.access_time,
                      localizations.supplierSinceLabel, 
                      _formatDate(supplier.createdAt, context), 
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            
            if (supplier.notes.isNotEmpty) ...[
              Card(
                elevation: 2,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        localizations.notesSectionTitle, 
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Divider(),
                      const SizedBox(height: 8),
                      Text(supplier.notes),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],
            
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                Expanded(
                  child: _buildActionButton(
                    context,
                    Icons.shopping_cart,
                    localizations.placeOrderButtonLabel, 
                    onPressed: () => _placeOrder(context),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildActionButton(
                    context,
                    Icons.phone,
                    localizations.callButtonLabel, 
                    onPressed: () => _makePhoneCall(context, supplier.phoneNumber),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildActionButton(
                    context,
                    Icons.delete,
                    localizations.deleteButtonLabel, 
                    isDestructive: true,
                    onPressed: () => _confirmDelete(context, supplier), 
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(
    IconData icon,
    String label,
    String value, {
    VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: Colors.grey[700]),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 12,
                  ),
                ),
                Text(
                  value,
                  style: const TextStyle(fontSize: 16),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton(
    BuildContext context,
    IconData icon,
    String label, {
    required VoidCallback onPressed,
    bool isDestructive = false,
  }) {
    final theme = Theme.of(context);
    return ElevatedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 18),
      label: Text(label, textAlign: TextAlign.center, style: const TextStyle(fontSize: 12)), // Adjusted
      style: ElevatedButton.styleFrom(
        backgroundColor: isDestructive ? Colors.red.withOpacity(0.1) : theme.colorScheme.primaryContainer,
        foregroundColor: isDestructive ? Colors.red : theme.colorScheme.onPrimaryContainer,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12), 
        textStyle: const TextStyle(fontSize: 12), 
      ),
    );
  }
  void _navigateToEditSupplier(BuildContext context, Supplier supplier) {
    final BuildContext currentContext = context; 
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AddSupplierScreen(supplier: supplier),
      ),    ).then((value) {
      if (currentContext.mounted) { 
        currentContext.read<SupplierBloc>().add(LoadSupplier(supplier.id));
      }
    });
  }

  void _placeOrder(BuildContext context) {
    final localizations = AppLocalizations.of(context)!; 
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(localizations.featureToImplement)), 
    );
  }

  void _makePhoneCall(BuildContext context, String phoneNumber) {
    final localizations = AppLocalizations.of(context)!; 
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(localizations.callingNumber(phoneNumber))), // Corrected
    );
  }

  void _sendEmail(BuildContext context, String email) {
    final localizations = AppLocalizations.of(context)!; 
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(localizations.emailingTo(email))), // Corrected
    );
  }

  void _openMap(BuildContext context, String address) {
    final localizations = AppLocalizations.of(context)!; 
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(localizations.openingMapFor(address))), // Corrected
    );
  }  
  void _confirmDelete(BuildContext context, Supplier supplier) { 
    final localizations = AppLocalizations.of(context)!; 
    final supplierBloc = BlocProvider.of<SupplierBloc>(context); 

    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(localizations.confirmDeleteSupplierTitle), 
          content: Text(
            localizations.confirmDeleteSupplierMessage(supplier.name), // Corrected
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: Text(localizations.cancelButtonLabel), 
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext);
                supplierBloc.add(DeleteSupplier(supplier.id)); 
                if (Navigator.canPop(context)) { // Check if context is still valid
                    Navigator.pop(context); 
                }
              },
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: Text(localizations.deleteButtonLabel), 
            ),
          ],
        );
      },
    );
  }
  Color _getCategoryColor(SupplierCategory category) {
    switch (category) {
      case SupplierCategory.local:
        return Colors.green;
      case SupplierCategory.international:
        return Colors.blue;
      case SupplierCategory.online:
        return Colors.orange;
      case SupplierCategory.strategic:
        return Colors.purple;
      case SupplierCategory.regular:
        return Colors.teal;
      case SupplierCategory.newSupplier: // Changed from new to newSupplier
        return Colors.pink;
      case SupplierCategory.occasional:
        return Colors.brown;
    }
  }

  String _getCategoryName(BuildContext context, SupplierCategory category) {
    final localizations = AppLocalizations.of(context)!; 
    switch (category) {
      case SupplierCategory.local:
        return localizations.supplierCategoryLocal; 
      case SupplierCategory.international:
        return localizations.supplierCategoryInternational; 
      case SupplierCategory.online:
        return localizations.supplierCategoryOnline; 
      case SupplierCategory.strategic:
        return localizations.supplierCategoryStrategic;
      case SupplierCategory.regular:
        return localizations.supplierCategoryRegular;
      case SupplierCategory.newSupplier: // Changed from new to newSupplier
        return localizations.supplierCategoryNew; 
      case SupplierCategory.occasional:
        return localizations.supplierCategoryOccasional;
    }
  }

  String _formatDate(DateTime date, BuildContext context) { 
    final locale = Localizations.localeOf(context).toString();
    return DateFormat.yMd(locale).format(date);
  }
}
