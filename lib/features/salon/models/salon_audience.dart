import 'salon_service.dart';

/// PUBLIC visé par une prestation : homme, femme, enfant, ou tous.
///
/// Le public et la TECHNIQUE sont deux questions différentes : une coupe peut
/// être homme ou femme, et une couleur s'adresse le plus souvent aux femmes
/// sans cesser d'être une couleur. Elles vivaient pourtant dans la même
/// énumération de catégories, ce qui obligeait à choisir l'une OU l'autre :
/// « Coupe femme » était classée en « Femme » chez l'un, en « Coupe » chez
/// l'autre, et on ne pouvait lister ni toutes les coupes ni toutes les
/// prestations femme.
///
/// Le public a son propre champ, déjà porté par le serveur (`targetGender`).
enum SalonAudience {
  tous,
  homme,
  femme,
  enfant;

  /// Valeur persistée. `unisex` côté serveur = s'adresse à tous.
  String get apiValue => this == SalonAudience.tous ? 'unisex' : name;

  String get label {
    switch (this) {
      case SalonAudience.tous:
        return 'Tous publics';
      case SalonAudience.homme:
        return 'Homme';
      case SalonAudience.femme:
        return 'Femme';
      case SalonAudience.enfant:
        return 'Enfant';
    }
  }

  /// Libellé court, pour une puce dans une liste dense.
  String get shortLabel => this == SalonAudience.tous ? 'Tous' : label;

  static SalonAudience fromValue(String? value) {
    switch (value) {
      case 'homme':
        return SalonAudience.homme;
      case 'femme':
        return SalonAudience.femme;
      case 'enfant':
        return SalonAudience.enfant;
      default:
        return SalonAudience.tous;
    }
  }

  /// Public d'une prestation, en rattrapant les fiches anciennes : avant que le
  /// public ait son champ, il était rangé dans la catégorie. Une prestation
  /// classée « Femme » s'adresse donc aux femmes, même sans `targetGender`.
  static SalonAudience of(SalonService service) {
    if ((service.targetGender ?? '').isNotEmpty) {
      return fromValue(service.targetGender);
    }
    switch (service.category) {
      case SalonServiceCategory.homme:
        return SalonAudience.homme;
      case SalonServiceCategory.femme:
        return SalonAudience.femme;
      case SalonServiceCategory.enfant:
        return SalonAudience.enfant;
      default:
        return SalonAudience.tous;
    }
  }
}

/// Les catégories qui décrivent un GESTE TECHNIQUE, seules proposées à la
/// création. Les trois anciennes valeurs de public restent dans l'énumération
/// pour lire les fiches déjà saisies, mais on ne les propose plus : leur rôle
/// est repris par [SalonAudience].
const List<SalonServiceCategory> kSalonTechniqueCategories = [
  SalonServiceCategory.coupe,
  SalonServiceCategory.couleur,
  SalonServiceCategory.coiffage,
  SalonServiceCategory.tresses,
  SalonServiceCategory.defrisage,
  SalonServiceCategory.soins,
  SalonServiceCategory.manucure,
  SalonServiceCategory.pedicure,
  SalonServiceCategory.autre,
];

/// La technique d'une prestation, en repliant les anciennes catégories de
/// public sur « Autres » : une fiche classée « Femme » ne dit pas quel geste
/// est réalisé, et prétendre le contraire tromperait le regroupement.
SalonServiceCategory salonTechniqueOf(SalonService service) {
  switch (service.category) {
    case SalonServiceCategory.homme:
    case SalonServiceCategory.femme:
    case SalonServiceCategory.enfant:
      return SalonServiceCategory.autre;
    default:
      return service.category;
  }
}
