import 'package:flutter/foundation.dart';

/// Compte fermé : signal immédiat, quelle que soit la requête refusée.
///
/// Le portail refuse toute requête d'un client suspendu avec un 403 portant le
/// code `ACCOUNT_SUSPENDED`. C'est le signal le plus sûr et le plus précoce
/// dont l'application dispose : il arrive dès le premier appel, sans attendre
/// le sondage de l'abonnement.
///
/// Sans lui, un client suspendu voyait l'application se charger normalement
/// puis rester vide, chaque écran échouant en silence. L'écran de compte fermé
/// n'apparaissait qu'au sondage suivant, jusqu'à un quart d'heure plus tard.
///
/// Même mécanisme pour un membre bloqué par l'administrateur de son
/// entreprise (403 `MEMBERSHIP_SUSPENDED`) : le compte reste valide, seul
/// l'accès à cette entreprise est fermé, et c'est réversible. Les données
/// locales sont donc conservées.
enum AccountBlockKind {
  /// Compte client suspendu par Wanzo (`ACCOUNT_SUSPENDED`).
  account,

  /// Membre bloqué par l'administrateur de son entreprise
  /// (`MEMBERSHIP_SUSPENDED`).
  membership,
}

class AccountBlockDetail {
  const AccountBlockDetail({
    required this.message,
    this.kind = AccountBlockKind.account,
    this.reason,
    this.supportEmail,
    this.supportPhone,
    this.supportWhatsapp,
  });

  final String message;
  final AccountBlockKind kind;
  final String? reason;
  final String? supportEmail;
  final String? supportPhone;
  final String? supportWhatsapp;

  bool get isMembership => kind == AccountBlockKind.membership;
}

/// Porte le blocage connu. `null` tant que rien n'a été refusé.
class AccountBlockNotifier extends ValueNotifier<AccountBlockDetail?> {
  AccountBlockNotifier._() : super(null);

  static final AccountBlockNotifier instance = AccountBlockNotifier._();

  static const String codeCompteSuspendu = 'ACCOUNT_SUSPENDED';
  static const String codeMembreSuspendu = 'MEMBERSHIP_SUSPENDED';

  /// Enregistre un refus. Les suivants ne changent rien : le premier suffit,
  /// sauf un compte fermé qui l'emporte sur un simple accès suspendu.
  void signal(AccountBlockDetail detail) {
    final actuel = value;
    if (actuel != null &&
        !(actuel.isMembership && detail.kind == AccountBlockKind.account)) {
      return;
    }
    value = detail;
  }

  /// Après une réactivation, l'application repart d'un état propre.
  void clear() => value = null;

  /// Code d'erreur stable porté par un corps de réponse, quelle que soit
  /// l'enveloppe du service : `{code}`, `{statusCode, code, message}`,
  /// `{success:false, error:{code}}`, `{data:{...}}`, ou un `message` objet.
  static String? codeErreur(dynamic corps) =>
      _noeudAvecCode(corps)?['code']?.toString();

  /// Premier objet de l'enveloppe qui porte un champ `code` (profondeur
  /// bornée : une réponse n'en emboîte jamais plus de quelques-unes).
  static Map? _noeudAvecCode(dynamic corps, [int profondeur = 0]) {
    if (corps is! Map || profondeur > 4) return null;
    final code = corps['code'];
    if (code is String && code.trim().isNotEmpty) return corps;
    for (final cle in const ['error', 'data', 'message', 'response', 'details']) {
      final trouve = _noeudAvecCode(corps[cle], profondeur + 1);
      if (trouve != null) return trouve;
    }
    return null;
  }

  /// Reconnaît le refus du portail dans un corps de réponse.
  /// Retourne `null` si ce 403 vient d'autre chose (droits insuffisants).
  static AccountBlockDetail? lireRefus(dynamic corps) {
    if (corps is! Map) return null;
    final noeud = _noeudAvecCode(corps);
    final code = noeud?['code']?.toString();

    if (code == codeMembreSuspendu) {
      final message = noeud?['message'];
      return AccountBlockDetail(
        kind: AccountBlockKind.membership,
        message: (message is String && message.trim().isNotEmpty)
            ? message.trim()
            : 'Votre accès à cette entreprise a été suspendu par son administrateur.',
      );
    }

    final source = code == codeCompteSuspendu ? noeud! : corps;
    final bloque = corps['accessBlocked'];
    if (code != codeCompteSuspendu && bloque != true) return null;

    final support = source['support'] ?? corps['support'];
    String? contact(String cle) {
      if (support is! Map) return null;
      final valeur = support[cle]?.toString().trim();
      return (valeur == null || valeur.isEmpty) ? null : valeur;
    }

    final message = source['message'] ?? corps['message'];
    final texte = message is String ? message.trim() : null;
    return AccountBlockDetail(
      message: (texte == null || texte.isEmpty)
          ? 'Votre compte est suspendu.'
          : texte,
      reason: (source['accountSuspensionReason'] ??
              corps['accountSuspensionReason'])
          ?.toString(),
      supportEmail: contact('email'),
      supportPhone: contact('phone'),
      supportWhatsapp: contact('whatsapp'),
    );
  }
}
