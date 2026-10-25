import 'package:flutter/foundation.dart';

import '../../../core/enums/business_unit_enums.dart';
import '../../../core/models/payment_method_code.dart';
import '../../../core/services/business_context_service.dart';
import '../models/sale.dart';

/// Corps envoyé au backend gestion pour `POST sales`, `POST sales/sync` et
/// `PATCH sales/:id`. UNE seule construction pour les deux services d'API
/// (écran de vente et synchronisation hors ligne), qui divergeaient.
///
/// Contrat (CreateSaleDto / UpdateSaleDto, ValidationPipe `whitelist: true`,
/// une clé inconnue est supprimée en silence) :
/// - la devise de la vente s'appelle `transactionCurrencyCode` (et non
///   `currencyCode`, clé inconnue : une vente en USD était enregistrée en CDF) ;
/// - le montant payé s'appelle `amountPaidInCdf` à la création et
///   `paidAmountInCdf` à la mise à jour : les deux sont émis ;
/// - `businessUnitType` est l'enum backend en minuscules (`company`, `branch`,
///   `pos`) : `COMPANY` était rejeté par `@IsEnum` ;
/// - `paymentMethod` est obligatoire à la création ;
/// - aucune chaîne vide pour une date, un email ou une URL.
///
/// [includeItems] à `false` pour un PATCH qui ne touche pas aux lignes
/// (règlement, changement de statut) : le backend ne recalcule alors pas le
/// stock et ne peut pas rejeter un identifiant de ligne inconnu.
///
/// Lève [StateError] si la vente est dans une devise étrangère sans taux de
/// change exploitable : un taux 1 implicite ferait enregistrer 10 USD comme
/// 10 CDF.
Map<String, dynamic> saleToApiDto(
  Sale sale, {
  bool includeItems = true,
  String? sourceMode,
}) {
  final currency = (sale.transactionCurrencyCode ?? 'CDF').toUpperCase();
  final rate = saleExchangeRateForApi(sale);
  String? nonEmpty(String? v) => (v != null && v.trim().isNotEmpty) ? v : null;

  return {
    if (nonEmpty(sale.localId) != null) 'localId': sale.localId,
    // Mode métier ayant produit la vente (colonne mode du journal comptable).
    'sourceMode':
        sourceMode ?? BusinessContextService().activityMode.apiValue,
    // Instant UTC (suffixe Z), comme opened_at de la caisse : l'heure
    // locale du poste ne decale plus la vente d'un jour. Affichage : local.
    'date': sale.date.toUtc().toIso8601String(),
    if (sale.dueDate != null) 'dueDate': sale.dueDate!.toIso8601String(),
    if (nonEmpty(sale.customerId) != null) 'customerId': sale.customerId,
    // Client de passage : si aucun customerId réel, le backend fait un
    // find-or-create du Customer via ce numéro (base fidélité).
    if (nonEmpty(sale.customerPhoneNumber) != null)
      'customerPhoneNumber': sale.customerPhoneNumber,
    'customerName': sale.customerName,
    // Code canonique (cash, mobile_money, credit...), jamais le libellé traduit.
    'paymentMethod': paymentMethodCode(sale.paymentMethod),
    if (nonEmpty(sale.paymentReference) != null)
      'paymentReference': sale.paymentReference,
    'exchangeRate': rate,
    'transactionCurrencyCode': currency,
    if (nonEmpty(sale.notes) != null) 'notes': sale.notes,
    'amountPaidInCdf': sale.paidAmountInCdf,
    'paidAmountInCdf': sale.paidAmountInCdf,
    if (sale.paidAmountInTransactionCurrency != null &&
        sale.paidAmountInTransactionCurrency! > 0)
      'paidAmountInTransactionCurrency': sale.paidAmountInTransactionCurrency,
    // Statut : accepté par les DTO de création et de mise à jour.
    'status': sale.status.name,
    if (sale.discountPercentage > 0)
      'discountPercentage': sale.discountPercentage,
    // Totaux calculés par l'app (après remise globale) : le serveur applique
    // la même remise et peut contrôler la cohérence.
    'totalAmountInCdf': sale.totalAmountInCdf,
    if (sale.amountHT != null) 'amountHT': sale.amountHT,
    if (sale.taxAmount != null) 'taxAmount': sale.taxAmount,
    if (sale.totalAmountInTransactionCurrency != null)
      'totalAmountInTransactionCurrency': sale.totalAmountInTransactionCurrency,
    // Pièces jointes : URLs Cloudinary seulement, jamais les chemins locaux.
    if (sale.attachmentUrls != null && sale.attachmentUrls!.isNotEmpty)
      'attachmentUrls': sale.attachmentUrls,
    if (nonEmpty(sale.companyId) != null) 'companyId': sale.companyId,
    if (nonEmpty(sale.businessUnitId) != null)
      'businessUnitId': sale.businessUnitId,
    if (nonEmpty(sale.businessUnitCode) != null)
      'businessUnitCode': sale.businessUnitCode,
    if (sale.businessUnitType != null)
      'businessUnitType': sale.businessUnitType!.code,
    if (includeItems)
      'items': sale.items
          .map(
            (item) => {
              // L'identifiant de ligne DOIT être renvoyé sur un PATCH : sans
              // lui, le backend recrée les lignes et re-décrémente le stock.
              // Il n'est émis que s'il est connu du serveur (non vide).
              if (item.id != null && item.id!.isNotEmpty) 'id': item.id,
              if (item.productId != null && item.productId!.isNotEmpty)
                'productId': item.productId,
              'productName': item.productName,
              'quantity': item.quantity,
              'unitPrice': item.unitPrice,
              if (item.discount != null && item.discount! > 0)
                'discount': item.discount,
              'currencyCode':
                  item.currencyCode.isNotEmpty ? item.currencyCode : currency,
              'itemType': item.itemType.name,
              // Service du catalogue (page Offre) et palier de prix retenu.
              if (item.serviceId != null && item.serviceId!.isNotEmpty)
                'serviceId': item.serviceId,
              if (item.priceTierCode != null && item.priceTierCode!.isNotEmpty)
                'priceTierCode': item.priceTierCode,
              if (item.taxRate != null) 'taxRate': item.taxRate,
              if (item.notes != null && item.notes!.isNotEmpty)
                'notes': item.notes,
              // Mode salon : exécutant + commission figée (si renseignés).
              if (item.performerId != null && item.performerId!.isNotEmpty)
                'performerId': item.performerId,
              if (item.performerName != null && item.performerName!.isNotEmpty)
                'performerName': item.performerName,
              if (item.commissionRate != null)
                'commissionRate': item.commissionRate,
              if (item.commissionAmount != null)
                'commissionAmount': item.commissionAmount,
            },
          )
          .toList(),
  };
}

