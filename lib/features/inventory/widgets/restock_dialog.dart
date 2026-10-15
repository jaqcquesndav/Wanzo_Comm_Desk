import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:uuid/uuid.dart';

import '../../../constants/spacing.dart';
import '../../../core/enums/currency_enum.dart';
import '../../../core/models/operation_payment.dart';
import '../../../core/services/currency_service.dart';
import '../../../core/utils/price_plausibility.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../expenses/bloc/expense_bloc.dart';
import '../../expenses/models/expense.dart';
import '../../supplier/models/supplier.dart';
import '../../supplier/widgets/supplier_picker_field.dart';
import '../bloc/inventory_bloc.dart';
import '../bloc/inventory_event.dart';
import '../models/product.dart';
import '../models/stock_transaction.dart';

/// Réapprovisionnement d'un produit : UNE seule boîte, réutilisée partout
/// (fiche produit, liste du stock, recherche de la vente).
///
/// Un achat de marchandise fait deux choses : il crée la dépense (catégorie
/// stock), payée ou à payer au fournisseur, PUIS il fait entrer le stock
/// (mouvement « achat » rattaché à cette dépense : le serveur ne compte
/// l'achat qu'une fois). Les deux passent par les blocs existants
/// (AddExpense, AddStockTransaction), rien n'est réimplémenté.
///
/// Renvoie `true` quand le réapprovisionnement a été enregistré.
Future<bool?> showRestockDialog(BuildContext context, Product product) {
  return showDialog<bool>(
    context: context,
    builder: (_) => _RestockDialog(product: product),
  );
}

class _RestockDialog extends StatefulWidget {
  final Product product;
  const _RestockDialog({required this.product});

  @override
  State<_RestockDialog> createState() => _RestockDialogState();
}

class _RestockDialogState extends State<_RestockDialog> {
  final _formKey = GlobalKey<FormState>();
  final _qtyController = TextEditingController();
  late final TextEditingController _priceController;
  final _supplierNameController = TextEditingController();
  final _supplierPhoneController = TextEditingController();

  Supplier? _supplier;
  bool _paid = true;
  String? _method = kPaymentMethodOptions.first;
  bool _envoi = false;

  /// Devise du prix d'achat, choisie une fois (devise active des réglages
  /// si son taux existe, sinon CDF) ; jamais réécrite par une reconstruction.
  late Currency _devise;

  @override
  void initState() {
    super.initState();
    final currencies = context.read<CurrencyService>();
    final active = currencies.currentSettings.activeCurrency;
    _devise = currencies.hasRate(active) ? active : Currency.CDF;
    // Coût connu (base CDF) proposé dans la devise choisie.
    final cost = widget.product.costPriceInCdf;
    final costInDevise =
        cost > 0 ? currencies.convertFromCdf(cost, _devise) : 0.0;
    _priceController = TextEditingController(
      text: costInDevise > 0 ? costInDevise.toStringAsFixed(2) : '',
    );
  }

  /// Devises proposées : celles qui ont un taux exploitable.
  List<Currency> get _devisesDisponibles {
    final currencies = context.read<CurrencyService>();
    return Currency.values.where(currencies.hasRate).toList();
  }

  @override
  void dispose() {
    _qtyController.dispose();
    _priceController.dispose();
    _supplierNameController.dispose();
    _supplierPhoneController.dispose();
    super.dispose();
  }

  double get _qty =>
      double.tryParse(_qtyController.text.replaceAll(',', '.')) ?? 0;
  double get _price =>
      double.tryParse(_priceController.text.replaceAll(',', '.')) ?? 0;
  double get _total => _qty * _price;

