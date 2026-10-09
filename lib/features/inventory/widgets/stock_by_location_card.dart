import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../constants/spacing.dart';
import '../../../core/enums/business_unit_enums.dart';
import '../../../core/services/api_client.dart';
import '../../business_unit/models/business_unit.dart';
import '../../business_unit/repositories/business_unit_repository.dart';
import '../models/product.dart';

/// Une ligne de stock : un emplacement (unité d'affaires) ou la part non
/// affectée (niveau entreprise, `businessUnitId == null`).
class _Ligne {
  const _Ligne(this.businessUnitId, this.nom, this.quantite);
  final String? businessUnitId;
  final String nom;
  final double quantite;
}

/// Stock d'un article par emplacement (magasin, succursale, dépôt) et
/// transfert entre emplacements. Les emplacements sont les unités d'affaires
/// de l'entreprise ; la part qui n'est rangée nulle part est « Non affecté ».
/// Le transfert ne change pas le stock total. Il demande une connexion : le
/// serveur vérifie le stock disponible à la source.
class StockByLocationCard extends StatefulWidget {
  const StockByLocationCard({super.key, required this.product});

  final Product product;

  @override
  State<StockByLocationCard> createState() => _StockByLocationCardState();
}

class _StockByLocationCardState extends State<StockByLocationCard> {
  static const _nonAffecte = 'Non affecté (entreprise)';

  List<_Ligne>? _lignes;
  String? _erreur;
  bool _chargement = true;

  @override
  void initState() {
    super.initState();
    _charger();
  }

  Map<String, dynamic> _deballer(dynamic r) {
    if (r is Map && r['data'] is Map) return Map<String, dynamic>.from(r['data']);
    if (r is Map) return Map<String, dynamic>.from(r);
    return const {};
  }

  Future<void> _charger() async {
    setState(() {
      _chargement = true;
      _erreur = null;
    });
    try {
      final r = await ApiClient().get(
        'stock-transactions/by-location/${widget.product.id}',
        requiresAuth: true,
      );
      final m = _deballer(r);
      final lignes = <_Ligne>[
        _Ligne(null, _nonAffecte, (m['unallocated'] as num?)?.toDouble() ?? 0),
        for (final l in (m['locations'] as List? ?? const []))
          _Ligne(
            l['businessUnitId'] as String?,
            (l['name'] as String?) ?? 'Emplacement',
            (l['quantity'] as num?)?.toDouble() ?? 0,
          ),
      ];
      if (!mounted) return;
      setState(() {
        _lignes = lignes;
        _chargement = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _erreur = 'Stock par emplacement indisponible hors connexion.';
        _chargement = false;
      });
    }
  }

  String _qte(double q) =>
      q == q.roundToDouble() ? q.toStringAsFixed(0) : q.toStringAsFixed(2);

  Future<void> _transferer() async {
    final lignes = _lignes;
    if (lignes == null) return;
    List<BusinessUnit> unites;
    try {
      unites = await context.read<BusinessUnitRepository>().getAllLocalBusinessUnits();
    } catch (_) {
      unites = const [];
    }
    // Destinations : chaque unité hors entreprise (l'entreprise = non affecté).
    final destinations = <_Ligne>[
      const _Ligne(null, _nonAffecte, 0),
      for (final u in unites.where((u) => u.type != BusinessUnitType.company))
        _Ligne(u.id, u.name, 0),
    ];
    final sources = lignes.where((l) => l.quantite > 0).toList();
    if (!mounted) return;
    if (destinations.length < 2) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            "Créez d'abord un magasin, une succursale ou un dépôt (Paramètres, unités d'affaires).",
          ),
        ),
      );
      return;
    }
    if (sources.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Aucun stock à transférer pour cet article.')),
      );
      return;
    }
    final fait = await showDialog<bool>(
      context: context,
      builder: (_) => _TransfertDialog(
        product: widget.product,
        sources: sources,
        destinations: destinations,
      ),
    );
    if (fait == true) _charger();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.only(bottom: WanzoSpacing.lg),
      child: Padding(
        padding: const EdgeInsets.all(WanzoSpacing.base),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.warehouse_outlined, size: 20),
                const SizedBox(width: WanzoSpacing.sm),
                Expanded(
                  child: Text('Stock par emplacement', style: theme.textTheme.titleMedium),
                ),
                OutlinedButton.icon(
                  onPressed: _chargement || _lignes == null ? null : _transferer,
                  icon: const Icon(Icons.swap_horiz, size: 18),
                  label: const Text('Transférer'),
                ),
              ],
            ),
            const SizedBox(height: WanzoSpacing.sm),
            if (_chargement)
              const LinearProgressIndicator()
            else if (_erreur != null)
              Row(
                children: [
                  Expanded(child: Text(_erreur!, style: theme.textTheme.bodySmall)),
                  TextButton(onPressed: _charger, child: const Text('Réessayer')),
                ],
              )
            else
              for (final l in _lignes!)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: WanzoSpacing.xs),
                  child: Row(
                    children: [
                      Icon(
                        l.businessUnitId == null ? Icons.business_outlined : Icons.store_outlined,
                        size: 18,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                      const SizedBox(width: WanzoSpacing.sm),
                      Expanded(child: Text(l.nom)),
                      Text(
                        '${_qte(l.quantite)} ${widget.product.unit.name}',
                        style: theme.textTheme.titleSmall,
                      ),
                    ],
                  ),
                ),
          ],
        ),
      ),
    );
  }
}