/// Taux de change devise de la vente vers CDF à transmettre au backend.
///
/// CDF : 1 par définition. Devise étrangère : le taux figé de la vente, qui
/// doit être connu et supérieur à 1 (un taux à 1 est le symptôme du défaut
/// « taux 1 implicite »). Sinon [StateError] : la vente reste en attente
/// au lieu d'être enregistrée avec des montants faux.
double saleExchangeRateForApi(Sale sale) {
  final currency = (sale.transactionCurrencyCode ?? 'CDF').toUpperCase();
  if (currency == 'CDF') return 1.0;
  final rate = sale.transactionExchangeRate;
  if (rate == null || rate <= 1.0) {
    throw StateError(
      'Taux de change $currency vers CDF inconnu pour cette vente : '
      'renseignez le taux du jour avant de l\'enregistrer.',
    );
  }
  return rate;
}

/// Taille de page pour relire toutes les ventes (le backend pagine à 10 par
/// défaut quand `limit` est absent).
const int salesPageSize = 100;

/// Garde-fou contre une boucle infinie de pagination.
const int salesMaxPages = 200;

/// Liste de ventes d'une réponse serveur : une vente mal formée est ignorée
/// (et tracée) au lieu de faire échouer toute la liste.
List<Sale> parseSaleList(List<dynamic> raw) {
  final sales = <Sale>[];
  for (final item in raw) {
    if (item is! Map) continue;
    try {
      sales.add(Sale.fromJson(Map<String, dynamic>.from(item)));
    } catch (e) {
      debugPrint('[SalesAPI] Vente mal formée ignorée : $e');
    }
  }
  return sales;
}
