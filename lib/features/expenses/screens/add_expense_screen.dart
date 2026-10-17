import 'dart:io'; // Import for File

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import '../../../constants/constants.dart';
import '../../../core/shared_widgets/wanzo_scaffold.dart';
import '../../../core/enums/currency_enum.dart';
import '../../../core/models/currency_settings_model.dart';
import '../../../core/services/currency_service.dart';
import '../../../core/models/operation_payment.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/platform/image_picker/image_picker_service_factory.dart';
import '../../../core/platform/image_picker/image_picker_service_interface.dart';
import '../../../core/widgets/desktop/responsive_form_container.dart';
import '../../../core/widgets/desktop/modal_form_shell.dart';
import '../../../features/settings/presentation/cubit/currency_settings_cubit.dart';
import '../../../features/dashboard/bloc/dashboard_bloc.dart';
import '../../../features/supplier/models/supplier.dart';
import '../../../features/supplier/widgets/supplier_picker_field.dart';
import '../bloc/expense_bloc.dart';
import '../models/expense.dart';
import '../../../core/services/business_context_service.dart';
import '../../../core/shared_widgets/searchable_select.dart';
import '../config/expense_category_config.dart';

class AddExpenseScreen extends StatefulWidget {
  /// Callback appelé après sauvegarde réussie (mode modal).
  /// Si null, la navigation standard (context.pop) est utilisée.
  final VoidCallback? onSaved;

  /// Dépense à modifier (mode édition). Le montant déjà payé n'y est pas
  /// modifiable : les règlements passent par « Régler ».
  final Expense? expense;

  /// Fournisseur pré-sélectionné (ex. « Passer commande » depuis sa fiche).
  final Supplier? initialSupplier;

  const AddExpenseScreen({
    super.key,
    this.onSaved,
    this.expense,
    this.initialSupplier,
  });

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

  /// Précision de la catégorie (« Avance prestataire », « Électricité »…).
  String? _selectedSubCategory;

  /// `true` = l'utilisateur a demandé la liste complète, au-delà de son métier.
  bool _allCategories = false;

  /// Catégories proposées : celles du métier, sauf demande explicite de tout
  /// voir. La catégorie déjà retenue reste dans la liste, sinon le champ
  /// afficherait une valeur absente de ses propres choix.
  List<ExpenseCategory> get _categoryChoices {
    final list = _allCategories
        ? ExpenseCategoryConfig.all
        : ExpenseCategoryConfig.forMode(
            BusinessContextService().activityMode);
    if (!list.contains(_selectedCategory)) {
      return [_selectedCategory, ...list];
    }
    return list;
  }
  String? _selectedPaymentMethod;

  String? _linkedSupplierId;
  Supplier? _foundSupplier;

  final List<File> _imageFiles = [];
  late final ImagePickerServiceInterface _imagePickerService;

  // Currency settings
  Currency? _selectedTransactionCurrency;
  double _transactionExchangeRate = 1.0;
  Map<Currency, double> _exchangeRates = {};

  /// Devise fixée au premier chargement seulement : un rechargement des
  /// réglages ne doit jamais écraser le choix de l'utilisateur.
  bool _deviseInitialisee = false;
  List<Currency> _availableCurrencies = Currency.values;

  bool get _isEdit => widget.expense != null;

  /// Ramène un ancien libellé de mode de paiement vers la liste partagée
  /// (kPaymentMethodOptions). « Crédit » ou « N/A » ne sont pas des modes.
  static String? _normalizeMethod(String? method) {
    if (method == null) return null;
    if (kPaymentMethodOptions.contains(method)) return method;
    switch (method.trim().toLowerCase()) {
      case 'espèce':
      case 'espece':
      case 'cash':
        return 'Espèces';
      case 'carte bancaire':
        return 'Carte bancaire';
      case 'virement':
        return 'Virement bancaire';
      case 'mobile money':
        return 'Mobile Money';
      case 'chèque':
      case 'cheque':
        return 'Chèque';
    }
    return null;
  }

