import 'dart:convert';

import 'measurement_units_data.dart';

/// Unités de mesure Wanzo : même catalogue que le serveur
/// (packages/shared/src/standards/measurement-units.ts), copie identique dans
/// [kMeasurementUnitsSnapshot].
///
/// Le code réel d'une fiche est `Product.unitCode` ; l'enum historique
/// `ProductUnit` n'en est que la projection (`legacy`), seule valeur que
/// comprennent les apps déjà installées. Un code inconnu (unité ajoutée au
/// serveur après cette version) s'affiche tel quel, sans planter.
///
/// Le stock est toujours dans l'unité de référence de la fiche (le carton).
/// Un demi-carton n'est pas une unité à part : c'est 0,5 carton. Une
/// bouteille d'un carton de 24 est 1/24 de carton.
enum MeasurementUnitKind { count, packaging, weight, volume, length, area }

class MeasurementUnitDef {
  final String code;
  final MeasurementUnitKind kind;
  final Map<String, String> labels;
  final String? symbol;
  final String? pluralFr;
  final String legacy;
  final bool integer;
  final int rank;
  final String? siDim;
  final double? siFactor;
  final double? defaultContains;
  final String? measureDim;
  final double? measureAmount;
  final bool divisible;
  final Map<String, String>? halfLabels;

  const MeasurementUnitDef({
    required this.code,
    required this.kind,
    required this.labels,
    required this.legacy,
    required this.integer,
    required this.rank,
    this.symbol,
    this.pluralFr,
    this.siDim,
    this.siFactor,
    this.defaultContains,
    this.measureDim,
    this.measureAmount,
    this.divisible = false,
    this.halfLabels,
  });

  factory MeasurementUnitDef.fromJson(Map<String, dynamic> j) {
    final si = j['si'] as Map<String, dynamic>?;
    final measure = j['measure'] as Map<String, dynamic>?;
    final half = j['halfLabels'] as Map?;
    return MeasurementUnitDef(
      code: j['code'] as String,
      kind: MeasurementUnitKind.values.firstWhere(
        (k) => k.name == j['kind'],
        orElse: () => MeasurementUnitKind.count,
      ),
      labels: Map<String, String>.from(j['labels'] as Map),
      symbol: j['symbol'] as String?,
      pluralFr: j['pluralFr'] as String?,
      legacy: j['legacy'] as String,
      integer: j['integer'] == true,
      rank: (j['rank'] as num).toInt(),
      siDim: si?['dim'] as String?,
      siFactor: (si?['factor'] as num?)?.toDouble(),
      defaultContains: (j['defaultContains'] as num?)?.toDouble(),
      measureDim: measure?['dim'] as String?,
      measureAmount: (measure?['amount'] as num?)?.toDouble(),
      divisible: j['divisible'] == true,
      halfLabels: half == null ? null : Map<String, String>.from(half),
    );
  }

  bool get isPackaging => kind == MeasurementUnitKind.packaging;
  bool get isPhysical => siFactor != null;

  String label([String lang = 'fr']) => labels[lang] ?? labels['fr'] ?? code;
}

double? _num(dynamic v) {
  if (v == null) return null;
  if (v is num) return v.toDouble();
  return double.tryParse(v.toString().trim());
}

/// Options de l'unité d'une fiche : fractions admises (demi par défaut pour
/// une unité divisible, quart en option), prix du demi et du quart (défaut
/// au prorata, modifiables), pièce contenue (1 carton = 24 bouteilles) et
/// son prix.
class ProductUnitOptions {
  /// Null : défaut (demi si l'unité est divisible). [] : indivisible.
  final List<double>? fractions;
  final double? halfPriceInCdf;
  final double? quarterPriceInCdf;
  final String? pieceUnitCode;
  final double? piecesPerUnit;
  final double? piecePriceInCdf;

  const ProductUnitOptions({
    this.fractions,
    this.halfPriceInCdf,
    this.quarterPriceInCdf,
    this.pieceUnitCode,
    this.piecesPerUnit,
    this.piecePriceInCdf,
  });

  bool get hasPieces =>
      pieceUnitCode != null && (piecesPerUnit ?? 0) > 0;

