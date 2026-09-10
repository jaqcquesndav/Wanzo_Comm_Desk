import 'package:flutter/material.dart';

import 'package:wanzo/core/widgets/dish_thumb_grid.dart';

import '../models/menu_item.dart';
import '../models/restaurant_order.dart';
import '../repositories/menu_repository.dart';

/// Aperçu photo du CONTENU d'une commande : résout chaque `productId` de ligne
/// vers son plat de la CARTE ([MenuItem], via [MenuRepository]) puis affiche une
/// miniature ou une grille de photos ([DishThumbGrid]).
///
/// BUG historique corrigé : la résolution passait par l'`InventoryRepository`
/// (le stock), alors que `RestaurantOrderLine.productId` est l'id d'un
/// [MenuItem] (la carte) — d'où l'icône de repli systématique. On résout donc
/// bien via la carte.
///
/// [menuById] est le catalogue déjà chargé (passé par l'écran parent pour éviter
/// une lecture Hive par carte). S'il est `null`, le widget charge la carte
/// localement (lecture locale, sûre hors-ligne).
class OrderDishThumbs extends StatelessWidget {
  final RestaurantOrder order;
  final Map<String, MenuItem>? menuById;
  final double size;
  final double radius;
  final int maxTiles;

  const OrderDishThumbs({
    super.key,
    required this.order,
    this.menuById,
    this.size = 48,
    this.radius = 10,
    this.maxTiles = 4,
  });

  /// Miniatures des plats DISTINCTS de la commande (dédoublonnés par plat),
  /// dans l'ordre de la commande.
  List<DishThumb> _thumbs(Map<String, MenuItem> menu) {
    final seen = <String>{};
    final out = <DishThumb>[];
    for (final l in order.lines) {
      if (!seen.add(l.productId)) continue;
      final item = menu[l.productId];
      if (item == null) continue;
      out.add(DishThumb(photoUrl: item.photoUrl, photoPath: item.photoPath));
    }
    return out;
  }

  Widget _grid(Map<String, MenuItem> menu) => DishThumbGrid(
        thumbs: _thumbs(menu),
        size: size,
        radius: radius,
        maxTiles: maxTiles,
      );

  @override
  Widget build(BuildContext context) {
    final map = menuById;
    if (map != null) return _grid(map);
    return FutureBuilder<Map<String, MenuItem>>(
      future: MenuRepository().loadMap(),
      builder: (context, snap) => _grid(snap.data ?? const {}),
    );
  }
}
