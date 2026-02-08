import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_it/get_it.dart';
import 'package:wanzo/l10n/app_localizations.dart'; // Import AppLocalizations
import 'package:wanzo/core/services/currency_service.dart'; // Import CurrencyService
import 'package:wanzo/core/utils/currency_formatter.dart'; // Added import
import 'package:wanzo/core/enums/currency_enum.dart'; // Added import for Currency enum and extension
import 'package:wanzo/core/services/form_navigation_service.dart';
import 'package:wanzo/core/services/sync_service.dart';
import '../bloc/supplier_bloc.dart';
import '../bloc/supplier_event.dart';
import '../bloc/supplier_state.dart';
import '../models/supplier.dart';
import 'supplier_details_screen.dart';

/// Écran principal de gestion des fournisseurs
class SuppliersScreen extends StatefulWidget {
  final bool isEmbedded;
  const SuppliersScreen({super.key, this.isEmbedded = false});

  @override
  State<SuppliersScreen> createState() => _SuppliersScreenState();
}

class _SuppliersScreenState extends State<SuppliersScreen> {
  final TextEditingController _searchController = TextEditingController();
  StreamSubscription<SyncStatus>? _syncSubscription;

  @override
  void initState() {
    super.initState();
    // Charge la liste des fournisseurs au démarrage
    context.read<SupplierBloc>().add(const LoadSuppliers());

    // Écouter le SyncService pour recharger les fournisseurs après synchronisation
    _setupSyncListener();
  }

  void _setupSyncListener() {
    if (GetIt.instance.isRegistered<SyncService>()) {
      final syncService = GetIt.instance<SyncService>();
      _syncSubscription = syncService.syncStatus.listen((status) {
        if (status == SyncStatus.completed && mounted) {
          debugPrint('🔄 Sync terminée - Rechargement des fournisseurs');
          context.read<SupplierBloc>().add(const LoadSuppliers());
        }
      });
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _syncSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final localizations =
        AppLocalizations.of(context)!; // Add localizations instance
    final Widget screenContent = Column(
      children: [
        // Barre de recherche
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: localizations.searchSupplierHint, // Localized
              prefixIcon: const Icon(Icons.search),
              suffixIcon: IconButton(
                icon: const Icon(Icons.clear),
                tooltip: localizations.clearSearchTooltip, // Localized
                onPressed: () {
                  _searchController.clear();
                  context.read<SupplierBloc>().add(const LoadSuppliers());
                },
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10.0),
              ),
            ),
            onChanged: (value) {
              if (value.length > 2) {
                context.read<SupplierBloc>().add(SearchSuppliers(value));
              } else if (value.isEmpty) {
                context.read<SupplierBloc>().add(const LoadSuppliers());
              }
            },
          ),
        ),

