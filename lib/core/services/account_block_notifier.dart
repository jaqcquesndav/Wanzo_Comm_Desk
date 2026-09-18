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
class AccountBlockDetail {
  const AccountBlockDetail({
    required this.message,
    this.reason,
    this.supportEmail,
    this.supportPhone,
    this.supportWhatsapp,
  });

  final String message;
  final String? reason;
  final String? supportEmail;
  final String? supportPhone;
  final String? supportWhatsapp;
}

/// Porte le blocage connu. `null` tant que rien n'a été refusé.
class AccountBlockNotifier extends ValueNotifier<AccountBlockDetail?> {
  AccountBlockNotifier._() : super(null);

  static final AccountBlockNotifier instance = AccountBlockNotifier._();

  /// Enregistre un refus. Les suivants ne changent rien : le premier suffit.
  void signal(AccountBlockDetail detail) {
    if (value != null) return;
    value = detail;
  }

  /// Après une réactivation, l'application repart d'un état propre.
  void clear() => value = null;

  /// Reconnaît le refus du portail dans un corps de réponse.
  /// Retourne `null` si ce 403 vient d'autre chose (droits insuffisants).
  static AccountBlockDetail? lireRefus(dynamic corps) {
    if (corps is! Map) return null;
    final code = corps['code'];
    final bloque = corps['accessBlocked'];
    if (code != 'ACCOUNT_SUSPENDED' && bloque != true) return null;

    final support = corps['support'];
    String? contact(String cle) {
      if (support is! Map) return null;
      final valeur = support[cle]?.toString().trim();
      return (valeur == null || valeur.isEmpty) ? null : valeur;
    }

    final message = corps['message']?.toString();
    return AccountBlockDetail(
      message: (message == null || message.isEmpty)
          ? 'Votre compte est suspendu.'
          : message,
      reason: corps['accountSuspensionReason']?.toString(),
      supportEmail: contact('email'),
      supportPhone: contact('phone'),
      supportWhatsapp: contact('whatsapp'),
    );
  }
}
