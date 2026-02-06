// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for French (`fr`).
class AppLocalizationsFr extends AppLocalizations {
  AppLocalizationsFr([String locale = 'fr']) : super(locale);

  @override
  String get invoiceSettingsTitle => 'Paramètres de facturation';

  @override
  String get currencySettings => 'Paramètres de devise';

  @override
  String get activeCurrency => 'Devise active';

  @override
  String exchangeRateSpecific(String currencyFrom, String currencyTo) {
    return 'Taux de change ($currencyFrom vers $currencyTo)';
  }

  @override
  String exchangeRateHint(String currencyFrom, String currencyTo) {
    return 'ex: 650 pour 1 USD = 650 FCFA';
  }

  @override
  String get errorFieldRequired => 'Ce champ est requis.';

  @override
  String get errorInvalidRate => 'Veuillez entrer un taux positif valide.';

  @override
  String get invoiceFormatting => 'Formatage des factures';

  @override
  String invoiceFormatHint(Object YEAR, Object MONTH, Object SEQ) {
    return 'Utilisez $YEAR, $MONTH, $SEQ pour les valeurs dynamiques.';
  }

  @override
  String get invoiceNumberFormat => 'Format du numéro de facture';

  @override
  String get invoicePrefix => 'Préfixe de facture';

  @override
  String get taxesAndConditions => 'Taxes et conditions';

  @override
  String get showTaxesOnInvoices => 'Afficher les taxes sur les factures';

  @override
  String get defaultTaxRatePercentage => 'Taux de taxe par défaut (%)';

  @override
  String get errorInvalidTaxRate => 'Le taux de taxe doit être entre 0 et 100.';

  @override
  String get defaultPaymentTerms => 'Conditions de paiement par défaut';

  @override
  String get defaultInvoiceNotes => 'Notes de facture par défaut';

  @override
  String get settingsSavedSuccess => 'Paramètres enregistrés avec succès.';

  @override
  String get anErrorOccurred => 'Une erreur s\'est produite';

  @override
  String get errorUnknown => 'Erreur inconnue';

  @override
  String currencySettingsError(String errorDetails) {
    return 'Impossible d\'enregistrer les paramètres de devise : $errorDetails';
  }

  @override
  String get currencySettingsSavedSuccess =>
      'Paramètres de devise enregistrés avec succès.';

  @override
  String get currencyCDF => 'Franc Congolais';

  @override
  String get currencyUSD => 'Dollar Américain';

  @override
  String get currencyFCFA => 'Franc CFA';

  @override
  String get editProductTitle => 'Modifier le produit';

  @override
  String get addProductTitle => 'Ajouter un produit';

  @override
  String get productCategoryFood => 'Alimentation';

  @override
  String get productCategoryDrink => 'Boisson';

  @override
  String get productCategoryOther => 'Autre';

  @override
  String get units => 'Unités';

  @override
  String get notes => 'Notes (Facultatif)';

  @override
  String get saveProduct => 'Enregistrer le produit';

  @override
  String get inventoryValue => 'Valeur de l\'inventaire';

  @override
  String get products => 'Produits';

  @override
  String get stockMovements => 'Mouvements de stock';

  @override
  String get noProducts => 'Aucun produit pour le moment.';

  @override
  String get noStockMovements => 'Aucun mouvement de stock pour le moment.';

  @override
  String get searchProducts => 'Rechercher des produits...';

  @override
  String get totalStock => 'Stock total';

  @override
  String get valueInCdf => 'Valeur (CDF)';

  @override
  String valueIn(String currencyCode) {
    return 'Valeur ($currencyCode)';
  }

  @override
  String get lastModified => 'Dernière modification';

  @override
  String get productDetails => 'Détails du produit';

  @override
  String get deleteProduct => 'Supprimer le produit';

  @override
  String get confirmDeleteProductTitle => 'Confirmer la suppression';

  @override
  String get confirmDeleteProductMessage =>
      'Êtes-vous sûr de vouloir supprimer ce produit ? Cette action est irréversible.';

  @override
  String get commonCancel => 'Annuler';

  @override
  String get delete => 'Supprimer';

  @override
  String get stockIn => 'Entrée de stock';

  @override
  String get stockOut => 'Sortie de stock';

  @override
  String get adjustment => 'Ajustement';

  @override
  String get quantity => 'Quantité';

  @override
  String get reason => 'Raison (Facultatif)';

  @override
  String get addStockMovement => 'Ajouter un mouvement de stock';

  @override
  String get newStock => 'Nouveau stock';

  @override
  String get value => 'Valeur';

  @override
  String get type => 'Type';

  @override
  String get date => 'Date';

  @override
  String get product => 'Produit';

  @override
  String get selectProduct => 'Sélectionner un produit';

  @override
  String get selectCategory => 'Sélectionner une catégorie';

  @override
  String get selectUnit => 'Sélectionner une unité';

  @override
  String imagePickingErrorMessage(String errorDetails) {
    return 'Erreur lors de la sélection de l\'image : $errorDetails';
  }

  @override
  String get galleryAction => 'Galerie';

  @override
  String get cameraAction => 'Appareil photo';

  @override
  String get removeImageAction => 'Supprimer l\'image';

  @override
  String get productImageSectionTitle => 'Image du produit';

  @override
  String get addImageLabel => 'Ajouter une image';

  @override
  String get generalInformationSectionTitle => 'Informations générales';

  @override
  String get productNameLabel => 'Nom du produit';

  @override
  String get productNameValidationError => 'Veuillez saisir le nom du produit.';

  @override
  String get productDescriptionLabel => 'Description';

  @override
  String get productBarcodeLabel => 'Code-barres (Facultatif)';

  @override
  String get featureComingSoonMessage => 'Fonctionnalité bientôt disponible !';

  @override
  String get productCategoryLabel => 'Catégorie';

  @override
  String get productCategoryElectronics => 'Électronique';

  @override
  String get productCategoryClothing => 'Vêtements';

  @override
  String get productCategoryHousehold => 'Ménager';

  @override
  String get productCategoryHygiene => 'Hygiène';

  @override
  String get productCategoryOffice => 'Fournitures de bureau';

  @override
  String get pricingSectionTitle => 'Prix et Devise';

  @override
  String get inputCurrencyLabel => 'Devise de saisie';

  @override
  String get inputCurrencyValidationError =>
      'Veuillez sélectionner une devise de saisie.';

  @override
  String get costPriceLabel => 'Prix d\'achat';

  @override
  String get costPriceValidationError => 'Veuillez saisir le prix d\'achat.';

  @override
  String get negativePriceValidationError =>
      'Le prix ne peut pas être négatif.';

  @override
  String get invalidNumberValidationError =>
      'Veuillez saisir un nombre valide.';

  @override
  String get sellingPriceLabel => 'Prix de vente';

  @override
  String get sellingPriceValidationError => 'Veuillez saisir le prix de vente.';

  @override
  String get stockManagementSectionTitle => 'Gestion des stocks';

  @override
  String get stockQuantityLabel => 'Quantité en stock';

  @override
  String get stockQuantityValidationError =>
      'Veuillez saisir la quantité en stock.';

