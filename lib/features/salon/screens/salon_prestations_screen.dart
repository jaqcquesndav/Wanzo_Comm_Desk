import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:uuid/uuid.dart';

import 'package:wanzo/core/modules/module_registry.dart';
import 'package:wanzo/core/services/business_context_service.dart';
import 'package:wanzo/core/shared_widgets/empty_state_view.dart';
import 'package:wanzo/core/shared_widgets/wanzo_scaffold.dart';
import 'package:wanzo/core/utils/currency_formatter.dart';

import '../cubit/salon_cubit.dart';
import '../models/salon_service.dart';
import '../repositories/salon_service_repository.dart';
import '../services/salon_api_service.dart';

/// Composition de la CARTE des prestations du salon : un catalogue de services
/// tarifés, authoré directement (nom, catégorie, prix, durée, commission).
/// Chaque prestation est une entité [SalonService] à part entière — PAS une
/// surcouche du stock. Miroir DESKTOP de `RestaurantMenuConfigScreen` : le
/// formulaire d'ajout/édition s'ouvre en MODAL (Dialog centré), pas en feuille
/// basse.
class SalonPrestationsScreen extends StatefulWidget {
  const SalonPrestationsScreen({super.key});

  @override
  State<SalonPrestationsScreen> createState() => _SalonPrestationsScreenState();
}

