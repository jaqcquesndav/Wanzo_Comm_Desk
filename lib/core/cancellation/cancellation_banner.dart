import 'package:flutter/material.dart';

import 'document_cancellation.dart';

/// Bandeau d'une pièce annulée : « Annulée le ... par ... : motif », et
/// l'action « Rétablir » pour les rôles autorisés.
class CancellationBanner extends StatelessWidget {
  final CancellationInfo info;

  /// Annulation saisie hors ligne, pas encore reçue par le serveur.
  final bool pendingSync;

  /// Null : pas de bouton (rôle non autorisé).
  final VoidCallback? onRestore;

  const CancellationBanner({
    super.key,
    required this.info,
    this.pendingSync = false,
    this.onRestore,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Container(
      key: const ValueKey('cancellation-banner'),
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: scheme.errorContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.block, color: scheme.onErrorContainer),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  cancellationBanner(info),
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: scheme.onErrorContainer,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  pendingSync
                      ? 'En attente de synchronisation. Hors des totaux.'
                      : 'Hors des totaux, conservée pour la trace.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: scheme.onErrorContainer,
                  ),
                ),
              ],
            ),
          ),
          if (onRestore != null)
            TextButton.icon(
              onPressed: onRestore,
              icon: const Icon(Icons.restore),
              label: const Text('Rétablir'),
              style: TextButton.styleFrom(
                foregroundColor: scheme.onErrorContainer,
              ),
            ),
        ],
      ),
    );
  }
}