  /// Lecture tolérante (objet ou chaîne JSON, nombres en chaîne).
  static ProductUnitOptions? fromJson(dynamic raw) {
    if (raw is String) {
      if (raw.trim().isEmpty) return null;
      try {
        raw = jsonDecode(raw);
      } catch (_) {
        return null;
      }
    }
    if (raw is! Map) return null;
    final f = raw['fractions'];
    final piece = MeasurementUnits.normalize(raw['pieceUnitCode']) ??
        (raw['pieceUnitCode']?.toString().trim().isEmpty ?? true
            ? null
            : raw['pieceUnitCode'].toString().trim());
    final n = _num(raw['piecesPerUnit']);
    return ProductUnitOptions(
      fractions: f is List
          ? [
              for (final x in MeasurementUnits.allowedFractions)
                if (f.map(_num).contains(x)) x,
            ]
          : null,
      halfPriceInCdf: _num(raw['halfPriceInCdf']),
      quarterPriceInCdf: _num(raw['quarterPriceInCdf']),
      pieceUnitCode: (n != null && n > 0) ? piece : null,
      piecesPerUnit: (piece != null && n != null && n > 0) ? n : null,
      piecePriceInCdf: _num(raw['piecePriceInCdf']),
    );
  }

  Map<String, dynamic> toJson() => {
        if (fractions != null) 'fractions': fractions,
        if (halfPriceInCdf != null) 'halfPriceInCdf': halfPriceInCdf,
        if (quarterPriceInCdf != null) 'quarterPriceInCdf': quarterPriceInCdf,
        if (hasPieces) 'pieceUnitCode': pieceUnitCode,
        if (hasPieces) 'piecesPerUnit': piecesPerUnit,
        if (hasPieces && piecePriceInCdf != null)
          'piecePriceInCdf': piecePriceInCdf,
      };

  String encode() => jsonEncode(toJson());

  @override
  bool operator ==(Object other) =>
      other is ProductUnitOptions && jsonEncode(other.toJson()) == jsonEncode(toJson());

  @override
  int get hashCode => jsonEncode(toJson()).hashCode;
}

/// Une unité proposée à la vente, à l'achat ou à l'inventaire d'un produit :
/// le carton (facteur 1), le demi-carton (le carton au facteur 0,5), le
/// quart, ou la pièce (bouteille, facteur 1/24).
class SellableUnit {
  final String code;
  final double factor;
  final String label;
  final double? sellingPriceInCdf;
  final double? costPriceInCdf;
  const SellableUnit(this.code, this.factor, this.label,
      {this.sellingPriceInCdf, this.costPriceInCdf});
  bool get isBase => factor == 1;
  bool get isFraction => factor == 0.5 || factor == 0.25;

  /// Clé unique (le demi-carton partage le code du carton).
  String get key => '$code@$factor';
}

class MeasurementUnits {
  MeasurementUnits._();

  static final List<MeasurementUnitDef> all = [
    for (final u in kMeasurementUnitsSnapshot['units'] as List)
      MeasurementUnitDef.fromJson(Map<String, dynamic>.from(u as Map)),
  ];

  static final Map<String, MeasurementUnitDef> _byCode = {
    for (final u in all) u.code: u,
  };

  static final Map<String, String> _aliases = Map<String, String>.from(
    kMeasurementUnitsSnapshot['aliases'] as Map,
  );

  /// Fractions admises : le demi, et le quart en option.
  static final List<double> allowedFractions = [
    for (final f in kMeasurementUnitsSnapshot['fractions'] as List)
      (f as num).toDouble(),
  ];

  /// Les 8 valeurs de l'enum historique (colonne products.unit).
  static const legacyCodes = [
    'piece', 'kg', 'g', 'l', 'ml', 'package', 'box', 'other' //
  ];

  /// Codes triés par usage : d'abord les plus employés dans la boutique,
  /// puis l'ordre du catalogue (pièce, unité, kg, carton...).
  static List<String> sortedCodes({Map<String, int> usage = const {}}) {
    final list = [...all]..sort((a, b) {
        final ua = usage[a.code] ?? 0;
        final ub = usage[b.code] ?? 0;
        if (ua != ub) return ub.compareTo(ua);
        return a.rank.compareTo(b.rank);
      });
    return [for (final u in list) u.code];
  }

  static MeasurementUnitDef? of(String? code) =>
      code == null ? null : _byCode[code];

  static bool isKnown(String? code) => code != null && _byCode.containsKey(code);

  /// « Kg », « pièce », « m² » -> kg, piece, m2. Inconnu : null.
  static String? normalize(dynamic raw) {
    if (raw == null) return null;
    final s = raw.toString().trim();
    if (s.isEmpty) return null;
    if (_byCode.containsKey(s)) return s;
    final lower = s.toLowerCase();
    if (_byCode.containsKey(lower)) return lower;
    return _aliases[lower];
  }

  /// Projection sur l'enum historique (piece par défaut).
  static String legacyOf(String? code) => of(code)?.legacy ?? 'piece';

