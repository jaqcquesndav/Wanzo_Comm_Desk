import 'package:flutter/material.dart';

import '../exceptions/api_exceptions.dart';

/// Dit la vérité sur une écriture faite sans réseau.
///
/// Quand la connexion manque, l'écriture n'est pas perdue : elle est conservée
/// sur l'appareil et rejouée au retour du réseau. L'app annonçait pourtant
/// « Échec de l'enregistrement », ce qui poussait à ressaisir et créait un
/// doublon à la reconnexion.
///
/// Renvoie `true` quand l'écriture est en attente, pour que l'appelant garde
/// son affichage optimiste au lieu de revenir en arrière.
bool showWriteOutcome(
  BuildContext context,
  Object error, {
  String? failureLabel,
}) {
  final messenger = ScaffoldMessenger.maybeOf(context);
  if (error is OfflineQueuedException) {
    messenger?.showSnackBar(
      SnackBar(
        backgroundColor: Colors.green.shade700,
        content: const Row(
          children: [
            Icon(Icons.cloud_off, color: Colors.white, size: 18),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                'En attente : enregistré sur cet appareil, envoi automatique au retour du réseau.',
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
    return true;
  }
  messenger?.showSnackBar(
    SnackBar(
      content: Text('${failureLabel ?? 'Échec'} : ${readableWriteError(error)}'),
      backgroundColor: Theme.of(context).colorScheme.error,
    ),
  );
  return false;
}

/// Vrai si l'erreur signifie « conservé hors ligne », et non « perdu ».
bool isQueuedOffline(Object error) => error is OfflineQueuedException;

/// Motif lisible d'un refus (message du serveur plutôt que la trace brute).
String readableWriteError(Object error) {
  if (error is ApiException) return error.message;
  final text = error.toString();
  return text.startsWith('Exception: ') ? text.substring(11) : text;
}
