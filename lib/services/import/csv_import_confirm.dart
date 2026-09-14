import 'package:flutter/material.dart';

/// Boîte de confirmation commune aux imports CSV (produits, services) :
/// nombre de lignes prêtes, erreurs (5 premières), Annuler / Importer.
Future<bool> confirmCsvImport(
  BuildContext context, {
  required int successCount,
  required int totalRows,
  required List<String> errors,
  required String noun, // « produit(s) », « service(s) »
}) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Confirmer l\'import'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('$successCount $noun prêt(s) à importer sur $totalRows ligne(s).'),
          if (errors.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              '${errors.length} erreur(s):',
              style: const TextStyle(color: Colors.orange, fontWeight: FontWeight.bold),
            ),
            ...errors.take(5).map(
                  (e) => Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text('• $e', style: const TextStyle(fontSize: 12)),
                  ),
                ),
            if (errors.length > 5)
              Text(
                '... et ${errors.length - 5} autre(s)',
                style: const TextStyle(fontSize: 12, fontStyle: FontStyle.italic),
              ),
          ],
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annuler')),
        FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Importer')),
      ],
    ),
  );
  return ok == true;
}