class _SalonPrestationsScreenState extends State<SalonPrestationsScreen> {
  final SalonServiceRepository _repo = SalonServiceRepository();
  final SalonApiService _api = SalonApiService();
  List<SalonService> _items = [];
  bool _loading = true;
  bool _publishing = false;
  String _search = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final items = await _repo.loadAll();
    if (!mounted) return;
    setState(() {
      _items = items;
      _loading = false;
    });
    // Tenir le cubit (dashboard/ticket) au courant de la carte à jour.
    if (mounted) {
      try {
        context.read<SalonCubit>().reloadServices();
      } catch (_) {
        // Écran hors ShellRoute (test isolé) : sans conséquence.
      }
    }
  }

  /// Prestations groupées par catégorie, filtrées par la recherche (nom).
  Map<SalonServiceCategory, List<SalonService>> get _byCategory {
    final q = _search.trim().toLowerCase();
    final grouped = <SalonServiceCategory, List<SalonService>>{};
    for (final item in _items) {
      if (q.isNotEmpty && !item.name.toLowerCase().contains(q)) continue;
      grouped.putIfAbsent(item.category, () => []).add(item);
    }
    return grouped;
  }

  /// Publie la carte locale complète vers le backend (bulk-upsert). Best-effort.
  Future<void> _publish() async {
    if (_publishing) return;
    if (_items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Ajoutez au moins une prestation avant de publier.'),
        ),
      );
      return;
    }
    setState(() => _publishing = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await _api.bulkUpsertServices(_items);
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(
          content: Text('Carte publiée (${_items.length} prestations).'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (_) {
      if (!mounted) return;
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Publication impossible. Vérifiez votre connexion.'),
          backgroundColor: Colors.orange,
        ),
      );
    } finally {
      if (mounted) setState(() => _publishing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ctx = BusinessContextService();
    final index = ModuleRegistry.indexOfSidebarRoute(
      ctx.activityMode,
      ctx.currentContext?.userRole,
      '/salon/prestations',
    );
    final grouped = _byCategory;
    final categories = grouped.keys.toList()
      ..sort((a, b) => a.order.compareTo(b.order));
    return WanzoScaffold(
      currentIndex: index < 0 ? 0 : index,
      title: 'Composer la carte',
      appBarActions: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: FilledButton.icon(
            onPressed: (_publishing || _items.isEmpty) ? null : _publish,
            icon: _publishing
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.cloud_upload_outlined),
            label: const Text('Publier la carte'),
          ),
        ),
      ],
      floatingActionButton: FloatingActionButton(
        tooltip: 'Ajouter une prestation',
        onPressed: () => _openForm(),
        child: const Icon(Icons.add),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _items.isEmpty
              ? const EmptyStateView(
                  icon: Icons.content_cut,
                  message: 'Votre carte est vide. Ajoutez vos prestations.',
                )
              : Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                      child: TextField(
                        decoration: InputDecoration(
                          hintText: 'Rechercher une prestation…',
                          prefixIcon: const Icon(Icons.search),
                          suffixIcon: _search.isEmpty
                              ? null
                              : IconButton(
                                  icon: const Icon(Icons.clear),
                                  tooltip: 'Effacer',
                                  onPressed: () => setState(() => _search = ''),
                                ),
                          isDense: true,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onChanged: (v) => setState(() => _search = v),
                      ),
                    ),
                    Expanded(
                      child: categories.isEmpty
                          ? const EmptyStateView(
                              icon: Icons.search_off,
                              message: 'Aucune prestation ne correspond.',
                            )
                          : ListView(
                              padding:
                                  const EdgeInsets.fromLTRB(16, 12, 16, 96),
                              children: [
                                for (final cat in categories)
                                  _categorySection(cat, grouped[cat]!),
                              ],
                            ),
                    ),
                  ],
                ),
    );
  }

  Widget _categorySection(
      SalonServiceCategory category, List<SalonService> services) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(category.label,
                  style: theme.textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.w700)),
              const SizedBox(width: 8),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text('${services.length}',
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: theme.colorScheme.primary)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          for (final item in services) _serviceCard(item),
        ],
      ),
    );
  }

  Widget _serviceCard(SalonService item) {
    final theme = Theme.of(context);
    final duration = item.durationMinutes;
    final commission = item.serviceCommissionPct;
    return Card(
      clipBehavior: Clip.antiAlias,
      margin: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        onTap: () => _openForm(existing: item),
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(item.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  fontWeight: FontWeight.w700, fontSize: 15)),
                        ),
                        if (!item.active)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.error
                                  .withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text('Inactive',
                                style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    color: theme.colorScheme.error)),
                          ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(formatCurrency(item.priceCdf, 'CDF'),
                        style: TextStyle(
                            color: theme.colorScheme.primary,
                            fontWeight: FontWeight.w700,
                            fontSize: 14)),
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 12,
                      children: [
                        if (duration != null && duration > 0)
                          _meta(theme, Icons.schedule, '$duration min'),
                        if (commission != null)
                          _meta(theme, Icons.percent,
                              'Comm. ${commission.toStringAsFixed(0)} %'),
                      ],
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: item.active ? 'Désactiver' : 'Activer',
                icon: Icon(
                  item.active
                      ? Icons.check_circle_outline
                      : Icons.remove_circle_outline,
                  color:
                      item.active ? Colors.green : theme.colorScheme.error,
                ),
                visualDensity: VisualDensity.compact,
                onPressed: () => _toggleActive(item),
              ),
              IconButton(
                tooltip: 'Modifier',
                icon: const Icon(Icons.edit_outlined),
                visualDensity: VisualDensity.compact,
                onPressed: () => _openForm(existing: item),
              ),
              IconButton(
                tooltip: 'Supprimer',
                icon: Icon(Icons.delete_outline,
                    color: theme.colorScheme.error),
                visualDensity: VisualDensity.compact,
                onPressed: () => _confirmDelete(item),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _meta(ThemeData theme, IconData icon, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: theme.colorScheme.onSurfaceVariant),
        const SizedBox(width: 3),
        Text(label,
            style: theme.textTheme.labelSmall
                ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
      ],
    );
  }

  Future<void> _toggleActive(SalonService item) async {
    await _repo.upsert(item.copyWith(active: !item.active));
    await _load();
  }

  Future<void> _confirmDelete(SalonService item) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Supprimer la prestation'),
        content: Text('Retirer « ${item.name} » de la carte ?'),
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
      await _repo.delete(item.id);
      await _load();
    }
  }

  Future<void> _openForm({SalonService? existing}) async {
    final saved = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => _ServiceFormDialog(repo: _repo, existing: existing),
    );
    if (saved == true) {
      await _load();
    }
  }
}

