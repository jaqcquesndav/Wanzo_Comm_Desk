/// Catégories de carte (menu) d'un établissement de restauration.
///
/// Sert à distinguer, parmi les produits du catalogue, ceux qui font partie de
/// la CARTE (plats servis) — et à les regrouper lors de la prise de commande —
/// du stock ordinaire (ingrédients, consommables) qui n'apparaît PAS au menu.
///
/// La catégorie d'un plat est portée par l'entité [MenuItem] de la carte
/// (stockée localement, cf. `MenuRepository`) : aucune modification de l'entité
/// `Product` ni du backend au-delà du module restaurant.
enum MenuCourse {
  entree,
  plat,
  accompagnement,
  dessert,
  boisson,
  autre,
}

extension MenuCourseX on MenuCourse {
  String get apiValue => name;

  /// Libellé affiché.
  String get label {
    switch (this) {
      case MenuCourse.entree:
        return 'Entrées';
      case MenuCourse.plat:
        return 'Plats';
      case MenuCourse.accompagnement:
        return 'Accompagnements';
      case MenuCourse.dessert:
        return 'Desserts';
      case MenuCourse.boisson:
        return 'Boissons';
      case MenuCourse.autre:
        return 'Autres';
    }
  }

  /// Ordre d'affichage dans la carte (entrée → plat → … → boisson).
  int get order {
    switch (this) {
      case MenuCourse.entree:
        return 0;
      case MenuCourse.plat:
        return 1;
      case MenuCourse.accompagnement:
        return 2;
      case MenuCourse.dessert:
        return 3;
      case MenuCourse.boisson:
        return 4;
      case MenuCourse.autre:
        return 5;
    }
  }

  /// Résout une catégorie depuis sa valeur stockée (repli : `autre`).
  static MenuCourse fromValue(String? value) {
    return MenuCourse.values.firstWhere(
      (c) => c.name == value,
      orElse: () => MenuCourse.autre,
    );
  }
}
