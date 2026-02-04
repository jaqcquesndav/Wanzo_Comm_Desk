import 'dart:io'; // Added for File support
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';
import 'package:image_picker/image_picker.dart'; // Added image_picker
import 'package:path_provider/path_provider.dart'; // Added path_provider
import 'package:path/path.dart' as path; // Added path
import '../../../constants/spacing.dart';
import '../../../core/shared_widgets/wanzo_scaffold.dart';
import '../../../core/widgets/barcode_scanner_widget.dart'; // Import du scanner
import '../../../core/services/barcode_scanner_service.dart'; // Import du service
import '../bloc/inventory_bloc.dart';
import '../bloc/inventory_event.dart';
import '../bloc/inventory_state.dart';
import '../models/product.dart';
import 'package:wanzo/core/enums/currency_enum.dart'; // Added
import 'package:wanzo/features/settings/presentation/cubit/currency_settings_cubit.dart'; // Changed
import 'package:wanzo/core/services/currency_service.dart'; // Added
import 'package:wanzo/l10n/app_localizations.dart'; // Updated import

/// Écran d'ajout de produit
class AddProductScreen extends StatefulWidget {
  /// Produit à modifier (null pour un nouveau produit)
  final Product? product;

  const AddProductScreen({super.key, this.product});

  @override
  State<AddProductScreen> createState() => _AddProductScreenState();
}

class _AddProductScreenState extends State<AddProductScreen> {
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

  File? _selectedImageFile; // To store the selected image file
  String?
  _currentImagePath; // To store the path of an existing or newly saved image

  bool _isEditing = false;
  Currency? _selectedInputCurrency;
  Currency _appActiveCurrency = Currency.CDF; // Default to CDF

