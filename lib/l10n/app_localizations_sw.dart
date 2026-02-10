// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Swahili (`sw`).
class AppLocalizationsSw extends AppLocalizations {
  AppLocalizationsSw([String locale = 'sw']) : super(locale);

  @override
  String get invoiceSettingsTitle => 'Mipangilio ya Ankara';

  @override
  String get currencySettings => 'Mipangilio ya Sarafu';

  @override
  String get activeCurrency => 'Sarafu Inayotumika';

  @override
  String exchangeRateSpecific(String currencyFrom, String currencyTo) {
    return 'Kiwango cha ubadilishaji ($currencyFrom hadi $currencyTo)';
  }

  @override
  String exchangeRateHint(String currencyFrom, String currencyTo) {
    return 'Weka kiwango cha 1 $currencyFrom hadi $currencyTo';
  }

  @override
  String get errorFieldRequired => 'Sehemu hii inahitajika.';

  @override
  String get errorInvalidRate => 'Tafadhali weka kiwango sahihi chanya.';

  @override
  String get invoiceFormatting => 'Muundo wa Ankara';

  @override
  String invoiceFormatHint(Object YEAR, Object MONTH, Object SEQ) {
    return 'Tumia $YEAR, $MONTH, $SEQ kwa thamani zinazobadilika.';
  }

  @override
  String get invoiceNumberFormat => 'Umbizo la Nambari ya Ankara';

  @override
  String get invoicePrefix => 'Kiambishi awali cha Ankara';

  @override
  String get taxesAndConditions => 'Kodi na Masharti';

  @override
  String get showTaxesOnInvoices => 'Onyesha kodi kwenye ankara';

  @override
  String get defaultTaxRatePercentage => 'Kiwango cha Kodi Chaguomsingi (%)';

  @override
  String get errorInvalidTaxRate =>
      'Kiwango cha kodi lazima kiwe kati ya 0 na 100.';

  @override
  String get defaultPaymentTerms => 'Masharti Chaguomsingi ya Malipo';

  @override
  String get defaultInvoiceNotes => 'Maelezo Chaguomsingi ya Ankara';

  @override
  String get settingsSavedSuccess => 'Mipangilio imehifadhiwa kikamilifu.';

  @override
  String get anErrorOccurred => 'Hitilafu imetokea.';

  @override
  String get errorUnknown => 'Hitilafu isiyojulikana';

  @override
  String currencySettingsError(String errorDetails) {
    return 'Haikuweza kuhifadhi mipangilio ya sarafu: $errorDetails';
  }

  @override
  String get currencySettingsSavedSuccess =>
      'Mipangilio ya sarafu imehifadhiwa kikamilifu.';

  @override
  String get currencyCDF => 'Faranga ya Kongo';

  @override
  String get currencyUSD => 'Dola ya Marekani';

  @override
  String get currencyFCFA => 'Faranga ya CFA';

  @override
  String get editProductTitle => 'Hariri Bidhaa';

  @override
  String get addProductTitle => 'Ongeza Bidhaa';

  @override
  String get productCategoryFood => 'Chakula';

  @override
  String get productCategoryDrink => 'Kinywaji';

  @override
  String get productCategoryOther => 'Nyingine';

  @override
  String get units => 'Vipimo';

  @override
  String get notes => 'Maelezo (Si lazima)';

  @override
  String get saveProduct => 'Hifadhi Bidhaa';

  @override
  String get inventoryValue => 'Thamani ya Mali';

  @override
  String get products => 'Bidhaa';

  @override
  String get stockMovements => 'Mienendo ya Hisa';

  @override
  String get noProducts => 'Hakuna bidhaa bado.';

  @override
  String get noStockMovements => 'Hakuna mienendo ya hisa bado.';

  @override
  String get searchProducts => 'Tafuta bidhaa...';

  @override
  String get totalStock => 'Jumla ya Hisa';

  @override
  String get valueInCdf => 'Thamani (CDF)';

  @override
  String valueIn(String currencyCode) {
    return 'Thamani ($currencyCode)';
  }

  @override
  String get lastModified => 'Imebadilishwa Mwisho';

  @override
  String get productDetails => 'Maelezo ya Bidhaa';

  @override
  String get deleteProduct => 'Futa Bidhaa';

  @override
  String get confirmDeleteProductTitle => 'Thibitisha Kufuta';

  @override
  String get confirmDeleteProductMessage =>
      'Una uhakika unataka kufuta bidhaa hii? Kitendo hiki hakiwezi kutenduliwa.';

  @override
  String get commonCancel => 'Ghairi';

  @override
  String get delete => 'Futa';

  @override
  String get stockIn => 'Uingizaji Hisa';

  @override
  String get stockOut => 'Utoaji Hisa';

  @override
  String get adjustment => 'Marekebisho';

  @override
  String get quantity => 'Kiasi';

  @override
  String get reason => 'Sababu (Si lazima)';

  @override
  String get addStockMovement => 'Ongeza Mwenendo wa Hisa';

  @override
  String get newStock => 'Hisa Mpya';

  @override
  String get value => 'Thamani';

  @override
  String get type => 'Aina';

  @override
  String get date => 'Tarehe';

  @override
  String get product => 'Bidhaa';

  @override
  String get selectProduct => 'Chagua Bidhaa';

  @override
  String get selectCategory => 'Chagua Kategoria';

  @override
  String get selectUnit => 'Chagua Kipimo';

  @override
  String imagePickingErrorMessage(String errorDetails) {
    return 'Hitilafu wakati wa kuchagua picha: $errorDetails';
  }

  @override
  String get galleryAction => 'Matunzio';

  @override
  String get cameraAction => 'Kamera';

  @override
  String get removeImageAction => 'Ondoa Picha';

  @override
  String get productImageSectionTitle => 'Picha ya Bidhaa';

  @override
  String get addImageLabel => 'Ongeza Picha';

  @override
  String get generalInformationSectionTitle => 'Taarifa za Jumla';

  @override
  String get productNameLabel => 'Jina la Bidhaa';

  @override
  String get productNameValidationError => 'Tafadhali ingiza jina la bidhaa.';

  @override
  String get productDescriptionLabel => 'Maelezo';

  @override
  String get productBarcodeLabel => 'Msimbo Pau (Si lazima)';

  @override
  String get featureComingSoonMessage => 'Kipengele kinakuja hivi karibuni!';

  @override
  String get productCategoryLabel => 'Kategoria';

  @override
  String get productCategoryElectronics => 'Elektroniki';

  @override
  String get productCategoryClothing => 'Nguo';

  @override
  String get productCategoryHousehold => 'Vifaa vya Nyumbani';

  @override
  String get productCategoryHygiene => 'Usafi';

  @override
  String get productCategoryOffice => 'Vifaa vya Ofisi';

  @override
  String get pricingSectionTitle => 'Bei na Sarafu';

  @override
  String get inputCurrencyLabel => 'Sarafu ya Kuingiza';

  @override
  String get inputCurrencyValidationError =>
      'Tafadhali chagua sarafu ya kuingiza.';

  @override
  String get costPriceLabel => 'Bei ya Gharama';

  @override
  String get costPriceValidationError => 'Tafadhali ingiza bei ya gharama.';

  @override
  String get negativePriceValidationError => 'Bei haiwezi kuwa hasi.';

