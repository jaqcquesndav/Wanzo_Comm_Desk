import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

import 'package:wanzo/core/utils/currency_formatter.dart';
import 'package:wanzo/features/atelier/models/atelier_order.dart';
import 'package:wanzo/features/atelier/models/customer_vehicle.dart';
import 'package:wanzo/features/atelier/services/atelier_api_service.dart';
import 'package:wanzo/features/atelier/services/vehicle_sheet_pdf.dart';
import 'package:wanzo/features/atelier/widgets/vehicle_form_sheet.dart';
import 'package:wanzo/features/settings/bloc/settings_bloc.dart';
import 'package:wanzo/features/settings/bloc/settings_state.dart';
import 'package:wanzo/features/settings/models/settings.dart';

/// Fiche de suivi d'un véhicule client, À L'ÉCRAN : identité du véhicule
/// (Fabricant, Modèle, Année, puis le véhicule spécifique), indicateurs et
/// historique des interventions. Elle évolue seule à chaque commande garage
/// rattachée au véhicule. Le PDF (VehicleSheetPdf) n'est que l'état de sortie
/// imprimable ou partageable de cette même fiche.
class VehicleSheetScreen extends StatefulWidget {
  final CustomerVehicle vehicle;
  final String? customerName;

  const VehicleSheetScreen({super.key, required this.vehicle, this.customerName});

  @override
  State<VehicleSheetScreen> createState() => _VehicleSheetScreenState();
}

class _VehicleSheetScreenState extends State<VehicleSheetScreen> {
  final _api = AtelierApiService();
  final _dateFmt = DateFormat('dd/MM/yyyy');
  final _km = NumberFormat.decimalPattern('fr');
  late CustomerVehicle _vehicle = widget.vehicle;
  List<AtelierOrder> _orders = const [];
  bool _loading = true;
  bool _busy = false;
  bool _changed = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final o = await _api.getOrders(customerId: _vehicle.customerId, vehicleId: _vehicle.id);
      o.sort((a, b) => (b.entryDate ?? b.createdAt ?? DateTime(2000))
          .compareTo(a.entryDate ?? a.createdAt ?? DateTime(2000)));
      if (mounted) setState(() { _orders = o; _loading = false; });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Settings? _settings() {
    try {
      final s = context.read<SettingsBloc>().state;
      if (s is SettingsLoaded) return s.settings;
      if (s is SettingsUpdated) return s.settings;
    } catch (_) {
      // SettingsBloc absent : identité société omise sur le PDF.
    }
    return null;
  }

  Future<void> _edit() async {
    final v = await showVehicleForm(context, customerId: _vehicle.customerId, vehicle: _vehicle);
    if (v != null && mounted) setState(() { _vehicle = v; _changed = true; });
  }

