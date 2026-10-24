import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

import '../models/product.dart';
import '../models/stock_transaction.dart';
import '../repositories/inventory_repository.dart';

/// Inventaire physique (comptage) : brouillon tenu sur l'appareil, validé
/// en AJUSTEMENTS SIGNÉS par la voie unique `stock-transactions` (un
/// mouvement par article en écart, référence commune `INV-...`).

/// Brouillon de comptage, repris tel quel après fermeture de l'app.
@immutable
class StockCountDraft {
  final String reference;
  final DateTime startedAt;

  /// Quantités comptées par article (absent = pas encore compté).
  final Map<String, double> counts;

  const StockCountDraft({
    required this.reference,
    required this.startedAt,
    this.counts = const {},
  });

  factory StockCountDraft.start([DateTime? now]) {
    final t = now ?? DateTime.now();
    return StockCountDraft(
      reference: 'INV-${DateFormat('yyyyMMdd-HHmm').format(t)}',
      startedAt: t,
    );
  }

  StockCountDraft withCount(String productId, double? qty) {
    final next = Map<String, double>.from(counts);
    if (qty == null) {
      next.remove(productId);
    } else {
      next[productId] = qty;
    }
    return StockCountDraft(reference: reference, startedAt: startedAt, counts: next);
  }

  /// +1 sur l'article (lecture d'un code-barres : un article lu = un compté).
  StockCountDraft increment(String productId, [double by = 1]) =>
      withCount(productId, (counts[productId] ?? 0) + by);

  Map<String, dynamic> toJson() => {
    'reference': reference,
    'startedAt': startedAt.toIso8601String(),
    'counts': counts,
  };

  factory StockCountDraft.fromJson(Map<String, dynamic> j) => StockCountDraft(
    reference: j['reference'] as String,
    startedAt: DateTime.parse(j['startedAt'] as String),
    counts: (j['counts'] as Map? ?? const {}).map(
      (k, v) => MapEntry(k.toString(), (v as num).toDouble()),
    ),
  );
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
/// moment de la validation).
List<StockCountGap> stockCountGaps(Iterable<Product> products, StockCountDraft draft) {
  final out = <StockCountGap>[];
  for (final p in products) {
    final counted = draft.counts[p.id];
    if (counted == null) continue;
    final gap = StockCountGap(p, p.stockQuantity, counted);
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
        'Inventaire du $date (${draft.reference}) : compté ${_fmt(gap.counted)}, théorique ${_fmt(gap.theoretical)}',
    unitCostInCdf: gap.product.costPriceInCdf,
    totalValueInCdf: gap.valueInCdf,
    currencyCode: 'CDF',
    businessUnitId: gap.product.businessUnitId,
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
