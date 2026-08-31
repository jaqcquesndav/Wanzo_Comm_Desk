import 'package:flutter/material.dart';

import 'package:wanzo/core/modules/module_registry.dart';
import 'package:wanzo/core/services/business_context_service.dart';
import 'package:wanzo/core/shared_widgets/empty_state_view.dart';
import 'package:wanzo/core/shared_widgets/wanzo_scaffold.dart';
import 'package:wanzo/core/utils/currency_formatter.dart';
import 'package:wanzo/core/widgets/desktop/desktop_data_table.dart';

import '../services/salon_api_service.dart';

/// Performances / commissions par coiffeur sur une période — l'entrée de
/// préparation de la PAIE. Lit `/salon/performers/commissions` (best-effort).
/// Version DESKTOP : période sélectionnable + tableau dense + total en pied.
class SalonPerformanceScreen extends StatefulWidget {
  const SalonPerformanceScreen({super.key});

  @override
  State<SalonPerformanceScreen> createState() => _SalonPerformanceScreenState();
}

class _SalonPerformanceScreenState extends State<SalonPerformanceScreen> {
  final SalonApiService _api = SalonApiService();
  late DateTimeRange _range;
  List<StylistCommission> _rows = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _range = DateTimeRange(
      start: DateTime(now.year, now.month, 1),
      end: DateTime(now.year, now.month, now.day, 23, 59, 59),
    );
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final rows =
          await _api.getCommissions(from: _range.start, to: _range.end);
      if (!mounted) return;
      setState(() {
        _rows = rows;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Données indisponibles. Vérifiez votre connexion.';
      });
    }
  }

  Future<void> _pickRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 1)),
      initialDateRange: _range,
    );
    if (picked == null) return;
    setState(() => _range = DateTimeRange(
          start: DateTime(
              picked.start.year, picked.start.month, picked.start.day),
          end: DateTime(picked.end.year, picked.end.month, picked.end.day, 23,
              59, 59),
        ));
    await _load();
  }

  String _fmtDate(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

  @override
  Widget build(BuildContext context) {
    final ctx = BusinessContextService();
    final index = ModuleRegistry.indexOfSidebarRoute(
      ctx.activityMode,
      ctx.currentContext?.userRole,
      '/salon/performance',
    );
    final theme = Theme.of(context);
    final totalCommission =
        _rows.fold<double>(0, (sum, r) => sum + r.totalCommission);
    return WanzoScaffold(
      currentIndex: index < 0 ? 0 : index,
      title: 'Performances',
      appBarActions: [
        IconButton(
          tooltip: 'Actualiser',
          icon: const Icon(Icons.refresh),
          onPressed: _load,
        ),
      ],
      body: Column(
        children: [
          // Sélecteur de période.
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Row(
              children: [
                OutlinedButton.icon(
                  onPressed: _pickRange,
                  icon: const Icon(Icons.date_range, size: 18),
                  label: Text(
                      '${_fmtDate(_range.start)} — ${_fmtDate(_range.end)}'),
                ),
                const Spacer(),
                if (!_loading && _error == null && _rows.isNotEmpty)
                  Row(
                    children: [
                      Text('Total commissions : ',
                          style: theme.textTheme.titleSmall),
                      Text(
                        formatCurrency(totalCommission, 'CDF'),
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                    ? _ErrorView(message: _error!, onRetry: _load)
                    : _rows.isEmpty
                        ? const EmptyStateView(
                            icon: Icons.leaderboard_outlined,
                            message: 'Aucune commission sur cette période.',
                          )
                        : DesktopDataTable<StylistCommission>(
                            data: _rows,
                            showSearch: true,
                            searchHint: 'Rechercher un coiffeur…',
                            searchFilter: (r, q) =>
                                r.stylistName.toLowerCase().contains(q),
                            columns: const [
                              DataColumn(label: Text('Coiffeur')),
                              DataColumn(label: Text('Prestations')),
                              DataColumn(label: Text('CA prestations')),
                              DataColumn(label: Text('CA produits')),
                              DataColumn(label: Text('Comm. prestations')),
                              DataColumn(label: Text('Comm. produits')),
                              DataColumn(label: Text('Total commission')),
                            ],
                            rowBuilder: (r) => DataRow(
                              cells: [
                                DataCell(Text(r.stylistName,
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w600))),
                                DataCell(Text('${r.servicesCount}')),
                                DataCell(Text(
                                    formatCurrency(r.serviceRevenue, 'CDF'))),
                                DataCell(Text(
                                    formatCurrency(r.retailRevenue, 'CDF'))),
                                DataCell(Text(formatCurrency(
                                    r.serviceCommission, 'CDF'))),
                                DataCell(Text(
                                    formatCurrency(r.retailCommission, 'CDF'))),
                                DataCell(Text(
                                  formatCurrency(r.totalCommission, 'CDF'),
                                  style: TextStyle(
                                      fontWeight: FontWeight.w700,
                                      color: theme.colorScheme.primary),
                                )),
                              ],
                            ),
                          ),
          ),
        ],
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorView({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.cloud_off, size: 40, color: Colors.grey),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Text(message, textAlign: TextAlign.center),
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh),
            label: const Text('Réessayer'),
          ),
        ],
      ),
    );
  }
}