  /// Libellé dans la langue de l'app ; code inconnu affiché tel quel.
  static String label(String? code, [String lang = 'fr']) {
    final def = of(code);
    return def?.label(lang) ?? (code ?? '');
  }

  /// Nom du demi : « Demi-carton », « Demi-pièce (3 yards) » pour un pagne.
  static String halfLabel(String? code, [String lang = 'fr']) {
    final def = of(code);
    final h = def?.halfLabels;
    if (h != null) return h[lang] ?? h['fr']!;
    return '1/2 ${label(code, lang).toLowerCase()}';
  }

  /// Symbole (kg, L) ou libellé : imprimé sur les tickets.
  static String shortLabel(String? code, [String lang = 'fr']) {
    final def = of(code);
    if (def == null) return code ?? '';
    return def.symbol ?? def.label(lang);
  }

  static String kindLabel(MeasurementUnitKind kind) {
    switch (kind) {
      case MeasurementUnitKind.count:
        return 'Comptage';
      case MeasurementUnitKind.packaging:
        return 'Emballage';
      case MeasurementUnitKind.weight:
        return 'Poids';
      case MeasurementUnitKind.volume:
        return 'Volume';
      case MeasurementUnitKind.length:
        return 'Longueur';
      case MeasurementUnitKind.area:
        return 'Surface';
    }
  }

  /// Quantités entières (comptage). Code inconnu : décimales permises.
  static bool isInteger(String? code) {
    final def = of(code);
    return (def?.integer ?? false) && !(def?.divisible ?? false);
  }

  static bool isDivisible(String? code) => of(code)?.divisible ?? false;

  /// Fractions effectives d'une fiche (demi par défaut si l'unité est divisible).
  static List<double> fractionsOf(String baseCode, ProductUnitOptions? o) {
    if (o?.fractions != null) {
      return [for (final f in allowedFractions) if (o!.fractions!.contains(f)) f];
    }
    return isDivisible(baseCode) ? const [0.5] : const [];
  }

  /// Nombre de pièces proposé : douzaine 12, plateau 30, sac de 50 kg 50
  /// (pièce kg), jerrican de 20 L 20 (pièce L), pagne 6 (pièce yard).
  static double? suggestedContains(String packagingCode, String pieceCode) {
    final pack = of(packagingCode);
    final piece = of(pieceCode);
    if (pack == null) return null;
    if (pack.measureAmount != null &&
        piece?.siFactor != null &&
        piece!.siDim == pack.measureDim) {
      return (pack.measureAmount! / piece.siFactor! * 1000).round() / 1000;
    }
    if (pack.defaultContains != null &&
        (piece == null ||
            piece.kind == MeasurementUnitKind.count ||
            piece.kind == MeasurementUnitKind.packaging)) {
      return pack.defaultContains;
    }
    return null;
  }

  /// 1 demi-carton = 0,5 ; 5 bouteilles de 24 = 0,208333. Facteur absent = 1.
  static double toBase(num quantity, double? factor) {
    final f = (factor != null && factor > 0) ? factor : 1.0;
    return (quantity * f * 1e6).round() / 1e6;
  }

  /// Prix d'une unité de ligne : demi, quart ou pièce (défaut au prorata).
  static double unitPriceFor(double basePrice, ProductUnitOptions? o, double factor) {
    if (factor == 0.5 && o?.halfPriceInCdf != null) return o!.halfPriceInCdf!;
    if (factor == 0.25 && o?.quarterPriceInCdf != null) return o!.quarterPriceInCdf!;
    if (factor < 0.25 && o?.piecePriceInCdf != null) return o!.piecePriceInCdf!;
    return (basePrice * factor * 100).round() / 100;
  }

  static String formatNumber(num n) {
    final r = (n * 1000).round() / 1000;
    if (r == r.roundToDouble()) return r.toInt().toString();
    return r.toString().replaceAll('.', ',');
  }

  /// Quantité imprimée : entière pour les unités de comptage.
  static String formatQuantity(num quantity, String? code) =>
      formatNumber(isInteger(code) ? quantity.round() : quantity);

  static String _word(String? code, num q) {
    final def = of(code);
    if (def == null) return code ?? '';
    if (def.symbol != null) return def.symbol!;
    final w = (q.abs() > 1 && def.pluralFr != null) ? def.pluralFr! : def.labels['fr']!;
    return w.isEmpty ? w : w[0].toLowerCase() + w.substring(1);
  }

  static const _fractionText = [
    [0.5, '1/2', 'et demi'],
    [0.25, '1/4', 'et quart'],
    [0.75, '3/4', 'et trois quarts'],
  ];

