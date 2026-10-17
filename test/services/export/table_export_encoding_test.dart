import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:wanzo/services/export/table_export_service.dart';
import 'package:wanzo/services/journal_export_service.dart';

/// Exports de tables et du journal : encodage CSV, texte PDF, nom de fichier.
void main() {
  group('CSV', () {
    test('UTF-8 avec BOM : les montants formatés en français restent '
        'intacts', () {
      // NumberFormat fr sépare les milliers par une espace fine insécable.
      const csv = 'Montant,Devise\n1\u202F250\u202F000 FC,CDF\nDépôt,USD\n';
      final bytes = TableExportService.encodeCsvUtf8(csv);

      expect(bytes.sublist(0, 3), [0xEF, 0xBB, 0xBF]);
      final decoded = utf8.decode(bytes.sublist(3));
      expect(decoded, csv);
      // L'ancien encodage (codeUnits tronqués) produisait « 1/250/000 ».
      expect(decoded.contains('1/250'), isFalse);
    });
  });

  group('PDF', () {
    test('espaces insécables et signes typographiques remplacés', () {
      expect(
        TableExportService.pdfSafeText('1\u202F250\u00A0FC \u2014 l\u2019état\u2026'),
        "1 250 FC - l'état...",
      );
    });

    test('texte Latin-1 inchangé', () {
      expect(TableExportService.pdfSafeText('Dépenses à payer'), 'Dépenses à payer');
    });
  });

  group('Nom du fichier du journal', () {
    test('chemin Windows : seul le nom du fichier est gardé', () {
      expect(
        JournalExportService.fileBaseName(
          r'C:\Users\x\AppData\Local\Temp\journal_ABC.pdf',
        ),
        'journal_ABC.pdf',
      );
    });

    test('chemin POSIX', () {
      expect(
        JournalExportService.fileBaseName('/tmp/journal_ABC.pdf'),
        'journal_ABC.pdf',
      );
    });
  });
}
