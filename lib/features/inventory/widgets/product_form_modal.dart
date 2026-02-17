import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:uuid/uuid.dart';
import 'package:wanzo/core/widgets/desktop/adaptive_modal.dart';
import 'package:wanzo/core/widgets/desktop/form_layout_widgets.dart';
import 'package:wanzo/core/enums/currency_enum.dart';
import 'package:wanzo/core/services/currency_service.dart';
import 'package:wanzo/features/settings/presentation/cubit/currency_settings_cubit.dart';
import '../bloc/inventory_bloc.dart';
import '../bloc/inventory_event.dart';
import '../bloc/inventory_state.dart';
import '../models/product.dart';

/// Modal pour ajouter ou modifier un produit
/// Utilise AdaptiveModal pour une présentation professionnelle desktop
class ProductFormModal extends StatefulWidget {
  /// Produit à modifier (null pour un nouveau produit)
  final Product? product;

  /// Callback appelé après succès
  final VoidCallback? onSuccess;

  const ProductFormModal({super.key, this.product, this.onSuccess});

  /// Affiche la modal de formulaire produit
  static Future<bool?> show(
    BuildContext context, {
    Product? product,
    VoidCallback? onSuccess,
  }) {
    return AdaptiveModal.show<bool>(
      context: context,
      title: product != null ? 'Modifier le produit' : 'Nouveau produit',
      subtitle:
          product != null
              ? 'Mettre à jour les informations du produit'
              : 'Ajouter un produit au stock',
      headerIcon: Icons.inventory_2,
      headerIconColor: Colors.teal,
      size: ModalSize.large,
      child: ProductFormModal(product: product, onSuccess: onSuccess),
    );
  }

  @override
  State<ProductFormModal> createState() => _ProductFormModalState();
}

