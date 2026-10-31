import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:wanzo/core/units/measurement_units.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/enums/business_unit_enums.dart';
import '../../../core/shared_widgets/wanzo_scaffold.dart';
import '../../business_unit/models/business_unit.dart';
import '../../business_unit/repositories/business_unit_repository.dart';
import '../bloc/inventory_bloc.dart';
import '../bloc/inventory_event.dart';
import '../models/product.dart';
import '../repositories/inventory_repository.dart';
import 'stock_count.dart';

final _qty = NumberFormat('#,##0.###', 'fr');
final _money = NumberFormat('#,##0', 'fr');

/// Inventaire physique : comptage par catégorie ou recherche, saisie ou
/// lecture à la douchette (dans le champ de recherche) des quantités, écart avec le
/// théorique, validation en ajustements signés. Le brouillon est gardé sur
/// l'appareil : on peut compter hors ligne et reprendre plus tard.
class StockCountScreen extends StatefulWidget {
  const StockCountScreen({super.key});

  @override
  State<StockCountScreen> createState() => _StockCountScreenState();
}

class _StockCountScreenState extends State<StockCountScreen> {
  static const _page = 30;
  final _service = StockCountService();
  final _search = TextEditingController();
  StockCountDraft? _draft;
  List<Product> _products = const [];
  /// Emplacements (unités d'affaires hors entreprise). Le choix n'est proposé
  /// qu'à partir de deux.
  List<BusinessUnit> _locations = const [];
  ProductCategory? _category;
  bool _onlyGaps = false;
  int _shown = _page;
  bool _busy = false;

  InventoryRepository get _repo => context.read<InventoryRepository>();

