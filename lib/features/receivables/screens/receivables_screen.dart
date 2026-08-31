import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../core/services/business_context_service.dart';
import '../../../core/services/currency_service.dart';
import '../../../core/shared_widgets/wanzo_scaffold.dart';
import '../../../core/widgets/desktop/desktop_data_table.dart';
import '../../../core/widgets/desktop/row_actions_menu.dart';
import '../../customer/models/customer.dart';
import '../../customer/repositories/customer_repository.dart';
import '../../sales/models/sale.dart';
import '../../sales/repositories/sales_repository.dart';
import '../utils/receivables_utils.dart';

/// Ligne agrégée de créance : un client et le détail de son solde impayé.
class _ReceivableRow {
  final String customerKey;
  final String customerName;
  final String? phone;
  final Customer? customer;
  final double totalDue;

  /// Montants dus par tranche d'ancienneté (index 0..3, cf. [kAgeingBucketLabels]).
  final List<double> buckets;
  final int invoicesCount;
  final int overdueCount;

  const _ReceivableRow({
    required this.customerKey,
    required this.customerName,
    required this.phone,
    required this.customer,
    required this.totalDue,
    required this.buckets,
    required this.invoicesCount,
    required this.overdueCount,
  });
}

/// Critères de tri disponibles sur l'écran des créances.
enum _ReceivableSort { amount, name, overdue }

/// Écran « Créances clients » : table desktop des clients ayant un solde impayé
/// (ventes en attente / partiellement payées), avec balance âgée et relance.
class ReceivablesScreen extends StatefulWidget {
  const ReceivablesScreen({super.key});

  @override
  State<ReceivablesScreen> createState() => _ReceivablesScreenState();
}

class _ReceivablesScreenState extends State<ReceivablesScreen> {
  late Future<List<_ReceivableRow>> _future;
  _ReceivableSort _sort = _ReceivableSort.amount;
  bool _ascending = false;

  @override
  void initState() {
    super.initState();
    _future = _loadReceivables();
  }

  void _reload() {
    setState(() {
      _future = _loadReceivables();
    });
  }

  Future<List<_ReceivableRow>> _loadReceivables() async {
    final salesRepo = context.read<SalesRepository>();
    final customerRepo = context.read<CustomerRepository>();

    final sales = await salesRepo.getAllSales();
    List<Customer> customers = const [];
    try {
      customers = await customerRepo.getCustomers(forceLocal: true);
    } catch (_) {
      customers = const [];
    }
    final customersById = {for (final c in customers) c.id: c};

    // Regrouper les créances ouvertes par client.
    final Map<String, List<Sale>> byCustomer = {};
    for (final sale in sales) {
      if (!isOpenReceivable(sale)) continue;
      final key = (sale.customerId != null && sale.customerId!.isNotEmpty)
          ? sale.customerId!
          : 'name:${sale.customerName}';
      byCustomer.putIfAbsent(key, () => []).add(sale);
    }

    final rows = <_ReceivableRow>[];
    byCustomer.forEach((key, custSales) {
      final buckets = <double>[0, 0, 0, 0];
      double totalDue = 0;
      int overdueCount = 0;
      for (final sale in custSales) {
        final due = sale.remainingAmountInCdf;
        totalDue += due;
        buckets[ageingBucketIndex(sale)] += due;
        if (isSaleOverdue(sale)) overdueCount++;
      }
      final customer = key.startsWith('name:') ? null : customersById[key];
      rows.add(
        _ReceivableRow(
          customerKey: key,
          customerName: customer?.name ?? custSales.first.customerName,
          phone: customer?.phoneNumber,
          customer: customer,
          totalDue: totalDue,
          buckets: buckets,
          invoicesCount: custSales.length,
          overdueCount: overdueCount,
        ),
      );
    });

    return rows;
  }

  List<_ReceivableRow> _sortedRows(List<_ReceivableRow> rows) {
    final sorted = List<_ReceivableRow>.from(rows);
    int cmp(_ReceivableRow a, _ReceivableRow b) {
      switch (_sort) {
        case _ReceivableSort.amount:
          return a.totalDue.compareTo(b.totalDue);
        case _ReceivableSort.name:
          return a.customerName.toLowerCase().compareTo(
            b.customerName.toLowerCase(),
          );
        case _ReceivableSort.overdue:
          return a.overdueCount.compareTo(b.overdueCount);
      }
    }

    sorted.sort((a, b) => _ascending ? cmp(a, b) : cmp(b, a));
    return sorted;
  }

