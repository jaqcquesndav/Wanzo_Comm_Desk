import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:wanzo/core/shared_widgets/empty_state_view.dart';
import 'package:wanzo/core/utils/currency_formatter.dart';

import '../cubit/services_cubit.dart';
import '../models/service_item.dart';

/// Onglet « Services » de la page Offre : catalogue des services à paliers de
/// prix, recherche, filtre par catégorie, activation rapide. La création et la
/// modification sont déléguées au parent (page ou modal selon la plateforme).
class ServicesTab extends StatefulWidget {
  final VoidCallback onAdd;
  final ValueChanged<ServiceItem> onEdit;

  const ServicesTab({super.key, required this.onAdd, required this.onEdit});

  @override
  State<ServicesTab> createState() => _ServicesTabState();
}

class _ServicesTabState extends State<ServicesTab> {
  final _searchCtrl = TextEditingController();
  String _query = '';
  String? _category;

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ServicesCubit, ServicesState>(
      builder: (context, state) {
        if (state.loading && state.items.isEmpty) {
          return const Center(child: CircularProgressIndicator());
        }
        if (state.items.isEmpty) {
          return EmptyStateView(
            icon: Icons.design_services_outlined,
            message: state.error != null
                ? 'Impossible de charger les services.\n${state.error}'
                : 'Aucun service configuré.\nAjoutez vos prestations avec leurs paliers de prix : elles seront proposées à la facturation.',
            actionLabel: 'Ajouter un service',
            actionIcon: Icons.add,
            onAction: widget.onAdd,
          );
        }

        final q = _query.trim().toLowerCase();
        final items = state.items.where((s) {
          final catOk = _category == null || (s.category ?? '') == _category;
          if (!catOk) return false;
          if (q.isEmpty) return true;
          return s.name.toLowerCase().contains(q) ||
              (s.category ?? '').toLowerCase().contains(q) ||
              (s.description ?? '').toLowerCase().contains(q);
        }).toList();

        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
              child: TextField(
                controller: _searchCtrl,
                decoration: InputDecoration(
                  hintText: 'Rechercher un service',
                  prefixIcon: const Icon(Icons.search),
                  isDense: true,
                  border: const OutlineInputBorder(),
                  suffixIcon: _query.isEmpty
                      ? null
                      : IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () {
                            _searchCtrl.clear();
                            setState(() => _query = '');
                          },
                        ),
                ),
                onChanged: (v) => setState(() => _query = v),
              ),
            ),
            if (state.categories.isNotEmpty)
              SizedBox(
                height: 44,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: FilterChip(
                        label: const Text('Toutes'),
                        selected: _category == null,
                        onSelected: (_) => setState(() => _category = null),
                      ),
                    ),
                    for (final c in state.categories)
                      Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: FilterChip(
                          label: Text(c),
                          selected: _category == c,
                          onSelected: (_) => setState(() => _category = _category == c ? null : c),
                        ),
                      ),
                  ],
                ),
              ),
            Expanded(
              child: items.isEmpty
                  ? Center(
                      child: Text(
                        'Aucun service ne correspond à cette recherche.',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(12, 4, 12, 96),
                      itemCount: items.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (context, i) => _ServiceTile(
                        service: items[i],
                        onTap: () => widget.onEdit(items[i]),
                        onToggleActive: () => context.read<ServicesCubit>().toggleActive(items[i]),
                        onDelete: () => _confirmDelete(context, items[i]),
                      ),
                    ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _confirmDelete(BuildContext context, ServiceItem service) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Supprimer ce service ?'),
        content: Text('« ${service.name} » ne sera plus proposé à la facturation. Les ventes passées sont conservées.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annuler')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Supprimer')),
        ],
      ),
    );
    if (ok == true && context.mounted) {
      await context.read<ServicesCubit>().delete(service);
    }
  }
}

class _ServiceTile extends StatelessWidget {
  final ServiceItem service;
  final VoidCallback onTap;
  final VoidCallback onToggleActive;
  final VoidCallback onDelete;

  const _ServiceTile({
    required this.service,
    required this.onTap,
    required this.onToggleActive,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurface.withAlpha((0.6 * 255).round());
    final meta = <String>[
      if ((service.category ?? '').isNotEmpty) service.category!,
      if (service.durationMinutes != null) '${service.durationMinutes} min',
      if (service.isPublic) 'Catalogue public',
      if (service.pendingSync) 'À synchroniser',
    ].join(' · ');

    return Card(
      margin: EdgeInsets.zero,
      child: InkWell(
        onTap: onTap,
        onLongPress: onDelete,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 4, 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withAlpha((0.1 * 255).round()),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(Icons.design_services_outlined, color: theme.colorScheme.primary, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      service.name,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: service.active ? null : muted,
                        decoration: service.active ? null : TextDecoration.lineThrough,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (meta.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(meta, style: theme.textTheme.bodySmall?.copyWith(color: muted)),
                      ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: [
                        for (final t in service.priceTiers)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: t.isDefault
                                  ? theme.colorScheme.primary.withAlpha((0.12 * 255).round())
                                  : theme.colorScheme.surfaceContainerHighest,
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              '${t.label} · ${formatCurrency(t.priceCdf, 'CDF')}',
                              style: theme.textTheme.labelSmall?.copyWith(
                                fontWeight: t.isDefault ? FontWeight.w600 : FontWeight.w500,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              Switch(
                value: service.active,
                onChanged: (_) => onToggleActive(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
