import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:url_launcher/url_launcher.dart'; // Pour ouvrir les fichiers PDF
import 'package:wanzo/core/enums/currency_enum.dart'; // Corrected: Currency is the enum name
import 'package:wanzo/core/models/currency_settings_model.dart';
import 'package:wanzo/core/utils/currency_formatter.dart';
import 'package:wanzo/core/widgets/desktop/responsive_form_container.dart';
import 'package:wanzo/core/widgets/smart_image.dart'; // SmartImage for Cloudinary URLs
import 'package:wanzo/features/customer/bloc/customer_bloc.dart';
import 'package:wanzo/features/customer/bloc/customer_event.dart';
import 'package:wanzo/features/customer/bloc/customer_state.dart';
import 'package:wanzo/features/customer/models/customer.dart';
import 'package:wanzo/features/inventory/bloc/inventory_bloc.dart';
import 'package:wanzo/features/inventory/bloc/inventory_event.dart';
import 'package:wanzo/features/inventory/bloc/inventory_state.dart';
import 'package:wanzo/features/inventory/models/product.dart';
import 'package:wanzo/features/invoice/services/invoice_service.dart';
import 'package:wanzo/features/settings/bloc/settings_bloc.dart'
    as old_settings_bloc;
import 'package:wanzo/features/settings/bloc/settings_event.dart'
    as old_settings_event;
import 'package:wanzo/features/settings/bloc/settings_state.dart'
    as old_settings_state;
import 'package:wanzo/features/settings/models/settings.dart'
    as old_settings_model;
import 'package:wanzo/features/settings/presentation/cubit/currency_settings_cubit.dart';
import '../widgets/sales_barcode_scanner.dart';
import '../../../constants/spacing.dart';
import '../../../core/services/barcode_scanner_service.dart'; // Import du service scanner
import '../bloc/sales_bloc.dart';
import '../models/sale.dart';
import '../models/sale_item.dart';

/// Types de postes pour les devis/factures (UI uniquement, stocké dans notes)
enum QuoteItemCategory {
  product, // Produit du stock
  service, // Service générique
  labor, // Main d'œuvre
  material, // Matériel/Fournitures
  transport, // Frais de transport
  miscFees, // Frais divers
}

extension QuoteItemCategoryExtension on QuoteItemCategory {
  String get displayName {
    switch (this) {
      case QuoteItemCategory.product:
        return 'Produit';
      case QuoteItemCategory.service:
        return 'Service';
      case QuoteItemCategory.labor:
        return 'Main d\'œuvre';
      case QuoteItemCategory.material:
        return 'Matériel/Fournitures';
      case QuoteItemCategory.transport:
        return 'Transport';
      case QuoteItemCategory.miscFees:
        return 'Frais divers';
    }
  }

  IconData get icon {
    switch (this) {
      case QuoteItemCategory.product:
        return Icons.inventory_2;
      case QuoteItemCategory.service:
        return Icons.miscellaneous_services;
      case QuoteItemCategory.labor:
        return Icons.engineering;
      case QuoteItemCategory.material:
        return Icons.hardware;
      case QuoteItemCategory.transport:
        return Icons.local_shipping;
      case QuoteItemCategory.miscFees:
        return Icons.receipt_long;
    }
  }

  Color get color {
    switch (this) {
      case QuoteItemCategory.product:
        return Colors.blue;
      case QuoteItemCategory.service:
        return Colors.green;
      case QuoteItemCategory.labor:
        return Colors.orange;
      case QuoteItemCategory.material:
        return Colors.purple;
      case QuoteItemCategory.transport:
        return Colors.teal;
      case QuoteItemCategory.miscFees:
        return Colors.grey;
    }
  }

  String get defaultUnit {
    switch (this) {
      case QuoteItemCategory.product:
        return 'unité';
      case QuoteItemCategory.service:
        return 'prestation';
      case QuoteItemCategory.labor:
        return 'heure';
      case QuoteItemCategory.material:
        return 'lot';
      case QuoteItemCategory.transport:
        return 'trajet';
      case QuoteItemCategory.miscFees:
        return 'forfait';
    }
  }

  /// Convertit en SaleItemType pour le stockage
  SaleItemType get saleItemType {
    return this == QuoteItemCategory.product
        ? SaleItemType.product
        : SaleItemType.service;
  }
}

/// Écran d'ajout d'une nouvelle vente
class AddSaleScreen extends StatefulWidget {
  const AddSaleScreen({super.key});

  @override
  State<AddSaleScreen> createState() => _AddSaleScreenState();
}

class _AddSaleScreenState extends State<AddSaleScreen> {
  final _formKey = GlobalKey<FormState>();

  // Contrôleurs pour les champs du formulaire
  final _customerNameController = TextEditingController();
  final _customerPhoneController = TextEditingController();
  final _notesController = TextEditingController();
  final _discountController = TextEditingController(text: '0');

  String? _linkedCustomerId;
  Customer? _foundCustomer; // Pour stocker le client trouvé par numéro

  // Valeurs par défaut
  String _paymentMethod = 'Espèces';
  final List<SaleItem> _items = [];
  double _paidAmount = 0.0;
  double _discountPercentage = 0.0; // Pourcentage de réduction (0-100)

  // Pour l'ajout rapide par catégorie
  ProductCategory? _selectedQuickCategory;
  bool _showQuickAdd = false;

  // Currency related state
  Currency _defaultCurrency = Currency.CDF; // App default
  Currency? _selectedTransactionCurrency;
  double _transactionExchangeRate =
      1.0; // Rate of _selectedTransactionCurrency to _defaultCurrency (CDF)
  Map<Currency, double> _exchangeRates =
      {}; // Stores rate_to_CDF for each currency
  List<Currency> _availableCurrencies = Currency.values;

  @override
  void initState() {
    super.initState();
    context.read<old_settings_bloc.SettingsBloc>().add(
      const old_settings_event.LoadSettings(),
    );
    context.read<InventoryBloc>().add(const LoadProducts());
    context.read<CustomerBloc>();

    final currencySettingsCubit = context.read<CurrencySettingsCubit>();
    // Access state directly after cubit is obtained
    final currentCurrencyState = currencySettingsCubit.state;
    if (currentCurrencyState.status == CurrencySettingsStatus.loaded) {
      _initializeCurrencySettings(currentCurrencyState.settings);
    } else {
      currencySettingsCubit
          .loadSettings(); // Trigger load if not already loaded
    }
  }

  void _initializeCurrencySettings(CurrencySettings settings) {
    setState(() {
      _defaultCurrency = settings.activeCurrency;
      _selectedTransactionCurrency = settings.activeCurrency;
      // The following lines correctly initialize _exchangeRates
      _exchangeRates = {
        Currency.USD: settings.usdToCdfRate,
        Currency.FCFA: settings.fcfaToCdfRate,
        Currency.CDF: 1.0, // CDF to CDF is always 1.0
      };

      _transactionExchangeRate = _exchangeRates[settings.activeCurrency] ?? 1.0;

      _availableCurrencies =
          _exchangeRates.keys
              .where((k) => _exchangeRates[k] != null && _exchangeRates[k]! > 0)
              .toList();

      // Ensure default currency is always available if it has a rate
      if (!_availableCurrencies.contains(settings.activeCurrency) &&
          (_exchangeRates[settings.activeCurrency] ?? 0) > 0) {
        _availableCurrencies.add(settings.activeCurrency);
      }
      // If no currencies are available (e.g. all rates are 0 or null), add default as a fallback
      if (_availableCurrencies.isEmpty) {
        _availableCurrencies.add(settings.activeCurrency);
      }

      if (_selectedTransactionCurrency == null ||
          !_availableCurrencies.contains(_selectedTransactionCurrency)) {
        _selectedTransactionCurrency =
            _availableCurrencies.isNotEmpty
                ? _availableCurrencies.first
                : settings.activeCurrency;
      }
      _transactionExchangeRate =
          _exchangeRates[_selectedTransactionCurrency!] ?? 1.0;
    });
  }