  @override
  String get invalidNumberValidationError => 'Tafadhali ingiza nambari sahihi.';

  @override
  String get sellingPriceLabel => 'Bei ya Kuuza';

  @override
  String get sellingPriceValidationError => 'Tafadhali ingiza bei ya kuuza.';

  @override
  String get stockManagementSectionTitle => 'Usimamizi wa Hisa';

  @override
  String get stockQuantityLabel => 'Kiasi katika Hisa';

  @override
  String get stockQuantityValidationError => 'Tafadhali ingiza kiasi cha hisa.';

  @override
  String get negativeQuantityValidationError => 'Kiasi hakiwezi kuwa hasi.';

  @override
  String get productUnitLabel => 'Kipimo';

  @override
  String get productUnitPiece => 'Kipande(Vipande)';

  @override
  String get productUnitKg => 'Kilogramu (kg)';

  @override
  String get productUnitG => 'Gramu (g)';

  @override
  String get productUnitL => 'Lita (L)';

  @override
  String get productUnitMl => 'Mililita (ml)';

  @override
  String get productUnitPackage => 'Kifurushi(Vifurushi)';

  @override
  String get productUnitBox => 'Sanduku(Masanduku)';

  @override
  String get productUnitOther => 'Kipimo Kingine';

  @override
  String get lowStockThresholdLabel => 'Kiwango cha Tahadhari ya Hisa Chini';

  @override
  String get lowStockThresholdHelper =>
      'Pokea tahadhari hisa inapofikia kiwango hiki.';

  @override
  String get lowStockThresholdValidationError =>
      'Tafadhali ingiza kiwango sahihi cha tahadhari.';

  @override
  String get negativeThresholdValidationError => 'Kiwango hakiwezi kuwa hasi.';

  @override
  String get saveChangesButton => 'Hifadhi Mabadiliko';

  @override
  String get addProductButton => 'Ongeza Bidhaa';

  @override
  String get notesLabelOptional => 'Maelezo (Si lazima)';

  @override
  String addStockDialogTitle(String productName) {
    return 'Ongeza Hisa kwa $productName';
  }

  @override
  String get currentStockLabel => 'Hisa ya Sasa';

  @override
  String get quantityToAddLabel => 'Kiasi cha Kuongeza';

  @override
  String get quantityValidationError => 'Tafadhali ingiza kiasi.';

  @override
  String get positiveQuantityValidationError =>
      'Kiasi lazima kiwe chanya kwa ununuzi.';

  @override
  String get addButtonLabel => 'Ongeza';

  @override
  String get stockAdjustmentDefaultNote => 'Marekebisho ya hisa';

  @override
  String get stockTransactionTypeOther => 'Nyingine';

  @override
  String get productInitialFallback => 'B';

  @override
  String get inventoryScreenTitle => 'Mali';

  @override
  String get allProductsTabLabel => 'Bidhaa Zote';

  @override
  String get lowStockTabLabel => 'Hisa Chini';

  @override
  String get transactionsTabLabel => 'Miamala';

  @override
  String get noProductsAvailableMessage => 'Hakuna bidhaa zinazopatikana.';

  @override
  String get noLowStockProductsMessage => 'Hakuna bidhaa zenye hisa chini.';

  @override
  String get noTransactionsAvailableMessage => 'Hakuna miamala inayopatikana.';

  @override
  String get searchProductDialogTitle => 'Tafuta Bidhaa';

  @override
  String get searchProductHintText => 'Ingiza jina la bidhaa au msimbo pau...';

  @override
  String get cancelButtonLabel => 'Ghairi';

  @override
  String get searchButtonLabel => 'Tafuta';

  @override
  String get filterByCategoryDialogTitle => 'Chuja kwa Kategoria';

  @override
  String get noCategoriesAvailableMessage =>
      'Hakuna kategoria zinazopatikana za kuchuja.';

  @override
  String get showAllButtonLabel => 'Onyesha Zote';

  @override
  String get noProductsInInventoryMessage =>
      'Bado hujaongeza bidhaa zozote kwenye mali yako.';

  @override
  String get priceLabel => 'Bei';

  @override
  String get inputPriceLabel => 'Bei ya Kuingiza';

  @override
  String get stockLabel => 'Hisa';

  @override
  String get unknownProductLabel => 'Bidhaa Isiyojulikana';

  @override
  String get quantityLabel => 'Kiasi';

  @override
  String get dateLabel => 'Tarehe';

  @override
  String get valueLabel => 'Thamani';

  @override
  String get retryButtonLabel => 'Jaribu Tena';

  @override
  String get stockTransactionTypePurchase => 'Ununuzi';

  @override
  String get stockTransactionTypeSale => 'Uuzaji';

  @override
  String get stockTransactionTypeAdjustment => 'Marekebisho';

  @override
  String get salesScreenTitle => 'Usimamizi wa Mauzo';

  @override
  String get salesTabAll => 'Zote';

  @override
  String get salesTabPending => 'Inasubiri';

  @override
  String get salesTabCompleted => 'Imekamilika';

  @override
  String get salesFilterDialogTitle => 'Chuja Mauzo';

  @override
  String get salesFilterDialogCancel => 'Ghairi';

  @override
  String get salesFilterDialogApply => 'Tumia';

  @override
  String get salesSummaryTotal => 'Jumla ya Mauzo';

  @override
  String get salesSummaryCount => 'Idadi ya Mauzo';

  @override
  String get salesStatusPending => 'Inasubiri';

  @override
  String get salesStatusCompleted => 'Imekamilika';

  @override
  String get salesStatusPartiallyPaid => 'Imelipwa Kiasi';

  @override
  String get salesStatusCancelled => 'Imeghairiwa';

  @override
  String get salesNoSalesFound => 'Hakuna mauzo yaliyopatikana';

  @override
  String get salesAddSaleButton => 'Ongeza Mauzo';

  @override
  String get salesErrorPrefix => 'Hitilafu';

  @override
  String get salesRetryButton => 'Jaribu Tena';

  @override
  String get salesFilterDialogStartDate => 'Tarehe ya Kuanza';

  @override
  String get salesFilterDialogEndDate => 'Tarehe ya Mwisho';

  @override
  String get salesListItemSaleIdPrefix => 'Mauzo #';

