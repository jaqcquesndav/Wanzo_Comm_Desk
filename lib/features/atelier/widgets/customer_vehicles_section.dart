import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:wanzo/core/modules/activity_mode.dart';
import 'package:wanzo/core/services/business_context_service.dart';
import 'package:wanzo/features/atelier/models/customer_vehicle.dart';
import 'package:wanzo/features/atelier/screens/vehicle_sheet_screen.dart';
import 'package:wanzo/features/atelier/services/atelier_api_service.dart';
import 'package:wanzo/features/atelier/widgets/vehicle_form_sheet.dart';

/// Section « Véhicules » du détail client, mode garage uniquement : liste des
/// véhicules du client, ajout / modification, et ouverture de la FICHE DE
/// SUIVI à l'écran (VehicleSheetScreen) ; le PDF n'en est que l'état de sortie.
class CustomerVehiclesSection extends StatefulWidget {
  final String customerId;
  final String? customerName;

  const CustomerVehiclesSection({super.key, required this.customerId, this.customerName});

  @override
  State<CustomerVehiclesSection> createState() => _CustomerVehiclesSectionState();
}

class _CustomerVehiclesSectionState extends State<CustomerVehiclesSection> {
  final _api = AtelierApiService();
  List<CustomerVehicle> _vehicles = const [];
  bool _loading = true;

  bool get _isGarage => BusinessContextService().activityMode == ActivityMode.garage;

  @override
  void initState() {
    super.initState();
    if (_isGarage && widget.customerId.isNotEmpty) {
      _load();
    } else {
      _loading = false;
    }
  }

  Future<void> _load() async {
    try {
      final v = await _api.getVehicles(widget.customerId);
      if (mounted) setState(() { _vehicles = v; _loading = false; });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _add() async {
    final v = await showVehicleForm(context, customerId: widget.customerId);
    if (v != null) _load();
  }

  Future<void> _edit(CustomerVehicle vehicle) async {
    final v = await showVehicleForm(context, customerId: widget.customerId, vehicle: vehicle);
    if (v != null) _load();
  }

  /// Fiche de suivi à l'écran ; recharge la liste si le véhicule a été modifié.
  Future<void> _openSheet(CustomerVehicle vehicle) async {
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => VehicleSheetScreen(vehicle: vehicle, customerName: widget.customerName),
      ),
    );
    if (changed == true) _load();
  }

  Future<void> _remove(CustomerVehicle vehicle) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Retirer ce véhicule ?'),
        content: Text('${vehicle.displayLabel} ne sera plus proposé sur les nouvelles interventions. L\'historique est conservé.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annuler')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Retirer')),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await _api.deleteVehicle(vehicle.id);
      _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Retrait impossible : $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_isGarage) return const SizedBox.shrink();
    final theme = Theme.of(context);
    final km = NumberFormat.decimalPattern('fr');
    return Card(
      margin: const EdgeInsets.only(top: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.directions_car_outlined, size: 20, color: theme.colorScheme.primary),
                const SizedBox(width: 8),
                Text('Véhicules', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
                const Spacer(),
                TextButton.icon(
                  onPressed: _add,
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Ajouter'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (_loading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_vehicles.isEmpty)
              Text(
                'Aucun véhicule enregistré. Ajoutez le véhicule du client pour ouvrir sa fiche de suivi.',
                style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              )
            else
              for (final v in _vehicles)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: CircleAvatar(
                    backgroundColor: theme.colorScheme.primaryContainer,
                    child: Icon(Icons.directions_car, color: theme.colorScheme.onPrimaryContainer),
                  ),
                  title: Text(
                    (v.plate ?? '').isNotEmpty ? v.plate! : v.designation,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  subtitle: Text([
                    if ((v.plate ?? '').isNotEmpty) v.designation,
                    if ((v.color ?? '').isNotEmpty) v.color!,
                    if (v.mileage != null) '${km.format(v.mileage)} km',
                  ].join(' · ')),
                  onTap: () => _openSheet(v),
                  trailing: PopupMenuButton<String>(
                          tooltip: 'Actions',
                          onSelected: (a) {
                            switch (a) {
                              case 'sheet':
                                _openSheet(v);
                                break;
                              case 'edit':
                                _edit(v);
                                break;
                              case 'remove':
                                _remove(v);
                                break;
                            }
                          },
                          itemBuilder: (_) => const [
                            PopupMenuItem(value: 'sheet', child: ListTile(dense: true, leading: Icon(Icons.assignment_outlined), title: Text('Fiche de suivi'))),
                            PopupMenuItem(value: 'edit', child: ListTile(dense: true, leading: Icon(Icons.edit_outlined), title: Text('Modifier'))),
                            PopupMenuItem(value: 'remove', child: ListTile(dense: true, leading: Icon(Icons.remove_circle_outline), title: Text('Retirer'))),
                          ],
                        ),
                ),
          ],
        ),
      ),
    );
  }
}