  @override
  String get negativeQuantityValidationError =>
      'La quantité ne peut pas être négative.';

  @override
  String get productUnitLabel => 'Unité';

  @override
  String get productUnitPiece => 'Pièce(s)';

  @override
  String get productUnitKg => 'Kilogramme(s) (kg)';

  @override
  String get productUnitG => 'Gramme(s) (g)';

  @override
  String get productUnitL => 'Litre(s) (L)';

  @override
  String get productUnitMl => 'Millilitre(s) (ml)';

  @override
  String get productUnitPackage => 'Paquet(s)';

  @override
  String get productUnitBox => 'Boîte(s)';

  @override
  String get productUnitOther => 'Autre unité';

  @override
  String get lowStockThresholdLabel => 'Seuil d\'alerte de stock bas';

  @override
  String get lowStockThresholdHelper =>
      'Recevoir une alerte lorsque le stock atteint ce niveau.';

  @override
  String get lowStockThresholdValidationError =>
      'Veuillez saisir un seuil d\'alerte valide.';

  @override
  String get negativeThresholdValidationError =>
      'Le seuil ne peut pas être négatif.';

  @override
  String get saveChangesButton => 'Enregistrer les modifications';

  @override
  String get addProductButton => 'Ajouter le produit';

  @override
  String get notesLabelOptional => 'Notes (Facultatif)';

  @override
  String addStockDialogTitle(String productName) {
    return 'Ajouter du stock à $productName';
  }

  @override
  String get currentStockLabel => 'Stock actuel';

  @override
  String get quantityToAddLabel => 'Quantité à ajouter';

  @override
  String get quantityValidationError => 'Veuillez saisir une quantité.';

  @override
  String get positiveQuantityValidationError =>
      'La quantité doit être positive pour un achat.';

  @override
  String get addButtonLabel => 'Ajouter';

  @override
  String get stockAdjustmentDefaultNote => 'Ajustement de stock';

  @override
  String get stockTransactionTypeOther => 'Autre';

  @override
  String get productInitialFallback => 'P';

  @override
  String get inventoryScreenTitle => 'Inventaire';

  @override
  String get allProductsTabLabel => 'Tous les produits';

  @override
  String get lowStockTabLabel => 'Stock faible';

  @override
  String get transactionsTabLabel => 'Transactions';

  @override
  String get noProductsAvailableMessage => 'Aucun produit disponible.';

  @override
  String get noLowStockProductsMessage => 'Aucun produit en stock faible.';

  @override
  String get noTransactionsAvailableMessage => 'Aucune transaction disponible.';

  @override
  String get searchProductDialogTitle => 'Rechercher un produit';

  @override
  String get searchProductHintText =>
      'Saisir le nom du produit ou le code-barres...';

  @override
  String get cancelButtonLabel => 'Annuler';

  @override
  String get searchButtonLabel => 'Rechercher';

  @override
  String get filterByCategoryDialogTitle => 'Filtrer par catégorie';

  @override
  String get noCategoriesAvailableMessage =>
      'Aucune catégorie disponible pour le filtrage.';

  @override
  String get showAllButtonLabel => 'Afficher tout';

  @override
  String get noProductsInInventoryMessage =>
      'Vous n\'avez encore ajouté aucun produit à votre inventaire.';

  @override
  String get priceLabel => 'Prix';

  @override
  String get inputPriceLabel => 'Saisie';

  @override
  String get stockLabel => 'Stock';

  @override
  String get unknownProductLabel => 'Produit inconnu';

  @override
  String get quantityLabel => 'Quantité';

  @override
  String get dateLabel => 'Date';

  @override
  String get valueLabel => 'Valeur';

  @override
  String get retryButtonLabel => 'Réessayer';

  @override
  String get stockTransactionTypePurchase => 'Achat';

  @override
  String get stockTransactionTypeSale => 'Vente';

  @override
  String get stockTransactionTypeAdjustment => 'Ajustement';

  @override
  String get salesScreenTitle => 'Gestion des ventes';

  @override
  String get salesTabAll => 'Toutes';

  @override
  String get salesTabPending => 'En attente';

  @override
  String get salesTabCompleted => 'Terminées';

  @override
  String get salesFilterDialogTitle => 'Filtrer les ventes';

  @override
  String get salesFilterDialogCancel => 'Annuler';

  @override
  String get salesFilterDialogApply => 'Appliquer';

  @override
  String get salesSummaryTotal => 'Total des ventes';

  @override
  String get salesSummaryCount => 'Nombre de ventes';

  @override
  String get salesStatusPending => 'En attente';

  @override
  String get salesStatusCompleted => 'Terminée';

  @override
  String get salesStatusPartiallyPaid => 'Partiellement payée';

  @override
  String get salesStatusCancelled => 'Annulée';

  @override
  String get salesNoSalesFound => 'Aucune vente trouvée';

  @override
  String get salesAddSaleButton => 'Ajouter une vente';

  @override
  String get salesErrorPrefix => 'Erreur';

  @override
  String get salesRetryButton => 'Réessayer';

  @override
  String get salesFilterDialogStartDate => 'Date de début';

  @override
  String get salesFilterDialogEndDate => 'Date de fin';

  @override
  String get salesListItemSaleIdPrefix => 'Vente #';

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
  String get salesListItemTotal => 'Total :';

  @override
  String get salesListItemRemainingToPay => 'Reste à payer :';

  @override
  String get subscriptionScreenTitle => 'Gestion des Abonnements';

  @override
  String get subscriptionUnsupportedFileType =>
      'Type de fichier non supporté. Veuillez choisir un fichier JPG ou PNG.';

  @override
  String get subscriptionFileTooLarge =>
      'Fichier trop volumineux. La taille maximale est de 5MB.';

  @override
  String get subscriptionNoImageSelected => 'Aucune image sélectionnée.';

  @override
  String get subscriptionUpdateSuccessMessage =>
      'Abonnement mis à jour avec succès.';

  @override
  String subscriptionUpdateFailureMessage(String error) {
    return 'Échec de la mise à jour de l\'abonnement : $error';
  }

  @override
  String get subscriptionTokenTopUpSuccessMessage =>
      'Recharge de tokens réussie.';

  @override
  String subscriptionTokenTopUpFailureMessage(String error) {
    return 'Échec de la recharge de tokens : $error';
  }

  @override
  String get subscriptionPaymentProofUploadSuccessMessage =>
      'Preuve de paiement téléchargée avec succès.';

  @override
  String subscriptionPaymentProofUploadFailureMessage(String error) {
    return 'Échec du téléchargement de la preuve de paiement : $error';
  }

  @override
  String get subscriptionRetryButton => 'Réessayer';

  @override
  String get subscriptionUnhandledState => 'État non géré ou initialisation...';

  @override
  String get subscriptionSectionOurOffers => 'Nos Offres d\'Abonnement';

  @override
  String get subscriptionSectionCurrentSubscription =>
      'Votre Abonnement Actuel';

  @override
  String get subscriptionSectionTokenUsage => 'Utilisation des Tokens Adha';

  @override
  String get subscriptionSectionInvoiceHistory => 'Historique des Factures';

  @override
  String get subscriptionSectionPaymentMethods => 'Méthodes de Paiement';

