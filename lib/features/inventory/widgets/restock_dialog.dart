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
import '../../../core/units/measurement_units.dart';
import '../../../core/units/unit_fields.dart';

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
    // Pas de fermeture par clic extérieur pendant l'envoi de la dépense.
    barrierDismissible: false,
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

  /// Dépense déjà enregistrée : une nouvelle tentative ne rejoue que le stock.
  Expense? _depenseEnregistree;

  /// Devise du prix d'achat, choisie une fois (devise active des réglages
  /// si son taux existe, sinon CDF) ; jamais réécrite par une reconstruction.
  late Currency _devise;

  /// Unité d'achat : carton, demi-carton ou pièce. Quantité et prix saisis
  /// dans cette unité ; le stock reçoit quantité x facteur cartons.
  late SellableUnit _unite = widget.product.sellableUnits.first;

  void _choisirUnite(SellableUnit u) {
    final ancien = _unite.factor;
    setState(() {
      _unite = u;
      // Prix proposé : celui de l'unité précédente ramené au nouveau contenu.
      if (_price > 0 && ancien > 0) {
        final p = _price / ancien * u.factor;
        _priceController.text = p.toStringAsFixed(2);
      }
    });
  }

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
    // Devise étrangère sans taux : refus, jamais un taux 1 muet. Reprise du
    // stock : taux figé sur la dépense déjà enregistrée.
    final taux = _depenseEnregistree?.exchangeRate ??
        context.read<CurrencyService>().usableRateToCdfForCode(code);
    if (taux == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(CurrencyService.missingRateMessage(code))),
      );
      return;
    }
    // Prix en francs anormalement bas : sans doute des dollars (une seule
    // fois, pas à la reprise du stock).
    final choix = _depenseEnregistree != null
        ? ChoixDevisePrix.garder
        : await verifierPrixSaisi(context, prix: _price, codeDevise: code);
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
    // Nom saisi sans fiche choisie : gardé sur la dépense (comme le mobile).
    final nomSaisi = _supplierNameController.text.trim();
    final nomFournisseur =
        _supplier?.name ?? (nomSaisi.isEmpty ? null : nomSaisi);

    // 1. La dépense d'achat D'ABORD : payée (avec son mode) ou à payer au
    // fournisseur. Son identifiant serveur rattache ensuite le stock. Une
    // reprise (stock refusé) ne la recrée pas.
    var depense = _depenseEnregistree;
    if (depense == null) {
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
            supplierName: nomFournisseur,
            paidAmount: _paid ? _total : 0.0,
            paymentStatus:
                _paid ? ExpensePaymentStatus.paid : ExpensePaymentStatus.unpaid,
            paymentMethod: _paid ? _method : null,
            notes: '${lineQuantityLabel(_qty, _unite.code, _unite.factor)} x '
                '${formatCurrency(_price, code)}',
          ),
          saved: depenseEnregistree,
        ),
      );
      try {
        depense = await depenseEnregistree.future.timeout(
          const Duration(seconds: 45),
        );
      } catch (e) {
        if (!mounted) return;
        setState(() => _envoi = false);
        final motif = e is TimeoutException
            ? 'pas de réponse. Vérifiez la liste des dépenses avant de '
                'réessayer.'
            : '$e'.replaceFirst('Exception: ', '');
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
      if (!mounted) return;
      setState(() => _depenseEnregistree = depense);
    }
    final achat = depense;

    // 2. L'entrée de stock. Dépense acceptée par le serveur : achat rattaché
    // (le serveur passe 311 / 6031, pas une seconde dette). Dépense en
    // attente du réseau (pas encore d'identifiant serveur) : stock appliqué
    // en local, l'achat est gardé et part avec l'id serveur de la dépense.
    // Le coût est valorisé au taux FIGÉ de la dépense.
    final tauxAchat = achat.exchangeRate ?? taux;
    final surServeur = achat.syncStatus == 'synced';
    final mouvement = StockTransaction(
      id: const Uuid().v4(),
      productId: product.id,
      type: StockTransactionType.purchase,
      // En unités de base : 3 cartons de 24 = 72, coût du carton / 24.
      quantity: MeasurementUnits.toBase(_qty, _unite.factor),
      date: now,
      referenceId: achat.id,
      notes: _unite.isBase
          ? 'Réapprovisionnement ${product.name}'
          : 'Réapprovisionnement ${product.name} : '
              '${lineQuantityLabel(_qty, _unite.code, _unite.factor)}',
      unitCostInCdf: _price * tauxAchat / _unite.factor,
      totalValueInCdf: _total * tauxAchat,
      currencyCode: 'CDF',
    );
    final issue = Completer<String?>();
    inventoryBloc.add(
      AddStockTransaction(
        mouvement,
        expenseId: surServeur ? achat.id : null,
        awaitingExpenseId: surServeur ? null : achat.id,
        serverOutcome: issue,
      ),
    );
    final refus = await issue.future;
    if (!mounted) return;

    if (refus != null) {
      // La dépense existe, le stock non (rien n'a bougé sur l'appareil) :
      // la saisie est figée et « Réessayer le stock » ne rejoue que lui.
      setState(() => _envoi = false);
      messenger.showSnackBar(
        SnackBar(
          duration: const Duration(seconds: 10),
          backgroundColor: Colors.red,
          content: Text(
            'La dépense est enregistrée, mais le stock de ${product.name} '
            "n'a pas été mis à jour : $refus Utilisez « Réessayer le stock ».",
          ),
        ),
      );
      return;
    }

    Navigator.of(context).pop(true);
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
          // Dépense enregistrée : la saisie est figée, seul le stock se rejoue.
          child: AbsorbPointer(
            absorbing: _depenseEnregistree != null,
            child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Stock actuel : ${product.stockLabel}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: WanzoSpacing.md),
                // Acheté au carton, au demi-carton ou à l'unité.
                SellableUnitSelector(
                  units: product.sellableUnits,
                  selectedKey: _unite.key,
                  onChanged: _choisirUnite,
                ),
                if (product.sellableUnits.length > 1)
                  const SizedBox(height: WanzoSpacing.md),
                TextFormField(
                  controller: _qtyController,
                  autofocus: true,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  inputFormatters: [numberFormatter],
                  decoration: InputDecoration(
                    labelText: 'Quantité reçue',
                    suffixText: _unite.label,
                    helperText: _unite.isBase || _qty <= 0
                        ? null
                        : '= ${MeasurementUnits.formatStockBreakdown(MeasurementUnits.toBase(_qty, _unite.factor), product.baseUnitCode, product.unitOptions)}',
                    border: const OutlineInputBorder(),
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
                    labelText: _unite.isBase
                        ? 'Prix d\'achat unitaire'
                        : 'Prix d\'achat par ${_unite.label.toLowerCase()}',
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
      ),
      actions: [
        TextButton(
          // Dépense déjà enregistrée : on ferme, on n'annule plus rien.
          onPressed: _envoi
              ? null
              : () => Navigator.of(context).pop(_depenseEnregistree != null),
          child: Text(_depenseEnregistree != null ? 'Fermer' : 'Annuler'),
        ),
        FilledButton.icon(
          onPressed: _envoi ? null : _submit,
          icon: _envoi
              ? const SizedBox.square(
                  dimension: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.add_shopping_cart),
          label: Text(
            _depenseEnregistree != null
                ? 'Réessayer le stock'
                : 'Réapprovisionner',
          ),
        ),
      ],
    );
  }
}