  /// « 1 carton », « 3 cartons », « 1/2 carton », « 2 cartons et demi », « 2,5 kg ».
  static String formatUnitQuantity(num quantity, String? code) {
    final def = of(code);
    if (def?.divisible ?? false) {
      final whole = (quantity + 1e-6).floor();
      final frac = quantity - whole;
      for (final t in _fractionText) {
        if ((frac - (t[0] as double)).abs() < 1e-4) {
          if (whole == 0) return '${t[1]} ${_word(code, 1)}';
          return '$whole ${_word(code, whole)} ${t[2]}';
        }
      }
    }
    final q = isInteger(code) ? quantity.round() : quantity;
    return '${formatNumber(q)} ${_word(code, q)}'.trim();
  }

  /// Stock lisible dans l'unité de référence : « 2 cartons et demi » ; reste
  /// qui n'est ni un demi ni un quart, en pièces si la fiche les définit :
  /// 3 cartons moins 5 bouteilles = « 2 cartons et 19 bouteilles ».
  static String formatStockBreakdown(num baseQuantity, String? baseCode,
      [ProductUnitOptions? options]) {
    final q = (baseQuantity * 1e6).round() / 1e6;
    final n = options?.piecesPerUnit ?? 0;
    if (q <= 0 || n <= 0 || options?.pieceUnitCode == null) {
      return formatUnitQuantity(q, baseCode);
    }
    var whole = (q + 1e-6).floor();
    final frac = q - whole;
    if (frac < 1e-4) return formatUnitQuantity(whole, baseCode);
    if (isDivisible(baseCode) &&
        _fractionText.any((t) => (frac - (t[0] as double)).abs() < 1e-4)) {
      return formatUnitQuantity(q, baseCode);
    }
    var pieces = (frac * n).round();
    if (pieces >= n) {
      whole += 1;
      pieces = 0;
    }
    if (pieces == 0) return formatUnitQuantity(whole, baseCode);
    final tail = formatUnitQuantity(pieces, options!.pieceUnitCode);
    return whole > 0 ? '${formatUnitQuantity(whole, baseCode)} et $tail' : tail;
  }

  /// Unités proposées pour vendre, acheter ou compter un produit : l'unité
  /// de référence, son demi (et son quart) si la fiche les admet, sa pièce.
  static List<SellableUnit> sellableUnits(
    String baseCode,
    ProductUnitOptions? options, {
    double? baseSellingPriceInCdf,
    double? baseCostPriceInCdf,
    String lang = 'fr',
  }) {
    SellableUnit unit(String code, double factor, String label) => SellableUnit(
          code,
          factor,
          label,
          sellingPriceInCdf: baseSellingPriceInCdf == null
              ? null
              : unitPriceFor(baseSellingPriceInCdf, options, factor),
          costPriceInCdf: baseCostPriceInCdf == null
              ? null
              : (baseCostPriceInCdf * factor * 100).round() / 100,
        );
    final fr = fractionsOf(baseCode, options);
    return [
      unit(baseCode, 1, label(baseCode, lang)),
      if (fr.contains(0.5)) unit(baseCode, 0.5, halfLabel(baseCode, lang)),
      if (fr.contains(0.25))
        unit(baseCode, 0.25, '1/4 ${label(baseCode, lang).toLowerCase()}'),
      if (options?.hasPieces ?? false)
        unit(options!.pieceUnitCode!, 1 / options.piecesPerUnit!,
            label(options.pieceUnitCode, lang)),
    ];
  }
}

/// Libellé affiché d'une unité stockée (code, ou ancienne graphie libre) :
/// « kg », « Sac de 50 kg », « m² ». Inconnue : affichée telle quelle.
String unitDisplay(String? raw) {
  if (raw == null || raw.trim().isEmpty) return '';
  final code = MeasurementUnits.normalize(raw);
  return code == null ? raw : MeasurementUnits.shortLabel(code);
}

/// Quantité imprimée d'une ligne de ticket ou de facture : « 1/2 carton »
/// (1 demi), « 1 carton et demi » (3 demis), « 5 bouteilles », « 2,5 kg »,
/// « 3 » (ligne sans unité, version plus ancienne).
String lineQuantityLabel(num quantity, String? unitCode, [double? unitFactor]) {
  if (unitCode == null || unitCode.isEmpty) {
    return MeasurementUnits.formatNumber(quantity);
  }
  final f = unitFactor ?? 1;
  if (MeasurementUnits.isDivisible(unitCode) && f > 0 && f < 1) {
    return MeasurementUnits.formatUnitQuantity(
        MeasurementUnits.toBase(quantity, f), unitCode);
  }
  return MeasurementUnits.formatUnitQuantity(quantity, unitCode);
}
