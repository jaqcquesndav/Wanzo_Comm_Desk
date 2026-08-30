import 'package:flutter/material.dart';

/// Affiche une boîte de dialogue de confirmation avant la déconnexion.
///
/// Utilisée par tous les points de déclenchement de déconnexion de l'app
/// (menu profil du header desktop, app bar mobile, écrans d'attente de sync,
/// écran d'adhésion à une unité d'affaires) afin d'offrir une expérience
/// homogène. Retourne `true` uniquement si l'utilisateur confirme.
Future<bool> confirmLogout(BuildContext context) async {
  final theme = Theme.of(context);
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) {
      return AlertDialog(
        title: const Text('Se déconnecter ?'),
        content: const Text('Voulez-vous vraiment vous déconnecter ?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: TextButton.styleFrom(
              foregroundColor: theme.colorScheme.error,
            ),
            child: const Text('Se déconnecter'),
          ),
        ],
      );
    },
  );
  return confirmed ?? false;
}