  @override
  void dispose() {
    _customerNameController.dispose();
    _customerPhoneController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _searchCustomerByPhone(String phoneNumber) async {
    if (phoneNumber.isEmpty) {
      setState(() {
        _foundCustomer = null;
        _linkedCustomerId = null;
        _customerNameController.clear();
      });
      return;
    }
    context.read<CustomerBloc>().add(SearchCustomers(phoneNumber));
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<CurrencySettingsCubit, CurrencySettingsState>(
      listener: (context, state) {
        if (state.status == CurrencySettingsStatus.loaded) {
          _initializeCurrencySettings(state.settings);
        } else if (state.status == CurrencySettingsStatus.error) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Erreur chargement devises: ${state.errorMessage}'),
            ),
          );
        }
      },
      child: Scaffold(
        appBar: AppBar(title: const Text('Nouvelle vente')),
        body: MultiBlocListener(
          listeners: [
            BlocListener<SalesBloc, SalesState>(
              listener: (context, state) {
                if (state is SalesOperationSuccess) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(state.message),
                      backgroundColor: Colors.green,
                    ),
                  );
                  if (state.saleId != null) {
                    _handleSaleSuccess(state.saleId!);
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'ID de vente manquant, impossible de générer le document.',
                        ),
                      ),
                    );
                    if (mounted) Navigator.of(context).pop(true);
                  }
                } else if (state is SalesError) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(state.message),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              },
            ),
            BlocListener<CustomerBloc, CustomerState>(
              listener: (context, state) {
                if (state is CustomerSearchResults) {
                  if (state.customers.isNotEmpty &&
                      state.customers.any(
                        (c) => c.phoneNumber == _customerPhoneController.text,
                      )) {
                    final matchedCustomer = state.customers.firstWhere(
                      (c) => c.phoneNumber == _customerPhoneController.text,
                    );
                    setState(() {
                      _foundCustomer = matchedCustomer;
                      _linkedCustomerId = matchedCustomer.id;
                      _customerNameController.text = matchedCustomer.name;
                    });
                  } else {
                    setState(() {
                      _foundCustomer = null;
                      _linkedCustomerId = null;
                    });
                  }
                } else if (state is CustomerError) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        "Erreur recherche client: ${state.message}",
                      ),
                      backgroundColor: Colors.orange,
                    ),
                  );
                  setState(() {
                    _foundCustomer = null;
                    _linkedCustomerId = null;
                  });
                }
              },
            ),
          ],
          child: ResponsiveFormWrapper(
            child: Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(WanzoSpacing.md),
                children: [
                  // Section articles
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(WanzoSpacing.md),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  const Icon(Icons.shopping_bag),
                                  const SizedBox(width: WanzoSpacing.sm),
                                  Text(
                                    'Articles (${_items.length})',
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleMedium
                                        ?.copyWith(fontWeight: FontWeight.bold),
                                  ),
                                ],
                              ),
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  OutlinedButton.icon(
                                    icon: const Icon(Icons.qr_code_scanner),
                                    label: const Text('Scanner'),
                                    onPressed: _showBarcodeScanner,
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor:
                                          Theme.of(context).colorScheme.primary,
                                    ),
                                  ),
                                  const SizedBox(width: WanzoSpacing.sm),
                                  ElevatedButton(
                                    onPressed: _showAddItemDialog,
                                    child: const Icon(Icons.add),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          const Divider(),
                          // Section d'ajout rapide par catégorie
                          _buildQuickAddSection(),
                          if (_items.isEmpty)
                            const Padding(
                              padding: EdgeInsets.symmetric(
                                vertical: WanzoSpacing.md,
                              ),
                              child: Center(
                                child: Text(
                                  'Aucun article ajouté',
                                  style: TextStyle(
                                    fontStyle: FontStyle.italic,
                                    color: Colors.grey,
                                  ),
                                ),
                              ),
                            )
                          else
                            _buildItemsList(), // Updated to use transaction currency
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: WanzoSpacing.md),
                  // Section paiement
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(WanzoSpacing.md),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.payment),
                              const SizedBox(width: WanzoSpacing.sm),
                              Text(
                                'Informations de paiement',
                                style: Theme.of(context).textTheme.titleMedium
                                    ?.copyWith(fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                          const Divider(),
                          const SizedBox(height: WanzoSpacing.sm),

                          // Currency Selector
                          if (_availableCurrencies.length > 1) ...[
                            DropdownButtonFormField<Currency>(
                              value: _selectedTransactionCurrency,
                              decoration: const InputDecoration(
                                labelText: 'Devise de la transaction',
                                border: OutlineInputBorder(),
                              ),
                              items:
                                  _availableCurrencies.map((Currency currency) {
                                    return DropdownMenuItem<Currency>(
                                      value: currency,
                                      child: Text(
                                        currency.displayName(context),
                                      ), // Use context for potential localization
                                    );
                                  }).toList(),
                              onChanged: (Currency? newValue) {
                                if (newValue != null) {
                                  setState(() {
                                    _selectedTransactionCurrency = newValue;
                                    _transactionExchangeRate =
                                        _exchangeRates[newValue] ?? 1.0;
                                    if (_paymentMethod != 'Crédit') {
                                      _paidAmount =
                                          _calculateTotalInTransactionCurrency();
                                    }
                                  });
                                }
                              },
                              validator:
                                  (value) =>
                                      value == null
                                          ? 'Sélectionnez une devise'
                                          : null,
                            ),
                            const SizedBox(height: WanzoSpacing.md),
                            if (_selectedTransactionCurrency != null &&
                                _selectedTransactionCurrency !=
                                    _defaultCurrency)
                              Padding(
                                padding: const EdgeInsets.only(
                                  bottom: WanzoSpacing.sm,
                                ),
                                child: Text(
                                  'Taux: 1 ${_selectedTransactionCurrency?.code} = ${formatNumber(_transactionExchangeRate)} ${_defaultCurrency.code}',
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                              ),
                          ],

                          // Affichage du sous-total avant réduction
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('Sous-total'),
                              Text(
                                formatCurrency(
                                  _calculateSubtotalInTransactionCurrency(),
                                  _selectedTransactionCurrency?.code ??
                                      _defaultCurrency.code,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: WanzoSpacing.xs),

                          // Champ de réduction en pourcentage
                          Row(
                            children: [
                              Expanded(
                                child: TextFormField(
                                  controller: _discountController,
                                  keyboardType:
                                      const TextInputType.numberWithOptions(
                                        decimal: true,
                                      ),
                                  inputFormatters: [
                                    FilteringTextInputFormatter.allow(
                                      RegExp(r'^\d+\.?\d{0,2}'),
                                    ),
                                  ],
                                  decoration: const InputDecoration(
                                    labelText: 'Réduction (%)',
                                    border: OutlineInputBorder(),
                                    suffixText: '%',
                                  ),
                                  onChanged: (value) {
                                    setState(() {
                                      _discountPercentage =
                                          double.tryParse(value) ?? 0.0;
                                      // Limiter à 100%
                                      if (_discountPercentage > 100) {
                                        _discountPercentage = 100;
                                        _discountController.text = '100';
                                      }
                                      // Mettre à jour le montant payé si paiement complet
                                      if (_paymentMethod != 'Crédit') {
                                        _paidAmount =
                                            _calculateTotalInTransactionCurrency();
                                      }
                                    });
                                  },
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: WanzoSpacing.xs),

                          Column(
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text('Montant total'),
                                  Text(
                                    formatCurrency(
                                      _calculateTotalInTransactionCurrency(),
                                      _selectedTransactionCurrency?.code ??
                                          _defaultCurrency.code,
                                    ),
                                    style: Theme.of(
                                      context,
                                    ).textTheme.titleMedium?.copyWith(
                                      fontWeight: FontWeight.bold,
                                      color: Theme.of(context).primaryColor,
                                    ),
                                  ),
                                ],
                              ),
                              // Afficher le total en CDF si une autre devise est sélectionnée
                              if (_selectedTransactionCurrency?.code !=
                                  'CDF') ...[
                                const SizedBox(height: 4),
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      'Total (CDF)',
                                      style: Theme.of(
                                        context,
                                      ).textTheme.bodySmall?.copyWith(
                                        fontStyle: FontStyle.italic,
                                      ),
                                    ),
                                    Text(
                                      formatCurrency(
                                        _calculateTotalInTransactionCurrency() *
                                            (_exchangeRates[_selectedTransactionCurrency!] ??
                                                1.0),
                                        'CDF',
                                      ),
                                      style: Theme.of(
                                        context,
                                      ).textTheme.bodySmall?.copyWith(
                                        fontStyle: FontStyle.italic,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ],
                          ),
                          const SizedBox(height: WanzoSpacing.md),
                          TextFormField(
                            key: ValueKey(_selectedTransactionCurrency),
                            initialValue: _paidAmount.toStringAsFixed(2),
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            inputFormatters: [
                              FilteringTextInputFormatter.allow(
                                RegExp(r'^\d+\.?\d{0,2}'),
                              ),
                            ],
                            decoration: InputDecoration(
                              labelText: 'Montant payé',
                              border: const OutlineInputBorder(),
                              prefixText:
                                  '${_selectedTransactionCurrency?.symbol ?? _defaultCurrency.symbol} ',
                            ),
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Veuillez entrer le montant payé';
                              }
                              final amount = double.tryParse(value);
                              if (amount == null) return 'Montant invalide';
                              if (amount < 0) {
                                return 'Le montant ne peut pas être négatif';
                              }
                              return null;
                            },
                            onChanged: (value) {
                              setState(() {
                                _paidAmount = double.tryParse(value) ?? 0.0;
                              });
                            },
                          ),
                          const SizedBox(height: WanzoSpacing.md),
                          DropdownButtonFormField<String>(
                            value: _paymentMethod,
                            decoration: const InputDecoration(
                              labelText: 'Méthode de paiement',
                              border: OutlineInputBorder(),
                            ),
                            items: const [
                              DropdownMenuItem(
                                value: 'Espèces',
                                child: Text('Espèces'),
                              ),
                              DropdownMenuItem(
                                value: 'Mobile Money',
                                child: Text('Mobile Money'),
                              ),
                              DropdownMenuItem(
                                value: 'Carte bancaire',
                                child: Text('Carte bancaire'),
                              ),
                              DropdownMenuItem(
                                value: 'Virement bancaire',
                                child: Text('Virement bancaire'),
                              ),
                              DropdownMenuItem(
                                value: 'Crédit',
                                child: Text('Crédit'),
                              ),
                            ],
                            onChanged: (value) {
                              setState(() {
                                _paymentMethod = value!;
                                if (_paymentMethod != 'Crédit') {
                                  _paidAmount =
                                      _calculateTotalInTransactionCurrency();
                                }
                              });
                            },
                          ),
                          const SizedBox(height: WanzoSpacing.md),
                          if (_items.isNotEmpty)
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(
                                vertical: WanzoSpacing.sm,
                                horizontal: WanzoSpacing.md,
                              ),
                              decoration: BoxDecoration(
                                color: _getPaymentStatusColor().withAlpha(
                                  (0.1 * 255).round(),
                                ),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: _getPaymentStatusColor(),
                                ),
                              ),
                              child: Text(
                                _getPaymentStatusText(),
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: _getPaymentStatusColor(),
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: WanzoSpacing.md),
                  // Section client (déplacée après le paiement, champs optionnels)
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(WanzoSpacing.md),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.person),
                              const SizedBox(width: WanzoSpacing.sm),
                              Text(
                                'Informations client (optionnel)',
                                style: Theme.of(context).textTheme.titleMedium
                                    ?.copyWith(fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                          const Divider(),
                          const SizedBox(height: WanzoSpacing.sm),
                          BlocBuilder<CustomerBloc, CustomerState>(
                            builder: (context, customerState) {
                              final allCustomers =
                                  customerState is CustomerSearchResults
                                      ? customerState.customers
                                      : (customerState is CustomersLoaded
                                          ? customerState.customers
                                          : <Customer>[]);

                              return Autocomplete<Customer>(
                                optionsBuilder: (
                                  TextEditingValue textEditingValue,
                                ) {
                                  if (textEditingValue.text.isEmpty) {
                                    return const Iterable<Customer>.empty();
                                  }

                                  // Rechercher en temps réel
                                  _searchCustomerByPhone(textEditingValue.text);

                                  return allCustomers.where((
                                    Customer customer,
                                  ) {
                                    return customer.phoneNumber
                                            .toLowerCase()
                                            .contains(
                                              textEditingValue.text
                                                  .toLowerCase(),
                                            ) ||
                                        customer.name.toLowerCase().contains(
                                          textEditingValue.text.toLowerCase(),
                                        );
                                  });
                                },
                                displayStringForOption:
                                    (Customer option) => option.phoneNumber,
                                onSelected: (Customer selection) {
                                  setState(() {
                                    _foundCustomer = selection;
                                    _linkedCustomerId = selection.id;
                                    _customerPhoneController.text =
                                        selection.phoneNumber;
                                    _customerNameController.text =
                                        selection.name;
                                  });
                                },
                                fieldViewBuilder: (
                                  context,
                                  textEditingController,
                                  focusNode,
                                  onFieldSubmitted,
                                ) {
                                  // Synchroniser avec notre controller
                                  if (_customerPhoneController.text !=
                                      textEditingController.text) {
                                    textEditingController.text =
                                        _customerPhoneController.text;
                                  }

                                  textEditingController.addListener(() {
                                    if (_customerPhoneController.text !=
                                        textEditingController.text) {
                                      _customerPhoneController.text =
                                          textEditingController.text;

                                      // Réinitialiser si le texte change
                                      if (_foundCustomer != null &&
                                          _foundCustomer!.phoneNumber !=
                                              textEditingController.text) {
                                        setState(() {
                                          _foundCustomer = null;
                                          _linkedCustomerId = null;
                                          _customerNameController.clear();
                                        });
                                      }
                                    }
                                  });

                                  return TextFormField(
                                    controller: textEditingController,
                                    focusNode: focusNode,
                                    decoration: const InputDecoration(
                                      labelText:
                                          'Contact téléphonique du client',
                                      border: OutlineInputBorder(),
                                      hintText: 'Ex: 0812345678 (optionnel)',
                                    ),
                                    keyboardType: TextInputType.phone,
                                  );
                                },
                                optionsViewBuilder: (
                                  context,
                                  onSelected,
                                  options,
                                ) {
                                  return Align(
                                    alignment: Alignment.topLeft,
                                    child: Material(
                                      elevation: 4.0,
                                      child: ConstrainedBox(
                                        constraints: const BoxConstraints(
                                          maxHeight: 200,
                                          maxWidth: 400,
                                        ),
                                        child: ListView.builder(
                                          padding: const EdgeInsets.all(8.0),
                                          itemCount: options.length,
                                          itemBuilder: (context, index) {
                                            final Customer option = options
                                                .elementAt(index);
                                            return ListTile(
                                              leading: const Icon(
                                                Icons.person,
                                                size: 20,
                                              ),
                                              title: Text(option.name),
                                              subtitle: Text(
                                                option.phoneNumber,
                                              ),
                                              onTap: () {
                                                onSelected(option);
                                              },
                                            );
                                          },
                                        ),
                                      ),
                                    ),
                                  );
                                },
                              );
                            },
                          ),
                          const SizedBox(height: WanzoSpacing.md),
                          TextFormField(
                            controller: _customerNameController,
                            decoration: InputDecoration(
                              labelText: 'Nom du client',
                              border: const OutlineInputBorder(),
                              filled: _foundCustomer != null,
                              fillColor:
                                  _foundCustomer != null
                                      ? Colors.green.withAlpha(
                                        (0.05 * 255).round(),
                                      )
                                      : null,
                              hintText: 'Laissez vide pour "Inconnu"',
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: WanzoSpacing.md),
                  // Section notes
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(WanzoSpacing.md),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.note),
                              const SizedBox(width: WanzoSpacing.sm),
                              Text(
                                'Notes (optionnel)',
                                style: Theme.of(context).textTheme.titleMedium
                                    ?.copyWith(fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                          const Divider(),
                          const SizedBox(height: WanzoSpacing.sm),
                          TextFormField(
                            controller: _notesController,
                            maxLines: 3,
                            decoration: const InputDecoration(
                              hintText: 'Ajouter des notes ou commentaires...',
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: WanzoSpacing.lg),
                ],
              ),
            ),
          ),
        ),
        bottomNavigationBar: BottomAppBar(
          child: Padding(
            padding: const EdgeInsets.all(WanzoSpacing.md),
            child: BlocBuilder<SalesBloc, SalesState>(
              builder: (context, state) {
                bool isLoading = state is SalesLoading;
                return SizedBox(
                  height: 54, // Augmentation de la hauteur du conteneur
                  child: ElevatedButton(
                    onPressed:
                        (_items.isEmpty ||
                                isLoading ||
                                _selectedTransactionCurrency == null)
                            ? null
                            : _saveSale,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        vertical: 12,
                      ), // Ajustement du padding vertical
                      backgroundColor: Theme.of(context).primaryColor,
                      foregroundColor: Colors.white,
                    ),
                    child:
                        isLoading
                            ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                            : const Text(
                              'Enregistrer la vente',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  Color _getPaymentStatusColor() {
    final total = _calculateTotalInTransactionCurrency();
    if (_paymentMethod == 'Crédit') {
      if (_paidAmount == 0) return Colors.orange;
      if (_paidAmount < total) return Colors.blue;
      return Colors.green;
    }
    return _isPaidFully() ? Colors.green : Colors.red;
  }

  String _getPaymentStatusText() {
    final total = _calculateTotalInTransactionCurrency();
    final currencyCode =
        _selectedTransactionCurrency?.code ?? _defaultCurrency.code;
    if (_paymentMethod == 'Crédit') {
      if (_paidAmount == 0) return 'Vente à crédit (aucun acompte)';
      if (_paidAmount < total) {
        return 'Acompte: ${formatCurrency(_paidAmount, currencyCode)}, Reste: ${formatCurrency(total - _paidAmount, currencyCode)}';
      }
      return 'Payé (crédit soldé)';
    }
    if (_isPaidFully()) return 'Entièrement payé';
    return 'Reste à payer: ${formatCurrency(total - _paidAmount, currencyCode)}';
  }

  Future<void> _handleSaleSuccess(String saleId) async {
    final oldSettingsBlocState =
        context.read<old_settings_bloc.SettingsBloc>().state;
    old_settings_model.Settings? currentLegacySettings;
    if (oldSettingsBlocState is old_settings_state.SettingsLoaded) {
      currentLegacySettings = oldSettingsBlocState.settings;
    } else if (oldSettingsBlocState is old_settings_state.SettingsUpdated) {
      currentLegacySettings = oldSettingsBlocState.settings;
    }

    if (currentLegacySettings == null) {
      if (mounted) {
        // Add mounted check
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Erreur: Paramètres (anciens) non chargés pour la génération du document.',
            ),
          ),
        );
        Navigator.of(context).pop(true); // MODIFIED: Pop with true
      }
      return;
    }

    final totalInTransactionCurrency = _calculateTotalInTransactionCurrency();
    final currentRate = _exchangeRates[_selectedTransactionCurrency!] ?? 1.0;
    final totalInCdf = totalInTransactionCurrency * currentRate;
    final paidInCdf = _paidAmount * currentRate;

    final saleForPdf = Sale(
      id: saleId,
      date: DateTime.now(),
      customerId:
          _linkedCustomerId ??
          'new_cust_ph_${_customerPhoneController.text.isNotEmpty ? _customerPhoneController.text.replaceAll(RegExp(r'[^0-9]'), '') : DateTime.now().millisecondsSinceEpoch}',
      customerName: _customerNameController.text,
      items: List<SaleItem>.from(_items),
      totalAmountInCdf: totalInCdf,
      paidAmountInCdf: paidInCdf,
      transactionCurrencyCode: _selectedTransactionCurrency!.code,
      transactionExchangeRate: currentRate,
      totalAmountInTransactionCurrency: totalInTransactionCurrency,
      paidAmountInTransactionCurrency: _paidAmount,
      discountPercentage: _discountPercentage,
      paymentMethod: _paymentMethod,
      status: _isPaidFully() ? SaleStatus.completed : SaleStatus.pending,
      notes: _notesController.text,
    );

    final invoiceService = InvoiceService();
    String? pdfPath;
    String documentType = '';

    if (_paymentMethod == 'Crédit' && !_isPaidFully()) {
      documentType = 'Facture';
      pdfPath = await invoiceService.generateInvoicePdf(
        saleForPdf,
        currentLegacySettings,
      );
    } else {
      documentType = 'Reçu';
      pdfPath = await invoiceService.generateReceiptPdf(
        saleForPdf,
        currentLegacySettings,
      );
    }

    if (pdfPath.isNotEmpty) {
      // Simplified from: pdfPath != null && pdfPath.isNotEmpty
      _showDocumentOptions(
        pdfPath,
        documentType,
        saleForPdf,
        currentLegacySettings,
      );
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Impossible de générer le $documentType. Chemin non valide.',
            ),
          ),
        );
        Navigator.of(context).pop(true); // MODIFIED: Pop with true
      }
    }
  }

  // Méthode pour réinitialiser le formulaire pour une nouvelle vente
  void _resetForm() {
    // Sauvegarde des informations que nous souhaitons conserver
    final currentTransactionCurrency = _selectedTransactionCurrency;
    final currentExchangeRates = Map<Currency, double>.from(_exchangeRates);

    setState(() {
      // Réinitialiser tous les contrôleurs de texte
      _customerNameController.clear();
      _customerPhoneController.clear();
      _notesController.clear();
      _discountController.text = '0';

      // Réinitialiser les informations du client
      _linkedCustomerId = null;
      _foundCustomer = null;

      // Réinitialiser les détails de la vente
      _paymentMethod = 'Espèces'; // Valeur par défaut
      _items.clear();
      _paidAmount = 0.0;
      _discountPercentage = 0.0;

      // Conserver les paramètres de devise
      _selectedTransactionCurrency = currentTransactionCurrency;
      _exchangeRates = currentExchangeRates;
      // S'assurer que le taux de change est correctement mis à jour
      _transactionExchangeRate =
          _exchangeRates[_selectedTransactionCurrency!] ?? 1.0;
    });

    // Recharger les produits disponibles
    context.read<InventoryBloc>().add(const LoadProducts());

    // Réinitialiser l'état du formulaire
    if (_formKey.currentState != null) {
      _formKey.currentState!.reset();
    }

    // Défiler vers le haut pour commencer la nouvelle vente
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        Scrollable.ensureVisible(
          _formKey.currentContext ?? context,
          duration: const Duration(milliseconds: 300),
        );
      }
    });
  }

  void _showDocumentOptions(
    String pdfPath,
    String documentType,
    Sale sale,
    old_settings_model.Settings settings,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.85,
      ),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (BuildContext bc) {
        final invoiceService = InvoiceService();
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 16.0, horizontal: 8.0),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                // En-tête avec message de succès
                Padding(
                  padding: const EdgeInsets.only(bottom: 16.0, top: 8.0),
                  child: Column(
                    children: [
                      const Icon(
                        Icons.check_circle,
                        color: Colors.green,
                        size: 48.0,
                      ),
                      const SizedBox(height: 8.0),
                      Text(
                        'Vente enregistrée avec succès',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24.0,
                          vertical: 8.0,
                        ),
                        child: Text(
                          'Montant total: ${_formatAmount(sale)}',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ),
                      const Divider(),
                    ],
                  ),
                ),
                // Options
                ListTile(
                  leading: const Icon(
                    Icons.add_circle_outline,
                    color: Colors.green,
                  ),
                  title: const Text('Enregistrer une autre vente'),
                  subtitle: const Text('Réinitialiser le formulaire'),
                  onTap: () {
                    Navigator.pop(bc);
                    _resetForm(); // Réinitialise le formulaire pour une nouvelle vente

                    // Montrer un feedback à l'utilisateur
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'Formulaire réinitialisé. Vous pouvez enregistrer une nouvelle vente.',
                        ),
                        backgroundColor: Colors.green,
                        duration: Duration(seconds: 2),
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  },
                ),
                // Nous gardons l'option de prévisualisation mais nous la plaçons en deuxième position
                ListTile(
                  leading: const Icon(Icons.visibility, color: Colors.blue),
                  title: Text('Prévisualiser $documentType'),
                  onTap: () async {
                    Navigator.pop(bc);
                    try {
                      // Utiliser url_launcher pour ouvrir le PDF
                      final file = File(pdfPath);
                      if (await file.exists()) {
                        final uri = Uri.file(pdfPath);
                        await launchUrl(uri);
                      }
                    } catch (e) {
                      debugPrint('Erreur lors de l\'ouverture du document: $e');
                    }
                    if (mounted) Navigator.of(context).pop(true);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.print, color: Colors.blue),
                  title: Text('Imprimer $documentType'),
                  onTap: () async {
                    Navigator.pop(bc);
                    await invoiceService.printDocument(pdfPath);
                    if (mounted) Navigator.of(context).pop(true);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.share, color: Colors.orange),
                  title: Text('Partager $documentType'),
                  onTap: () async {
                    Navigator.pop(bc);
                    await invoiceService.shareInvoice(
                      sale,
                      settings,
                      customerPhoneNumber: _customerPhoneController.text,
                    );
                    if (mounted) Navigator.of(context).pop(true);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.close, color: Colors.grey),
                  title: const Text('Fermer et continuer'),
                  onTap: () {
                    Navigator.pop(bc);
                    if (mounted) Navigator.of(context).pop(true);
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // Méthode pour formater le montant de la vente
  String _formatAmount(Sale sale) {
    // Si une devise de transaction est spécifiée et qu'il y a un montant dans cette devise
    if (sale.transactionCurrencyCode != null &&
        sale.totalAmountInTransactionCurrency != null) {
      return '${sale.totalAmountInTransactionCurrency!.toStringAsFixed(2)} ${sale.transactionCurrencyCode}';
    }

    // Par défaut, utiliser le montant en CDF
    return '${sale.totalAmountInCdf.toStringAsFixed(2)} CDF';
  }

  /// Construit l'icône de catégorie pour les produits sans image
  Widget _buildCategoryIcon(ProductCategory category) {
    return Container(
      decoration: BoxDecoration(
        color: _getCategoryColor(category).withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Center(
        child: Icon(
          category.icon,
          color: _getCategoryColor(category),
          size: 24,
        ),
      ),
    );
  }

  /// Retourne la couleur associée à une catégorie
  Color _getCategoryColor(ProductCategory category) {
    switch (category) {
      case ProductCategory.food:
        return Colors.orange;
      case ProductCategory.drink:
        return Colors.blue;
      case ProductCategory.electronics:
        return Colors.indigo;
      case ProductCategory.clothing:
        return Colors.purple;
      case ProductCategory.household:
        return Colors.brown;
      case ProductCategory.hygiene:
        return Colors.teal;
      case ProductCategory.office:
        return Colors.blueGrey;
      case ProductCategory.cosmetics:
        return Colors.pink;
      case ProductCategory.pharmaceuticals:
        return Colors.red;
      case ProductCategory.bakery:
        return Colors.amber;
      case ProductCategory.dairy:
        return Colors.lightBlue;
      case ProductCategory.meat:
        return Colors.deepOrange;
      case ProductCategory.vegetables:
        return Colors.green;
      case ProductCategory.fruits:
        return Colors.lime;
      case ProductCategory.other:
        return Colors.grey;
    }
  }

  /// Construit le widget leading pour un item du panier (image ou icône)
  Widget _buildItemLeadingWidget(SaleItem item) {
    // Détecter le type de poste de devis via les notes
    if (item.itemType == SaleItemType.service) {
      // Vérifier si c'est un type de poste spécifique (main d'œuvre, transport, etc.)
      QuoteItemCategory? quoteCategory;
      if (item.notes != null) {
        for (final category in QuoteItemCategory.values) {
          if (item.notes!.startsWith('[${category.displayName}]')) {
            quoteCategory = category;
            break;
          }
        }
      }

      // Utiliser les couleurs et icônes du type de poste si trouvé
      final color = quoteCategory?.color ?? Colors.green;
      final icon = quoteCategory?.icon ?? Icons.miscellaneous_services;

      return Container(
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Icon(icon, size: 16, color: color),
      );
    }

    // Chercher le produit pour obtenir l'image
    final inventoryState = context.read<InventoryBloc>().state;
    Product? product;
    if (inventoryState is ProductsLoaded) {
      product =
          inventoryState.products
              .where((p) => p.id == item.productId)
              .firstOrNull;
    }

    if (product?.imagePath != null && product!.imagePath!.isNotEmpty ||
        product?.imageUrl != null && product!.imageUrl!.isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(6),
        child: SizedBox(
          width: 28,
          height: 28,
          child: SmartImage(
            imageUrl: product.imageUrl,
            imagePath: product.imagePath,
            fit: BoxFit.cover,
            placeholderIcon: Icons.inventory_2,
          ),
        ),
      );
    }

    // Icône par défaut pour produit
    if (product != null) {
      return Container(
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          color: _getCategoryColor(product.category).withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Icon(
          product.category.icon,
          size: 16,
          color: _getCategoryColor(product.category),
        ),
      );
    }

    return Container(
      width: 28,
      height: 28,
      decoration: BoxDecoration(
        color: Colors.blue.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(6),
      ),
      child: const Icon(Icons.inventory_2, size: 16, color: Colors.blue),
    );
  }

  /// Construit la section d'ajout rapide par catégorie
  Widget _buildQuickAddSection() {
    return BlocBuilder<InventoryBloc, InventoryState>(
      builder: (context, state) {
        if (state is! ProductsLoaded || state.products.isEmpty) {
          return const SizedBox.shrink();
        }

        // Catégories disponibles (celles qui ont des produits)
        final availableCategories =
            state.products.map((p) => p.category).toSet().toList()
              ..sort((a, b) => a.displayName.compareTo(b.displayName));

        // Produits filtrés par catégorie sélectionnée
        final filteredProducts =
            _selectedQuickCategory != null
                ? state.products
                    .where(
                      (p) =>
                          p.category == _selectedQuickCategory &&
                          p.stockQuantity > 0,
                    )
                    .toList()
                : <Product>[];

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Bouton pour afficher/masquer l'ajout rapide
            InkWell(
              onTap: () => setState(() => _showQuickAdd = !_showQuickAdd),
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  children: [
                    Icon(
                      _showQuickAdd ? Icons.expand_less : Icons.flash_on,
                      size: 18,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Ajout rapide',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.primary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const Spacer(),
                    Icon(
                      _showQuickAdd
                          ? Icons.keyboard_arrow_up
                          : Icons.keyboard_arrow_down,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ],
                ),
              ),
            ),

            // Contenu de l'ajout rapide
            AnimatedCrossFade(
              firstChild: const SizedBox.shrink(),
              secondChild: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 8),
                  // Chips des catégories
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children:
                          availableCategories.take(8).map((category) {
                            final isSelected =
                                _selectedQuickCategory == category;
                            final productCount =
                                state.products
                                    .where(
                                      (p) =>
                                          p.category == category &&
                                          p.stockQuantity > 0,
                                    )
                                    .length;
                            return Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: FilterChip(
                                selected: isSelected,
                                showCheckmark: false,
                                avatar: Icon(
                                  category.icon,
                                  size: 16,
                                  color:
                                      isSelected
                                          ? Theme.of(
                                            context,
                                          ).colorScheme.onPrimaryContainer
                                          : _getCategoryColor(category),
                                ),
                                label: Text(
                                  '${category.displayName} ($productCount)',
                                ),
                                labelStyle: TextStyle(
                                  fontSize: 12,
                                  color:
                                      isSelected
                                          ? Theme.of(
                                            context,
                                          ).colorScheme.onPrimaryContainer
                                          : null,
                                ),
                                selectedColor:
                                    Theme.of(
                                      context,
                                    ).colorScheme.primaryContainer,
                                onSelected: (selected) {
                                  setState(() {
                                    _selectedQuickCategory =
                                        selected ? category : null;
                                  });
                                },
                              ),
                            );
                          }).toList(),
                    ),
                  ),

                  // Grille de produits de la catégorie sélectionnée
                  if (_selectedQuickCategory != null &&
                      filteredProducts.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    SizedBox(
                      height: 100,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        itemCount: filteredProducts.length,
                        itemBuilder: (context, index) {
                          final product = filteredProducts[index];
                          return _buildQuickAddProductTile(product);
                        },
                      ),
                    ),
                  ],

                  if (_selectedQuickCategory != null &&
                      filteredProducts.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Text(
                        'Aucun produit disponible dans cette catégorie',
                        style: TextStyle(
                          fontStyle: FontStyle.italic,
                          color: Colors.grey[600],
                          fontSize: 13,
                        ),
                      ),
                    ),
                ],
              ),
              crossFadeState:
                  _showQuickAdd
                      ? CrossFadeState.showSecond
                      : CrossFadeState.showFirst,
              duration: const Duration(milliseconds: 200),
            ),
            const SizedBox(height: 8),
          ],
        );
      },
    );
  }

  /// Construit une tuile de produit pour l'ajout rapide
  Widget _buildQuickAddProductTile(Product product) {
    final displayPrice =
        _selectedTransactionCurrency != null
            ? formatCurrency(
              product.sellingPriceInCdf /
                  (_exchangeRates[_selectedTransactionCurrency!] ?? 1.0),
              _selectedTransactionCurrency!.code,
            )
            : formatCurrency(product.sellingPriceInCdf, 'CDF');

    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: InkWell(
        onTap: () => _quickAddProduct(product),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: 90,
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey.shade300),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Image ou icône
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: SizedBox(
                  width: 40,
                  height: 40,
                  child:
                      (product.imagePath != null &&
                                  product.imagePath!.isNotEmpty) ||
                              (product.imageUrl != null &&
                                  product.imageUrl!.isNotEmpty)
                          ? SmartImage(
                            imageUrl: product.imageUrl,
                            imagePath: product.imagePath,
                            fit: BoxFit.cover,
                            placeholderIcon: Icons.inventory_2,
                          )
                          : _buildCategoryIcon(product.category),
                ),
              ),
              const SizedBox(height: 4),
              // Nom
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Text(
                  product.name,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                ),
              ),
              // Prix
              Text(
                displayPrice,
                style: TextStyle(
                  fontSize: 10,
                  color: Theme.of(context).colorScheme.primary,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Ajoute rapidement un produit au panier avec quantité 1
  void _quickAddProduct(Product product) {
    if (_selectedTransactionCurrency == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Veuillez d\'abord sélectionner une devise.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final exchangeRate = _exchangeRates[_selectedTransactionCurrency!] ?? 1.0;
    final unitPriceInTransactionCurrency =
        product.sellingPriceInCdf / exchangeRate;

    final saleItem = SaleItem(
      productId: product.id,
      productName: product.name,
      quantity: 1,
      unitPrice: unitPriceInTransactionCurrency,
      totalPrice: unitPriceInTransactionCurrency,
      currencyCode: _selectedTransactionCurrency!.code,
      exchangeRate: exchangeRate,
      unitPriceInCdf: product.sellingPriceInCdf,
      totalPriceInCdf: product.sellingPriceInCdf,
      itemType: SaleItemType.product,
    );

    _addItem(saleItem);

    // Feedback visuel
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.white, size: 18),
            const SizedBox(width: 8),
            Expanded(child: Text('${product.name} ajouté')),
          ],
        ),
        backgroundColor: Colors.green,
        duration: const Duration(milliseconds: 1200),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(8),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  Widget _buildItemsList() {
    final currencyCode =
        _selectedTransactionCurrency?.code ?? _defaultCurrency.code;
    final currencySymbol =
        _selectedTransactionCurrency?.symbol ?? _defaultCurrency.symbol;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: WanzoSpacing.sm),
          child: Row(
            children: [
              Expanded(
                flex: 3,
                child: Text(
                  'Article/Service',
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold),
                ),
              ),
              Expanded(
                flex: 1,
                child: Text(
                  'Qté',
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
              ),
              Expanded(
                flex: 2,
                child: Text(
                  'Prix U. ($currencySymbol)',
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold),
                  textAlign: TextAlign.right,
                ),
              ),
              const SizedBox(width: WanzoSpacing.md), // For delete icon
            ],
          ),
        ),
        const Divider(),
        ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: _items.length,
          separatorBuilder: (context, index) => const Divider(),
          itemBuilder: (context, index) {
            final item = _items[index];

            // Convertir le prix unitaire à la devise actuellement sélectionnée si nécessaire
            double displayUnitPrice = item.unitPrice;

            // Si la devise de l'item est différente de la devise sélectionnée actuellement
            if (item.currencyCode != currencyCode) {
              // Convertir d'abord en CDF (devise pivot)
              double amountInCdf = item.unitPrice * item.exchangeRate;

              // Puis convertir de CDF à la devise sélectionnée
              double exchangeRateToSelected =
                  _exchangeRates[_selectedTransactionCurrency!] ?? 1.0;
              if (exchangeRateToSelected > 0) {
                displayUnitPrice = amountInCdf / exchangeRateToSelected;
              }
            }

            return Row(
              children: [
                // Item type icon avec image produit
                Padding(
                  padding: const EdgeInsets.only(right: 8.0),
                  child: _buildItemLeadingWidget(item),
                ),
                Expanded(
                  flex: 3,
                  child: InkWell(
                    onTap: () => _showEditItemDialog(index, item),
                    borderRadius: BorderRadius.circular(4),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  item.productName,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                              Icon(
                                Icons.edit,
                                size: 12,
                                color: Colors.grey[400],
                              ),
                            ],
                          ),
                          // Afficher le type de poste et les notes si présentes
                          if (item.notes != null && item.notes!.isNotEmpty)
                            Text(
                              _getDisplayNotes(item.notes!),
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.grey[600],
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
                Expanded(
                  flex: 1,
                  child: Text(
                    '${item.quantity.toInt()}',
                    textAlign: TextAlign.center,
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Text(
                    formatCurrency(displayUnitPrice, currencyCode),
                    textAlign: TextAlign.right,
                    // Style visuel pour indiquer une conversion
                    style:
                        item.currencyCode != currencyCode
                            ? TextStyle(
                              color: Theme.of(context).colorScheme.primary,
                            )
                            : null,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.delete, color: Colors.red, size: 20),
                  onPressed: () => _removeItem(index),
                ),
              ],
            );
          },
        ),
        const Divider(),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: WanzoSpacing.sm),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Total',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    formatCurrency(
                      _calculateTotalInTransactionCurrency(),
                      currencyCode,
                    ),
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).primaryColor,
                    ),
                  ),
                ],
              ),
              // Afficher le total en CDF si une autre devise est sélectionnée
              if (currencyCode != 'CDF') ...[
                const SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Total (CDF)',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                    Text(
                      formatCurrency(
                        _calculateTotalInTransactionCurrency() *
                            (_exchangeRates[_selectedTransactionCurrency!] ??
                                1.0),
                        'CDF',
                      ),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  /// Ouvre le scanner de code-barres pour ajouter rapidement des produits
  Future<void> _showBarcodeScanner() async {
    final scannerService = BarcodeScannerService();

    // Vérifier le support du scanner
    final isSupported = await scannerService.isScannerSupported();
    if (!isSupported) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Scanner non supporté sur cet appareil'),
            backgroundColor: Colors.orange,
          ),
        );
      }
      return;
    }

    // Vérifier les permissions
    final hasPermission = await scannerService.checkCameraPermission();
    if (!hasPermission) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Permission caméra requise pour scanner'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    // Ouvrir le scanner
    if (mounted) {
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder:
              (context) => SalesBarcodeScanner(
                onProductSelected: (product) {
                  // Ajouter le produit directement à la vente avec quantité 1
                  final unitPriceInTransactionCurrency =
                      _convertFromCdfToTransactionCurrency(
                        product.sellingPriceInCdf,
                      );
                  final saleItem = SaleItem(
                    productId: product.id,
                    productName: product.name,
                    quantity: 1,
                    unitPrice: unitPriceInTransactionCurrency,
                    totalPrice: unitPriceInTransactionCurrency,
                    currencyCode:
                        (_selectedTransactionCurrency ?? _defaultCurrency).code,
                    exchangeRate: _transactionExchangeRate,
                    unitPriceInCdf: product.sellingPriceInCdf,
                    totalPriceInCdf: product.sellingPriceInCdf,
                    itemType: SaleItemType.product,
                  );

                  _addItem(saleItem);

                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('${product.name} ajouté à la vente'),
                      backgroundColor: Colors.green,
                    ),
                  );
                },
                onBarcodeNotFound: (barcode) {
                  // Code-barres non trouvé - proposer d'ajouter le produit
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        'Produit non trouvé pour le code: $barcode',
                      ),
                      backgroundColor: Colors.orange,
                      action: SnackBarAction(
                        label: 'Ajouter',
                        onPressed: () {
                          // TODO: Navigation vers ajout de produit avec code-barres pré-rempli
                        },
                      ),
                    ),
                  );
                },
              ),
        ),
      );
    }
  }

  void _showAddItemDialog() {
    final productNameController = TextEditingController();
    final productIdController = TextEditingController();
    final quantityController = TextEditingController(text: '1');
    final unitPriceController = TextEditingController();
    final notesController = TextEditingController();
    Product? selectedProductForDialog;
    final GlobalKey<FormState> addItemFormKey = GlobalKey<FormState>();

    // Utiliser QuoteItemCategory pour plus de flexibilité
    QuoteItemCategory currentCategory = QuoteItemCategory.product;

    final dialogCurrency = _selectedTransactionCurrency;
    if (dialogCurrency == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Veuillez d\'abord sélectionner une devise pour la transaction.',
          ),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    final dialogCurrencyCode = dialogCurrency.code;
    final dialogCurrencySymbol = dialogCurrency.symbol;
    final currentTransactionExchangeRateToCdf =
        _exchangeRates[dialogCurrency] ?? 1.0;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (bottomSheetContext) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            double calculatedTotalPrice = 0;
            final qty = int.tryParse(quantityController.text);
            final price = double.tryParse(unitPriceController.text);
            if (qty != null && price != null) {
              calculatedTotalPrice = qty * price;
            }

            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
                left: 16,
                right: 16,
                top: 16,
              ),
              child: Form(
                key: addItemFormKey,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Ajouter un poste',
                            style: Theme.of(context).textTheme.titleLarge
                                ?.copyWith(fontWeight: FontWeight.bold),
                          ),
                          IconButton(
                            onPressed: () => Navigator.pop(bottomSheetContext),
                            icon: const Icon(Icons.close),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Sélection du type de poste avec chips
                      Text(
                        'Type de poste',
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children:
                            QuoteItemCategory.values.map((category) {
                              final isSelected = currentCategory == category;
                              return ChoiceChip(
                                selected: isSelected,
                                showCheckmark: false,
                                avatar: Icon(
                                  category.icon,
                                  size: 18,
                                  color:
                                      isSelected
                                          ? Colors.white
                                          : category.color,
                                ),
                                label: Text(category.displayName),
                                labelStyle: TextStyle(
                                  color: isSelected ? Colors.white : null,
                                  fontWeight:
                                      isSelected ? FontWeight.w600 : null,
                                ),
                                selectedColor: category.color,
                                onSelected: (selected) {
                                  if (selected) {
                                    setStateDialog(() {
                                      currentCategory = category;
                                      // Réinitialiser les champs selon le type
                                      if (category !=
                                          QuoteItemCategory.product) {
                                        selectedProductForDialog = null;
                                        productIdController.clear();
                                      }
                                      // Pré-remplir le nom pour certaines catégories
                                      if (category == QuoteItemCategory.labor) {
                                        productNameController.text =
                                            productNameController.text.isEmpty
                                                ? 'Main d\'œuvre'
                                                : productNameController.text;
                                      } else if (category ==
                                          QuoteItemCategory.transport) {
                                        productNameController.text =
                                            productNameController.text.isEmpty
                                                ? 'Frais de transport'
                                                : productNameController.text;
                                      }
                                    });
                                  }
                                },
                              );
                            }).toList(),
                      ),
                      const SizedBox(height: 20),

                      // Champ de saisie selon le type
                      if (currentCategory == QuoteItemCategory.product)
                        BlocBuilder<InventoryBloc, InventoryState>(
                          builder: (context, state) {
                            List<Product> productSuggestions =
                                state is ProductsLoaded ? state.products : [];
                            return Autocomplete<Product>(
                              displayStringForOption:
                                  (Product option) => option.name,
                              optionsBuilder: (
                                TextEditingValue textEditingValue,
                              ) {
                                if (textEditingValue.text.isEmpty) {
                                  return const Iterable<Product>.empty();
                                }
                                return productSuggestions.where(
                                  (Product p) => p.name.toLowerCase().contains(
                                    textEditingValue.text.toLowerCase(),
                                  ),
                                );
                              },
                              onSelected: (Product selection) {
                                setStateDialog(() {
                                  selectedProductForDialog = selection;
                                  productNameController.text = selection.name;
                                  productIdController.text = selection.id;
                                  if (currentTransactionExchangeRateToCdf > 0) {
                                    unitPriceController.text = (selection
                                                .sellingPriceInCdf /
                                            currentTransactionExchangeRateToCdf)
                                        .toStringAsFixed(2);
                                  } else {
                                    unitPriceController.text = selection
                                        .sellingPriceInCdf
                                        .toStringAsFixed(2);
                                  }
                                  if (quantityController.text.isEmpty ||
                                      quantityController.text == '0') {
                                    quantityController.text = '1';
                                  }
                                });
                              },
                              fieldViewBuilder: (
                                ctx,
                                controller,
                                focusNode,
                                onSubmitted,
                              ) {
                                return TextFormField(
                                  controller: productNameController,
                                  focusNode: focusNode,
                                  decoration: InputDecoration(
                                    labelText: 'Nom du produit',
                                    border: const OutlineInputBorder(),
                                    hintText: 'Rechercher produit...',
                                    prefixIcon: Icon(
                                      QuoteItemCategory.product.icon,
                                    ),
                                  ),
                                  onChanged: (value) {
                                    if (selectedProductForDialog != null &&
                                        selectedProductForDialog!.name !=
                                            value) {
                                      setStateDialog(() {
                                        selectedProductForDialog = null;
                                        productIdController.clear();
                                      });
                                    }
                                  },
                                  validator:
                                      (v) =>
                                          v == null || v.isEmpty
                                              ? 'Nom du produit requis'
                                              : null,
                                );
                              },
                              optionsViewBuilder: (ctx, onSelected, options) {
                                return _buildProductOptionsView(
                                  options.toList(),
                                  onSelected,
                                  currentTransactionExchangeRateToCdf,
                                  dialogCurrencyCode,
                                );
                              },
                            );
                          },
                        )
                      else
                        // Champ de saisie libre pour les autres types
                        TextFormField(
                          controller: productNameController,
                          decoration: InputDecoration(
                            labelText: _getLabelForCategory(currentCategory),
                            hintText: _getHintForCategory(currentCategory),
                            border: const OutlineInputBorder(),
                            prefixIcon: Icon(
                              currentCategory.icon,
                              color: currentCategory.color,
                            ),
                          ),
                          validator:
                              (v) =>
                                  v == null || v.isEmpty
                                      ? '${currentCategory.displayName} requis'
                                      : null,
                        ),

                      const SizedBox(height: 16),

                      // Quantité et Prix sur la même ligne
                      Row(
                        children: [
                          Expanded(
                            flex: 2,
                            child: TextFormField(
                              controller: quantityController,
                              keyboardType: TextInputType.number,
                              inputFormatters: [
                                FilteringTextInputFormatter.digitsOnly,
                              ],
                              decoration: InputDecoration(
                                labelText: 'Quantité',
                                border: const OutlineInputBorder(),
                                suffixText: currentCategory.defaultUnit,
                              ),
                              validator: (v) {
                                if (v == null || v.isEmpty) return 'Requis';
                                final q = int.tryParse(v);
                                if (q == null || q <= 0) return 'Invalide';
                                if (currentCategory ==
                                        QuoteItemCategory.product &&
                                    selectedProductForDialog != null &&
                                    q >
                                        selectedProductForDialog!
                                            .stockQuantity) {
                                  return 'Stock: ${selectedProductForDialog!.stockQuantity.toInt()}';
                                }
                                return null;
                              },
                              onChanged: (_) => setStateDialog(() {}),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            flex: 3,
                            child: TextFormField(
                              controller: unitPriceController,
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                    decimal: true,
                                  ),
                              inputFormatters: [
                                FilteringTextInputFormatter.allow(
                                  RegExp(r'^\d+\.?\d{0,2}'),
                                ),
                              ],
                              decoration: InputDecoration(
                                labelText: 'Prix unitaire',
                                border: const OutlineInputBorder(),
                                prefixText: '$dialogCurrencySymbol ',
                              ),
                              validator: (v) {
                                if (v == null || v.isEmpty) return 'Requis';
                                final p = double.tryParse(v);
                                if (p == null || p < 0) return 'Invalide';
                                return null;
                              },
                              onChanged: (_) => setStateDialog(() {}),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 16),

                      // Notes optionnelles (utile pour les devis)
                      TextFormField(
                        controller: notesController,
                        decoration: InputDecoration(
                          labelText: 'Description / Notes (optionnel)',
                          hintText: _getNotesHintForCategory(currentCategory),
                          border: const OutlineInputBorder(),
                          prefixIcon: const Icon(Icons.notes),
                        ),
                        maxLines: 2,
                      ),

                      const SizedBox(height: 16),

                      // Résumé du prix
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Theme.of(
                            context,
                          ).colorScheme.primaryContainer.withValues(alpha: 0.3),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Total',
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                                Text(
                                  '${quantityController.text.isEmpty ? "0" : quantityController.text} × ${unitPriceController.text.isEmpty ? "0" : unitPriceController.text} $dialogCurrencySymbol',
                                  style: Theme.of(context).textTheme.bodySmall
                                      ?.copyWith(color: Colors.grey[600]),
                                ),
                              ],
                            ),
                            Text(
                              formatCurrency(
                                calculatedTotalPrice,
                                dialogCurrencyCode,
                              ),
                              style: Theme.of(
                                context,
                              ).textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 20),

                      // Bouton d'ajout
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: () {
                            if (addItemFormKey.currentState!.validate()) {
                              final String productName =
                                  productNameController.text;
                              final int currentQuantity = int.parse(
                                quantityController.text,
                              );
                              final double unitPriceInSelectedCurrency =
                                  double.parse(unitPriceController.text);

                              // Générer l'ID approprié
                              final String resolvedProductId =
                                  currentCategory == QuoteItemCategory.product
                                      ? (selectedProductForDialog?.id ??
                                          productIdController.text.takeIf(
                                            (it) => it.isNotEmpty,
                                          ) ??
                                          'manual_prod-${DateTime.now().millisecondsSinceEpoch}')
                                      : '${currentCategory.name}-${DateTime.now().millisecondsSinceEpoch}';

                              final totalPriceInSelectedCurrency =
                                  currentQuantity * unitPriceInSelectedCurrency;
                              final unitPriceInCdf =
                                  unitPriceInSelectedCurrency *
                                  currentTransactionExchangeRateToCdf;
                              final totalPriceInCdf =
                                  totalPriceInSelectedCurrency *
                                  currentTransactionExchangeRateToCdf;

                              // Construire les notes avec le type de poste
                              String? itemNotes;
                              if (currentCategory !=
                                      QuoteItemCategory.product &&
                                  currentCategory !=
                                      QuoteItemCategory.service) {
                                itemNotes = '[${currentCategory.displayName}]';
                                if (notesController.text.isNotEmpty) {
                                  itemNotes += ' ${notesController.text}';
                                }
                              } else if (notesController.text.isNotEmpty) {
                                itemNotes = notesController.text;
                              }

                              _addItem(
                                SaleItem(
                                  productId: resolvedProductId,
                                  productName: productName,
                                  quantity: currentQuantity,
                                  unitPrice: unitPriceInSelectedCurrency,
                                  totalPrice: totalPriceInSelectedCurrency,
                                  currencyCode: dialogCurrency.code,
                                  exchangeRate:
                                      currentTransactionExchangeRateToCdf,
                                  unitPriceInCdf: unitPriceInCdf,
                                  totalPriceInCdf: totalPriceInCdf,
                                  itemType: currentCategory.saleItemType,
                                  notes: itemNotes,
                                ),
                              );
                              Navigator.pop(bottomSheetContext);
                            }
                          },
                          icon: Icon(currentCategory.icon),
                          label: Text(
                            'Ajouter ${currentCategory.displayName.toLowerCase()}',
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: currentCategory.color,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  /// Retourne le label du champ selon la catégorie
  String _getLabelForCategory(QuoteItemCategory category) {
    switch (category) {
      case QuoteItemCategory.product:
        return 'Nom du produit';
      case QuoteItemCategory.service:
        return 'Description du service';
      case QuoteItemCategory.labor:
        return 'Type de main d\'œuvre';
      case QuoteItemCategory.material:
        return 'Matériel / Fournitures';
      case QuoteItemCategory.transport:
        return 'Description du transport';
      case QuoteItemCategory.miscFees:
        return 'Description des frais';
    }
  }

  /// Retourne le hint du champ selon la catégorie
  String _getHintForCategory(QuoteItemCategory category) {
    switch (category) {
      case QuoteItemCategory.product:
        return 'Ex: Écran LCD 24"';
      case QuoteItemCategory.service:
        return 'Ex: Installation logiciel';
      case QuoteItemCategory.labor:
        return 'Ex: Technicien électricien';
      case QuoteItemCategory.material:
        return 'Ex: Câbles et connecteurs';
      case QuoteItemCategory.transport:
        return 'Ex: Livraison sur site';
      case QuoteItemCategory.miscFees:
        return 'Ex: Frais administratifs';
    }
  }

  /// Retourne le hint pour les notes selon la catégorie
  String _getNotesHintForCategory(QuoteItemCategory category) {
    switch (category) {
      case QuoteItemCategory.product:
        return 'Détails sur le produit...';
      case QuoteItemCategory.service:
        return 'Détails sur le service...';
      case QuoteItemCategory.labor:
        return 'Ex: Intervention sur site, 2 techniciens';
      case QuoteItemCategory.material:
        return 'Spécifications techniques...';
      case QuoteItemCategory.transport:
        return 'Ex: Aller-retour, distance 50km';
      case QuoteItemCategory.miscFees:
        return 'Justification des frais...';
    }
  }

  /// Nettoie les notes pour l'affichage (enlève le préfixe de type si présent)
  String _getDisplayNotes(String notes) {
    // Si les notes commencent par un type de poste entre crochets, on l'affiche différemment
    for (final category in QuoteItemCategory.values) {
      final prefix = '[${category.displayName}]';
      if (notes.startsWith(prefix)) {
        final remainder = notes.substring(prefix.length).trim();
        if (remainder.isEmpty) {
          return category.displayName;
        }
        return remainder;
      }
    }
    return notes;
  }

  /// Construit la vue des options de produits améliorée
  Widget _buildProductOptionsView(
    List<Product> options,
    void Function(Product) onSelected,
    double exchangeRate,
    String currencyCode,
  ) {
    return Align(
      alignment: Alignment.topLeft,
      child: Material(
        elevation: 4.0,
        borderRadius: BorderRadius.circular(12),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 280, maxWidth: 350),
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(vertical: 8),
            shrinkWrap: true,
            itemCount: options.length,
            itemBuilder: (context, index) {
              final product = options[index];
              String displayPrice;
              if (exchangeRate > 0) {
                displayPrice = formatCurrency(
                  product.sellingPriceInCdf / exchangeRate,
                  currencyCode,
                );
              } else {
                displayPrice =
                    "${formatCurrency(product.sellingPriceInCdf, _defaultCurrency.code)} (CDF)";
              }
              final bool isLowStock =
                  product.stockQuantity <= product.alertThreshold;

              return InkWell(
                onTap: () => onSelected(product),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  child: Row(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: SizedBox(
                          width: 48,
                          height: 48,
                          child:
                              (product.imagePath != null &&
                                          product.imagePath!.isNotEmpty) ||
                                      (product.imageUrl != null &&
                                          product.imageUrl!.isNotEmpty)
                                  ? SmartImage(
                                    imageUrl: product.imageUrl,
                                    imagePath: product.imagePath,
                                    fit: BoxFit.cover,
                                    placeholderIcon: Icons.inventory_2,
                                  )
                                  : _buildCategoryIcon(product.category),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              product.name,
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 2),
                            Row(
                              children: [
                                Icon(
                                  isLowStock
                                      ? Icons.warning_amber
                                      : Icons.inventory_2,
                                  size: 14,
                                  color:
                                      isLowStock ? Colors.orange : Colors.grey,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  '${product.stockQuantity.toInt()} en stock',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color:
                                        isLowStock
                                            ? Colors.orange
                                            : Colors.grey[600],
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.primaryContainer,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          displayPrice,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color:
                                Theme.of(
                                  context,
                                ).colorScheme.onPrimaryContainer,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  void _addItem(SaleItem item) {
    setState(() {
      // Vérifier si le produit existe déjà dans la liste
      final existingItemIndex = _items.indexWhere(
        (existingItem) =>
            existingItem.productId == item.productId &&
            existingItem.itemType == item.itemType &&
            existingItem.unitPrice == item.unitPrice,
      );

      if (existingItemIndex >= 0) {
        // Si le produit existe déjà, augmenter la quantité au lieu d'ajouter une nouvelle ligne
        final existingItem = _items[existingItemIndex];
        final updatedQuantity = existingItem.quantity + item.quantity;

        // Calculer les nouveaux totaux
        final updatedTotalPrice = existingItem.unitPrice * updatedQuantity;
        final updatedTotalPriceInCdf =
            existingItem.unitPriceInCdf * updatedQuantity;

        // Créer un nouvel item avec la quantité mise à jour
        final updatedItem = SaleItem(
          productId: existingItem.productId,
          productName: existingItem.productName,
          quantity: updatedQuantity,
          unitPrice: existingItem.unitPrice,
          totalPrice: updatedTotalPrice,
          currencyCode: existingItem.currencyCode,
          exchangeRate: existingItem.exchangeRate,
          unitPriceInCdf: existingItem.unitPriceInCdf,
          totalPriceInCdf: updatedTotalPriceInCdf,
          itemType: existingItem.itemType,
        );

        // Remplacer l'ancien item par le nouveau
        _items[existingItemIndex] = updatedItem;
      } else {
        // Sinon, ajouter un nouvel item
        _items.add(item);
      }

      if (_paymentMethod != 'Crédit') {
        _paidAmount = _calculateTotalInTransactionCurrency();
      }
    });
  }

  /// Affiche un dialog pour éditer un article du panier
  void _showEditItemDialog(int index, SaleItem item) {
    final nameController = TextEditingController(text: item.productName);
    final quantityController = TextEditingController(
      text: item.quantity.toString(),
    );
    final priceController = TextEditingController(
      text: item.unitPrice.toStringAsFixed(2),
    );

    // Extraire les notes sans le préfixe de type
    String currentNotes = '';
    String? typePrefix;
    if (item.notes != null && item.notes!.isNotEmpty) {
      for (final category in QuoteItemCategory.values) {
        final prefix = '[${category.displayName}]';
        if (item.notes!.startsWith(prefix)) {
          typePrefix = prefix;
          currentNotes = item.notes!.substring(prefix.length).trim();
          break;
        }
      }
      if (typePrefix == null) {
        currentNotes = item.notes!;
      }
    }
    final notesController = TextEditingController(text: currentNotes);

    final currencyCode =
        _selectedTransactionCurrency?.code ?? _defaultCurrency.code;
    final currencySymbol =
        _selectedTransactionCurrency?.symbol ?? _defaultCurrency.symbol;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (bottomSheetContext) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            double calculatedTotal = 0;
            final qty = int.tryParse(quantityController.text);
            final price = double.tryParse(priceController.text);
            if (qty != null && price != null) {
              calculatedTotal = qty * price;
            }

            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
                left: 16,
                right: 16,
                top: 16,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            _buildItemLeadingWidget(item),
                            const SizedBox(width: 12),
                            Text(
                              'Modifier l\'article',
                              style: Theme.of(context).textTheme.titleLarge
                                  ?.copyWith(fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                        IconButton(
                          onPressed: () => Navigator.pop(bottomSheetContext),
                          icon: const Icon(Icons.close),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // Libellé / Nom
                    TextFormField(
                      controller: nameController,
                      decoration: const InputDecoration(
                        labelText: 'Libellé',
                        hintText: 'Nom de l\'article ou du service',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.label_outline),
                      ),
                      textCapitalization: TextCapitalization.sentences,
                    ),
                    const SizedBox(height: 16),

                    // Quantité et Prix
                    Row(
                      children: [
                        Expanded(
                          flex: 2,
                          child: TextFormField(
                            controller: quantityController,
                            keyboardType: TextInputType.number,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                            ],
                            decoration: const InputDecoration(
                              labelText: 'Quantité',
                              border: OutlineInputBorder(),
                            ),
                            onChanged: (_) => setStateDialog(() {}),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          flex: 3,
                          child: TextFormField(
                            controller: priceController,
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            inputFormatters: [
                              FilteringTextInputFormatter.allow(
                                RegExp(r'^\d+\.?\d{0,2}'),
                              ),
                            ],
                            decoration: InputDecoration(
                              labelText: 'Prix unitaire',
                              border: const OutlineInputBorder(),
                              prefixText: '$currencySymbol ',
                            ),
                            onChanged: (_) => setStateDialog(() {}),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Notes
                    TextFormField(
                      controller: notesController,
                      decoration: const InputDecoration(
                        labelText: 'Notes (optionnel)',
                        hintText: 'Description ou détails supplémentaires',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.notes),
                      ),
                      maxLines: 2,
                    ),
                    const SizedBox(height: 16),

                    // Résumé du prix
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Theme.of(
                          context,
                        ).colorScheme.primaryContainer.withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Total'),
                          Text(
                            formatCurrency(calculatedTotal, currencyCode),
                            style: Theme.of(
                              context,
                            ).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Boutons
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () {
                              Navigator.pop(bottomSheetContext);
                              _removeItem(index);
                            },
                            icon: const Icon(Icons.delete, color: Colors.red),
                            label: const Text(
                              'Supprimer',
                              style: TextStyle(color: Colors.red),
                            ),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              side: const BorderSide(color: Colors.red),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          flex: 2,
                          child: ElevatedButton.icon(
                            onPressed: () {
                              final newName = nameController.text.trim();
                              final newQty = int.tryParse(
                                quantityController.text,
                              );
                              final newPrice = double.tryParse(
                                priceController.text,
                              );

                              if (newName.isEmpty ||
                                  newQty == null ||
                                  newQty <= 0 ||
                                  newPrice == null ||
                                  newPrice < 0) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      'Veuillez vérifier les valeurs saisies',
                                    ),
                                    backgroundColor: Colors.orange,
                                  ),
                                );
                                return;
                              }

                              // Reconstruire les notes avec le préfixe si nécessaire
                              String? newNotes;
                              if (typePrefix != null) {
                                newNotes = typePrefix;
                                if (notesController.text.isNotEmpty) {
                                  newNotes =
                                      '$newNotes ${notesController.text}';
                                }
                              } else if (notesController.text.isNotEmpty) {
                                newNotes = notesController.text;
                              }

                              // Recalculer les prix
                              final newTotalPrice = newQty * newPrice;
                              final newUnitPriceInCdf =
                                  newPrice * item.exchangeRate;
                              final newTotalPriceInCdf =
                                  newTotalPrice * item.exchangeRate;

                              // Créer l'item mis à jour
                              final updatedItem = SaleItem(
                                productId: item.productId,
                                productName: newName,
                                quantity: newQty,
                                unitPrice: newPrice,
                                totalPrice: newTotalPrice,
                                currencyCode: item.currencyCode,
                                exchangeRate: item.exchangeRate,
                                unitPriceInCdf: newUnitPriceInCdf,
                                totalPriceInCdf: newTotalPriceInCdf,
                                itemType: item.itemType,
                                notes: newNotes,
                              );

                              setState(() {
                                _items[index] = updatedItem;
                                if (_paymentMethod != 'Crédit') {
                                  _paidAmount =
                                      _calculateTotalInTransactionCurrency();
                                }
                              });

                              Navigator.pop(bottomSheetContext);
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Article "$newName" modifié'),
                                  backgroundColor: Colors.green,
                                  duration: const Duration(seconds: 2),
                                ),
                              );
                            },
                            icon: const Icon(Icons.check),
                            label: const Text('Enregistrer'),
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _removeItem(int index) {
    setState(() {
      _items.removeAt(index);
      if (_paymentMethod != 'Crédit') {
        _paidAmount = _calculateTotalInTransactionCurrency();
      }
    });
  }

  double _calculateTotalInTransactionCurrency() {
    // Calcule le sous-total en convertissant le prix de chaque article si nécessaire
    final subtotal = _items.fold(0.0, (total, item) {
      if (item.currencyCode ==
          (_selectedTransactionCurrency?.code ?? _defaultCurrency.code)) {
        // L'article est déjà dans la devise de transaction actuelle
        return total + item.totalPrice;
      } else {
        // Convertit le prix de l'article de sa devise à la devise de transaction actuelle
        double itemValueInCdf = item.totalPriceInCdf;
        double convertedValue = _convertFromCdfToTransactionCurrency(
          itemValueInCdf,
        );
        return total + convertedValue;
      }
    });

    final discount = subtotal * (_discountPercentage / 100);
    return subtotal - discount;
  }

  double _calculateSubtotalInTransactionCurrency() {
    // Même logique de conversion pour le sous-total
    return _items.fold(0.0, (total, item) {
      if (item.currencyCode ==
          (_selectedTransactionCurrency?.code ?? _defaultCurrency.code)) {
        return total + item.totalPrice;
      } else {
        double itemValueInCdf = item.totalPriceInCdf;
        double convertedValue = _convertFromCdfToTransactionCurrency(
          itemValueInCdf,
        );
        return total + convertedValue;
      }
    });
  }

  double _convertFromCdfToTransactionCurrency(double cdfAmount) {
    if (_transactionExchangeRate <= 0) return cdfAmount;
    return cdfAmount / _transactionExchangeRate;
  }

  bool _isPaidFully() {
    final total = _calculateTotalInTransactionCurrency();
    return (_paidAmount - total).abs() < 0.001 || _paidAmount >= total;
  }

  void _saveSale() {
    if (_formKey.currentState!.validate() && _items.isNotEmpty) {
      if (_selectedTransactionCurrency == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Veuillez sélectionner une devise.'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      final totalInTransactionCurrency = _calculateTotalInTransactionCurrency();
      final currentRate = _exchangeRates[_selectedTransactionCurrency!] ?? 1.0;
      final totalInCdf = totalInTransactionCurrency * currentRate;
      final paidInCdf = _paidAmount * currentRate;

      final sale = Sale(
        id: '',
        date: DateTime.now(),
        customerId:
            _linkedCustomerId ??
            'new_cust_ph_${_customerPhoneController.text.isNotEmpty ? _customerPhoneController.text.replaceAll(RegExp(r'[^0-9]'), '') : DateTime.now().millisecondsSinceEpoch}',
        customerName:
            _customerNameController.text.isNotEmpty
                ? _customerNameController.text
                : 'Inconnu',
        items: List<SaleItem>.from(_items),
        totalAmountInCdf: totalInCdf,
        paidAmountInCdf: paidInCdf,
        transactionCurrencyCode: _selectedTransactionCurrency!.code,
        transactionExchangeRate: currentRate,
        totalAmountInTransactionCurrency: totalInTransactionCurrency,
        paidAmountInTransactionCurrency: _paidAmount,
        discountPercentage: _discountPercentage,
        paymentMethod: _paymentMethod,
        status: _isPaidFully() ? SaleStatus.completed : SaleStatus.pending,
        notes: _notesController.text,
      );
      context.read<SalesBloc>().add(AddSale(sale));
    } else if (_items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Veuillez ajouter au moins un article.')),
      );
    }
  }

  String formatNumber(double number, {int decimalDigits = 2}) =>
      number.toStringAsFixed(decimalDigits);
}

// Extension for String.isNotEmpty
extension StringExtension on String {
  String? takeIf(bool Function(String) predicate) {
    return predicate(this) ? this : null;
  }
}

// TODO: Update currency_formatter.dart to use CurrencyEnum instead of old CurrencyType.
// For now, formatCurrency(double amount, String currencyCodeOrSymbol) is assumed to work.

// TODO: [ITEM_TYPE_INTEGRATION] Ensure SaleItemType is correctly imported and used.
// Check if SaleItem model in sale_item.dart has the itemType field and SaleItemType enum.
