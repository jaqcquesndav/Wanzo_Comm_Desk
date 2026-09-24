import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:wanzo/core/services/business_context_service.dart';
import 'package:wanzo/core/utils/currency_formatter.dart';
import 'package:wanzo/services/export/table_export_service.dart';

import '../models/stylist.dart';
import '../models/stylist_statement.dart';
import '../services/salon_api_service.dart';

/// Relevé de compte d'un coiffeur, et son export.
///
/// La question de fin de mois est toujours la même : combien a-t-il gagné,
/// combien a-t-il déjà pris, que reste-t-il à lui verser. Les deux côtés
/// vivaient dans des écrans différents (ses commissions d'un côté, les dépenses
/// de l'autre) et ne se rencontraient jamais. Ils sont réunis ici.
Future<void> showStylistStatement(
  BuildContext context,
  Stylist stylist, {
  DateTime? from,
  DateTime? to,
}) async {
  final start = from ?? DateTime(DateTime.now().year, DateTime.now().month, 1);
  final end = to ?? DateTime.now();
  await showDialog<void>(
    context: context,
    builder: (_) => _StatementDialog(stylist: stylist, from: start, to: end),
  );
}

class _StatementDialog extends StatefulWidget {
  const _StatementDialog({
    required this.stylist,
    required this.from,
    required this.to,
  });

  final Stylist stylist;
  final DateTime from;
  final DateTime to;

  @override
  State<_StatementDialog> createState() => _StatementDialogState();
}

class _StatementDialogState extends State<_StatementDialog> {
  final _api = SalonApiService();
  final _dateFmt = DateFormat('dd/MM/yyyy');
  final _nombreFmt = NumberFormat('#,##0', 'fr_FR');