  @override
  void initState() {
    super.initState();
    final e = widget.expense;
    if (e != null) {
      _descriptionController.text = e.motif;
      _amountController.text = e.amount.toStringAsFixed(2);
      _paidAmountController.text = (e.paidAmount ?? 0).toStringAsFixed(2);
      _notesController.text = e.notes ?? '';
      _beneficiaryController.text = e.beneficiary ?? '';
      _supplierNameController.text = e.supplierName ?? '';
      _selectedDate = e.date;
      _selectedCategory = e.category;
      _selectedSubCategory = e.subCategory;
      _selectedPaymentMethod = _normalizeMethod(e.paymentMethod);
      _linkedSupplierId = e.supplierId;
      if (e.supplierId != null && e.supplierId!.isNotEmpty) {
        _foundSupplier = Supplier(
          id: e.supplierId!,
          name: e.supplierName ?? '',
          phoneNumber: '',
          createdAt: DateTime.now(),
        );
      }
    } else if (widget.initialSupplier != null) {
      _foundSupplier = widget.initialSupplier;
      _linkedSupplierId = widget.initialSupplier!.id;
      _supplierNameController.text = widget.initialSupplier!.name;
      _supplierPhoneController.text = widget.initialSupplier!.phoneNumber;
    }
    _imagePickerService = ImagePickerServiceFactory.getInstance();
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
      final premierChargement = !_deviseInitialisee;
      if (premierChargement) {
        _selectedTransactionCurrency = settings.activeCurrency;
      }
      _exchangeRates = {
        Currency.USD: settings.usdToCdfRate,
        Currency.FCFA: settings.fcfaToCdfRate,
        Currency.CDF: 1.0,
      };
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
      if (premierChargement &&
          (_selectedTransactionCurrency == null ||
              !_availableCurrencies.contains(_selectedTransactionCurrency))) {
        _selectedTransactionCurrency =
            _availableCurrencies.isNotEmpty
                ? _availableCurrencies.first
                : settings.activeCurrency;
      }
      // Édition : la devise d'origine de la dépense reste celle affichée.
      final editCode = widget.expense?.currencyCode;
      if (premierChargement && editCode != null) {
        for (final c in Currency.values) {
          if (c.code == editCode) {
            _selectedTransactionCurrency = c;
            break;
          }
        }
      }
      // Le choix déjà fait reste proposé, même si son taux a disparu.
      final choisie = _selectedTransactionCurrency;
      if (choisie != null && !_availableCurrencies.contains(choisie)) {
        _availableCurrencies.add(choisie);
      }
      // 0 = taux manquant : l'enregistrement sera refusé, jamais un 1 muet.
      _transactionExchangeRate =
          _exchangeRates[_selectedTransactionCurrency!] ?? 0;
      _deviseInitialisee = true;
    });
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

  Future<void> _pickImageFromGallery() async {
    try {
      final File? pickedFile = await _imagePickerService.pickFromGallery(
        imageQuality: 70,
      );
      if (pickedFile != null) {
        setState(() {
          _imageFiles.add(pickedFile);
        });
      }
    } catch (e) {
      debugPrint('Error picking image: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur lors de la sélection de l\'image: $e'),
          ),
        );
      }
    }
  }

  Future<void> _pickImageFromCamera() async {
    if (!_imagePickerService.isCameraAvailable) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'La caméra n\'est pas disponible sur cette plateforme. Utilisez la galerie.',
            ),
          ),
        );
      }
      return;
    }
    try {
      final File? pickedFile = await _imagePickerService.pickFromCamera(
        imageQuality: 70,
      );
      if (pickedFile != null) {
        setState(() {
          _imageFiles.add(pickedFile);
        });
      }
    } catch (e) {
      debugPrint('Error picking image from camera: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur lors de la capture de l\'image: $e')),
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
      if (widget.expense == null && paidAmount > amount + 0.001) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Le montant payé dépasse le montant total.'),
          ),
        );
        return;
      }
      // Un mode de paiement n'a de sens que pour la part réellement payée.
      final method = paidAmount > 0 ? _selectedPaymentMethod : null;

      // Devise toujours stockée avec son taux vers le CDF (1 pour CDF) ; une
      // devise étrangère sans taux est refusée. En édition, le taux figé de la
      // dépense est conservé tant que la devise ne change pas.
      final original = widget.expense;
      final devise = _selectedTransactionCurrency ?? Currency.CDF;
      final tauxFige = original != null &&
              devise.code == original.effectiveCurrencyCode &&
              (original.exchangeRate ?? 0) > 0
          ? original.exchangeRate!
          : null;
      final taux =
          devise == Currency.CDF ? 1.0 : (tauxFige ?? _transactionExchangeRate);
      if (!(taux > 0)) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(CurrencyService.missingRateMessage(devise.code))),
        );
        return;
      }

      if (original != null) {
        // Édition : la part payée ne bouge pas ici (règlements via « Régler »).
        final updated = original.copyWith(
          date: _selectedDate,
          motif: _descriptionController.text,
          amount: amount,
          category: _selectedCategory,
          subCategory: _selectedSubCategory,
          paymentMethod: method,
          currencyCode: devise.code,
          notes: _notesController.text,
          beneficiary: _beneficiaryController.text,
          supplierId: _linkedSupplierId,
          supplierName: _supplierNameController.text,
          exchangeRate: taux,
          paymentStatus: _determinePaymentStatus(),
        );
        context.read<ExpenseBloc>().add(UpdateExpense(updated));
        return;
      }

      final newExpense = Expense(
        id: const Uuid().v4(),
        date: _selectedDate,
        motif: _descriptionController.text,
        amount: amount,
        category: _selectedCategory,
        subCategory: _selectedSubCategory,
        paymentMethod: method,
        attachmentUrls: [],
        currencyCode: devise.code,
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
        exchangeRate: taux,
        paymentStatus: _determinePaymentStatus(),
      );

      context.read<ExpenseBloc>().add(
        AddExpense(newExpense, imageFiles: _imageFiles),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final bodyContent = MultiBlocListener(
      listeners: [
        BlocListener<ExpenseBloc, ExpenseState>(
          listener: (context, state) {
            if (state is ExpenseOperationSuccess) {
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(SnackBar(content: Text(state.message)));
              // Cartes « Charges » du tableau de bord à jour.
              context.read<DashboardBloc>().add(
                LoadDashboardData(date: DateTime.now()),
              );
              if (widget.onSaved != null) {
                widget.onSaved!();
              } else {
                context.pop(true);
              }
            } else if (state is ExpenseError) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    state.message.replaceAll('Exception: ', ''),
                  ),
                ),
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
      ],
      child: ResponsiveFormWrapper(
        isModal: widget.onSaved != null,
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
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SearchSelectField<ExpenseCategory>(
                          label: 'Catégorie',
                          hint: 'Sélectionner une catégorie',
                          value: _selectedCategory,
                          items: _categoryChoices,
                          itemLabel: (category) => category.displayName,
                          onChanged: (value) {
                            if (value == null) return;
                            setState(() {
                              _selectedCategory = value;
                              // La sous-catégorie appartient à sa catégorie :
                              // changer de catégorie la remet à zéro plutôt que
                              // de garder un détail qui ne veut plus rien dire.
                              _selectedSubCategory = null;
                            });
                          },
                        ),
                        SearchSelectField<String>(
                          label: 'Précision',
                          hint: 'Préciser (facultatif)',
                          value: _selectedSubCategory,
                          items: ExpenseCategoryConfig.subcategoriesFor(
                              _selectedCategory),
                          itemLabel: (s) => s,
                          onChanged: (value) =>
                              setState(() => _selectedSubCategory = value),
                        ),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: TextButton.icon(
                            onPressed: () => setState(
                                () => _allCategories = !_allCategories),
                            icon: Icon(
                              _allCategories
                                  ? Icons.filter_list
                                  : Icons.filter_list_off,
                              size: 18,
                            ),
                            label: Text(_allCategories
                                ? 'Revenir aux catégories du métier'
                                : 'Voir toutes les catégories'),
                          ),
                        ),
                      ],
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
                                      _exchangeRates[newValue] ?? 0;
                                });
                              }
                            },
                          ),
                          const SizedBox(height: WanzoSpacing.sm),

                          // Exchange Rate Display
                          if ((_selectedTransactionCurrency ?? Currency.CDF) != Currency.CDF)
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
                                    _transactionExchangeRate > 0
                                        ? 'Taux: 1 ${_selectedTransactionCurrency?.code} = ${_transactionExchangeRate.toStringAsFixed(2)} CDF'
                                        : CurrencyService.missingRateMessage(
                                            _selectedTransactionCurrency?.code ?? '',
                                          ),
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
                                '${_selectedTransactionCurrency?.symbol ?? "CDF"} ',
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
                          // Édition : les règlements passent par « Régler ».
                          readOnly: _isEdit,
                          decoration: InputDecoration(
                            labelText: 'Montant payé',
                            helperText: _isEdit
                                ? 'Pour un nouveau paiement, utilisez « Régler » sur la fiche.'
                                : null,
                            prefixText:
                                '${_selectedTransactionCurrency?.symbol ?? "CDF"} ',
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
                                formatCurrency(_calculateRemainingAmount(), _selectedTransactionCurrency?.code ?? "CDF"),
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
                        if ((_selectedTransactionCurrency ?? Currency.CDF) != Currency.CDF &&
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
                                  'Équivalent: ${formatCurrency(_calculateTotalInTransactionCurrency() * _transactionExchangeRate, 'CDF')}',
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

                // Mode de paiement : seulement pour la part réellement payée
                // (jamais « Crédit » ni « N/A », ce ne sont pas des modes).
                if (_calculatePaidAmount() > 0) ...[
                  const SizedBox(height: WanzoSpacing.md),
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
                        value: kPaymentMethodOptions.contains(
                                _selectedPaymentMethod)
                            ? _selectedPaymentMethod
                            : null,
                        decoration: InputDecoration(
                          labelText: 'Mode de paiement',
                          border: InputBorder.none,
                          prefixIcon: Icon(
                            Icons.payment,
                            color: Theme.of(
                              context,
                            ).colorScheme.primary.withAlpha(120),
                          ),
                        ),
                        hint: const Text('Sélectionner un mode'),
                        validator: (v) =>
                            _calculatePaidAmount() > 0 && v == null
                                ? 'Indiquez le mode de paiement.'
                                : null,
                        items: kPaymentMethodOptions.map((String method) {
                          IconData icon;
                          switch (method) {
                            case 'Espèces':
                              icon = Icons.money;
                              break;
                            case 'Mobile Money':
                              icon = Icons.phone_android;
                              break;
                            case 'Carte bancaire':
                              icon = Icons.credit_card;
                              break;
                            case 'Chèque':
                              icon = Icons.account_balance_wallet;
                              break;
                            case 'Virement bancaire':
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
                ],

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
                              _calculatePaidAmount() < _calculateTotalInTransactionCurrency()
                                  ? 'Fournisseur'
                                  : 'Fournisseur (optionnel)',
                              style: Theme.of(context).textTheme.titleMedium
                                  ?.copyWith(fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                        const SizedBox(height: WanzoSpacing.md),
                        // Picker fournisseur partagé : cache Hive complet
                        // (online et offline), recherche serveur en complément,
                        // et création inline sans quitter le formulaire.
                        SupplierPickerField(
                          controller: _supplierNameController,
                          phoneController: _supplierPhoneController,
                          label: 'Nom du fournisseur',
                          hint: 'Rechercher ou creer un fournisseur',
                          initialSupplier: _foundSupplier,
                          // Une dépense à payer (en tout ou en partie) est une
                          // dette : il faut savoir envers quel fournisseur.
                          validator: (_) =>
                              _calculatePaidAmount() <
                                          _calculateTotalInTransactionCurrency() &&
                                      _linkedSupplierId == null
                                  ? 'Choisissez ou créez le fournisseur : la dépense n\x27est pas entièrement payée.'
                                  : null,
                          onSelected: (supplier) {
                            setState(() {
                              _foundSupplier = supplier;
                              _linkedSupplierId = supplier?.id;
                            });
                          },
                        ),
                        const SizedBox(height: WanzoSpacing.md),
                        TextFormField(
                          controller: _supplierPhoneController,
                          keyboardType: TextInputType.phone,
                          decoration: InputDecoration(
                            labelText: 'Numéro de téléphone',
                            hintText: 'Téléphone du fournisseur (optionnel)',
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
                                onPressed: _pickImageFromGallery,
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
                                onPressed:
                                    _imagePickerService.isCameraAvailable
                                        ? _pickImageFromCamera
                                        : null,
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
                        // Le bouton principal s'étend sur toute la largeur du
                        // formulaire (au lieu d'une largeur réduite au contenu).
                        minimumSize: const Size.fromHeight(52),
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
                                    'Enregistrer la dépense',
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

    // Mode modal : en-tête léger (pas de seconde AppBar dans le Dialog)
    if (widget.onSaved != null) {
      return ModalFormShell(
        title: _isEdit ? 'Modifier la dépense' : 'Nouvelle dépense',
        icon: Icons.receipt_long,
        child: bodyContent,
      );
    }

    // Mode page : WanzoScaffold avec navigation
    return WanzoScaffold(
      title: _isEdit ? 'Modifier la dépense' : 'Nouvelle dépense',
      currentIndex: 0,
      body: bodyContent,
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