        // Liste des fournisseurs
        Expanded(
          child: BlocConsumer<SupplierBloc, SupplierState>(
            listener: (context, state) {
              if (state is SupplierError) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(localizations.supplierError(state.message)),
                  ), // Localized & Positional
                );
              } else if (state is SupplierOperationSuccess) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(state.message),
                  ), // Keep dynamic message from BLoC
                );
              }
            },
            builder: (context, state) {
              if (state is SupplierLoading) {
                return const Center(child: CircularProgressIndicator());
              } else if (state is SuppliersLoaded) {
                return _buildSuppliersList(
                  context,
                  state.suppliers,
                ); // Pass context
              } else if (state is SupplierSearchResults) {
                return _buildSuppliersList(
                  context, // Pass context
                  state.suppliers,
                  isSearchResult: true,
                  searchTerm: state.searchTerm,
                );
              } else if (state is TopSuppliersLoaded) {
                return _buildSuppliersList(
                  context, // Pass context
                  state.suppliers,
                  isTopSuppliers: true,
                );
              } else if (state is RecentSuppliersLoaded) {
                return _buildSuppliersList(
                  context, // Pass context
                  state.suppliers,
                  isRecentSuppliers: true,
                );
              } else if (state is SupplierError) {
                return Center(
                  child: Text(
                    localizations.supplierError(
                      state.message,
                    ), // Localized & Positional
                    style: const TextStyle(color: Colors.red),
                  ),
                );
              }

              return Center(
                child: Text(localizations.noSuppliersToShow),
              ); // Localized
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
        title: Text(localizations.suppliersTitle), // Localized
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_list),
            tooltip: localizations.filterSuppliersTooltip, // Localized
            onPressed: _showFilterOptions,
          ),
        ],
      ),
      body: screenContent, // Use the defined screenContent
      floatingActionButton: FloatingActionButton(
        onPressed: () => _navigateToAddSupplier(context),
        tooltip: localizations.addSupplierTooltip, // Localized
        child: const Icon(Icons.add),
      ),
    );
  }

  /// Construit la liste des fournisseurs
  Widget _buildSuppliersList(
    BuildContext context, // Add context
    List<Supplier> suppliers, {
    bool isSearchResult = false,
    bool isTopSuppliers = false,
    bool isRecentSuppliers = false,
    String searchTerm = '', // Corrected string escaping
  }) {
    final localizations =
        AppLocalizations.of(context)!; // Add localizations instance
    if (suppliers.isEmpty) {
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
                Icons.business_outlined,
                size: 64,
                color: Theme.of(
                  context,
                ).colorScheme.onSurface.withAlpha((0.4 * 255).round()),
              ),
              const SizedBox(height: 16),
              Text(
                localizations.noSuppliersAvailable,
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
    if (isTopSuppliers) {
      header = Padding(
        padding: const EdgeInsets.all(16.0),
        child: Text(
          localizations.topSuppliersByPurchases, // Localized
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
      );
    } else if (isRecentSuppliers) {
      header = Padding(
        padding: const EdgeInsets.all(16.0),
        child: Text(
          localizations.recentlyAddedSuppliers, // Localized
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
      );
    } else if (isSearchResult) {
      header = Padding(
        padding: const EdgeInsets.all(16.0),
        child: Text(
          localizations.resultsForSearchTerm(
            searchTerm,
          ), // Localized & Positional
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
            itemCount: suppliers.length,
            itemBuilder: (context, index) {
              final supplier = suppliers[index];
              return _buildSupplierListItem(context, supplier); // Pass context
            },
          ),
        ),
      ],
    );
  }

  /// Construit un élément de la liste des fournisseurs
  Widget _buildSupplierListItem(BuildContext context, Supplier supplier) {
    // Add context
    final localizations =
        AppLocalizations.of(context)!; // Add localizations instance
    final currencyService =
        context.read<CurrencyService>(); // Get CurrencyService instance

    final lastPurchaseText =
        supplier.lastPurchaseDate != null
            ? localizations.lastPurchaseDate(
              _formatDate(supplier.lastPurchaseDate!),
            ) // Localized & Positional
            : localizations.noRecentPurchase; // Localized

    final categoryColor = _getCategoryColor(context, supplier.category);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: categoryColor,
          child: Text(
            supplier.name.isNotEmpty ? supplier.name[0].toUpperCase() : '?',
            style: TextStyle(
              color: Theme.of(context).colorScheme.onPrimaryContainer,
            ),
          ),
        ),
        title: Text(supplier.name),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              supplier.contactPerson.isNotEmpty
                  ? localizations.contactPerson(
                    supplier.contactPerson,
                  ) // Localized & Positional
                  : supplier.phoneNumber,
            ),
            Builder(
              builder: (context) {
                // Access the 'code' getter from the Currency enum extension
                final String currencyCode =
                    currencyService.currentSettings.activeCurrency.code;
                final String formattedTotalPurchases = formatCurrency(
                  supplier.totalPurchases,
                  currencyCode,
                );
                return Text(
                  localizations.totalPurchasesAmount(
                    formattedTotalPurchases,
                  ), // Localized & Positional
                  style: const TextStyle(fontWeight: FontWeight.bold),
                );
              },
            ),
            Text(lastPurchaseText),
          ],
        ),
        trailing: PopupMenuButton<String>(
          icon: const Icon(Icons.more_vert),
          tooltip: localizations.moreOptionsTooltip, // Localized
          onSelected: (value) {
            if (value == 'details') {
              _navigateToSupplierDetails(context, supplier);
            } else if (value == 'edit') {
              _navigateToEditSupplier(context, supplier);
            } else if (value == 'delete') {
              _showDeleteConfirmation(context, supplier);
            }
          },
          itemBuilder:
              (BuildContext context) => [
                PopupMenuItem<String>(
                  value: 'details',
                  child: Text(localizations.viewDetails), // Localized
                ),
                PopupMenuItem<String>(
                  value: 'edit',
                  child: Text(localizations.edit), // Localized
                ),
                PopupMenuItem<String>(
                  value: 'delete',
                  child: Text(localizations.delete), // Localized
                ),
              ],
        ),
        onTap: () => _navigateToSupplierDetails(context, supplier),
      ),
    );
  }

  /// Affiche les options de filtrage
  void _showFilterOptions() {
    final localizations =
        AppLocalizations.of(context)!; // Add localizations instance
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.list),
                title: Text(localizations.allSuppliers), // Localized
                onTap: () {
                  Navigator.pop(context);
                  context.read<SupplierBloc>().add(const LoadSuppliers());
                },
              ),
              ListTile(
                leading: const Icon(Icons.star),
                title: Text(localizations.topSuppliers), // Localized
                onTap: () {
                  Navigator.pop(context);
                  context.read<SupplierBloc>().add(const LoadTopSuppliers());
                },
              ),
              ListTile(
                leading: const Icon(Icons.history),
                title: Text(localizations.recentSuppliers), // Localized
                onTap: () {
                  Navigator.pop(context);
                  context.read<SupplierBloc>().add(const LoadRecentSuppliers());
                },
              ),
              ListTile(
                leading: const Icon(Icons.category),
                title: Text(localizations.byCategory), // Localized
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
    final localizations =
        AppLocalizations.of(context)!; // Add localizations instance
    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(localizations.filterByCategory), // Localized
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children:
                SupplierCategory.values.map((category) {
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
                      context.read<SupplierBloc>().add(
                        FilterSuppliersByCategoryEvent(category),
                      ); // Corrected event name
                    },
                  );
                }).toList(),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: Text(localizations.cancelButtonLabel), // Localized
            ),
          ],
        );
      },
    );
  }

  /// Affiche une boîte de dialogue de confirmation de suppression
  void _showDeleteConfirmation(BuildContext context, Supplier supplier) {
    final localizations =
        AppLocalizations.of(context)!; // Add localizations instance
    showDialog(
      context: context,
      builder: (dialogContext) {
        // Renamed context to dialogContext
        return AlertDialog(
          title: Text(localizations.deleteSupplierTitle), // Localized
          content: Text(
            localizations.deleteSupplierConfirmation(
              supplier.name,
            ), // Localized & Positional
          ),
          actions: [
            TextButton(
              onPressed:
                  () => Navigator.pop(dialogContext), // Use dialogContext
              child: Text(localizations.cancelButtonLabel), // Localized
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext); // Use dialogContext
                context.read<SupplierBloc>().add(DeleteSupplier(supplier.id));
              },
              style: TextButton.styleFrom(
                foregroundColor: Theme.of(context).colorScheme.error,
              ),
              child: Text(localizations.deleteButtonLabel), // Localized
            ),
          ],
        );
      },
    );
  }

  /// Navigation vers l\'écran de détails d\'un fournisseur
  void _navigateToSupplierDetails(BuildContext context, Supplier supplier) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => SupplierDetailsScreen(supplier: supplier),
      ),
    ).then((_) {
      // Recharger les fournisseurs après retour des détails (au cas où il y a eu modification/suppression)
      if (mounted) {
        context.read<SupplierBloc>().add(const LoadSuppliers());
      }
    });
  }

  /// Navigation vers l'écran d'ajout d'un fournisseur
  void _navigateToAddSupplier(BuildContext context) {
    FormNavigationService.instance.openSupplierForm(
      context,
      onSuccess: () {
        // Recharger les fournisseurs après ajout
        if (mounted) {
          context.read<SupplierBloc>().add(const LoadSuppliers());
        }
      },
    );
  }

  /// Navigation vers l'écran de modification d'un fournisseur
  void _navigateToEditSupplier(BuildContext context, Supplier supplier) {
    FormNavigationService.instance.openSupplierForm(
      context,
      supplier: supplier,
      onSuccess: () {
        // Recharger les fournisseurs après modification
        if (mounted) {
          context.read<SupplierBloc>().add(const LoadSuppliers());
        }
      },
    );
  }

  /// Retourne la couleur associée à une catégorie de fournisseur
  Color _getCategoryColor(BuildContext context, SupplierCategory category) {
    switch (category) {
      case SupplierCategory.strategic:
        return Theme.of(context).colorScheme.primary;
      case SupplierCategory.regular:
        return Theme.of(context).colorScheme.secondary;
      case SupplierCategory.newSupplier:
        return Theme.of(context).colorScheme.tertiary;
      case SupplierCategory.occasional:
        return Theme.of(context).colorScheme.surfaceContainerHighest;
      case SupplierCategory.international:
        return Theme.of(context).colorScheme.primaryContainer;
      case SupplierCategory.local:
        return Theme.of(context).colorScheme.secondaryContainer;
      case SupplierCategory.online: // Added missing case
        return Theme.of(context).colorScheme.tertiaryContainer; // Example color
    }
  }

  /// Retourne le nom d\\\\\\\'une catégorie de fournisseur
  String _getCategoryName(BuildContext context, SupplierCategory category) {
    // Add context
    final localizations =
        AppLocalizations.of(context)!; // Add localizations instance
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
      case SupplierCategory.online: // Added missing case
        return localizations
            .supplierCategoryOnline; // Assuming this localization exists
    }
  }

  /// Formate une date
  String _formatDate(DateTime date) {
    // Consider using DateFormat from intl package for more robust and locale-aware formatting
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}'; // Corrected string escaping
  }
}