  @override
  String get subscriptionChangeSubscriptionButton => 'Changer d\'abonnement';

  @override
  String get subscriptionTierFree => 'Gratuit';

  @override
  String subscriptionTierUsers(int count) {
    return 'Utilisateurs : $count';
  }

  @override
  String subscriptionTierAdhaTokens(int count) {
    return 'Tokens Adha : $count';
  }

  @override
  String get subscriptionTierFeatures => 'Fonctionnalités :';

  @override
  String get subscriptionTierCurrentPlanChip => 'Plan Actuel';

  @override
  String get subscriptionTierChoosePlanButton => 'Choisir ce plan';

  @override
  String subscriptionCurrentPlanTitle(String tierName) {
    return 'Plan Actuel : $tierName';
  }

  @override
  String subscriptionCurrentPlanPrice(String price) {
    return 'Prix : $price';
  }

  @override
  String subscriptionAvailableAdhaTokens(int count) {
    return 'Tokens Adha disponibles : $count';
  }

  @override
  String get subscriptionTopUpTokensButton => 'Recharger des Tokens';

  @override
  String get subscriptionNoInvoices =>
      'Aucune facture disponible pour le moment.';

  @override
  String subscriptionInvoiceListTitle(String id, String date) {
    return 'Facture $id - $date';
  }

  @override
  String subscriptionInvoiceListSubtitle(String amount, String status) {
    return 'Montant : $amount - Statut : $status';
  }

  @override
  String get subscriptionDownloadInvoiceTooltip => 'Télécharger la facture';

  @override
  String subscriptionSimulateDownloadInvoice(String id, String url) {
    return 'Simulation : Téléchargement de $id depuis $url';
  }

  @override
  String subscriptionSimulateViewInvoiceDetails(String id) {
    return 'Simulation : Voir détails de la facture $id';
  }

  @override
  String get subscriptionPaymentMethodsNextInvoice =>
      'Méthodes de paiement pour la prochaine facture :';

  @override
  String get subscriptionPaymentMethodsRegistered => 'Méthodes enregistrées :';

  @override
  String get subscriptionPaymentMethodsOtherOptions =>
      'Autres options de paiement :';

  @override
  String get subscriptionPaymentMethodNewCard => 'Nouvelle Carte Bancaire';

  @override
  String get subscriptionPaymentMethodNewMobileMoney => 'Nouveau Mobile Money';

  @override
  String get subscriptionPaymentMethodManual =>
      'Paiement Manuel (Transfert/Dépôt)';

  @override
  String get subscriptionManualPaymentInstructions =>
      'Veuillez effectuer le transfert/dépôt aux coordonnées qui seront fournies et télécharger une preuve de paiement.';

  @override
  String subscriptionProofUploadedLabel(String fileName) {
    return 'Preuve Téléchargée : $fileName';
  }

  @override
  String get subscriptionUploadProofButton => 'Télécharger la preuve';

  @override
  String get subscriptionReplaceProofButton => 'Remplacer la preuve';

  @override
  String get subscriptionConfirmPaymentMethodButton =>
      'Confirmer la méthode de paiement';

  @override
  String subscriptionSimulatePaymentMethodSelected(String method) {
    return 'Méthode de paiement sélectionnée : $method (Simulation)';
  }

  @override
  String get subscriptionChangeDialogTitle => 'Changer d\'abonnement';

  @override
  String subscriptionChangeDialogTierSubtitle(String price, String tokens) {
    return '$price - Tokens : $tokens';
  }

  @override
  String get subscriptionTopUpDialogTitle => 'Recharger des Tokens Adha';

  @override
  String subscriptionTopUpDialogAmount(String amount, String currencyCode) {
    return '$amount $currencyCode';
  }

  @override
  String get subscriptionNoActivePlan =>
      'Vous n\'avez pas de plan d\'abonnement actif.';

  @override
  String get contactsScreenTitle => 'Contacts';

  @override
  String get contactsScreenClientsTab => 'Clients';

  @override
  String get contactsScreenSuppliersTab => 'Fournisseurs';

  @override
  String get contactsScreenAddClientTooltip => 'Ajouter un client';

  @override
  String get contactsScreenAddSupplierTooltip => 'Ajouter un fournisseur';

  @override
  String get searchCustomerHint => 'Rechercher un client...';

  @override
  String customerError(String message) {
    return 'Erreur : $message';
  }

  @override
  String get noCustomersToShow => 'Aucun client à afficher';

  @override
  String get customersTitle => 'Clients';

  @override
  String get filterCustomersTooltip => 'Filtrer les clients';

  @override
  String get addCustomerTooltip => 'Ajouter un nouveau client';

  @override
  String noResultsForSearchTerm(String searchTerm) {
    return 'Aucun résultat pour $searchTerm';
  }

  @override
  String get noCustomersAvailable => 'Aucun client disponible';

  @override
  String get topCustomersByPurchases => 'Meilleurs clients par achats';

  @override
  String get recentlyAddedCustomers => 'Clients récemment ajoutés';

  @override
  String resultsForSearchTerm(String searchTerm) {
    return 'Résultats pour $searchTerm';
  }

  @override
  String lastPurchaseDate(String date) {
    return 'Dernier achat : $date';
  }

  @override
  String get noRecentPurchase => 'Aucun achat récent';

  @override
  String totalPurchasesAmount(String amount) {
    return 'Total des achats : $amount';
  }

  @override
  String get viewDetails => 'Voir les détails';

  @override
  String get edit => 'Modifier';

  @override
  String get allCustomers => 'Tous les clients';

  @override
  String get topCustomers => 'Meilleurs clients';

  @override
  String get recentCustomers => 'Clients récents';

  @override
  String get byCategory => 'Par catégorie';

  @override
  String get filterByCategory => 'Filtrer par catégorie';

  @override
  String get deleteCustomerTitle => 'Supprimer le client';

  @override
  String deleteCustomerConfirmation(String customerName) {
    return 'Êtes-vous sûr de vouloir supprimer $customerName ? Cette action est irréversible.';
  }

  @override
  String get customerCategoryVip => 'VIP';

  @override
  String get customerCategoryRegular => 'Régulier';

  @override
  String get customerCategoryNew => 'Nouveau';

  @override
  String get customerCategoryOccasional => 'Occasionnel';

  @override
  String get customerCategoryBusiness => 'Affaires';

  @override
  String get customerCategoryUnknown => 'Inconnue';

  @override
  String get editCustomerTitle => 'Modifier le client';

  @override
  String get addCustomerTitle => 'Ajouter un client';

  @override
  String get customerPhoneHint => '+243 999 123 456';

  @override
  String get customerInformation => 'Informations du client';

  @override
  String get customerNameLabel => 'Nom du client';

  @override
  String get customerNameValidationError => 'Veuillez saisir le nom du client.';

  @override
  String get customerPhoneLabel => 'Téléphone du client';

  @override
  String get customerPhoneValidationError =>
      'Veuillez saisir le numéro de téléphone du client.';

  @override
  String get customerEmailLabel => 'Email du client (Facultatif)';

  @override
  String get customerEmailLabelOptional => 'Email du client';

