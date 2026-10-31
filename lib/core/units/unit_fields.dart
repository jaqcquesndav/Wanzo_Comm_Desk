import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../shared_widgets/searchable_select.dart';
import 'measurement_units.dart';

/// Langue des libellés d'unité : celle de l'app (fr, en, sw, ln), fr sinon.
String unitLang(BuildContext context) {
  final code = Localizations.maybeLocaleOf(context)?.languageCode ?? 'fr';
  return const {'fr', 'en', 'sw', 'ln'}.contains(code) ? code : 'fr';
}

/// Nombre de fiches par unité : les unités de la boutique en tête de liste.
Map<String, int> unitUsage(Iterable<String> codes) {
  final out = <String, int>{};
  for (final c in codes) {
    out[c] = (out[c] ?? 0) + 1;
  }
  return out;
}

/// Choix d'une unité du catalogue : recherche, tri par usage, type en
/// sous-titre (Emballage, Poids...). Un code inconnu (version plus récente du
/// serveur) reste affiché tel quel et sélectionnable.
class MeasurementUnitField extends StatelessWidget {
  final String label;
  final String? value;
  final ValueChanged<String> onChanged;
  final Map<String, int> usage;
  final List<String>? only;

  const MeasurementUnitField({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
    this.usage = const {},
    this.only,
  });

  @override
  Widget build(BuildContext context) {
    final lang = unitLang(context);
    final codes = only ?? MeasurementUnits.sortedCodes(usage: usage);
    final items = [
      if (value != null && !codes.contains(value)) value!,
      ...codes,
    ];
    return SearchSelectField<String>(
      label: label,
      hint: '-',
      value: value,
      items: items,
      itemLabel: (c) => MeasurementUnits.label(c, lang),
      itemSubtitle: (c) {
        final def = MeasurementUnits.of(c);
        return def == null ? '' : MeasurementUnits.kindLabel(def.kind);
      },
      onChanged: (c) {
        if (c != null) onChanged(c);
      },
    );
  }
}

/// Conditionnements d'un produit : « Vendu aussi par » carton, demi-carton,
/// sac... Le contenu est proposé d'office (douzaine 12, plateau 30, sac de
/// 50 kg 50, demi-carton = moitié du carton). Prix du conditionnement
/// facultatif, dans la devise de saisie du formulaire ([priceSuffix]).
class PackagingEditor extends StatefulWidget {
  final String baseUnitCode;
  final List<ProductPackaging> initial;
  final ValueChanged<List<ProductPackaging>> onChanged;
  final String priceSuffix;

  const PackagingEditor({
    super.key,
    required this.baseUnitCode,
    required this.initial,
    required this.onChanged,
    this.priceSuffix = '',
  });

  @override
  State<PackagingEditor> createState() => _PackagingEditorState();
}

class _PackagingRow {
  String code;
  final TextEditingController contains;
  final TextEditingController price;
  _PackagingRow(this.code, String contains, String price)
      : contains = TextEditingController(text: contains),
        price = TextEditingController(text: price);
}

class _PackagingEditorState extends State<PackagingEditor> {
  late final List<_PackagingRow> _rows = [
    for (final p in widget.initial)
      _PackagingRow(
        p.unitCode,
        MeasurementUnits.formatNumber(p.contains).replaceAll(',', '.'),
        p.sellingPriceInCdf == null
            ? ''
            : MeasurementUnits.formatNumber(p.sellingPriceInCdf!)
                .replaceAll(',', '.'),
      ),
  ];

  @override
  void dispose() {
    for (final r in _rows) {
      r.contains.dispose();
      r.price.dispose();
    }
    super.dispose();
  }

  static double? _parse(String s) =>
      double.tryParse(s.trim().replaceAll(' ', '').replaceAll(',', '.'));

  Map<String, double> get _known => {
        for (final r in _rows)
          if ((_parse(r.contains.text) ?? 0) > 0) r.code: _parse(r.contains.text)!,
      };

  void _emit() {
    final seen = <String>{};
    widget.onChanged([
      for (final r in _rows)
        if ((_parse(r.contains.text) ?? 0) > 0 &&
            r.code != widget.baseUnitCode &&
            seen.add(r.code))
          ProductPackaging(
            unitCode: r.code,
            contains: _parse(r.contains.text)!,
            sellingPriceInCdf: _parse(r.price.text),
          ),
    ]);
  }

