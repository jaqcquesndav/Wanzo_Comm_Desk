import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/modules/module_registry.dart';
import '../../../core/services/business_context_service.dart';
import '../../../core/shared_widgets/empty_state_view.dart';
import '../../../core/shared_widgets/wanzo_scaffold.dart';
import '../../../core/widgets/desktop/desktop_data_table.dart';
import '../../../core/widgets/desktop/row_actions_menu.dart';
import '../../services/config/garage_vehicle_categories.dart';
import '../models/customer_vehicle.dart';
import '../services/atelier_api_service.dart';
import '../widgets/vehicle_form_sheet.dart';
import 'vehicle_sheet_screen.dart';

/// Le PARC du garage : tous les véhicules confiés, tous clients confondus.
///
/// Le garagiste reconnaît la voiture avant son propriétaire, et la cherche par
/// sa plaque. Tant que les véhicules n'étaient atteignables qu'à travers la
/// fiche d'un client, il fallait déjà savoir à qui la voiture appartenait pour
/// la retrouver. Page desktop uniquement : elle demande la largeur d'un
/// tableau, que le mobile n'a pas.
class GarageFleetScreen extends StatefulWidget {
  const GarageFleetScreen({super.key});

  @override
  State<GarageFleetScreen> createState() => _GarageFleetScreenState();
}

class _GarageFleetScreenState extends State<GarageFleetScreen> {
  final _api = AtelierApiService();
  final _dateFmt = DateFormat('dd/MM/yyyy');
  final _km = NumberFormat.decimalPattern('fr');

  List<CustomerVehicle> _vehicles = const [];
  bool _loading = true;
  String? _error;

