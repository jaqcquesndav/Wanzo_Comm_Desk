import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../core/navigation/app_router.dart';
import '../../expenses/repositories/expense_repository.dart';
import '../../sales/repositories/sales_repository.dart';
import '../models/operation_journal_entry.dart';

/// Ouvre la PIÈCE derrière une ligne du journal des opérations.
///
/// Une ligne de journal est le reflet d'un document : une vente, une dépense,
/// un règlement, un mouvement de stock. Taper dessus ouvre ce document :
///  - vente, règlement client, encaissement : la vente (sinon la fiche client) ;
///  - dépense, règlement fournisseur : la dépense (sinon le fournisseur) ;
///  - entrée ou sortie de stock : la fiche produit.
/// La pièce est cherchée dans les données locales avant d'y aller : une ligne
/// dont la pièce a disparu (dépense supprimée) affiche un message au lieu
/// d'ouvrir une fiche vide. Jamais de clic muet.
Future<void> openJournalOperationDocument(
  BuildContext context,
  OperationJournalEntry operation,
) async {
  final id = operation.relatedDocumentId?.trim() ?? '';
  final productId = operation.productId?.trim() ?? '';
  final customerId = operation.customerId?.trim() ?? '';
  final supplierId = operation.supplierId?.trim() ?? '';

  // Mouvement de stock : la fiche produit répond à « quel article ? ».
  if (operation.type == OperationType.stockIn ||
      operation.type == OperationType.stockOut) {
    if (productId.isNotEmpty) {
      context.push('/inventory/product/$productId');
      return;
    }
    _noDocument(context);
    return;
  }

  if (id.isNotEmpty) {
    if (await _saleExists(context, id)) {
      if (!context.mounted) return;
      context.pushNamed(AppRoute.saleDetail.name, pathParameters: {'id': id});
      return;
    }
    if (!context.mounted) return;
    if (await _expenseExists(context, id)) {
      if (!context.mounted) return;
      context.pushNamed(
        AppRoute.expenseDetail.name,
        pathParameters: {'id': id},
      );
      return;
    }
  }
  if (!context.mounted) return;

  // Règlement fournisseur ou sortie de caisse sans dépense retrouvée : la
  // fiche du fournisseur (comme sur le mobile).
  final isSupplierSide =
      operation.type == OperationType.supplierPayment ||
      operation.type == OperationType.cashOut;
  if (isSupplierSide && supplierId.isNotEmpty) {
    context.push('/suppliers/detail/$supplierId');
    return;
  }

  // Règlement ou encaissement sans vente retrouvée : la fiche du client.
  if (customerId.isNotEmpty) {
    context.push('/customers/detail/$customerId');
    return;
  }
  if (supplierId.isNotEmpty) {
    context.push('/suppliers/detail/$supplierId');
    return;
  }
  _noDocument(context);
}

Future<bool> _saleExists(BuildContext context, String id) async {
  try {
    return await context.read<SalesRepository>().getSaleById(id) != null;
  } catch (_) {
    return false;
  }
}

Future<bool> _expenseExists(BuildContext context, String id) async {
  try {
    return await context.read<ExpenseRepository>().getExpenseById(id) != null;
  } catch (_) {
    return false;
  }
}

void _noDocument(BuildContext context) {
  ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(
      content: Text(
        'Cette ligne n\'a pas de pièce à ouvrir (pièce supprimée ou '
        'opération sans document).',
      ),
    ),
  );
}
