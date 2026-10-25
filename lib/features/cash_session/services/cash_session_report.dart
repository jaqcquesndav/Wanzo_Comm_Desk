import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../models/cash_session.dart';

final _num = NumberFormat('#,##0.##', 'fr');
final _dt = DateFormat('dd/MM/yyyy HH:mm');

String cashAmount(double v, String currency) => '${_num.format(v)} $currency';

/// Montants par devise lus d'un JSON ({ CDF: 1000, USD: 2 }).
Map<String, double> cashAmountsOf(dynamic raw) {
  if (raw is! Map) return const {};
  final out = <String, double>{};
  raw.forEach((k, v) {
    final n = v is num ? v.toDouble() : double.tryParse('$v');
    if (n != null) out[k.toString()] = n;
  });
  return out;
}

String _row(String left, String right, int width) {
  final space = width - right.length;
  final l = left.length > space - 1 ? left.substring(0, (space - 1).clamp(0, left.length)) : left;
  return '${l.padRight(space)}$right';
}

/// Lignes du rapport de clôture (ticket Z), largeur [width] caractères.
List<String> zTicketLines(
  CashSession s, {
  String? companyName,
  int width = 32,
}) {
  final sep = '-' * width;
  final lines = <String>[
    if (companyName != null && companyName.isNotEmpty) companyName.toUpperCase(),
    'CLOTURE DE CAISSE',
    if (s.registerLabel != null) s.registerLabel!,
    sep,
    'Ouverture : ${_dt.format(s.openedAt)}',
    if (s.openedByName != null) 'Par : ${s.openedByName}',
    if (s.closedAt != null) 'Cloture  : ${_dt.format(s.closedAt!)}',
    if (s.closedByName != null) 'Par : ${s.closedByName}',
    sep,
    'FONDS D\'OUVERTURE',
    if (s.openingFloat.isEmpty) _row('Aucun', '0', width),
    for (final e in s.openingFloat.entries) _row(e.key, cashAmount(e.value, e.key), width),
    sep,
    'ENCAISSEMENTS (${s.salesCount} vente(s))',
  ];
  final receipts = s.receiptsByMethod();
  if (receipts.isEmpty) lines.add(_row('Aucun', '0', width));
  for (final g in CashMethodGroup.values) {
    final byCur = receipts[g];
    if (byCur == null) continue;
    for (final e in byCur.entries) {
      lines.add(_row(g.label, cashAmount(e.value, e.key), width));
    }
  }
  // Ventes non encaissées : information seulement, jamais dans les especes.
  final credit = s.creditGranted();
  if (credit.isNotEmpty) {
    lines
      ..add(sep)
      ..add('CREDIT ACCORDE (non encaisse)');
    for (final e in credit.entries) {
      lines.add(_row('Credit accorde', cashAmount(e.value, e.key), width));
    }
  }
  final expenses = s.totalOf(CashMovementKind.expense, cashOnly: true);
  final ins = s.totalOf(CashMovementKind.manualIn);
  final outs = s.totalOf(CashMovementKind.manualOut);
  final deposits = s.totalOf(CashMovementKind.bankDeposit);
  lines
    ..add(sep)
    ..add('MOUVEMENTS D\'ESPECES');
  for (final e in expenses.entries) {
    lines.add(_row('Depenses payees', cashAmount(e.value, e.key), width));
  }
  for (final e in ins.entries) {
    lines.add(_row('Entrees', cashAmount(e.value, e.key), width));
  }
  for (final e in deposits.entries) {
    lines.add(_row('Depots en banque', cashAmount(e.value, e.key), width));
  }
  for (final e in outs.entries) {
    lines.add(_row('Autres sorties', cashAmount(e.value, e.key), width));
  }
  if (expenses.isEmpty && ins.isEmpty && outs.isEmpty && deposits.isEmpty) lines.add(_row('Aucun', '0', width));
  // Dépôt refusé par le serveur : sorti du tiroir mais pas comptabilisé.
  for (final m in s.notPostedDeposits) {
    lines
      ..add(_row('Depot NON COMPTABILISE', cashAmount(m.amount, m.currency), width))
      ..add('  ${m.syncIssue}');
  }

  final expected = s.expected ?? s.expectedCash();
  lines
    ..add(sep)
    ..add('ESPECES PAR DEVISE');
  for (final code in expected.keys) {
    final exp = expected[code] ?? 0;
    final cnt = s.counted?[code];
    final diff = s.difference?[code];
    lines.add(_row('Theorique $code', cashAmount(exp, code), width));
    if (cnt != null) lines.add(_row('Compte $code', cashAmount(cnt, code), width));
    if (diff != null) lines.add(_row('Ecart $code', cashAmount(diff, code), width));
  }
  if (s.differenceReason != null) {
    lines
      ..add(sep)
      ..add('Motif de l\'ecart :')
      ..add(s.differenceReason!);
  }
  // Clôture déjà enregistrée sur le serveur par quelqu'un d'autre.
  final srv = s.serverClosure;
  if (srv != null) {
    lines
      ..add(sep)
      ..add('DEJA CLOTUREE SUR LE SERVEUR');
    if (srv['closedByName'] != null) lines.add('Par : ${srv['closedByName']}');
    final at = DateTime.tryParse('${srv['closedAt']}')?.toLocal();
    if (at != null) lines.add('Le : ${_dt.format(at)}');
    for (final e in cashAmountsOf(srv['counted']).entries) {
      lines.add(_row('Compte serveur ${e.key}', cashAmount(e.value, e.key), width));
    }
    for (final e in cashAmountsOf(srv['difference']).entries) {
      lines.add(_row('Ecart serveur ${e.key}', cashAmount(e.value, e.key), width));
    }
    for (final e in cashAmountsOf(srv['countGap']).entries) {
      if (e.value.abs() < 0.01) continue;
      lines.add(_row('A corriger ${e.key}', cashAmount(e.value, e.key), width));
    }
  }
  lines
    ..add(sep)
    ..add('Signature caissier :')
    ..add('')
    ..add('Signature responsable :')
    ..add('');
  return lines;
}

/// Même rapport en PDF (ticket ou A4), pour l'impression système ou le
/// partage.
pw.Document zTicketPdf(
  CashSession s,
  PdfPageFormat format, {
  String? companyName,
}) {
  final width = format.width < 200 ? 32 : 48;
  final lines = zTicketLines(s, companyName: companyName, width: width);
  final doc = pw.Document();
  final font = pw.Font.courier();
  final bold = pw.Font.courierBold();
  final page = format.copyWith(marginLeft: 6, marginRight: 6, marginTop: 8, marginBottom: 8);
  final children = <pw.Widget>[
        for (final l in lines)
          pw.Text(
            l,
            style: pw.TextStyle(
              font: l.toUpperCase() == l && l.trim().isNotEmpty && !l.startsWith('-') ? bold : font,
              fontSize: format.width < 200 ? 7.5 : 10,
            ),
          ),
  ];
  // Rouleau (hauteur infinie) : une seule page qui s'allonge.
  if (format.height == double.infinity) {
    doc.addPage(pw.Page(pageFormat: page, build: (_) => pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: children)));
  } else {
    doc.addPage(pw.MultiPage(pageFormat: page, build: (_) => children));
  }
  return doc;
}
