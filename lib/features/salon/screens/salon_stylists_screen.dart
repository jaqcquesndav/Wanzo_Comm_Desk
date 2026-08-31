import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:wanzo/core/modules/module_registry.dart';
import 'package:wanzo/core/services/business_context_service.dart';
import 'package:wanzo/core/shared_widgets/empty_state_view.dart';
import 'package:wanzo/core/shared_widgets/wanzo_scaffold.dart';
import 'package:wanzo/core/utils/currency_formatter.dart';
import 'package:wanzo/core/widgets/desktop/desktop_data_table.dart';

import '../cubit/salon_cubit.dart';
import '../models/stylist.dart';

/// Gestion des COIFFEURS / COIFFEUSES du salon (CRUD) : nom, téléphone, modèle
/// de rémunération (commission / location de fauteuil), taux de commission sur
/// prestations et sur produits de détail. Version DESKTOP : un tableau dense
/// (`DesktopDataTable`) + un formulaire en DIALOG (modal), pas une feuille basse.
class SalonStylistsScreen extends StatelessWidget {
  const SalonStylistsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final ctx = BusinessContextService();
    final index = ModuleRegistry.indexOfSidebarRoute(
      ctx.activityMode,
      ctx.currentContext?.userRole,
      '/salon/stylists',
    );
    return WanzoScaffold(
      currentIndex: index < 0 ? 0 : index,
      title: 'Coiffeurs',
      appBarActions: [
        IconButton(
          tooltip: 'Actualiser',
          icon: const Icon(Icons.refresh),
          onPressed: () => context.read<SalonCubit>().load(),
        ),
      ],
      body: BlocBuilder<SalonCubit, SalonState>(
        builder: (context, state) {
          if (state.loading && state.stylists.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }
          if (state.stylists.isEmpty) {
            return _EmptyStylists(
              onAdd: () => _openForm(context),
              error: state.error,
            );
          }
          return Column(
            children: [
              if (state.error != null)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                  child: Text(
                    state.error!,
                    style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                        fontSize: 12),
                  ),
                ),
              Expanded(
                child: DesktopDataTable<Stylist>(
                  data: state.stylists,
                  onAdd: () => _openForm(context),
                  addButtonLabel: 'Ajouter un coiffeur',
                  searchHint: 'Rechercher un coiffeur…',
                  searchFilter: (s, q) =>
                      s.name.toLowerCase().contains(q) ||
                      (s.phone?.toLowerCase().contains(q) ?? false),
                  onRowTap: (s) => _openForm(context, existing: s),
                  columns: const [
                    DataColumn(label: Text('Nom')),
                    DataColumn(label: Text('Téléphone')),
                    DataColumn(label: Text('Rémunération')),
                    DataColumn(label: Text('Comm. prestations')),
                    DataColumn(label: Text('Comm. produits')),
                    DataColumn(label: Text('Statut')),
                    DataColumn(label: Text('')),
                  ],
                  rowBuilder: (s) => _row(context, s),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  DataRow _row(BuildContext context, Stylist s) {
    final theme = Theme.of(context);
    final remuneration = s.payModel == StylistPayModel.boothRent
        ? '${s.payModel.label} · ${formatCurrency(s.boothRentAmount ?? 0, 'CDF')}'
        : s.payModel.label;
    return DataRow(
      cells: [
        DataCell(Text(s.name, style: const TextStyle(fontWeight: FontWeight.w600))),
        DataCell(Text(s.phone?.isNotEmpty == true ? s.phone! : '—')),
        DataCell(Text(remuneration)),
        DataCell(Text(s.payModel == StylistPayModel.boothRent
            ? '—'
            : '${s.serviceCommissionPct.toStringAsFixed(0)} %')),
        DataCell(Text(s.payModel == StylistPayModel.boothRent
            ? '—'
            : '${s.retailCommissionPct.toStringAsFixed(0)} %')),
        DataCell(
          s.active
              ? Text('Actif',
                  style: TextStyle(
                      color: Colors.green.shade700,
                      fontWeight: FontWeight.w600))
              : Text('Inactif',
                  style: TextStyle(
                      color: theme.colorScheme.error,
                      fontWeight: FontWeight.w600)),
        ),
        DataCell(
          PopupMenuButton<String>(
            onSelected: (v) {
              if (v == 'edit') {
                _openForm(context, existing: s);
              } else if (v == 'toggle') {
                context
                    .read<SalonCubit>()
                    .updateStylist(s.id, {'active': !s.active});
              } else if (v == 'delete') {
                _confirmDelete(context, s);
              }
            },
            itemBuilder: (_) => [
              const PopupMenuItem(value: 'edit', child: Text('Modifier')),
              PopupMenuItem(
                  value: 'toggle',
                  child: Text(s.active ? 'Désactiver' : 'Activer')),
              const PopupMenuItem(value: 'delete', child: Text('Supprimer')),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _confirmDelete(BuildContext context, Stylist s) async {
    final cubit = context.read<SalonCubit>();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Supprimer le coiffeur'),
        content: Text('Retirer « ${s.name} » ?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
    if (ok == true) {
      await cubit.deleteStylist(s.id);
    }
  }

  Future<void> _openForm(BuildContext context, {Stylist? existing}) async {
    final cubit = context.read<SalonCubit>();
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => BlocProvider.value(
        value: cubit,
        child: _StylistFormDialog(existing: existing),
      ),
    );
  }
}

class _EmptyStylists extends StatelessWidget {
  final VoidCallback onAdd;
  final String? error;
  const _EmptyStylists({required this.onAdd, this.error});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        if (error != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Text(error!,
                style: TextStyle(
                    color: Theme.of(context).colorScheme.error, fontSize: 12)),
          ),
        Expanded(
          child: EmptyStateView(
            icon: Icons.badge_outlined,
            message: 'Aucun coiffeur. Ajoutez votre équipe.',
            actionLabel: 'Ajouter un coiffeur',
            actionIcon: Icons.add,
            onAction: onAdd,
          ),
        ),
      ],
    );
  }
}

class _StylistFormDialog extends StatefulWidget {
  final Stylist? existing;
  const _StylistFormDialog({this.existing});

  @override
  State<_StylistFormDialog> createState() => _StylistFormDialogState();
}

class _StylistFormDialogState extends State<_StylistFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _phoneController;
  late final TextEditingController _serviceCommController;
  late final TextEditingController _retailCommController;
  late final TextEditingController _boothRentController;
  late StylistPayModel _payModel;
  bool _active = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _nameController = TextEditingController(text: e?.name ?? '');
    _phoneController = TextEditingController(text: e?.phone ?? '');
    _serviceCommController = TextEditingController(
        text: e != null ? e.serviceCommissionPct.toStringAsFixed(0) : '');
    _retailCommController = TextEditingController(
        text: e != null ? e.retailCommissionPct.toStringAsFixed(0) : '');
    _boothRentController = TextEditingController(
        text: e?.boothRentAmount != null
            ? e!.boothRentAmount!.toStringAsFixed(0)
            : '');
    _payModel = e?.payModel ?? StylistPayModel.commission;
    _active = e?.active ?? true;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _serviceCommController.dispose();
    _retailCommController.dispose();
    _boothRentController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    final phone = _phoneController.text.trim();
    final booth = double.tryParse(_boothRentController.text.trim());
    final draft = Stylist(
      id: widget.existing?.id ?? '',
      name: _nameController.text.trim(),
      phone: phone.isEmpty ? null : phone,
      payModel: _payModel,
      serviceCommissionPct:
          double.tryParse(_serviceCommController.text.trim()) ?? 0,
      retailCommissionPct:
          double.tryParse(_retailCommController.text.trim()) ?? 0,
      boothRentAmount:
          _payModel == StylistPayModel.boothRent ? booth : null,
      active: _active,
    );
    final cubit = context.read<SalonCubit>();
    if (widget.existing == null) {
      await cubit.createStylist(draft);
    } else {
      await cubit.updateStylist(widget.existing!.id, draft.toCreateJson());
    }
    if (!mounted) return;
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isEditing = widget.existing != null;
    final isBooth = _payModel == StylistPayModel.boothRent;
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 520,
          maxHeight: MediaQuery.of(context).size.height * 0.9,
        ),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 8, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        isEditing ? 'Modifier le coiffeur' : 'Nouveau coiffeur',
                        style: theme.textTheme.titleLarge
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Fermer',
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Flexible(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
                  shrinkWrap: true,
                  children: [
                    TextFormField(
                      controller: _nameController,
                      textCapitalization: TextCapitalization.words,
                      decoration: const InputDecoration(
                        labelText: 'Nom *',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.person),
                      ),
                      validator: (v) => (v == null || v.trim().isEmpty)
                          ? 'Le nom est requis'
                          : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _phoneController,
                      keyboardType: TextInputType.phone,
                      decoration: const InputDecoration(
                        labelText: 'Téléphone',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.phone),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text('Rémunération',
                        style: theme.textTheme.labelLarge?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant)),
                    const SizedBox(height: 8),
                    SegmentedButton<StylistPayModel>(
                      segments: const [
                        ButtonSegment(
                          value: StylistPayModel.commission,
                          label: Text('Commission'),
                          icon: Icon(Icons.percent),
                        ),
                        ButtonSegment(
                          value: StylistPayModel.boothRent,
                          label: Text('Fauteuil'),
                          icon: Icon(Icons.chair_alt),
                        ),
                      ],
                      selected: {_payModel},
                      onSelectionChanged: (s) =>
                          setState(() => _payModel = s.first),
                    ),
                    const SizedBox(height: 16),
                    if (!isBooth) ...[
                      TextFormField(
                        controller: _serviceCommController,
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(
                              RegExp(r'^\d+\.?\d{0,2}')),
                        ],
                        decoration: const InputDecoration(
                          labelText: 'Commission prestations (%)',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.content_cut),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _retailCommController,
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(
                              RegExp(r'^\d+\.?\d{0,2}')),
                        ],
                        decoration: const InputDecoration(
                          labelText: 'Commission produits (%)',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.shopping_bag_outlined),
                        ),
                      ),
                    ] else
                      TextFormField(
                        controller: _boothRentController,
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(
                              RegExp(r'^\d+\.?\d{0,2}')),
                        ],
                        decoration: const InputDecoration(
                          labelText: 'Loyer du fauteuil (CDF)',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.chair_alt),
                        ),
                      ),
                    const SizedBox(height: 8),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Actif'),
                      value: _active,
                      onChanged: (v) => setState(() => _active = v),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: _saving ? null : () => Navigator.pop(context),
                      child: const Text('Annuler'),
                    ),
                    const SizedBox(width: 8),
                    FilledButton.icon(
                      onPressed: _saving ? null : _save,
                      icon: _saving
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.check),
                      label: Text(isEditing ? 'Enregistrer' : 'Ajouter'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
