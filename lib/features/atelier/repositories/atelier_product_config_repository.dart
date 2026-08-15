import 'package:hive/hive.dart';

/// Type d'article en mode ATELIER de confection.
///
/// Distingue, parmi les produits du catalogue, les INTRANTS de production
/// (tissus, fournitures consommés lors de la fabrication) des PRODUITS FINIS
/// (articles confectionnés). Un produit absent de cette table est une
/// marchandise ordinaire (comportement historique boutique).
enum AtelierProductType {
  /// Intrant de production (matière première, fourniture).
  intrant,

  /// Produit fini (article confectionné).
  produitFini,
}

extension AtelierProductTypeX on AtelierProductType {
  /// Valeur stable persistée (clé du mapping local).
  String get apiValue {
    switch (this) {
      case AtelierProductType.intrant:
        return 'intrant';
      case AtelierProductType.produitFini:
        return 'produit_fini';
    }
  }

  /// Libellé affiché.
  String get label {
    switch (this) {
      case AtelierProductType.intrant:
        return 'Intrant de production';
      case AtelierProductType.produitFini:
        return 'Produit fini';
    }
  }

  /// Résout un type depuis sa valeur stockée. Renvoie `null` (marchandise
  /// ordinaire) pour une valeur absente ou inconnue.
  static AtelierProductType? fromValue(String? value) {
    switch (value) {
      case 'intrant':
        return AtelierProductType.intrant;
      case 'produit_fini':
        return AtelierProductType.produitFini;
      default:
        return null;
    }
  }
}

/// Configuration locale du TYPE d'article en mode atelier : quels produits sont
/// des intrants de production ou des produits finis.
///
/// Choix délibéré (calqué sur `MenuConfigRepository`) : box Hive `String`
/// (clé = productId, valeur = type), PAS de `TypeAdapter` ni de modification de
/// l'entité `Product` → aucun `typeId`, aucune migration, aucun impact backend.
/// Un produit absent de cette table est une marchandise ordinaire.
class AtelierProductConfigRepository {
  static const _boxName = 'atelier_product_config';
  Box<String>? _box;

  Future<Box<String>> _openBox() async {
    if (_box != null && _box!.isOpen) return _box!;
    _box = Hive.isBoxOpen(_boxName)
        ? Hive.box<String>(_boxName)
        : await Hive.openBox<String>(_boxName);
    return _box!;
  }

  /// Type configuré pour un produit (`null` = marchandise ordinaire).
  Future<AtelierProductType?> getType(String productId) async {
    final box = await _openBox();
    return AtelierProductTypeX.fromValue(box.get(productId));
  }

  /// Affecte un type d'atelier à un produit.
  Future<void> setType(String productId, AtelierProductType type) async {
    final box = await _openBox();
    await box.put(productId, type.apiValue);
  }

  /// Retire le type d'un produit (redevient marchandise ordinaire).
  Future<void> clear(String productId) async {
    final box = await _openBox();
    await box.delete(productId);
  }

  /// Map productId → type, pour tous les produits configurés.
  Future<Map<String, AtelierProductType>> getAll() async {
    final box = await _openBox();
    final result = <String, AtelierProductType>{};
    for (final key in box.keys) {
      final type = AtelierProductTypeX.fromValue(box.get(key));
      if (key is String && type != null) {
        result[key] = type;
      }
    }
    return result;
  }
}