  @override
  void initState() {
    super.initState();

    _isEditing = widget.product != null;
    _currentImagePath = widget.product?.imagePath;

    _nameController = TextEditingController(text: widget.product?.name ?? '');
    _descriptionController = TextEditingController(
      text: widget.product?.description ?? '',
    );
    _barcodeController = TextEditingController(
      text: widget.product?.barcode ?? '',
    );

    final currencySettingsCubit = context.read<CurrencySettingsCubit>();
    final currencySettingsState = currencySettingsCubit.state;

    if (currencySettingsState.status == CurrencySettingsStatus.loaded) {
      final settings = currencySettingsState.settings;
      _appActiveCurrency = settings.activeCurrency;

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
      // Default values if currency settings are not loaded
      _appActiveCurrency = Currency.CDF;
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
      text: widget.product?.stockQuantity.toString() ?? '',
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

  Future<void> _pickImage(ImageSource source) async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? pickedFile = await picker.pickImage(source: source);

      if (pickedFile != null) {
        final File imageFile = File(pickedFile.path);
        // Optionally, save the image to the app's directory and store the path
        final Directory appDir = await getApplicationDocumentsDirectory();
        final String fileName = path.basename(imageFile.path);
        final String savedImagePath = path.join(appDir.path, fileName);

        // Check if the file already exists at the destination, if so, generate a unique name
        String uniqueSavedImagePath = savedImagePath;
        int counter = 1;
        while (await File(uniqueSavedImagePath).exists()) {
          String newFileName =
              '${path.basenameWithoutExtension(savedImagePath)}_$counter${path.extension(savedImagePath)}';
          uniqueSavedImagePath = path.join(appDir.path, newFileName);
          counter++;
        }

        await imageFile.copy(uniqueSavedImagePath);

        setState(() {
          _selectedImageFile = imageFile; // Keep for display before saving form
          _currentImagePath =
              uniqueSavedImagePath; // Store the path to be saved with the product
        });
      }
    } catch (e) {
      // Handle exceptions, e.g., permission denied
      if (mounted) {
        // Check if the widget is still in the tree
        final l10n = AppLocalizations.of(context)!; // Ensure l10n is available
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.imagePickingErrorMessage(e.toString()))),
        );
      }
    }
  }

  void _showImageSourceActionSheet(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    showModalBottomSheet(
      context: context,
      builder: (BuildContext bc) {
        return SafeArea(
          child: Wrap(
            children: <Widget>[
              ListTile(
                leading: const Icon(Icons.photo_library),
                title: Text(l10n.galleryAction),
                onTap: () {
                  _pickImage(ImageSource.gallery);
                  Navigator.of(context).pop();
                },
              ),
              ListTile(
                leading: const Icon(Icons.photo_camera),
                title: Text(l10n.cameraAction),
                onTap: () {
                  _pickImage(ImageSource.camera);
                  Navigator.of(context).pop();
                },
              ),
              if (_selectedImageFile != null ||
                  (_currentImagePath != null && _currentImagePath!.isNotEmpty))
                ListTile(
                  leading: const Icon(Icons.delete, color: Colors.red),
                  title: Text(
                    l10n.removeImageAction,
                    style: const TextStyle(color: Colors.red),
                  ),
                  onTap: () {
                    setState(() {
                      _selectedImageFile = null;
                      _currentImagePath = null;
                    });
                    Navigator.of(context).pop();
                  },
                ),
            ],
          ),
        );
      },
    );
  }

  /// Ouvre le scanner de code-barres
  Future<void> _openBarcodeScanner() async {
    final scannerService = BarcodeScannerService();

    // Vérifier d'abord si le scanner est supporté
    final isSupported = await scannerService.isScannerSupported();
    if (!isSupported) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Scanner de code-barres non supporté sur cet appareil',
            ),
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
            content: Text('Permission d\'accès à la caméra requise'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    // Ouvrir le scanner
    if (mounted) {
      final result = await Navigator.of(context).push<String>(
        MaterialPageRoute(
          builder:
              (context) => BarcodeScannerWidget(
                title: 'Scanner le code du produit',
                subtitle: 'Alignez le code-barres ou QR code dans le cadre',
                onBarcodeScanned: (barcode) {
                  Navigator.of(context).pop(barcode);
                },
              ),
        ),
      );

      // Si un code a été scanné, l'ajouter au champ
      if (result != null && result.isNotEmpty) {
        setState(() {
          _barcodeController.text = result;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Code scanné: $result'),
            backgroundColor: Colors.green,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return BlocListener<InventoryBloc, InventoryState>(
      listener: (context, state) {
        if (state is InventoryOperationSuccess) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(state.message)));
          if (mounted) {
            context.pop();
          }
        } else if (state is InventoryError) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(state.message), backgroundColor: Colors.red),
          );
        }
      },
      child: WanzoScaffold(
        currentIndex: 2,
        title: _isEditing ? l10n.editProductTitle : l10n.addProductTitle,
        onBackPressed: () => context.pop(),
        body: BlocBuilder<CurrencySettingsCubit, CurrencySettingsState>(
          builder: (context, currencyState) {
            if (currencyState.status == CurrencySettingsStatus.loading ||
                currencyState.status == CurrencySettingsStatus.initial) {
              return const Center(child: CircularProgressIndicator());
            } else if (currencyState.status == CurrencySettingsStatus.error) {
              return Center(
                child: Text(
                  l10n.currencySettingsError(
                    currencyState.errorMessage ?? l10n.errorUnknown,
                  ),
                ),
              );
            } else if (currencyState.status == CurrencySettingsStatus.loaded) {
              final settings = currencyState.settings;
              _appActiveCurrency = settings.activeCurrency;

              // For new products, ensure _selectedInputCurrency reflects the loaded appActiveCurrency.
              // For edited products, _selectedInputCurrency is set in initState from the product's data.
              if (!_isEditing) {
                _selectedInputCurrency = _appActiveCurrency;
              }
              // Fallback if _selectedInputCurrency is still null for any reason.
              _selectedInputCurrency ??= _appActiveCurrency;

              return SingleChildScrollView(
                padding: const EdgeInsets.all(WanzoSpacing.md),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Image Picker Section
                      _buildSectionTitle(
                        context,
                        l10n.productImageSectionTitle,
                      ),
                      const SizedBox(height: WanzoSpacing.md),
                      GestureDetector(
                        onTap: () => _showImageSourceActionSheet(context),
                        child: Container(
                          height: 150,
                          decoration: BoxDecoration(
                            color: Colors.grey[200],
                            borderRadius: BorderRadius.circular(
                              WanzoSpacing.sm,
                            ),
                            border: Border.all(color: Colors.grey.shade400),
                          ),
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              if (_selectedImageFile != null)
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(
                                    WanzoSpacing.sm,
                                  ),
                                  child: Image.file(
                                    _selectedImageFile!,
                                    width: double.infinity,
                                    height: 150,
                                    fit: BoxFit.cover,
                                  ),
                                )
                              else if (_currentImagePath != null &&
                                  _currentImagePath!.isNotEmpty)
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(
                                    WanzoSpacing.sm,
                                  ),
                                  child: Image.file(
                                    File(
                                      _currentImagePath!,
                                    ), // Display existing image
                                    width: double.infinity,
                                    height: 150,
                                    fit: BoxFit.cover,
                                  ),
                                )
                              else
                                Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.add_a_photo,
                                      size: 40,
                                      color: Colors.grey[600],
                                    ),
                                    const SizedBox(height: WanzoSpacing.sm),
                                    Text(
                                      l10n.addImageLabel,
                                      style: TextStyle(color: Colors.grey[700]),
                                    ),
                                  ],
                                ),
                              if (_selectedImageFile != null ||
                                  (_currentImagePath != null &&
                                      _currentImagePath!.isNotEmpty))
                                Positioned(
                                  top: 8,
                                  right: 8,
                                  child: InkWell(
                                    onTap: () {
                                      setState(() {
                                        _selectedImageFile = null;
                                        _currentImagePath = null;
                                      });
                                    },
                                    child: Container(
                                      padding: const EdgeInsets.all(4),
                                      decoration: BoxDecoration(
                                        color: Colors.black.withValues(
                                          alpha: 0.5,
                                        ),
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
                        ),
                      ),
                      const SizedBox(height: WanzoSpacing.lg),

                      // Informations générales
                      _buildSectionTitle(
                        context,
                        l10n.generalInformationSectionTitle,
                      ),
                      const SizedBox(height: WanzoSpacing.md),

                      // Nom du produit
                      TextFormField(
                        controller: _nameController,
                        decoration: InputDecoration(
                          labelText: l10n.productNameLabel,
                          border: const OutlineInputBorder(),
                          prefixIcon: const Icon(Icons.inventory),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return l10n.productNameValidationError;
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: WanzoSpacing.md),

                      // Description
                      TextFormField(
                        controller: _descriptionController,
                        decoration: InputDecoration(
                          labelText: l10n.productDescriptionLabel,
                          border: const OutlineInputBorder(),
                          prefixIcon: const Icon(Icons.description),
                        ),
                        maxLines: 3,
                      ),
                      const SizedBox(height: WanzoSpacing.md),

                      // Code-barres
                      TextFormField(
                        controller: _barcodeController,
                        decoration: InputDecoration(
                          labelText: l10n.productBarcodeLabel,
                          border: const OutlineInputBorder(),
                          prefixIcon: const Icon(Icons.qr_code),
                          suffixIcon: IconButton(
                            icon: const Icon(Icons.camera_alt),
                            onPressed: _openBarcodeScanner,
                            tooltip: 'Scanner un code-barres',
                          ),
                        ),
                      ),
                      const SizedBox(height: WanzoSpacing.md),

                      // Catégorie
                      Autocomplete<ProductCategory>(
                        initialValue: TextEditingValue(
                          text: _getCategoryName(_selectedCategory, l10n),
                        ),
                        optionsBuilder: (TextEditingValue textEditingValue) {
                          if (textEditingValue.text.isEmpty) {
                            return ProductCategory.values;
                          }
                          return ProductCategory.values.where((category) {
                            final displayName =
                                _getCategoryName(category, l10n).toLowerCase();
                            final searchText =
                                textEditingValue.text.toLowerCase();
                            return displayName.contains(searchText);
                          });
                        },
                        displayStringForOption:
                            (ProductCategory category) =>
                                _getCategoryName(category, l10n),
                        onSelected: (ProductCategory selection) {
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
                              labelText: l10n.productCategoryLabel,
                              border: const OutlineInputBorder(),
                              prefixIcon: const Icon(Icons.category),
                            ),
                          );
                        },
                        optionsViewBuilder: (
                          BuildContext context,
                          AutocompleteOnSelected<ProductCategory> onSelected,
                          Iterable<ProductCategory> options,
                        ) {
                          return Align(
                            alignment: Alignment.topLeft,
                            child: Material(
                              elevation: 4.0,
                              child: Container(
                                width: 300,
                                constraints: const BoxConstraints(
                                  maxHeight: 200,
                                ),
                                child: ListView.builder(
                                  padding: const EdgeInsets.all(8.0),
                                  itemCount: options.length,
                                  itemBuilder: (
                                    BuildContext context,
                                    int index,
                                  ) {
                                    final option = options.elementAt(index);
                                    return ListTile(
                                      leading: Icon(option.icon),
                                      title: Text(
                                        _getCategoryName(option, l10n),
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
                      ),
                      const SizedBox(height: WanzoSpacing.lg),

                      // Prix & Currency Section
                      _buildSectionTitle(context, l10n.pricingSectionTitle),
                      const SizedBox(height: WanzoSpacing.md),
                      DropdownButtonFormField<Currency>(
                        value: _selectedInputCurrency,
                        decoration: InputDecoration(
                          labelText: l10n.inputCurrencyLabel,
                          border: const OutlineInputBorder(),
                          prefixIcon: const Icon(Icons.money),
                        ),
                        items:
                            Currency.values.map((Currency currency) {
                              return DropdownMenuItem<Currency>(
                                value: currency,
                                child: Text(
                                  currency.displayName(context),
                                ), // Pass context
                              );
                            }).toList(),
                        onChanged: (Currency? newValue) {
                          setState(() {
                            _selectedInputCurrency = newValue!;
                          });
                        },
                        validator:
                            (value) =>
                                value == null
                                    ? l10n.inputCurrencyValidationError
                                    : null,
                      ),
                      const SizedBox(height: WanzoSpacing.md),

                      // Prix d'achat
                      TextFormField(
                        controller: _costPriceController,
                        decoration: InputDecoration(
                          labelText:
                              '${l10n.costPriceLabel} (${_selectedInputCurrency?.code ?? _appActiveCurrency.code})',
                          border: const OutlineInputBorder(),
                          prefixIcon: const Icon(Icons.store),
                        ),
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(
                            RegExp(r'^\d+\.?\d{0,2}'),
                          ),
                        ],
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return l10n.costPriceValidationError;
                          }
                          try {
                            final price = double.parse(value);
                            if (price < 0) {
                              return l10n.negativePriceValidationError;
                            }
                          } catch (e) {
                            return l10n.invalidNumberValidationError;
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: WanzoSpacing.md),

                      // Prix de vente
                      TextFormField(
                        controller: _sellingPriceController,
                        decoration: InputDecoration(
                          labelText:
                              '${l10n.sellingPriceLabel} (${_selectedInputCurrency?.code ?? _appActiveCurrency.code})',
                          border: const OutlineInputBorder(),
                          prefixIcon: const Icon(Icons.sell),
                        ),
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(
                            RegExp(r'^\d+\.?\d{0,2}'),
                          ),
                        ],
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return l10n.sellingPriceValidationError;
                          }
                          try {
                            final price = double.parse(value);
                            if (price < 0) {
                              return l10n.negativePriceValidationError;
                            }
                          } catch (e) {
                            return l10n.invalidNumberValidationError;
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: WanzoSpacing.lg),

                      // Stock
                      _buildSectionTitle(
                        context,
                        l10n.stockManagementSectionTitle,
                      ),
                      const SizedBox(height: WanzoSpacing.md),

                      // Quantité en stock
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Quantité
                          Expanded(
                            flex: 2,
                            child: TextFormField(
                              controller: _stockQuantityController,
                              decoration: InputDecoration(
                                labelText: l10n.stockQuantityLabel,
                                border: const OutlineInputBorder(),
                                prefixIcon: const Icon(Icons.inventory_2),
                              ),
                              keyboardType: TextInputType.number,
                              inputFormatters: [
                                FilteringTextInputFormatter.allow(
                                  RegExp(r'^\d+\.?\d{0,2}'),
                                ),
                              ],
                              validator: (value) {
                                if (_isEditing &&
                                    widget.product?.stockQuantity.toString() ==
                                        value) {
                                  // If editing and quantity hasn't changed, no new stock transaction needed for initial quantity.
                                  // Validation for format is still good.
                                  try {
                                    if (value != null && value.isNotEmpty) {
                                      double.parse(value);
                                    }
                                  } catch (e) {
                                    return l10n.invalidNumberValidationError;
                                  }
                                  return null;
                                }
                                if (value == null || value.isEmpty) {
                                  return l10n.stockQuantityValidationError;
                                }
                                try {
                                  final quantity = double.parse(value);
                                  if (quantity < 0) {
                                    return l10n.negativeQuantityValidationError;
                                  }
                                } catch (e) {
                                  return l10n.invalidNumberValidationError;
                                }
                                return null;
                              },
                            ),
                          ),
                          const SizedBox(width: WanzoSpacing.md),

                          // Unité
                          Expanded(
                            flex: 1,
                            child: DropdownButtonFormField<ProductUnit>(
                              isExpanded: true,
                              value: _selectedUnit,
                              decoration: InputDecoration(
                                labelText: l10n.productUnitLabel,
                                border: const OutlineInputBorder(),
                              ),
                              items:
                                  ProductUnit.values.map((unit) {
                                    return DropdownMenuItem<ProductUnit>(
                                      value: unit,
                                      child: Text(
                                        _getUnitName(unit, l10n),
                                        overflow: TextOverflow.ellipsis,
                                      ), // Pass l10n
                                    );
                                  }).toList(),
                              onChanged: (value) {
                                if (value != null) {
                                  setState(() {
                                    _selectedUnit = value;
                                  });
                                }
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: WanzoSpacing.md),

                      // Seuil d'alerte
                      TextFormField(
                        controller: _alertThresholdController,
                        decoration: InputDecoration(
                          labelText: l10n.lowStockThresholdLabel,
                          border: const OutlineInputBorder(),
                          prefixIcon: const Icon(Icons.warning),
                          helperText: l10n.lowStockThresholdHelper,
                        ),
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(
                            RegExp(r'^\d+\.?\d{0,2}'),
                          ),
                        ],
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return l10n.lowStockThresholdValidationError;
                          }
                          try {
                            final threshold = double.parse(value);
                            if (threshold < 0) {
                              return l10n.negativeThresholdValidationError;
                            }
                          } catch (e) {
                            return l10n.invalidNumberValidationError;
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: WanzoSpacing.xl),

                      // Bouton de soumission
                      ElevatedButton.icon(
                        icon: Icon(_isEditing ? Icons.save : Icons.add),
                        label: Text(
                          _isEditing
                              ? l10n.saveChangesButton
                              : l10n.addProductButton,
                        ),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                            vertical: WanzoSpacing.md,
                          ),
                          textStyle: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        onPressed: () {
                          if (_formKey.currentState!.validate()) {
                            _submitForm(context);
                          }
                        },
                      ),
                    ],
                  ),
                ),
              );
            }

            // Fallback for any other unhandled state (should ideally not be reached with an enum)
            return Center(child: Text(l10n.errorUnknown));
          },
        ),
      ),
    );
  }

  Widget _buildSectionTitle(BuildContext context, String title) {
    return Text(
      title,
      style: Theme.of(context).textTheme.titleLarge?.copyWith(
        fontWeight: FontWeight.bold,
        color: Theme.of(context).colorScheme.primary,
      ),
    );
  }

  void _submitForm(BuildContext context) {
    final currencyService = context.read<CurrencyService>();

    final costPriceInput = double.tryParse(_costPriceController.text) ?? 0.0;
    final sellingPriceInput =
        double.tryParse(_sellingPriceController.text) ?? 0.0;
    final stockQuantity =
        double.tryParse(_stockQuantityController.text) ??
        (widget.product?.stockQuantity ?? 0);

    final inputCurrency = _selectedInputCurrency ?? _appActiveCurrency;

    // Get the exchange rate from the input currency to CDF
    // This uses the getRateToCdf method which relies on the loaded _currentSettings in CurrencyService
    final exchangeRate = currencyService.getRateToCdf(inputCurrency);

    // Convert input prices to CDF using the specific methods from CurrencyService
    final costPriceInCdf = currencyService.convertToCdf(
      costPriceInput,
      inputCurrency,
    );
    final sellingPriceInCdf = currencyService.convertToCdf(
      sellingPriceInput,
      inputCurrency,
    );

    final product = Product(
      id: widget.product?.id ?? const Uuid().v4(),
      name: _nameController.text,
      description: _descriptionController.text,
      barcode: _barcodeController.text,
      category: _selectedCategory,
      costPriceInCdf: costPriceInCdf,
      sellingPriceInCdf: sellingPriceInCdf,
      stockQuantity: stockQuantity,
      unit: _selectedUnit,
      alertThreshold: double.tryParse(_alertThresholdController.text) ?? 5.0,
      createdAt: widget.product?.createdAt ?? DateTime.now(),
      updatedAt: DateTime.now(),
      imagePath: _currentImagePath,
      inputCurrencyCode: inputCurrency.code,
      inputExchangeRate: exchangeRate, // Store the rate used for this product
      costPriceInInputCurrency: costPriceInput,
      sellingPriceInInputCurrency: sellingPriceInput,
    );

    if (_isEditing) {
      context.read<InventoryBloc>().add(UpdateProduct(product));
    } else {
      context.read<InventoryBloc>().add(AddProduct(product));
    }
  }

  String _getCategoryName(ProductCategory category, AppLocalizations l10n) {
    // Utiliser l'extension pour obtenir le nom de la catégorie
    return category.displayName;
  }

  String _getUnitName(ProductUnit unit, AppLocalizations l10n) {
    switch (unit) {
      case ProductUnit.piece:
        return l10n.productUnitPiece;
      case ProductUnit.kg:
        return l10n.productUnitKg;
      case ProductUnit.g:
        return l10n.productUnitG;
      case ProductUnit.l:
        return l10n.productUnitL;
      case ProductUnit.ml:
        return l10n.productUnitMl;
      case ProductUnit.package:
        return l10n.productUnitPackage;
      case ProductUnit.box:
        return l10n.productUnitBox;
      case ProductUnit.other:
        return l10n.productUnitOther;
    }
  }
}
