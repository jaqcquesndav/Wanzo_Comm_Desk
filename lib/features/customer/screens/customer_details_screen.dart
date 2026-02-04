import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:wanzo/l10n/app_localizations.dart';
import 'package:wanzo/core/services/currency_service.dart';
import 'package:intl/intl.dart'; // Keep for _formatDate
import '../bloc/customer_bloc.dart';
import '../bloc/customer_event.dart';
import '../bloc/customer_state.dart';
import '../models/customer.dart';
import 'add_customer_screen.dart';

/// Écran de détails d'un client
class CustomerDetailsScreen extends StatelessWidget {
  /// Client à afficher
  final Customer? customer;
  
  /// ID du client
  final String customerId;

  const CustomerDetailsScreen({
    super.key, 
    this.customer,
    this.customerId = '',
  });
  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;
    if (customer == null && customerId.isNotEmpty) {
      context.read<CustomerBloc>().add(LoadCustomer(customerId));
      
      return Scaffold(
        appBar: AppBar(
          title: Text(localizations.customerDetailsTitle),
        ),
        body: BlocBuilder<CustomerBloc, CustomerState>(
          builder: (context, state) {            if (state is CustomerLoading) {
              return const Center(child: CircularProgressIndicator());
            } else if (state is CustomerLoaded) {
              return _buildCustomerDetails(context, state.customer);
            } else if (state is CustomerError) {
              return Center(child: Text(localizations.customerError(state.message))); // Corrected
            }
            return Center(child: Text(localizations.customerNotFound));
          },
        ),
      );
    }
    
    return _buildCustomerDetails(context, customer!);
  }
  
  Widget _buildCustomerDetails(BuildContext context, Customer customer) {
    final localizations = AppLocalizations.of(context)!;
    final currencyService = context.read<CurrencyService>();

    return Scaffold(
      appBar: AppBar(
        title: Text(localizations.customerDetailsTitle),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            tooltip: localizations.editCustomerTooltip,
            onPressed: () => _navigateToEditCustomer(context, customer),
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
                    backgroundColor: _getCategoryColor(customer.category),
                    child: Text(
                      customer.name.isNotEmpty ? customer.name[0].toUpperCase() : '?',
                      style: const TextStyle(
                        fontSize: 36,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    customer.name,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),                    decoration: BoxDecoration(
                      color: _getCategoryColor(customer.category).withValues(alpha: 0.2), // Corrected
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Text(
                      _getCategoryName(context, customer.category),
                      style: TextStyle(
                        color: _getCategoryColor(customer.category),
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
                    
                    _buildInfoRow(
                      Icons.phone,
                      localizations.customerPhoneLabel,
                      customer.phoneNumber,
                      onTap: () => _makePhoneCall(context, customer.phoneNumber),
                    ),
                    const SizedBox(height: 12),
                    
                    if (customer.email?.isNotEmpty ?? false) ...[
                      _buildInfoRow(
                        Icons.email,
                        localizations.customerEmailLabelOptional,
                        customer.email ?? '',
                        onTap: () => _sendEmail(context, customer.email ?? ''),
                      ),
                      const SizedBox(height: 12),
                    ],
                    
                    if (customer.address?.isNotEmpty ?? false) ...[
                      _buildInfoRow(
                        Icons.location_on,
                        localizations.customerAddressLabelOptional,
                        customer.address ?? '',
                        onTap: () => _openMap(context, customer.address ?? ''),
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
                      localizations.purchaseStatisticsSectionTitle,
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
                      currencyService.formatAmount(customer.totalPurchases), // Corrected
                    ),
                    const SizedBox(height: 12),
                    
                    _buildInfoRow(
                      Icons.calendar_today,
                      localizations.lastPurchaseLabel,
                      customer.lastPurchaseDate != null
                          ? _formatDate(context, customer.lastPurchaseDate!) // Corrected
                          : localizations.noPurchaseRecorded,
                    ),
                    const SizedBox(height: 12),
                    
                    _buildInfoRow(
                      Icons.access_time,
                      localizations.customerSinceLabel,
                      _formatDate(context, customer.createdAt), // Corrected
                    ),
                    const SizedBox(height: 12),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            
            if (customer.notes?.isNotEmpty ?? false) ...[
              Card(
                elevation: 2,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        localizations.notesLabelOptional, 
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Divider(),
                      const SizedBox(height: 8),
                      Text(customer.notes ?? ''),
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
                    Icons.add_shopping_cart,
                    localizations.addSaleButtonLabel,
                    onPressed: () => _addSale(context, customer),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildActionButton(
                    context,
                    Icons.phone,
                    localizations.callButtonLabel,
                    onPressed: () => _makePhoneCall(context, customer.phoneNumber),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildActionButton(
                    context,
                    Icons.delete,
                    localizations.deleteButtonLabel,
                    isDestructive: true,
                    onPressed: () => _confirmDelete(context, customer),
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
      label: Text(label, textAlign: TextAlign.center, style: const TextStyle(fontSize: 12)), // Adjusted text style
      style: ElevatedButton.styleFrom(
        backgroundColor: isDestructive ? Colors.red.withValues(alpha: 0.1) : theme.colorScheme.primaryContainer,
        foregroundColor: isDestructive ? Colors.red : theme.colorScheme.onPrimaryContainer,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12), 
        textStyle: const TextStyle(fontSize: 12), 
      ),
    );
  }
  void _navigateToEditCustomer(BuildContext context, Customer customer) {
    final BuildContext currentContext = context; 
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AddCustomerScreen(customer: customer),
      ),
    ).then((value) {
      if (currentContext.mounted) { 
        currentContext.read<CustomerBloc>().add(LoadCustomer(customer.id));
      }
    });
  }

  void _addSale(BuildContext context, Customer customer) {
    final localizations = AppLocalizations.of(context)!;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(localizations.featureComingSoonMessage)),
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

  void _confirmDelete(BuildContext context, Customer customer) {
    final localizations = AppLocalizations.of(context)!;
    final customerBloc = BlocProvider.of<CustomerBloc>(context); 

    showDialog(
      context: context,
      builder: (dialogContext) { 
        return AlertDialog(
          title: Text(localizations.deleteCustomerTitle),
          content: Text(
            localizations.deleteCustomerConfirmation(customer.name), // Corrected
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: Text(localizations.cancelButtonLabel),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext); 
                customerBloc.add(DeleteCustomer(customer.id)); 
                if (Navigator.canPop(context)) { // Check if context is still valid for Navigator.pop
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
      // No default needed as all enum values are handled by CustomerCategory.values
      // and _getCategoryName handles unknown cases for display.
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

  String _formatDate(BuildContext context, DateTime date) { // Corrected signature
    final locale = Localizations.localeOf(context).toString();
    return DateFormat.yMd(locale).format(date);
  }
}
