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

/// Options de l'unité d'un produit, dans la fiche :
/// - « Se vend au demi » (actif d'office pour un carton, un sac, un pagne,
///   une douzaine, un plateau), « et au quart » en option, prix du demi
///   proposé à la moitié et modifiable ;
/// - « Contient N pièces » (1 carton = 24 bouteilles), nombre proposé
///   d'office (douzaine 12, plateau 30, sac de 50 kg 50), prix à la pièce.
/// Les prix sont dans la devise de saisie du formulaire ([priceSuffix]) ;
/// [basePrice] (même devise) sert aux valeurs proposées.
class UnitOptionsEditor extends StatefulWidget {
  final String baseUnitCode;
  final ProductUnitOptions? initial;
  final ValueChanged<ProductUnitOptions> onChanged;
  final String priceSuffix;
  final double? Function() basePrice;

  const UnitOptionsEditor({
    super.key,
    required this.baseUnitCode,
    required this.initial,
    required this.onChanged,
    required this.basePrice,
    this.priceSuffix = '',
  });

  @override
  State<UnitOptionsEditor> createState() => _UnitOptionsEditorState();
}

class _UnitOptionsEditorState extends State<UnitOptionsEditor> {
  late bool _half;
  late bool _quarter;
  late bool _pieces;
  String? _pieceCode;
  late final TextEditingController _halfPrice;
  late final TextEditingController _count;
  late final TextEditingController _piecePrice;

  static String _fmt(double? v) =>
      v == null ? '' : MeasurementUnits.formatNumber(v).replaceAll(',', '.');

  @override
  void initState() {
    super.initState();
    final o = widget.initial;
    final fr = MeasurementUnits.fractionsOf(widget.baseUnitCode, o);
    _half = fr.contains(0.5);
    _quarter = fr.contains(0.25);
    _pieces = o?.hasPieces ?? false;
    _pieceCode = o?.pieceUnitCode;
    _halfPrice = TextEditingController(text: _fmt(o?.halfPriceInCdf));
    _count = TextEditingController(text: _fmt(o?.piecesPerUnit));
    _piecePrice = TextEditingController(text: _fmt(o?.piecePriceInCdf));
  }

  @override
  void dispose() {
    _halfPrice.dispose();
    _count.dispose();
    _piecePrice.dispose();
    super.dispose();
  }

  static double? _parse(String s) =>
      double.tryParse(s.trim().replaceAll(' ', '').replaceAll(',', '.'));

  void _emit() {
    final n = _parse(_count.text);
    widget.onChanged(ProductUnitOptions(
      fractions: [if (_half) 0.5, if (_half && _quarter) 0.25],
      halfPriceInCdf: _half ? _parse(_halfPrice.text) : null,
      pieceUnitCode: _pieces && (n ?? 0) > 0 ? _pieceCode : null,
      piecesPerUnit: _pieces && _pieceCode != null ? n : null,
      piecePriceInCdf: _pieces ? _parse(_piecePrice.text) : null,
    ));
  }

  String? _hint(double factor) {
    final p = widget.basePrice();
    if (p == null || p <= 0) return null;
    return 'Par défaut : ${MeasurementUnits.formatNumber(p * factor)} ${widget.priceSuffix}';
  }

  Widget _numberField(TextEditingController c, String label,
          {String? suffix, String? helper}) =>
      TextField(
        controller: c,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))],
        decoration: InputDecoration(
          labelText: label,
          suffixText: suffix,
          helperText: helper,
          isDense: true,
          border: const OutlineInputBorder(),
        ),
        onChanged: (_) => setState(_emit),
      );

  @override
  Widget build(BuildContext context) {
    final lang = unitLang(context);
    final base = MeasurementUnits.label(widget.baseUnitCode, lang).toLowerCase();
    final half = MeasurementUnits.halfLabel(widget.baseUnitCode, lang).toLowerCase();
    final n = _parse(_count.text);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SwitchListTile(
          dense: true,
          contentPadding: EdgeInsets.zero,
          title: Text('Se vend au demi ($half)'),
          subtitle: const Text('Le stock garde les demis : 2 cartons et demi'),
          value: _half,
          onChanged: (v) => setState(() {
            _half = v;
            _emit();
          }),
        ),
        if (_half) ...[
          _numberField(_halfPrice, 'Prix du $half (option)',
              suffix: widget.priceSuffix, helper: _hint(0.5)),
          CheckboxListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            controlAffinity: ListTileControlAffinity.leading,
            title: Text('Aussi au quart (1/4 $base)'),
            value: _quarter,
            onChanged: (v) => setState(() {
              _quarter = v ?? false;
              _emit();
            }),
          ),
        ],
        SwitchListTile(
          dense: true,
          contentPadding: EdgeInsets.zero,
          title: Text('Se vend aussi à la pièce'),
          subtitle: Text('1 $base contient N pièces (bouteilles, paquets...)'),
          value: _pieces,
          onChanged: (v) => setState(() {
            _pieces = v;
            _pieceCode ??= 'bottle';
            final s = MeasurementUnits.suggestedContains(
                widget.baseUnitCode, _pieceCode!);
            if (v && _count.text.isEmpty && s != null) _count.text = _fmt(s);
            _emit();
          }),
        ),
        if (_pieces) ...[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 3,
                child: _numberField(_count, 'Contient'),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 4,
                child: MeasurementUnitField(
                  label: 'Pièce',
                  value: _pieceCode,
                  only: [
                    for (final c in MeasurementUnits.sortedCodes())
                      if (c != widget.baseUnitCode) c,
                  ],
                  onChanged: (c) => setState(() {
                    _pieceCode = c;
                    final s = MeasurementUnits.suggestedContains(
                        widget.baseUnitCode, c);
                    if (s != null) _count.text = _fmt(s);
                    _emit();
                  }),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          _numberField(
            _piecePrice,
            'Prix à la pièce (option)',
            suffix: widget.priceSuffix,
            helper: n != null && n > 0 ? _hint(1 / n) : null,
          ),
        ],
      ],
    );
  }
}

/// Choix de l'unité d'une ligne (vente, achat, inventaire) : carton,
/// demi-carton, pièce. Rien d'affiché quand seule l'unité de référence existe.
class SellableUnitSelector extends StatelessWidget {
  final List<SellableUnit> units;
  final String selectedKey;
  final ValueChanged<SellableUnit> onChanged;

  const SellableUnitSelector({
    super.key,
    required this.units,
    required this.selectedKey,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    if (units.length < 2) return const SizedBox.shrink();
    return Wrap(
      spacing: 8,
      runSpacing: 4,
      children: [
        for (final u in units)
          ChoiceChip(
            label: Text(u.label),
            selected: u.key == selectedKey,
            onSelected: (_) => onChanged(u),
          ),
      ],
    );
  }
}
