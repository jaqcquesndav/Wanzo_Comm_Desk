// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get invoiceSettingsTitle => 'Invoice Settings';

  @override
  String get currencySettings => 'Currency Settings';

  @override
  String get activeCurrency => 'Active Currency';

  @override
  String exchangeRateSpecific(String currencyFrom, String currencyTo) {
    return 'Exchange Rate ($currencyFrom to $currencyTo)';
  }

  @override
  String exchangeRateHint(String currencyFrom, String currencyTo) {
    return 'e.g., 650 for 1 USD = 650 FCFA';
  }

  @override
  String get errorFieldRequired => 'This field is required.';

  @override
  String get errorInvalidRate => 'Please enter a valid positive rate.';

  @override
  String get invoiceFormatting => 'Invoice Formatting';

  @override
  String invoiceFormatHint(Object YEAR, Object MONTH, Object SEQ) {
    return 'Use $YEAR, $MONTH, $SEQ for dynamic values.';
  }

  @override
  String get invoiceNumberFormat => 'Invoice Number Format';

  @override
  String get invoicePrefix => 'Invoice Prefix';

  @override
  String get taxesAndConditions => 'Taxes & Conditions';

  @override
  String get showTaxesOnInvoices => 'Show taxes on invoices';

  @override
  String get defaultTaxRatePercentage => 'Default Tax Rate (%)';

  @override
  String get errorInvalidTaxRate => 'Tax rate must be between 0 and 100.';

  @override
  String get defaultPaymentTerms => 'Default Payment Terms';

  @override
  String get defaultInvoiceNotes => 'Default Invoice Notes';

  @override
  String get settingsSavedSuccess => 'Settings saved successfully.';

  @override
  String get anErrorOccurred => 'An error occurred';

  @override
  String get errorUnknown => 'Unknown error';

  @override
  String currencySettingsError(String errorDetails) {
    return 'Could not save currency settings: $errorDetails';
  }

  @override
  String get currencySettingsSavedSuccess =>
      'Currency settings saved successfully.';

  @override
  String get currencyCDF => 'Congolese Franc';

  @override
  String get currencyUSD => 'US Dollar';

  @override
  String get currencyFCFA => 'CFA Franc';

  @override
  String get editProductTitle => 'Edit Product';

  @override
  String get addProductTitle => 'Add Product';

  @override
  String get productCategoryFood => 'Food';

  @override
  String get productCategoryDrink => 'Drink';

  @override
  String get productCategoryOther => 'Other';

  @override
  String get units => 'Units';

  @override
  String get notes => 'Notes (Optional)';

  @override
  String get saveProduct => 'Save Product';

  @override
  String get inventoryValue => 'Inventory Value';

  @override
  String get products => 'Products';

  @override
  String get stockMovements => 'Stock Movements';

  @override
  String get noProducts => 'No products yet.';

  @override
  String get noStockMovements => 'No stock movements yet.';

  @override
  String get searchProducts => 'Search products...';

  @override
  String get totalStock => 'Total Stock';

  @override
  String get valueInCdf => 'Value (CDF)';

  @override
  String valueIn(String currencyCode) {
    return 'Value ($currencyCode)';
  }

  @override
  String get lastModified => 'Last Modified';

  @override
  String get productDetails => 'Product Details';

  @override
  String get deleteProduct => 'Delete Product';

  @override
  String get confirmDeleteProductTitle => 'Confirm Deletion';

  @override
  String get confirmDeleteProductMessage =>
      'Are you sure you want to delete this product? This action cannot be undone.';

  @override
  String get commonCancel => 'Cancel';

  @override
  String get delete => 'Delete';

  @override
  String get stockIn => 'Stock In';

  @override
  String get stockOut => 'Stock Out';

  @override
  String get adjustment => 'Adjustment';

  @override
  String get quantity => 'Quantity';

  @override
  String get reason => 'Reason (Optional)';

  @override
  String get addStockMovement => 'Add Stock Movement';

  @override
  String get newStock => 'New Stock';

  @override
  String get value => 'Value';

  @override
  String get type => 'Type';

  @override
  String get date => 'Date';

  @override
  String get product => 'Product';

  @override
  String get selectProduct => 'Select Product';

  @override
  String get selectCategory => 'Select Category';

  @override
  String get selectUnit => 'Select Unit';

  @override
  String imagePickingErrorMessage(String errorDetails) {
    return 'Error picking image: $errorDetails';
  }

  @override
  String get galleryAction => 'Gallery';

  @override
  String get cameraAction => 'Camera';

  @override
  String get removeImageAction => 'Remove Image';

  @override
  String get productImageSectionTitle => 'Product Image';

  @override
  String get addImageLabel => 'Add Image';

  @override
  String get generalInformationSectionTitle => 'General Information';

  @override
  String get productNameLabel => 'Product Name';

  @override
  String get productNameValidationError => 'Please enter the product name.';

  @override
  String get productDescriptionLabel => 'Description';

  @override
  String get productBarcodeLabel => 'Barcode (Optional)';

  @override
  String get featureComingSoonMessage => 'Feature coming soon!';

  @override
  String get productCategoryLabel => 'Category';

  @override
  String get productCategoryElectronics => 'Electronics';

  @override
  String get productCategoryClothing => 'Clothing';

  @override
  String get productCategoryHousehold => 'Household';

  @override
  String get productCategoryHygiene => 'Hygiene';

  @override
  String get productCategoryOffice => 'Office Supplies';

  @override
  String get pricingSectionTitle => 'Pricing and Currency';

  @override
  String get inputCurrencyLabel => 'Input Currency';

  @override
  String get inputCurrencyValidationError => 'Please select an input currency.';

  @override
  String get costPriceLabel => 'Cost Price';

  @override
  String get costPriceValidationError => 'Please enter the cost price.';

  @override
  String get negativePriceValidationError => 'Price cannot be negative.';

  @override
  String get invalidNumberValidationError => 'Please enter a valid number.';

  @override
  String get sellingPriceLabel => 'Selling Price';

  @override
  String get sellingPriceValidationError => 'Please enter the selling price.';

  @override
  String get stockManagementSectionTitle => 'Stock Management';

  @override
  String get stockQuantityLabel => 'Quantity in Stock';

  @override
  String get stockQuantityValidationError => 'Please enter the stock quantity.';

  @override
  String get negativeQuantityValidationError => 'Quantity cannot be negative.';

  @override
  String get productUnitLabel => 'Unit';

  @override
  String get productUnitPiece => 'Piece(s)';

  @override
  String get productUnitKg => 'Kilogram(s) (kg)';

  @override
  String get productUnitG => 'Gram(s) (g)';

  @override
  String get productUnitL => 'Liter(s) (L)';

  @override
  String get productUnitMl => 'Milliliter(s) (ml)';

  @override
  String get productUnitPackage => 'Package(s)';

  @override
  String get productUnitBox => 'Box(es)';

  @override
  String get productUnitOther => 'Other Unit';

  @override
  String get lowStockThresholdLabel => 'Low Stock Alert Threshold';

  @override
  String get lowStockThresholdHelper =>
      'Receive an alert when stock reaches this level.';

  @override
  String get lowStockThresholdValidationError =>
      'Please enter a valid alert threshold.';

  @override
  String get negativeThresholdValidationError =>
      'Threshold cannot be negative.';

  @override
  String get saveChangesButton => 'Save Changes';

  @override
  String get addProductButton => 'Add Product';

  @override
  String get notesLabelOptional => 'Notes (Optional)';

  @override
  String addStockDialogTitle(String productName) {
    return 'Add Stock to $productName';
  }

  @override
  String get currentStockLabel => 'Current Stock';

  @override
  String get quantityToAddLabel => 'Quantity to Add';

  @override
  String get quantityValidationError => 'Please enter a quantity.';

  @override
  String get positiveQuantityValidationError =>
      'Quantity must be positive for a purchase.';

  @override
  String get addButtonLabel => 'Add';

  @override
  String get stockAdjustmentDefaultNote => 'Stock adjustment';

  @override
  String get stockTransactionTypeOther => 'Other';

  @override
  String get productInitialFallback => 'P';

  @override
  String get inventoryScreenTitle => 'Inventory';

  @override
  String get allProductsTabLabel => 'All Products';

  @override
  String get lowStockTabLabel => 'Low Stock';

  @override
  String get transactionsTabLabel => 'Transactions';

  @override
  String get noProductsAvailableMessage => 'No products available.';

  @override
  String get noLowStockProductsMessage => 'No products with low stock.';

  @override
  String get noTransactionsAvailableMessage => 'No transactions available.';

  @override
  String get searchProductDialogTitle => 'Search Product';

  @override
  String get searchProductHintText => 'Enter product name or barcode...';

  @override
  String get cancelButtonLabel => 'Cancel';

  @override
  String get searchButtonLabel => 'Search';

  @override
  String get filterByCategoryDialogTitle => 'Filter by Category';

  @override
  String get noCategoriesAvailableMessage =>
      'No categories available to filter.';

  @override
  String get showAllButtonLabel => 'Show All';

  @override
  String get noProductsInInventoryMessage =>
      'You haven\'\'t added any products to your inventory yet.';

  @override
  String get priceLabel => 'Price';

  @override
  String get inputPriceLabel => 'Input';

  @override
  String get stockLabel => 'Stock';

  @override
  String get unknownProductLabel => 'Unknown Product';

  @override
  String get quantityLabel => 'Quantity';

  @override
  String get dateLabel => 'Date';

  @override
  String get valueLabel => 'Label for value';

  @override
  String get retryButtonLabel => 'Retry';

  @override
  String get stockTransactionTypePurchase => 'Purchase';

  @override
  String get stockTransactionTypeSale => 'Sale';

  @override
  String get stockTransactionTypeAdjustment => 'Adjustment';

  @override
  String get salesScreenTitle => 'Sales Management';

  @override
  String get salesTabAll => 'All';

  @override
  String get salesTabPending => 'Pending';

  @override
  String get salesTabCompleted => 'Completed';

  @override
  String get salesFilterDialogTitle => 'Filter Sales';

  @override
  String get salesFilterDialogCancel => 'Cancel';

  @override
  String get salesFilterDialogApply => 'Apply';

  @override
  String get salesSummaryTotal => 'Total Sales';

  @override
  String get salesSummaryCount => 'Number of Sales';

  @override
  String get salesStatusPending => 'Pending';

  @override
  String get salesStatusCompleted => 'Completed';

  @override
  String get salesStatusPartiallyPaid => 'Partially Paid';

  @override
  String get salesStatusCancelled => 'Cancelled';

  @override
  String get salesNoSalesFound => 'No sales found';

  @override
  String get salesAddSaleButton => 'Add Sale';

  @override
  String get salesErrorPrefix => 'Error';

  @override
  String get salesRetryButton => 'Retry';

  @override
  String get salesFilterDialogStartDate => 'Start Date';

  @override
  String get salesFilterDialogEndDate => 'End Date';

  @override
  String get salesListItemSaleIdPrefix => 'Sale #';

  @override
  String salesListItemArticles(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count articles',
      one: '1 article',
    );
    return '$_temp0';
  }

  @override
  String get salesListItemTotal => 'Total:';

  @override
  String get salesListItemRemainingToPay => 'Remaining to pay:';

  @override
  String get subscriptionScreenTitle => 'Subscription Management';

  @override
  String get subscriptionUnsupportedFileType =>
      'Unsupported file type. Please choose a JPG or PNG file.';

  @override
  String get subscriptionFileTooLarge => 'File too large. Maximum size is 5MB.';

  @override
  String get subscriptionNoImageSelected => 'No image selected.';

  @override
  String get subscriptionUpdateSuccessMessage =>
      'Subscription updated successfully.';

  @override
  String subscriptionUpdateFailureMessage(String error) {
    return 'Failed to update subscription: $error';
  }

  @override
  String get subscriptionTokenTopUpSuccessMessage =>
      'Tokens topped up successfully.';

  @override
  String subscriptionTokenTopUpFailureMessage(String error) {
    return 'Failed to top up tokens: $error';
  }

  @override
  String get subscriptionPaymentProofUploadSuccessMessage =>
      'Payment proof uploaded successfully.';

  @override
  String subscriptionPaymentProofUploadFailureMessage(String error) {
    return 'Failed to upload payment proof: $error';
  }

  @override
  String get subscriptionRetryButton => 'Retry';

  @override
  String get subscriptionUnhandledState =>
      'Unhandled state or initialization...';

  @override
  String get subscriptionSectionOurOffers => 'Our Subscription Offers';

  @override
  String get subscriptionSectionCurrentSubscription =>
      'Your Current Subscription';

  @override
  String get subscriptionSectionTokenUsage => 'Adha Token Usage';

  @override
  String get subscriptionSectionInvoiceHistory => 'Invoice History';

  @override
  String get subscriptionSectionPaymentMethods => 'Payment Methods';

  @override
  String get subscriptionChangeSubscriptionButton => 'Change Subscription';

  @override
  String get subscriptionTierFree => 'Free';

  @override
  String subscriptionTierUsers(int count) {
    return 'Users: $count';
  }

  @override
  String subscriptionTierAdhaTokens(int count) {
    return 'Adha Tokens: $count';
  }

  @override
  String get subscriptionTierFeatures => 'Features:';

  @override
  String get subscriptionTierCurrentPlanChip => 'Current Plan';

  @override
  String get subscriptionTierChoosePlanButton => 'Choose this plan';

  @override
  String subscriptionCurrentPlanTitle(String tierName) {
    return 'Current Plan: $tierName';
  }

  @override
  String subscriptionCurrentPlanPrice(String price) {
    return 'Price: $price';
  }

  @override
  String subscriptionAvailableAdhaTokens(int count) {
    return 'Available Adha Tokens: $count';
  }

  @override
  String get subscriptionTopUpTokensButton => 'Top-up Tokens';

  @override
  String get subscriptionNoInvoices => 'No invoices available at the moment.';

  @override
  String subscriptionInvoiceListTitle(String id, String date) {
    return 'Invoice $id - $date';
  }

  @override
  String subscriptionInvoiceListSubtitle(String amount, String status) {
    return 'Amount: $amount - Status: $status';
  }

  @override
  String get subscriptionDownloadInvoiceTooltip => 'Download invoice';

  @override
  String subscriptionSimulateDownloadInvoice(String id, String url) {
    return 'Simulation: Downloading $id from $url';
  }

  @override
  String subscriptionSimulateViewInvoiceDetails(String id) {
    return 'Simulation: View invoice details $id';
  }

  @override
  String get subscriptionPaymentMethodsNextInvoice =>
      'Payment methods for the next invoice:';

  @override
  String get subscriptionPaymentMethodsRegistered => 'Registered methods:';

  @override
  String get subscriptionPaymentMethodsOtherOptions => 'Other payment options:';

  @override
  String get subscriptionPaymentMethodNewCard => 'New Credit Card';

  @override
  String get subscriptionPaymentMethodNewMobileMoney => 'New Mobile Money';

  @override
  String get subscriptionPaymentMethodManual =>
      'Manual Payment (Transfer/Deposit)';

  @override
  String get subscriptionManualPaymentInstructions =>
      'Please make the transfer/deposit to the provided details and upload a proof of payment.';

  @override
  String subscriptionProofUploadedLabel(String fileName) {
    return 'Proof Uploaded: $fileName';
  }

  @override
  String get subscriptionUploadProofButton => 'Upload Proof';

  @override
  String get subscriptionReplaceProofButton => 'Replace Proof';

  @override
  String get subscriptionConfirmPaymentMethodButton => 'Confirm Payment Method';

  @override
  String subscriptionSimulatePaymentMethodSelected(String method) {
    return 'Selected payment method: $method (Simulation)';
  }

  @override
  String get subscriptionChangeDialogTitle => 'Change Subscription';

  @override
  String subscriptionChangeDialogTierSubtitle(String price, String tokens) {
    return '$price - Tokens: $tokens';
  }

  @override
  String get subscriptionTopUpDialogTitle => 'Top-up Adha Tokens';

  @override
  String subscriptionTopUpDialogAmount(String amount, String currencyCode) {
    return '$amount $currencyCode';
  }

  @override
  String get subscriptionNoActivePlan =>
      'You do not have an active subscription plan.';

  @override
  String get contactsScreenTitle => 'Contacts';

  @override
  String get contactsScreenClientsTab => 'Clients';

  @override
  String get contactsScreenSuppliersTab => 'Suppliers';

  @override
  String get contactsScreenAddClientTooltip => 'Add a client';

  @override
  String get contactsScreenAddSupplierTooltip => 'Add a supplier';

  @override
  String get searchCustomerHint => 'Search for a customer...';

  @override
  String customerError(String message) {
    return 'Error: $message';
  }

  @override
  String get noCustomersToShow => 'No customers to display';

  @override
  String get customersTitle => 'Customers';

  @override
  String get filterCustomersTooltip => 'Filter customers';

  @override
  String get addCustomerTooltip => 'Add a new customer';

  @override
  String noResultsForSearchTerm(String searchTerm) {
    return 'No results for $searchTerm';
  }

  @override
  String get noCustomersAvailable => 'No customers available';

  @override
  String get topCustomersByPurchases => 'Top customers by purchases';

  @override
  String get recentlyAddedCustomers => 'Recently added customers';

  @override
  String resultsForSearchTerm(String searchTerm) {
    return 'Results for $searchTerm';
  }

  @override
  String lastPurchaseDate(String date) {
    return 'Last purchase: $date';
  }

  @override
  String get noRecentPurchase => 'No recent purchase';

  @override
  String totalPurchasesAmount(String amount) {
    return 'Total purchases: $amount';
  }

  @override
  String get viewDetails => 'View details';

  @override
  String get edit => 'Edit';

  @override
  String get allCustomers => 'All customers';

  @override
  String get topCustomers => 'Top customers';

  @override
  String get recentCustomers => 'Recent customers';

  @override
  String get byCategory => 'By category';

  @override
  String get filterByCategory => 'Filter by category';

  @override
  String get deleteCustomerTitle => 'Delete customer';

  @override
  String deleteCustomerConfirmation(String customerName) {
    return 'Are you sure you want to delete $customerName? This action is irreversible.';
  }

  @override
  String get customerCategoryVip => 'VIP';

  @override
  String get customerCategoryRegular => 'Regular';

  @override
  String get customerCategoryNew => 'New';

  @override
  String get customerCategoryOccasional => 'Occasional';

  @override
  String get customerCategoryBusiness => 'Business';

  @override
  String get customerCategoryUnknown => 'Unknown';

  @override
  String get editCustomerTitle => 'Edit Customer';

  @override
  String get addCustomerTitle => 'Add Customer';

  @override
  String get customerPhoneHint => '+243 999 123 456';

  @override
  String get customerInformation => 'Customer Information';

  @override
  String get customerNameLabel => 'Customer Name';

  @override
  String get customerNameValidationError =>
      'Please enter the customer\'s name.';

  @override
  String get customerPhoneLabel => 'Customer Phone';

  @override
  String get customerPhoneValidationError =>
      'Please enter the customer\'s phone number.';

  @override
  String get customerEmailLabel => 'Customer Email (Optional)';

  @override
  String get customerEmailLabelOptional => 'Customer Email';

  @override
  String get customerEmailValidationError =>
      'Please enter a valid email address.';

  @override
  String get customerAddressLabel => 'Customer Address (Optional)';

  @override
  String get customerAddressLabelOptional => 'Customer Address';

  @override
  String get customerCategoryLabel => 'Customer Category';

  @override
  String get customerNotesLabel => 'Notes (Optional)';

  @override
  String get updateButtonLabel => 'Update';

  @override
  String get customerDetailsTitle => 'Customer Details';

  @override
  String get editCustomerTooltip => 'Edit customer';

  @override
  String get customerNotFound => 'Customer not found';

  @override
  String get contactInformationSectionTitle => 'Contact Information';

  @override
  String get purchaseStatisticsSectionTitle => 'Purchase Statistics';

  @override
  String get totalPurchasesLabel => 'Total Purchases';

  @override
  String get lastPurchaseLabel => 'Last Purchase';

  @override
  String get noPurchaseRecorded => 'No purchase recorded';

  @override
  String get customerSinceLabel => 'Customer Since';

  @override
  String get addSaleButtonLabel => 'Add Sale';

  @override
  String get callButtonLabel => 'Call';

  @override
  String get deleteButtonLabel => 'Delete';

  @override
  String callingNumber(String phoneNumber) {
    return 'Calling $phoneNumber...';
  }

  @override
  String emailingTo(String email) {
    return 'Emailing to $email...';
  }

  @override
  String openingMapFor(String address) {
    return 'Opening map for $address...';
  }

  @override
  String get searchSupplierHint => 'Search for a supplier...';

  @override
  String get clearSearchTooltip => 'Clear search';

  @override
  String supplierError(String message) {
    return 'Error: $message';
  }

  @override
  String get noSuppliersToShow => 'No suppliers to display';

  @override
  String get suppliersTitle => 'Suppliers';

  @override
  String get filterSuppliersTooltip => 'Filter suppliers';

  @override
  String get addSupplierTooltip => 'Add a new supplier';

  @override
  String get noSuppliersAvailable => 'No suppliers available';

  @override
  String get topSuppliersByPurchases => 'Top suppliers by purchases';

  @override
  String get recentlyAddedSuppliers => 'Recently added suppliers';

  @override
  String contactPerson(String name) {
    return 'Contact: $name';
  }

  @override
  String get moreOptionsTooltip => 'More options';

  @override
  String get allSuppliers => 'All suppliers';

  @override
  String get topSuppliers => 'Top suppliers';

  @override
  String get recentSuppliers => 'Recent suppliers';

  @override
  String get deleteSupplierTitle => 'Delete supplier';

  @override
  String deleteSupplierConfirmation(String supplierName) {
    return 'Are you sure you want to delete $supplierName? This action is irreversible.';
  }

  @override
  String get supplierCategoryStrategic => 'Strategic';

  @override
  String get supplierCategoryRegular => 'Regular';

  @override
  String get supplierCategoryNew => 'New';

  @override
  String get supplierCategoryOccasional => 'Occasional';

  @override
  String get supplierCategoryInternational => 'International';

  @override
  String get supplierCategoryUnknown => 'Unknown';

  @override
  String get supplierCategoryLocal => 'Local';

  @override
  String get supplierCategoryOnline => 'Online';

  @override
  String get addSupplierTitle => 'Add Supplier';

  @override
  String get editSupplierTitle => 'Edit Supplier';

  @override
  String get supplierInformation => 'Supplier Information';

  @override
  String get supplierNameLabel => 'Supplier Name *';

  @override
  String get supplierNameValidationError => 'Name is required';

  @override
  String get supplierPhoneLabel => 'Phone Number *';

  @override
  String get supplierPhoneValidationError => 'Phone number is required';

  @override
  String get supplierPhoneHint => '+243 999 123 456';

  @override
  String get supplierEmailLabel => 'Email';

  @override
  String get supplierEmailValidationError => 'Please enter a valid email';

  @override
  String get supplierContactPersonLabel => 'Contact Person';

  @override
  String get supplierAddressLabel => 'Address';

  @override
  String get commercialInformation => 'Commercial Information';

  @override
  String get deliveryTimeLabel => 'Delivery Time';

  @override
  String get paymentTermsLabel => 'Payment Terms';

  @override
  String get paymentTermsHint => 'Ex: Net 30, 50% upfront, etc.';

  @override
  String get supplierCategoryLabel => 'Supplier Category';

  @override
  String get supplierNotesLabel => 'Notes';

  @override
  String get updateSupplierButton => 'Update';

  @override
  String get addSupplierButton => 'Add';

  @override
  String get supplierDetailsTitle => 'Supplier Details';

  @override
  String supplierErrorLoading(String message) {
    return 'Error: $message';
  }

  @override
  String get supplierNotFound => 'Supplier not found';

  @override
  String get contactLabel => 'Contact';

  @override
  String get phoneLabel => 'Phone';

  @override
  String get emailLabel => 'Email';

  @override
  String get addressLabel => 'Address';

  @override
  String get commercialInformationSectionTitle => 'Commercial Information';

  @override
  String deliveryTimeInDays(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count days',
      one: '1 day',
      zero: 'Not specified',
    );
    return '$_temp0';
  }

  @override
  String get supplierSinceLabel => 'Supplier Since';

  @override
  String get notesSectionTitle => 'Notes';

  @override
  String get placeOrderButtonLabel => 'Place Order';

  @override
  String get featureToImplement => 'Feature to implement';

  @override
  String get confirmDeleteSupplierTitle => 'Delete Supplier';

  @override
  String confirmDeleteSupplierMessage(String supplierName) {
    return 'Are you sure you want to delete $supplierName? This action is irreversible.';
  }

  @override
  String get commonConfirm => 'Confirm';

  @override
  String get commonError => 'Error';

  @override
  String get commonToday => 'Today';

  @override
  String get commonThisMonth => 'This Month';

  @override
  String get commonThisYear => 'This Year';

  @override
  String get commonCustom => 'Custom';

  @override
  String get commonAnonymousClient => 'Anonymous Client';

  @override
  String get commonAnonymousClientInitial => 'A';

  @override
  String get commonErrorDataUnavailable => 'Data unavailable';

  @override
  String get commonNoData => 'No data available';

  @override
  String get dashboardScreenTitle => 'Dashboard';

  @override
  String get dashboardHeaderSalesToday => 'Sales Today';

  @override
  String get dashboardHeaderClientsServed => 'Clients Served';

  @override
  String get dashboardHeaderReceivables => 'Receivables';

  @override
  String get dashboardHeaderTransactions => 'Transactions';

  @override
  String get dashboardCardViewDetails => 'View Details';

  @override
  String get dashboardSalesChartTitle => 'Sales Overview';

  @override
  String get dashboardSalesChartNoData =>
      'No sales data to display for the chart.';

  @override
  String get dashboardRecentSalesTitle => 'Recent Sales';

  @override
  String get dashboardRecentSalesViewAll => 'View All';

  @override
  String get dashboardRecentSalesNoData => 'No recent sales.';

  @override
  String get dashboardOperationsJournalTitle => 'Operations Journal';

  @override
  String get dashboardOperationsJournalViewAll => 'View All';

  @override
  String get dashboardOperationsJournalNoData => 'No recent operations.';

  @override
  String get dashboardOperationsJournalBalanceLabel => 'Balance';

  @override
  String get dashboardJournalExportSelectDateRangeTitle => 'Select Date Range';

  @override
  String get dashboardJournalExportExportButton => 'Export to PDF';

  @override
  String get dashboardJournalExportPrintButton => 'Print Journal';

  @override
  String get dashboardJournalExportSuccessMessage =>
      'Journal exported successfully.';

  @override
  String get dashboardJournalExportFailureMessage =>
      'Failed to export journal.';

  @override
  String get dashboardJournalExportNoDataForPeriod =>
      'No data available for the selected period to export.';

  @override
  String get dashboardJournalExportPrintingMessage =>
      'Preparing journal for printing...';

  @override
  String get dashboardQuickActionsTitle => 'Quick Actions';

  @override
  String get dashboardQuickActionsNewSale => 'New Sale';

  @override
  String get dashboardQuickActionsNewExpense => 'New Expense';

  @override
  String get dashboardQuickActionsNewProduct => 'New Product';

  @override
  String get dashboardQuickActionsNewService => 'New Service';

  @override
  String get dashboardQuickActionsNewClient => 'New Client';

  @override
  String get dashboardQuickActionsNewSupplier => 'New Supplier';

  @override
  String get dashboardQuickActionsCashRegister => 'Cash Register';

  @override
  String get dashboardQuickActionsSettings => 'Settings';

  @override
  String get dashboardQuickActionsNewInvoice => 'Invoicing';

  @override
  String get dashboardQuickActionsNewFinancing => 'Financing';

  @override
  String get commonLoading => 'Loading...';

  @override
  String get cancel => 'Cancel';

  @override
  String get journalPdf_title => 'Operations Journal';

  @override
  String journalPdf_footer_pageInfo(int currentPage, int totalPages) {
    return 'Page $currentPage of $totalPages';
  }

  @override
  String journalPdf_period(String startDate, String endDate) {
    return 'Period: $startDate - $endDate';
  }

  @override
  String get journalPdf_tableHeader_date => 'Date';

  @override
  String get journalPdf_tableHeader_time => 'Time';

  @override
  String get journalPdf_tableHeader_description => 'Description';

  @override
  String get journalPdf_tableHeader_debit => 'Debit';

  @override
  String get journalPdf_tableHeader_credit => 'Credit';

  @override
  String get journalPdf_tableHeader_balance => 'Balance';

  @override
  String get journalPdf_openingBalance => 'Opening Balance';

  @override
  String get journalPdf_closingBalance => 'Closing Balance';

  @override
  String get journalPdf_footer_generatedBy => 'Generated by Wanzo';

  @override
  String get adhaHomePageTitle => 'Adha - AI Assistant';

  @override
  String get adhaHomePageDescription => 'Adha, your smart business assistant';

  @override
  String get adhaHomePageBody =>
      'Ask me questions about your business and I will help you make the best decisions with personalized analysis and advice.';

  @override
  String get startConversationButton => 'Start a conversation';

  @override
  String get viewConversationsButton => 'View my conversations';

  @override
  String get salesAnalysisFeatureTitle => 'Sales Analysis';

  @override
  String get salesAnalysisFeatureDescription =>
      'Get insights into your sales performance';

  @override
  String get inventoryManagementFeatureTitle => 'Inventory Management';

  @override
  String get inventoryManagementFeatureDescription =>
      'Track and optimize your inventory';

  @override
  String get customerRelationsFeatureTitle => 'Customer Relations';

  @override
  String get customerRelationsFeatureDescription =>
      'Advice for retaining your customers';

  @override
  String get financialCalculationsFeatureTitle => 'Financial Calculations';

  @override
  String get financialCalculationsFeatureDescription =>
      'Financial projections and analysis';

  @override
  String get loginButton => 'Login';

  @override
  String get registerButton => 'Register';

  @override
  String get emailHint => 'Enter your email';

  @override
  String get emailValidationErrorRequired => 'Please enter your email';

  @override
  String get emailValidationErrorInvalid => 'Please enter a valid email';

  @override
  String get passwordLabel => 'Password';

  @override
  String get passwordHint => 'Enter your password';

  @override
  String get passwordValidationErrorRequired => 'Please enter your password';

  @override
  String authFailureMessage(Object message) {
    return 'Authentication failed: $message';
  }

  @override
  String get loginToYourAccount => 'Login to your account';

  @override
  String get rememberMeLabel => 'Remember me';

  @override
  String get forgotPasswordButton => 'Forgot password?';

  @override
  String get noAccountPrompt => 'Don\'t have an account?';

  @override
  String get createAccountButton => 'Create account';

  @override
  String get demoModeButton => 'Demo Mode';

  @override
  String get settings => 'Settings';

  @override
  String get settingsTitle => 'Settings';

  @override
  String get settingsDescription => 'Manage your application settings.';

  @override
  String get wanzoFallbackText => 'Wanzo Fallback';

  @override
  String get appVersion => 'App Version';

  @override
  String get loadingSettings => 'Loading settings...';

  @override
  String get companyInformation => 'Company Information';

  @override
  String get companyInformationSubtitle => 'Manage your company details';

  @override
  String get appearanceAndDisplay => 'Appearance and Display';

  @override
  String get appearanceAndDisplaySubtitle => 'Customize the look and feel';

  @override
  String get theme => 'Theme';

  @override
  String get themeLight => 'Light';

  @override
  String get themeDark => 'Dark';

  @override
  String get themeSystem => 'System';

  @override
  String get language => 'Language';

  @override
  String get languageEnglish => 'English';

  @override
  String get languageFrench => 'French';

  @override
  String get languageSwahili => 'Swahili';

  @override
  String get dateFormat => 'Date Format';

  @override
  String get dateFormatDDMMYYYY => 'DD/MM/YYYY';

  @override
  String get dateFormatMMDDYYYY => 'MM/DD/YYYY';

  @override
  String get dateFormatYYYYMMDD => 'YYYY/MM/DD';

  @override
  String get dateFormatDDMMMYYYY => 'DD MMM YYYY';

  @override
  String get monthJan => 'January';

  @override
  String get monthFeb => 'February';

  @override
  String get monthMar => 'March';

  @override
  String get monthApr => 'April';

  @override
  String get monthMay => 'May';

  @override
  String get monthJun => 'June';

  @override
  String get monthJul => 'July';

  @override
  String get monthAug => 'August';

  @override
  String get monthSep => 'September';

  @override
  String get monthOct => 'October';

  @override
  String get monthNov => 'November';

  @override
  String get monthDec => 'December';

  @override
  String get changeLogo => 'Change Logo';

  @override
  String get companyName => 'Company Name';

  @override
  String get companyNameRequired => 'Company name is required';

  @override
  String get email => 'Email';

  @override
  String get invalidEmail => 'Invalid email address';

  @override
  String get phoneNumber => 'Phone Number';

  @override
  String get address => 'Address';

  @override
  String get rccm => 'RCCM';

  @override
  String get rccmHelperText => 'Trade and Personal Property Credit Register';

  @override
  String get taxId => 'Tax ID';

  @override
  String get taxIdHelperText => 'National Tax Identification Number';

  @override
  String get website => 'Website';

  @override
  String get invoiceSettings => 'Invoice Settings';

  @override
  String get invoiceSettingsSubtitle => 'Manage your invoice preferences';

  @override
  String get defaultInvoiceFooter => 'Default Invoice Footer';

  @override
  String get defaultInvoiceFooterHint => 'e.g., Thank you for your business!';

  @override
  String get showTotalInWords => 'Show Total in Words';

  @override
  String get exchangeRate => 'Exchange Rate (USD to Local)';

  @override
  String get inventorySettings => 'Inventory Settings';

  @override
  String get inventorySettingsSubtitle => 'Manage your inventory preferences';

  @override
  String get generalSettings => 'General Settings';

  @override
  String get defaultCategory => 'Default Category';

  @override
  String get defaultCategoryRequired => 'Default category is required';

  @override
  String get lowStockAlert => 'Low Stock Alert';

  @override
  String get lowStockAlertHint => 'Quantity at which to trigger alert';

  @override
  String get trackInventory => 'Track Inventory';

  @override
  String get allowNegativeStock => 'Allow Negative Stock';

  @override
  String get saveChanges => 'Save Changes';

  @override
  String get settingsUpdatedSuccessfully => 'Settings updated successfully';

  @override
  String get errorUpdatingSettings => 'Error updating settings';

  @override
  String get changesSaved => 'Changes saved successfully!';

  @override
  String get errorSavingChanges => 'Error saving changes';

  @override
  String get selectTheme => 'Select Theme';

  @override
  String get selectLanguage => 'Select Language';

  @override
  String get selectDateFormat => 'Select Date Format';

  @override
  String get displaySettings => 'Display Settings';

  @override
  String get displaySettingsDescription => 'Manage display settings.';

  @override
  String get companySettings => 'Company Settings';

  @override
  String get companySettingsDescription => 'Manage company settings.';

  @override
  String get invoiceSettingsDescription => 'Manage invoice settings.';

  @override
  String get inventorySettingsDescription => 'Manage inventory settings.';

  @override
  String minValue(double minValue) {
    return 'Min value: $minValue';
  }

  @override
  String maxValue(double maxValue) {
    return 'Max value: $maxValue';
  }

  @override
  String get valueMustBeNumber => 'Value must be a number';

  @override
  String get valueMustBePositive => 'Value must be positive';

  @override
  String get fieldRequired => 'This field is required';

  @override
  String get settingsGeneral => 'General';

  @override
  String get settingsCompany => 'Company';

  @override
  String get settingsInvoice => 'Invoice';

  @override
  String get settingsInventory => 'Inventory';

  @override
  String get settingsAppearance => 'Appearance';

  @override
  String get searchSettings => 'Search settings...';

  @override
  String get backupAndReports => 'Backup and Reports';

  @override
  String get backupAndReportsSubtitle =>
      'Manage data backup and generate reports';

  @override
  String get notifications => 'Notifications';

  @override
  String get notificationsSubtitle => 'Manage app notifications';

  @override
  String get resetSettings => 'Reset Settings';

  @override
  String get confirmResetSettings =>
      'Are you sure you want to reset all settings to their default values? This action cannot be undone.';

  @override
  String get reset => 'Reset';

  @override
  String get taxIdentificationNumber => 'Tax Identification Number';

  @override
  String get rccmNumber => 'RCCM Number';

  @override
  String get idNatNumber => 'National ID Number';

  @override
  String get idNatHelperText => 'National Identification Number';

  @override
  String get selectImageSource => 'Select Image Source';

  @override
  String get gallery => 'Gallery';

  @override
  String get camera => 'Camera';

  @override
  String get deleteCurrentLogo => 'Delete Current Logo';

  @override
  String get logoDeleted => 'Logo deleted.';

  @override
  String get logoUpdatedSuccessfully => 'Logo updated successfully.';

  @override
  String errorSelectingLogo(String errorDetails) {
    return 'Error selecting logo: $errorDetails';
  }

  @override
  String get defaultProductCategory => 'Default Product Category';

  @override
  String get stockAlerts => 'Stock Alerts';

  @override
  String get lowStockAlertDays => 'Low Stock Alert Days';

  @override
  String get days => 'Days';

  @override
  String get enterValidNumber => 'Please enter a valid number.';

  @override
  String get lowStockAlertDescription =>
      'Receive alerts when product stock is low for a specified number of days.';

  @override
  String get productCategories => 'Product Categories';

  @override
  String get manageYourProductCategories => 'Manage your product categories.';

  @override
  String get addCategory => 'Add Category';

  @override
  String get editCategory => 'Edit Category';

  @override
  String get deleteCategory => 'Delete Category';

  @override
  String get categoryName => 'Category Name';

  @override
  String get categoryNameCannotBeEmpty => 'Category name cannot be empty.';

  @override
  String get categoryAdded => 'Category added';

  @override
  String get categoryUpdated => 'Category updated';

  @override
  String get categoryDeleted => 'Category deleted';

  @override
  String get confirmDeleteCategory =>
      'Are you sure you want to delete this category?';

  @override
  String get deleteCategoryMessage => 'This action cannot be undone.';

  @override
  String errorAddingCategory(Object error) {
    return 'Error adding category: $error';
  }

  @override
  String errorUpdatingCategory(Object error) {
    return 'Error updating category: $error';
  }

  @override
  String errorDeletingCategory(Object error) {
    return 'Error deleting category: $error';
  }

  @override
  String errorFetchingCategories(Object error) {
    return 'Error fetching categories: $error';
  }

  @override
  String get noCategoriesFound =>
      'No categories found. Add one to get started!';

  @override
  String get signupScreenTitle => 'Create Business Account';

  @override
  String get signupStepIdentity => 'Identity';

  @override
  String get signupStepCompany => 'Company';

  @override
  String get signupStepConfirmation => 'Confirmation';

  @override
  String get signupPersonalInfoTitle => 'Your Personal Information';

  @override
  String get signupOwnerNameLabel => 'Full Name of Owner';

  @override
  String get signupOwnerNameHint => 'Enter your full name';

  @override
  String get signupOwnerNameValidation => 'Please enter the owner\'s name';

  @override
  String get signupEmailLabel => 'Email Address';

  @override
  String get signupEmailHint => 'Enter your email address';

  @override
  String get signupEmailValidationRequired => 'Please enter your email';

  @override
  String get signupEmailValidationInvalid => 'Please enter a valid email';

  @override
  String get signupPhoneLabel => 'Phone Number';

  @override
  String get signupPhoneHint => 'Enter your phone number';

  @override
  String get signupPhoneValidation => 'Please enter your phone number';

  @override
  String get signupPasswordLabel => 'Password';

  @override
  String get signupPasswordHint => 'Enter your password (min. 8 characters)';

  @override
  String get signupPasswordValidationRequired => 'Please enter a password';

  @override
  String get signupPasswordValidationLength =>
      'Password must be at least 8 characters';

  @override
  String get signupConfirmPasswordLabel => 'Confirm Password';

  @override
  String get signupConfirmPasswordHint => 'Confirm your password';

  @override
  String get signupConfirmPasswordValidationRequired =>
      'Please confirm your password';

  @override
  String get signupConfirmPasswordValidationMatch => 'Passwords do not match';

  @override
  String get signupRequiredFields => '* Required fields';

  @override
  String get signupCompanyInfoTitle => 'Your Company Information';

  @override
  String get signupCompanyNameLabel => 'Company Name';

  @override
  String get signupCompanyNameHint => 'Enter your company name';

  @override
  String get signupCompanyNameValidation => 'Please enter the company name';

  @override
  String get signupRccmLabel => 'RCCM Number / Business Registration';

  @override
  String get signupRccmHint => 'Enter your RCCM number or equivalent';

  @override
  String get signupRccmValidation => 'Please enter the RCCM number';

  @override
  String get signupAddressLabel => 'Address / Location';

  @override
  String get signupAddressHint => 'Enter your company address';

  @override
  String get signupAddressValidation => 'Please enter your company address';

  @override
  String get signupActivitySectorLabel => 'Business Sector';

  @override
  String get signupTermsAndConditionsTitle => 'Summary and Terms';

  @override
  String get signupInfoSummaryPersonal => 'Personal Information:';

  @override
  String get signupInfoSummaryName => 'Name:';

  @override
  String get signupInfoSummaryEmail => 'Email:';

  @override
  String get signupInfoSummaryPhone => 'Phone:';

  @override
  String get signupInfoSummaryCompany => 'Company Information:';

  @override
  String get signupInfoSummaryCompanyName => 'Company Name:';

  @override
  String get signupInfoSummaryRccm => 'RCCM:';

  @override
  String get signupInfoSummaryAddress => 'Address:';

  @override
  String get signupInfoSummaryActivitySector => 'Activity Sector:';

  @override
  String get signupAgreeToTerms => 'I have read and agree to the';

  @override
  String get signupTermsOfUse => 'Terms of Use';

  @override
  String get andConnector => 'and';

  @override
  String get signupPrivacyPolicy => 'Privacy Policy';

  @override
  String get signupAgreeToTermsConfirmation =>
      'By checking this box, you confirm that you have read, understood, and accepted our terms of service and privacy policy.';

  @override
  String get signupButtonPrevious => 'Previous';

  @override
  String get signupButtonNext => 'Next';

  @override
  String get signupButtonRegister => 'Register';

  @override
  String get signupAlreadyHaveAccount => 'Already have an account? Log in';

  @override
  String get signupErrorFillFields =>
      'Please fill in all required fields correctly for the current step.';

  @override
  String get signupErrorAgreeToTerms =>
      'You must agree to the terms and conditions to register.';

  @override
  String get signupSuccessMessage =>
      'Registration successful! Logging you in...';

  @override
  String signupErrorRegistration(String error) {
    return 'Registration failed: $error';
  }

  @override
  String get sectorAgricultureName => 'Agriculture and Agri-food';

  @override
  String get sectorAgricultureDescription =>
      'Agricultural production, food processing, livestock';

  @override
  String get sectorCommerceName => 'Trade and Distribution';

  @override
  String get sectorCommerceDescription => 'Retail, distribution, import-export';

  @override
  String get sectorServicesName => 'Services';

  @override
  String get sectorServicesDescription => 'Business and personal services';

  @override
  String get sectorTechnologyName => 'Technology and Innovation';

  @override
  String get sectorTechnologyDescription =>
      'Software development, telecommunications, fintech';

  @override
  String get sectorManufacturingName => 'Manufacturing and Industry';

  @override
  String get sectorManufacturingDescription =>
      'Industrial production, crafts, textiles';

  @override
  String get sectorConstructionName => 'Construction and Real Estate';

  @override
  String get sectorConstructionDescription =>
      'Construction, real estate development, architecture';

  @override
  String get sectorTransportationName => 'Transport and Logistics';

  @override
  String get sectorTransportationDescription =>
      'Freight transport, logistics, warehousing';

  @override
  String get sectorEnergyName => 'Energy and Natural Resources';

  @override
  String get sectorEnergyDescription => 'Energy production, mining, water';

  @override
  String get sectorTourismName => 'Tourism and Hospitality';

  @override
  String get sectorTourismDescription => 'Hotels, restaurants, tourism';

  @override
  String get sectorEducationName => 'Education and Training';

  @override
  String get sectorEducationDescription => 'Teaching, vocational training';

  @override
  String get sectorHealthName => 'Health and Medical Services';

  @override
  String get sectorHealthDescription =>
      'Medical care, pharmacy, medical equipment';

  @override
  String get sectorFinanceName => 'Financial Services';

  @override
  String get sectorFinanceDescription => 'Banking, insurance, microfinance';

  @override
  String get sectorOtherName => 'Other';

  @override
  String get sectorOtherDescription => 'Other business sectors';

  @override
  String get financeSettings => 'Finance';

  @override
  String get financeSettingsSubtitle =>
      'Configure your bank accounts and Mobile Money';

  @override
  String get businessUnitTypeCompany => 'Company';

  @override
  String get businessUnitTypeBranch => 'Branch';

  @override
  String get businessUnitTypePOS => 'Point of Sale';

  @override
  String get businessUnitTypeCompanyDesc => 'Headquarters - Main establishment';

  @override
  String get businessUnitTypeBranchDesc => 'Regional branch or agency';

  @override
  String get businessUnitTypePOSDesc => 'Point of sale, shop or warehouse';

  @override
  String get businessUnitStatusActive => 'Active';

  @override
  String get businessUnitStatusInactive => 'Inactive';

  @override
  String get businessUnitStatusSuspended => 'Suspended';

  @override
  String get businessUnitStatusClosed => 'Closed';

  @override
  String get businessUnitConfiguration => 'Business Unit';

  @override
  String get businessUnitConfigurationDescription =>
      'Configure the unit to isolate data by establishment';

  @override
  String get businessUnitDefaultCompany => 'Company Level';

  @override
  String get businessUnitDefaultDescription => 'Global company data';

  @override
  String get businessUnitDefaultCompanyDescription =>
      'You are operating at company level. All data is centralized.';

  @override
  String get businessUnitLevelDefault => 'Default';

  @override
  String get businessUnitConfigureByCode => 'Configure a branch or POS';

  @override
  String get businessUnitConfigureByCodeDescription =>
      'Enter the code received when creating the unit';

  @override
  String get businessUnitCodeLabel => 'Unit code';

  @override
  String get businessUnitCodeHint => 'E.g: BRN-001, POS-KIN-001';

  @override
  String get businessUnitCodeHelper => 'Unique code provided by administrator';

  @override
  String get businessUnitCodeInfo =>
      'Once the branch or point of sale is created from the back-office, you will receive a code to configure this device.';

  @override
  String get businessUnitCode => 'Code';

  @override
  String get businessUnitType => 'Type';

  @override
  String get businessUnitName => 'Unit name';

  @override
  String get businessUnitConfigured => 'Unit configured';

  @override
  String get businessUnitChangeInfo =>
      'To change unit, contact the administrator or reset the application.';

  @override
  String get userRoleAdmin => 'Administrator';

  @override
  String get userRoleSuperAdmin => 'Super Administrator';

  @override
  String get userRoleManager => 'Manager';

  @override
  String get userRoleAccountant => 'Accountant';

  @override
  String get userRoleCashier => 'Cashier';

  @override
  String get userRoleSales => 'Sales';

  @override
  String get userRoleInventoryManager => 'Inventory Manager';

  @override
  String get userRoleStaff => 'Staff';

  @override
  String get userRoleCustomerSupport => 'Customer Support';

  @override
  String get userRoleAdminDescription => 'Business owner with full rights';

  @override
  String get userRoleSuperAdminDescription =>
      'Maximum rights across the company and all services';

  @override
  String get userRoleManagerDescription => 'Manager with extended rights';

  @override
  String get userRoleAccountantDescription => 'Access to accounting functions';

  @override
  String get userRoleCashierDescription => 'Access to cashier functions';

  @override
  String get userRoleSalesDescription => 'Access to sales functions';

  @override
  String get userRoleInventoryManagerDescription =>
      'Access to inventory management';

  @override
  String get userRoleStaffDescription => 'Standard employee';

  @override
  String get userRoleCustomerSupportDescription => 'Access to customer support';
}