class _TransfertDialog extends StatefulWidget {
  const _TransfertDialog({
    required this.product,
    required this.sources,
    required this.destinations,
  });

  final Product product;
  final List<_Ligne> sources;
  final List<_Ligne> destinations;

  @override
  State<_TransfertDialog> createState() => _TransfertDialogState();
}

class _TransfertDialogState extends State<_TransfertDialog> {
  late _Ligne _source = widget.sources.first;
  _Ligne? _destination;
  final _quantite = TextEditingController();
  final _notes = TextEditingController();
  bool _envoi = false;
  String? _erreur;

  List<_Ligne> get _destinationsPossibles => widget.destinations
      .where((d) => d.businessUnitId != _source.businessUnitId)
      .toList();

  double get _valeur => double.tryParse(_quantite.text.replaceAll(',', '.')) ?? 0;

  bool get _valide =>
      _destination != null && _valeur > 0 && _valeur <= _source.quantite && !_envoi;

  Future<void> _valider() async {
    setState(() {
      _envoi = true;
      _erreur = null;
    });
    try {
      await ApiClient().post(
        'stock-transactions/transfer',
        body: {
          'productId': widget.product.id,
          'fromBusinessUnitId': _source.businessUnitId,
          'toBusinessUnitId': _destination!.businessUnitId,
          'quantity': _valeur,
          if (_notes.text.trim().isNotEmpty) 'notes': _notes.text.trim(),
        },
        requiresAuth: true,
      );
      if (!mounted) return;
      Navigator.pop(context, true);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Transféré vers ${_destination!.nom}')),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _envoi = false;
        _erreur = 'Transfert impossible : $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final dispo = _source.quantite;
    return AlertDialog(
      title: Text('Transférer ${widget.product.name}'),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DropdownButtonFormField<_Ligne>(
              value: _source,
              decoration: const InputDecoration(labelText: 'Depuis'),
              items: [
                for (final s in widget.sources)
                  DropdownMenuItem(value: s, child: Text('${s.nom} (${s.quantite})')),
              ],
              onChanged: (v) => setState(() {
                _source = v!;
                if (_destination?.businessUnitId == _source.businessUnitId) {
                  _destination = null;
                }
              }),
            ),
            const SizedBox(height: WanzoSpacing.md),
            DropdownButtonFormField<_Ligne>(
              value: _destination,
              decoration: const InputDecoration(labelText: 'Vers'),
              items: [
                for (final d in _destinationsPossibles)
                  DropdownMenuItem(value: d, child: Text(d.nom)),
              ],
              onChanged: (v) => setState(() => _destination = v),
            ),
            const SizedBox(height: WanzoSpacing.md),
            TextField(
              controller: _quantite,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))],
              decoration: InputDecoration(
                labelText: 'Quantité (${widget.product.unit.name})',
                helperText: 'Disponible : $dispo',
                errorText: _valeur > dispo ? 'Plus que le disponible' : null,
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: WanzoSpacing.md),
            TextField(
              controller: _notes,
              decoration: const InputDecoration(labelText: 'Note (facultatif)'),
            ),
            if (_erreur != null) ...[
              const SizedBox(height: WanzoSpacing.md),
              Text(_erreur!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _envoi ? null : () => Navigator.pop(context, false),
          child: const Text('Annuler'),
        ),
        FilledButton.icon(
          onPressed: _valide ? _valider : null,
          icon: _envoi
              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
              : const Icon(Icons.swap_horiz, size: 18),
          label: const Text('Transférer'),
        ),
      ],
    );
  }
}