  /// Filtre par catégorie de tarification : le barème du garage se lit par
  /// colonne, retrouver « tous les poids lourds » est un geste courant.
  String? _category;

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
      final v = await _api.getAllVehicles();
      if (!mounted) return;
      setState(() {
        _vehicles = v;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = "Le parc n'a pas pu être chargé.";
      });
    }
  }

  List<CustomerVehicle> get _filtered => _category == null
      ? _vehicles
      : _vehicles.where((v) => v.pricingCategory == _category).toList();

  String _categoryLabel(String? code) {
    if (code == null || code.isEmpty) return '';
    for (final c in kGarageVehicleCategories) {
      if (c.code == code) return c.label;
    }
    return code;
  }

  Future<void> _openSheet(CustomerVehicle vehicle) async {
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => VehicleSheetScreen(
          vehicle: vehicle,
          customerName: vehicle.customerName,
        ),
      ),
    );
    if (changed == true) _load();
  }

  Future<void> _edit(CustomerVehicle vehicle) async {
    final v = await showVehicleForm(
      context,
      customerId: vehicle.customerId,
      vehicle: vehicle,
    );
    if (v != null) _load();
  }

  Future<void> _remove(CustomerVehicle vehicle) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Retirer du parc'),
        content: Text(
          '${vehicle.displayLabel} ne sera plus proposé à la création d\'une '
          'intervention. Son historique reste consultable.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(ctx).colorScheme.error,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Retirer'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await _api.deleteVehicle(vehicle.id);
      _load();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Le retrait a échoué.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final ctx = BusinessContextService();
    final index = ModuleRegistry.indexOfSidebarRoute(
      ctx.activityMode,
      ctx.currentContext?.userRole,
      '/garage/parc',
    );
    return WanzoScaffold(
      currentIndex: index < 0 ? 0 : index,
      title: 'Parc',
      appBarActions: [
        IconButton(
          tooltip: 'Actualiser',
          icon: const Icon(Icons.refresh),
          onPressed: _loading ? null : _load,
        ),
      ],
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _body(context),
    );
  }

  Widget _body(BuildContext context) {
    final theme = Theme.of(context);
    if (_error != null) {
      return EmptyStateView(
        icon: Icons.cloud_off,
        message: _error!,
        actionLabel: 'Réessayer',
        onAction: _load,
      );
    }
    if (_vehicles.isEmpty) {
      return const EmptyStateView(
        icon: Icons.directions_car_outlined,
        message: "Aucun véhicule dans le parc. Un véhicule s'ajoute depuis la "
            "fiche de son propriétaire, ou à la création d'une intervention.",
      );
    }

    return Column(
      children: [
        _summary(theme),
        _categoryFilter(theme),
        Expanded(
          child: DesktopDataTable<CustomerVehicle>(
            data: _filtered,
            searchHint: 'Plaque, marque, modèle, châssis ou propriétaire…',
            searchFilter: (v, q) => [
              v.plate,
              v.brand,
              v.model,
              v.vin,
              v.customerName,
              v.color,
              v.year?.toString(),
            ].where((e) => e != null).join(' ').toLowerCase().contains(q),
            // Le clic ouvre la FICHE DE SUIVI ; les autres gestes restent dans
            // le menu de ligne.
            onRowTap: _openSheet,
            exportHeaders: const [
              'Immatriculation',
              'Véhicule',
              'Propriétaire',
              'Catégorie',
              'Kilométrage',
              'Au parc depuis',
            ],
            exportConfig: DataTableExportConfig(
              title: 'Parc du garage',
              fileName: 'parc_garage',
              companyName:
                  BusinessContextService().currentContext?.companyName,
              rowDataExtractor: (v) => [
                v.plate ?? '',
                v.designation,
                v.customerName ?? '',
                _categoryLabel(v.pricingCategory),
                v.mileage == null ? '' : _km.format(v.mileage!),
                v.createdAt == null ? '' : _dateFmt.format(v.createdAt!),
              ],
            ),
            columns: const [
              DataColumn(label: Text('Immatriculation')),
              DataColumn(label: Text('Véhicule')),
              DataColumn(label: Text('Propriétaire')),
              DataColumn(label: Text('Catégorie')),
              DataColumn(label: Text('Kilométrage')),
              DataColumn(label: Text('Au parc depuis')),
              DataColumn(label: Text('Actions')),
            ],
            rowBuilder: (v) => DataRow(
              cells: [
                DataCell(Text(
                  (v.plate ?? '').isNotEmpty ? v.plate! : '—',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                )),
                DataCell(Text(v.designation)),
                DataCell(Text(
                  (v.customerName ?? '').isNotEmpty ? v.customerName! : '—',
                )),
                DataCell(Text(
                  _categoryLabel(v.pricingCategory).isEmpty
                      ? '—'
                      : _categoryLabel(v.pricingCategory),
                )),
                DataCell(Text(
                  v.mileage == null ? '—' : '${_km.format(v.mileage!)} km',
                )),
                DataCell(Text(
                  v.createdAt == null ? '—' : _dateFmt.format(v.createdAt!),
                )),
                DataCell(RowActionsMenu(
                  actions: [
                    RowAction(
                      label: 'Fiche de suivi',
                      icon: Icons.description_outlined,
                      onSelected: () => _openSheet(v),
                    ),
                    RowAction(
                      label: 'Modifier',
                      icon: Icons.edit_outlined,
                      onSelected: () => _edit(v),
                    ),
                    RowAction(
                      label: 'Retirer du parc',
                      icon: Icons.delete_outline,
                      destructive: true,
                      onSelected: () => _remove(v),
                    ),
                  ],
                )),
              ],
            ),
          ),
        ),
      ],
    );
  }

  /// Ce que le garagiste veut savoir en ouvrant la page : combien de véhicules,
  /// pour combien de clients, et combien attendent encore leur catégorie de
  /// tarification (sans elle, le barème ne peut pas s'appliquer).
  Widget _summary(ThemeData theme) {
    final owners = _vehicles.map((v) => v.customerId).toSet().length;
    final unclassified =
        _vehicles.where((v) => (v.pricingCategory ?? '').isEmpty).length;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Row(
        children: [
          _stat(theme, '${_vehicles.length}', 'véhicules au parc'),
          const SizedBox(width: 12),
          _stat(theme, '$owners', owners > 1 ? 'propriétaires' : 'propriétaire'),
          if (unclassified > 0) ...[
            const SizedBox(width: 12),
            _stat(
              theme,
              '$unclassified',
              'sans catégorie de tarification',
              warning: true,
            ),
          ],
        ],
      ),
    );
  }

  Widget _stat(ThemeData theme, String value, String label,
      {bool warning = false}) {
    final color = warning ? theme.colorScheme.error : theme.colorScheme.primary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(value,
              style: theme.textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w700, color: color)),
          const SizedBox(width: 8),
          Text(label, style: theme.textTheme.bodySmall),
        ],
      ),
    );
  }

  Widget _categoryFilter(ThemeData theme) {
    // On ne propose que les catégories réellement présentes : une liste de
    // filtres vides fait chercher là où il n'y a rien.
    final present = <String>{
      for (final v in _vehicles)
        if ((v.pricingCategory ?? '').isNotEmpty) v.pricingCategory!,
    };
    if (present.length < 2) return const SizedBox(height: 8);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          FilterChip(
            label: const Text('Toutes'),
            selected: _category == null,
            onSelected: (_) => setState(() => _category = null),
          ),
          for (final c in kGarageVehicleCategories)
            if (present.contains(c.code))
              FilterChip(
                label: Text(c.label),
                selected: _category == c.code,
                onSelected: (sel) =>
                    setState(() => _category = sel ? c.code : null),
              ),
        ],
      ),
    );
  }
}
