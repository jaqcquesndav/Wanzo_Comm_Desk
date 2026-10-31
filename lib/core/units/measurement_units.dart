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
  final String? halfOf;

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
    this.halfOf,
  });

  factory MeasurementUnitDef.fromJson(Map<String, dynamic> j) {
    final si = j['si'] as Map<String, dynamic>?;
    final measure = j['measure'] as Map<String, dynamic>?;
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
      halfOf: j['halfOf'] as String?,
    );
  }

  bool get isPackaging => kind == MeasurementUnitKind.packaging;
  bool get isPhysical => siFactor != null;

  String label([String lang = 'fr']) => labels[lang] ?? labels['fr'] ?? code;
}

/// Conditionnement d'un produit : 1 carton = 24 unités de base.
class ProductPackaging {
  final String unitCode;
  final double contains;
  final double? sellingPriceInCdf;
  final double? costPriceInCdf;
  final String? barcode;

  const ProductPackaging({
    required this.unitCode,
    required this.contains,
    this.sellingPriceInCdf,
    this.costPriceInCdf,
    this.barcode,
  });

  static double? _num(dynamic v) {
    if (v == null) return null;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString().trim());
  }

  /// Lecture tolérante : contenu en chaîne (numeric Postgres), entrée invalide ignorée.
  static ProductPackaging? tryFromJson(dynamic raw) {
    if (raw is! Map) return null;
    final code = MeasurementUnits.normalize(raw['unitCode']) ??
        raw['unitCode']?.toString().trim();
    final contains = _num(raw['contains']);
    if (code == null || code.isEmpty || contains == null || contains <= 0) {
      return null;
    }
    return ProductPackaging(
      unitCode: code,
      contains: contains,
      sellingPriceInCdf: _num(raw['sellingPriceInCdf']),
      costPriceInCdf: _num(raw['costPriceInCdf']),
      barcode: (raw['barcode']?.toString().isNotEmpty ?? false)
          ? raw['barcode'].toString()
          : null,
    );
  }

  static List<ProductPackaging> listFromJson(dynamic raw) {
    if (raw is String) {
      if (raw.trim().isEmpty) return const [];
      try {
        raw = jsonDecode(raw);
      } catch (_) {
        return const [];
      }
    }
    if (raw is! List) return const [];
    return [
      for (final e in raw)
        if (tryFromJson(e) case final p?) p,
    ];
  }

  static String? encodeList(List<ProductPackaging> list) =>
      list.isEmpty ? null : jsonEncode([for (final p in list) p.toJson()]);

  Map<String, dynamic> toJson() => {
        'unitCode': unitCode,
        'contains': contains,
        if (sellingPriceInCdf != null) 'sellingPriceInCdf': sellingPriceInCdf,
        if (costPriceInCdf != null) 'costPriceInCdf': costPriceInCdf,
        if (barcode != null) 'barcode': barcode,
      };

  ProductPackaging copyWith({
    String? unitCode,
    double? contains,
    double? sellingPriceInCdf,
    double? costPriceInCdf,
  }) =>
      ProductPackaging(
        unitCode: unitCode ?? this.unitCode,
        contains: contains ?? this.contains,
        sellingPriceInCdf: sellingPriceInCdf ?? this.sellingPriceInCdf,
        costPriceInCdf: costPriceInCdf ?? this.costPriceInCdf,
        barcode: barcode,
      );

  @override
  bool operator ==(Object other) =>
      other is ProductPackaging &&
      other.unitCode == unitCode &&
      other.contains == contains &&
      other.sellingPriceInCdf == sellingPriceInCdf &&
      other.costPriceInCdf == costPriceInCdf &&
      other.barcode == barcode;

  @override
  int get hashCode =>
      Object.hash(unitCode, contains, sellingPriceInCdf, costPriceInCdf, barcode);
}

/// Une unité proposée à la vente ou à l'achat d'un produit : la base (1) ou
/// un conditionnement (24 pour un carton).
class SellableUnit {
  final String code;
  final double factor;
  final double? sellingPriceInCdf;
  final double? costPriceInCdf;
  const SellableUnit(this.code, this.factor,
      {this.sellingPriceInCdf, this.costPriceInCdf});
  bool get isBase => factor == 1;
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