  @override
  String get customerEmailValidationError =>
      'Veuillez saisir une adresse e-mail valide.';

  @override
  String get customerAddressLabel => 'Adresse du client (Facultatif)';

  @override
  String get customerAddressLabelOptional => 'Adresse du client';

  @override
  String get customerCategoryLabel => 'Catégorie de client';

  @override
  String get customerNotesLabel => 'Notes (Facultatif)';

  @override
  String get updateButtonLabel => 'Mettre à jour';

  @override
  String get customerDetailsTitle => 'Détails du client';

  @override
  String get editCustomerTooltip => 'Modifier le client';

  @override
  String get customerNotFound => 'Client non trouvé';

  @override
  String get contactInformationSectionTitle => 'Informations de contact';

  @override
  String get purchaseStatisticsSectionTitle => 'Statistiques d\'achat';

  @override
  String get totalPurchasesLabel => 'Total des achats';

  @override
  String get lastPurchaseLabel => 'Dernier achat';

  @override
  String get noPurchaseRecorded => 'Aucun achat enregistré';

  @override
  String get customerSinceLabel => 'Client depuis';

  @override
  String get addSaleButtonLabel => 'Ajouter une vente';

  @override
  String get callButtonLabel => 'Appeler';

  @override
  String get deleteButtonLabel => 'Supprimer';

  @override
  String callingNumber(String phoneNumber) {
    return 'Appel vers $phoneNumber...';
  }

  @override
  String emailingTo(String email) {
    return 'Envoi d\'email à $email...';
  }

  @override
  String openingMapFor(String address) {
    return 'Ouverture de la carte pour $address...';
  }

  @override
  String get searchSupplierHint => 'Rechercher un fournisseur...';

  @override
  String get clearSearchTooltip => 'Effacer la recherche';

  @override
  String supplierError(String message) {
    return 'Erreur : $message';
  }

  @override
  String get noSuppliersToShow => 'Aucun fournisseur à afficher';

  @override
  String get suppliersTitle => 'Fournisseurs';

  @override
  String get filterSuppliersTooltip => 'Filtrer les fournisseurs';

  @override
  String get addSupplierTooltip => 'Ajouter un nouveau fournisseur';

  @override
  String get noSuppliersAvailable => 'Aucun fournisseur disponible';

  @override
  String get topSuppliersByPurchases => 'Principaux fournisseurs par achats';

  @override
  String get recentlyAddedSuppliers => 'Fournisseurs récemment ajoutés';

  @override
  String contactPerson(String name) {
    return 'Contact : $name';
  }

  @override
  String get moreOptionsTooltip => 'Plus d\'options';

  @override
  String get allSuppliers => 'Tous les fournisseurs';

  @override
  String get topSuppliers => 'Principaux fournisseurs';

  @override
  String get recentSuppliers => 'Fournisseurs récents';

  @override
  String get deleteSupplierTitle => 'Supprimer le fournisseur';

  @override
  String deleteSupplierConfirmation(String supplierName) {
    return 'Êtes-vous sûr de vouloir supprimer $supplierName ? Cette action est irréversible.';
  }

  @override
  String get supplierCategoryStrategic => 'Stratégique';

  @override
  String get supplierCategoryRegular => 'Régulier';

  @override
  String get supplierCategoryNew => 'Nouveau';

  @override
  String get supplierCategoryOccasional => 'Occasionnel';

  @override
  String get supplierCategoryInternational => 'International';

  @override
  String get supplierCategoryUnknown => 'Inconnu';

  @override
  String get supplierCategoryLocal => 'Local';

  @override
  String get supplierCategoryOnline => 'En ligne';

  @override
  String get addSupplierTitle => 'Ajouter un fournisseur';

  @override
  String get editSupplierTitle => 'Modifier le fournisseur';

  @override
  String get supplierInformation => 'Informations du fournisseur';

  @override
  String get supplierNameLabel => 'Nom du fournisseur *';

  @override
  String get supplierNameValidationError => 'Le nom est obligatoire';

  @override
  String get supplierPhoneLabel => 'Numéro de téléphone *';

  @override
  String get supplierPhoneValidationError =>
      'Le numéro de téléphone est obligatoire';

  @override
  String get supplierPhoneHint => '+243 999 123 456';

  @override
  String get supplierEmailLabel => 'Email';

  @override
  String get supplierEmailValidationError => 'Veuillez entrer un email valide';

  @override
  String get supplierContactPersonLabel => 'Personne à contacter';

  @override
  String get supplierAddressLabel => 'Adresse';

  @override
  String get commercialInformation => 'Informations commerciales';

  @override
  String get deliveryTimeLabel => 'Délai de livraison';

  @override
  String get paymentTermsLabel => 'Conditions de paiement';

  @override
  String get paymentTermsHint => 'Ex: Net 30, 50% d\'avance, etc.';

  @override
  String get supplierCategoryLabel => 'Catégorie de fournisseur';

  @override
  String get supplierNotesLabel => 'Notes';

  @override
  String get updateSupplierButton => 'Mettre à jour';

  @override
  String get addSupplierButton => 'Ajouter';

  @override
  String get supplierDetailsTitle => 'Détails du fournisseur';

  @override
  String supplierErrorLoading(String message) {
    return 'Erreur : $message';
  }

  @override
  String get supplierNotFound => 'Fournisseur non trouvé';

  @override
  String get contactLabel => 'Contact';

  @override
  String get phoneLabel => 'Téléphone';

  @override
  String get emailLabel => 'E-mail';

  @override
  String get addressLabel => 'Adresse';

  @override
  String get commercialInformationSectionTitle => 'Informations commerciales';