  @override
  String salesListItemArticles(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count bidhaa',
      one: 'bidhaa 1',
    );
    return '$_temp0';
  }

  @override
  String get salesListItemTotal => 'Jumla:';

  @override
  String get salesListItemRemainingToPay => 'Kiasi Kilichobaki Kulipa:';

  @override
  String get subscriptionScreenTitle => 'Usimamizi wa Usajili';

  @override
  String get subscriptionUnsupportedFileType =>
      'Aina ya faili haitumiki. Tafadhali chagua faili ya JPG au PNG.';

  @override
  String get subscriptionFileTooLarge =>
      'Faili ni kubwa mno. Ukubwa wa juu ni 5MB.';

  @override
  String get subscriptionNoImageSelected => 'Hakuna picha iliyochaguliwa.';

  @override
  String get subscriptionUpdateSuccessMessage =>
      'Usajili umesasishwa kikamilifu.';

  @override
  String subscriptionUpdateFailureMessage(String error) {
    return 'Imeshindwa kusasisha usajili: $error';
  }

  @override
  String get subscriptionTokenTopUpSuccessMessage =>
      'Tokeni zimeongezwa kikamilifu.';

  @override
  String subscriptionTokenTopUpFailureMessage(String error) {
    return 'Imeshindwa kuongeza tokeni: $error';
  }

  @override
  String get subscriptionPaymentProofUploadSuccessMessage =>
      'Uthibitisho wa malipo umepakiwa kikamilifu.';

  @override
  String subscriptionPaymentProofUploadFailureMessage(String error) {
    return 'Imeshindwa kupakia uthibitisho wa malipo: $error';
  }

  @override
  String get subscriptionRetryButton => 'Jaribu Tena';

  @override
  String get subscriptionUnhandledState =>
      'Hali isiyoshughulikiwa au uanzishaji...';

  @override
  String get subscriptionSectionOurOffers => 'Matoleo Yetu ya Usajili';

  @override
  String get subscriptionSectionCurrentSubscription => 'Usajili Wako wa Sasa';

  @override
  String get subscriptionSectionTokenUsage => 'Matumizi ya Tokeni za Adha';

  @override
  String get subscriptionSectionInvoiceHistory => 'Historia ya Ankara';

  @override
  String get subscriptionSectionPaymentMethods => 'Njia za Malipo';

  @override
  String get subscriptionChangeSubscriptionButton => 'Badilisha Usajili';

  @override
  String get subscriptionTierFree => 'Bure';

  @override
  String subscriptionTierUsers(int count) {
    return 'Watumiaji: $count';
  }

  @override
  String subscriptionTierAdhaTokens(int count) {
    return 'Tokeni za Adha: $count';
  }

  @override
  String get subscriptionTierFeatures => 'Vipengele:';

  @override
  String get subscriptionTierCurrentPlanChip => 'Mpango wa Sasa';

  @override
  String get subscriptionTierChoosePlanButton => 'Chagua mpango huu';

  @override
  String subscriptionCurrentPlanTitle(String tierName) {
    return 'Mpango wa Sasa: $tierName';
  }

  @override
  String subscriptionCurrentPlanPrice(String price) {
    return 'Bei: $price';
  }

  @override
  String subscriptionAvailableAdhaTokens(int count) {
    return 'Tokeni za Adha Zinazopatikana: $count';
  }

  @override
  String get subscriptionTopUpTokensButton => 'Ongeza Tokeni';

  @override
  String get subscriptionNoInvoices => 'Hakuna ankara zinazopatikana kwa sasa.';

  @override
  String subscriptionInvoiceListTitle(String id, String date) {
    return 'Ankara $id - $date';
  }

  @override
  String subscriptionInvoiceListSubtitle(String amount, String status) {
    return 'Kiasi: $amount - Hali: $status';
  }

  @override
  String get subscriptionDownloadInvoiceTooltip => 'Pakua ankara';

  @override
  String subscriptionSimulateDownloadInvoice(String id, String url) {
    return 'Uigaji: Inapakua $id kutoka $url';
  }

  @override
  String subscriptionSimulateViewInvoiceDetails(String id) {
    return 'Uigaji: Tazama maelezo ya ankara $id';
  }

  @override
  String get subscriptionPaymentMethodsNextInvoice =>
      'Njia za malipo kwa ankara inayofuata:';

  @override
  String get subscriptionPaymentMethodsRegistered => 'Njia zilizosajiliwa:';

  @override
  String get subscriptionPaymentMethodsOtherOptions =>
      'Chaguo zingine za malipo:';

  @override
  String get subscriptionPaymentMethodNewCard => 'Kadi Mpya ya Mkopo';

  @override
  String get subscriptionPaymentMethodNewMobileMoney => 'Pesa Mpya ya Simu';

  @override
  String get subscriptionPaymentMethodManual =>
      'Malipo ya Mwongozo (Uhamisho/Amana)';

  @override
  String get subscriptionManualPaymentInstructions =>
      'Tafadhali fanya uhamisho/amana kwa maelezo yaliyotolewa na upakie uthibitisho wa malipo.';

  @override
  String subscriptionProofUploadedLabel(String fileName) {
    return 'Uthibitisho Umepakiwa: $fileName';
  }

  @override
  String get subscriptionUploadProofButton => 'Pakia Uthibitisho';

  @override
  String get subscriptionReplaceProofButton => 'Badilisha Uthibitisho';

  @override
  String get subscriptionConfirmPaymentMethodButton =>
      'Thibitisha Njia ya Malipo';

  @override
  String subscriptionSimulatePaymentMethodSelected(String method) {
    return 'Njia ya malipo iliyochaguliwa: $method (Uigaji)';
  }

  @override
  String get subscriptionChangeDialogTitle => 'Badilisha Usajili';

  @override
  String subscriptionChangeDialogTierSubtitle(String price, String tokens) {
    return '$price - Tokeni: $tokens';
  }

  @override
  String get subscriptionTopUpDialogTitle => 'Ongeza Tokeni za Adha';

  @override
  String subscriptionTopUpDialogAmount(String amount, String currencyCode) {
    return '$amount $currencyCode';
  }

  @override
  String get subscriptionNoActivePlan => 'Huna mpango wa usajili unaotumika.';

  @override
  String get contactsScreenTitle => 'Anwani';

  @override
  String get contactsScreenClientsTab => 'Wateja';

  @override
  String get contactsScreenSuppliersTab => 'Wauzaji';

  @override
  String get contactsScreenAddClientTooltip => 'Ongeza mteja';

  @override
  String get contactsScreenAddSupplierTooltip => 'Ongeza muuzaji';

  @override
  String get searchCustomerHint => 'Tafuta mteja...';

  @override
  String customerError(String message) {
    return 'Hitilafu: $message';
  }

  @override
  String get noCustomersToShow => 'Hakuna wateja wa kuonyesha';

  @override
  String get customersTitle => 'Wateja';

  @override
  String get filterCustomersTooltip => 'Chuja wateja';

  @override
  String get addCustomerTooltip => 'Ongeza mteja mpya';

  @override
  String noResultsForSearchTerm(String searchTerm) {
    return 'Hakuna matokeo ya $searchTerm';
  }

  @override
  String get noCustomersAvailable => 'Hakuna wateja wanaopatikana';

  @override
  String get topCustomersByPurchases => 'Wateja wakuu kwa ununuzi';

  @override
  String get recentlyAddedCustomers => 'Wateja walioongezwa hivi karibuni';

  @override
  String resultsForSearchTerm(String searchTerm) {
    return 'Matokeo ya $searchTerm';
  }

  @override
  String lastPurchaseDate(String date) {
    return 'Ununuzi wa mwisho: $date';
  }

  @override
  String get noRecentPurchase => 'Hakuna ununuzi wa hivi karibuni';

  @override
  String totalPurchasesAmount(String amount) {
    return 'Jumla ya ununuzi: $amount';
  }

  @override
  String get viewDetails => 'Tazama maelezo';

  @override
  String get edit => 'Hariri';

  @override
  String get allCustomers => 'Wateja wote';

  @override
  String get topCustomers => 'Wateja wakuu';

  @override
  String get recentCustomers => 'Wateja wa hivi karibuni';

  @override
  String get byCategory => 'Kwa Kategoria';

  @override
  String get filterByCategory => 'Chuja kwa kategoria';

  @override
  String get deleteCustomerTitle => 'Futa mteja';

  @override
  String deleteCustomerConfirmation(String customerName) {
    return 'Una uhakika unataka kumfuta $customerName? Kitendo hiki hakiwezi kutenduliwa.';
  }

  @override
  String get customerCategoryVip => 'VIP';

  @override
  String get customerCategoryRegular => 'Kawaida';

  @override
  String get customerCategoryNew => 'Mpya';

  @override
  String get customerCategoryOccasional => 'Wa Mara kwa Mara';

  @override
  String get customerCategoryBusiness => 'Biashara';

  @override
  String get customerCategoryUnknown => 'Haijulikani';

  @override
  String get editCustomerTitle => 'Hariri Mteja';

  @override
  String get addCustomerTitle => 'Ongeza Mteja';

  @override
  String get customerPhoneHint => '+243 999 123 456';

  @override
  String get customerInformation => 'Taarifa za Mteja';

  @override
  String get customerNameLabel => 'Jina la Mteja';

  @override
  String get customerNameValidationError => 'Tafadhali ingiza jina la mteja.';

  @override
  String get customerPhoneLabel => 'Simu ya Mteja';

  @override
  String get customerPhoneValidationError =>
      'Tafadhali ingiza nambari ya simu ya mteja.';

  @override
  String get customerEmailLabel => 'Barua Pepe ya Mteja (Si lazima)';

  @override
  String get customerEmailLabelOptional => 'Barua Pepe ya Mteja';

  @override
  String get customerEmailValidationError =>
      'Tafadhali ingiza anwani sahihi ya barua pepe.';

  @override
  String get customerAddressLabel => 'Anwani ya Mteja (Si lazima)';

  @override
  String get customerAddressLabelOptional => 'Anwani ya Mteja';

  @override
  String get customerCategoryLabel => 'Kategoria ya Mteja';

  @override
  String get customerNotesLabel => 'Maelezo (Si lazima)';

  @override
  String get updateButtonLabel => 'Sasisha';

  @override
  String get customerDetailsTitle => 'Maelezo ya Mteja';

  @override
  String get editCustomerTooltip => 'Hariri mteja';

  @override
  String get customerNotFound => 'Mteja hajapatikana';

  @override
  String get contactInformationSectionTitle => 'Taarifa za Mawasiliano';

  @override
  String get purchaseStatisticsSectionTitle => 'Takwimu za Ununuzi';

  @override
  String get totalPurchasesLabel => 'Jumla ya Ununuzi';

  @override
  String get lastPurchaseLabel => 'Ununuzi wa Mwisho';

  @override
  String get noPurchaseRecorded => 'Hakuna ununuzi uliorekodiwa';

  @override
  String get customerSinceLabel => 'Mteja Tangu';

  @override
  String get addSaleButtonLabel => 'Ongeza Mauzo';

  @override
  String get callButtonLabel => 'Piga Simu';

  @override
  String get deleteButtonLabel => 'Futa';

  @override
  String callingNumber(String phoneNumber) {
    return 'Inapiga $phoneNumber...';
  }

  @override
  String emailingTo(String email) {
    return 'Inatuma barua pepe kwa $email...';
  }

  @override
  String openingMapFor(String address) {
    return 'Inafungua ramani ya $address...';
  }

  @override
  String get searchSupplierHint => 'Tafuta muuzaji...';

  @override
  String get clearSearchTooltip => 'Futa utafutaji';

  @override
  String supplierError(String message) {
    return 'Hitilafu: $message';
  }

  @override
  String get noSuppliersToShow => 'Hakuna wauzaji wa kuonyesha';

  @override
  String get suppliersTitle => 'Wauzaji';

  @override
  String get filterSuppliersTooltip => 'Chuja wauzaji';

  @override
  String get addSupplierTooltip => 'Ongeza muuzaji mpya';

  @override
  String get noSuppliersAvailable => 'Hakuna wauzaji wanaopatikana';

  @override
  String get topSuppliersByPurchases => 'Wauzaji wakuu kwa ununuzi';

  @override
  String get recentlyAddedSuppliers => 'Wauzaji walioongezwa hivi karibuni';

  @override
  String contactPerson(String name) {
    return 'Mawasiliano: $name';
  }

  @override
  String get moreOptionsTooltip => 'Chaguo zaidi';

  @override
  String get allSuppliers => 'Wauzaji wote';

  @override
  String get topSuppliers => 'Wauzaji wakuu';

  @override
  String get recentSuppliers => 'Wauzaji wa hivi karibuni';

  @override
  String get deleteSupplierTitle => 'Futa muuzaji';

  @override
  String deleteSupplierConfirmation(String supplierName) {
    return 'Una uhakika unataka kumfuta $supplierName? Kitendo hiki hakiwezi kutenduliwa.';
  }

  @override
  String get supplierCategoryStrategic => 'Kimkakati';

  @override
  String get supplierCategoryRegular => 'Kawaida';

  @override
  String get supplierCategoryNew => 'Mpya';

  @override
  String get supplierCategoryOccasional => 'Wa Mara kwa Mara';

  @override
  String get supplierCategoryInternational => 'Kimataifa';

  @override
  String get supplierCategoryUnknown => 'Haijulikani';

  @override
  String get supplierCategoryLocal => 'Wa Ndani';

  @override
  String get supplierCategoryOnline => 'Mtandaoni';

  @override
  String get addSupplierTitle => 'Ongeza Muuzaji';

  @override
  String get editSupplierTitle => 'Hariri Muuzaji';

  @override
  String get supplierInformation => 'Taarifa za Muuzaji';

  @override
  String get supplierNameLabel => 'Jina la Muuzaji *';

  @override
  String get supplierNameValidationError => 'Jina linahitajika';

  @override
  String get supplierPhoneLabel => 'Nambari ya Simu *';

  @override
  String get supplierPhoneValidationError => 'Nambari ya simu inahitajika';

  @override
  String get supplierPhoneHint => '+243 999 123 456';

  @override
  String get supplierEmailLabel => 'Barua Pepe';

  @override
  String get supplierEmailValidationError =>
      'Tafadhali ingiza barua pepe sahihi';

  @override
  String get supplierContactPersonLabel => 'Mtu wa Kuwasiliana Naye';

  @override
  String get supplierAddressLabel => 'Anwani';

  @override
  String get commercialInformation => 'Taarifa za Kibiashara';

  @override
  String get deliveryTimeLabel => 'Muda wa Uwasilishaji';

  @override
  String get paymentTermsLabel => 'Masharti ya Malipo';

  @override
  String get paymentTermsHint => 'Mfano: Siku 30, 50% mwanzo, n.k.';

  @override
  String get supplierCategoryLabel => 'Kategoria ya Muuzaji';

  @override
  String get supplierNotesLabel => 'Maelezo';

  @override
  String get updateSupplierButton => 'Sasisha';

  @override
  String get addSupplierButton => 'Ongeza';

  @override
  String get supplierDetailsTitle => 'Maelezo ya Muuzaji';

  @override
  String supplierErrorLoading(String message) {
    return 'Hitilafu: $message';
  }

  @override
  String get supplierNotFound => 'Muuzaji hajapatikana';

  @override
  String get contactLabel => 'Mawasiliano';

  @override
  String get phoneLabel => 'Simu';

  @override
  String get emailLabel => 'Barua Pepe';

  @override
  String get addressLabel => 'Anwani';

  @override
  String get commercialInformationSectionTitle => 'Taarifa za Kibiashara';

  @override
  String deliveryTimeInDays(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count siku',
      one: 'siku 1',
      zero: 'Haijabainishwa',
    );
    return '$_temp0';
  }

  @override
  String get supplierSinceLabel => 'Muuzaji Tangu';

  @override
  String get notesSectionTitle => 'Maelezo';

  @override
  String get placeOrderButtonLabel => 'Weka Oda';

  @override
  String get featureToImplement => 'Kipengele cha kutekeleza';

  @override
  String get confirmDeleteSupplierTitle => 'Futa Muuzaji';

  @override
  String confirmDeleteSupplierMessage(String supplierName) {
    return 'Una uhakika unataka kumfuta $supplierName? Kitendo hiki hakiwezi kutenduliwa.';
  }

  @override
  String get commonConfirm => 'Thibitisha';

  @override
  String get commonError => 'Hitilafu';

  @override
  String get commonToday => 'Leo';

  @override
  String get commonThisMonth => 'Mwezi Huu';

  @override
  String get commonThisYear => 'Mwaka Huu';

  @override
  String get commonCustom => 'Maalum';

  @override
  String get commonAnonymousClient => 'Mteja Asiyejulikana';

  @override
  String get commonAnonymousClientInitial => 'A';

  @override
  String get commonErrorDataUnavailable => 'Data haipatikani';

  @override
  String get commonNoData => 'Hakuna data inayopatikana';

  @override
  String get dashboardScreenTitle => 'Dashibodi';

  @override
  String get dashboardHeaderSalesToday => 'Mauzo ya Leo';

  @override
  String get dashboardHeaderClientsServed => 'Wateja Waliohudumiwa';

  @override
  String get dashboardHeaderReceivables => 'Madeni Yanayodaiwa';

  @override
  String get dashboardHeaderTransactions => 'Miamala';

  @override
  String get dashboardCardViewDetails => 'Tazama Maelezo';

  @override
  String get dashboardSalesChartTitle => 'Muhtasari wa Mauzo';

  @override
  String get dashboardSalesChartNoData =>
      'Hakuna data ya mauzo ya kuonyesha kwenye chati.';

  @override
  String get dashboardRecentSalesTitle => 'Mauzo ya Hivi Karibuni';

  @override
  String get dashboardRecentSalesViewAll => 'Tazama Yote';

  @override
  String get dashboardRecentSalesNoData => 'Hakuna mauzo ya hivi karibuni.';

  @override
  String get dashboardOperationsJournalTitle => 'Jarida la Uendeshaji';

  @override
  String get dashboardOperationsJournalViewAll => 'Tazama Yote';

  @override
  String get dashboardOperationsJournalNoData =>
      'Hakuna shughuli za hivi karibuni.';

  @override
  String get dashboardOperationsJournalBalanceLabel => 'Salio';

  @override
  String get dashboardJournalExportSelectDateRangeTitle =>
      'Chagua Kipindi cha Tarehe';

  @override
  String get dashboardJournalExportExportButton => 'Hamisha kwa PDF';

  @override
  String get dashboardJournalExportPrintButton => 'Chapisha Jarida';

  @override
  String get dashboardJournalExportSuccessMessage =>
      'Jarida limehamishwa kikamilifu.';

  @override
  String get dashboardJournalExportFailureMessage =>
      'Imeshindwa kuhamisha jarida.';

  @override
  String get dashboardJournalExportNoDataForPeriod =>
      'Hakuna data inayopatikana kwa kipindi kilichochaguliwa ili kuhamisha.';

  @override
  String get dashboardJournalExportPrintingMessage =>
      'Inaandaa jarida kwa uchapishaji...';

  @override
  String get dashboardQuickActionsTitle => 'Vitendo vya Haraka';

  @override
  String get dashboardQuickActionsNewSale => 'Mauzo Mapya';

  @override
  String get dashboardQuickActionsNewExpense => 'Gharama Mpya';

  @override
  String get dashboardQuickActionsNewProduct => 'Bidhaa Mpya';

  @override
  String get dashboardQuickActionsNewService => 'Huduma Mpya';

  @override
  String get dashboardQuickActionsNewClient => 'Mteja Mpya';

  @override
  String get dashboardQuickActionsNewSupplier => 'Muuzaji Mpya';

  @override
  String get dashboardQuickActionsCashRegister => 'Rejista ya Pesa';

  @override
  String get dashboardQuickActionsSettings => 'Mipangilio';

  @override
  String get dashboardQuickActionsNewInvoice => 'Ankara';

  @override
  String get dashboardQuickActionsNewFinancing => 'Ufadhili';

  @override
  String get commonLoading => 'Inapakia...';

  @override
  String get cancel => 'Ghairi';

  @override
  String get journalPdf_title => 'Jarida la Uendeshaji';

  @override
  String journalPdf_footer_pageInfo(int currentPage, int totalPages) {
    return 'Ukurasa $currentPage kati ya $totalPages';
  }

  @override
  String journalPdf_period(String startDate, String endDate) {
    return 'Kipindi: $startDate - $endDate';
  }

  @override
  String get journalPdf_tableHeader_date => 'Tarehe';

  @override
  String get journalPdf_tableHeader_time => 'Wakati';

  @override
  String get journalPdf_tableHeader_description => 'Maelezo';

  @override
  String get journalPdf_tableHeader_debit => 'Debiti';

  @override
  String get journalPdf_tableHeader_credit => 'Krediti';

  @override
  String get journalPdf_tableHeader_balance => 'Salio';

  @override
  String get journalPdf_openingBalance => 'Salio la Kuanzia';

  @override
  String get journalPdf_closingBalance => 'Salio la Kufunga';

  @override
  String get journalPdf_footer_generatedBy => 'Imetolewa na Wanzo';

  @override
  String get adhaHomePageTitle => 'Adha - Msaidizi wa AI';

  @override
  String get adhaHomePageDescription =>
      'Adha, msaidizi wako mahiri wa biashara';

  @override
  String get adhaHomePageBody =>
      'Niulize maswali kuhusu biashara yako na nitakusaidia kufanya maamuzi bora kwa uchambuzi na ushauri wa kibinafsi.';

  @override
  String get startConversationButton => 'Anzisha mazungumzo';

  @override
  String get viewConversationsButton => 'Tazama mazungumzo yangu';

  @override
  String get salesAnalysisFeatureTitle => 'Uchambuzi wa Mauzo';

  @override
  String get salesAnalysisFeatureDescription =>
      'Pata maarifa kuhusu utendaji wako wa mauzo';

  @override
  String get inventoryManagementFeatureTitle => 'Usimamizi wa Mali';

  @override
  String get inventoryManagementFeatureDescription =>
      'Fuatilia na uboreshe mali yako';

  @override
  String get customerRelationsFeatureTitle => 'Mahusiano na Wateja';

  @override
  String get customerRelationsFeatureDescription =>
      'Ushauri wa kuwahifadhi wateja wako';

  @override
  String get financialCalculationsFeatureTitle => 'Mahesabu ya Kifedha';

  @override
  String get financialCalculationsFeatureDescription =>
      'Makadirio na uchambuzi wa kifedha';

  @override
  String get loginButton => 'Ingia';

  @override
  String get registerButton => 'Jisajili';

  @override
  String get emailHint => 'Ingiza barua pepe yako';

  @override
  String get emailValidationErrorRequired => 'Tafadhali ingiza barua pepe yako';

  @override
  String get emailValidationErrorInvalid =>
      'Tafadhali ingiza barua pepe sahihi';

  @override
  String get passwordLabel => 'Nenosiri';

  @override
  String get passwordHint => 'Ingiza nenosiri lako';

  @override
  String get passwordValidationErrorRequired =>
      'Tafadhali ingiza nenosiri lako';

  @override
  String authFailureMessage(Object message) {
    return 'Uthibitishaji umeshindwa: $message';
  }

  @override
  String get loginToYourAccount => 'Ingia kwenye akaunti yako';

  @override
  String get rememberMeLabel => 'Nikumbuke';

  @override
  String get forgotPasswordButton => 'Umesahau nenosiri?';

  @override
  String get noAccountPrompt => 'Huna akaunti?';

  @override
  String get createAccountButton => 'Fungua akaunti';

  @override
  String get demoModeButton => 'Hali ya Onyesho';

  @override
  String get settings => 'Mipangilio';

  @override
  String get settingsTitle => 'Mipangilio';

  @override
  String get settingsDescription => 'Dhibiti mipangilio ya programu yako.';

  @override
  String get wanzoFallbackText => 'Maandishi Mbadala ya Wanzo';

  @override
  String get appVersion => 'Toleo la Programu';

  @override
  String get loadingSettings => 'Inapakia mipangilio...';

  @override
  String get companyInformation => 'Taarifa za Kampuni';

  @override
  String get companyInformationSubtitle => 'Dhibiti maelezo ya kampuni yako';

  @override
  String get appearanceAndDisplay => 'Muonekano na Onyesho';

  @override
  String get appearanceAndDisplaySubtitle => 'Binafsisha mwonekano na hisia';

  @override
  String get theme => 'Mandhari';

  @override
  String get themeLight => 'Nuru';

  @override
  String get themeDark => 'Giza';

  @override
  String get themeSystem => 'Mfumo';

  @override
  String get language => 'Lugha';

  @override
  String get languageEnglish => 'Kiingereza';

  @override
  String get languageFrench => 'Kifaransa';

  @override
  String get languageSwahili => 'Kiswahili';

  @override
  String get dateFormat => 'Umbizo la Tarehe';

  @override
  String get dateFormatDDMMYYYY => 'DD/MM/YYYY';

  @override
  String get dateFormatMMDDYYYY => 'MM/DD/YYYY';

  @override
  String get dateFormatYYYYMMDD => 'YYYY/MM/DD';

  @override
  String get dateFormatDDMMMYYYY => 'DD MMM YYYY';

  @override
  String get monthJan => 'Januari';

  @override
  String get monthFeb => 'Februari';

  @override
  String get monthMar => 'Machi';

  @override
  String get monthApr => 'Aprili';

  @override
  String get monthMay => 'Mei';

  @override
  String get monthJun => 'Juni';

  @override
  String get monthJul => 'Julai';

  @override
  String get monthAug => 'Agosti';

  @override
  String get monthSep => 'Septemba';

  @override
  String get monthOct => 'Oktoba';

  @override
  String get monthNov => 'Novemba';

  @override
  String get monthDec => 'Desemba';

  @override
  String get changeLogo => 'Badilisha Nembo';

  @override
  String get companyName => 'Jina la Kampuni';

  @override
  String get companyNameRequired => 'Jina la kampuni linahitajika';

  @override
  String get email => 'Barua Pepe';

  @override
  String get invalidEmail => 'Anwani ya barua pepe si sahihi';

  @override
  String get phoneNumber => 'Nambari ya Simu';

  @override
  String get address => 'Anwani';

  @override
  String get rccm => 'RCCM';

  @override
  String get rccmHelperText => 'Rejista ya Biashara na Mikopo ya Mali Binafsi';

  @override
  String get taxId => 'Namba ya Utambulisho wa Mlipakodi (NIM)';

  @override
  String get taxIdHelperText =>
      'Nambari ya Utambulisho wa Mlipakodi ya Kitaifa';

  @override
  String get website => 'Tovuti';

  @override
  String get invoiceSettings => 'Mipangilio ya Ankara';

  @override
  String get invoiceSettingsSubtitle => 'Dhibiti mapendeleo yako ya ankara';

  @override
  String get defaultInvoiceFooter => 'Kijachini Chaguo-msingi cha Ankara';

  @override
  String get defaultInvoiceFooterHint => 'k.m., Asante kwa biashara yako!';

  @override
  String get showTotalInWords => 'Onyesha Jumla kwa Maneno';

  @override
  String get exchangeRate =>
      'Kiwango cha Ubadilishaji (USD kwenda Sarafu ya Ndani)';

  @override
  String get inventorySettings => 'Mipangilio ya Mali';

  @override
  String get inventorySettingsSubtitle => 'Dhibiti mapendeleo yako ya mali';

  @override
  String get generalSettings => 'Mipangilio ya Jumla';

  @override
  String get defaultCategory => 'Kategoria Chaguo-msingi';

  @override
  String get defaultCategoryRequired => 'Kategoria chaguo-msingi inahitajika';

  @override
  String get lowStockAlert => 'Tahadhari ya Hisa Chini';

  @override
  String get lowStockAlertHint => 'Kiasi ambacho tahadhari itatolewa';

  @override
  String get trackInventory => 'Fuatilia Mali';

  @override
  String get allowNegativeStock => 'Ruhusu Hisa Hasi';

  @override
  String get saveChanges => 'Hifadhi Mabadiliko';

  @override
  String get settingsUpdatedSuccessfully => 'Mipangilio imesasishwa kikamilifu';

  @override
  String get errorUpdatingSettings => 'Hitilafu kusasisha mipangilio';

  @override
  String get changesSaved => 'Mabadiliko yamehifadhiwa kikamilifu!';

  @override
  String get errorSavingChanges => 'Hitilafu kuhifadhi mabadiliko';

  @override
  String get selectTheme => 'Chagua Mandhari';

  @override
  String get selectLanguage => 'Chagua Lugha';

  @override
  String get selectDateFormat => 'Chagua Umbizo la Tarehe';

  @override
  String get displaySettings => 'Mipangilio ya Onyesho';

  @override
  String get displaySettingsDescription => 'Dhibiti mipangilio ya onyesho.';

  @override
  String get companySettings => 'Mipangilio ya Kampuni';

  @override
  String get companySettingsDescription => 'Dhibiti mipangilio ya kampuni.';

  @override
  String get invoiceSettingsDescription => 'Dhibiti mipangilio ya ankara.';

  @override
  String get inventorySettingsDescription => 'Dhibiti mipangilio ya mali.';

  @override
  String minValue(double minValue) {
    return 'Thamani ya chini: $minValue';
  }

  @override
  String maxValue(double maxValue) {
    return 'Thamani ya juu: $maxValue';
  }

  @override
  String get valueMustBeNumber => 'Thamani lazima iwe nambari';

  @override
  String get valueMustBePositive => 'Thamani lazima iwe chanya';

  @override
  String get fieldRequired => 'Sehemu hii inahitajika';

  @override
  String get settingsGeneral => 'Jumla';

  @override
  String get settingsCompany => 'Kampuni';

  @override
  String get settingsInvoice => 'Ankara';

  @override
  String get settingsInventory => 'Mali';

  @override
  String get settingsAppearance => 'Muonekano';

  @override
  String get searchSettings => 'Tafuta mipangilio...';

  @override
  String get backupAndReports => 'Nakala na Ripoti';

  @override
  String get backupAndReportsSubtitle => 'Dhibiti nakala ya data na toa ripoti';

  @override
  String get notifications => 'Arifa';

  @override
  String get notificationsSubtitle => 'Dhibiti arifa za programu';

  @override
  String get resetSettings => 'Weka Upya Mipangilio';

  @override
  String get confirmResetSettings =>
      'Una uhakika unataka kuweka upya mipangilio yote kuwa chaguomsingi? Kitendo hiki hakiwezi kutenduliwa.';

  @override
  String get reset => 'Weka Upya';

  @override
  String get taxIdentificationNumber => 'Nambari ya Utambulisho wa Mlipakodi';

  @override
  String get rccmNumber => 'Nambari ya RCCM';

  @override
  String get idNatNumber => 'Nambari ya Kitambulisho cha Taifa';

  @override
  String get idNatHelperText => 'Nambari ya Utambulisho wa Kitaifa';

  @override
  String get selectImageSource => 'Chagua Chanzo cha Picha';

  @override
  String get gallery => 'Matunzio';

  @override
  String get camera => 'Kamera';

  @override
  String get deleteCurrentLogo => 'Futa Nembo ya Sasa';

  @override
  String get logoDeleted => 'Nembo imefutwa.';

  @override
  String get logoUpdatedSuccessfully => 'Nembo imesasishwa kikamilifu.';

  @override
  String errorSelectingLogo(String errorDetails) {
    return 'Hitilafu kuchagua nembo: $errorDetails';
  }

  @override
  String get defaultProductCategory => 'Kategoria Chaguo-msingi ya Bidhaa';

  @override
  String get stockAlerts => 'Tahadhari za Hisa';

  @override
  String get lowStockAlertDays => 'Siku za Tahadhari ya Hisa Chini';

  @override
  String get days => 'Siku';

  @override
  String get enterValidNumber => 'Tafadhali ingiza nambari sahihi.';

  @override
  String get lowStockAlertDescription =>
      'Pokea tahadhari wakati hisa ya bidhaa iko chini kwa idadi maalum ya siku.';

  @override
  String get productCategories => 'Kategoria za Bidhaa';

  @override
  String get manageYourProductCategories => 'Dhibiti kategoria zako za bidhaa.';

  @override
  String get addCategory => 'Ongeza Kategoria';

  @override
  String get editCategory => 'Hariri Kategoria';

  @override
  String get deleteCategory => 'Futa Kategoria';

  @override
  String get categoryName => 'Jina la Kategoria';

  @override
  String get categoryNameCannotBeEmpty =>
      'Jina la kategoria haliwezi kuwa tupu.';

  @override
  String get categoryAdded => 'Kategoria imeongezwa';

  @override
  String get categoryUpdated => 'Kategoria imesasishwa';

  @override
  String get categoryDeleted => 'Kategoria imefutwa';

  @override
  String get confirmDeleteCategory =>
      'Una uhakika unataka kufuta kategoria hii?';

  @override
  String get deleteCategoryMessage => 'Kitendo hiki hakiwezi kutenduliwa.';

  @override
  String errorAddingCategory(Object error) {
    return 'Hitilafu kuongeza kategoria: $error';
  }

  @override
  String errorUpdatingCategory(Object error) {
    return 'Hitilafu kusasisha kategoria: $error';
  }

  @override
  String errorDeletingCategory(Object error) {
    return 'Hitilafu kufuta kategoria: $error';
  }

  @override
  String errorFetchingCategories(Object error) {
    return 'Hitilafu kupata kategoria: $error';
  }

  @override
  String get noCategoriesFound =>
      'Hakuna kategoria zilizopatikana. Ongeza moja ili kuanza!';

  @override
  String get signupScreenTitle => 'Fungua Akaunti ya Biashara';

  @override
  String get signupStepIdentity => 'Utambulisho';

  @override
  String get signupStepCompany => 'Kampuni';

  @override
  String get signupStepConfirmation => 'Uthibitisho';

  @override
  String get signupPersonalInfoTitle => 'Taarifa Zako Binafsi';

  @override
  String get signupOwnerNameLabel => 'Jina Kamili la Mmiliki';

  @override
  String get signupOwnerNameHint => 'Ingiza jina lako kamili';

  @override
  String get signupOwnerNameValidation => 'Tafadhali ingiza jina la mmiliki';

  @override
  String get signupEmailLabel => 'Anwani ya Barua Pepe';

  @override
  String get signupEmailHint => 'Ingiza anwani yako ya barua pepe';

  @override
  String get signupEmailValidationRequired =>
      'Tafadhali ingiza barua pepe yako';

  @override
  String get signupEmailValidationInvalid =>
      'Tafadhali ingiza barua pepe sahihi';

  @override
  String get signupPhoneLabel => 'Nambari ya Simu';

  @override
  String get signupPhoneHint => 'Ingiza nambari yako ya simu';

  @override
  String get signupPhoneValidation => 'Tafadhali ingiza nambari yako ya simu';

  @override
  String get signupPasswordLabel => 'Nenosiri';

  @override
  String get signupPasswordHint => 'Ingiza nenosiri lako (angalau herufi 8)';

  @override
  String get signupPasswordValidationRequired => 'Tafadhali ingiza nenosiri';

  @override
  String get signupPasswordValidationLength =>
      'Nenosiri lazima liwe na angalau herufi 8';

  @override
  String get signupConfirmPasswordLabel => 'Thibitisha Nenosiri';

  @override
  String get signupConfirmPasswordHint => 'Thibitisha nenosiri lako';

  @override
  String get signupConfirmPasswordValidationRequired =>
      'Tafadhali thibitisha nenosiri lako';

  @override
  String get signupConfirmPasswordValidationMatch => 'Manenosiri hayafanani';

  @override
  String get signupRequiredFields => '* Sehemu zinazohitajika';

  @override
  String get signupCompanyInfoTitle => 'Taarifa za Kampuni Yako';

  @override
  String get signupCompanyNameLabel => 'Jina la Kampuni';

  @override
  String get signupCompanyNameHint => 'Ingiza jina la kampuni yako';

  @override
  String get signupCompanyNameValidation => 'Tafadhali ingiza jina la kampuni';

  @override
  String get signupRccmLabel => 'Nambari ya RCCM / Usajili wa Biashara';

  @override
  String get signupRccmHint => 'Ingiza nambari yako ya RCCM au sawa';

  @override
  String get signupRccmValidation => 'Tafadhali ingiza nambari ya RCCM';

  @override
  String get signupAddressLabel => 'Anwani / Mahali';

  @override
  String get signupAddressHint => 'Ingiza anwani ya kampuni yako';

  @override
  String get signupAddressValidation =>
      'Tafadhali ingiza anwani ya kampuni yako';

  @override
  String get signupActivitySectorLabel => 'Sekta ya Biashara';

  @override
  String get signupTermsAndConditionsTitle => 'Muhtasari na Masharti';

  @override
  String get signupInfoSummaryPersonal => 'Taarifa Binafsi:';

  @override
  String get signupInfoSummaryName => 'Jina:';

  @override
  String get signupInfoSummaryEmail => 'Barua Pepe:';

  @override
  String get signupInfoSummaryPhone => 'Simu:';

  @override
  String get signupInfoSummaryCompany => 'Taarifa za Kampuni:';

  @override
  String get signupInfoSummaryCompanyName => 'Jina la Kampuni:';

  @override
  String get signupInfoSummaryRccm => 'RCCM:';

  @override
  String get signupInfoSummaryAddress => 'Anwani:';

  @override
  String get signupInfoSummaryActivitySector => 'Sekta ya Shughuli:';

  @override
  String get signupAgreeToTerms => 'Nimesoma na kukubaliana na';

  @override
  String get signupTermsOfUse => 'Masharti ya Matumizi';

  @override
  String get andConnector => 'na';

  @override
  String get signupPrivacyPolicy => 'Sera ya Faragha';

  @override
  String get signupAgreeToTermsConfirmation =>
      'Kwa kuweka tiki hapa, unathibitisha kuwa umesoma, umeelewa, na umekubali masharti yetu ya huduma na sera ya faragha.';

  @override
  String get signupButtonPrevious => 'Nyuma';

  @override
  String get signupButtonNext => 'Mbele';

  @override
  String get signupButtonRegister => 'Jisajili';

  @override
  String get signupAlreadyHaveAccount => 'Tayari una akaunti? Ingia';

  @override
  String get signupErrorFillFields =>
      'Tafadhali jaza sehemu zote zinazohitajika kwa usahihi kwa hatua ya sasa.';

  @override
  String get signupErrorAgreeToTerms =>
      'Lazima ukubaliane na masharti na kanuni ili kujisajili.';

  @override
  String get signupSuccessMessage => 'Usajili umefanikiwa! Tunakuingiza...';

  @override
  String signupErrorRegistration(String error) {
    return 'Usajili umeshindwa: $error';
  }

  @override
  String get sectorAgricultureName => 'Kilimo na Chakula';

  @override
  String get sectorAgricultureDescription =>
      'Uzalishaji wa kilimo, usindikaji wa chakula, mifugo';

  @override
  String get sectorCommerceName => 'Biashara na Usambazaji';

  @override
  String get sectorCommerceDescription =>
      'Rejareja, usambazaji, uagizaji-usafirishaji';

  @override
  String get sectorServicesName => 'Huduma';

  @override
  String get sectorServicesDescription => 'Huduma za biashara na binafsi';

  @override
  String get sectorTechnologyName => 'Teknolojia na Ubunifu';

  @override
  String get sectorTechnologyDescription =>
      'Uendelezaji wa programu, mawasiliano, teknolojia ya kifedha';

  @override
  String get sectorManufacturingName => 'Utengenezaji na Viwanda';

  @override
  String get sectorManufacturingDescription =>
      'Uzalishaji wa viwandani, ufundi, nguo';

  @override
  String get sectorConstructionName => 'Ujenzi na Mali isiyohamishika';

  @override
  String get sectorConstructionDescription =>
      'Ujenzi, uendelezaji wa mali isiyohamishika, usanifu majengo';

  @override
  String get sectorTransportationName => 'Usafiri na Usafirishaji';

  @override
  String get sectorTransportationDescription =>
      'Usafirishaji wa mizigo, usafirishaji, uhifadhi';

  @override
  String get sectorEnergyName => 'Nishati na Maliasili';

  @override
  String get sectorEnergyDescription =>
      'Uzalishaji wa nishati, uchimbaji madini, maji';

  @override
  String get sectorTourismName => 'Utalii na Ukarimu';

  @override
  String get sectorTourismDescription => 'Hoteli, migahawa, utalii';

  @override
  String get sectorEducationName => 'Elimu na Mafunzo';

  @override
  String get sectorEducationDescription => 'Ufundishaji, mafunzo ya ufundi';

  @override
  String get sectorHealthName => 'Afya na Huduma za Matibabu';

  @override
  String get sectorHealthDescription =>
      'Huduma za matibabu, duka la dawa, vifaa vya matibabu';

  @override
  String get sectorFinanceName => 'Huduma za Kifedha';

  @override
  String get sectorFinanceDescription => 'Benki, bima, fedha ndogo';

  @override
  String get sectorOtherName => 'Nyingine';

  @override
  String get sectorOtherDescription => 'Sekta zingine za biashara';

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

  @override
  String get sidebarRevenues => 'Revenues';

  @override
  String get sidebarCharges => 'Expenses';

  @override
  String get chartTitleAccountingView => 'Business Activity';

  @override
  String get chartTitleCashFlowView => 'Cash Flow';

  @override
  String get chartLegendRevenues => 'Revenues (Turnover)';

  @override
  String get chartLegendCharges => 'Expenses';

  @override
  String get chartLegendCashIn => 'Cash In';

  @override
  String get chartLegendCashOut => 'Cash Out';

  @override
  String get kpiTurnover => 'Turnover';

  @override
  String get kpiCashIn => 'Cash In';

  @override
  String get kpiCashOut => 'Cash Out';

  @override
  String get kpiReceivables => 'Receivables';

  @override
  String get kpiPayables => 'Payables';

  @override
  String get filterCashFlowOnly => 'Cash Flow';

  @override
  String get filterAccountingOnly => 'Accounting';

  @override
  String get paymentStatusPaid => 'Collected';

  @override
  String get paymentStatusPartial => 'Partial';

  @override
  String get paymentStatusPending => 'To Collect';

  @override
  String get expensePaymentStatusPaid => 'Disbursed';

  @override
  String get expensePaymentStatusPartial => 'Partial';

  @override
  String get expensePaymentStatusPending => 'To Disburse';

  @override
  String get documentTypeInvoice => 'Invoice';

  @override
  String get documentTypeReceipt => 'Cash Receipt';

  @override
  String get documentTypeCashVoucher => 'Cash Voucher';

  @override
  String get subscriptionQuotaExhaustedTitle =>
      'Kiwango cha tokeni kimemalizika';

  @override
  String get subscriptionExpiredTitle => 'Usajili umeisha';

  @override
  String get subscriptionPastDueTitle => 'Malipo yanasubiri';

  @override
  String get subscriptionFeatureNotAvailableTitle => 'Kipengele hakipatikani';

  @override
  String subscriptionGracePeriodRemaining(int days) {
    return 'Una siku $days zilizobaki kabla ya kusimamishwa kwa huduma.';
  }

  @override
  String get subscriptionRenewButton => 'Sasisha usajili wangu';

  @override
  String get subscriptionPayNowButton => 'Lipa sasa';

  @override
  String get subscriptionViewPlansButton => 'Tazama mipango inayopatikana';

  @override
  String get subscriptionNewConversationButton => 'Mazungumzo mapya';

  @override
  String get subscriptionContactSupport =>
      'Wasiliana na msaada ikiwa tatizo linaendelea.';
}