  Future<void> _submit() async {
    if (_envoi || !_formKey.currentState!.validate()) return;
    final product = widget.product;
    final code = _devise.code;
    // Devise étrangère sans taux : refus, jamais un taux 1 muet.
    final taux = context.read<CurrencyService>().usableRateToCdfForCode(code);
    if (taux == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(CurrencyService.missingRateMessage(code))),
      );
      return;
    }
    // Prix en francs anormalement bas : sans doute des dollars.
    final choix = await verifierPrixSaisi(context, prix: _price, codeDevise: code);
    if (!mounted || choix == ChoixDevisePrix.annule) return;
    if (choix == ChoixDevisePrix.enDollars) {
      // On bascule en dollars et on laisse relire avant d'enregistrer.
      if (!context.read<CurrencyService>().hasRate(Currency.USD)) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(CurrencyService.missingRateMessage('USD'))),
        );
        return;
      }
      setState(() => _devise = Currency.USD);
      return;
    }
    setState(() => _envoi = true);
    final messenger = ScaffoldMessenger.of(context);
    final inventoryBloc = context.read<InventoryBloc>();
    final now = DateTime.now();

    // 1. La dépense d'achat D'ABORD : payée (avec son mode) ou à payer au
    // fournisseur. Son identifiant serveur rattache ensuite le stock.
    final depenseEnregistree = Completer<Expense>();
    context.read<ExpenseBloc>().add(
      AddExpense(
        Expense(
          id: const Uuid().v4(),
          date: now,
          motif: 'Réapprovisionnement ${product.name}',
          amount: _total,
          category: ExpenseCategory.inventory,
          currencyCode: code,
          exchangeRate: taux,
          supplierId: _supplier?.id,
          supplierName: _supplier?.name,
          paidAmount: _paid ? _total : 0.0,
          paymentStatus:
              _paid ? ExpensePaymentStatus.paid : ExpensePaymentStatus.unpaid,
          paymentMethod: _paid ? _method : null,
          notes: '${_qty.toStringAsFixed(_qty % 1 == 0 ? 0 : 2)} x '
              '${formatCurrency(_price, code)}',
        ),
        saved: depenseEnregistree,
      ),
    );
    final Expense depense;
    try {
      depense = await depenseEnregistree.future;
    } catch (e) {
      if (!mounted) return;
      setState(() => _envoi = false);
      final motif = '$e'.replaceFirst('Exception: ', '');
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            "La dépense n'a pas pu être enregistrée, le stock n'a pas "
            'été modifié : $motif',
          ),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // 2. L'entrée de stock. Dépense acceptée par le serveur : achat rattaché
    // (le serveur passe 311 / 6031, pas une seconde dette). Dépense en
    // attente du réseau (pas encore d'identifiant serveur) : stock appliqué
    // en local, l'achat est gardé et part avec l'id serveur de la dépense.
    final surServeur = depense.syncStatus == 'synced';
    final mouvement = StockTransaction(
      id: const Uuid().v4(),
      productId: product.id,
      type: StockTransactionType.purchase,
      quantity: _qty,
      date: now,
      referenceId: depense.id,
      notes: 'Réapprovisionnement ${product.name}',
      unitCostInCdf: _price * taux,
      totalValueInCdf: _total * taux,
      currencyCode: 'CDF',
    );
    final expenseId = surServeur ? depense.id : null;
    final issue = Completer<String?>();
    inventoryBloc.add(
      AddStockTransaction(
        mouvement,
        expenseId: expenseId,
        awaitingExpenseId: surServeur ? null : depense.id,
        serverOutcome: issue,
      ),
    );
    final refus = await issue.future;
    if (!mounted) return;
    Navigator.of(context).pop(true);

    if (refus == null) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            surServeur
                ? 'Réapprovisionnement de ${product.name} enregistré : '
                    'stock mis à jour et dépense créée.'
                : 'Hors connexion : réapprovisionnement de ${product.name} '
                    'enregistré sur cet appareil, envoyé au retour du réseau.',
          ),
          backgroundColor: Colors.green,
        ),
      );
      return;
    }
    // La dépense existe, le stock serveur non : on le dit et on propose de
    // renvoyer le même mouvement (sans le recompter sur l'appareil).
    messenger.showSnackBar(
      SnackBar(
        duration: const Duration(seconds: 12),
        backgroundColor: Colors.red,
        content: Text(
          'La dépense est enregistrée, mais le stock de ${product.name} '
          "n'a pas été mis à jour sur le serveur : $refus",
        ),
        action: SnackBarAction(
          label: 'Réessayer',
          textColor: Colors.white,
          onPressed: () => _renvoyerMouvement(
            inventoryBloc,
            messenger,
            mouvement,
            expenseId,
          ),
        ),
      ),
    );
  }

  static Future<void> _renvoyerMouvement(
    InventoryBloc bloc,
    ScaffoldMessengerState messenger,
    StockTransaction mouvement,
    String? expenseId,
  ) async {
    final refus = await bloc.inventoryRepository.syncStockTransaction(
      mouvement,
      expenseId: expenseId,
    );
    bloc.add(LoadProduct(mouvement.productId));
    messenger.showSnackBar(
      SnackBar(
        backgroundColor: refus == null ? Colors.green : Colors.red,
        content: Text(
          refus == null
              ? 'Stock mis à jour sur le serveur.'
              : "Le stock n'a toujours pas été mis à jour : $refus",
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final product = widget.product;
    final numberFormatter = FilteringTextInputFormatter.allow(
      RegExp(r'[0-9.,]'),
    );
    return AlertDialog(
      title: Text('Réapprovisionner ${product.name}'),
      content: SizedBox(
        width: 460,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Stock actuel : ${product.stockQuantity.toStringAsFixed(product.stockQuantity % 1 == 0 ? 0 : 2)}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: WanzoSpacing.md),
                TextFormField(
                  controller: _qtyController,
                  autofocus: true,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  inputFormatters: [numberFormatter],
                  decoration: const InputDecoration(
                    labelText: 'Quantité reçue',
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (_) => setState(() {}),
                  validator: (_) =>
                      _qty > 0 ? null : 'Indiquez une quantité positive.',
                ),
                const SizedBox(height: WanzoSpacing.md),
                TextFormField(
                  controller: _priceController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  inputFormatters: [numberFormatter],
                  decoration: InputDecoration(
                    labelText: 'Prix d\'achat unitaire',
                    border: const OutlineInputBorder(),
                    // Devise du prix saisi, parmi celles qui ont un taux.
                    suffixIcon: Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<Currency>(
                          value: _devise,
                          items: _devisesDisponibles
                              .map(
                                (c) => DropdownMenuItem(
                                  value: c,
                                  child: Text(c.code),
                                ),
                              )
                              .toList(),
                          onChanged: (c) {
                            if (c != null) setState(() => _devise = c);
                          },
                        ),
                      ),
                    ),
                  ),
                  onChanged: (_) => setState(() {}),
                  validator: (_) =>
                      _price > 0 ? null : 'Indiquez le prix d\'achat.',
                ),
                const SizedBox(height: WanzoSpacing.sm),
                Text(
                  'Total de l\'achat : ${formatCurrency(_total, _devise.code)}',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: WanzoSpacing.md),
                SupplierPickerField(
                  controller: _supplierNameController,
                  phoneController: _supplierPhoneController,
                  label: _paid ? 'Fournisseur (optionnel)' : 'Fournisseur',
                  hint: 'Rechercher ou créer un fournisseur',
                  onSelected: (s) => setState(() => _supplier = s),
                  // À payer = dette : il faut savoir envers qui.
                  validator: (_) => !_paid && _supplier == null
                      ? 'Choisissez le fournisseur à payer.'
                      : null,
                ),
                const SizedBox(height: WanzoSpacing.md),
                SegmentedButton<bool>(
                  segments: const [
                    ButtonSegment(
                      value: true,
                      label: Text('Payé'),
                      icon: Icon(Icons.check_circle_outline),
                    ),
                    ButtonSegment(
                      value: false,
                      label: Text('À payer'),
                      icon: Icon(Icons.schedule),
                    ),
                  ],
                  selected: {_paid},
                  onSelectionChanged: (v) => setState(() => _paid = v.first),
                ),
                if (_paid) ...[
                  const SizedBox(height: WanzoSpacing.md),
                  DropdownButtonFormField<String>(
                    value: _method,
                    decoration: const InputDecoration(
                      labelText: 'Mode de paiement',
                      border: OutlineInputBorder(),
                    ),
                    items: kPaymentMethodOptions
                        .map(
                          (m) => DropdownMenuItem(value: m, child: Text(m)),
                        )
                        .toList(),
                    onChanged: (v) => setState(() => _method = v),
                    validator: (v) =>
                        v == null ? 'Indiquez le mode de paiement.' : null,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _envoi ? null : () => Navigator.of(context).pop(false),
          child: const Text('Annuler'),
        ),
        FilledButton.icon(
          onPressed: _envoi ? null : _submit,
          icon: _envoi
              ? const SizedBox.square(
                  dimension: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.add_shopping_cart),
          label: const Text('Réapprovisionner'),
        ),
      ],
    );
  }
}
