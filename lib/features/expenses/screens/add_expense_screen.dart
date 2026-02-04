import 'dart:io'; // Import for File
import 'package:collection/collection.dart'; // Import for firstWhereOrNull

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart'; // Import image_picker
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import '../../../constants/constants.dart';
import '../../../core/shared_widgets/wanzo_scaffold.dart';
import '../../../core/enums/currency_enum.dart';
import '../../../core/models/currency_settings_model.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../features/settings/presentation/cubit/currency_settings_cubit.dart';
import '../../../features/supplier/bloc/supplier_bloc.dart';
import '../../../features/supplier/bloc/supplier_event.dart';
import '../../../features/supplier/bloc/supplier_state.dart';
import '../../../features/supplier/models/supplier.dart';
import '../bloc/expense_bloc.dart';
import '../models/expense.dart';

class AddExpenseScreen extends StatefulWidget {
  const AddExpenseScreen({super.key});

  @override
  State<AddExpenseScreen> createState() => _AddExpenseScreenState();
}

class _AddExpenseScreenState extends State<AddExpenseScreen> {
  final _formKey = GlobalKey<FormState>();
  final _descriptionController = TextEditingController();
  final _amountController = TextEditingController();
  final _paidAmountController = TextEditingController();
  final _notesController = TextEditingController();
  final _beneficiaryController = TextEditingController();
  final _supplierPhoneController = TextEditingController();
  final _supplierNameController = TextEditingController();

  DateTime _selectedDate = DateTime.now();
  ExpenseCategory _selectedCategory = ExpenseCategory.other;
  String? _selectedPaymentMethod;

  String? _linkedSupplierId;
  Supplier? _foundSupplier;

  final List<File> _imageFiles = [];
  final ImagePicker _picker = ImagePicker();

  // Currency settings
  Currency _defaultCurrency = Currency.CDF;
  Currency? _selectedTransactionCurrency;
  double _transactionExchangeRate = 1.0;
  Map<Currency, double> _exchangeRates = {};
  List<Currency> _availableCurrencies = Currency.values;

  final List<String> _paymentMethods = [
    'Espèce',
    'Mobile Money',
    'Carte Bancaire',
    'Chèque',
    'Virement',
    'Crédit',
  ];

  @override
  void initState() {
    super.initState();
    final currencySettingsCubit = context.read<CurrencySettingsCubit>();
    final currentCurrencyState = currencySettingsCubit.state;
    if (currentCurrencyState.status == CurrencySettingsStatus.loaded) {
      _initializeCurrencySettings(currentCurrencyState.settings);
    } else {
      currencySettingsCubit.loadSettings();
    }
  }