  @override
  void initState() {
    super.initState();
    _products = _repo.getAllProducts()..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    _service.load().then((d) {
      if (!mounted) return;
      setState(() => _draft = d ?? StockCountDraft.start());
    });
    _loadLocations();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _update(StockCountDraft d) async {
    setState(() => _draft = d);
    await _service.save(d);
  }

  void _onCode(String code) {
    if (!mounted || _draft == null || ModalRoute.of(context)?.isCurrent != true) return;
    final p = findProductByCode(_products, code);
    if (p == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Code $code : aucun article (code-barres ou SKU).')),
      );
      return;
    }
    HapticFeedback.selectionClick();
    _update(_draft!.increment(p.id));
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          duration: const Duration(seconds: 1),
          content: Text('${p.name} : ${_qty.format(_draft!.counts[p.id])} compté(s)'),
        ),
      );
  }

  List<Product> get _filtered {
    final q = _search.text.trim().toLowerCase();
    return _products.where((p) {
      if (_category != null && p.category != _category) return false;
      if (q.isNotEmpty &&
          !p.name.toLowerCase().contains(q) &&
          !p.barcode.toLowerCase().contains(q) &&
          !(p.sku ?? '').toLowerCase().contains(q)) {
        return false;
      }
      if (_onlyGaps) {
        final c = _draft?.counts[p.id];
        if (c == null || c == _draft!.theoreticalOf(p)) return false;
      }
      return true;
    }).toList();
  }

  Future<void> _loadLocations() async {
    try {
      final units = await context.read<BusinessUnitRepository>().getAllLocalBusinessUnits();
      if (!mounted) return;
      setState(() {
        _locations = units.where((u) => u.type != BusinessUnitType.company).toList()
          ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
      });
    } catch (_) {
      // Pas d'unités connues : inventaire global seulement.
    }
  }

  /// Change l'emplacement compté (null = tous). Le théorique devient le stock
  /// de l'emplacement, lu sur le serveur ; les comptages en cours repartent
  /// de zéro (ils portaient sur un autre stock).
  Future<void> _changeLocation(String? id) async {
    final draft = _draft;
    if (draft == null || id == draft.locationId) return;
    if (draft.counts.isNotEmpty) {
      final ok = await _confirm(
        'Changer d\'emplacement',
        'Les ${draft.counts.length} comptage(s) en cours seront effacés.',
      );
      if (!ok || !mounted) return;
    }
    var stock = const <String, double>{};
    String? name;
    if (id != null) {
      name = _locations.where((u) => u.id == id).firstOrNull?.name;
      setState(() => _busy = true);
      try {
        stock = await StockCountService.fetchLocationStock(id);
      } catch (_) {
        if (mounted) {
          setState(() => _busy = false);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Stock de l\'emplacement indisponible hors connexion. Réessayez une fois connecté.')),
          );
        }
        return;
      }
      if (!mounted) return;
      setState(() => _busy = false);
    }
    await _update(draft.forLocation(id, name, stock));
  }

  Future<void> _editCount(Product p) async {
    final ctrl = TextEditingController(
      text: _draft!.counts[p.id] == null ? '' : _qty.format(_draft!.counts[p.id]).replaceAll(' ', ''),
    );
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(p.name, maxLines: 2, overflow: TextOverflow.ellipsis),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))],
          decoration: InputDecoration(
            labelText: 'Quantité comptée',
            // Compté dans l'unité de référence (cartons), demis acceptés.
            suffixText: MeasurementUnits.label(p.baseUnitCode),
            helperText: 'Théorique : ${MeasurementUnits.formatStockBreakdown(_draft!.theoreticalOf(p), p.baseUnitCode, p.unitOptions)}',
          ),
          onSubmitted: (v) => Navigator.pop(ctx, v),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, '__clear__'), child: const Text('Effacer')),
          // « ½ » : un carton entamé compte pour un demi (2 -> 2,5).
          if (MeasurementUnits.fractionsOf(p.baseUnitCode, p.unitOptions).contains(0.5))
            TextButton(
              onPressed: () {
                final v = double.tryParse(ctrl.text.replaceAll(',', '.').replaceAll(' ', '')) ?? 0;
                ctrl.text = MeasurementUnits.formatNumber(v.floor() + 0.5);
              },
              child: const Text('½'),
            ),
          FilledButton(onPressed: () => Navigator.pop(ctx, ctrl.text), child: const Text('OK')),
        ],
      ),
    );
    if (result == null) return;
    if (result == '__clear__' || result.trim().isEmpty) {
      await _update(_draft!.withCount(p.id, null));
      return;
    }
    final v = double.tryParse(result.replaceAll(',', '.').replaceAll(' ', ''));
    if (v == null || v < 0) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Quantité invalide')));
      }
      return;
    }
    await _update(_draft!.withCount(p.id, v));
  }

  Future<void> _validate() async {
    var draft = _draft!;
    // Emplacement : théorique relu au moment de valider (dernier connu hors ligne).
    if (draft.locationId != null) {
      try {
        draft = draft.withLocationStock(await StockCountService.fetchLocationStock(draft.locationId!));
        await _update(draft);
      } catch (_) {}
      if (!mounted) return;
    }
    final gaps = stockCountGaps(_products, draft);
    if (gaps.isEmpty) {
      final ok = await _confirm(
        'Aucun écart',
        '${draft.counts.length} article(s) comptés, tous conformes. Terminer l\'inventaire ?',
      );
      if (ok) {
        await _service.clear();
        if (mounted) setState(() => _draft = StockCountDraft.start());
      }
      return;
    }
    final value = gaps.fold<double>(0, (s, g) => s + g.valueInCdf);
    final ok = await _confirm(
      'Valider l\'inventaire',
      '${gaps.length} écart(s) sur ${draft.counts.length} article(s) comptés.\n'
          'Valeur de l\'écart : ${_money.format(value)} CDF.\n\n'
          'Un ajustement de stock sera enregistré pour chaque écart (référence ${draft.reference}).',
    );
    if (!ok || !mounted) return;
    setState(() => _busy = true);
    final result = await StockCountService.apply(_repo, draft, gaps);
    if (!mounted) return;
    // Seuls les articles refusés restent dans le brouillon.
    final remaining = draft.onlyCounts(result.refused.keys);
    if (remaining.counts.isEmpty) {
      await _service.clear();
    } else {
      await _service.save(remaining);
    }
    if (!mounted) return;
    setState(() {
      _busy = false;
      _draft = remaining.counts.isEmpty ? StockCountDraft.start() : remaining;
      _products = _repo.getAllProducts()..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    });
    context.read<InventoryBloc>().add(const LoadProducts());
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          result.refused.isEmpty
              ? '${result.applied} ajustement(s) enregistré(s).'
              : '${result.applied} ajustement(s) enregistré(s), ${result.refused.length} refusé(s) : ${result.refused.values.first}',
        ),
      ),
    );
  }

  Future<bool> _confirm(String title, String body) async =>
      await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(title),
          content: Text(body),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annuler')),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Valider')),
          ],
        ),
      ) ??
      false;

  Future<void> _restart() async {
    final ok = await _confirm('Recommencer', 'Effacer tous les comptages en cours ?');
    if (!ok) return;
    await _service.clear();
    if (mounted) setState(() => _draft = StockCountDraft.start());
  }

  @override
  Widget build(BuildContext context) {
    final draft = _draft;
    final categories = {for (final p in _products) p.category}.toList()
      ..sort((a, b) => a.displayName.compareTo(b.displayName));
    final list = _filtered;
    final visible = list.take(_shown).toList();
    final gaps = draft == null ? const <StockCountGap>[] : stockCountGaps(_products, draft);

    return WanzoScaffold(
      currentIndex: 2,
      title: 'Inventaire',
      onBackPressed: () => context.canPop() ? context.pop() : context.go('/inventory'),
      appBarActions: [
        PopupMenuButton<String>(
          tooltip: 'Plus d\'actions',
          onSelected: (v) => v == 'restart' ? _restart() : null,
          itemBuilder: (_) => const [
            PopupMenuItem(value: 'restart', child: Text('Recommencer le comptage')),
          ],
        ),
      ],
      body: draft == null
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                  child: Column(
                    children: [
                      TextField(
                        controller: _search,
                        decoration: const InputDecoration(
                          prefixIcon: Icon(Icons.search),
                          hintText: 'Nom, code-barres ou SKU',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                        onChanged: (_) => setState(() => _shown = _page),
                        onSubmitted: (v) {
                          // Douchette en émulation clavier dans le champ.
                          final p = findProductByCode(_products, v);
                          if (p != null) {
                            _search.clear();
                            _onCode(v);
                          }
                        },
                      ),
                      if (_locations.length >= 2) ...[
                        const SizedBox(height: 8),
                        DropdownButtonFormField<String?>(
                          value: _locations.any((u) => u.id == draft.locationId) ? draft.locationId : null,
                          isExpanded: true,
                          decoration: const InputDecoration(
                            labelText: 'Emplacement',
                            helperText: 'Tous : stock de l\'article. Un emplacement : son stock seul.',
                            border: OutlineInputBorder(),
                            isDense: true,
                          ),
                          items: [
                            const DropdownMenuItem<String?>(value: null, child: Text('Tous')),
                            for (final u in _locations)
                              DropdownMenuItem<String?>(
                                value: u.id,
                                child: Text(u.name, overflow: TextOverflow.ellipsis),
                              ),
                          ],
                          onChanged: _busy ? null : _changeLocation,
                        ),
                      ],
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: DropdownButtonFormField<ProductCategory?>(
                              value: _category,
                              isExpanded: true,
                              decoration: const InputDecoration(
                                labelText: 'Catégorie',
                                border: OutlineInputBorder(),
                                isDense: true,
                              ),
                              items: [
                                const DropdownMenuItem(value: null, child: Text('Toutes')),
                                for (final c in categories)
                                  DropdownMenuItem(value: c, child: Text(c.displayName, overflow: TextOverflow.ellipsis)),
                              ],
                              onChanged: (c) => setState(() {
                                _category = c;
                                _shown = _page;
                              }),
                            ),
                          ),
                          const SizedBox(width: 8),
                          FilterChip(
                            label: const Text('Écarts'),
                            selected: _onlyGaps,
                            onSelected: (v) => setState(() => _onlyGaps = v),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${draft.reference} · ${draft.counts.length} compté(s) · ${gaps.length} écart(s)',
                        style: Theme.of(context).textTheme.bodySmall,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: list.isEmpty
                      ? const Center(child: Text('Aucun article.'))
                      : ListView.builder(
                          itemCount: visible.length + (list.length > _shown ? 1 : 0),
                          itemBuilder: (context, i) {
                            if (i == visible.length) {
                              return TextButton(
                                onPressed: () => setState(() => _shown += _page),
                                child: Text('Voir plus (${list.length - _shown} restants)'),
                              );
                            }
                            final p = visible[i];
                            final counted = draft.counts[p.id];
                            final theoretical = draft.theoreticalOf(p);
                            final diff = counted == null ? null : counted - theoretical;
                            return ListTile(
                              title: Text(p.name, maxLines: 1, overflow: TextOverflow.ellipsis),
                              subtitle: Text(
                                'Théorique ${_qty.format(theoretical)}'
                                '${diff == null ? '' : ' · écart ${diff > 0 ? '+' : ''}${_qty.format(diff)}'}',
                                style: TextStyle(
                                  color: diff == null || diff == 0
                                      ? null
                                      : (diff < 0 ? Colors.red.shade700 : Colors.orange.shade800),
                                ),
                              ),
                              trailing: Text(
                                counted == null ? 'À compter' : _qty.format(counted),
                                style: TextStyle(
                                  fontWeight: counted == null ? FontWeight.normal : FontWeight.bold,
                                ),
                              ),
                              onTap: () => _editCount(p),
                            );
                          },
                        ),
                ),
                SafeArea(
                  top: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
                    child: SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: _busy || draft.counts.isEmpty ? null : _validate,
                        icon: _busy
                            ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                            : const Icon(Icons.fact_check),
                        label: Text(gaps.isEmpty ? 'Terminer l\'inventaire' : 'Valider ${gaps.length} écart(s)'),
                      ),
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}
