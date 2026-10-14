import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:uuid/uuid.dart';

import '../../../constants/spacing.dart';
import '../../../core/models/operation_payment.dart';
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
/// Un achat de marchandise fait deux choses : il fait entrer le stock
/// (mouvement « achat ») ET il crée la dépense correspondante (catégorie
/// stock), payée ou à payer au fournisseur. Les deux passent par les blocs
/// existants (AddStockTransaction, AddExpense), rien n'est réimplémenté.
///
/// Renvoie `true` quand le réapprovisionnement a été envoyé.
Future<bool?> showRestockDialog(BuildContext context, Product product) {
  return showDialog<bool>(
    context: context,
    builder: (_) => _RestockDialog(product: product),
  ).then((done) {
    if (done == true && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Réapprovisionnement de ${product.name} enregistré : '
            'stock mis à jour et dépense créée.',
          ),
          backgroundColor: Colors.green,
        ),
      );
    }
    return done;
  });
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

  @override
  void initState() {
    super.initState();
    final cost = widget.product.costPriceInCdf;
    _priceController = TextEditingController(
      text: cost > 0 ? cost.toStringAsFixed(2) : '',
    );
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

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    final product = widget.product;
    final now = DateTime.now();
    final expenseId = const Uuid().v4();

    // 1. Entrée de stock (achat), rattachée à la dépense.
    context.read<InventoryBloc>().add(
      AddStockTransaction(
        StockTransaction(
          id: const Uuid().v4(),
          productId: product.id,
          type: StockTransactionType.purchase,
          quantity: _qty,
          date: now,
          referenceId: expenseId,
          notes: 'Réapprovisionnement ${product.name}',
          unitCostInCdf: _price,
          totalValueInCdf: _total,
          currencyCode: 'CDF',
        ),
      ),
    );

    // 2. Dépense d'achat : payée (avec son mode) ou à payer au fournisseur.
    context.read<ExpenseBloc>().add(
      AddExpense(
        Expense(
          id: expenseId,
          date: now,
          motif: 'Réapprovisionnement ${product.name}',
          amount: _total,
          category: ExpenseCategory.inventory,
          currencyCode: 'CDF',
          supplierId: _supplier?.id,
          supplierName: _supplier?.name,
          paidAmount: _paid ? _total : 0.0,
          paymentStatus:
              _paid ? ExpensePaymentStatus.paid : ExpensePaymentStatus.unpaid,
          paymentMethod: _paid ? _method : null,
          notes: '${_qty.toStringAsFixed(_qty % 1 == 0 ? 0 : 2)} x '
              '${formatCurrency(_price, 'CDF')}',
        ),
      ),
    );

    Navigator.of(context).pop(true);
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
                  decoration: const InputDecoration(
                    labelText: 'Prix d\'achat unitaire',
                    suffixText: 'CDF',
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (_) => setState(() {}),
                  validator: (_) =>
                      _price > 0 ? null : 'Indiquez le prix d\'achat.',
                ),
                const SizedBox(height: WanzoSpacing.sm),
                Text(
                  'Total de l\'achat : ${formatCurrency(_total, 'CDF')}',
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
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Annuler'),
        ),
        FilledButton.icon(
          onPressed: _submit,
          icon: const Icon(Icons.add_shopping_cart),
          label: const Text('Réapprovisionner'),
        ),
      ],
    );
  }
}