  /// Quantités entières (comptage, emballages). Code inconnu : décimales permises.
  static bool isInteger(String? code) => of(code)?.integer ?? false;

  /// Contenu proposé pour un emballage, en unités de base : douzaine 12,
  /// sac de 50 kg 50 (base kg), jerrican de 20 L 20 (base L), demi-carton =
  /// moitié du carton déjà saisi.
  static double? suggestedContains(
    String packagingCode,
    String baseCode, {
    Map<String, double> known = const {},
  }) {
    final pack = of(packagingCode);
    final base = of(baseCode);
    if (pack == null) return null;
    final parent = pack.halfOf == null ? null : known[pack.halfOf];
    if (parent != null && parent > 0) return parent / 2;
    if (pack.measureAmount != null &&
        base?.siFactor != null &&
        base!.siDim == pack.measureDim) {
      return (pack.measureAmount! / base.siFactor! * 1000).round() / 1000;
    }
    if (pack.defaultContains != null &&
        (base == null ||
            base.kind == MeasurementUnitKind.count ||
            base.kind == MeasurementUnitKind.packaging)) {
      return pack.defaultContains;
    }
    return null;
  }

  /// 2 cartons de 24 = 48. Facteur absent ou invalide = 1.
  static double toBase(num quantity, double? factor) {
    final f = (factor != null && factor > 0) ? factor : 1.0;
    return (quantity * f * 1000).round() / 1000;
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

  /// « 1 carton », « 3 cartons », « 2,5 kg ».
  static String formatUnitQuantity(num quantity, String? code) {
    final q = isInteger(code) ? quantity.round() : quantity;
    return '${formatNumber(q)} ${_word(code, q)}'.trim();
  }

  /// 77 bouteilles, carton de 24 : « 3 cartons et 5 bouteilles ».
  static String formatStockBreakdown(
    num baseQuantity,
    String? baseCode, [
    List<ProductPackaging> packagings = const [],
  ]) {
    final packs = packagings.where((p) => p.contains > 1).toList()
      ..sort((a, b) => b.contains.compareTo(a.contains));
    if (packs.isEmpty || baseQuantity <= 0) {
      return formatUnitQuantity(baseQuantity, baseCode);
    }
    final biggest = packs.first;
    final full = (baseQuantity / biggest.contains + 1e-9).floor();
    if (full <= 0) return formatUnitQuantity(baseQuantity, baseCode);
    final rest =
        ((baseQuantity - full * biggest.contains) * 1000).round() / 1000;
    final head = formatUnitQuantity(full, biggest.unitCode);
    return rest > 0 ? '$head et ${formatUnitQuantity(rest, baseCode)}' : head;
  }

  /// Unités proposées pour vendre ou acheter un produit : la base puis ses
  /// conditionnements, du plus petit au plus grand.
  static List<SellableUnit> sellableUnits(
    String baseCode,
    List<ProductPackaging> packagings, {
    double? baseSellingPriceInCdf,
    double? baseCostPriceInCdf,
  }) {
    final packs = [...packagings]..sort((a, b) => a.contains.compareTo(b.contains));
    return [
      SellableUnit(baseCode, 1,
          sellingPriceInCdf: baseSellingPriceInCdf,
          costPriceInCdf: baseCostPriceInCdf),
      for (final p in packs)
        if (p.unitCode != baseCode)
          SellableUnit(
            p.unitCode,
            p.contains,
            sellingPriceInCdf: p.sellingPriceInCdf ??
                (baseSellingPriceInCdf == null
                    ? null
                    : baseSellingPriceInCdf * p.contains),
            costPriceInCdf: p.costPriceInCdf ??
                (baseCostPriceInCdf == null ? null : baseCostPriceInCdf * p.contains),
          ),
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

/// Quantité imprimée d'une ligne de ticket ou de facture : « 2 cartons »,
/// « 2,5 kg », « 3 » (ligne sans unité, version plus ancienne). Entière pour
/// les unités de comptage.
String lineQuantityLabel(num quantity, String? unitCode) =>
    (unitCode == null || unitCode.isEmpty)
        ? MeasurementUnits.formatNumber(quantity)
        : MeasurementUnits.formatUnitQuantity(quantity, unitCode);