/// Formulaire DÉDIÉ d'une prestation, présenté en DIALOG (modal desktop) : nom,
/// catégorie, prix, durée, commission spécifique (override). Ce n'est PAS le
/// formulaire de stock — une prestation est authorée directement.
class _ServiceFormDialog extends StatefulWidget {
  final SalonServiceRepository repo;
  final SalonService? existing;
  const _ServiceFormDialog({required this.repo, this.existing});

  @override
  State<_ServiceFormDialog> createState() => _ServiceFormDialogState();
}

class _ServiceFormDialogState extends State<_ServiceFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _priceController;
  late final TextEditingController _durationController;
  late final TextEditingController _commissionController;
  late SalonServiceCategory _category;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _nameController = TextEditingController(text: e?.name ?? '');
    _priceController = TextEditingController(
        text: e != null ? e.priceCdf.toStringAsFixed(0) : '');
    _durationController = TextEditingController(
        text: e?.durationMinutes != null ? '${e!.durationMinutes}' : '');
    _commissionController = TextEditingController(
        text: e?.serviceCommissionPct != null
            ? e!.serviceCommissionPct!.toStringAsFixed(0)
            : '');
    _category = e?.category ?? SalonServiceCategory.femme;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _priceController.dispose();
    _durationController.dispose();
    _commissionController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    final price = double.tryParse(_priceController.text.trim()) ?? 0;
    final duration = int.tryParse(_durationController.text.trim());
    final commission = double.tryParse(_commissionController.text.trim());
    final service = SalonService(
      id: widget.existing?.id ?? const Uuid().v4(),
      name: _nameController.text.trim(),
      category: _category,
      priceCdf: price,
      durationMinutes: (duration != null && duration > 0) ? duration : null,
      serviceCommissionPct: commission,
      active: widget.existing?.active ?? true,
      position: widget.existing?.position ?? 0,
    );
    await widget.repo.upsert(service);
    if (!mounted) return;
    Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isEditing = widget.existing != null;
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
                        isEditing
                            ? 'Modifier la prestation'
                            : 'Nouvelle prestation',
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
                      textCapitalization: TextCapitalization.sentences,
                      decoration: const InputDecoration(
                        labelText: 'Nom *',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.content_cut),
                      ),
                      validator: (v) => (v == null || v.trim().isEmpty)
                          ? 'Le nom est requis'
                          : null,
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<SalonServiceCategory>(
                      value: _category,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'Catégorie',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.category),
                      ),
                      items: [
                        for (final c in SalonServiceCategory.values)
                          DropdownMenuItem(value: c, child: Text(c.label)),
                      ],
                      onChanged: (v) {
                        if (v != null) setState(() => _category = v);
                      },
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _priceController,
                      keyboardType: TextInputType.number,
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(
                            RegExp(r'^\d+\.?\d{0,2}')),
                      ],
                      decoration: const InputDecoration(
                        labelText: 'Prix (CDF) *',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.sell),
                      ),
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) {
                          return 'Le prix est requis';
                        }
                        final price = double.tryParse(v.trim());
                        if (price == null || price <= 0) return 'Prix invalide';
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _durationController,
                            keyboardType: TextInputType.number,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                            ],
                            decoration: const InputDecoration(
                              labelText: 'Durée (min)',
                              border: OutlineInputBorder(),
                              prefixIcon: Icon(Icons.schedule),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextFormField(
                            controller: _commissionController,
                            keyboardType: TextInputType.number,
                            inputFormatters: [
                              FilteringTextInputFormatter.allow(
                                  RegExp(r'^\d+\.?\d{0,2}')),
                            ],
                            decoration: const InputDecoration(
                              labelText: 'Commission %',
                              hintText: 'Coiffeur',
                              border: OutlineInputBorder(),
                              prefixIcon: Icon(Icons.percent),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Commission facultative : si vide, on applique le taux du coiffeur.',
                      style: theme.textTheme.bodySmall
                          ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
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
                      label:
                          Text(isEditing ? 'Enregistrer' : 'Ajouter à la carte'),
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
