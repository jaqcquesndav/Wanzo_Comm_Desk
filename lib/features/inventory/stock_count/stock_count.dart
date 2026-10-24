import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

import '../../../core/services/api_client.dart';
import '../models/product.dart';
import '../models/stock_transaction.dart';
import '../repositories/inventory_repository.dart';

/// Inventaire physique (comptage) : brouillon tenu sur l'appareil, validé
/// en AJUSTEMENTS SIGNÉS par la voie unique `stock-transactions` (un
/// mouvement par article en écart, référence commune `INV-...`).

/// Brouillon de comptage, repris tel quel après fermeture de l'app.
///
/// Inventaire par emplacement (facultatif) : avec [locationId], le théorique
/// de chaque article est son stock DANS cet emplacement ([locationStock],
/// dernière valeur connue du serveur, gardée pour compter hors ligne) et les
/// ajustements portent ce `locationId`. Sans emplacement (« Tous »), le
/// théorique est le stock de l'article, comme avant.
@immutable
class StockCountDraft {
  final String reference;
  final DateTime startedAt;

  /// Quantités comptées par article (absent = pas encore compté).
  final Map<String, double> counts;

  /// Emplacement compté (unité d'affaires), null = tous.
  final String? locationId;
  final String? locationName;

  /// Stock par article dans l'emplacement (absent = 0).
  final Map<String, double> locationStock;

  const StockCountDraft({
    required this.reference,
    required this.startedAt,
    this.counts = const {},
    this.locationId,
    this.locationName,
    this.locationStock = const {},
  });

  factory StockCountDraft.start([DateTime? now]) {
    final t = now ?? DateTime.now();
    return StockCountDraft(
      reference: 'INV-${DateFormat('yyyyMMdd-HHmm').format(t)}',
      startedAt: t,
    );
  }

  /// Nouveau comptage limité à un emplacement (null = tous).
  StockCountDraft forLocation(String? id, String? name, Map<String, double> stock) => StockCountDraft(
    reference: reference,
    startedAt: startedAt,
    locationId: id,
    locationName: id == null ? null : name,
    locationStock: id == null ? const {} : Map.unmodifiable(stock),
  );

  /// Stock de l'emplacement rafraîchi (mêmes comptages).
  StockCountDraft withLocationStock(Map<String, double> stock) => StockCountDraft(
    reference: reference,
    startedAt: startedAt,
    counts: counts,
    locationId: locationId,
    locationName: locationName,
    locationStock: Map.unmodifiable(stock),
  );

  /// Théorique d'un article pour ce comptage.
  double theoreticalOf(Product p) => locationId == null ? p.stockQuantity : (locationStock[p.id] ?? 0);

  StockCountDraft withCount(String productId, double? qty) {
    final next = Map<String, double>.from(counts);
    if (qty == null) {
      next.remove(productId);
    } else {
      next[productId] = qty;
    }
    return StockCountDraft(
      reference: reference,
      startedAt: startedAt,
      counts: next,
      locationId: locationId,
      locationName: locationName,
      locationStock: locationStock,
    );
  }

  /// Ne garde que les comptages de [ids] (articles refusés à la validation).
  StockCountDraft onlyCounts(Iterable<String> ids) => StockCountDraft(
    reference: reference,
    startedAt: startedAt,
    counts: {for (final id in ids) if (counts[id] != null) id: counts[id]!},
    locationId: locationId,
    locationName: locationName,
    locationStock: locationStock,
  );

  /// +1 sur l'article (lecture d'un code-barres : un article lu = un compté).
  StockCountDraft increment(String productId, [double by = 1]) =>
      withCount(productId, (counts[productId] ?? 0) + by);

  Map<String, dynamic> toJson() => {
    'reference': reference,
    'startedAt': startedAt.toIso8601String(),
    'counts': counts,
    if (locationId != null) 'locationId': locationId,
    if (locationName != null) 'locationName': locationName,
    if (locationId != null) 'locationStock': locationStock,
  };

  factory StockCountDraft.fromJson(Map<String, dynamic> j) => StockCountDraft(
    reference: j['reference'] as String,
    startedAt: DateTime.parse(j['startedAt'] as String),
    counts: _qtyMap(j['counts']),
    locationId: j['locationId'] as String?,
    locationName: j['locationName'] as String?,
    locationStock: _qtyMap(j['locationStock']),
  );
}

Map<String, double> _qtyMap(dynamic raw) =>
    (raw as Map? ?? const {}).map((k, v) => MapEntry(k.toString(), (v as num).toDouble()));

/// Réponse de `stock-transactions/location-stock/:id` (enveloppée ou non) en
/// stock par article.
Map<String, double> parseLocationStock(dynamic response) {
  dynamic body = response;
  while (body is Map && body['items'] == null && body['data'] != null) {
    body = body['data'];
  }
  final items = body is Map ? body['items'] : null;
  if (items is! List) return const {};
  return {
    for (final it in items)
      if (it is Map && it['productId'] != null)
        it['productId'].toString(): (it['quantity'] is num)
            ? (it['quantity'] as num).toDouble()
            : double.tryParse('${it['quantity']}') ?? 0,
  };
}

