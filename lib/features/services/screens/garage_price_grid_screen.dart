import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:uuid/uuid.dart';

import '../config/garage_vehicle_categories.dart';
import '../cubit/services_cubit.dart';
import '../models/service_item.dart';

/// Barème du garage : une prestation par ligne, une catégorie de véhicule par
/// colonne.
///
/// C'est la façon dont un garage tarifie réellement. Saisir ce barème une
/// prestation à la fois, avec neuf cartes de prix chacune, était impraticable :
/// vingt prestations font cent quatre-vingts cartes. Ici tout tient dans un
/// tableau, on remplit ce qui s'applique, et les cases vides ne sont pas
/// enregistrées.
///
/// Chaque ligne devient un service, chaque colonne remplie un palier de prix.
/// Le modèle existant suffit : rien de nouveau côté serveur.
class GaragePriceGridScreen extends StatefulWidget {
  /// Prestations déjà enregistrées, rechargées dans la grille.
  final List<ServiceItem> existing;

  const GaragePriceGridScreen({super.key, this.existing = const []});

  @override
  State<GaragePriceGridScreen> createState() => _GaragePriceGridScreenState();
}

class _GaragePriceGridScreenState extends State<GaragePriceGridScreen> {
  /// Colonnes retenues. Un garage qui ne touche pas aux poids lourds décoche
  /// la colonne et gagne de la place.
  late final Set<String> _columns = {
    for (final c in kGarageVehicleCategories) c.code,
  };

  final List<_GridRow> _rows = [];
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    for (final s in widget.existing) {
      _rows.add(_GridRow.fromService(s));
    }
    if (_rows.isEmpty) _seedStandardWorks();
  }

  @override
  void dispose() {
    for (final r in _rows) {
      r.dispose();
    }
    super.dispose();
  }

  /// Amorce la grille avec les prestations courantes d'un garage mécanique :
  /// on retire ce qu'on ne fait pas plutôt que de tout taper.
  void _seedStandardWorks() {
    for (final name in kGarageStandardWorks) {
      _rows.add(_GridRow(name: name));
    }
  }

  List<GarageVehicleCategory> get _activeColumns => [
        for (final c in kGarageVehicleCategories)
          if (_columns.contains(c.code)) c,
      ];

  Future<void> _save() async {
    final cubit = ServicesCubit();
    final items = <ServiceItem>[];

    for (final row in _rows) {
      final name = row.name.text.trim();
      if (name.isEmpty) continue;

      final tiers = <ServicePriceTier>[];
      for (final c in _activeColumns) {
        final raw = row.prices[c.code]?.text.trim() ?? '';
        if (raw.isEmpty) continue; // case vide : prestation non pratiquée
        final value = double.tryParse(raw.replaceAll(',', '.'));
        if (value == null || value <= 0) continue;
        tiers.add(c.toTier(priceCdf: value, isDefault: tiers.isEmpty));
      }
      // Une prestation sans aucun prix n'est pas encore un service.
      if (tiers.isEmpty) continue;

      items.add(ServiceItem(
        id: row.id ?? const Uuid().v4(),
        name: name,
        category: row.category.text.trim().isEmpty
            ? null
            : row.category.text.trim(),
        priceTiers: tiers,
        metier: cubit.metierToStamp,
        activityModes: [cubit.currentModeCode],
        active: true,
      ));
    }

    if (items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Renseignez au moins un prix pour enregistrer le barème.'),
        backgroundColor: Colors.orange,
      ));
      return;
    }

    setState(() => _saving = true);
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await cubit.importAll(items);
      navigator.pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      messenger.showSnackBar(SnackBar(content: Text('Échec : $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final columns = _activeColumns;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Barème du garage'),
        actions: [
          TextButton.icon(
            onPressed: _saving ? null : _save,
            icon: _saving
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.check),
            label: const Text('Enregistrer'),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
            child: Text(
              'Un prix par catégorie de véhicule. Laissez vide ce que vous ne '
              'faites pas sur cette catégorie.',
              style: theme.textTheme.bodySmall,
            ),
          ),
          SizedBox(
            height: 44,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              children: [
                for (final c in kGarageVehicleCategories)
                  Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: FilterChip(
                      label: Text(c.label),
                      selected: _columns.contains(c.code),
                      onSelected: (on) => setState(() {
                        if (on) {
                          _columns.add(c.code);
                        } else {
                          _columns.remove(c.code);
                        }
                      }),
                    ),
                  ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: SingleChildScrollView(
                child: DataTable(
                  columnSpacing: 18,
                  headingRowHeight: 44,
                  dataRowMinHeight: 52,
                  dataRowMaxHeight: 60,
                  columns: [
                    const DataColumn(label: Text('Prestation')),
                    for (final c in columns)
                      DataColumn(
                        label: Tooltip(message: c.hint, child: Text(c.label)),
                      ),
                    const DataColumn(label: Text('')),
                  ],
                  rows: [
                    for (var i = 0; i < _rows.length; i++)
                      DataRow(cells: [
                        DataCell(SizedBox(
                          width: 210,
                          child: TextField(
                            controller: _rows[i].name,
                            decoration: const InputDecoration(
                              isDense: true,
                              border: InputBorder.none,
                              hintText: 'Nom de la prestation',
                            ),
                          ),
                        )),
                        for (final c in columns)
                          DataCell(SizedBox(
                            width: 92,
                            child: TextField(
                              controller: _rows[i].priceFor(c.code),
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                      decimal: true),
                              inputFormatters: [
                                FilteringTextInputFormatter.allow(
                                    RegExp(r'[0-9.,]')),
                              ],
                              textAlign: TextAlign.right,
                              decoration: const InputDecoration(
                                isDense: true,
                                border: InputBorder.none,
                                hintText: '—',
                              ),
                            ),
                          )),
                        DataCell(IconButton(
                          tooltip: 'Retirer la prestation',
                          icon: const Icon(Icons.close, size: 18),
                          onPressed: () =>
                              setState(() => _rows.removeAt(i).dispose()),
                        )),
                      ]),
                  ],
                ),
              ),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  OutlinedButton.icon(
                    onPressed: () => setState(() => _rows.add(_GridRow())),
                    icon: const Icon(Icons.add),
                    label: const Text('Prestation'),
                  ),
                  const Spacer(),
                  Text('${_rows.length} ligne(s)',
                      style: theme.textTheme.bodySmall),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Une ligne du barème : la prestation et ses prix par catégorie.
class _GridRow {
  final String? id;
  final TextEditingController name;
  final TextEditingController category;
  final Map<String, TextEditingController> prices = {};

  _GridRow({String? name, String? category, this.id})
      : name = TextEditingController(text: name ?? ''),
        category = TextEditingController(text: category ?? '');

  factory _GridRow.fromService(ServiceItem s) {
    final row = _GridRow(name: s.name, category: s.category, id: s.id);
    for (final t in s.priceTiers) {
      row.priceFor(t.code).text =
          t.priceCdf == t.priceCdf.roundToDouble()
              ? t.priceCdf.toInt().toString()
              : t.priceCdf.toString();
    }
    return row;
  }

  TextEditingController priceFor(String code) =>
      prices.putIfAbsent(code, () => TextEditingController());

  void dispose() {
    name.dispose();
    category.dispose();
    for (final c in prices.values) {
      c.dispose();
    }
  }
}