  String _suggest(String code) {
    final s = MeasurementUnits.suggestedContains(code, widget.baseUnitCode,
        known: _known);
    return s == null ? '' : MeasurementUnits.formatNumber(s).replaceAll(',', '.');
  }

  void _add() {
    final used = {for (final r in _rows) r.code, widget.baseUnitCode};
    final next = ['carton', 'half_carton', 'package', 'dozen', 'bag']
        .firstWhere((c) => !used.contains(c), orElse: () => 'carton');
    setState(() => _rows.add(_PackagingRow(next, _suggest(next), '')));
    _emit();
  }

  /// Carton saisi sans demi-carton : proposé d'un geste (moitié du carton).
  Widget? _halfHint() {
    for (final r in _rows) {
      final half = MeasurementUnits.all
          .where((u) => u.halfOf == r.code)
          .map((u) => u.code)
          .firstOrNull;
      final c = _parse(r.contains.text);
      if (half == null || c == null || c <= 1) continue;
      if (_rows.any((x) => x.code == half) || half == widget.baseUnitCode) {
        continue;
      }
      return Align(
        alignment: Alignment.centerLeft,
        child: TextButton.icon(
          icon: const Icon(Icons.add, size: 18),
          label: Text(
              'Ajouter ${MeasurementUnits.label(half, unitLang(context)).toLowerCase()} '
              '(${MeasurementUnits.formatNumber(c / 2)})'),
          onPressed: () {
            setState(() => _rows.add(_PackagingRow(half,
                MeasurementUnits.formatNumber(c / 2).replaceAll(',', '.'), '')));
            _emit();
          },
        ),
      );
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final lang = unitLang(context);
    final base = MeasurementUnits.label(widget.baseUnitCode, lang).toLowerCase();
    final hint = _halfHint();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < _rows.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 4,
                  child: MeasurementUnitField(
                    label: 'Conditionnement',
                    value: _rows[i].code,
                    only: [
                      for (final c in MeasurementUnits.sortedCodes())
                        if (c != widget.baseUnitCode &&
                            (MeasurementUnits.of(c)?.isPackaging ?? false))
                          c,
                    ],
                    onChanged: (c) {
                      setState(() {
                        _rows[i].code = c;
                        final s = _suggest(c);
                        if (s.isNotEmpty) _rows[i].contains.text = s;
                      });
                      _emit();
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 3,
                  child: TextField(
                    controller: _rows[i].contains,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
                    ],
                    decoration: InputDecoration(
                      labelText: 'Contient',
                      suffixText: base,
                      isDense: true,
                      border: const OutlineInputBorder(),
                    ),
                    onChanged: (_) {
                      setState(() {});
                      _emit();
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 3,
                  child: TextField(
                    controller: _rows[i].price,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
                    ],
                    decoration: InputDecoration(
                      labelText: 'Prix (option)',
                      suffixText: widget.priceSuffix,
                      isDense: true,
                      border: const OutlineInputBorder(),
                    ),
                    onChanged: (_) => _emit(),
                  ),
                ),
                IconButton(
                  tooltip: 'Retirer',
                  icon: const Icon(Icons.close),
                  onPressed: () {
                    setState(() => _rows.removeAt(i));
                    _emit();
                  },
                ),
              ],
            ),
          ),
        if (hint != null) hint,
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            icon: const Icon(Icons.inventory_2_outlined, size: 18),
            label: Text(_rows.isEmpty
                ? 'Vendu aussi au carton, au sac, à la douzaine...'
                : 'Autre conditionnement'),
            onPressed: _add,
          ),
        ),
      ],
    );
  }
}

/// Choix de l'unité d'une ligne (vente, achat, inventaire) parmi la base et
/// les conditionnements du produit. Rien d'affiché sans conditionnement.
class SellableUnitSelector extends StatelessWidget {
  final List<SellableUnit> units;
  final String selected;
  final ValueChanged<SellableUnit> onChanged;

  const SellableUnitSelector({
    super.key,
    required this.units,
    required this.selected,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    if (units.length < 2) return const SizedBox.shrink();
    final lang = unitLang(context);
    return Wrap(
      spacing: 8,
      runSpacing: 4,
      children: [
        for (final u in units)
          ChoiceChip(
            label: Text(u.isBase
                ? MeasurementUnits.label(u.code, lang)
                : '${MeasurementUnits.label(u.code, lang)} (${MeasurementUnits.formatNumber(u.factor)})'),
            selected: u.code == selected,
            onSelected: (_) => onChanged(u),
          ),
      ],
    );
  }
}