/// Écart d'un article : compté - théorique.
@immutable
class StockCountGap {
  final Product product;
  final double theoretical;
  final double counted;

  const StockCountGap(this.product, this.theoretical, this.counted);

  double get difference => _round(counted - theoretical);
  double get valueInCdf => difference * product.costPriceInCdf;
}

double _round(double v) => (v * 1000).roundToDouble() / 1000;

/// Écarts non nuls des articles comptés (le théorique est le stock connu au
/// moment de la validation : celui de l'article, ou de l'emplacement compté).
List<StockCountGap> stockCountGaps(Iterable<Product> products, StockCountDraft draft) {
  final out = <StockCountGap>[];
  for (final p in products) {
    final counted = draft.counts[p.id];
    if (counted == null) continue;
    final gap = StockCountGap(p, draft.theoreticalOf(p), counted);
    if (gap.difference != 0) out.add(gap);
  }
  return out;
}

/// Article lu par code-barres ou SKU (sans tenir compte de la casse).
Product? findProductByCode(Iterable<Product> products, String code) {
  final c = code.trim().toLowerCase();
  if (c.isEmpty) return null;
  for (final p in products) {
    if (p.barcode.trim().toLowerCase() == c) return p;
  }
  for (final p in products) {
    if ((p.sku ?? '').trim().toLowerCase() == c) return p;
  }
  return null;
}

/// Mouvement d'ajustement signé d'un écart d'inventaire.
StockTransaction adjustmentForGap(StockCountGap gap, StockCountDraft draft, {String? id}) {
  final date = DateFormat('dd/MM/yyyy').format(draft.startedAt);
  return StockTransaction(
    id: id ?? const Uuid().v4(),
    productId: gap.product.id,
    type: StockTransactionType.adjustment,
    quantity: gap.difference,
    date: DateTime.now(),
    referenceId: draft.reference,
    notes:
        'Inventaire du $date (${draft.reference})'
        '${draft.locationName != null ? ', ${draft.locationName}' : ''}'
        ' : compté ${_fmt(gap.counted)}, théorique ${_fmt(gap.theoretical)}',
    unitCostInCdf: gap.product.costPriceInCdf,
    totalValueInCdf: gap.valueInCdf,
    currencyCode: 'CDF',
    businessUnitId: gap.product.businessUnitId,
    // Inventaire d'un emplacement : l'ajustement porte sur son stock.
    locationId: draft.locationId,
  );
}

String _fmt(double v) => v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toString();

/// Résultat d'une validation : ajustements passés et refus par article.
class StockCountResult {
  final int applied;
  final Map<String, String> refused;
  const StockCountResult(this.applied, this.refused);
}

/// Stockage du brouillon (une seule session de comptage à la fois).
class StockCountService {
  StockCountService({Future<Box<String>> Function()? box}) : _boxFn = box;
  static const _boxName = 'stock_count_draft';
  static const _key = 'current';
  final Future<Box<String>> Function()? _boxFn;

  Future<Box<String>> _box() =>
      _boxFn?.call() ??
      (Hive.isBoxOpen(_boxName) ? Future.value(Hive.box<String>(_boxName)) : Hive.openBox<String>(_boxName));

  Future<StockCountDraft?> load() async {
    try {
      final raw = (await _box()).get(_key);
      if (raw == null) return null;
      return StockCountDraft.fromJson(Map<String, dynamic>.from(jsonDecode(raw) as Map));
    } catch (e) {
      debugPrint('⚠️ Inventaire : brouillon illisible ($e)');
      return null;
    }
  }

  Future<void> save(StockCountDraft draft) async => (await _box()).put(_key, jsonEncode(draft.toJson()));

  Future<void> clear() async => (await _box()).delete(_key);

  /// Stock de chaque article dans un emplacement (connexion requise ; le
  /// brouillon garde la dernière valeur pour compter hors ligne).
  static Future<Map<String, double>> fetchLocationStock(String locationId) async => parseLocationStock(
    await ApiClient().get('stock-transactions/location-stock/$locationId', requiresAuth: true),
  );

  /// Passe un ajustement par écart, article par article. Un refus du serveur
  /// (stock, droits) n'arrête pas les autres ; l'article refusé reste dans
  /// le brouillon pour être corrigé. Hors ligne, les mouvements partent par
  /// la file d'écritures.
  static Future<StockCountResult> apply(
    InventoryRepository repository,
    StockCountDraft draft,
    List<StockCountGap> gaps,
  ) async {
    var applied = 0;
    final refused = <String, String>{};
    for (final gap in gaps) {
      try {
        await repository.addStockTransaction(adjustmentForGap(gap, draft));
        applied++;
      } on StockRefusedException catch (e) {
        refused[gap.product.id] = e.message;
      } catch (e) {
        refused[gap.product.id] = '$e'.replaceFirst('Exception: ', '');
      }
    }
    return StockCountResult(applied, refused);
  }
}