  void _initializeCurrencySettings(CurrencySettings settings) {
    setState(() {
      _defaultCurrency = settings.activeCurrency;
      _selectedTransactionCurrency = settings.activeCurrency;
      _exchangeRates = {
        Currency.USD: settings.usdToCdfRate,
        Currency.FCFA: settings.fcfaToCdfRate,
        Currency.CDF: 1.0,
      };
      _transactionExchangeRate = _exchangeRates[settings.activeCurrency] ?? 1.0;
      _availableCurrencies =
          _exchangeRates.keys
              .where((k) => _exchangeRates[k] != null && _exchangeRates[k]! > 0)
              .toList();
      if (!_availableCurrencies.contains(settings.activeCurrency) &&
          (_exchangeRates[settings.activeCurrency] ?? 0) > 0) {
        _availableCurrencies.add(settings.activeCurrency);
      }
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

  Future<void> _searchSupplierByPhone(String phoneNumber) async {
    if (phoneNumber.isEmpty) {
      setState(() {
        _foundSupplier = null;
        _linkedSupplierId = null;
        _supplierNameController.clear();
      });
      return;
    }
    context.read<SupplierBloc>().add(SearchSuppliers(phoneNumber));
  }

  double _calculateTotalInTransactionCurrency() {
    return double.tryParse(_amountController.text) ?? 0.0;
  }

  double _calculatePaidAmount() {
    return double.tryParse(_paidAmountController.text) ?? 0.0;
  }

  double _calculateRemainingAmount() {
    return _calculateTotalInTransactionCurrency() - _calculatePaidAmount();
  }

  Color _getPaymentStatusColor() {
    if (_calculatePaidAmount() >= _calculateTotalInTransactionCurrency()) {
      return Colors.green;
    } else if (_calculatePaidAmount() > 0) {
      return Colors.orange;
    } else if (_selectedPaymentMethod == 'Crédit') {
      return Colors.blue;
    } else {
      return Colors.red;
    }
  }

  String _getPaymentStatusText() {
    final total = _calculateTotalInTransactionCurrency();
    final paid = _calculatePaidAmount();
    if (paid >= total && total > 0) {
      return 'Payé intégralement';
    } else if (paid > 0 && paid < total) {
      return 'Partiellement payé (${formatCurrency(_calculateRemainingAmount(), _selectedTransactionCurrency?.code ?? "CDF")} restant)';
    } else if (_selectedPaymentMethod == 'Crédit') {
      return 'À crédit - Non payé';
    } else {
      return 'Non payé';
    }
  }

  ExpensePaymentStatus _determinePaymentStatus() {
    final total = _calculateTotalInTransactionCurrency();
    final paid = _calculatePaidAmount();
    if (paid >= total && total > 0) {
      return ExpensePaymentStatus.paid;
    } else if (paid > 0 && paid < total) {
      return ExpensePaymentStatus.partial;
    } else if (_selectedPaymentMethod == 'Crédit') {
      return ExpensePaymentStatus.credit;
    } else {
      return ExpensePaymentStatus.unpaid;
    }
  }

  Future<void> _pickDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2101),
      locale: const Locale('fr', 'FR'),
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final XFile? pickedFile = await _picker.pickImage(
        source: source,
        imageQuality: 70, // Compression quality
      );
      if (pickedFile != null) {
        setState(() {
          _imageFiles.add(File(pickedFile.path));
        });
      }
    } catch (e) {
      // Handle exceptions, e.g., permission denied
      debugPrint('Error picking image: $e');
      if (mounted) {
        // Vérification si le widget est toujours monté
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur lors de la sélection de l\'image: $e'),
          ),
        );
      }
    }
  }

  void _removeImage(int index) {
    setState(() {
      _imageFiles.removeAt(index);
    });
  }

  void _submitExpense() {
    if (_formKey.currentState!.validate()) {
      final amount = double.tryParse(_amountController.text);
      if (amount == null || amount <= 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Veuillez entrer un montant valide.')),
        );
        return;
      }

      final paidAmount = double.tryParse(_paidAmountController.text) ?? 0.0;

      final newExpense = Expense(
        id: const Uuid().v4(),
        date: _selectedDate,
        motif: _descriptionController.text,
        amount: amount,
        category: _selectedCategory,
        paymentMethod: _selectedPaymentMethod ?? 'N/A',
        attachmentUrls: [],
        currencyCode: _selectedTransactionCurrency?.code ?? 'CDF',
        notes: _notesController.text.isNotEmpty ? _notesController.text : null,
        beneficiary:
            _beneficiaryController.text.isNotEmpty
                ? _beneficiaryController.text
                : null,
        supplierId: _linkedSupplierId,
        supplierName:
            _supplierNameController.text.isNotEmpty
                ? _supplierNameController.text
                : null,
        paidAmount: paidAmount,
        exchangeRate:
            _selectedTransactionCurrency != _defaultCurrency
                ? _transactionExchangeRate
                : null,
        paymentStatus: _determinePaymentStatus(),
      );

      context.read<ExpenseBloc>().add(
        AddExpense(newExpense, imageFiles: _imageFiles),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return WanzoScaffold(
      title: 'Nouvelle Dépense',
      currentIndex: 0,
      body: MultiBlocListener(
        listeners: [
          BlocListener<ExpenseBloc, ExpenseState>(
            listener: (context, state) {
              if (state is ExpenseOperationSuccess) {
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(SnackBar(content: Text(state.message)));
                context.pop(true);
              } else if (state is ExpenseError) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Erreur: ${state.message}')),
                );
              }
            },
          ),
          BlocListener<CurrencySettingsCubit, CurrencySettingsState>(
            listener: (context, state) {
              if (state.status == CurrencySettingsStatus.loaded) {
                _initializeCurrencySettings(state.settings);
              }
            },
          ),
          BlocListener<SupplierBloc, SupplierState>(
            listener: (context, state) {
              if (state is SupplierSearchResults) {
                // Handle empty suppliers list
                if (state.suppliers.isEmpty) {
                  setState(() {
                    _foundSupplier = null;
                    _linkedSupplierId = null;
                  });
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Aucun fournisseur trouvé'),
                      backgroundColor: Colors.orange,
                    ),
                  );
                  return;
                }

                final searchText = _supplierPhoneController.text.trim();
                // Use firstWhereOrNull to safely handle no match
                final matchedSupplier =
                    state.suppliers.firstWhereOrNull(
                      (s) => s.phoneNumber == searchText,
                    ) ??
                    state.suppliers.first;

                setState(() {
                  _foundSupplier = matchedSupplier;
                  _linkedSupplierId = matchedSupplier.id;
                  _supplierNameController.text = matchedSupplier.name;
                });

                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      'Fournisseur trouvé: ${matchedSupplier.name}',
                    ),
                    backgroundColor: Colors.green,
                  ),
                );
              } else if (state is SupplierError) {
                setState(() {
                  _foundSupplier = null;
                  _linkedSupplierId = null;
                });

                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Aucun fournisseur trouvé'),
                    backgroundColor: Colors.orange,
                  ),
                );
              }
            },
          ),
        ],
        child: Padding(
          padding: const EdgeInsets.all(WanzoSpacing.md),
          child: Form(
            key: _formKey,
            child: ListView(
              children: <Widget>[
                // Carte pour la date
                Card(
                  elevation: 1,
                  margin: EdgeInsets.zero,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(WanzoRadius.sm),
                    side: BorderSide(
                      color: Theme.of(
                        context,
                      ).colorScheme.outline.withAlpha(100),
                    ),
                  ),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(WanzoRadius.sm),
                    onTap: () => _pickDate(context),
                    child: Padding(
                      padding: const EdgeInsets.all(WanzoSpacing.md),
                      child: Row(
                        children: [
                          Icon(
                            Icons.calendar_today,
                            color: Theme.of(context).colorScheme.primary,
                            size: 20,
                          ),
                          const SizedBox(width: WanzoSpacing.sm),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Date de la dépense',
                                  style: Theme.of(
                                    context,
                                  ).textTheme.bodySmall?.copyWith(
                                    color:
                                        Theme.of(context).colorScheme.secondary,
                                  ),
                                ),
                                Text(
                                  DateFormat(
                                    'dd MMMM yyyy',
                                    'fr_FR',
                                  ).format(_selectedDate),
                                  style: Theme.of(context).textTheme.titleMedium
                                      ?.copyWith(fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                          ),
                          Icon(
                            Icons.arrow_forward_ios,
                            color: Theme.of(
                              context,
                            ).colorScheme.onSurface.withAlpha(100),
                            size: 16,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: WanzoSpacing.md),

                // Description avec design amélioré
                TextFormField(
                  controller: _descriptionController,
                  decoration: InputDecoration(
                    labelText: 'Motif',
                    prefixIcon: Icon(
                      Icons.description,
                      color: Theme.of(
                        context,
                      ).colorScheme.primary.withAlpha(120),
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(WanzoRadius.sm),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(WanzoRadius.sm),
                      borderSide: BorderSide(
                        color: Theme.of(context).colorScheme.primary,
                        width: 2,
                      ),
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Veuillez entrer un motif.';
                    }
                    return null;
                  },
                ),

                const SizedBox(height: WanzoSpacing.md),

                // Catégorie avec design amélioré
                Card(
                  elevation: 1,
                  margin: EdgeInsets.zero,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(WanzoRadius.sm),
                    side: BorderSide(
                      color: Theme.of(
                        context,
                      ).colorScheme.outline.withAlpha(100),
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: WanzoSpacing.sm,
                    ),
                    child: Autocomplete<ExpenseCategory>(
                      initialValue: TextEditingValue(
                        text: _selectedCategory.displayName,
                      ),
                      optionsBuilder: (TextEditingValue textEditingValue) {
                        if (textEditingValue.text.isEmpty) {
                          return ExpenseCategory.values;
                        }
                        return ExpenseCategory.values.where((category) {
                          final displayName =
                              category.displayName.toLowerCase();
                          final searchText =
                              textEditingValue.text.toLowerCase();
                          return displayName.contains(searchText);
                        });
                      },
                      displayStringForOption:
                          (ExpenseCategory category) => category.displayName,
                      onSelected: (ExpenseCategory selection) {
                        setState(() {
                          _selectedCategory = selection;
                        });
                      },
                      fieldViewBuilder: (
                        BuildContext context,
                        TextEditingController textEditingController,
                        FocusNode focusNode,
                        VoidCallback onFieldSubmitted,
                      ) {
                        return TextFormField(
                          controller: textEditingController,
                          focusNode: focusNode,
                          onFieldSubmitted: (String value) {
                            onFieldSubmitted();
                          },
                          decoration: InputDecoration(
                            labelText: 'Catégorie',
                            border: InputBorder.none,
                            prefixIcon: Icon(
                              _selectedCategory.icon,
                              color: Theme.of(
                                context,
                              ).colorScheme.primary.withAlpha(120),
                            ),
                          ),
                        );
                      },
                      optionsViewBuilder: (
                        BuildContext context,
                        AutocompleteOnSelected<ExpenseCategory> onSelected,
                        Iterable<ExpenseCategory> options,
                      ) {
                        return Align(
                          alignment: Alignment.topLeft,
                          child: Material(
                            elevation: 4.0,
                            child: Container(
                              width: 300,
                              constraints: const BoxConstraints(maxHeight: 200),
                              child: ListView.builder(
                                padding: const EdgeInsets.all(8.0),
                                itemCount: options.length,
                                itemBuilder: (BuildContext context, int index) {
                                  final option = options.elementAt(index);
                                  return ListTile(
                                    leading: Icon(option.icon, size: 18),
                                    title: Text(option.displayName),
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
                    ),
                  ),
                ),

                const SizedBox(height: WanzoSpacing.md),

                // Informations de paiement
                Card(
                  margin: const EdgeInsets.symmetric(vertical: WanzoSpacing.xs),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(WanzoRadius.sm),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(WanzoSpacing.md),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.payments,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                            const SizedBox(width: WanzoSpacing.sm),
                            Text(
                              'Informations de paiement',
                              style: Theme.of(context).textTheme.titleMedium
                                  ?.copyWith(fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                        const SizedBox(height: WanzoSpacing.md),

                        // Currency Selector (only show if multiple currencies available)
                        if (_availableCurrencies.length > 1) ...[
                          DropdownButtonFormField<Currency>(
                            value: _selectedTransactionCurrency,
                            decoration: InputDecoration(
                              labelText: 'Devise de transaction',
                              filled: true,
                              fillColor: Theme.of(context)
                                  .colorScheme
                                  .surfaceContainerHighest
                                  .withAlpha(76),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(
                                  WanzoRadius.sm,
                                ),
                                borderSide: BorderSide.none,
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: WanzoSpacing.md,
                                vertical: WanzoSpacing.sm,
                              ),
                            ),
                            items:
                                _availableCurrencies.map((Currency currency) {
                                  return DropdownMenuItem<Currency>(
                                    value: currency,
                                    child: Text(
                                      '${currency.code} - ${currency.symbol}',
                                    ),
                                  );
                                }).toList(),
                            onChanged: (Currency? newValue) {
                              if (newValue != null) {
                                setState(() {
                                  _selectedTransactionCurrency = newValue;
                                  _transactionExchangeRate =
                                      _exchangeRates[newValue] ?? 1.0;
                                });
                              }
                            },
                          ),
                          const SizedBox(height: WanzoSpacing.sm),

                          // Exchange Rate Display
                          if (_selectedTransactionCurrency != _defaultCurrency)
                            Container(
                              padding: const EdgeInsets.all(WanzoSpacing.sm),
                              decoration: BoxDecoration(
                                color: Theme.of(
                                  context,
                                ).colorScheme.primaryContainer.withAlpha(102),
                                borderRadius: BorderRadius.circular(
                                  WanzoRadius.sm,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.info_outline,
                                    size: 16,
                                    color:
                                        Theme.of(
                                          context,
                                        ).colorScheme.onPrimaryContainer,
                                  ),
                                  const SizedBox(width: WanzoSpacing.xs),
                                  Text(
                                    'Taux: 1 ${_selectedTransactionCurrency?.code} = ${_transactionExchangeRate.toStringAsFixed(2)} ${_defaultCurrency.code}',
                                    style: Theme.of(
                                      context,
                                    ).textTheme.bodySmall?.copyWith(
                                      color:
                                          Theme.of(
                                            context,
                                          ).colorScheme.onPrimaryContainer,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          const SizedBox(height: WanzoSpacing.md),
                        ],

                        // Total Amount
                        TextFormField(
                          controller: _amountController,
                          decoration: InputDecoration(
                            labelText: 'Montant total',
                            prefixText:
                                '${_selectedTransactionCurrency?.symbol ?? "FC"} ',
                            filled: true,
                            fillColor: Theme.of(
                              context,
                            ).colorScheme.surfaceContainerHighest.withAlpha(76),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(
                                WanzoRadius.sm,
                              ),
                              borderSide: BorderSide.none,
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: WanzoSpacing.md,
                              vertical: WanzoSpacing.md,
                            ),
                          ),
                          keyboardType: TextInputType.number,
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Veuillez entrer un montant.';
                            }
                            if (double.tryParse(value) == null ||
                                double.parse(value) <= 0) {
                              return 'Veuillez entrer un montant valide.';
                            }
                            return null;
                          },
                          onChanged: (value) => setState(() {}),
                        ),
                        const SizedBox(height: WanzoSpacing.md),

                        // Paid Amount
                        TextFormField(
                          controller: _paidAmountController,
                          decoration: InputDecoration(
                            labelText: 'Montant payé',
                            prefixText:
                                '${_selectedTransactionCurrency?.symbol ?? "FC"} ',
                            filled: true,
                            fillColor: Theme.of(
                              context,
                            ).colorScheme.surfaceContainerHighest.withAlpha(76),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(
                                WanzoRadius.sm,
                              ),
                              borderSide: BorderSide.none,
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: WanzoSpacing.md,
                              vertical: WanzoSpacing.md,
                            ),
                          ),
                          keyboardType: TextInputType.number,
                          onChanged: (value) => setState(() {}),
                        ),
                        const SizedBox(height: WanzoSpacing.md),

                        // Remaining Amount Display
                        Container(
                          padding: const EdgeInsets.all(WanzoSpacing.md),
                          decoration: BoxDecoration(
                            color: Theme.of(context)
                                .colorScheme
                                .surfaceContainerHighest
                                .withAlpha(127),
                            borderRadius: BorderRadius.circular(WanzoRadius.sm),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Reste à payer:',
                                style: Theme.of(context).textTheme.bodyLarge
                                    ?.copyWith(fontWeight: FontWeight.bold),
                              ),
                              Text(
                                '${_selectedTransactionCurrency?.symbol ?? "FC"} ${_calculateRemainingAmount().toStringAsFixed(2)}',
                                style: Theme.of(
                                  context,
                                ).textTheme.bodyLarge?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color:
                                      _calculateRemainingAmount() > 0
                                          ? Theme.of(context).colorScheme.error
                                          : Colors.green,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: WanzoSpacing.md),

                        // Dual Currency Display (if non-CDF)
                        if (_selectedTransactionCurrency != _defaultCurrency &&
                            _calculateTotalInTransactionCurrency() > 0)
                          Container(
                            padding: const EdgeInsets.all(WanzoSpacing.sm),
                            decoration: BoxDecoration(
                              color: Theme.of(
                                context,
                              ).colorScheme.tertiaryContainer.withAlpha(102),
                              borderRadius: BorderRadius.circular(
                                WanzoRadius.sm,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.currency_exchange,
                                  size: 16,
                                  color:
                                      Theme.of(
                                        context,
                                      ).colorScheme.onTertiaryContainer,
                                ),
                                const SizedBox(width: WanzoSpacing.xs),
                                Text(
                                  'Équivalent: ${_defaultCurrency.symbol} ${(_calculateTotalInTransactionCurrency() * _transactionExchangeRate).toStringAsFixed(2)}',
                                  style: Theme.of(
                                    context,
                                  ).textTheme.bodySmall?.copyWith(
                                    color:
                                        Theme.of(
                                          context,
                                        ).colorScheme.onTertiaryContainer,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        const SizedBox(height: WanzoSpacing.md),

                        // Payment Status Indicator
                        Container(
                          padding: const EdgeInsets.all(WanzoSpacing.md),
                          decoration: BoxDecoration(
                            color: _getPaymentStatusColor().withAlpha(51),
                            borderRadius: BorderRadius.circular(WanzoRadius.sm),
                            border: Border.all(
                              color: _getPaymentStatusColor(),
                              width: 2,
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.info_outline,
                                color: _getPaymentStatusColor(),
                              ),
                              const SizedBox(width: WanzoSpacing.sm),
                              Expanded(
                                child: Text(
                                  _getPaymentStatusText(),
                                  style: Theme.of(
                                    context,
                                  ).textTheme.bodyMedium?.copyWith(
                                    color: _getPaymentStatusColor(),
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: WanzoSpacing.md),

                // Méthode de paiement
                Card(
                  elevation: 1,
                  margin: EdgeInsets.zero,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(WanzoRadius.sm),
                    side: BorderSide(
                      color: Theme.of(
                        context,
                      ).colorScheme.outline.withAlpha(100),
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: WanzoSpacing.sm,
                    ),
                    child: DropdownButtonFormField<String>(
                      value: _selectedPaymentMethod,
                      decoration: InputDecoration(
                        labelText: 'Méthode de Paiement',
                        border: InputBorder.none,
                        prefixIcon: Icon(
                          Icons.payment,
                          color: Theme.of(
                            context,
                          ).colorScheme.primary.withAlpha(120),
                        ),
                      ),
                      hint: const Text('Sélectionner une méthode'),
                      items:
                          _paymentMethods.map((String method) {
                            IconData icon;
                            switch (method) {
                              case 'Espèce':
                                icon = Icons.money;
                                break;
                              case 'Mobile Money':
                                icon = Icons.phone_android;
                                break;
                              case 'Carte Bancaire':
                                icon = Icons.credit_card;
                                break;
                              case 'Chèque':
                                icon = Icons.account_balance_wallet;
                                break;
                              case 'Virement':
                                icon = Icons.account_balance;
                                break;
                              default:
                                icon = Icons.payment;
                            }

                            return DropdownMenuItem<String>(
                              value: method,
                              child: Row(
                                children: [
                                  Icon(icon, size: 18),
                                  const SizedBox(width: WanzoSpacing.sm),
                                  Text(method),
                                ],
                              ),
                            );
                          }).toList(),
                      onChanged: (String? newValue) {
                        setState(() {
                          _selectedPaymentMethod = newValue;
                        });
                      },
                    ),
                  ),
                ),

                const SizedBox(height: WanzoSpacing.md),

                // Informations fournisseur
                Card(
                  margin: const EdgeInsets.symmetric(vertical: WanzoSpacing.xs),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(WanzoRadius.sm),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(WanzoSpacing.md),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.business,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                            const SizedBox(width: WanzoSpacing.sm),
                            Text(
                              'Informations fournisseur (optionnel)',
                              style: Theme.of(context).textTheme.titleMedium
                                  ?.copyWith(fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                        const SizedBox(height: WanzoSpacing.md),
                        BlocBuilder<SupplierBloc, SupplierState>(
                          builder: (context, supplierState) {
                            final allSuppliers =
                                supplierState is SupplierSearchResults
                                    ? supplierState.suppliers
                                    : (supplierState is SuppliersLoaded
                                        ? supplierState.suppliers
                                        : <Supplier>[]);

                            return Autocomplete<Supplier>(
                              optionsBuilder: (
                                TextEditingValue textEditingValue,
                              ) {
                                if (textEditingValue.text.isEmpty) {
                                  return const Iterable<Supplier>.empty();
                                }

                                // Rechercher en temps réel
                                _searchSupplierByPhone(textEditingValue.text);

                                return allSuppliers.where((Supplier supplier) {
                                  return supplier.phoneNumber
                                          .toLowerCase()
                                          .contains(
                                            textEditingValue.text.toLowerCase(),
                                          ) ||
                                      supplier.name.toLowerCase().contains(
                                        textEditingValue.text.toLowerCase(),
                                      );
                                });
                              },
                              displayStringForOption:
                                  (Supplier option) => option.phoneNumber,
                              onSelected: (Supplier selection) {
                                setState(() {
                                  _foundSupplier = selection;
                                  _linkedSupplierId = selection.id;
                                  _supplierPhoneController.text =
                                      selection.phoneNumber;
                                  _supplierNameController.text = selection.name;
                                });
                              },
                              fieldViewBuilder: (
                                context,
                                textEditingController,
                                focusNode,
                                onFieldSubmitted,
                              ) {
                                // Synchroniser avec notre controller
                                if (_supplierPhoneController.text !=
                                    textEditingController.text) {
                                  textEditingController.text =
                                      _supplierPhoneController.text;
                                }

                                textEditingController.addListener(() {
                                  if (_supplierPhoneController.text !=
                                      textEditingController.text) {
                                    _supplierPhoneController.text =
                                        textEditingController.text;

                                    // Réinitialiser si le texte change
                                    if (_foundSupplier != null &&
                                        _foundSupplier!.phoneNumber !=
                                            textEditingController.text) {
                                      setState(() {
                                        _foundSupplier = null;
                                        _linkedSupplierId = null;
                                        _supplierNameController.clear();
                                      });
                                    }
                                  }
                                });

                                return TextFormField(
                                  controller: textEditingController,
                                  focusNode: focusNode,
                                  decoration: InputDecoration(
                                    labelText: 'Numéro de téléphone',
                                    hintText:
                                        'Rechercher un fournisseur (optionnel)',
                                    filled: true,
                                    fillColor: Theme.of(context)
                                        .colorScheme
                                        .surfaceContainerHighest
                                        .withAlpha(76),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(
                                        WanzoRadius.sm,
                                      ),
                                      borderSide: BorderSide.none,
                                    ),
                                    contentPadding: const EdgeInsets.symmetric(
                                      horizontal: WanzoSpacing.md,
                                      vertical: WanzoSpacing.md,
                                    ),
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
                                          final Supplier option = options
                                              .elementAt(index);
                                          return ListTile(
                                            leading: const Icon(
                                              Icons.business,
                                              size: 20,
                                            ),
                                            title: Text(option.name),
                                            subtitle: Text(option.phoneNumber),
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
                          controller: _supplierNameController,
                          decoration: InputDecoration(
                            labelText: 'Nom du fournisseur',
                            filled: true,
                            fillColor:
                                _foundSupplier != null
                                    ? Colors.green.withAlpha(51)
                                    : Theme.of(context)
                                        .colorScheme
                                        .surfaceContainerHighest
                                        .withAlpha(76),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(
                                WanzoRadius.sm,
                              ),
                              borderSide: BorderSide.none,
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: WanzoSpacing.md,
                              vertical: WanzoSpacing.md,
                            ),
                            suffixIcon:
                                _foundSupplier != null
                                    ? const Icon(
                                      Icons.check_circle,
                                      color: Colors.green,
                                    )
                                    : null,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: WanzoSpacing.lg),

                // Section pièces justificatives améliorée
                Card(
                  elevation: 1,
                  margin: EdgeInsets.zero,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(WanzoRadius.sm),
                    side: BorderSide(
                      color: Theme.of(
                        context,
                      ).colorScheme.outline.withAlpha(100),
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(WanzoSpacing.md),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.attach_file,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                            const SizedBox(width: WanzoSpacing.sm),
                            Text(
                              'Pièces justificatives',
                              style: Theme.of(context).textTheme.titleMedium
                                  ?.copyWith(fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                        const SizedBox(height: WanzoSpacing.md),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            Expanded(
                              child: ElevatedButton.icon(
                                icon: const Icon(Icons.photo_library),
                                label: const Text('Galerie'),
                                onPressed:
                                    () => _pickImage(ImageSource.gallery),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor:
                                      Theme.of(
                                        context,
                                      ).colorScheme.primaryContainer,
                                  foregroundColor:
                                      Theme.of(
                                        context,
                                      ).colorScheme.onPrimaryContainer,
                                  padding: const EdgeInsets.symmetric(
                                    vertical: WanzoSpacing.sm,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: WanzoSpacing.md),
                            Expanded(
                              child: ElevatedButton.icon(
                                icon: const Icon(Icons.camera_alt),
                                label: const Text('Caméra'),
                                onPressed: () => _pickImage(ImageSource.camera),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor:
                                      Theme.of(
                                        context,
                                      ).colorScheme.primaryContainer,
                                  foregroundColor:
                                      Theme.of(
                                        context,
                                      ).colorScheme.onPrimaryContainer,
                                  padding: const EdgeInsets.symmetric(
                                    vertical: WanzoSpacing.sm,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: WanzoSpacing.md),
                        if (_imageFiles.isNotEmpty)
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Divider(),
                              const SizedBox(height: WanzoSpacing.sm),
                              Text(
                                'Images ajoutées (${_imageFiles.length})',
                                style: Theme.of(context).textTheme.bodyMedium
                                    ?.copyWith(fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: WanzoSpacing.sm),
                              SizedBox(
                                height: 120,
                                child: ListView.builder(
                                  scrollDirection: Axis.horizontal,
                                  itemCount: _imageFiles.length,
                                  itemBuilder: (context, index) {
                                    return Padding(
                                      padding: const EdgeInsets.only(
                                        right: WanzoSpacing.sm,
                                      ),
                                      child: Stack(
                                        children: [
                                          Card(
                                            elevation: 2,
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(
                                                    WanzoRadius.md,
                                                  ),
                                            ),
                                            child: ClipRRect(
                                              borderRadius:
                                                  BorderRadius.circular(
                                                    WanzoRadius.md,
                                                  ),
                                              child: Image.file(
                                                _imageFiles[index],
                                                height: 100,
                                                width: 100,
                                                fit: BoxFit.cover,
                                              ),
                                            ),
                                          ),
                                          Positioned(
                                            top: 0,
                                            right: 0,
                                            child: InkWell(
                                              onTap: () => _removeImage(index),
                                              child: Container(
                                                padding: const EdgeInsets.all(
                                                  2,
                                                ),
                                                decoration: BoxDecoration(
                                                  color: Colors.red.withAlpha(
                                                    204,
                                                  ), // Remplacé withOpacity(0.8) par withAlpha(204)
                                                  shape: BoxShape.circle,
                                                ),
                                                child: const Icon(
                                                  Icons.close,
                                                  color: Colors.white,
                                                  size: 18,
                                                ),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    );
                                  },
                                ),
                              ),
                            ],
                          ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: WanzoSpacing.md),

                // Note: Currency selection moved to Payment Tracking section above
                const SizedBox(height: WanzoSpacing.md),

                // Bénéficiaire
                Card(
                  margin: const EdgeInsets.symmetric(vertical: WanzoSpacing.xs),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(WanzoRadius.sm),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(WanzoSpacing.md),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Bénéficiaire (optionnel)',
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: WanzoSpacing.sm),
                        TextFormField(
                          controller: _beneficiaryController,
                          decoration: InputDecoration(
                            hintText: 'Nom du bénéficiaire',
                            filled: true,
                            fillColor: Theme.of(
                              context,
                            ).colorScheme.surfaceContainerHighest.withAlpha(
                              76,
                            ), // Remplacé surfaceVariant.withOpacity(0.3)
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(
                                WanzoRadius.sm,
                              ),
                              borderSide: BorderSide.none,
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: WanzoSpacing.md,
                              vertical: WanzoSpacing.md,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: WanzoSpacing.md),

                // Notes
                Card(
                  margin: const EdgeInsets.symmetric(vertical: WanzoSpacing.xs),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(WanzoRadius.sm),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(WanzoSpacing.md),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Notes (optionnel)',
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: WanzoSpacing.sm),
                        TextFormField(
                          controller: _notesController,
                          decoration: InputDecoration(
                            hintText: 'Notes supplémentaires...',
                            filled: true,
                            fillColor: Theme.of(
                              context,
                            ).colorScheme.surfaceContainerHighest.withAlpha(
                              76,
                            ), // Remplacé surfaceVariant.withOpacity(0.3)
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(
                                WanzoRadius.sm,
                              ),
                              borderSide: BorderSide.none,
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: WanzoSpacing.md,
                              vertical: WanzoSpacing.md,
                            ),
                          ),
                          maxLines: 3,
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: WanzoSpacing.xl),

                // Bouton d'enregistrement amélioré
                BlocBuilder<ExpenseBloc, ExpenseState>(
                  builder: (context, state) {
                    return ElevatedButton(
                      onPressed:
                          state is ExpenseLoading ? null : _submitExpense,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: WanzoColors.primary,
                        padding: const EdgeInsets.symmetric(
                          vertical: WanzoSpacing.md,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(WanzoRadius.sm),
                        ),
                      ),
                      child:
                          state is ExpenseLoading
                              ? const SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                              : const Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.save, color: Colors.white),
                                  SizedBox(width: WanzoSpacing.sm),
                                  Text(
                                    'Enregistrer la Dépense',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 16,
                                    ),
                                  ),
                                ],
                              ),
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    _amountController.dispose();
    _paidAmountController.dispose();
    _notesController.dispose();
    _beneficiaryController.dispose();
    _supplierPhoneController.dispose();
    _supplierNameController.dispose();
    super.dispose();
  }
}