  @override
  Widget build(BuildContext context) {
    return WanzoScaffold(
      currentIndex: 3, // Regroupé avec les contacts (clients)
      title: 'Créances clients',
      appBarActions: [
        IconButton(
          icon: const Icon(Icons.refresh),
          tooltip: 'Actualiser',
          onPressed: _reload,
        ),
      ],
      body: FutureBuilder<List<_ReceivableRow>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: Text('Erreur de chargement des créances: ${snapshot.error}'),
            );
          }
          final rows = snapshot.data ?? const [];
          if (rows.isEmpty) {
            return _buildEmptyState(context);
          }
          return _buildContent(context, _sortedRows(rows));
        },
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.verified_outlined,
            size: 80,
            color: Colors.green.shade300,
          ),
          const SizedBox(height: 16),
          Text(
            'Aucune créance en cours',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(color: Colors.grey[600]),
          ),
          const SizedBox(height: 8),
          Text(
            'Toutes les ventes sont encaissées.',
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: Colors.grey[500]),
          ),
        ],
      ),
    );
  }

  Widget _buildContent(BuildContext context, List<_ReceivableRow> rows) {
    final theme = Theme.of(context);
    final currencyService = context.read<CurrencyService>();
    final grandTotal = rows.fold<double>(0, (s, r) => s + r.totalDue);
    final overdueDebtors = rows.where((r) => r.overdueCount > 0).length;

    return Column(
      children: [
        // En-tête : total à recouvrer + nombre de débiteurs.
        Container(
          padding: const EdgeInsets.all(16),
          color: theme.colorScheme.errorContainer.withValues(alpha: 0.25),
          child: Row(
            children: [
              _headerStat(
                context,
                icon: Icons.people_alt_outlined,
                label: '${rows.length} débiteur${rows.length > 1 ? 's' : ''}',
              ),
              const SizedBox(width: 24),
              if (overdueDebtors > 0)
                _headerStat(
                  context,
                  icon: Icons.warning_amber_rounded,
                  label:
                      '$overdueDebtors en retard',
                  color: Colors.red,
                ),
              const Spacer(),
              Text(
                'Total à recouvrer : ${currencyService.formatAmount(grandTotal)}',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.error,
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: DesktopDataTable<_ReceivableRow>(
            data: rows,
            searchHint: 'Rechercher un client...',
            searchFilter: (row, query) =>
                row.customerName.toLowerCase().contains(query),
            onRowTap: (row) => _openCustomer(context, row),
            actions: [_buildSortControls(context)],
            exportConfig: DataTableExportConfig(
              title: 'Créances clients',
              fileName: 'creances_clients',
              companyName: BusinessContextService().currentContext?.companyName ?? 'Wanzo',
              rowDataExtractor: (item) {
                final r = item as _ReceivableRow;
                return [
                  r.customerName,
                  r.invoicesCount,
                  currencyService.formatAmount(r.buckets[0]),
                  currencyService.formatAmount(r.buckets[1]),
                  currencyService.formatAmount(r.buckets[2]),
                  currencyService.formatAmount(r.buckets[3]),
                  currencyService.formatAmount(r.totalDue),
                ];
              },
            ),
            exportHeaders: const [
              'Client',
              'Factures',
              '0-30 j',
              '31-60 j',
              '61-90 j',
              '90 j+',
              'Total dû',
            ],
            columns: const [
              DataColumn(label: Text('Client')),
              DataColumn(label: Text('Factures'), numeric: true),
              DataColumn(label: Text('0-30 j'), numeric: true),
              DataColumn(label: Text('31-60 j'), numeric: true),
              DataColumn(label: Text('61-90 j'), numeric: true),
              DataColumn(label: Text('90 j+'), numeric: true),
              DataColumn(label: Text('Total dû'), numeric: true),
              DataColumn(label: Text('Actions')),
            ],
            rowBuilder: (row) => _buildRow(context, row, currencyService),
          ),
        ),
      ],
    );
  }

  Widget _headerStat(
    BuildContext context, {
    required IconData icon,
    required String label,
    Color? color,
  }) {
    final theme = Theme.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 18, color: color ?? theme.colorScheme.onSurface),
        const SizedBox(width: 6),
        Text(
          label,
          style: theme.textTheme.titleSmall?.copyWith(color: color),
        ),
      ],
    );
  }

  Widget _buildSortControls(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.sort, size: 18),
        const SizedBox(width: 6),
        DropdownButton<_ReceivableSort>(
          value: _sort,
          underline: const SizedBox(),
          items: const [
            DropdownMenuItem(
              value: _ReceivableSort.amount,
              child: Text('Montant dû'),
            ),
            DropdownMenuItem(
              value: _ReceivableSort.name,
              child: Text('Nom du client'),
            ),
            DropdownMenuItem(
              value: _ReceivableSort.overdue,
              child: Text('Retards'),
            ),
          ],
          onChanged: (value) {
            if (value != null) setState(() => _sort = value);
          },
        ),
        IconButton(
          icon: Icon(
            _ascending ? Icons.arrow_upward : Icons.arrow_downward,
            size: 18,
          ),
          tooltip: _ascending ? 'Croissant' : 'Décroissant',
          onPressed: () => setState(() => _ascending = !_ascending),
        ),
      ],
    );
  }

  DataRow _buildRow(
    BuildContext context,
    _ReceivableRow row,
    CurrencyService currencyService,
  ) {
    final theme = Theme.of(context);

    Widget bucketCell(int i) {
      final amount = row.buckets[i];
      if (amount <= 0) {
        return Text('—', style: theme.textTheme.bodySmall);
      }
      // La tranche 90j+ est mise en évidence (créance à risque).
      final isRisk = i == 3;
      return Text(
        currencyService.formatAmount(amount),
        style: theme.textTheme.bodySmall?.copyWith(
          color: isRisk ? Colors.red : null,
          fontWeight: isRisk ? FontWeight.w600 : FontWeight.normal,
        ),
      );
    }

    return DataRow(
      cells: [
        DataCell(
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircleAvatar(
                radius: 16,
                backgroundColor: theme.colorScheme.primary.withValues(
                  alpha: 0.15,
                ),
                child: Text(
                  row.customerName.isNotEmpty
                      ? row.customerName[0].toUpperCase()
                      : '?',
                  style: TextStyle(
                    fontSize: 13,
                    color: theme.colorScheme.primary,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  row.customerName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              if (row.overdueCount > 0) ...[
                const SizedBox(width: 8),
                _overduePill(context, row.overdueCount),
              ],
            ],
          ),
        ),
        DataCell(Text('${row.invoicesCount}')),
        DataCell(bucketCell(0)),
        DataCell(bucketCell(1)),
        DataCell(bucketCell(2)),
        DataCell(bucketCell(3)),
        DataCell(
          Text(
            currencyService.formatAmount(row.totalDue),
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.error,
            ),
          ),
        ),
        DataCell(
          RowActionsMenu(
            actions: [
              RowAction(
                label: 'Relancer',
                icon: Icons.notifications_active_outlined,
                onSelected: () => _remind(context, row, currencyService),
              ),
              RowAction(
                label: 'Voir le client',
                icon: Icons.visibility_outlined,
                onSelected: () => _openCustomer(context, row),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _overduePill(BuildContext context, int count) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.red.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.schedule, size: 12, color: Colors.red),
          const SizedBox(width: 4),
          Text(
            '$count en retard',
            style: const TextStyle(
              color: Colors.red,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  void _openCustomer(BuildContext context, _ReceivableRow row) {
    if (row.customer == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Fiche client indisponible pour ce débiteur.'),
        ),
      );
      return;
    }
    context.push('/customers/detail/${row.customer!.id}', extra: row.customer);
  }

  Future<void> _remind(
    BuildContext context,
    _ReceivableRow row,
    CurrencyService currencyService,
  ) async {
    final business =
        BusinessContextService().currentContext?.companyName ??
        BusinessContextService().businessUnitName ??
        'Wanzo';
    final message = buildReminderMessage(
      businessName: business,
      customerName: row.customerName,
      amountDueText: currencyService.formatAmount(row.totalDue),
    );
    await launchWhatsAppOrSms(context, message: message, phone: row.phone);
  }
}
