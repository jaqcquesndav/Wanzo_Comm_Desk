import 'package:flutter/material.dart';

import '../utils/desktop_modal.dart';
import 'cancel_reason_form.dart';
import 'document_cancellation.dart';

/// Demande le motif d'annulation d'une pièce dans une fenêtre modale
/// (desktop : jamais de feuille du bas). Renvoie le motif, ou null si la
/// fenêtre est fermée.
Future<String?> showCancelDocumentDialog(
  BuildContext context, {
  required CancellableDocument doc,
}) {
  final isSale = doc == CancellableDocument.sale;
  return showDesktopModal<String>(
    context,
    title: isSale ? 'Annuler la vente' : 'Annuler la dépense',
    icon: Icons.block,
    builder:
        (ctx) => CancelReasonForm(
          doc: doc,
          presets: isSale ? kSaleCancelPresets : kExpenseCancelPresets,
          confirmLabel: isSale ? 'Annuler la vente' : 'Annuler la dépense',
          explanation: cancelExplanation(doc),
          onConfirm: (reason) => Navigator.of(ctx).pop(reason),
          onCancel: () => Navigator.of(ctx).pop(),
        ),
  );
}

/// Confirme le rétablissement d'une pièce annulée. Renvoie le motif (vide si
/// aucun), ou null si la fenêtre est fermée.
Future<String?> showRestoreDocumentDialog(
  BuildContext context, {
  required CancellableDocument doc,
}) {
  final isSale = doc == CancellableDocument.sale;
  return showDesktopModal<String>(
    context,
    title: isSale ? 'Rétablir la vente' : 'Rétablir la dépense',
    icon: Icons.restore,
    builder:
        (ctx) => CancelReasonForm(
          doc: doc,
          presets: const [],
          reasonRequired: false,
          confirmLabel: 'Rétablir',
          explanation:
              isSale
                  ? 'La vente reprend sa place dans les totaux, le stock est '
                      'de nouveau sorti et la comptabilité en est informée.'
                  : 'La dépense reprend sa place dans les totaux et la '
                      'comptabilité en est informée.',
          onConfirm: (reason) => Navigator.of(ctx).pop(reason),
          onCancel: () => Navigator.of(ctx).pop(),
        ),
  );
}
