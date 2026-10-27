import '../models/operation_journal_entry.dart';

/// Contre-passation au journal des opérations d'une pièce annulée (vente,
/// dépense) et reprise des écritures si elle est rétablie.
///
/// Les écritures d'origine restent : on ajoute des écritures inverses datées
/// du jour, si bien que chaque total (caisse, ventes, stock) retombe à zéro
/// pour la pièce. Le calcul se fait sur le SOLDE de la pièce par nature,
/// devise et produit : rejouer l'annulation ne contre-passe jamais deux fois.

const kJournalReversalPrefix = 'Annulation ';
const kJournalReinstatementPrefix = 'Rétablissement ';

bool _isCorrection(OperationJournalEntry e) =>
    e.description.startsWith(kJournalReversalPrefix) ||
    e.description.startsWith(kJournalReinstatementPrefix);

String _groupKey(OperationJournalEntry e) =>
    '${e.type.name}|${(e.currencyCode ?? 'CDF').toUpperCase()}|${e.productId ?? ''}';

/// Solde de la pièce par groupe (nature, devise, produit).
Map<String, double> journalNetByGroup(Iterable<OperationJournalEntry> entries) {
  final net = <String, double>{};
  for (final e in entries) {
    net[_groupKey(e)] = (net[_groupKey(e)] ?? 0) + e.amount;
  }
  return net;
}

/// La pièce est-elle déjà soldée au journal (tout contre-passé) ?
bool isJournalNetZero(Iterable<OperationJournalEntry> entries) =>
    journalNetByGroup(entries).values.every((v) => v.abs() < 0.005);

/// Écritures inverses à ajouter pour solder la pièce. Vide si elle l'est déjà.
List<OperationJournalEntry> journalReversalEntries(
  List<OperationJournalEntry> documentEntries, {
  required DateTime at,
  required String Function() newId,
}) {
  final net = journalNetByGroup(documentEntries);
  final out = <OperationJournalEntry>[];
  final seen = <String>{};
  for (final e in documentEntries.where((e) => !_isCorrection(e))) {
    final key = _groupKey(e);
    if (!seen.add(key)) continue;
    final amount = net[key] ?? 0;
    if (amount.abs() < 0.005) continue;
    out.add(
      e.copyWith(
        id: newId(),
        date: at,
        amount: -amount,
        description: '$kJournalReversalPrefix${e.description}',
        isDebit: !e.isDebit,
        isCredit: !e.isCredit,
      ),
    );
  }
  return out;
}

/// Écritures à ajouter pour reprendre une pièce rétablie : les écritures
/// d'origine sont rejouées. Vide si la pièce n'est pas soldée (jamais
/// annulée, ou déjà rétablie).
List<OperationJournalEntry> journalReinstatementEntries(
  List<OperationJournalEntry> documentEntries, {
  required DateTime at,
  required String Function() newId,
}) {
  final originals = documentEntries.where((e) => !_isCorrection(e)).toList();
  if (originals.isEmpty || !isJournalNetZero(documentEntries)) return const [];
  final byGroup = <String, double>{};
  for (final e in originals) {
    byGroup[_groupKey(e)] = (byGroup[_groupKey(e)] ?? 0) + e.amount;
  }
  final out = <OperationJournalEntry>[];
  final seen = <String>{};
  for (final e in originals) {
    final key = _groupKey(e);
    if (!seen.add(key)) continue;
    final amount = byGroup[key] ?? 0;
    if (amount.abs() < 0.005) continue;
    out.add(
      e.copyWith(
        id: newId(),
        date: at,
        amount: amount,
        description: '$kJournalReinstatementPrefix${e.description}',
      ),
    );
  }
  return out;
}
