import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:wanzo/l10n/app_localizations.dart';
import 'package:wanzo/core/services/currency_service.dart';
import '../bloc/customer_bloc.dart';
import '../bloc/customer_event.dart';
import '../bloc/customer_state.dart';
import '../models/customer.dart';
import 'customer_details_screen.dart';
import 'add_customer_screen.dart';

/// Écran principal de gestion des clients
class CustomersScreen extends StatefulWidget {
  final bool isEmbedded;
  const CustomersScreen({super.key, this.isEmbedded = false});

  @override
  State<CustomersScreen> createState() => _CustomersScreenState();
}

class _CustomersScreenState extends State<CustomersScreen> {
  final TextEditingController _searchController = TextEditingController();
  late CurrencyService _currencyService;

  @override
  void initState() {
    super.initState();
    // Charge la liste des clients au démarrage
    context.read<CustomerBloc>().add(const LoadCustomers());
    // Initialize CurrencyService
    _currencyService =
        CurrencyService(); // Initialize CurrencyService without settingsBloc
    _currencyService.loadSettings(); // Load currency settings
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;
    final Widget screenContent = Column(
      children: [
        // Barre de recherche
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: localizations.searchCustomerHint,
              prefixIcon: const Icon(Icons.search),
              suffixIcon: IconButton(
                icon: const Icon(Icons.clear),
                onPressed: () {
                  _searchController.clear();
                  context.read<CustomerBloc>().add(const LoadCustomers());
                },
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10.0),
              ),
            ),
            onChanged: (value) {
              if (value.length > 2) {
                context.read<CustomerBloc>().add(SearchCustomers(value));
              } else if (value.isEmpty) {
                context.read<CustomerBloc>().add(const LoadCustomers());
              }
            },
          ),
        ),

        // Liste des clients
        Expanded(
          child: BlocConsumer<CustomerBloc, CustomerState>(
            listener: (context, state) {
              if (state is CustomerError) {
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(SnackBar(content: Text(state.message)));
              } else if (state is CustomerOperationSuccess) {
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(SnackBar(content: Text(state.message)));
              }
            },
            builder: (context, state) {
              if (state is CustomerLoading) {
                return const Center(child: CircularProgressIndicator());
              } else if (state is CustomersLoaded) {
                return _buildCustomersList(context, state.customers);
              } else if (state is CustomerSearchResults) {
                return _buildCustomersList(
                  context,
                  state.customers,
                  isSearchResult: true,
                  searchTerm: state.searchTerm,
                );
              } else if (state is TopCustomersLoaded) {
                return _buildCustomersList(
                  context,
                  state.customers,
                  isTopCustomers: true,
                );
              } else if (state is RecentCustomersLoaded) {
                return _buildCustomersList(
                  context,
                  state.customers,
                  isRecentCustomers: true,
                );
              } else if (state is CustomerError) {
                return Center(
                  child: Text(
                    localizations.customerError(state.message),
                    style: const TextStyle(color: Colors.red),
                  ),
                );
              }

              return Center(child: Text(localizations.noCustomersToShow));
            },
          ),
        ),
      ],
    );

    if (widget.isEmbedded) {
      return screenContent; // Return only the content for embedding
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(localizations.customersTitle),
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_list),
            tooltip: localizations.filterCustomersTooltip,
            onPressed: _showFilterOptions,
          ),
        ],
      ),
      body: screenContent,
      floatingActionButton: FloatingActionButton(
        onPressed: () => _navigateToAddCustomer(context),
        tooltip: localizations.addCustomerTooltip,
        child: const Icon(Icons.add),
      ),
    );
  }

  /// Construit la liste des clients
  Widget _buildCustomersList(
    BuildContext context,
    List<Customer> customers, {
    bool isSearchResult = false,
    bool isTopCustomers = false,
    bool isRecentCustomers = false,
    String searchTerm = '',
  }) {
    final localizations = AppLocalizations.of(context)!;
    if (customers.isEmpty) {
      if (isSearchResult) {
        return Padding(
          padding: const EdgeInsets.all(24.0),
          child: Center(
            child: Text(
              localizations.noResultsForSearchTerm(searchTerm),
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: Theme.of(
                  context,
                ).colorScheme.onSurface.withAlpha((0.7 * 255).round()),
              ),
              textAlign: TextAlign.center,
            ),
          ),
        );
      }
      return Padding(
        padding: const EdgeInsets.all(24.0),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.people_outline,
                size: 64,
                color: Theme.of(
                  context,
                ).colorScheme.onSurface.withAlpha((0.4 * 255).round()),
              ),
              const SizedBox(height: 16),
              Text(
                localizations.noCustomersAvailable,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: Theme.of(
                    context,
                  ).colorScheme.onSurface.withAlpha((0.7 * 255).round()),
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    // Titre spécial pour les listes filtrées
    Widget? header;
    if (isTopCustomers) {
      header = Padding(
        padding: const EdgeInsets.all(16.0),
        child: Text(
          localizations.topCustomersByPurchases,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
      );
    } else if (isRecentCustomers) {
      header = Padding(
        padding: const EdgeInsets.all(16.0),
        child: Text(
          localizations.recentlyAddedCustomers,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
      );
    } else if (isSearchResult) {
      header = Padding(
        padding: const EdgeInsets.all(16.0),
        child: Text(
          localizations.resultsForSearchTerm(searchTerm),
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (header != null) header,
        Expanded(
          child: ListView.builder(
            itemCount: customers.length,
            itemBuilder: (context, index) {
              final customer = customers[index];
              return _buildCustomerListItem(context, customer);
            },
          ),
        ),
      ],
    );
  }

  /// Construit un élément de la liste des clients
  Widget _buildCustomerListItem(BuildContext context, Customer customer) {
    final localizations = AppLocalizations.of(context)!;
    final lastPurchaseText =
        customer.lastPurchaseDate != null
            ? localizations.lastPurchaseDate(
              _formatDate(customer.lastPurchaseDate!),
            )
            : localizations.noRecentPurchase;

    final categoryColor = _getCategoryColor(context, customer.category);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: categoryColor, // Use theme color
          child: Text(
            customer.name.isNotEmpty ? customer.name[0].toUpperCase() : '?',
            style: TextStyle(
              color: Theme.of(context).colorScheme.onPrimaryContainer,
            ), // Ensure text is visible
          ),
        ),
        title: Text(customer.name),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(customer.phoneNumber),
            Text(
              localizations.totalPurchasesAmount(
                _formatCurrency(customer.totalPurchases),
              ),
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            Text(lastPurchaseText),
          ],
        ),
        trailing: PopupMenuButton<String>(
          icon: const Icon(Icons.more_vert),
          onSelected: (value) {
            if (value == 'details') {
              _navigateToCustomerDetails(context, customer);
            } else if (value == 'edit') {
              _navigateToEditCustomer(context, customer);
            } else if (value == 'delete') {
              _showDeleteConfirmation(context, customer);
            }
          },
          itemBuilder:
              (BuildContext context) => [
                PopupMenuItem<String>(
                  value: 'details',
                  child: Text(localizations.viewDetails),
                ),
                PopupMenuItem<String>(
                  value: 'edit',
                  child: Text(localizations.edit),
                ),
                PopupMenuItem<String>(
                  value: 'delete',
                  child: Text(localizations.delete),
                ),
              ],
        ),
        onTap: () => _navigateToCustomerDetails(context, customer),
      ),
    );
  }

  /// Affiche les options de filtrage
  void _showFilterOptions() {
    final localizations = AppLocalizations.of(context)!;
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.list),
                title: Text(localizations.allCustomers),
                onTap: () {
                  Navigator.pop(context);
                  context.read<CustomerBloc>().add(const LoadCustomers());
                },
              ),
              ListTile(
                leading: const Icon(Icons.star),
                title: Text(localizations.topCustomers),
                onTap: () {
                  Navigator.pop(context);
                  context.read<CustomerBloc>().add(const LoadTopCustomers());
                },
              ),
              ListTile(
                leading: const Icon(Icons.history),
                title: Text(localizations.recentCustomers),
                onTap: () {
                  Navigator.pop(context);
                  context.read<CustomerBloc>().add(const LoadRecentCustomers());
                },
              ),
              ListTile(
                leading: const Icon(Icons.category),
                title: Text(localizations.byCategory),
                onTap: () {
                  Navigator.pop(context);
                  _showCategoriesFilter();
                },
              ),
            ],
          ),
        );
      },
    );
  }

  /// Affiche les options de filtrage par catégorie
  void _showCategoriesFilter() {
    final localizations = AppLocalizations.of(context)!;
    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(localizations.filterByCategory),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children:
                CustomerCategory.values.map((category) {
                  return ListTile(
                    leading: CircleAvatar(
                      backgroundColor: _getCategoryColor(context, category),
                      radius: 12,
                      child: Text(
                        _getCategoryName(context, category)[0],
                        style: TextStyle(
                          fontSize: 10,
                          color:
                              Theme.of(context).colorScheme.onPrimaryContainer,
                        ),
                      ),
                    ),
                    title: Text(_getCategoryName(context, category)),
                    onTap: () {
                      Navigator.pop(dialogContext);
                      // Ici, on pourrait implémenter un filtre par catégorie
                      // Pour l\'instant, nous revenons simplement à tous les clients
                      context.read<CustomerBloc>().add(const LoadCustomers());
                    },
                  );
                }).toList(),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: Text(localizations.cancel),
            ),
          ],
        );
      },
    );
  }

  /// Affiche une boîte de dialogue de confirmation de suppression
  void _showDeleteConfirmation(BuildContext context, Customer customer) {
    final localizations = AppLocalizations.of(context)!;
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(localizations.deleteCustomerTitle),
          content: Text(
            localizations.deleteCustomerConfirmation(customer.name),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(localizations.cancel),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                context.read<CustomerBloc>().add(DeleteCustomer(customer.id));
              },
              style: TextButton.styleFrom(
                foregroundColor: Theme.of(context).colorScheme.error,
              ),
              child: Text(localizations.delete),
            ),
          ],
        );
      },
    );
  }

  /// Navigation vers l'écran de détails d'un client
  void _navigateToCustomerDetails(BuildContext context, Customer customer) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CustomerDetailsScreen(customer: customer),
      ),
    ).then((_) {
      // Recharger les clients après retour des détails (au cas où il y a eu modification/suppression)
      if (mounted) {
        context.read<CustomerBloc>().add(const LoadCustomers());
      }
    });
  }

  /// Navigation vers l'écran d'ajout d'un client
  void _navigateToAddCustomer(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const AddCustomerScreen()),
    ).then((_) {
      // Recharger les clients après ajout
      if (mounted) {
        context.read<CustomerBloc>().add(const LoadCustomers());
      }
    });
  }

  /// Navigation vers l'écran de modification d'un client
  void _navigateToEditCustomer(BuildContext context, Customer customer) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AddCustomerScreen(customer: customer),
      ),
    ).then((_) {
      // Recharger les clients après modification
      if (mounted) {
        context.read<CustomerBloc>().add(const LoadCustomers());
      }
    });
  }

  /// Retourne la couleur associée à une catégorie de client
  Color _getCategoryColor(BuildContext context, CustomerCategory category) {
    // Added BuildContext
    switch (category) {
      case CustomerCategory.vip:
        return Theme.of(context).colorScheme.primary;
      case CustomerCategory.regular:
        return Theme.of(context).colorScheme.secondary;
      case CustomerCategory.new_customer:
        return Theme.of(context).colorScheme.tertiary;
      case CustomerCategory.occasional:
        return Theme.of(context).colorScheme.surfaceContainerHighest;
      case CustomerCategory.business:
        return Theme.of(context).colorScheme.primaryContainer;
    }
  }

  /// Retourne le nom d\'une catégorie de client
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

  String _formatCurrency(double amount) {
    // Use CurrencyService to format currency, assuming amount is in CDF
    return _currencyService.formatAmount(amount);
  }

  /// Formate une date
  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }
}