  Future<void> _export({required bool share}) async {
    setState(() => _busy = true);
    try {
      if (share) {
        await VehicleSheetPdf.shareSheet(_vehicle, _orders, customerName: widget.customerName, settings: _settings());
      } else {
        await VehicleSheetPdf.printSheet(_vehicle, _orders, customerName: widget.customerName, settings: _settings());
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Export impossible : $e')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  double get _totalCdf => _orders.fold(0, (s, o) => s + o.totalAmount * o.exchangeRate);

  DateTime? get _lastVisit => _orders.isEmpty ? null : (_orders.first.entryDate ?? _orders.first.createdAt);

  /// Dernier kilométrage connu : la commande la plus récente, sinon la fiche.
  String? get _lastMileage {
    for (final o in _orders) {
      final m = o.maintenanceDetails?.mileage;
      if (m != null && m.trim().isNotEmpty) return m;
    }
    return _vehicle.mileage == null ? null : _km.format(_vehicle.mileage);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final v = _vehicle;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) Navigator.of(context).pop(_changed);
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Fiche de suivi véhicule'),
          actions: [
            IconButton(tooltip: 'Modifier le véhicule', icon: const Icon(Icons.edit_outlined), onPressed: _edit),
            if (_busy)
              const Padding(
                padding: EdgeInsets.all(14),
                child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
              )
            else
              PopupMenuButton<String>(
                tooltip: 'État de sortie',
                icon: const Icon(Icons.picture_as_pdf_outlined),
                onSelected: (a) => _export(share: a == 'share'),
                itemBuilder: (_) => const [
                  PopupMenuItem(value: 'print', child: ListTile(dense: true, leading: Icon(Icons.print_outlined), title: Text('Imprimer / PDF'))),
                  PopupMenuItem(value: 'share', child: ListTile(dense: true, leading: Icon(Icons.share_outlined), title: Text('Partager la fiche'))),
                ],
              ),
          ],
        ),
        body: RefreshIndicator(
          onRefresh: _load,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // ── En-tête : plaque + désignation ──
              Row(
                children: [
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(Icons.directions_car, size: 30, color: theme.colorScheme.onPrimaryContainer),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          (v.plate ?? '').isNotEmpty ? v.plate! : v.designation,
                          style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
                        ),
                        if ((v.plate ?? '').isNotEmpty)
                          Text(v.designation, style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
                        if ((widget.customerName ?? '').isNotEmpty)
                          Text('Propriétaire : ${widget.customerName}',
                              style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // ── Indicateurs ──
              Row(
                children: [
                  _Kpi(label: 'Interventions', value: '${_orders.length}'),
                  const SizedBox(width: 8),
                  _Kpi(label: 'Dernière visite', value: _lastVisit == null ? '—' : _dateFmt.format(_lastVisit!)),
                  const SizedBox(width: 8),
                  _Kpi(label: 'Kilométrage', value: _lastMileage == null ? '—' : '$_lastMileage km'),
                ],
              ),
              const SizedBox(height: 16),

              // ── Identité : Fabricant, Modèle, Année ──
              _Section(
                title: 'Fabricant, modèle, année',
                icon: Icons.factory_outlined,
                rows: [
                  ('Fabricant', v.brand),
                  ('Modèle', v.model),
                  ('Année', v.year?.toString()),
                  ('Carrosserie', v.bodyType),
                  ('Boîte', v.transmission),
                ],
              ),
              const SizedBox(height: 12),

              // ── Véhicule spécifique ──
              _Section(
                title: 'Véhicule spécifique',
                icon: Icons.badge_outlined,
                rows: [
                  ('Immatriculation', v.plate),
                  ('Châssis (VIN)', v.vin),
                  ('Couleur', v.color),
                  ('Carburant', v.fuel),
                  ('Kilométrage relevé', v.mileage == null ? null : '${_km.format(v.mileage)} km'),
                  ('Remarques', v.notes),
                ],
              ),
              const SizedBox(height: 20),

              // ── Historique ──
              Row(
                children: [
                  Icon(Icons.history, size: 20, color: theme.colorScheme.primary),
                  const SizedBox(width: 8),
                  Text('Historique des interventions',
                      style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
                  const Spacer(),
                  if (_orders.isNotEmpty)
                    Text('Total ${formatCurrency(_totalCdf, 'CDF')}',
                        style: theme.textTheme.labelLarge?.copyWith(color: theme.colorScheme.primary)),
                ],
              ),
              const SizedBox(height: 8),
              if (_loading)
                const Padding(padding: EdgeInsets.symmetric(vertical: 24), child: Center(child: CircularProgressIndicator()))
              else if (_orders.isEmpty)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      'Aucune intervention pour ce véhicule. Créez une commande garage et sélectionnez ce véhicule : elle apparaîtra ici automatiquement.',
                      style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                    ),
                  ),
                )
              else
                for (final o in _orders) _InterventionTile(order: o, dateFmt: _dateFmt),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}

class _Kpi extends StatelessWidget {
  final String label;
  final String value;
  const _Kpi({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
            const SizedBox(height: 2),
            Text(value, style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700), maxLines: 1, overflow: TextOverflow.ellipsis),
          ],
        ),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  final String title;
  final IconData icon;
  final List<(String, String?)> rows;
  const _Section({required this.title, required this.icon, required this.rows});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final filled = rows.where((r) => (r.$2 ?? '').trim().isNotEmpty).toList();
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 18, color: theme.colorScheme.primary),
                const SizedBox(width: 8),
                Text(title, style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
              ],
            ),
            const SizedBox(height: 8),
            if (filled.isEmpty)
              Text('Non renseigné', style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant))
            else
              for (final r in filled)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 3),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        width: 130,
                        child: Text(r.$1, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
                      ),
                      Expanded(child: Text(r.$2!, style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w500))),
                    ],
                  ),
                ),
          ],
        ),
      ),
    );
  }
}

class _InterventionTile extends StatelessWidget {
  final AtelierOrder order;
  final DateFormat dateFmt;
  const _InterventionTile({required this.order, required this.dateFmt});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final m = order.maintenanceDetails;
    final date = order.entryDate ?? order.createdAt;
    final details = <(String, String?)>[
      ('Kilométrage', m?.mileage == null ? null : '${m!.mileage} km'),
      ('Panne signalée', m?.reportedFault),
      ('Diagnostic', m?.diagnostic),
      ('Travaux réalisés', m?.repairDone),
      ('Technicien', m?.technicianName),
      ('Garantie', m?.warrantyDays == null ? null : '${m!.warrantyDays} jours'),
    ].where((d) => (d.$2 ?? '').trim().isNotEmpty).toList();

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(order.label, style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary.withAlpha((0.12 * 255).round()),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(order.status.labelFor(order.metier),
                      style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.primary, fontWeight: FontWeight.w600)),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              [
                if (date != null) dateFmt.format(date),
                formatCurrency(order.totalAmount, order.currencyCode),
                if (order.remainingAmount > 0) 'reste ${formatCurrency(order.remainingAmount, order.currencyCode)}',
              ].join(' · '),
              style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
            if (details.isNotEmpty) ...[
              const Divider(height: 16),
              for (final d in details)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        width: 130,
                        child: Text(d.$1, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
                      ),
                      Expanded(child: Text(d.$2!, style: theme.textTheme.bodySmall)),
                    ],
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }
}
