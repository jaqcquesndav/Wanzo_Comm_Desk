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

  /// Le relevé tel qu'on le remet au coiffeur : les sommes versées, précédées
  /// de la synthèse. Même contenu en PDF et en tableur.
  TableExportConfig _exportConfig() {
    final s = _statement!;
    return TableExportConfig(
      title: 'Relevé de compte — ${s.stylistName}',
      subtitle:
          'Du ${_dateFmt.format(_from)} au ${_dateFmt.format(_to)}\n'
          'Commissions ${formatCurrency(s.totalCommission, 'CDF')} · '
          'Avances ${formatCurrency(s.advancesTotal, 'CDF')} · '
          'Solde ${formatCurrency(s.balance, 'CDF')}',
      headers: const ['Date', 'Motif', 'Nature', 'Montant'],
      rows: [
        for (final a in s.advances)
          [
            a.date == null ? '' : _dateFmt.format(a.date!),
            a.motif,
            a.subCategory ?? '',
            formatCurrency(a.amount, a.currencyCode ?? 'CDF'),
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
        width: 640,
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
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Du ${_dateFmt.format(_from)} au ${_dateFmt.format(_to)}',
            style: theme.textTheme.bodySmall
                ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _fact('Prestations', '${s.servicesCount}'),
              _fact('Chiffre réalisé',
                  formatCurrency(s.serviceRevenue + s.retailRevenue, 'CDF')),
              _fact('Commissions', formatCurrency(s.totalCommission, 'CDF')),
              _fact('Avances versées', formatCurrency(s.advancesTotal, 'CDF')),
              _fact(
                s.balance >= 0 ? 'Reste à verser' : 'Trop perçu',
                formatCurrency(s.balance.abs(), 'CDF'),
                color: s.balance >= 0
                    ? theme.colorScheme.primary
                    : theme.colorScheme.error,
              ),
            ],
          ),
          const SizedBox(height: 18),
          Align(
            alignment: Alignment.centerLeft,
            child: Text('Sommes déjà versées',
                style: theme.textTheme.titleSmall
                    ?.copyWith(fontWeight: FontWeight.w700)),
          ),
          const SizedBox(height: 6),
          if (s.advances.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Text(
                'Aucune avance sur la période.',
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
            )
          else
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 240),
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: s.advances.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (context, i) {
                  final a = s.advances[i];
                  return ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    title: Text(a.motif),
                    subtitle: Text([
                      if (a.date != null) _dateFmt.format(a.date!),
                      if ((a.subCategory ?? '').isNotEmpty) a.subCategory!,
                    ].join(' · ')),
                    trailing: Text(
                      formatCurrency(a.amount, a.currencyCode ?? 'CDF'),
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }

  Widget _fact(String label, String value, {Color? color}) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: (color ?? theme.colorScheme.primary).withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label,
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
          const SizedBox(height: 2),
          Text(
            value,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
              color: color ?? theme.colorScheme.primary,
            ),
          ),
        ],
      ),
    );
  }
}