class _ProductFormModalState extends State<ProductFormModal> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _nameController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _barcodeController;
  late final TextEditingController _costPriceController;
  late final TextEditingController _sellingPriceController;
  late final TextEditingController _stockQuantityController;
  late final TextEditingController _alertThresholdController;

  late ProductCategory _selectedCategory;
  late ProductUnit _selectedUnit;
  Currency? _selectedInputCurrency;
  Currency _appActiveCurrency = Currency.CDF;
  bool _isSubmitting = false;

  bool get _isEditing => widget.product != null;

  @override
  void initState() {
    super.initState();

    _nameController = TextEditingController(text: widget.product?.name ?? '');
    _descriptionController = TextEditingController(
      text: widget.product?.description ?? '',
    );
    _barcodeController = TextEditingController(
      text: widget.product?.barcode ?? '',
    );

    // Currency settings
    final currencySettingsCubit = context.read<CurrencySettingsCubit>();
    final currencySettingsState = currencySettingsCubit.state;

    if (currencySettingsState.status == CurrencySettingsStatus.loaded) {
      _appActiveCurrency = currencySettingsState.settings.activeCurrency;
      if (_isEditing && widget.product != null) {
        _selectedInputCurrency = Currency.values.firstWhere(
          (c) => c.code == widget.product!.inputCurrencyCode,
          orElse: () => _appActiveCurrency,
        );
        _costPriceController = TextEditingController(
          text: widget.product!.costPriceInInputCurrency.toStringAsFixed(2),
        );
        _sellingPriceController = TextEditingController(
          text: widget.product!.sellingPriceInInputCurrency.toStringAsFixed(2),
        );
      } else {
        _selectedInputCurrency = _appActiveCurrency;
        _costPriceController = TextEditingController();
        _sellingPriceController = TextEditingController();
      }
    } else {
      _selectedInputCurrency = Currency.CDF;
      _costPriceController = TextEditingController(
        text: widget.product?.costPriceInInputCurrency.toStringAsFixed(2) ?? '',
      );
      _sellingPriceController = TextEditingController(
        text:
            widget.product?.sellingPriceInInputCurrency.toStringAsFixed(2) ??
            '',
      );
    }

    _stockQuantityController = TextEditingController(
      text: widget.product?.stockQuantity.toString() ?? '0',
    );
    _alertThresholdController = TextEditingController(
      text: widget.product?.alertThreshold.toString() ?? '5',
    );

    _selectedCategory = widget.product?.category ?? ProductCategory.other;
    _selectedUnit = widget.product?.unit ?? ProductUnit.piece;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _barcodeController.dispose();
    _costPriceController.dispose();
    _sellingPriceController.dispose();
    _stockQuantityController.dispose();
    _alertThresholdController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<InventoryBloc, InventoryState>(
      listener: (context, state) {
        if (state is InventoryOperationSuccess) {
          widget.onSuccess?.call();
          Navigator.of(context).pop(true);
        } else if (state is InventoryError) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Erreur: ${state.message}'),
              backgroundColor: Colors.red,
            ),
          );
          setState(() => _isSubmitting = false);
        }
      },
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Section: Informations produit
            FormSection(
              title: 'Informations produit',
              description: 'Nom, catégorie et référence du produit',
              icon: Icons.info_outline,
              iconColor: Colors.teal,
              child: FormGridLayout(
                desktopColumns: 2,
                children: [
                  // Nom
                  FormFieldContainer(
                    label: 'Nom du produit',
                    isRequired: true,
                    child: TextFormField(
                      controller: _nameController,
                      decoration: InputDecoration(
                        hintText: 'Ex: Sac de riz 25kg',
                        prefixIcon: const Icon(Icons.inventory),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Le nom est requis';
                        }
                        return null;
                      },
                    ),
                  ),

                  // Catégorie
                  FormFieldContainer(
                    label: 'Catégorie',
                    isRequired: true,
                    child: DropdownButtonFormField<ProductCategory>(
                      value: _selectedCategory,
                      decoration: InputDecoration(
                        prefixIcon: const Icon(Icons.category),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      items:
                          ProductCategory.values.map((cat) {
                            return DropdownMenuItem(
                              value: cat,
                              child: Text(cat.displayName),
                            );
                          }).toList(),
                      onChanged: (value) {
                        if (value != null) {
                          setState(() => _selectedCategory = value);
                        }
                      },
                    ),
                  ),

                  // Description
                  FormFieldContainer(
                    label: 'Description',
                    helpText: 'Optionnel',
                    child: TextFormField(
                      controller: _descriptionController,
                      decoration: InputDecoration(
                        prefixIcon: const Icon(Icons.description),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ),

                  // Unité + Code-barres
                  FormFieldContainer(
                    label: 'Unité de mesure',
                    isRequired: true,
                    child: DropdownButtonFormField<ProductUnit>(
                      value: _selectedUnit,
                      decoration: InputDecoration(
                        prefixIcon: const Icon(Icons.straighten),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      items:
                          ProductUnit.values.map((unit) {
                            return DropdownMenuItem(
                              value: unit,
                              child: Text(_unitDisplayName(unit)),
                            );
                          }).toList(),
                      onChanged: (value) {
                        if (value != null) {
                          setState(() => _selectedUnit = value);
                        }
                      },
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // Section: Prix
            FormSection(
              title: 'Prix',
              description:
                  'Prix d\'achat et de vente en ${_selectedInputCurrency?.code ?? 'CDF'}',
              icon: Icons.attach_money,
              iconColor: Colors.green,
              child: FormGridLayout(
                desktopColumns: 2,
                children: [
                  // Prix d'achat
                  FormFieldContainer(
                    label:
                        'Prix d\'achat (${_selectedInputCurrency?.code ?? 'CDF'})',
                    isRequired: true,
                    child: TextFormField(
                      controller: _costPriceController,
                      decoration: InputDecoration(
                        prefixIcon: const Icon(Icons.shopping_cart),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                      ],
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Le prix d\'achat est requis';
                        }
                        if (double.tryParse(value) == null) {
                          return 'Prix invalide';
                        }
                        return null;
                      },
                    ),
                  ),

                  // Prix de vente
                  FormFieldContainer(
                    label:
                        'Prix de vente (${_selectedInputCurrency?.code ?? 'CDF'})',
                    isRequired: true,
                    child: TextFormField(
                      controller: _sellingPriceController,
                      decoration: InputDecoration(
                        prefixIcon: const Icon(Icons.sell),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                      ],
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Le prix de vente est requis';
                        }
                        if (double.tryParse(value) == null) {
                          return 'Prix invalide';
                        }
                        return null;
                      },
                    ),
                  ),

                  // Code-barres
                  FormFieldContainer(
                    label: 'Code-barres / Référence',
                    helpText: 'Optionnel',
                    child: TextFormField(
                      controller: _barcodeController,
                      decoration: InputDecoration(
                        prefixIcon: const Icon(Icons.qr_code),
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

            // Section: Stock
            FormSection(
              title: 'Stock',
              description: 'Quantité initiale et seuil d\'alerte',
              icon: Icons.warehouse,
              iconColor: Colors.orange,
              child: FormGridLayout(
                desktopColumns: 2,
                children: [
                  // Quantité en stock
                  FormFieldContainer(
                    label: 'Quantité en stock',
                    isRequired: true,
                    child: TextFormField(
                      controller: _stockQuantityController,
                      decoration: InputDecoration(
                        prefixIcon: const Icon(
                          Icons.production_quantity_limits,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'La quantité est requise';
                        }
                        if (int.tryParse(value) == null) {
                          return 'Quantité invalide';
                        }
                        return null;
                      },
                    ),
                  ),

                  // Seuil d'alerte
                  FormFieldContainer(
                    label: 'Seuil d\'alerte',
                    helpText: 'Notification quand le stock atteint ce niveau',
                    child: TextFormField(
                      controller: _alertThresholdController,
                      decoration: InputDecoration(
                        hintText: '5',
                        prefixIcon: const Icon(Icons.warning_amber),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Footer avec boutons
            ModalFormFooter(
              onCancel: () => Navigator.of(context).pop(false),
              onConfirm: _submitForm,
              confirmText: _isEditing ? 'Mettre à jour' : 'Ajouter le produit',
              confirmIcon: _isEditing ? Icons.update : Icons.add_circle,
              isLoading: _isSubmitting,
            ),
          ],
        ),
      ),
    );
  }

  String _unitDisplayName(ProductUnit unit) {
    switch (unit) {
      case ProductUnit.piece:
        return 'Pièce';
      case ProductUnit.kg:
        return 'Kilogramme (kg)';
      case ProductUnit.g:
        return 'Gramme (g)';
      case ProductUnit.l:
        return 'Litre (L)';
      case ProductUnit.ml:
        return 'Millilitre (mL)';
      case ProductUnit.package:
        return 'Paquet';
      case ProductUnit.box:
        return 'Boîte';
      case ProductUnit.other:
        return 'Autre';
    }
  }

  void _submitForm() {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);

    final currencyService = context.read<CurrencyService>();
    final inputCurrency = _selectedInputCurrency ?? _appActiveCurrency;
    final exchangeRate = currencyService.getRateToCdf(inputCurrency);

    final costPriceInput = double.parse(_costPriceController.text);
    final sellingPriceInput = double.parse(_sellingPriceController.text);
    final costPriceInCdf = currencyService.convertToCdf(
      costPriceInput,
      inputCurrency,
    );
    final sellingPriceInCdf = currencyService.convertToCdf(
      sellingPriceInput,
      inputCurrency,
    );

    final stockQuantity = double.tryParse(_stockQuantityController.text) ?? 0;
    final alertThreshold = double.tryParse(_alertThresholdController.text) ?? 5;
    final now = DateTime.now();

    final product = Product(
      id: widget.product?.id ?? const Uuid().v4(),
      name: _nameController.text.trim(),
      description: _descriptionController.text.trim(),
      barcode: _barcodeController.text.trim(),
      category: _selectedCategory,
      costPriceInCdf: costPriceInCdf,
      sellingPriceInCdf: sellingPriceInCdf,
      stockQuantity: stockQuantity,
      unit: _selectedUnit,
      alertThreshold: alertThreshold,
      createdAt: widget.product?.createdAt ?? now,
      updatedAt: now,
      imagePath: widget.product?.imagePath,
      inputCurrencyCode: inputCurrency.code,
      inputExchangeRate: exchangeRate,
      costPriceInInputCurrency: costPriceInput,
      sellingPriceInInputCurrency: sellingPriceInput,
    );

    if (_isEditing) {
      context.read<InventoryBloc>().add(UpdateProduct(product));
    } else {
      context.read<InventoryBloc>().add(AddProduct(product));
    }
  }
}
