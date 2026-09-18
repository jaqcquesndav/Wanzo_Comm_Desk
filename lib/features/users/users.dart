// filepath: lib/features/users/users.dart
/// Module de gestion des utilisateurs
///
/// Ne reste que le modele `AppUser`, dont les adaptateurs Hive (typeIds 75-77)
/// sont enregistres au demarrage. Le bloc de gestion des utilisateurs qui
/// vivait ici n'etait construit nulle part ; il a ete retire. Changer d'unite
/// d'affaires se fait via `JoinBusinessUnitDialog`.

library;

export 'models/app_user.dart';
