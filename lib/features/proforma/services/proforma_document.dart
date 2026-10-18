import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../invoice/services/invoice_service.dart';
import '../../sales/models/sale.dart';
import '../../sales/models/sale_item.dart';
import '../../settings/bloc/settings_bloc.dart';
import '../../settings/bloc/settings_state.dart';
import '../../settings/models/settings.dart';
import '../models/proforma.dart';

/// Impression d'une proforma : le MÊME générateur que la facture
/// (InvoiceService.generateInvoicePdf), rendu en « Facture proforma ». La
/// vente construite ici n'existe qu'en mémoire : rien n'est enregistré, rien
/// ne part en comptabilité, le stock ne bouge pas.
abstract final class ProformaDocument {
  /// Vente « d'aperçu » portant les lignes de la proforma, dans sa devise de
  /// présentation (base CDF conservée ligne par ligne).
  static Sale previewSale(Proforma p) {
    final rate = p.currencyCode == 'CDF' ? 1.0 : p.exchangeRate;
    final items = <SaleItem>[
      for (final l in p.lines) saleItemOf(p, l, rate),
    ];
    return _sale(p, items, rate);
  }

  /// Ligne de vente d'une ligne de proforma. Une quantité décimale (2,5 kg)
  /// n'est jamais arrondie : la ligne porte 1 et le libellé dit la quantité.
  static SaleItem saleItemOf(Proforma p, ProformaLine l, double rate) {
    final unit = rate > 0 ? l.unitPriceCdf / rate : l.unitPriceCdf;
    final entier = l.isWholeQuantity && l.quantity >= 1;
    return SaleItem.withCalculatedTotal(
          productId: l.productId ?? l.serviceId ?? p.id,
          productName: entier
              ? l.label
              : '${l.label} (${l.quantityLabel} x ${unit.toStringAsFixed(2)})',
          quantity: entier ? l.quantity.toInt() : 1,
          unitPrice: entier ? unit : unit * l.quantity,
          currencyCode: p.currencyCode,
          exchangeRate: rate,
          itemType: l.isProduct ? SaleItemType.product : SaleItemType.service,
          notes: l.note,
        );
  }

  static Sale _sale(Proforma p, List<SaleItem> items, double rate) {
    return Sale(
      id: p.id,
      date: p.issuedAt,
      customerId: p.customerId,
      customerName: p.customerName ?? 'Client',
      items: items,
      totalAmountInCdf: p.totalCdf,
      paidAmountInCdf: 0,
      status: SaleStatus.pending,
      notes: p.notes ?? '',
      transactionCurrencyCode: p.currencyCode,
      transactionExchangeRate: rate,
      totalAmountInTransactionCurrency: p.totalInCurrency,
      paidAmountInTransactionCurrency: 0,
    );
  }

  /// Paramètres de facturation courants (émetteur, logo, NIF), ou `null`.
  static Settings? settingsOf(BuildContext context) {
    try {
      final st = context.read<SettingsBloc>().state;
      if (st is SettingsLoaded) return st.settings;
      if (st is SettingsUpdated) return st.settings;
    } catch (_) {}
    return null;
  }

  /// Chemin du PDF de la proforma.
  static Future<String> pdf(Proforma p, Settings settings) =>
      InvoiceService().generateInvoicePdf(
        previewSale(p),
        settings,
        proforma: p.mention,
      );
}
