import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/navigation/app_router.dart';
import '../models/operation_journal_entry.dart';

/// Ouvre la PIÈCE derrière une ligne du journal des opérations.
///
/// Une ligne de journal est le reflet d'un document : une vente, une dépense,
/// un règlement. Taper dessus n'ouvrait qu'une fiche répétant les colonnes déjà
/// visibles, alors que la question qu'on se pose devant une ligne est toujours
/// « c'était quoi, cette vente ? ». On va donc au document quand on sait le
/// retrouver, et on garde la fiche de détail pour les lignes qui n'en ont pas
/// (mouvements de stock, financement).
///
/// Retourne `true` si un document a été ouvert.
bool openJournalOperationDocument(
  BuildContext context,
  OperationJournalEntry operation,
) {
  final id = operation.relatedDocumentId?.trim() ?? '';
  if (id.isEmpty) return false;

  switch (operation.type) {
    case OperationType.saleCash:
    case OperationType.saleCredit:
    case OperationType.saleInstallment:
    // Un règlement client se rapporte à la vente qu'il solde : c'est elle que
    // l'on veut relire.
    case OperationType.customerPayment:
      context.pushNamed(
        AppRoute.saleDetail.name,
        pathParameters: {'id': id},
      );
      return true;
    case OperationType.cashOut:
    case OperationType.supplierPayment:
      context.pushNamed(
        AppRoute.expenseDetail.name,
        pathParameters: {'id': id},
      );
      return true;
    case OperationType.stockIn:
    case OperationType.stockOut:
    case OperationType.cashIn:
    case OperationType.financingRequest:
    case OperationType.financingApproved:
    case OperationType.financingRepayment:
    case OperationType.other:
      // Pas de document propre à ouvrir : la fiche de détail reste la réponse.
      return false;
  }
}