  StylistStatement? _statement;
  bool _loading = true;
  String? _error;
  late DateTime _from = widget.from;
  late DateTime _to = widget.to;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final s = await _api.getPerformerStatement(
        widget.stylist.id,
        from: _from,
        to: _to,
      );
      if (!mounted) return;
      setState(() {
        _statement = s;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = "Le relevé n'a pas pu être chargé.";
      });
    }
  }

  Future<void> _pickPeriod() async {
    final range = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 1)),
      initialDateRange: DateTimeRange(start: _from, end: _to),
      locale: const Locale('fr', 'FR'),
    );
    if (range == null) return;
    setState(() {
      _from = range.start;
      _to = range.end;
    });
    await _load();
  }

  /// Le relevé tel qu'on le remet au coiffeur : le compte, ligne à ligne,
  /// dans l'ordre du temps, avec le solde après chaque mouvement. Ce qui est
  /// exporté est exactement ce qui est affiché.
  TableExportConfig _exportConfig() {
    final s = _statement!;
    final lignes = s.ledger;
    return TableExportConfig(
      title: 'Relevé de compte — ${s.stylistName}',
      subtitle: 'Du ${_dateFmt.format(_from)} au ${_dateFmt.format(_to)} '
          '(montants en CDF)',
      headers: const ['Date', 'Libellé', 'Nature', 'Gagné', 'Versé', 'Solde'],
      rows: [
        for (final l in lignes)
          [
            l.date == null ? '' : _dateFmt.format(l.date!),
            l.libelle,
            l.nature,
            l.credit == 0 ? '' : _montant(l.credit),
            l.debit == 0 ? '' : _montant(l.debit),
            _montant(l.solde),
          ],
        [
          '',
          'TOTAL',
          '',
          _montant(s.totalCommission),
          _montant(s.advancesTotal),
          _montant(s.balance),
        ],
      ],
      fileName: 'releve_${s.stylistName.replaceAll(' ', '_').toLowerCase()}',
      companyName: BusinessContextService().currentContext?.companyName,
      generatedAt: DateTime.now(),
    );
  }

  Future<void> _export(ExportFormat format) async {
    if (_statement == null) return;
    await TableExportService().export(
      context: context,
      config: _exportConfig(),
      format: format,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AlertDialog(
      title: Row(
        children: [
          Expanded(child: Text('Compte de ${widget.stylist.name}')),
          IconButton(
            tooltip: 'Changer la période',
            icon: const Icon(Icons.date_range),
            onPressed: _loading ? null : _pickPeriod,
          ),
        ],
      ),
      content: SizedBox(
        // Sur téléphone la largeur fixe déborderait : on suit l'écran.
        width: MediaQuery.of(context).size.width.clamp(280.0, 640.0),
        child: _loading
            ? const SizedBox(
                height: 160,
                child: Center(child: CircularProgressIndicator()),
              )
            : _error != null
                ? SizedBox(height: 120, child: Center(child: Text(_error!)))
                : _body(theme),
      ),
      actions: [
        if (!_loading && _error == null && _statement != null) ...[
          TextButton.icon(
            onPressed: () => _export(ExportFormat.pdf),
            icon: const Icon(Icons.picture_as_pdf_outlined, size: 18),
            label: const Text('PDF'),
          ),
          TextButton.icon(
            onPressed: () => _export(ExportFormat.xlsx),
            icon: const Icon(Icons.table_view_outlined, size: 18),
            label: const Text('Excel'),
          ),
        ],
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Fermer'),
        ),
      ],
    );
  }

  Widget _body(ThemeData theme) {
    final s = _statement!;
    final lignes = s.ledger;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Entête de relevé : la période et où l'on aboutit. Le détail est
        // dans le tableau, pas dans une rangée de vignettes.
        Text(
          'Du ${_dateFmt.format(_from)} au ${_dateFmt.format(_to)}'
          '  ·  ${s.servicesCount} prestation${s.servicesCount > 1 ? 's' : ''}',
          style: theme.textTheme.bodySmall
              ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
        ),
        const SizedBox(height: 4),
        Text.rich(
          TextSpan(
            style: theme.textTheme.bodyMedium,
            children: [
              TextSpan(
                text: s.balance >= 0 ? 'Reste à verser ' : 'Trop perçu ',
              ),
              TextSpan(
                text: formatCurrency(s.balance.abs(), 'CDF'),
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: s.balance >= 0
                      ? theme.colorScheme.primary
                      : theme.colorScheme.error,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        if (lignes.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 28),
            child: Text(
              'Aucun mouvement sur la période.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
          )
        else
          Flexible(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: ConstrainedBox(
                constraints: const BoxConstraints(minWidth: 460),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _enTete(theme),
                    const Divider(height: 1, thickness: 1),
                    Flexible(
                      child: SingleChildScrollView(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            for (var i = 0; i < lignes.length; i++)
                              _ligne(theme, lignes[i], pair: i.isEven),
                          ],
                        ),
                      ),
                    ),
                    const Divider(height: 1, thickness: 1),
                    _total(theme, s),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }

  /// Largeurs de colonnes partagées par l'entête, les lignes et le total :
  /// c'est ce qui fait tenir les chiffres les uns sous les autres.
  static const _colonnes = <int>[74, 150, 84, 84, 88];

  Widget _cellule(String texte, int largeur,
      {TextStyle? style, TextAlign align = TextAlign.left}) {
    return SizedBox(
      width: largeur.toDouble(),
      child: Text(
        texte,
        style: style,
        textAlign: align,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }

  Widget _enTete(ThemeData theme) {
    final style = theme.textTheme.labelSmall?.copyWith(
      fontWeight: FontWeight.w700,
      color: theme.colorScheme.onSurfaceVariant,
    );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          _cellule('Date', _colonnes[0], style: style),
          _cellule('Libellé', _colonnes[1], style: style),
          _cellule('Gagné', _colonnes[2],
              style: style, align: TextAlign.right),
          _cellule('Versé', _colonnes[3],
              style: style, align: TextAlign.right),
          _cellule('Solde', _colonnes[4],
              style: style, align: TextAlign.right),
        ],
      ),
    );
  }

  Widget _ligne(ThemeData theme, StylistLedgerLine l, {required bool pair}) {
    final corps = theme.textTheme.bodySmall;
    final chiffres = corps?.copyWith(
      fontFeatures: const [FontFeature.tabularFigures()],
    );
    return Container(
      color: pair
          ? Colors.transparent
          : theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          _cellule(l.date == null ? '' : _dateFmt.format(l.date!), _colonnes[0],
              style: chiffres),
          SizedBox(
            width: _colonnes[1].toDouble(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(l.libelle,
                    style: corps,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
                Text(
                  l.nature,
                  style: theme.textTheme.labelSmall
                      ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          _cellule(l.credit == 0 ? '' : _montant(l.credit), _colonnes[2],
              style: chiffres, align: TextAlign.right),
          _cellule(l.debit == 0 ? '' : _montant(l.debit), _colonnes[3],
              style: chiffres?.copyWith(color: theme.colorScheme.error),
              align: TextAlign.right),
          _cellule(_montant(l.solde), _colonnes[4],
              style: chiffres?.copyWith(fontWeight: FontWeight.w700),
              align: TextAlign.right),
        ],
      ),
    );
  }

  Widget _total(ThemeData theme, StylistStatement s) {
    final style = theme.textTheme.bodySmall?.copyWith(
      fontWeight: FontWeight.w700,
      fontFeatures: const [FontFeature.tabularFigures()],
    );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 9),
      child: Row(
        children: [
          _cellule('', _colonnes[0]),
          _cellule('TOTAL', _colonnes[1], style: style),
          _cellule(_montant(s.totalCommission), _colonnes[2],
              style: style, align: TextAlign.right),
          _cellule(_montant(s.advancesTotal), _colonnes[3],
              style: style, align: TextAlign.right),
          _cellule(
            _montant(s.balance),
            _colonnes[4],
            style: style?.copyWith(
              color: s.balance >= 0
                  ? theme.colorScheme.primary
                  : theme.colorScheme.error,
            ),
            align: TextAlign.right,
          ),
        ],
      ),
    );
  }

  /// Dans un tableau la devise est dans le sous-titre, pas sur chaque ligne :
  /// répéter le code cinquante fois empêche de comparer les colonnes.
  String _montant(double v) => _nombreFmt.format(v);
}