  @override
  String deliveryTimeInDays(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count jours',
      one: '1 jour',
      zero: 'Non spécifié',
    );
    return '$_temp0';
  }

  @override
  String get supplierSinceLabel => 'Fournisseur depuis';

  @override
  String get notesSectionTitle => 'Notes';

  @override
  String get placeOrderButtonLabel => 'Passer commande';

  @override
  String get featureToImplement => 'Fonctionnalité à implémenter';

  @override
  String get confirmDeleteSupplierTitle => 'Supprimer le fournisseur';

  @override
  String confirmDeleteSupplierMessage(String supplierName) {
    return 'Êtes-vous sûr de vouloir supprimer $supplierName ? Cette action est irréversible.';
  }

  @override
  String get commonConfirm => 'Confirmer';

  @override
  String get commonError => 'Erreur';

  @override
  String get commonToday => 'Aujourd\'hui';

  @override
  String get commonThisMonth => 'Ce Mois-ci';

  @override
  String get commonThisYear => 'Cette Année';

  @override
  String get commonCustom => 'Personnalisé';

  @override
  String get commonAnonymousClient => 'Client Anonyme';

  @override
  String get commonAnonymousClientInitial => 'A';

  @override
  String get commonErrorDataUnavailable => 'Données indisponibles';

  @override
  String get commonNoData => 'Aucune donnée disponible';

  @override
  String get dashboardScreenTitle => 'Tableau de Bord';

  @override
  String get dashboardHeaderSalesToday => 'Ventes Aujourd\'hui';

  @override
  String get dashboardHeaderClientsServed => 'Clients Servis';

  @override
  String get dashboardHeaderReceivables => 'Créances';

  @override
  String get dashboardHeaderTransactions => 'Transactions';

  @override
  String get dashboardCardViewDetails => 'Voir Détails';

  @override
  String get dashboardSalesChartTitle => 'Aperçu des Ventes';

  @override
  String get dashboardSalesChartNoData => 'Aucune donnée de vente à afficher.';

  @override
  String get dashboardRecentSalesTitle => 'Ventes Récentes';

  @override
  String get dashboardRecentSalesViewAll => 'Voir Tout';

  @override
  String get dashboardRecentSalesNoData => 'Aucune vente récente.';

  @override
  String get dashboardOperationsJournalTitle => 'Journal des Opérations';

  @override
  String get dashboardOperationsJournalViewAll => 'Voir Tout';

  @override
  String get dashboardOperationsJournalNoData => 'Aucune opération récente.';

  @override
  String get dashboardOperationsJournalBalanceLabel => 'Solde';

  @override
  String get dashboardJournalExportSelectDateRangeTitle =>
      'Sélectionner la plage de dates';

  @override
  String get dashboardJournalExportExportButton => 'Exporter en PDF';

  @override
  String get dashboardJournalExportPrintButton => 'Imprimer le Journal';

  @override
  String get dashboardJournalExportSuccessMessage =>
      'Journal exporté avec succès.';

  @override
  String get dashboardJournalExportFailureMessage =>
      'Échec de l\'exportation du journal.';

  @override
  String get dashboardJournalExportNoDataForPeriod =>
      'Aucune donnée disponible pour la période sélectionnée.';

  @override
  String get dashboardJournalExportPrintingMessage =>
      'Préparation du journal pour l\'impression...';

  @override
  String get dashboardQuickActionsTitle => 'Actions Rapides';

  @override
  String get dashboardQuickActionsNewSale => 'Nouvelle Vente';

  @override
  String get dashboardQuickActionsNewExpense => 'Nouvelle Dépense';

  @override
  String get dashboardQuickActionsNewProduct => 'Nouveau Produit';

  @override
  String get dashboardQuickActionsNewService => 'Nouveau Service';

  @override
  String get dashboardQuickActionsNewClient => 'Nouveau Client';

  @override
  String get dashboardQuickActionsNewSupplier => 'Nouveau Fournisseur';

  @override
  String get dashboardQuickActionsCashRegister => 'Caisse';

  @override
  String get dashboardQuickActionsSettings => 'Paramètres';

  @override
  String get dashboardQuickActionsNewInvoice => 'Facturation';

  @override
  String get dashboardQuickActionsNewFinancing => 'Financement';

  @override
  String get commonLoading => 'Chargement...';

  @override
  String get cancel => 'Annuler';

  @override
  String get journalPdf_title => 'Journal des Opérations';

  @override
  String journalPdf_footer_pageInfo(int currentPage, int totalPages) {
    return 'Page $currentPage sur $totalPages';
  }

  @override
  String journalPdf_period(String startDate, String endDate) {
    return 'Période : $startDate - $endDate';
  }

  @override
  String get journalPdf_tableHeader_date => 'Date';

  @override
  String get journalPdf_tableHeader_time => 'Heure';

  @override
  String get journalPdf_tableHeader_description => 'Description';

  @override
  String get journalPdf_tableHeader_debit => 'Débit';

  @override
  String get journalPdf_tableHeader_credit => 'Crédit';

  @override
  String get journalPdf_tableHeader_balance => 'Solde';

  @override
  String get journalPdf_openingBalance => 'Solde d\\\'ouverture';

  @override
  String get journalPdf_closingBalance => 'Solde de clôture';

  @override
  String get journalPdf_footer_generatedBy => 'Généré par Wanzo';

  @override
  String get adhaHomePageTitle => 'Adha - Assistant IA';

  @override
  String get adhaHomePageDescription =>
      'Adha, votre assistant d\'entreprise intelligent';

  @override
  String get adhaHomePageBody =>
      'Posez-moi des questions sur votre entreprise et je vous aiderai à prendre les meilleures décisions grâce à des analyses et des conseils personnalisés.';

  @override
  String get startConversationButton => 'Commencer une conversation';

  @override
  String get viewConversationsButton => 'Voir mes conversations';

  @override
  String get salesAnalysisFeatureTitle => 'Analyses de ventes';

  @override
  String get salesAnalysisFeatureDescription =>
      'Obtenez des insights sur vos performances commerciales';

  @override
  String get inventoryManagementFeatureTitle => 'Gestion de stock';

  @override
  String get inventoryManagementFeatureDescription =>
      'Suivez et optimisez votre inventaire';

  @override
  String get customerRelationsFeatureTitle => 'Relations clients';

  @override
  String get customerRelationsFeatureDescription =>
      'Conseils pour fidéliser vos clients';

  @override
  String get financialCalculationsFeatureTitle => 'Calculs financiers';

  @override
  String get financialCalculationsFeatureDescription =>
      'Projections et analyses financières';

  @override
  String get loginButton => 'Se connecter';

  @override
  String get registerButton => 'S\'inscrire';

  @override
  String get emailHint => 'Entrez votre e-mail';

  @override
  String get emailValidationErrorRequired => 'Veuillez entrer votre e-mail';

  @override
  String get emailValidationErrorInvalid => 'Veuillez entrer un e-mail valide';

  @override
  String get passwordLabel => 'Mot de passe';

  @override
  String get passwordHint => 'Entrez votre mot de passe';

  @override
  String get passwordValidationErrorRequired =>
      'Veuillez entrer votre mot de passe';

  @override
  String authFailureMessage(Object message) {
    return 'Échec de l\'authentification : $message';
  }

  @override
  String get loginToYourAccount => 'Connectez-vous à votre compte';

  @override
  String get rememberMeLabel => 'Se souvenir de moi';

  @override
  String get forgotPasswordButton => 'Mot de passe oublié ?';

  @override
  String get noAccountPrompt => 'Vous n\'avez pas de compte ?';

  @override
  String get createAccountButton => 'Créer un compte';

  @override
  String get demoModeButton => 'Mode Démo';

  @override
  String get settings => 'Paramètres';

  @override
  String get settingsTitle => 'Paramètres';

  @override
  String get settingsDescription =>
      'Gérez les paramètres de votre application.';

  @override
  String get wanzoFallbackText => 'Texte de secours Wanzo';

  @override
  String get appVersion => 'Version de l\'application';

  @override
  String get loadingSettings => 'Chargement des paramètres...';

  @override
  String get companyInformation => 'Informations sur l\'entreprise';

  @override
  String get companyInformationSubtitle =>
      'Gérez les détails de votre entreprise';

  @override
  String get appearanceAndDisplay => 'Apparence et Affichage';

  @override
  String get appearanceAndDisplaySubtitle =>
      'Personnalisez l\'apparence et le ressenti';

  @override
  String get theme => 'Thème';

  @override
  String get themeLight => 'Clair';

  @override
  String get themeDark => 'Sombre';

  @override
  String get themeSystem => 'Système';

  @override
  String get language => 'Langue';

  @override
  String get languageEnglish => 'Anglais';

  @override
  String get languageFrench => 'Français';

  @override
  String get languageSwahili => 'Swahili';

  @override
  String get dateFormat => 'Format de date';

  @override
  String get dateFormatDDMMYYYY => 'JJ/MM/AAAA';

  @override
  String get dateFormatMMDDYYYY => 'MM/JJ/AAAA';

  @override
  String get dateFormatYYYYMMDD => 'AAAA/MM/JJ';

  @override
  String get dateFormatDDMMMYYYY => 'JJ MMM AAAA';

  @override
  String get monthJan => 'Janvier';

  @override
  String get monthFeb => 'Février';

  @override
  String get monthMar => 'Mars';

  @override
  String get monthApr => 'Avril';

  @override
  String get monthMay => 'Mai';

  @override
  String get monthJun => 'Juin';

  @override
  String get monthJul => 'Juillet';

  @override
  String get monthAug => 'Août';

  @override
  String get monthSep => 'Septembre';

  @override
  String get monthOct => 'Octobre';

  @override
  String get monthNov => 'Novembre';

  @override
  String get monthDec => 'Décembre';

  @override
  String get changeLogo => 'Changer le logo';

  @override
  String get companyName => 'Nom de l\'entreprise';

  @override
  String get companyNameRequired => 'Le nom de l\'entreprise est requis';

  @override
  String get email => 'E-mail';

  @override
  String get invalidEmail => 'Adresse e-mail invalide';

  @override
  String get phoneNumber => 'Numéro de téléphone';

  @override
  String get address => 'Adresse';

  @override
  String get rccm => 'RCCM';

  @override
  String get rccmHelperText => 'Registre du Commerce et du Crédit Mobilier';

  @override
  String get taxId => 'NIF';

  @override
  String get taxIdHelperText => 'Numéro d\'Identification Fiscale';

  @override
  String get website => 'Site Web';

  @override
  String get invoiceSettings => 'Paramètres de facturation';

  @override
  String get invoiceSettingsSubtitle => 'Gérez vos préférences de facturation';

  @override
  String get defaultInvoiceFooter => 'Pied de page de facture par défaut';

  @override
  String get defaultInvoiceFooterHint => 'ex: Merci pour votre confiance !';

  @override
  String get showTotalInWords => 'Afficher le total en lettres';

  @override
  String get exchangeRate => 'Taux de change (USD vers Local)';

  @override
  String get inventorySettings => 'Paramètres d\'inventaire';

  @override
  String get inventorySettingsSubtitle => 'Gérez vos préférences d\'inventaire';

  @override
  String get generalSettings => 'Paramètres généraux';

  @override
  String get defaultCategory => 'Catégorie par défaut';

  @override
  String get defaultCategoryRequired => 'La catégorie par défaut est requise';

  @override
  String get lowStockAlert => 'Alerte de stock bas';

  @override
  String get lowStockAlertHint => 'Quantité à laquelle déclencher l\'alerte';

  @override
  String get trackInventory => 'Suivre l\'inventaire';

  @override
  String get allowNegativeStock => 'Autoriser le stock négatif';

  @override
  String get saveChanges => 'Enregistrer les modifications';

  @override
  String get settingsUpdatedSuccessfully => 'Paramètres mis à jour avec succès';

  @override
  String get errorUpdatingSettings =>
      'Erreur lors de la mise à jour des paramètres';

  @override
  String get changesSaved => 'Modifications enregistrées avec succès !';

  @override
  String get errorSavingChanges =>
      'Erreur lors de l\'enregistrement des modifications';

  @override
  String get selectTheme => 'Sélectionner un thème';

  @override
  String get selectLanguage => 'Sélectionner la langue';

  @override
  String get selectDateFormat => 'Sélectionner le format de date';

  @override
  String get displaySettings => 'Paramètres d\'affichage';

  @override
  String get displaySettingsDescription => 'Gérer les paramètres d\'affichage.';

  @override
  String get companySettings => 'Paramètres de l\'entreprise';

  @override
  String get companySettingsDescription =>
      'Gérer les paramètres de l\'entreprise.';

  @override
  String get invoiceSettingsDescription =>
      'Gérer les paramètres de facturation.';

  @override
  String get inventorySettingsDescription =>
      'Gérer les paramètres d\'inventaire.';

  @override
  String minValue(double minValue) {
    return 'Valeur min : $minValue';
  }

  @override
  String maxValue(double maxValue) {
    return 'Valeur max : $maxValue';
  }

  @override
  String get valueMustBeNumber => 'La valeur doit être un nombre';

  @override
  String get valueMustBePositive => 'La valeur doit être positive';

  @override
  String get fieldRequired => 'Ce champ est requis';

  @override
  String get settingsGeneral => 'Général';

  @override
  String get settingsCompany => 'Entreprise';

  @override
  String get settingsInvoice => 'Facture';

  @override
  String get settingsInventory => 'Inventaire';

  @override
  String get settingsAppearance => 'Apparence';

  @override
  String get searchSettings => 'Rechercher des paramètres...';

  @override
  String get backupAndReports => 'Sauvegarde et Rapports';

  @override
  String get backupAndReportsSubtitle =>
      'Gérer la sauvegarde des données et générer des rapports';

  @override
  String get notifications => 'Notifications';

  @override
  String get notificationsSubtitle =>
      'Gérer les notifications de l\'application';

  @override
  String get resetSettings => 'Réinitialiser les paramètres';

  @override
  String get confirmResetSettings =>
      'Êtes-vous sûr de vouloir réinitialiser tous les paramètres à leurs valeurs par défaut ? Cette action est irréversible.';

  @override
  String get reset => 'Réinitialiser';

  @override
  String get taxIdentificationNumber => 'Numéro d\'Identification Fiscale';

  @override
  String get rccmNumber => 'Numéro RCCM';

  @override
  String get idNatNumber => 'Numéro ID National';

  @override
  String get idNatHelperText => 'Numéro d\'Identification Nationale';

  @override
  String get selectImageSource => 'Sélectionner la source de l\'image';

  @override
  String get gallery => 'Galerie';

  @override
  String get camera => 'Appareil photo';

  @override
  String get deleteCurrentLogo => 'Supprimer le logo actuel';

  @override
  String get logoDeleted => 'Logo supprimé.';

  @override
  String get logoUpdatedSuccessfully => 'Logo mis à jour avec succès.';

  @override
  String errorSelectingLogo(String errorDetails) {
    return 'Erreur lors de la sélection du logo : $errorDetails';
  }

  @override
  String get defaultProductCategory => 'Catégorie de produit par défaut';

  @override
  String get stockAlerts => 'Alertes de stock';

  @override
  String get lowStockAlertDays => 'Jours d\'alerte de stock bas';

  @override
  String get days => 'Jours';

  @override
  String get enterValidNumber => 'Veuillez entrer un nombre valide.';

  @override
  String get lowStockAlertDescription =>
      'Recevoir des alertes lorsque le stock d\'un produit est bas pendant un nombre de jours spécifié.';

  @override
  String get productCategories => 'Catégories de produits';

  @override
  String get manageYourProductCategories => 'Gérez vos catégories de produits.';

  @override
  String get addCategory => 'Ajouter une catégorie';

  @override
  String get editCategory => 'Modifier la catégorie';

  @override
  String get deleteCategory => 'Supprimer la catégorie';

  @override
  String get categoryName => 'Nom de la catégorie';

  @override
  String get categoryNameCannotBeEmpty =>
      'Le nom de la catégorie ne peut pas être vide.';

  @override
  String get categoryAdded => 'Catégorie ajoutée';

  @override
  String get categoryUpdated => 'Catégorie mise à jour';

  @override
  String get categoryDeleted => 'Catégorie supprimée';

  @override
  String get confirmDeleteCategory =>
      'Êtes-vous sûr de vouloir supprimer cette catégorie ?';

  @override
  String get deleteCategoryMessage => 'Cette action est irréversible.';

  @override
  String errorAddingCategory(Object error) {
    return 'Erreur lors de l\'ajout de la catégorie : $error';
  }

  @override
  String errorUpdatingCategory(Object error) {
    return 'Erreur lors de la mise à jour de la catégorie : $error';
  }

  @override
  String errorDeletingCategory(Object error) {
    return 'Erreur lors de la suppression de la catégorie : $error';
  }

  @override
  String errorFetchingCategories(Object error) {
    return 'Erreur lors de la récupération des catégories : $error';
  }

  @override
  String get noCategoriesFound =>
      'Aucune catégorie trouvée. Ajoutez-en une pour commencer !';

  @override
  String get signupScreenTitle => 'Créer un compte entreprise';

  @override
  String get signupStepIdentity => 'Identité';

  @override
  String get signupStepCompany => 'Entreprise';

  @override
  String get signupStepConfirmation => 'Confirmation';

  @override
  String get signupPersonalInfoTitle => 'Vos informations personnelles';

  @override
  String get signupOwnerNameLabel => 'Nom complet du propriétaire';

  @override
  String get signupOwnerNameHint => 'Entrez votre nom complet';

  @override
  String get signupOwnerNameValidation =>
      'Veuillez entrer le nom du propriétaire';

  @override
  String get signupEmailLabel => 'Adresse e-mail';

  @override
  String get signupEmailHint => 'Entrez votre adresse e-mail';

  @override
  String get signupEmailValidationRequired => 'Veuillez entrer votre e-mail';

  @override
  String get signupEmailValidationInvalid => 'Veuillez entrer un e-mail valide';

  @override
  String get signupPhoneLabel => 'Numéro de téléphone';

  @override
  String get signupPhoneHint => 'Entrez votre numéro de téléphone';

  @override
  String get signupPhoneValidation =>
      'Veuillez entrer votre numéro de téléphone';

  @override
  String get signupPasswordLabel => 'Mot de passe';

  @override
  String get signupPasswordHint =>
      'Entrez votre mot de passe (min. 8 caractères)';

  @override
  String get signupPasswordValidationRequired =>
      'Veuillez entrer un mot de passe';

  @override
  String get signupPasswordValidationLength =>
      'Le mot de passe doit comporter au moins 8 caractères';

  @override
  String get signupConfirmPasswordLabel => 'Confirmer le mot de passe';

  @override
  String get signupConfirmPasswordHint => 'Confirmez votre mot de passe';

  @override
  String get signupConfirmPasswordValidationRequired =>
      'Veuillez confirmer votre mot de passe';

  @override
  String get signupConfirmPasswordValidationMatch =>
      'Les mots de passe ne correspondent pas';

  @override
  String get signupRequiredFields => '* Champs obligatoires';

  @override
  String get signupCompanyInfoTitle => 'Informations sur votre entreprise';

  @override
  String get signupCompanyNameLabel => 'Nom de l\'entreprise';

  @override
  String get signupCompanyNameHint => 'Entrez le nom de votre entreprise';

  @override
  String get signupCompanyNameValidation =>
      'Veuillez entrer le nom de l\'entreprise';

  @override
  String get signupRccmLabel => 'Numéro RCCM / Enregistrement commercial';

  @override
  String get signupRccmHint => 'Entrez votre numéro RCCM ou équivalent';

  @override
  String get signupRccmValidation => 'Veuillez entrer le numéro RCCM';

  @override
  String get signupAddressLabel => 'Adresse / Localisation';

  @override
  String get signupAddressHint => 'Entrez l\'adresse de votre entreprise';

  @override
  String get signupAddressValidation =>
      'Veuillez entrer l\'adresse de l\'entreprise';

  @override
  String get signupActivitySectorLabel => 'Secteur d\'activité';

  @override
  String get signupTermsAndConditionsTitle => 'Résumé et conditions';

  @override
  String get signupInfoSummaryPersonal => 'Informations personnelles :';

  @override
  String get signupInfoSummaryName => 'Nom :';

  @override
  String get signupInfoSummaryEmail => 'E-mail :';

  @override
  String get signupInfoSummaryPhone => 'Téléphone :';

  @override
  String get signupInfoSummaryCompany => 'Informations sur l\'entreprise :';

  @override
  String get signupInfoSummaryCompanyName => 'Nom de l\'entreprise :';

  @override
  String get signupInfoSummaryRccm => 'RCCM :';

  @override
  String get signupInfoSummaryAddress => 'Adresse :';

  @override
  String get signupInfoSummaryActivitySector => 'Secteur d\'activité :';

  @override
  String get signupAgreeToTerms => 'J\'ai lu et j\'accepte les';

  @override
  String get signupTermsOfUse => 'Conditions d\'utilisation';

  @override
  String get andConnector => 'et';

  @override
  String get signupPrivacyPolicy => 'Politique de confidentialité';

  @override
  String get signupAgreeToTermsConfirmation =>
      'En cochant cette case, vous confirmez avoir lu, compris et accepté nos conditions d\'utilisation et notre politique de confidentialité.';

  @override
  String get signupButtonPrevious => 'Précédent';

  @override
  String get signupButtonNext => 'Suivant';

  @override
  String get signupButtonRegister => 'S\'inscrire';

  @override
  String get signupAlreadyHaveAccount =>
      'Vous avez déjà un compte ? Se connecter';

  @override
  String get signupErrorFillFields =>
      'Veuillez remplir correctement tous les champs obligatoires pour l\'étape actuelle.';

  @override
  String get signupErrorAgreeToTerms =>
      'Vous devez accepter les conditions générales pour vous inscrire.';

  @override
  String get signupSuccessMessage =>
      'Inscription réussie ! Connexion en cours...';

  @override
  String signupErrorRegistration(String error) {
    return 'L\'inscription a échoué : $error';
  }

  @override
  String get sectorAgricultureName => 'Agriculture et agroalimentaire';

  @override
  String get sectorAgricultureDescription =>
      'Production agricole, transformation alimentaire, élevage';

  @override
  String get sectorCommerceName => 'Commerce et distribution';

  @override
  String get sectorCommerceDescription =>
      'Vente au détail, distribution, import-export';

  @override
  String get sectorServicesName => 'Services';

  @override
  String get sectorServicesDescription =>
      'Services aux entreprises et aux particuliers';

  @override
  String get sectorTechnologyName => 'Technologies et innovation';

  @override
  String get sectorTechnologyDescription =>
      'Développement informatique, télécommunications, fintech';

  @override
  String get sectorManufacturingName => 'Manufacture et industrie';

  @override
  String get sectorManufacturingDescription =>
      'Production industrielle, artisanat, textile';

  @override
  String get sectorConstructionName => 'Construction et immobilier';

  @override
  String get sectorConstructionDescription =>
      'BTP, promotion immobilière, architecture';

  @override
  String get sectorTransportationName => 'Transport et logistique';

  @override
  String get sectorTransportationDescription =>
      'Transport de marchandises, logistique, entreposage';

  @override
  String get sectorEnergyName => 'Énergie et ressources naturelles';

  @override
  String get sectorEnergyDescription => 'Production d\'énergie, mines, eau';

  @override
  String get sectorTourismName => 'Tourisme et hôtellerie';

  @override
  String get sectorTourismDescription => 'Hôtellerie, restauration, tourisme';

  @override
  String get sectorEducationName => 'Éducation et formation';

  @override
  String get sectorEducationDescription =>
      'Enseignement, formation professionnelle';

  @override
  String get sectorHealthName => 'Santé et services médicaux';

  @override
  String get sectorHealthDescription =>
      'Soins médicaux, pharmacie, équipements médicaux';

  @override
  String get sectorFinanceName => 'Services financiers';

  @override
  String get sectorFinanceDescription => 'Banque, assurance, microfinance';

  @override
  String get sectorOtherName => 'Autre';

  @override
  String get sectorOtherDescription => 'Autres secteurs d\'activité';

  @override
  String get financeSettings => 'Finance';

  @override
  String get financeSettingsSubtitle =>
      'Configurez vos comptes bancaires et Mobile Money';

  @override
  String get businessUnitTypeCompany => 'Entreprise';

  @override
  String get businessUnitTypeBranch => 'Succursale';

  @override
  String get businessUnitTypePOS => 'Point de vente';

  @override
  String get businessUnitTypeCompanyDesc =>
      'Siège social - Établissement principal';

  @override
  String get businessUnitTypeBranchDesc => 'Succursale ou agence régionale';

  @override
  String get businessUnitTypePOSDesc => 'Point de vente, boutique ou dépôt';

  @override
  String get businessUnitStatusActive => 'Actif';

  @override
  String get businessUnitStatusInactive => 'Inactif';

  @override
  String get businessUnitStatusSuspended => 'Suspendu';

  @override
  String get businessUnitStatusClosed => 'Fermé';

  @override
  String get businessUnitConfiguration => 'Unité d\'affaires';

  @override
  String get businessUnitConfigurationDescription =>
      'Configurez l\'unité pour isoler les données par établissement';

  @override
  String get businessUnitDefaultCompany => 'Niveau Entreprise';

  @override
  String get businessUnitDefaultDescription =>
      'Données globales de l\'entreprise';

  @override
  String get businessUnitDefaultCompanyDescription =>
      'Vous opérez au niveau entreprise. Toutes les données sont centralisées.';

  @override
  String get businessUnitLevelDefault => 'Défaut';

  @override
  String get businessUnitConfigureByCode => 'Configurer une succursale ou POS';

  @override
  String get businessUnitConfigureByCodeDescription =>
      'Entrez le code reçu lors de la création de l\'unité';

  @override
  String get businessUnitCodeLabel => 'Code de l\'unité';

  @override
  String get businessUnitCodeHint => 'Ex: BRN-001, POS-KIN-001';

  @override
  String get businessUnitCodeHelper =>
      'Code unique fourni par l\'administrateur';

  @override
  String get businessUnitCodeInfo =>
      'Une fois la succursale ou le point de vente créé depuis le back-office, vous recevrez un code pour configurer cet appareil.';

  @override
  String get businessUnitCode => 'Code';

  @override
  String get businessUnitType => 'Type';

  @override
  String get businessUnitName => 'Nom de l\'unité';

  @override
  String get businessUnitConfigured => 'Unité configurée';

  @override
  String get businessUnitChangeInfo =>
      'Pour changer d\'unité, contactez l\'administrateur ou réinitialisez l\'application.';

  @override
  String get userRoleAdmin => 'Administrateur';

  @override
  String get userRoleSuperAdmin => 'Super Administrateur';

  @override
  String get userRoleManager => 'Manager';

  @override
  String get userRoleAccountant => 'Comptable';

  @override
  String get userRoleCashier => 'Caissier';

  @override
  String get userRoleSales => 'Commercial';

  @override
  String get userRoleInventoryManager => 'Gestionnaire Stock';

  @override
  String get userRoleStaff => 'Employé';

  @override
  String get userRoleCustomerSupport => 'Support Client';

  @override
  String get userRoleAdminDescription =>
      'Propriétaire de l\'entreprise avec tous les droits';

  @override
  String get userRoleSuperAdminDescription =>
      'Droits maximaux sur l\'entreprise et tous les services';

  @override
  String get userRoleManagerDescription => 'Gestionnaire avec droits étendus';

  @override
  String get userRoleAccountantDescription => 'Accès aux fonctions comptables';

  @override
  String get userRoleCashierDescription => 'Accès aux fonctions de caisse';

  @override
  String get userRoleSalesDescription => 'Accès aux fonctions de vente';

  @override
  String get userRoleInventoryManagerDescription =>
      'Accès à la gestion des stocks';

  @override
  String get userRoleStaffDescription => 'Employé standard';

  @override
  String get userRoleCustomerSupportDescription => 'Accès au support client';

  @override
  String get sidebarRevenues => 'Revenus';

  @override
  String get sidebarCharges => 'Charges';

  @override
  String get chartTitleAccountingView => 'Activité commerciale';

  @override
  String get chartTitleCashFlowView => 'Flux de trésorerie';

  @override
  String get chartLegendRevenues => 'Revenus (CA)';

  @override
  String get chartLegendCharges => 'Charges';

  @override
  String get chartLegendCashIn => 'Encaissements';

  @override
  String get chartLegendCashOut => 'Décaissements';

  @override
  String get kpiTurnover => 'Chiffre d\'affaires';

  @override
  String get kpiCashIn => 'Encaissements';

  @override
  String get kpiCashOut => 'Décaissements';

  @override
  String get kpiReceivables => 'Créances clients';

  @override
  String get kpiPayables => 'Dettes fournisseurs';

  @override
  String get filterCashFlowOnly => 'Trésorerie';

  @override
  String get filterAccountingOnly => 'Comptabilité';

  @override
  String get paymentStatusPaid => 'Encaissé';

  @override
  String get paymentStatusPartial => 'Partiel';

  @override
  String get paymentStatusPending => 'À encaisser';

  @override
  String get expensePaymentStatusPaid => 'Décaissé';

  @override
  String get expensePaymentStatusPartial => 'Partiel';

  @override
  String get expensePaymentStatusPending => 'À décaisser';

  @override
  String get documentTypeInvoice => 'Facture';

  @override
  String get documentTypeReceipt => 'Ticket de caisse';

  @override
  String get documentTypeCashVoucher => 'Bon de sortie caisse';
}
