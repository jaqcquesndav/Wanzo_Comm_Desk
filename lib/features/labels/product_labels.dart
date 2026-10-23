import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

import 'package:wanzo/core/enums/currency_enum.dart';
import 'package:wanzo/core/services/business_context_service.dart';
import 'package:wanzo/core/services/currency_display_service.dart';
import 'package:wanzo/core/services/currency_service.dart';
import 'package:wanzo/core/utils/currency_formatter.dart';
import 'package:wanzo/features/inventory/bloc/inventory_bloc.dart';
import 'package:wanzo/features/inventory/bloc/inventory_event.dart';
import 'package:wanzo/features/inventory/models/product.dart';
import 'package:wanzo/features/inventory/repositories/inventory_repository.dart';
import 'package:wanzo/features/settings/presentation/cubit/currency_settings_cubit.dart';

import 'label_codes.dart';
import 'label_item.dart';
import 'print_labels_screen.dart';

/// Unité courte imprimée après le prix (« 2 500 CDF / kg »).
String? productUnitShort(ProductUnit u) => switch (u) {
      ProductUnit.piece => 'pièce',
      ProductUnit.kg => 'kg',
      ProductUnit.g => 'g',
      ProductUnit.l => 'L',
      ProductUnit.ml => 'mL',
      ProductUnit.package => 'paquet',
      ProductUnit.box => 'boîte',
      ProductUnit.other => null,
    };

/// Article de stock vers étiquette. Le prix suit la règle de devise de
/// l'app : base CDF convertie dans la devise active, et la seconde devise
/// (CDF ou USD) quand l'affichage double est activé.
LabelItem productToLabel(
  Product p, {
  required Currency active,
  required double Function(double cdf, Currency to) convert,
  bool dualCurrency = false,
}) {
  final existing = LabelCodes.pickExistingCode(barcode: p.barcode, sku: p.sku);
  final code = existing ?? LabelCodes.generateSku(p.id);
  String? price;
  String? secondary;
  if (p.sellingPriceInCdf > 0) {
    price = formatCurrency(convert(p.sellingPriceInCdf, active), active.code);
    if (dualCurrency) {
      final other = active == Currency.USD ? Currency.CDF : Currency.USD;
      secondary =
          formatCurrency(convert(p.sellingPriceInCdf, other), other.code);
    }
  }
  return LabelItem(
    id: p.id,
    name: p.name,
    code: code,
    // Le code n'est reconnu par le lecteur de la caisse que s'il est le
    // code-barres du produit : un SKU seul est recopié dans ce champ.
    codeIsGenerated: LabelCodes.clean(p.barcode).isEmpty,
    price: price,
    secondaryPrice: secondary,
    unit: productUnitShort(p.unit),
    extra: p.expirationDate == null
        ? null
        : 'Exp. ${DateFormat('dd/MM/yyyy').format(p.expirationDate!)}',
    stockQuantity: p.stockQuantity,
  );
}

/// Nom imprimé : unité d'affaires dotée d'une identité propre, sinon
/// l'entreprise.
String? labelCompanyName() {
  final ctx = BusinessContextService();
  final bu = ctx.shouldUseBusinessUnitIdentity ? ctx.businessUnitName : null;
  final name = (bu ?? ctx.companyName ?? '').trim();
  return name.isEmpty ? null : name;
}

/// Ouvre l'impression d'étiquettes pour des articles de stock (un seul
/// depuis une carte ou une fiche, la liste entière pour un lot).
Future<void> printProductLabels(
  BuildContext context, {
  required List<Product> products,
  Set<String>? selectedIds,
}) async {
  Currency active = Currency.CDF;
  double Function(double, Currency) convert = (v, _) => v;
  try {
    final cs = context.read<CurrencyService>();
    convert = cs.convertFromCdf;
    active = cs.currentSettings.activeCurrency;
    active = context.read<CurrencySettingsCubit>().state.settings.activeCurrency;
  } catch (_) {}
  InventoryRepository? repo;
  InventoryBloc? bloc;
  try {
    repo = context.read<InventoryRepository>();
  } catch (_) {}
  try {
    bloc = context.read<InventoryBloc>();
  } catch (_) {}
  await CurrencyDisplayService.instance.load();
  final dual = CurrencyDisplayService.instance.dualCurrency.value;
  if (!context.mounted) return;

  final items = [
    for (final p in products)
      productToLabel(p, active: active, convert: convert, dualCurrency: dual),
  ];
  var saved = false;
  await openPrintLabels(
    context,
    items: items,
    selectedIds: selectedIds,
    companyName: labelCompanyName(),
    saveCode: repo == null
        ? null
        : (item) async {
            final p = repo!.getProductById(item.id);
            if (p == null) return false;
            if (LabelCodes.clean(p.barcode).isNotEmpty) return true;
            // Mise à jour locale d'abord, synchronisée ensuite (hors ligne
            // compris) par la voie existante du dépôt.
            await repo.updateProduct(p.copyWith(barcode: item.code));
            saved = true;
            return true;
          },
  );
  if (saved) bloc?.add(const LoadProducts());
}
