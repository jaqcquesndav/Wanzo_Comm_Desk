import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_fr.dart';
import 'app_localizations_sw.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('fr'),
    Locale('sw'),
  ];

  /// No description provided for @invoiceSettingsTitle.
  ///
  /// In en, this message translates to:
  /// **'Invoice Settings'**
  String get invoiceSettingsTitle;

  /// No description provided for @currencySettings.
  ///
  /// In en, this message translates to:
  /// **'Currency Settings'**
  String get currencySettings;

  /// No description provided for @activeCurrency.
  ///
  /// In en, this message translates to:
  /// **'Active Currency'**
  String get activeCurrency;

  /// Label for specific exchange rate input
  ///
  /// In en, this message translates to:
  /// **'Exchange Rate ({currencyFrom} to {currencyTo})'**
  String exchangeRateSpecific(String currencyFrom, String currencyTo);

  /// Hint text for exchange rate input
  ///
  /// In en, this message translates to:
  /// **'e.g., 650 for 1 USD = 650 FCFA'**
  String exchangeRateHint(String currencyFrom, String currencyTo);

  /// No description provided for @errorFieldRequired.
  ///
  /// In en, this message translates to:
  /// **'This field is required.'**
  String get errorFieldRequired;

  /// No description provided for @errorInvalidRate.
  ///
  /// In en, this message translates to:
  /// **'Please enter a valid positive rate.'**
  String get errorInvalidRate;

  /// No description provided for @invoiceFormatting.
  ///
  /// In en, this message translates to:
  /// **'Invoice Formatting'**
  String get invoiceFormatting;

  /// Hint for invoice number format placeholders
  ///
  /// In en, this message translates to:
  /// **'Use {YEAR}, {MONTH}, {SEQ} for dynamic values.'**
  String invoiceFormatHint(Object YEAR, Object MONTH, Object SEQ);

  /// No description provided for @invoiceNumberFormat.
  ///
  /// In en, this message translates to:
  /// **'Invoice Number Format'**
  String get invoiceNumberFormat;

  /// No description provided for @invoicePrefix.
  ///
  /// In en, this message translates to:
  /// **'Invoice Prefix'**
  String get invoicePrefix;

  /// No description provided for @taxesAndConditions.
  ///
  /// In en, this message translates to:
  /// **'Taxes & Conditions'**
  String get taxesAndConditions;

  /// No description provided for @showTaxesOnInvoices.
  ///
  /// In en, this message translates to:
  /// **'Show taxes on invoices'**
  String get showTaxesOnInvoices;

  /// No description provided for @defaultTaxRatePercentage.
  ///
  /// In en, this message translates to:
  /// **'Default Tax Rate (%)'**
  String get defaultTaxRatePercentage;

  /// No description provided for @errorInvalidTaxRate.
  ///
  /// In en, this message translates to:
  /// **'Tax rate must be between 0 and 100.'**
  String get errorInvalidTaxRate;

  /// No description provided for @defaultPaymentTerms.
  ///
  /// In en, this message translates to:
  /// **'Default Payment Terms'**
  String get defaultPaymentTerms;

  /// No description provided for @defaultInvoiceNotes.
  ///
  /// In en, this message translates to:
  /// **'Default Invoice Notes'**
  String get defaultInvoiceNotes;

  /// No description provided for @settingsSavedSuccess.
  ///
  /// In en, this message translates to:
  /// **'Settings saved successfully.'**
  String get settingsSavedSuccess;

  /// No description provided for @anErrorOccurred.
  ///
  /// In en, this message translates to:
  /// **'An error occurred'**
  String get anErrorOccurred;

  /// No description provided for @errorUnknown.
  ///
  /// In en, this message translates to:
  /// **'Unknown error'**
  String get errorUnknown;

  /// Error message for currency settings failure
  ///
  /// In en, this message translates to:
  /// **'Could not save currency settings: {errorDetails}'**
  String currencySettingsError(String errorDetails);

  /// No description provided for @currencySettingsSavedSuccess.
  ///
  /// In en, this message translates to:
  /// **'Currency settings saved successfully.'**
  String get currencySettingsSavedSuccess;

  /// No description provided for @currencyCDF.
  ///
  /// In en, this message translates to:
  /// **'Congolese Franc'**
  String get currencyCDF;

  /// No description provided for @currencyUSD.
  ///
  /// In en, this message translates to:
  /// **'US Dollar'**
  String get currencyUSD;

  /// No description provided for @currencyFCFA.
  ///
  /// In en, this message translates to:
  /// **'CFA Franc'**
  String get currencyFCFA;

  /// No description provided for @editProductTitle.
  ///
  /// In en, this message translates to:
  /// **'Edit Product'**
  String get editProductTitle;

  /// No description provided for @addProductTitle.
  ///
  /// In en, this message translates to:
  /// **'Add Product'**
  String get addProductTitle;

  /// No description provided for @productCategoryFood.
  ///
  /// In en, this message translates to:
  /// **'Food'**
  String get productCategoryFood;

  /// No description provided for @productCategoryDrink.
  ///
  /// In en, this message translates to:
  /// **'Drink'**
  String get productCategoryDrink;

  /// No description provided for @productCategoryOther.
  ///
  /// In en, this message translates to:
  /// **'Other'**
  String get productCategoryOther;

  /// No description provided for @units.
  ///
  /// In en, this message translates to:
  /// **'Units'**
  String get units;

  /// No description provided for @notes.
  ///
  /// In en, this message translates to:
  /// **'Notes (Optional)'**
  String get notes;

  /// No description provided for @saveProduct.
  ///
  /// In en, this message translates to:
  /// **'Save Product'**
  String get saveProduct;

  /// No description provided for @inventoryValue.
  ///
  /// In en, this message translates to:
  /// **'Inventory Value'**
  String get inventoryValue;

  /// No description provided for @products.
  ///
  /// In en, this message translates to:
  /// **'Products'**
  String get products;

  /// No description provided for @stockMovements.
  ///
  /// In en, this message translates to:
  /// **'Stock Movements'**
  String get stockMovements;

  /// No description provided for @noProducts.
  ///
  /// In en, this message translates to:
  /// **'No products yet.'**
  String get noProducts;

  /// No description provided for @noStockMovements.
  ///
  /// In en, this message translates to:
  /// **'No stock movements yet.'**
  String get noStockMovements;

  /// No description provided for @searchProducts.
  ///
  /// In en, this message translates to:
  /// **'Search products...'**
  String get searchProducts;

  /// No description provided for @totalStock.
  ///
  /// In en, this message translates to:
  /// **'Total Stock'**
  String get totalStock;

  /// No description provided for @valueInCdf.
  ///
  /// In en, this message translates to:
  /// **'Value (CDF)'**
  String get valueInCdf;

  /// No description provided for @valueIn.
  ///
  /// In en, this message translates to:
  /// **'Value ({currencyCode})'**
  String valueIn(String currencyCode);

  /// No description provided for @lastModified.
  ///
  /// In en, this message translates to:
  /// **'Last Modified'**
  String get lastModified;

  /// No description provided for @productDetails.
  ///
  /// In en, this message translates to:
  /// **'Product Details'**
  String get productDetails;

  /// No description provided for @deleteProduct.
  ///
  /// In en, this message translates to:
  /// **'Delete Product'**
  String get deleteProduct;

  /// No description provided for @confirmDeleteProductTitle.
  ///
  /// In en, this message translates to:
  /// **'Confirm Deletion'**
  String get confirmDeleteProductTitle;

  /// No description provided for @confirmDeleteProductMessage.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to delete this product? This action cannot be undone.'**
  String get confirmDeleteProductMessage;

  /// No description provided for @commonCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get commonCancel;

  /// No description provided for @delete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get delete;

  /// No description provided for @stockIn.
  ///
  /// In en, this message translates to:
  /// **'Stock In'**
  String get stockIn;

  /// No description provided for @stockOut.
  ///
  /// In en, this message translates to:
  /// **'Stock Out'**
  String get stockOut;

  /// No description provided for @adjustment.
  ///
  /// In en, this message translates to:
  /// **'Adjustment'**
  String get adjustment;

  /// No description provided for @quantity.
  ///
  /// In en, this message translates to:
  /// **'Quantity'**
  String get quantity;

  /// No description provided for @reason.
  ///
  /// In en, this message translates to:
  /// **'Reason (Optional)'**
  String get reason;

  /// No description provided for @addStockMovement.
  ///
  /// In en, this message translates to:
  /// **'Add Stock Movement'**
  String get addStockMovement;

  /// No description provided for @newStock.
  ///
  /// In en, this message translates to:
  /// **'New Stock'**
  String get newStock;

  /// No description provided for @value.
  ///
  /// In en, this message translates to:
  /// **'Value'**
  String get value;

  /// No description provided for @type.
  ///
  /// In en, this message translates to:
  /// **'Type'**
  String get type;

  /// No description provided for @date.
  ///
  /// In en, this message translates to:
  /// **'Date'**
  String get date;

  /// No description provided for @product.
  ///
  /// In en, this message translates to:
  /// **'Product'**
  String get product;

  /// No description provided for @selectProduct.
  ///
  /// In en, this message translates to:
  /// **'Select Product'**
  String get selectProduct;

  /// No description provided for @selectCategory.
  ///
  /// In en, this message translates to:
  /// **'Select Category'**
  String get selectCategory;

  /// No description provided for @selectUnit.
  ///
  /// In en, this message translates to:
  /// **'Select Unit'**
  String get selectUnit;

  /// No description provided for @imagePickingErrorMessage.
  ///
  /// In en, this message translates to:
  /// **'Error picking image: {errorDetails}'**
  String imagePickingErrorMessage(String errorDetails);

  /// No description provided for @galleryAction.
  ///
  /// In en, this message translates to:
  /// **'Gallery'**
  String get galleryAction;

  /// No description provided for @cameraAction.
  ///
  /// In en, this message translates to:
  /// **'Camera'**
  String get cameraAction;

  /// No description provided for @removeImageAction.
  ///
  /// In en, this message translates to:
  /// **'Remove Image'**
  String get removeImageAction;

  /// No description provided for @productImageSectionTitle.
  ///
  /// In en, this message translates to:
  /// **'Product Image'**
  String get productImageSectionTitle;

  /// No description provided for @addImageLabel.
  ///
  /// In en, this message translates to:
  /// **'Add Image'**
  String get addImageLabel;

  /// No description provided for @generalInformationSectionTitle.
  ///
  /// In en, this message translates to:
  /// **'General Information'**
  String get generalInformationSectionTitle;

  /// No description provided for @productNameLabel.
  ///
  /// In en, this message translates to:
  /// **'Product Name'**
  String get productNameLabel;

  /// No description provided for @productNameValidationError.
  ///
  /// In en, this message translates to:
  /// **'Please enter the product name.'**
  String get productNameValidationError;

  /// No description provided for @productDescriptionLabel.
  ///
  /// In en, this message translates to:
  /// **'Description'**
  String get productDescriptionLabel;

  /// No description provided for @productBarcodeLabel.
  ///
  /// In en, this message translates to:
  /// **'Barcode (Optional)'**
  String get productBarcodeLabel;

  /// No description provided for @featureComingSoonMessage.
  ///
  /// In en, this message translates to:
  /// **'Feature coming soon!'**
  String get featureComingSoonMessage;

  /// No description provided for @productCategoryLabel.
  ///
  /// In en, this message translates to:
  /// **'Category'**
  String get productCategoryLabel;

  /// No description provided for @productCategoryElectronics.
  ///
  /// In en, this message translates to:
  /// **'Electronics'**
  String get productCategoryElectronics;

  /// No description provided for @productCategoryClothing.
  ///
  /// In en, this message translates to:
  /// **'Clothing'**
  String get productCategoryClothing;

  /// No description provided for @productCategoryHousehold.
  ///
  /// In en, this message translates to:
  /// **'Household'**
  String get productCategoryHousehold;

  /// No description provided for @productCategoryHygiene.
  ///
  /// In en, this message translates to:
  /// **'Hygiene'**
  String get productCategoryHygiene;

  /// No description provided for @productCategoryOffice.
  ///
  /// In en, this message translates to:
  /// **'Office Supplies'**
  String get productCategoryOffice;

  /// No description provided for @pricingSectionTitle.
  ///
  /// In en, this message translates to:
  /// **'Pricing and Currency'**
  String get pricingSectionTitle;

  /// No description provided for @inputCurrencyLabel.
  ///
  /// In en, this message translates to:
  /// **'Input Currency'**
  String get inputCurrencyLabel;

  /// No description provided for @inputCurrencyValidationError.
  ///
  /// In en, this message translates to:
  /// **'Please select an input currency.'**
  String get inputCurrencyValidationError;

  /// No description provided for @costPriceLabel.
  ///
  /// In en, this message translates to:
  /// **'Cost Price'**
  String get costPriceLabel;

  /// No description provided for @costPriceValidationError.
  ///
  /// In en, this message translates to:
  /// **'Please enter the cost price.'**
  String get costPriceValidationError;

  /// No description provided for @negativePriceValidationError.
  ///
  /// In en, this message translates to:
  /// **'Price cannot be negative.'**
  String get negativePriceValidationError;

  /// No description provided for @invalidNumberValidationError.
  ///
  /// In en, this message translates to:
  /// **'Please enter a valid number.'**
  String get invalidNumberValidationError;

  /// No description provided for @sellingPriceLabel.
  ///
  /// In en, this message translates to:
  /// **'Selling Price'**
  String get sellingPriceLabel;

  /// No description provided for @sellingPriceValidationError.
  ///
  /// In en, this message translates to:
  /// **'Please enter the selling price.'**
  String get sellingPriceValidationError;

  /// No description provided for @stockManagementSectionTitle.
  ///
  /// In en, this message translates to:
  /// **'Stock Management'**
  String get stockManagementSectionTitle;

  /// No description provided for @stockQuantityLabel.
  ///
  /// In en, this message translates to:
  /// **'Quantity in Stock'**
  String get stockQuantityLabel;

  /// No description provided for @stockQuantityValidationError.
  ///
  /// In en, this message translates to:
  /// **'Please enter the stock quantity.'**
  String get stockQuantityValidationError;

  /// No description provided for @negativeQuantityValidationError.
  ///
  /// In en, this message translates to:
  /// **'Quantity cannot be negative.'**
  String get negativeQuantityValidationError;

  /// No description provided for @productUnitLabel.
  ///
  /// In en, this message translates to:
  /// **'Unit'**
  String get productUnitLabel;

  /// No description provided for @productUnitPiece.
  ///
  /// In en, this message translates to:
  /// **'Piece(s)'**
  String get productUnitPiece;

  /// No description provided for @productUnitKg.
  ///
  /// In en, this message translates to:
  /// **'Kilogram(s) (kg)'**
  String get productUnitKg;

  /// No description provided for @productUnitG.
  ///
  /// In en, this message translates to:
  /// **'Gram(s) (g)'**
  String get productUnitG;

  /// No description provided for @productUnitL.
  ///
  /// In en, this message translates to:
  /// **'Liter(s) (L)'**
  String get productUnitL;

  /// No description provided for @productUnitMl.
  ///
  /// In en, this message translates to:
  /// **'Milliliter(s) (ml)'**
  String get productUnitMl;

  /// No description provided for @productUnitPackage.
  ///
  /// In en, this message translates to:
  /// **'Package(s)'**
  String get productUnitPackage;

  /// No description provided for @productUnitBox.
  ///
  /// In en, this message translates to:
  /// **'Box(es)'**
  String get productUnitBox;

  /// No description provided for @productUnitOther.
  ///
  /// In en, this message translates to:
  /// **'Other Unit'**
  String get productUnitOther;

  /// No description provided for @lowStockThresholdLabel.
  ///
  /// In en, this message translates to:
  /// **'Low Stock Alert Threshold'**
  String get lowStockThresholdLabel;

  /// No description provided for @lowStockThresholdHelper.
  ///
  /// In en, this message translates to:
  /// **'Receive an alert when stock reaches this level.'**
  String get lowStockThresholdHelper;

  /// No description provided for @lowStockThresholdValidationError.
  ///
  /// In en, this message translates to:
  /// **'Please enter a valid alert threshold.'**
  String get lowStockThresholdValidationError;

  /// No description provided for @negativeThresholdValidationError.
  ///
  /// In en, this message translates to:
  /// **'Threshold cannot be negative.'**
  String get negativeThresholdValidationError;

  /// No description provided for @saveChangesButton.
  ///
  /// In en, this message translates to:
  /// **'Save Changes'**
  String get saveChangesButton;

  /// No description provided for @addProductButton.
  ///
  /// In en, this message translates to:
  /// **'Add Product'**
  String get addProductButton;

  /// No description provided for @notesLabelOptional.
  ///
  /// In en, this message translates to:
  /// **'Notes (Optional)'**
  String get notesLabelOptional;

  /// No description provided for @addStockDialogTitle.
  ///
  /// In en, this message translates to:
  /// **'Add Stock to {productName}'**
  String addStockDialogTitle(String productName);

  /// No description provided for @currentStockLabel.
  ///
  /// In en, this message translates to:
  /// **'Current Stock'**
  String get currentStockLabel;

  /// No description provided for @quantityToAddLabel.
  ///
  /// In en, this message translates to:
  /// **'Quantity to Add'**
  String get quantityToAddLabel;

  /// No description provided for @quantityValidationError.
  ///
  /// In en, this message translates to:
  /// **'Please enter a quantity.'**
  String get quantityValidationError;

  /// No description provided for @positiveQuantityValidationError.
  ///
  /// In en, this message translates to:
  /// **'Quantity must be positive for a purchase.'**
  String get positiveQuantityValidationError;

  /// No description provided for @addButtonLabel.
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get addButtonLabel;

  /// No description provided for @stockAdjustmentDefaultNote.
  ///
  /// In en, this message translates to:
  /// **'Stock adjustment'**
  String get stockAdjustmentDefaultNote;

  /// Label for other stock transaction types
  ///
  /// In en, this message translates to:
  /// **'Other'**
  String get stockTransactionTypeOther;

  /// Fallback initial letter for product image if name is empty or image fails
  ///
  /// In en, this message translates to:
  /// **'P'**
  String get productInitialFallback;

  /// Title for the Inventory Screen
  ///
  /// In en, this message translates to:
  /// **'Inventory'**
  String get inventoryScreenTitle;

  /// Label for the All Products tab
  ///
  /// In en, this message translates to:
  /// **'All Products'**
  String get allProductsTabLabel;

  /// Label for the Low Stock tab
  ///
  /// In en, this message translates to:
  /// **'Low Stock'**
  String get lowStockTabLabel;

  /// Label for the Transactions tab
  ///
  /// In en, this message translates to:
  /// **'Transactions'**
  String get transactionsTabLabel;

  /// Message displayed when there are no products
  ///
  /// In en, this message translates to:
  /// **'No products available.'**
  String get noProductsAvailableMessage;

  /// Message displayed when no products have low stock
  ///
  /// In en, this message translates to:
  /// **'No products with low stock.'**
  String get noLowStockProductsMessage;

  /// Message displayed when there are no transactions
  ///
  /// In en, this message translates to:
  /// **'No transactions available.'**
  String get noTransactionsAvailableMessage;

  /// Title for the search product dialog
  ///
  /// In en, this message translates to:
  /// **'Search Product'**
  String get searchProductDialogTitle;

  /// Hint text for the product search input field
  ///
  /// In en, this message translates to:
  /// **'Enter product name or barcode...'**
  String get searchProductHintText;

  /// Label for the cancel button
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancelButtonLabel;

  /// Label for the search button
  ///
  /// In en, this message translates to:
  /// **'Search'**
  String get searchButtonLabel;

  /// Title for the filter by category dialog
  ///
  /// In en, this message translates to:
  /// **'Filter by Category'**
  String get filterByCategoryDialogTitle;

  /// Message displayed when no categories are available for filtering
  ///
  /// In en, this message translates to:
  /// **'No categories available to filter.'**
  String get noCategoriesAvailableMessage;

  /// Label for the show all button in filters
  ///
  /// In en, this message translates to:
  /// **'Show All'**
  String get showAllButtonLabel;

  /// Message displayed on empty inventory screen
  ///
  /// In en, this message translates to:
  /// **'You haven\'\'t added any products to your inventory yet.'**
  String get noProductsInInventoryMessage;

  /// Label for product price
  ///
  /// In en, this message translates to:
  /// **'Price'**
  String get priceLabel;

  /// Label for product input price
  ///
  /// In en, this message translates to:
  /// **'Input'**
  String get inputPriceLabel;

  /// Label for product stock quantity
  ///
  /// In en, this message translates to:
  /// **'Stock'**
  String get stockLabel;

  /// Label for a product that cannot be found
  ///
  /// In en, this message translates to:
  /// **'Unknown Product'**
  String get unknownProductLabel;

  /// Label for quantity
  ///
  /// In en, this message translates to:
  /// **'Quantity'**
  String get quantityLabel;

  /// Label for date
  ///
  /// In en, this message translates to:
  /// **'Date'**
  String get dateLabel;

  /// Label for value
  ///
  /// In en, this message translates to:
  /// **'Label for value'**
  String get valueLabel;

  /// Label for the retry button
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get retryButtonLabel;

  /// Label for purchase stock transaction type
  ///
  /// In en, this message translates to:
  /// **'Purchase'**
  String get stockTransactionTypePurchase;

  /// Label for sale stock transaction type
  ///
  /// In en, this message translates to:
  /// **'Sale'**
  String get stockTransactionTypeSale;

  /// Label for adjustment stock transaction type
  ///
  /// In en, this message translates to:
  /// **'Adjustment'**
  String get stockTransactionTypeAdjustment;

  /// Title for the Sales Screen
  ///
  /// In en, this message translates to:
  /// **'Sales Management'**
  String get salesScreenTitle;

  /// Label for the All sales tab
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get salesTabAll;

  /// Label for the Pending sales tab
  ///
  /// In en, this message translates to:
  /// **'Pending'**
  String get salesTabPending;

  /// Label for the Completed sales tab
  ///
  /// In en, this message translates to:
  /// **'Completed'**
  String get salesTabCompleted;

  /// Title for the filter sales dialog
  ///
  /// In en, this message translates to:
  /// **'Filter Sales'**
  String get salesFilterDialogTitle;

  /// Label for the cancel button in filter sales dialog
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get salesFilterDialogCancel;

  /// Label for the apply button in filter sales dialog
  ///
  /// In en, this message translates to:
  /// **'Apply'**
  String get salesFilterDialogApply;

  /// Label for total sales in summary
  ///
  /// In en, this message translates to:
  /// **'Total Sales'**
  String get salesSummaryTotal;

  /// Label for number of sales in summary
  ///
  /// In en, this message translates to:
  /// **'Number of Sales'**
  String get salesSummaryCount;

  /// Status text for pending sales
  ///
  /// In en, this message translates to:
  /// **'Pending'**
  String get salesStatusPending;

  /// Status text for completed sales
  ///
  /// In en, this message translates to:
  /// **'Completed'**
  String get salesStatusCompleted;

  /// Status text for partially paid sales
  ///
  /// In en, this message translates to:
  /// **'Partially Paid'**
  String get salesStatusPartiallyPaid;

  /// Status text for cancelled sales
  ///
  /// In en, this message translates to:
  /// **'Cancelled'**
  String get salesStatusCancelled;

  /// Message when no sales are found
  ///
  /// In en, this message translates to:
  /// **'No sales found'**
  String get salesNoSalesFound;

  /// Label for the add sale button
  ///
  /// In en, this message translates to:
  /// **'Add Sale'**
  String get salesAddSaleButton;

  /// Prefix for error messages on sales screen
  ///
  /// In en, this message translates to:
  /// **'Error'**
  String get salesErrorPrefix;

  /// Label for the retry button on sales screen
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get salesRetryButton;

  /// Label for start date in filter sales dialog
  ///
  /// In en, this message translates to:
  /// **'Start Date'**
  String get salesFilterDialogStartDate;

  /// Label for end date in filter sales dialog
  ///
  /// In en, this message translates to:
  /// **'End Date'**
  String get salesFilterDialogEndDate;

  /// Prefix for sale ID in sale list item
  ///
  /// In en, this message translates to:
  /// **'Sale #'**
  String get salesListItemSaleIdPrefix;

  /// Text for number of articles in a sale item
  ///
  /// In en, this message translates to:
  /// **'{count,plural, =1{1 article} other{{count} articles}}'**
  String salesListItemArticles(int count);

  /// Label for total amount in sale list item
  ///
  /// In en, this message translates to:
  /// **'Total:'**
  String get salesListItemTotal;

  /// Label for remaining amount to pay in sale list item
  ///
  /// In en, this message translates to:
  /// **'Remaining to pay:'**
  String get salesListItemRemainingToPay;

  /// No description provided for @subscriptionScreenTitle.
  ///
  /// In en, this message translates to:
  /// **'Subscription Management'**
  String get subscriptionScreenTitle;

  /// No description provided for @subscriptionUnsupportedFileType.
  ///
  /// In en, this message translates to:
  /// **'Unsupported file type. Please choose a JPG or PNG file.'**
  String get subscriptionUnsupportedFileType;

  /// No description provided for @subscriptionFileTooLarge.
  ///
  /// In en, this message translates to:
  /// **'File too large. Maximum size is 5MB.'**
  String get subscriptionFileTooLarge;

  /// No description provided for @subscriptionNoImageSelected.
  ///
  /// In en, this message translates to:
  /// **'No image selected.'**
  String get subscriptionNoImageSelected;

  /// No description provided for @subscriptionUpdateSuccessMessage.
  ///
  /// In en, this message translates to:
  /// **'Subscription updated successfully.'**
  String get subscriptionUpdateSuccessMessage;

  /// No description provided for @subscriptionUpdateFailureMessage.
  ///
  /// In en, this message translates to:
  /// **'Failed to update subscription: {error}'**
  String subscriptionUpdateFailureMessage(String error);

  /// No description provided for @subscriptionTokenTopUpSuccessMessage.
  ///
  /// In en, this message translates to:
  /// **'Tokens topped up successfully.'**
  String get subscriptionTokenTopUpSuccessMessage;

  /// No description provided for @subscriptionTokenTopUpFailureMessage.
  ///
  /// In en, this message translates to:
  /// **'Failed to top up tokens: {error}'**
  String subscriptionTokenTopUpFailureMessage(String error);

  /// No description provided for @subscriptionPaymentProofUploadSuccessMessage.
  ///
  /// In en, this message translates to:
  /// **'Payment proof uploaded successfully.'**
  String get subscriptionPaymentProofUploadSuccessMessage;

  /// No description provided for @subscriptionPaymentProofUploadFailureMessage.
  ///
  /// In en, this message translates to:
  /// **'Failed to upload payment proof: {error}'**
  String subscriptionPaymentProofUploadFailureMessage(String error);

  /// No description provided for @subscriptionRetryButton.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get subscriptionRetryButton;

  /// No description provided for @subscriptionUnhandledState.
  ///
  /// In en, this message translates to:
  /// **'Unhandled state or initialization...'**
  String get subscriptionUnhandledState;

  /// No description provided for @subscriptionSectionOurOffers.
  ///
  /// In en, this message translates to:
  /// **'Our Subscription Offers'**
  String get subscriptionSectionOurOffers;

  /// No description provided for @subscriptionSectionCurrentSubscription.
  ///
  /// In en, this message translates to:
  /// **'Your Current Subscription'**
  String get subscriptionSectionCurrentSubscription;

  /// No description provided for @subscriptionSectionTokenUsage.
  ///
  /// In en, this message translates to:
  /// **'Adha Token Usage'**
  String get subscriptionSectionTokenUsage;

  /// No description provided for @subscriptionSectionInvoiceHistory.
  ///
  /// In en, this message translates to:
  /// **'Invoice History'**
  String get subscriptionSectionInvoiceHistory;

  /// No description provided for @subscriptionSectionPaymentMethods.
  ///
  /// In en, this message translates to:
  /// **'Payment Methods'**
  String get subscriptionSectionPaymentMethods;

  /// No description provided for @subscriptionChangeSubscriptionButton.
  ///
  /// In en, this message translates to:
  /// **'Change Subscription'**
  String get subscriptionChangeSubscriptionButton;

  /// No description provided for @subscriptionTierFree.
  ///
  /// In en, this message translates to:
  /// **'Free'**
  String get subscriptionTierFree;

  /// No description provided for @subscriptionTierUsers.
  ///
  /// In en, this message translates to:
  /// **'Users: {count}'**
  String subscriptionTierUsers(int count);

  /// No description provided for @subscriptionTierAdhaTokens.
  ///
  /// In en, this message translates to:
  /// **'Adha Tokens: {count}'**
  String subscriptionTierAdhaTokens(int count);

  /// No description provided for @subscriptionTierFeatures.
  ///
  /// In en, this message translates to:
  /// **'Features:'**
  String get subscriptionTierFeatures;

  /// No description provided for @subscriptionTierCurrentPlanChip.
  ///
  /// In en, this message translates to:
  /// **'Current Plan'**
  String get subscriptionTierCurrentPlanChip;

  /// No description provided for @subscriptionTierChoosePlanButton.
  ///
  /// In en, this message translates to:
  /// **'Choose this plan'**
  String get subscriptionTierChoosePlanButton;

  /// No description provided for @subscriptionCurrentPlanTitle.
  ///
  /// In en, this message translates to:
  /// **'Current Plan: {tierName}'**
  String subscriptionCurrentPlanTitle(String tierName);

  /// No description provided for @subscriptionCurrentPlanPrice.
  ///
  /// In en, this message translates to:
  /// **'Price: {price}'**
  String subscriptionCurrentPlanPrice(String price);

  /// No description provided for @subscriptionAvailableAdhaTokens.
  ///
  /// In en, this message translates to:
  /// **'Available Adha Tokens: {count}'**
  String subscriptionAvailableAdhaTokens(int count);

  /// No description provided for @subscriptionTopUpTokensButton.
  ///
  /// In en, this message translates to:
  /// **'Top-up Tokens'**
  String get subscriptionTopUpTokensButton;

  /// No description provided for @subscriptionNoInvoices.
  ///
  /// In en, this message translates to:
  /// **'No invoices available at the moment.'**
  String get subscriptionNoInvoices;

  /// No description provided for @subscriptionInvoiceListTitle.
  ///
  /// In en, this message translates to:
  /// **'Invoice {id} - {date}'**
  String subscriptionInvoiceListTitle(String id, String date);

  /// No description provided for @subscriptionInvoiceListSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Amount: {amount} - Status: {status}'**
  String subscriptionInvoiceListSubtitle(String amount, String status);

  /// No description provided for @subscriptionDownloadInvoiceTooltip.
  ///
  /// In en, this message translates to:
  /// **'Download invoice'**
  String get subscriptionDownloadInvoiceTooltip;

  /// No description provided for @subscriptionSimulateDownloadInvoice.
  ///
  /// In en, this message translates to:
  /// **'Simulation: Downloading {id} from {url}'**
  String subscriptionSimulateDownloadInvoice(String id, String url);

  /// No description provided for @subscriptionSimulateViewInvoiceDetails.
  ///
  /// In en, this message translates to:
  /// **'Simulation: View invoice details {id}'**
  String subscriptionSimulateViewInvoiceDetails(String id);

  /// No description provided for @subscriptionPaymentMethodsNextInvoice.
  ///
  /// In en, this message translates to:
  /// **'Payment methods for the next invoice:'**
  String get subscriptionPaymentMethodsNextInvoice;

  /// No description provided for @subscriptionPaymentMethodsRegistered.
  ///
  /// In en, this message translates to:
  /// **'Registered methods:'**
  String get subscriptionPaymentMethodsRegistered;

  /// No description provided for @subscriptionPaymentMethodsOtherOptions.
  ///
  /// In en, this message translates to:
  /// **'Other payment options:'**
  String get subscriptionPaymentMethodsOtherOptions;

  /// No description provided for @subscriptionPaymentMethodNewCard.
  ///
  /// In en, this message translates to:
  /// **'New Credit Card'**
  String get subscriptionPaymentMethodNewCard;

  /// No description provided for @subscriptionPaymentMethodNewMobileMoney.
  ///
  /// In en, this message translates to:
  /// **'New Mobile Money'**
  String get subscriptionPaymentMethodNewMobileMoney;

  /// No description provided for @subscriptionPaymentMethodManual.
  ///
  /// In en, this message translates to:
  /// **'Manual Payment (Transfer/Deposit)'**
  String get subscriptionPaymentMethodManual;

  /// No description provided for @subscriptionManualPaymentInstructions.
  ///
  /// In en, this message translates to:
  /// **'Please make the transfer/deposit to the provided details and upload a proof of payment.'**
  String get subscriptionManualPaymentInstructions;

  /// No description provided for @subscriptionProofUploadedLabel.
  ///
  /// In en, this message translates to:
  /// **'Proof Uploaded: {fileName}'**
  String subscriptionProofUploadedLabel(String fileName);

  /// No description provided for @subscriptionUploadProofButton.
  ///
  /// In en, this message translates to:
  /// **'Upload Proof'**
  String get subscriptionUploadProofButton;

  /// No description provided for @subscriptionReplaceProofButton.
  ///
  /// In en, this message translates to:
  /// **'Replace Proof'**
  String get subscriptionReplaceProofButton;

  /// No description provided for @subscriptionConfirmPaymentMethodButton.
  ///
  /// In en, this message translates to:
  /// **'Confirm Payment Method'**
  String get subscriptionConfirmPaymentMethodButton;

  /// No description provided for @subscriptionSimulatePaymentMethodSelected.
  ///
  /// In en, this message translates to:
  /// **'Selected payment method: {method} (Simulation)'**
  String subscriptionSimulatePaymentMethodSelected(String method);

  /// No description provided for @subscriptionChangeDialogTitle.
  ///
  /// In en, this message translates to:
  /// **'Change Subscription'**
  String get subscriptionChangeDialogTitle;

  /// No description provided for @subscriptionChangeDialogTierSubtitle.
  ///
  /// In en, this message translates to:
  /// **'{price} - Tokens: {tokens}'**
  String subscriptionChangeDialogTierSubtitle(String price, String tokens);

  /// No description provided for @subscriptionTopUpDialogTitle.
  ///
  /// In en, this message translates to:
  /// **'Top-up Adha Tokens'**
  String get subscriptionTopUpDialogTitle;

  /// No description provided for @subscriptionTopUpDialogAmount.
  ///
  /// In en, this message translates to:
  /// **'{amount} {currencyCode}'**
  String subscriptionTopUpDialogAmount(String amount, String currencyCode);

  /// No description provided for @subscriptionNoActivePlan.
  ///
  /// In en, this message translates to:
  /// **'You do not have an active subscription plan.'**
  String get subscriptionNoActivePlan;

  /// No description provided for @contactsScreenTitle.
  ///
  /// In en, this message translates to:
  /// **'Contacts'**
  String get contactsScreenTitle;

  /// No description provided for @contactsScreenClientsTab.
  ///
  /// In en, this message translates to:
  /// **'Clients'**
  String get contactsScreenClientsTab;

  /// No description provided for @contactsScreenSuppliersTab.
  ///
  /// In en, this message translates to:
  /// **'Suppliers'**
  String get contactsScreenSuppliersTab;

  /// No description provided for @contactsScreenAddClientTooltip.
  ///
  /// In en, this message translates to:
  /// **'Add a client'**
  String get contactsScreenAddClientTooltip;

  /// No description provided for @contactsScreenAddSupplierTooltip.
  ///
  /// In en, this message translates to:
  /// **'Add a supplier'**
  String get contactsScreenAddSupplierTooltip;

  /// No description provided for @searchCustomerHint.
  ///
  /// In en, this message translates to:
  /// **'Search for a customer...'**
  String get searchCustomerHint;

  /// No description provided for @customerError.
  ///
  /// In en, this message translates to:
  /// **'Error: {message}'**
  String customerError(String message);

  /// No description provided for @noCustomersToShow.
  ///
  /// In en, this message translates to:
  /// **'No customers to display'**
  String get noCustomersToShow;

  /// No description provided for @customersTitle.
  ///
  /// In en, this message translates to:
  /// **'Customers'**
  String get customersTitle;

  /// No description provided for @filterCustomersTooltip.
  ///
  /// In en, this message translates to:
  /// **'Filter customers'**
  String get filterCustomersTooltip;

  /// No description provided for @addCustomerTooltip.
  ///
  /// In en, this message translates to:
  /// **'Add a new customer'**
  String get addCustomerTooltip;

  /// No description provided for @noResultsForSearchTerm.
  ///
  /// In en, this message translates to:
  /// **'No results for {searchTerm}'**
  String noResultsForSearchTerm(String searchTerm);

  /// No description provided for @noCustomersAvailable.
  ///
  /// In en, this message translates to:
  /// **'No customers available'**
  String get noCustomersAvailable;

  /// No description provided for @topCustomersByPurchases.
  ///
  /// In en, this message translates to:
  /// **'Top customers by purchases'**
  String get topCustomersByPurchases;

  /// No description provided for @recentlyAddedCustomers.
  ///
  /// In en, this message translates to:
  /// **'Recently added customers'**
  String get recentlyAddedCustomers;

  /// No description provided for @resultsForSearchTerm.
  ///
  /// In en, this message translates to:
  /// **'Results for {searchTerm}'**
  String resultsForSearchTerm(String searchTerm);

  /// No description provided for @lastPurchaseDate.
  ///
  /// In en, this message translates to:
  /// **'Last purchase: {date}'**
  String lastPurchaseDate(String date);

  /// No description provided for @noRecentPurchase.
  ///
  /// In en, this message translates to:
  /// **'No recent purchase'**
  String get noRecentPurchase;

  /// No description provided for @totalPurchasesAmount.
  ///
  /// In en, this message translates to:
  /// **'Total purchases: {amount}'**
  String totalPurchasesAmount(String amount);

  /// No description provided for @viewDetails.
  ///
  /// In en, this message translates to:
  /// **'View details'**
  String get viewDetails;

  /// No description provided for @edit.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get edit;

  /// No description provided for @allCustomers.
  ///
  /// In en, this message translates to:
  /// **'All customers'**
  String get allCustomers;

  /// No description provided for @topCustomers.
  ///
  /// In en, this message translates to:
  /// **'Top customers'**
  String get topCustomers;

  /// No description provided for @recentCustomers.
  ///
  /// In en, this message translates to:
  /// **'Recent customers'**
  String get recentCustomers;

  /// No description provided for @byCategory.
  ///
  /// In en, this message translates to:
  /// **'By category'**
  String get byCategory;

  /// No description provided for @filterByCategory.
  ///
  /// In en, this message translates to:
  /// **'Filter by category'**
  String get filterByCategory;

  /// No description provided for @deleteCustomerTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete customer'**
  String get deleteCustomerTitle;

  /// No description provided for @deleteCustomerConfirmation.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to delete {customerName}? This action is irreversible.'**
  String deleteCustomerConfirmation(String customerName);

  /// No description provided for @customerCategoryVip.
  ///
  /// In en, this message translates to:
  /// **'VIP'**
  String get customerCategoryVip;

  /// No description provided for @customerCategoryRegular.
  ///
  /// In en, this message translates to:
  /// **'Regular'**
  String get customerCategoryRegular;

  /// No description provided for @customerCategoryNew.
  ///
  /// In en, this message translates to:
  /// **'New'**
  String get customerCategoryNew;

  /// No description provided for @customerCategoryOccasional.
  ///
  /// In en, this message translates to:
  /// **'Occasional'**
  String get customerCategoryOccasional;

  /// No description provided for @customerCategoryBusiness.
  ///
  /// In en, this message translates to:
  /// **'Business'**
  String get customerCategoryBusiness;

  /// No description provided for @customerCategoryUnknown.
  ///
  /// In en, this message translates to:
  /// **'Unknown'**
  String get customerCategoryUnknown;

  /// No description provided for @editCustomerTitle.
  ///
  /// In en, this message translates to:
  /// **'Edit Customer'**
  String get editCustomerTitle;

  /// No description provided for @addCustomerTitle.
  ///
  /// In en, this message translates to:
  /// **'Add Customer'**
  String get addCustomerTitle;

  /// No description provided for @customerPhoneHint.
  ///
  /// In en, this message translates to:
  /// **'+243 999 123 456'**
  String get customerPhoneHint;

  /// No description provided for @customerInformation.
  ///
  /// In en, this message translates to:
  /// **'Customer Information'**
  String get customerInformation;

  /// No description provided for @customerNameLabel.
  ///
  /// In en, this message translates to:
  /// **'Customer Name'**
  String get customerNameLabel;

  /// No description provided for @customerNameValidationError.
  ///
  /// In en, this message translates to:
  /// **'Please enter the customer\'s name.'**
  String get customerNameValidationError;

  /// No description provided for @customerPhoneLabel.
  ///
  /// In en, this message translates to:
  /// **'Customer Phone'**
  String get customerPhoneLabel;

  /// No description provided for @customerPhoneValidationError.
  ///
  /// In en, this message translates to:
  /// **'Please enter the customer\'s phone number.'**
  String get customerPhoneValidationError;

  /// No description provided for @customerEmailLabel.
  ///
  /// In en, this message translates to:
  /// **'Customer Email (Optional)'**
  String get customerEmailLabel;

  /// No description provided for @customerEmailLabelOptional.
  ///
  /// In en, this message translates to:
  /// **'Customer Email'**
  String get customerEmailLabelOptional;

  /// No description provided for @customerEmailValidationError.
  ///
  /// In en, this message translates to:
  /// **'Please enter a valid email address.'**
  String get customerEmailValidationError;

  /// No description provided for @customerAddressLabel.
  ///
  /// In en, this message translates to:
  /// **'Customer Address (Optional)'**
  String get customerAddressLabel;

  /// No description provided for @customerAddressLabelOptional.
  ///
  /// In en, this message translates to:
  /// **'Customer Address'**
  String get customerAddressLabelOptional;

  /// No description provided for @customerCategoryLabel.
  ///
  /// In en, this message translates to:
  /// **'Customer Category'**
  String get customerCategoryLabel;

  /// No description provided for @customerNotesLabel.
  ///
  /// In en, this message translates to:
  /// **'Notes (Optional)'**
  String get customerNotesLabel;

  /// No description provided for @updateButtonLabel.
  ///
  /// In en, this message translates to:
  /// **'Update'**
  String get updateButtonLabel;

  /// No description provided for @customerDetailsTitle.
  ///
  /// In en, this message translates to:
  /// **'Customer Details'**
  String get customerDetailsTitle;

  /// No description provided for @editCustomerTooltip.
  ///
  /// In en, this message translates to:
  /// **'Edit customer'**
  String get editCustomerTooltip;

  /// No description provided for @customerNotFound.
  ///
  /// In en, this message translates to:
  /// **'Customer not found'**
  String get customerNotFound;

  /// No description provided for @contactInformationSectionTitle.
  ///
  /// In en, this message translates to:
  /// **'Contact Information'**
  String get contactInformationSectionTitle;

  /// No description provided for @purchaseStatisticsSectionTitle.
  ///
  /// In en, this message translates to:
  /// **'Purchase Statistics'**
  String get purchaseStatisticsSectionTitle;

  /// No description provided for @totalPurchasesLabel.
  ///
  /// In en, this message translates to:
  /// **'Total Purchases'**
  String get totalPurchasesLabel;

  /// No description provided for @lastPurchaseLabel.
  ///
  /// In en, this message translates to:
  /// **'Last Purchase'**
  String get lastPurchaseLabel;

  /// No description provided for @noPurchaseRecorded.
  ///
  /// In en, this message translates to:
  /// **'No purchase recorded'**
  String get noPurchaseRecorded;

  /// No description provided for @customerSinceLabel.
  ///
  /// In en, this message translates to:
  /// **'Customer Since'**
  String get customerSinceLabel;

  /// No description provided for @addSaleButtonLabel.
  ///
  /// In en, this message translates to:
  /// **'Add Sale'**
  String get addSaleButtonLabel;

  /// No description provided for @callButtonLabel.
  ///
  /// In en, this message translates to:
  /// **'Call'**
  String get callButtonLabel;

  /// No description provided for @deleteButtonLabel.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get deleteButtonLabel;

  /// No description provided for @callingNumber.
  ///
  /// In en, this message translates to:
  /// **'Calling {phoneNumber}...'**
  String callingNumber(String phoneNumber);

  /// No description provided for @emailingTo.
  ///
  /// In en, this message translates to:
  /// **'Emailing to {email}...'**
  String emailingTo(String email);

  /// No description provided for @openingMapFor.
  ///
  /// In en, this message translates to:
  /// **'Opening map for {address}...'**
  String openingMapFor(String address);

  /// No description provided for @searchSupplierHint.
  ///
  /// In en, this message translates to:
  /// **'Search for a supplier...'**
  String get searchSupplierHint;

  /// No description provided for @clearSearchTooltip.
  ///
  /// In en, this message translates to:
  /// **'Clear search'**
  String get clearSearchTooltip;

  /// No description provided for @supplierError.
  ///
  /// In en, this message translates to:
  /// **'Error: {message}'**
  String supplierError(String message);

  /// No description provided for @noSuppliersToShow.
  ///
  /// In en, this message translates to:
  /// **'No suppliers to display'**
  String get noSuppliersToShow;

  /// No description provided for @suppliersTitle.
  ///
  /// In en, this message translates to:
  /// **'Suppliers'**
  String get suppliersTitle;

  /// No description provided for @filterSuppliersTooltip.
  ///
  /// In en, this message translates to:
  /// **'Filter suppliers'**
  String get filterSuppliersTooltip;

  /// No description provided for @addSupplierTooltip.
  ///
  /// In en, this message translates to:
  /// **'Add a new supplier'**
  String get addSupplierTooltip;

  /// No description provided for @noSuppliersAvailable.
  ///
  /// In en, this message translates to:
  /// **'No suppliers available'**
  String get noSuppliersAvailable;

  /// No description provided for @topSuppliersByPurchases.
  ///
  /// In en, this message translates to:
  /// **'Top suppliers by purchases'**
  String get topSuppliersByPurchases;

  /// No description provided for @recentlyAddedSuppliers.
  ///
  /// In en, this message translates to:
  /// **'Recently added suppliers'**
  String get recentlyAddedSuppliers;

  /// No description provided for @contactPerson.
  ///
  /// In en, this message translates to:
  /// **'Contact: {name}'**
  String contactPerson(String name);

  /// No description provided for @moreOptionsTooltip.
  ///
  /// In en, this message translates to:
  /// **'More options'**
  String get moreOptionsTooltip;

  /// No description provided for @allSuppliers.
  ///
  /// In en, this message translates to:
  /// **'All suppliers'**
  String get allSuppliers;

  /// No description provided for @topSuppliers.
  ///
  /// In en, this message translates to:
  /// **'Top suppliers'**
  String get topSuppliers;

  /// No description provided for @recentSuppliers.
  ///
  /// In en, this message translates to:
  /// **'Recent suppliers'**
  String get recentSuppliers;

  /// No description provided for @deleteSupplierTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete supplier'**
  String get deleteSupplierTitle;

  /// No description provided for @deleteSupplierConfirmation.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to delete {supplierName}? This action is irreversible.'**
  String deleteSupplierConfirmation(String supplierName);

  /// No description provided for @supplierCategoryStrategic.
  ///
  /// In en, this message translates to:
  /// **'Strategic'**
  String get supplierCategoryStrategic;

  /// No description provided for @supplierCategoryRegular.
  ///
  /// In en, this message translates to:
  /// **'Regular'**
  String get supplierCategoryRegular;

  /// No description provided for @supplierCategoryNew.
  ///
  /// In en, this message translates to:
  /// **'New'**
  String get supplierCategoryNew;

  /// No description provided for @supplierCategoryOccasional.
  ///
  /// In en, this message translates to:
  /// **'Occasional'**
  String get supplierCategoryOccasional;

  /// No description provided for @supplierCategoryInternational.
  ///
  /// In en, this message translates to:
  /// **'International'**
  String get supplierCategoryInternational;

  /// No description provided for @supplierCategoryUnknown.
  ///
  /// In en, this message translates to:
  /// **'Unknown'**
  String get supplierCategoryUnknown;

  /// Supplier category: Local
  ///
  /// In en, this message translates to:
  /// **'Local'**
  String get supplierCategoryLocal;

  /// Supplier category: Online
  ///
  /// In en, this message translates to:
  /// **'Online'**
  String get supplierCategoryOnline;

  /// No description provided for @addSupplierTitle.
  ///
  /// In en, this message translates to:
  /// **'Add Supplier'**
  String get addSupplierTitle;

  /// No description provided for @editSupplierTitle.
  ///
  /// In en, this message translates to:
  /// **'Edit Supplier'**
  String get editSupplierTitle;

  /// No description provided for @supplierInformation.
  ///
  /// In en, this message translates to:
  /// **'Supplier Information'**
  String get supplierInformation;

  /// No description provided for @supplierNameLabel.
  ///
  /// In en, this message translates to:
  /// **'Supplier Name *'**
  String get supplierNameLabel;

  /// No description provided for @supplierNameValidationError.
  ///
  /// In en, this message translates to:
  /// **'Name is required'**
  String get supplierNameValidationError;

  /// No description provided for @supplierPhoneLabel.
  ///
  /// In en, this message translates to:
  /// **'Phone Number *'**
  String get supplierPhoneLabel;

  /// No description provided for @supplierPhoneValidationError.
  ///
  /// In en, this message translates to:
  /// **'Phone number is required'**
  String get supplierPhoneValidationError;

  /// No description provided for @supplierPhoneHint.
  ///
  /// In en, this message translates to:
  /// **'+243 999 123 456'**
  String get supplierPhoneHint;

  /// No description provided for @supplierEmailLabel.
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get supplierEmailLabel;

  /// No description provided for @supplierEmailValidationError.
  ///
  /// In en, this message translates to:
  /// **'Please enter a valid email'**
  String get supplierEmailValidationError;

  /// No description provided for @supplierContactPersonLabel.
  ///
  /// In en, this message translates to:
  /// **'Contact Person'**
  String get supplierContactPersonLabel;

  /// No description provided for @supplierAddressLabel.
  ///
  /// In en, this message translates to:
  /// **'Address'**
  String get supplierAddressLabel;

  /// No description provided for @commercialInformation.
  ///
  /// In en, this message translates to:
  /// **'Commercial Information'**
  String get commercialInformation;

  /// No description provided for @deliveryTimeLabel.
  ///
  /// In en, this message translates to:
  /// **'Delivery Time'**
  String get deliveryTimeLabel;

  /// No description provided for @paymentTermsLabel.
  ///
  /// In en, this message translates to:
  /// **'Payment Terms'**
  String get paymentTermsLabel;

  /// No description provided for @paymentTermsHint.
  ///
  /// In en, this message translates to:
  /// **'Ex: Net 30, 50% upfront, etc.'**
  String get paymentTermsHint;

  /// No description provided for @supplierCategoryLabel.
  ///
  /// In en, this message translates to:
  /// **'Supplier Category'**
  String get supplierCategoryLabel;

  /// No description provided for @supplierNotesLabel.
  ///
  /// In en, this message translates to:
  /// **'Notes'**
  String get supplierNotesLabel;

  /// No description provided for @updateSupplierButton.
  ///
  /// In en, this message translates to:
  /// **'Update'**
  String get updateSupplierButton;

  /// No description provided for @addSupplierButton.
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get addSupplierButton;

  /// No description provided for @supplierDetailsTitle.
  ///
  /// In en, this message translates to:
  /// **'Supplier Details'**
  String get supplierDetailsTitle;

  /// No description provided for @supplierErrorLoading.
  ///
  /// In en, this message translates to:
  /// **'Error: {message}'**
  String supplierErrorLoading(String message);

  /// No description provided for @supplierNotFound.
  ///
  /// In en, this message translates to:
  /// **'Supplier not found'**
  String get supplierNotFound;

  /// No description provided for @contactLabel.
  ///
  /// In en, this message translates to:
  /// **'Contact'**
  String get contactLabel;

  /// No description provided for @phoneLabel.
  ///
  /// In en, this message translates to:
  /// **'Phone'**
  String get phoneLabel;

  /// No description provided for @emailLabel.
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get emailLabel;

  /// No description provided for @addressLabel.
  ///
  /// In en, this message translates to:
  /// **'Address'**
  String get addressLabel;

  /// No description provided for @commercialInformationSectionTitle.
  ///
  /// In en, this message translates to:
  /// **'Commercial Information'**
  String get commercialInformationSectionTitle;

  /// No description provided for @deliveryTimeInDays.
  ///
  /// In en, this message translates to:
  /// **'{count,plural, =0{Not specified} =1{1 day} other{{count} days}}'**
  String deliveryTimeInDays(int count);

  /// No description provided for @supplierSinceLabel.
  ///
  /// In en, this message translates to:
  /// **'Supplier Since'**
  String get supplierSinceLabel;

  /// No description provided for @notesSectionTitle.
  ///
  /// In en, this message translates to:
  /// **'Notes'**
  String get notesSectionTitle;

  /// No description provided for @placeOrderButtonLabel.
  ///
  /// In en, this message translates to:
  /// **'Place Order'**
  String get placeOrderButtonLabel;

  /// No description provided for @featureToImplement.
  ///
  /// In en, this message translates to:
  /// **'Feature to implement'**
  String get featureToImplement;

  /// No description provided for @confirmDeleteSupplierTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete Supplier'**
  String get confirmDeleteSupplierTitle;

  /// No description provided for @confirmDeleteSupplierMessage.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to delete {supplierName}? This action is irreversible.'**
  String confirmDeleteSupplierMessage(String supplierName);

  /// No description provided for @commonConfirm.
  ///
  /// In en, this message translates to:
  /// **'Confirm'**
  String get commonConfirm;

  /// No description provided for @commonError.
  ///
  /// In en, this message translates to:
  /// **'Error'**
  String get commonError;

  /// No description provided for @commonToday.
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get commonToday;

  /// No description provided for @commonThisMonth.
  ///
  /// In en, this message translates to:
  /// **'This Month'**
  String get commonThisMonth;

  /// No description provided for @commonThisYear.
  ///
  /// In en, this message translates to:
  /// **'This Year'**
  String get commonThisYear;

  /// No description provided for @commonCustom.
  ///
  /// In en, this message translates to:
  /// **'Custom'**
  String get commonCustom;

  /// No description provided for @commonAnonymousClient.
  ///
  /// In en, this message translates to:
  /// **'Anonymous Client'**
  String get commonAnonymousClient;

  /// No description provided for @commonAnonymousClientInitial.
  ///
  /// In en, this message translates to:
  /// **'A'**
  String get commonAnonymousClientInitial;

  /// No description provided for @commonErrorDataUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Data unavailable'**
  String get commonErrorDataUnavailable;

  /// No description provided for @commonNoData.
  ///
  /// In en, this message translates to:
  /// **'No data available'**
  String get commonNoData;

  /// No description provided for @dashboardScreenTitle.
  ///
  /// In en, this message translates to:
  /// **'Dashboard'**
  String get dashboardScreenTitle;

  /// No description provided for @dashboardHeaderSalesToday.
  ///
  /// In en, this message translates to:
  /// **'Sales Today'**
  String get dashboardHeaderSalesToday;

  /// No description provided for @dashboardHeaderClientsServed.
  ///
  /// In en, this message translates to:
  /// **'Clients Served'**
  String get dashboardHeaderClientsServed;

  /// No description provided for @dashboardHeaderReceivables.
  ///
  /// In en, this message translates to:
  /// **'Receivables'**
  String get dashboardHeaderReceivables;

  /// No description provided for @dashboardHeaderTransactions.
  ///
  /// In en, this message translates to:
  /// **'Transactions'**
  String get dashboardHeaderTransactions;

  /// No description provided for @dashboardCardViewDetails.
  ///
  /// In en, this message translates to:
  /// **'View Details'**
  String get dashboardCardViewDetails;

  /// No description provided for @dashboardSalesChartTitle.
  ///
  /// In en, this message translates to:
  /// **'Sales Overview'**
  String get dashboardSalesChartTitle;

  /// No description provided for @dashboardSalesChartNoData.
  ///
  /// In en, this message translates to:
  /// **'No sales data to display for the chart.'**
  String get dashboardSalesChartNoData;

  /// No description provided for @dashboardRecentSalesTitle.
  ///
  /// In en, this message translates to:
  /// **'Recent Sales'**
  String get dashboardRecentSalesTitle;

  /// No description provided for @dashboardRecentSalesViewAll.
  ///
  /// In en, this message translates to:
  /// **'View All'**
  String get dashboardRecentSalesViewAll;

  /// No description provided for @dashboardRecentSalesNoData.
  ///
  /// In en, this message translates to:
  /// **'No recent sales.'**
  String get dashboardRecentSalesNoData;

  /// No description provided for @dashboardOperationsJournalTitle.
  ///
  /// In en, this message translates to:
  /// **'Operations Journal'**
  String get dashboardOperationsJournalTitle;

  /// No description provided for @dashboardOperationsJournalViewAll.
  ///
  /// In en, this message translates to:
  /// **'View All'**
  String get dashboardOperationsJournalViewAll;

  /// No description provided for @dashboardOperationsJournalNoData.
  ///
  /// In en, this message translates to:
  /// **'No recent operations.'**
  String get dashboardOperationsJournalNoData;

  /// No description provided for @dashboardOperationsJournalBalanceLabel.
  ///
  /// In en, this message translates to:
  /// **'Balance'**
  String get dashboardOperationsJournalBalanceLabel;

  /// No description provided for @dashboardJournalExportSelectDateRangeTitle.
  ///
  /// In en, this message translates to:
  /// **'Select Date Range'**
  String get dashboardJournalExportSelectDateRangeTitle;

  /// No description provided for @dashboardJournalExportExportButton.
  ///
  /// In en, this message translates to:
  /// **'Export to PDF'**
  String get dashboardJournalExportExportButton;

  /// No description provided for @dashboardJournalExportPrintButton.
  ///
  /// In en, this message translates to:
  /// **'Print Journal'**
  String get dashboardJournalExportPrintButton;

  /// No description provided for @dashboardJournalExportSuccessMessage.
  ///
  /// In en, this message translates to:
  /// **'Journal exported successfully.'**
  String get dashboardJournalExportSuccessMessage;

  /// No description provided for @dashboardJournalExportFailureMessage.
  ///
  /// In en, this message translates to:
  /// **'Failed to export journal.'**
  String get dashboardJournalExportFailureMessage;

  /// No description provided for @dashboardJournalExportNoDataForPeriod.
  ///
  /// In en, this message translates to:
  /// **'No data available for the selected period to export.'**
  String get dashboardJournalExportNoDataForPeriod;

  /// No description provided for @dashboardJournalExportPrintingMessage.
  ///
  /// In en, this message translates to:
  /// **'Preparing journal for printing...'**
  String get dashboardJournalExportPrintingMessage;

  /// No description provided for @dashboardQuickActionsTitle.
  ///
  /// In en, this message translates to:
  /// **'Quick Actions'**
  String get dashboardQuickActionsTitle;

  /// No description provided for @dashboardQuickActionsNewSale.
  ///
  /// In en, this message translates to:
  /// **'New Sale'**
  String get dashboardQuickActionsNewSale;

  /// No description provided for @dashboardQuickActionsNewExpense.
  ///
  /// In en, this message translates to:
  /// **'New Expense'**
  String get dashboardQuickActionsNewExpense;

  /// No description provided for @dashboardQuickActionsNewProduct.
  ///
  /// In en, this message translates to:
  /// **'New Product'**
  String get dashboardQuickActionsNewProduct;

  /// No description provided for @dashboardQuickActionsNewService.
  ///
  /// In en, this message translates to:
  /// **'New Service'**
  String get dashboardQuickActionsNewService;

  /// No description provided for @dashboardQuickActionsNewClient.
  ///
  /// In en, this message translates to:
  /// **'New Client'**
  String get dashboardQuickActionsNewClient;

  /// No description provided for @dashboardQuickActionsNewSupplier.
  ///
  /// In en, this message translates to:
  /// **'New Supplier'**
  String get dashboardQuickActionsNewSupplier;

  /// No description provided for @dashboardQuickActionsCashRegister.
  ///
  /// In en, this message translates to:
  /// **'Cash Register'**
  String get dashboardQuickActionsCashRegister;

  /// No description provided for @dashboardQuickActionsSettings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get dashboardQuickActionsSettings;

  /// No description provided for @dashboardQuickActionsNewInvoice.
  ///
  /// In en, this message translates to:
  /// **'Invoicing'**
  String get dashboardQuickActionsNewInvoice;

  /// No description provided for @dashboardQuickActionsNewFinancing.
  ///
  /// In en, this message translates to:
  /// **'Financing'**
  String get dashboardQuickActionsNewFinancing;

  /// No description provided for @commonLoading.
  ///
  /// In en, this message translates to:
  /// **'Loading...'**
  String get commonLoading;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @journalPdf_title.
  ///
  /// In en, this message translates to:
  /// **'Operations Journal'**
  String get journalPdf_title;

  /// Footer for PDF, shows current and total pages
  ///
  /// In en, this message translates to:
  /// **'Page {currentPage} of {totalPages}'**
  String journalPdf_footer_pageInfo(int currentPage, int totalPages);

  /// Indicates the period covered by the journal
  ///
  /// In en, this message translates to:
  /// **'Period: {startDate} - {endDate}'**
  String journalPdf_period(String startDate, String endDate);

  /// No description provided for @journalPdf_tableHeader_date.
  ///
  /// In en, this message translates to:
  /// **'Date'**
  String get journalPdf_tableHeader_date;

  /// No description provided for @journalPdf_tableHeader_time.
  ///
  /// In en, this message translates to:
  /// **'Time'**
  String get journalPdf_tableHeader_time;

  /// No description provided for @journalPdf_tableHeader_description.
  ///
  /// In en, this message translates to:
  /// **'Description'**
  String get journalPdf_tableHeader_description;

  /// No description provided for @journalPdf_tableHeader_debit.
  ///
  /// In en, this message translates to:
  /// **'Debit'**
  String get journalPdf_tableHeader_debit;

  /// No description provided for @journalPdf_tableHeader_credit.
  ///
  /// In en, this message translates to:
  /// **'Credit'**
  String get journalPdf_tableHeader_credit;

  /// No description provided for @journalPdf_tableHeader_balance.
  ///
  /// In en, this message translates to:
  /// **'Balance'**
  String get journalPdf_tableHeader_balance;

  /// No description provided for @journalPdf_openingBalance.
  ///
  /// In en, this message translates to:
  /// **'Opening Balance'**
  String get journalPdf_openingBalance;

  /// No description provided for @journalPdf_closingBalance.
  ///
  /// In en, this message translates to:
  /// **'Closing Balance'**
  String get journalPdf_closingBalance;

  /// No description provided for @journalPdf_footer_generatedBy.
  ///
  /// In en, this message translates to:
  /// **'Generated by Wanzo'**
  String get journalPdf_footer_generatedBy;

  /// No description provided for @adhaHomePageTitle.
  ///
  /// In en, this message translates to:
  /// **'Adha - AI Assistant'**
  String get adhaHomePageTitle;

  /// No description provided for @adhaHomePageDescription.
  ///
  /// In en, this message translates to:
  /// **'Adha, your smart business assistant'**
  String get adhaHomePageDescription;

  /// No description provided for @adhaHomePageBody.
  ///
  /// In en, this message translates to:
  /// **'Ask me questions about your business and I will help you make the best decisions with personalized analysis and advice.'**
  String get adhaHomePageBody;

  /// No description provided for @startConversationButton.
  ///
  /// In en, this message translates to:
  /// **'Start a conversation'**
  String get startConversationButton;

  /// No description provided for @viewConversationsButton.
  ///
  /// In en, this message translates to:
  /// **'View my conversations'**
  String get viewConversationsButton;

  /// No description provided for @salesAnalysisFeatureTitle.
  ///
  /// In en, this message translates to:
  /// **'Sales Analysis'**
  String get salesAnalysisFeatureTitle;

  /// No description provided for @salesAnalysisFeatureDescription.
  ///
  /// In en, this message translates to:
  /// **'Get insights into your sales performance'**
  String get salesAnalysisFeatureDescription;

  /// No description provided for @inventoryManagementFeatureTitle.
  ///
  /// In en, this message translates to:
  /// **'Inventory Management'**
  String get inventoryManagementFeatureTitle;

  /// No description provided for @inventoryManagementFeatureDescription.
  ///
  /// In en, this message translates to:
  /// **'Track and optimize your inventory'**
  String get inventoryManagementFeatureDescription;

  /// No description provided for @customerRelationsFeatureTitle.
  ///
  /// In en, this message translates to:
  /// **'Customer Relations'**
  String get customerRelationsFeatureTitle;

  /// No description provided for @customerRelationsFeatureDescription.
  ///
  /// In en, this message translates to:
  /// **'Advice for retaining your customers'**
  String get customerRelationsFeatureDescription;

  /// No description provided for @financialCalculationsFeatureTitle.
  ///
  /// In en, this message translates to:
  /// **'Financial Calculations'**
  String get financialCalculationsFeatureTitle;

  /// No description provided for @financialCalculationsFeatureDescription.
  ///
  /// In en, this message translates to:
  /// **'Financial projections and analysis'**
  String get financialCalculationsFeatureDescription;

  /// No description provided for @loginButton.
  ///
  /// In en, this message translates to:
  /// **'Login'**
  String get loginButton;

  /// No description provided for @registerButton.
  ///
  /// In en, this message translates to:
  /// **'Register'**
  String get registerButton;

  /// No description provided for @emailHint.
  ///
  /// In en, this message translates to:
  /// **'Enter your email'**
  String get emailHint;

  /// No description provided for @emailValidationErrorRequired.
  ///
  /// In en, this message translates to:
  /// **'Please enter your email'**
  String get emailValidationErrorRequired;

  /// No description provided for @emailValidationErrorInvalid.
  ///
  /// In en, this message translates to:
  /// **'Please enter a valid email'**
  String get emailValidationErrorInvalid;

  /// No description provided for @passwordLabel.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get passwordLabel;

  /// No description provided for @passwordHint.
  ///
  /// In en, this message translates to:
  /// **'Enter your password'**
  String get passwordHint;

  /// No description provided for @passwordValidationErrorRequired.
  ///
  /// In en, this message translates to:
  /// **'Please enter your password'**
  String get passwordValidationErrorRequired;

  /// No description provided for @authFailureMessage.
  ///
  /// In en, this message translates to:
  /// **'Authentication failed: {message}'**
  String authFailureMessage(Object message);

  /// No description provided for @loginToYourAccount.
  ///
  /// In en, this message translates to:
  /// **'Login to your account'**
  String get loginToYourAccount;

  /// No description provided for @rememberMeLabel.
  ///
  /// In en, this message translates to:
  /// **'Remember me'**
  String get rememberMeLabel;

  /// No description provided for @forgotPasswordButton.
  ///
  /// In en, this message translates to:
  /// **'Forgot password?'**
  String get forgotPasswordButton;

  /// No description provided for @noAccountPrompt.
  ///
  /// In en, this message translates to:
  /// **'Don\'t have an account?'**
  String get noAccountPrompt;

  /// No description provided for @createAccountButton.
  ///
  /// In en, this message translates to:
  /// **'Create account'**
  String get createAccountButton;

  /// No description provided for @demoModeButton.
  ///
  /// In en, this message translates to:
  /// **'Demo Mode'**
  String get demoModeButton;

  /// No description provided for @settings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settings;

  /// No description provided for @settingsTitle.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settingsTitle;

  /// No description provided for @settingsDescription.
  ///
  /// In en, this message translates to:
  /// **'Manage your application settings.'**
  String get settingsDescription;

  /// No description provided for @wanzoFallbackText.
  ///
  /// In en, this message translates to:
  /// **'Wanzo Fallback'**
  String get wanzoFallbackText;

  /// No description provided for @appVersion.
  ///
  /// In en, this message translates to:
  /// **'App Version'**
  String get appVersion;

  /// No description provided for @loadingSettings.
  ///
  /// In en, this message translates to:
  /// **'Loading settings...'**
  String get loadingSettings;

  /// No description provided for @companyInformation.
  ///
  /// In en, this message translates to:
  /// **'Company Information'**
  String get companyInformation;

  /// No description provided for @companyInformationSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Manage your company details'**
  String get companyInformationSubtitle;

  /// No description provided for @appearanceAndDisplay.
  ///
  /// In en, this message translates to:
  /// **'Appearance and Display'**
  String get appearanceAndDisplay;

  /// No description provided for @appearanceAndDisplaySubtitle.
  ///
  /// In en, this message translates to:
  /// **'Customize the look and feel'**
  String get appearanceAndDisplaySubtitle;

  /// No description provided for @theme.
  ///
  /// In en, this message translates to:
  /// **'Theme'**
  String get theme;

  /// No description provided for @themeLight.
  ///
  /// In en, this message translates to:
  /// **'Light'**
  String get themeLight;

  /// No description provided for @themeDark.
  ///
  /// In en, this message translates to:
  /// **'Dark'**
  String get themeDark;

  /// No description provided for @themeSystem.
  ///
  /// In en, this message translates to:
  /// **'System'**
  String get themeSystem;

  /// No description provided for @language.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get language;

  /// No description provided for @languageEnglish.
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get languageEnglish;

  /// No description provided for @languageFrench.
  ///
  /// In en, this message translates to:
  /// **'French'**
  String get languageFrench;

  /// No description provided for @languageSwahili.
  ///
  /// In en, this message translates to:
  /// **'Swahili'**
  String get languageSwahili;

  /// No description provided for @dateFormat.
  ///
  /// In en, this message translates to:
  /// **'Date Format'**
  String get dateFormat;

  /// No description provided for @dateFormatDDMMYYYY.
  ///
  /// In en, this message translates to:
  /// **'DD/MM/YYYY'**
  String get dateFormatDDMMYYYY;

  /// No description provided for @dateFormatMMDDYYYY.
  ///
  /// In en, this message translates to:
  /// **'MM/DD/YYYY'**
  String get dateFormatMMDDYYYY;

  /// No description provided for @dateFormatYYYYMMDD.
  ///
  /// In en, this message translates to:
  /// **'YYYY/MM/DD'**
  String get dateFormatYYYYMMDD;

  /// No description provided for @dateFormatDDMMMYYYY.
  ///
  /// In en, this message translates to:
  /// **'DD MMM YYYY'**
  String get dateFormatDDMMMYYYY;

  /// No description provided for @monthJan.
  ///
  /// In en, this message translates to:
  /// **'January'**
  String get monthJan;

  /// No description provided for @monthFeb.
  ///
  /// In en, this message translates to:
  /// **'February'**
  String get monthFeb;

  /// No description provided for @monthMar.
  ///
  /// In en, this message translates to:
  /// **'March'**
  String get monthMar;

  /// No description provided for @monthApr.
  ///
  /// In en, this message translates to:
  /// **'April'**
  String get monthApr;

  /// No description provided for @monthMay.
  ///
  /// In en, this message translates to:
  /// **'May'**
  String get monthMay;

  /// No description provided for @monthJun.
  ///
  /// In en, this message translates to:
  /// **'June'**
  String get monthJun;

  /// No description provided for @monthJul.
  ///
  /// In en, this message translates to:
  /// **'July'**
  String get monthJul;

  /// No description provided for @monthAug.
  ///
  /// In en, this message translates to:
  /// **'August'**
  String get monthAug;

  /// No description provided for @monthSep.
  ///
  /// In en, this message translates to:
  /// **'September'**
  String get monthSep;

  /// No description provided for @monthOct.
  ///
  /// In en, this message translates to:
  /// **'October'**
  String get monthOct;

  /// No description provided for @monthNov.
  ///
  /// In en, this message translates to:
  /// **'November'**
  String get monthNov;

  /// No description provided for @monthDec.
  ///
  /// In en, this message translates to:
  /// **'December'**
  String get monthDec;

  /// No description provided for @changeLogo.
  ///
  /// In en, this message translates to:
  /// **'Change Logo'**
  String get changeLogo;

  /// No description provided for @companyName.
  ///
  /// In en, this message translates to:
  /// **'Company Name'**
  String get companyName;

  /// No description provided for @companyNameRequired.
  ///
  /// In en, this message translates to:
  /// **'Company name is required'**
  String get companyNameRequired;

  /// No description provided for @email.
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get email;

  /// No description provided for @invalidEmail.
  ///
  /// In en, this message translates to:
  /// **'Invalid email address'**
  String get invalidEmail;

  /// No description provided for @phoneNumber.
  ///
  /// In en, this message translates to:
  /// **'Phone Number'**
  String get phoneNumber;

  /// No description provided for @address.
  ///
  /// In en, this message translates to:
  /// **'Address'**
  String get address;

  /// No description provided for @rccm.
  ///
  /// In en, this message translates to:
  /// **'RCCM'**
  String get rccm;

  /// No description provided for @rccmHelperText.
  ///
  /// In en, this message translates to:
  /// **'Trade and Personal Property Credit Register'**
  String get rccmHelperText;

  /// No description provided for @taxId.
  ///
  /// In en, this message translates to:
  /// **'Tax ID'**
  String get taxId;

  /// No description provided for @taxIdHelperText.
  ///
  /// In en, this message translates to:
  /// **'National Tax Identification Number'**
  String get taxIdHelperText;

  /// No description provided for @website.
  ///
  /// In en, this message translates to:
  /// **'Website'**
  String get website;

  /// No description provided for @invoiceSettings.
  ///
  /// In en, this message translates to:
  /// **'Invoice Settings'**
  String get invoiceSettings;

  /// No description provided for @invoiceSettingsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Manage your invoice preferences'**
  String get invoiceSettingsSubtitle;

  /// No description provided for @defaultInvoiceFooter.
  ///
  /// In en, this message translates to:
  /// **'Default Invoice Footer'**
  String get defaultInvoiceFooter;

  /// No description provided for @defaultInvoiceFooterHint.
  ///
  /// In en, this message translates to:
  /// **'e.g., Thank you for your business!'**
  String get defaultInvoiceFooterHint;

  /// No description provided for @showTotalInWords.
  ///
  /// In en, this message translates to:
  /// **'Show Total in Words'**
  String get showTotalInWords;

  /// No description provided for @exchangeRate.
  ///
  /// In en, this message translates to:
  /// **'Exchange Rate (USD to Local)'**
  String get exchangeRate;

  /// No description provided for @inventorySettings.
  ///
  /// In en, this message translates to:
  /// **'Inventory Settings'**
  String get inventorySettings;

  /// No description provided for @inventorySettingsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Manage your inventory preferences'**
  String get inventorySettingsSubtitle;

  /// No description provided for @generalSettings.
  ///
  /// In en, this message translates to:
  /// **'General Settings'**
  String get generalSettings;

  /// No description provided for @defaultCategory.
  ///
  /// In en, this message translates to:
  /// **'Default Category'**
  String get defaultCategory;

  /// No description provided for @defaultCategoryRequired.
  ///
  /// In en, this message translates to:
  /// **'Default category is required'**
  String get defaultCategoryRequired;

  /// No description provided for @lowStockAlert.
  ///
  /// In en, this message translates to:
  /// **'Low Stock Alert'**
  String get lowStockAlert;

  /// No description provided for @lowStockAlertHint.
  ///
  /// In en, this message translates to:
  /// **'Quantity at which to trigger alert'**
  String get lowStockAlertHint;

  /// No description provided for @trackInventory.
  ///
  /// In en, this message translates to:
  /// **'Track Inventory'**
  String get trackInventory;

  /// No description provided for @allowNegativeStock.
  ///
  /// In en, this message translates to:
  /// **'Allow Negative Stock'**
  String get allowNegativeStock;

  /// No description provided for @saveChanges.
  ///
  /// In en, this message translates to:
  /// **'Save Changes'**
  String get saveChanges;

  /// Success message when settings are updated
  ///
  /// In en, this message translates to:
  /// **'Settings updated successfully'**
  String get settingsUpdatedSuccessfully;

  /// Error message when settings update fails
  ///
  /// In en, this message translates to:
  /// **'Error updating settings'**
  String get errorUpdatingSettings;

  /// No description provided for @changesSaved.
  ///
  /// In en, this message translates to:
  /// **'Changes saved successfully!'**
  String get changesSaved;

  /// No description provided for @errorSavingChanges.
  ///
  /// In en, this message translates to:
  /// **'Error saving changes'**
  String get errorSavingChanges;

  /// No description provided for @selectTheme.
  ///
  /// In en, this message translates to:
  /// **'Select Theme'**
  String get selectTheme;

  /// No description provided for @selectLanguage.
  ///
  /// In en, this message translates to:
  /// **'Select Language'**
  String get selectLanguage;

  /// No description provided for @selectDateFormat.
  ///
  /// In en, this message translates to:
  /// **'Select Date Format'**
  String get selectDateFormat;

  /// No description provided for @displaySettings.
  ///
  /// In en, this message translates to:
  /// **'Display Settings'**
  String get displaySettings;

  /// No description provided for @displaySettingsDescription.
  ///
  /// In en, this message translates to:
  /// **'Manage display settings.'**
  String get displaySettingsDescription;

  /// No description provided for @companySettings.
  ///
  /// In en, this message translates to:
  /// **'Company Settings'**
  String get companySettings;

  /// No description provided for @companySettingsDescription.
  ///
  /// In en, this message translates to:
  /// **'Manage company settings.'**
  String get companySettingsDescription;

  /// No description provided for @invoiceSettingsDescription.
  ///
  /// In en, this message translates to:
  /// **'Manage invoice settings.'**
  String get invoiceSettingsDescription;

  /// No description provided for @inventorySettingsDescription.
  ///
  /// In en, this message translates to:
  /// **'Manage inventory settings.'**
  String get inventorySettingsDescription;

  /// No description provided for @minValue.
  ///
  /// In en, this message translates to:
  /// **'Min value: {minValue}'**
  String minValue(double minValue);

  /// No description provided for @maxValue.
  ///
  /// In en, this message translates to:
  /// **'Max value: {maxValue}'**
  String maxValue(double maxValue);

  /// No description provided for @valueMustBeNumber.
  ///
  /// In en, this message translates to:
  /// **'Value must be a number'**
  String get valueMustBeNumber;

  /// No description provided for @valueMustBePositive.
  ///
  /// In en, this message translates to:
  /// **'Value must be positive'**
  String get valueMustBePositive;

  /// No description provided for @fieldRequired.
  ///
  /// In en, this message translates to:
  /// **'This field is required'**
  String get fieldRequired;

  /// No description provided for @settingsGeneral.
  ///
  /// In en, this message translates to:
  /// **'General'**
  String get settingsGeneral;

  /// No description provided for @settingsCompany.
  ///
  /// In en, this message translates to:
  /// **'Company'**
  String get settingsCompany;

  /// No description provided for @settingsInvoice.
  ///
  /// In en, this message translates to:
  /// **'Invoice'**
  String get settingsInvoice;

  /// No description provided for @settingsInventory.
  ///
  /// In en, this message translates to:
  /// **'Inventory'**
  String get settingsInventory;

  /// No description provided for @settingsAppearance.
  ///
  /// In en, this message translates to:
  /// **'Appearance'**
  String get settingsAppearance;

  /// No description provided for @searchSettings.
  ///
  /// In en, this message translates to:
  /// **'Search settings...'**
  String get searchSettings;

  /// No description provided for @backupAndReports.
  ///
  /// In en, this message translates to:
  /// **'Backup and Reports'**
  String get backupAndReports;

  /// No description provided for @backupAndReportsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Manage data backup and generate reports'**
  String get backupAndReportsSubtitle;

  /// No description provided for @notifications.
  ///
  /// In en, this message translates to:
  /// **'Notifications'**
  String get notifications;

  /// No description provided for @notificationsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Manage app notifications'**
  String get notificationsSubtitle;

  /// No description provided for @resetSettings.
  ///
  /// In en, this message translates to:
  /// **'Reset Settings'**
  String get resetSettings;

  /// No description provided for @confirmResetSettings.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to reset all settings to their default values? This action cannot be undone.'**
  String get confirmResetSettings;

  /// No description provided for @reset.
  ///
  /// In en, this message translates to:
  /// **'Reset'**
  String get reset;

  /// No description provided for @taxIdentificationNumber.
  ///
  /// In en, this message translates to:
  /// **'Tax Identification Number'**
  String get taxIdentificationNumber;

  /// No description provided for @rccmNumber.
  ///
  /// In en, this message translates to:
  /// **'RCCM Number'**
  String get rccmNumber;

  /// No description provided for @idNatNumber.
  ///
  /// In en, this message translates to:
  /// **'National ID Number'**
  String get idNatNumber;

  /// No description provided for @idNatHelperText.
  ///
  /// In en, this message translates to:
  /// **'National Identification Number'**
  String get idNatHelperText;

  /// No description provided for @selectImageSource.
  ///
  /// In en, this message translates to:
  /// **'Select Image Source'**
  String get selectImageSource;

  /// No description provided for @gallery.
  ///
  /// In en, this message translates to:
  /// **'Gallery'**
  String get gallery;

  /// No description provided for @camera.
  ///
  /// In en, this message translates to:
  /// **'Camera'**
  String get camera;

  /// No description provided for @deleteCurrentLogo.
  ///
  /// In en, this message translates to:
  /// **'Delete Current Logo'**
  String get deleteCurrentLogo;

  /// No description provided for @logoDeleted.
  ///
  /// In en, this message translates to:
  /// **'Logo deleted.'**
  String get logoDeleted;

  /// No description provided for @logoUpdatedSuccessfully.
  ///
  /// In en, this message translates to:
  /// **'Logo updated successfully.'**
  String get logoUpdatedSuccessfully;

  /// No description provided for @errorSelectingLogo.
  ///
  /// In en, this message translates to:
  /// **'Error selecting logo: {errorDetails}'**
  String errorSelectingLogo(String errorDetails);

  /// No description provided for @defaultProductCategory.
  ///
  /// In en, this message translates to:
  /// **'Default Product Category'**
  String get defaultProductCategory;

  /// No description provided for @stockAlerts.
  ///
  /// In en, this message translates to:
  /// **'Stock Alerts'**
  String get stockAlerts;

  /// No description provided for @lowStockAlertDays.
  ///
  /// In en, this message translates to:
  /// **'Low Stock Alert Days'**
  String get lowStockAlertDays;

  /// No description provided for @days.
  ///
  /// In en, this message translates to:
  /// **'Days'**
  String get days;

  /// No description provided for @enterValidNumber.
  ///
  /// In en, this message translates to:
  /// **'Please enter a valid number.'**
  String get enterValidNumber;

  /// No description provided for @lowStockAlertDescription.
  ///
  /// In en, this message translates to:
  /// **'Receive alerts when product stock is low for a specified number of days.'**
  String get lowStockAlertDescription;

  /// No description provided for @productCategories.
  ///
  /// In en, this message translates to:
  /// **'Product Categories'**
  String get productCategories;

  /// No description provided for @manageYourProductCategories.
  ///
  /// In en, this message translates to:
  /// **'Manage your product categories.'**
  String get manageYourProductCategories;

  /// No description provided for @addCategory.
  ///
  /// In en, this message translates to:
  /// **'Add Category'**
  String get addCategory;

  /// No description provided for @editCategory.
  ///
  /// In en, this message translates to:
  /// **'Edit Category'**
  String get editCategory;

  /// No description provided for @deleteCategory.
  ///
  /// In en, this message translates to:
  /// **'Delete Category'**
  String get deleteCategory;

  /// No description provided for @categoryName.
  ///
  /// In en, this message translates to:
  /// **'Category Name'**
  String get categoryName;

  /// No description provided for @categoryNameCannotBeEmpty.
  ///
  /// In en, this message translates to:
  /// **'Category name cannot be empty.'**
  String get categoryNameCannotBeEmpty;

  /// No description provided for @categoryAdded.
  ///
  /// In en, this message translates to:
  /// **'Category added'**
  String get categoryAdded;

  /// No description provided for @categoryUpdated.
  ///
  /// In en, this message translates to:
  /// **'Category updated'**
  String get categoryUpdated;

  /// No description provided for @categoryDeleted.
  ///
  /// In en, this message translates to:
  /// **'Category deleted'**
  String get categoryDeleted;

  /// No description provided for @confirmDeleteCategory.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to delete this category?'**
  String get confirmDeleteCategory;

  /// No description provided for @deleteCategoryMessage.
  ///
  /// In en, this message translates to:
  /// **'This action cannot be undone.'**
  String get deleteCategoryMessage;

  /// No description provided for @errorAddingCategory.
  ///
  /// In en, this message translates to:
  /// **'Error adding category: {error}'**
  String errorAddingCategory(Object error);

  /// No description provided for @errorUpdatingCategory.
  ///
  /// In en, this message translates to:
  /// **'Error updating category: {error}'**
  String errorUpdatingCategory(Object error);

  /// No description provided for @errorDeletingCategory.
  ///
  /// In en, this message translates to:
  /// **'Error deleting category: {error}'**
  String errorDeletingCategory(Object error);

  /// No description provided for @errorFetchingCategories.
  ///
  /// In en, this message translates to:
  /// **'Error fetching categories: {error}'**
  String errorFetchingCategories(Object error);

  /// No description provided for @noCategoriesFound.
  ///
  /// In en, this message translates to:
  /// **'No categories found. Add one to get started!'**
  String get noCategoriesFound;

  /// No description provided for @signupScreenTitle.
  ///
  /// In en, this message translates to:
  /// **'Create Business Account'**
  String get signupScreenTitle;

  /// No description provided for @signupStepIdentity.
  ///
  /// In en, this message translates to:
  /// **'Identity'**
  String get signupStepIdentity;

  /// No description provided for @signupStepCompany.
  ///
  /// In en, this message translates to:
  /// **'Company'**
  String get signupStepCompany;

  /// No description provided for @signupStepConfirmation.
  ///
  /// In en, this message translates to:
  /// **'Confirmation'**
  String get signupStepConfirmation;

  /// No description provided for @signupPersonalInfoTitle.
  ///
  /// In en, this message translates to:
  /// **'Your Personal Information'**
  String get signupPersonalInfoTitle;

  /// No description provided for @signupOwnerNameLabel.
  ///
  /// In en, this message translates to:
  /// **'Full Name of Owner'**
  String get signupOwnerNameLabel;

  /// No description provided for @signupOwnerNameHint.
  ///
  /// In en, this message translates to:
  /// **'Enter your full name'**
  String get signupOwnerNameHint;

  /// No description provided for @signupOwnerNameValidation.
  ///
  /// In en, this message translates to:
  /// **'Please enter the owner\'s name'**
  String get signupOwnerNameValidation;

  /// No description provided for @signupEmailLabel.
  ///
  /// In en, this message translates to:
  /// **'Email Address'**
  String get signupEmailLabel;

  /// No description provided for @signupEmailHint.
  ///
  /// In en, this message translates to:
  /// **'Enter your email address'**
  String get signupEmailHint;

  /// No description provided for @signupEmailValidationRequired.
  ///
  /// In en, this message translates to:
  /// **'Please enter your email'**
  String get signupEmailValidationRequired;

  /// No description provided for @signupEmailValidationInvalid.
  ///
  /// In en, this message translates to:
  /// **'Please enter a valid email'**
  String get signupEmailValidationInvalid;

  /// No description provided for @signupPhoneLabel.
  ///
  /// In en, this message translates to:
  /// **'Phone Number'**
  String get signupPhoneLabel;

  /// No description provided for @signupPhoneHint.
  ///
  /// In en, this message translates to:
  /// **'Enter your phone number'**
  String get signupPhoneHint;

  /// No description provided for @signupPhoneValidation.
  ///
  /// In en, this message translates to:
  /// **'Please enter your phone number'**
  String get signupPhoneValidation;

  /// No description provided for @signupPasswordLabel.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get signupPasswordLabel;

  /// No description provided for @signupPasswordHint.
  ///
  /// In en, this message translates to:
  /// **'Enter your password (min. 8 characters)'**
  String get signupPasswordHint;

  /// No description provided for @signupPasswordValidationRequired.
  ///
  /// In en, this message translates to:
  /// **'Please enter a password'**
  String get signupPasswordValidationRequired;

  /// No description provided for @signupPasswordValidationLength.
  ///
  /// In en, this message translates to:
  /// **'Password must be at least 8 characters'**
  String get signupPasswordValidationLength;

  /// No description provided for @signupConfirmPasswordLabel.
  ///
  /// In en, this message translates to:
  /// **'Confirm Password'**
  String get signupConfirmPasswordLabel;

  /// No description provided for @signupConfirmPasswordHint.
  ///
  /// In en, this message translates to:
  /// **'Confirm your password'**
  String get signupConfirmPasswordHint;

  /// No description provided for @signupConfirmPasswordValidationRequired.
  ///
  /// In en, this message translates to:
  /// **'Please confirm your password'**
  String get signupConfirmPasswordValidationRequired;

  /// No description provided for @signupConfirmPasswordValidationMatch.
  ///
  /// In en, this message translates to:
  /// **'Passwords do not match'**
  String get signupConfirmPasswordValidationMatch;

  /// No description provided for @signupRequiredFields.
  ///
  /// In en, this message translates to:
  /// **'* Required fields'**
  String get signupRequiredFields;

  /// No description provided for @signupCompanyInfoTitle.
  ///
  /// In en, this message translates to:
  /// **'Your Company Information'**
  String get signupCompanyInfoTitle;

  /// No description provided for @signupCompanyNameLabel.
  ///
  /// In en, this message translates to:
  /// **'Company Name'**
  String get signupCompanyNameLabel;

  /// No description provided for @signupCompanyNameHint.
  ///
  /// In en, this message translates to:
  /// **'Enter your company name'**
  String get signupCompanyNameHint;

  /// No description provided for @signupCompanyNameValidation.
  ///
  /// In en, this message translates to:
  /// **'Please enter the company name'**
  String get signupCompanyNameValidation;

  /// No description provided for @signupRccmLabel.
  ///
  /// In en, this message translates to:
  /// **'RCCM Number / Business Registration'**
  String get signupRccmLabel;

  /// No description provided for @signupRccmHint.
  ///
  /// In en, this message translates to:
  /// **'Enter your RCCM number or equivalent'**
  String get signupRccmHint;

  /// No description provided for @signupRccmValidation.
  ///
  /// In en, this message translates to:
  /// **'Please enter the RCCM number'**
  String get signupRccmValidation;

  /// No description provided for @signupAddressLabel.
  ///
  /// In en, this message translates to:
  /// **'Address / Location'**
  String get signupAddressLabel;

  /// No description provided for @signupAddressHint.
  ///
  /// In en, this message translates to:
  /// **'Enter your company address'**
  String get signupAddressHint;

  /// No description provided for @signupAddressValidation.
  ///
  /// In en, this message translates to:
  /// **'Please enter your company address'**
  String get signupAddressValidation;

  /// No description provided for @signupActivitySectorLabel.
  ///
  /// In en, this message translates to:
  /// **'Business Sector'**
  String get signupActivitySectorLabel;

  /// No description provided for @signupTermsAndConditionsTitle.
  ///
  /// In en, this message translates to:
  /// **'Summary and Terms'**
  String get signupTermsAndConditionsTitle;

  /// No description provided for @signupInfoSummaryPersonal.
  ///
  /// In en, this message translates to:
  /// **'Personal Information:'**
  String get signupInfoSummaryPersonal;

  /// No description provided for @signupInfoSummaryName.
  ///
  /// In en, this message translates to:
  /// **'Name:'**
  String get signupInfoSummaryName;

  /// No description provided for @signupInfoSummaryEmail.
  ///
  /// In en, this message translates to:
  /// **'Email:'**
  String get signupInfoSummaryEmail;

  /// No description provided for @signupInfoSummaryPhone.
  ///
  /// In en, this message translates to:
  /// **'Phone:'**
  String get signupInfoSummaryPhone;

  /// No description provided for @signupInfoSummaryCompany.
  ///
  /// In en, this message translates to:
  /// **'Company Information:'**
  String get signupInfoSummaryCompany;

  /// No description provided for @signupInfoSummaryCompanyName.
  ///
  /// In en, this message translates to:
  /// **'Company Name:'**
  String get signupInfoSummaryCompanyName;

  /// No description provided for @signupInfoSummaryRccm.
  ///
  /// In en, this message translates to:
  /// **'RCCM:'**
  String get signupInfoSummaryRccm;

  /// No description provided for @signupInfoSummaryAddress.
  ///
  /// In en, this message translates to:
  /// **'Address:'**
  String get signupInfoSummaryAddress;

  /// No description provided for @signupInfoSummaryActivitySector.
  ///
  /// In en, this message translates to:
  /// **'Activity Sector:'**
  String get signupInfoSummaryActivitySector;

  /// No description provided for @signupAgreeToTerms.
  ///
  /// In en, this message translates to:
  /// **'I have read and agree to the'**
  String get signupAgreeToTerms;

  /// No description provided for @signupTermsOfUse.
  ///
  /// In en, this message translates to:
  /// **'Terms of Use'**
  String get signupTermsOfUse;

  /// No description provided for @andConnector.
  ///
  /// In en, this message translates to:
  /// **'and'**
  String get andConnector;

  /// No description provided for @signupPrivacyPolicy.
  ///
  /// In en, this message translates to:
  /// **'Privacy Policy'**
  String get signupPrivacyPolicy;

  /// No description provided for @signupAgreeToTermsConfirmation.
  ///
  /// In en, this message translates to:
  /// **'By checking this box, you confirm that you have read, understood, and accepted our terms of service and privacy policy.'**
  String get signupAgreeToTermsConfirmation;

  /// No description provided for @signupButtonPrevious.
  ///
  /// In en, this message translates to:
  /// **'Previous'**
  String get signupButtonPrevious;

  /// No description provided for @signupButtonNext.
  ///
  /// In en, this message translates to:
  /// **'Next'**
  String get signupButtonNext;

  /// No description provided for @signupButtonRegister.
  ///
  /// In en, this message translates to:
  /// **'Register'**
  String get signupButtonRegister;

  /// No description provided for @signupAlreadyHaveAccount.
  ///
  /// In en, this message translates to:
  /// **'Already have an account? Log in'**
  String get signupAlreadyHaveAccount;

  /// No description provided for @signupErrorFillFields.
  ///
  /// In en, this message translates to:
  /// **'Please fill in all required fields correctly for the current step.'**
  String get signupErrorFillFields;

  /// No description provided for @signupErrorAgreeToTerms.
  ///
  /// In en, this message translates to:
  /// **'You must agree to the terms and conditions to register.'**
  String get signupErrorAgreeToTerms;

  /// No description provided for @signupSuccessMessage.
  ///
  /// In en, this message translates to:
  /// **'Registration successful! Logging you in...'**
  String get signupSuccessMessage;

  /// Error message when registration fails
  ///
  /// In en, this message translates to:
  /// **'Registration failed: {error}'**
  String signupErrorRegistration(String error);

  /// No description provided for @sectorAgricultureName.
  ///
  /// In en, this message translates to:
  /// **'Agriculture and Agri-food'**
  String get sectorAgricultureName;

  /// No description provided for @sectorAgricultureDescription.
  ///
  /// In en, this message translates to:
  /// **'Agricultural production, food processing, livestock'**
  String get sectorAgricultureDescription;

  /// No description provided for @sectorCommerceName.
  ///
  /// In en, this message translates to:
  /// **'Trade and Distribution'**
  String get sectorCommerceName;

  /// No description provided for @sectorCommerceDescription.
  ///
  /// In en, this message translates to:
  /// **'Retail, distribution, import-export'**
  String get sectorCommerceDescription;

  /// No description provided for @sectorServicesName.
  ///
  /// In en, this message translates to:
  /// **'Services'**
  String get sectorServicesName;

  /// No description provided for @sectorServicesDescription.
  ///
  /// In en, this message translates to:
  /// **'Business and personal services'**
  String get sectorServicesDescription;

  /// No description provided for @sectorTechnologyName.
  ///
  /// In en, this message translates to:
  /// **'Technology and Innovation'**
  String get sectorTechnologyName;

  /// No description provided for @sectorTechnologyDescription.
  ///
  /// In en, this message translates to:
  /// **'Software development, telecommunications, fintech'**
  String get sectorTechnologyDescription;

  /// No description provided for @sectorManufacturingName.
  ///
  /// In en, this message translates to:
  /// **'Manufacturing and Industry'**
  String get sectorManufacturingName;

  /// No description provided for @sectorManufacturingDescription.
  ///
  /// In en, this message translates to:
  /// **'Industrial production, crafts, textiles'**
  String get sectorManufacturingDescription;

  /// No description provided for @sectorConstructionName.
  ///
  /// In en, this message translates to:
  /// **'Construction and Real Estate'**
  String get sectorConstructionName;

  /// No description provided for @sectorConstructionDescription.
  ///
  /// In en, this message translates to:
  /// **'Construction, real estate development, architecture'**
  String get sectorConstructionDescription;

  /// No description provided for @sectorTransportationName.
  ///
  /// In en, this message translates to:
  /// **'Transport and Logistics'**
  String get sectorTransportationName;

  /// No description provided for @sectorTransportationDescription.
  ///
  /// In en, this message translates to:
  /// **'Freight transport, logistics, warehousing'**
  String get sectorTransportationDescription;

  /// No description provided for @sectorEnergyName.
  ///
  /// In en, this message translates to:
  /// **'Energy and Natural Resources'**
  String get sectorEnergyName;

  /// No description provided for @sectorEnergyDescription.
  ///
  /// In en, this message translates to:
  /// **'Energy production, mining, water'**
  String get sectorEnergyDescription;

  /// No description provided for @sectorTourismName.
  ///
  /// In en, this message translates to:
  /// **'Tourism and Hospitality'**
  String get sectorTourismName;

  /// No description provided for @sectorTourismDescription.
  ///
  /// In en, this message translates to:
  /// **'Hotels, restaurants, tourism'**
  String get sectorTourismDescription;

  /// No description provided for @sectorEducationName.
  ///
  /// In en, this message translates to:
  /// **'Education and Training'**
  String get sectorEducationName;

  /// No description provided for @sectorEducationDescription.
  ///
  /// In en, this message translates to:
  /// **'Teaching, vocational training'**
  String get sectorEducationDescription;

  /// No description provided for @sectorHealthName.
  ///
  /// In en, this message translates to:
  /// **'Health and Medical Services'**
  String get sectorHealthName;

  /// No description provided for @sectorHealthDescription.
  ///
  /// In en, this message translates to:
  /// **'Medical care, pharmacy, medical equipment'**
  String get sectorHealthDescription;

  /// No description provided for @sectorFinanceName.
  ///
  /// In en, this message translates to:
  /// **'Financial Services'**
  String get sectorFinanceName;

  /// No description provided for @sectorFinanceDescription.
  ///
  /// In en, this message translates to:
  /// **'Banking, insurance, microfinance'**
  String get sectorFinanceDescription;

  /// No description provided for @sectorOtherName.
  ///
  /// In en, this message translates to:
  /// **'Other'**
  String get sectorOtherName;

  /// No description provided for @sectorOtherDescription.
  ///
  /// In en, this message translates to:
  /// **'Other business sectors'**
  String get sectorOtherDescription;

  /// No description provided for @financeSettings.
  ///
  /// In en, this message translates to:
  /// **'Finance'**
  String get financeSettings;

  /// No description provided for @financeSettingsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Configure your bank accounts and Mobile Money'**
  String get financeSettingsSubtitle;

  /// No description provided for @businessUnitTypeCompany.
  ///
  /// In en, this message translates to:
  /// **'Company'**
  String get businessUnitTypeCompany;

  /// No description provided for @businessUnitTypeBranch.
  ///
  /// In en, this message translates to:
  /// **'Branch'**
  String get businessUnitTypeBranch;

  /// No description provided for @businessUnitTypePOS.
  ///
  /// In en, this message translates to:
  /// **'Point of Sale'**
  String get businessUnitTypePOS;

  /// No description provided for @businessUnitTypeCompanyDesc.
  ///
  /// In en, this message translates to:
  /// **'Headquarters - Main establishment'**
  String get businessUnitTypeCompanyDesc;

  /// No description provided for @businessUnitTypeBranchDesc.
  ///
  /// In en, this message translates to:
  /// **'Regional branch or agency'**
  String get businessUnitTypeBranchDesc;

  /// No description provided for @businessUnitTypePOSDesc.
  ///
  /// In en, this message translates to:
  /// **'Point of sale, shop or warehouse'**
  String get businessUnitTypePOSDesc;

  /// No description provided for @businessUnitStatusActive.
  ///
  /// In en, this message translates to:
  /// **'Active'**
  String get businessUnitStatusActive;

  /// No description provided for @businessUnitStatusInactive.
  ///
  /// In en, this message translates to:
  /// **'Inactive'**
  String get businessUnitStatusInactive;

  /// No description provided for @businessUnitStatusSuspended.
  ///
  /// In en, this message translates to:
  /// **'Suspended'**
  String get businessUnitStatusSuspended;

  /// No description provided for @businessUnitStatusClosed.
  ///
  /// In en, this message translates to:
  /// **'Closed'**
  String get businessUnitStatusClosed;

  /// No description provided for @businessUnitConfiguration.
  ///
  /// In en, this message translates to:
  /// **'Business Unit'**
  String get businessUnitConfiguration;

  /// No description provided for @businessUnitConfigurationDescription.
  ///
  /// In en, this message translates to:
  /// **'Configure the unit to isolate data by establishment'**
  String get businessUnitConfigurationDescription;

  /// No description provided for @businessUnitDefaultCompany.
  ///
  /// In en, this message translates to:
  /// **'Company Level'**
  String get businessUnitDefaultCompany;

  /// No description provided for @businessUnitDefaultDescription.
  ///
  /// In en, this message translates to:
  /// **'Global company data'**
  String get businessUnitDefaultDescription;

  /// No description provided for @businessUnitDefaultCompanyDescription.
  ///
  /// In en, this message translates to:
  /// **'You are operating at company level. All data is centralized.'**
  String get businessUnitDefaultCompanyDescription;

  /// No description provided for @businessUnitLevelDefault.
  ///
  /// In en, this message translates to:
  /// **'Default'**
  String get businessUnitLevelDefault;

  /// No description provided for @businessUnitConfigureByCode.
  ///
  /// In en, this message translates to:
  /// **'Configure a branch or POS'**
  String get businessUnitConfigureByCode;

  /// No description provided for @businessUnitConfigureByCodeDescription.
  ///
  /// In en, this message translates to:
  /// **'Enter the code received when creating the unit'**
  String get businessUnitConfigureByCodeDescription;

  /// No description provided for @businessUnitCodeLabel.
  ///
  /// In en, this message translates to:
  /// **'Unit code'**
  String get businessUnitCodeLabel;

  /// No description provided for @businessUnitCodeHint.
  ///
  /// In en, this message translates to:
  /// **'E.g: BRN-001, POS-KIN-001'**
  String get businessUnitCodeHint;

  /// No description provided for @businessUnitCodeHelper.
  ///
  /// In en, this message translates to:
  /// **'Unique code provided by administrator'**
  String get businessUnitCodeHelper;

  /// No description provided for @businessUnitCodeInfo.
  ///
  /// In en, this message translates to:
  /// **'Once the branch or point of sale is created from the back-office, you will receive a code to configure this device.'**
  String get businessUnitCodeInfo;

  /// No description provided for @businessUnitCode.
  ///
  /// In en, this message translates to:
  /// **'Code'**
  String get businessUnitCode;

  /// No description provided for @businessUnitType.
  ///
  /// In en, this message translates to:
  /// **'Type'**
  String get businessUnitType;

  /// No description provided for @businessUnitName.
  ///
  /// In en, this message translates to:
  /// **'Unit name'**
  String get businessUnitName;

  /// No description provided for @businessUnitConfigured.
  ///
  /// In en, this message translates to:
  /// **'Unit configured'**
  String get businessUnitConfigured;

  /// No description provided for @businessUnitChangeInfo.
  ///
  /// In en, this message translates to:
  /// **'To change unit, contact the administrator or reset the application.'**
  String get businessUnitChangeInfo;

  /// No description provided for @userRoleAdmin.
  ///
  /// In en, this message translates to:
  /// **'Administrator'**
  String get userRoleAdmin;

  /// No description provided for @userRoleSuperAdmin.
  ///
  /// In en, this message translates to:
  /// **'Super Administrator'**
  String get userRoleSuperAdmin;

  /// No description provided for @userRoleManager.
  ///
  /// In en, this message translates to:
  /// **'Manager'**
  String get userRoleManager;

  /// No description provided for @userRoleAccountant.
  ///
  /// In en, this message translates to:
  /// **'Accountant'**
  String get userRoleAccountant;

  /// No description provided for @userRoleCashier.
  ///
  /// In en, this message translates to:
  /// **'Cashier'**
  String get userRoleCashier;

  /// No description provided for @userRoleSales.
  ///
  /// In en, this message translates to:
  /// **'Sales'**
  String get userRoleSales;

  /// No description provided for @userRoleInventoryManager.
  ///
  /// In en, this message translates to:
  /// **'Inventory Manager'**
  String get userRoleInventoryManager;

  /// No description provided for @userRoleStaff.
  ///
  /// In en, this message translates to:
  /// **'Staff'**
  String get userRoleStaff;

  /// No description provided for @userRoleCustomerSupport.
  ///
  /// In en, this message translates to:
  /// **'Customer Support'**
  String get userRoleCustomerSupport;

  /// No description provided for @userRoleAdminDescription.
  ///
  /// In en, this message translates to:
  /// **'Business owner with full rights'**
  String get userRoleAdminDescription;

  /// No description provided for @userRoleSuperAdminDescription.
  ///
  /// In en, this message translates to:
  /// **'Maximum rights across the company and all services'**
  String get userRoleSuperAdminDescription;

  /// No description provided for @userRoleManagerDescription.
  ///
  /// In en, this message translates to:
  /// **'Manager with extended rights'**
  String get userRoleManagerDescription;

  /// No description provided for @userRoleAccountantDescription.
  ///
  /// In en, this message translates to:
  /// **'Access to accounting functions'**
  String get userRoleAccountantDescription;

  /// No description provided for @userRoleCashierDescription.
  ///
  /// In en, this message translates to:
  /// **'Access to cashier functions'**
  String get userRoleCashierDescription;

  /// No description provided for @userRoleSalesDescription.
  ///
  /// In en, this message translates to:
  /// **'Access to sales functions'**
  String get userRoleSalesDescription;

  /// No description provided for @userRoleInventoryManagerDescription.
  ///
  /// In en, this message translates to:
  /// **'Access to inventory management'**
  String get userRoleInventoryManagerDescription;

  /// No description provided for @userRoleStaffDescription.
  ///
  /// In en, this message translates to:
  /// **'Standard employee'**
  String get userRoleStaffDescription;

  /// No description provided for @userRoleCustomerSupportDescription.
  ///
  /// In en, this message translates to:
  /// **'Access to customer support'**
  String get userRoleCustomerSupportDescription;

  /// Label for Revenues menu (formerly Sales) in sidebar
  ///
  /// In en, this message translates to:
  /// **'Revenues'**
  String get sidebarRevenues;

  /// Label for Expenses menu (formerly Expenses) in sidebar
  ///
  /// In en, this message translates to:
  /// **'Expenses'**
  String get sidebarCharges;

  /// Chart title in accounting view
  ///
  /// In en, this message translates to:
  /// **'Business Activity'**
  String get chartTitleAccountingView;

  /// Chart title in cash flow view
  ///
  /// In en, this message translates to:
  /// **'Cash Flow'**
  String get chartTitleCashFlowView;

  /// Legend for revenues in accounting chart
  ///
  /// In en, this message translates to:
  /// **'Revenues (Turnover)'**
  String get chartLegendRevenues;

  /// Legend for expenses in accounting chart
  ///
  /// In en, this message translates to:
  /// **'Expenses'**
  String get chartLegendCharges;

  /// Legend for cash in in cash flow chart
  ///
  /// In en, this message translates to:
  /// **'Cash In'**
  String get chartLegendCashIn;

  /// Legend for cash out in cash flow chart
  ///
  /// In en, this message translates to:
  /// **'Cash Out'**
  String get chartLegendCashOut;

  /// KPI for turnover
  ///
  /// In en, this message translates to:
  /// **'Turnover'**
  String get kpiTurnover;

  /// KPI for cash in
  ///
  /// In en, this message translates to:
  /// **'Cash In'**
  String get kpiCashIn;

  /// KPI for cash out
  ///
  /// In en, this message translates to:
  /// **'Cash Out'**
  String get kpiCashOut;

  /// KPI for customer receivables
  ///
  /// In en, this message translates to:
  /// **'Receivables'**
  String get kpiReceivables;

  /// KPI for supplier payables
  ///
  /// In en, this message translates to:
  /// **'Payables'**
  String get kpiPayables;

  /// Filter for cash flow operations only
  ///
  /// In en, this message translates to:
  /// **'Cash Flow'**
  String get filterCashFlowOnly;

  /// Filter for accounting operations
  ///
  /// In en, this message translates to:
  /// **'Accounting'**
  String get filterAccountingOnly;

  /// Payment status: collected
  ///
  /// In en, this message translates to:
  /// **'Collected'**
  String get paymentStatusPaid;

  /// Payment status: partial
  ///
  /// In en, this message translates to:
  /// **'Partial'**
  String get paymentStatusPartial;

  /// Payment status: pending collection
  ///
  /// In en, this message translates to:
  /// **'To Collect'**
  String get paymentStatusPending;

  /// Expense payment status: disbursed
  ///
  /// In en, this message translates to:
  /// **'Disbursed'**
  String get expensePaymentStatusPaid;

  /// Expense payment status: partial
  ///
  /// In en, this message translates to:
  /// **'Partial'**
  String get expensePaymentStatusPartial;

  /// Expense payment status: pending disbursement
  ///
  /// In en, this message translates to:
  /// **'To Disburse'**
  String get expensePaymentStatusPending;

  /// Document type: invoice (commercial)
  ///
  /// In en, this message translates to:
  /// **'Invoice'**
  String get documentTypeInvoice;

  /// Document type: cash receipt (treasury)
  ///
  /// In en, this message translates to:
  /// **'Cash Receipt'**
  String get documentTypeReceipt;

  /// Document type: cash voucher
  ///
  /// In en, this message translates to:
  /// **'Cash Voucher'**
  String get documentTypeCashVoucher;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'fr', 'sw'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'fr':
      return AppLocalizationsFr();
    case 'sw':
      return AppLocalizationsSw();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
