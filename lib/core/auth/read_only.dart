import 'dart:convert';

import 'package:flutter/widgets.dart';

import '../enums/user_role.dart';
import 'user_rights.dart';

/// Code renvoyé par le serveur quand un lecteur tente une écriture.
const String readOnlyRoleCode = 'READ_ONLY_ROLE';

/// Message affiché pour ce refus.
const String readOnlyRoleMessage = 'Votre rôle permet la consultation seulement';

/// Lecteur (auditeur, analyste, RH, lecteur, rôles sans équivalent ici) :
/// règle UNIQUE de l'app pour masquer toute action d'écriture. Le serveur
/// refuse de toute façon l'écriture (403 READ_ONLY_ROLE) ; l'app ne propose
/// donc ni (+), ni action rapide d'écriture, ni formulaire de création.
///
/// Les widgets partagés (fabWithAdha, feuille d'actions rapides, menu 3
/// points, barre d'actions) et le routeur passent par ici, jamais par une
/// condition locale.
class ReadOnlyAccess {
  ReadOnlyAccess._();

  /// Remplace la lecture du rôle (tests).
  @visibleForTesting
  static bool Function()? debugOverride;

  /// L'utilisateur connecté est-il lecteur ? Faux tant que le rôle est inconnu
  /// (le serveur tranche alors).
  static bool get isReadOnly {
    final o = debugOverride;
    if (o != null) return o();
    return UserRights.role()?.isReadOnly ?? false;
  }

  /// Libellés d'écriture : création, vente, dépense, encaissement,
  /// annulation, rétablissement, modification, suppression...
  static final RegExp _writeLabel = RegExp(
    r'(nouve|ajout|cr[ée]er|cr[ée]ation|enregistr|vend|vente|d[ée]pens|encaiss|'
    r'annul|r[ée]tabl|modif|[ée]dit|supprim|archiv|valid|pay|paiement|transf[ée]r|'
    r'approvision|commande|r[ée]serv|ouvrir la caisse|cl[ôo]tur|inviter|affecter|'
    r'd[ée]poser|retirer|importer|ajuster|mouvement)',
    caseSensitive: false,
  );

  /// Une action portant ce libellé écrit-elle ? (lecture sinon : voir, fiche,
  /// PDF, imprimer, exporter, partager, historique, rapport...).
  static bool isWriteLabel(String label) => _writeLabel.hasMatch(label);

  /// L'action est-elle proposée à l'utilisateur ? [write] force la nature de
  /// l'action ; sans lui, elle se déduit du libellé.
  static bool allows({required String label, bool? write}) =>
      !isReadOnly || !(write ?? isWriteLabel(label));

  /// Segments de chemin des écrans de création et de modification.
  static final RegExp _writeRoute = RegExp(
    r'(^|/)(add|new|create|edit|form|checkout|sale|nouveau|nouvelle)(/|$|\?)',
  );

  /// Écran de création ou de modification ?
  static bool isWriteRoute(String location) => _writeRoute.hasMatch(location);

  /// Redirection du routeur : un lecteur n'ouvre aucun formulaire de création
  /// ou de modification ; il revient au tableau de bord (une page parente
  /// n'existe pas toujours comme route).
  static String? redirectFor(String location) {
    if (!isReadOnly || !isWriteRoute(location)) return null;
    return '/dashboard';
  }

  /// Le corps d'un refus serveur est-il celui du lecteur ?
  static bool isReadOnlyRefusal(Object? body) {
    if (body == null) return false;
    if (body is String) return body.contains(readOnlyRoleCode);
    try {
      return jsonEncode(body).contains(readOnlyRoleCode);
    } catch (_) {
      return false;
    }
  }
}

/// Affiche [child] seulement si l'utilisateur peut écrire ; [fallback] sinon
/// (rien par défaut).
class WriteGate extends StatelessWidget {
  const WriteGate({super.key, required this.child, this.fallback});

  final Widget child;
  final Widget? fallback;

  @override
  Widget build(BuildContext context) =>
      ReadOnlyAccess.isReadOnly ? (fallback ?? const SizedBox.shrink()) : child;
}
