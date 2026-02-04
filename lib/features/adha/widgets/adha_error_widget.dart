import 'package:flutter/material.dart';
import '../utils/adha_error_helper.dart';

/// Widget pour afficher les erreurs ADHA de manière user-friendly
/// Style ChatGPT/Gemini: messages clairs avec icônes et actions
class AdhaErrorWidget extends StatelessWidget {
  final String errorMessage;
  final VoidCallback? onRetry;
  final VoidCallback? onNewConversation;
  final VoidCallback? onReauth;

  const AdhaErrorWidget({
    super.key,
    required this.errorMessage,
    this.onRetry,
    this.onNewConversation,
    this.onReauth,
  });

  @override
  Widget build(BuildContext context) {
    final friendlyError = AdhaErrorHelper.parseError(errorMessage);
    final theme = Theme.of(context);

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Icône avec fond circulaire
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: theme.colorScheme.errorContainer.withOpacity(0.3),
                shape: BoxShape.circle,
              ),
              child: Icon(
                friendlyError.icon,
                size: 40,
                color: theme.colorScheme.error.withOpacity(0.8),
              ),
            ),
            const SizedBox(height: 24),

            // Titre
            Text(
              friendlyError.title,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w600,
                color: theme.colorScheme.onSurface,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),

            // Message explicatif
            Text(
              friendlyError.message,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),

            // Boutons d'action
            _buildActionButtons(context, friendlyError),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButtons(
    BuildContext context,
    AdhaFriendlyError friendlyError,
  ) {
    final theme = Theme.of(context);
    final List<Widget> buttons = [];

    // Bouton principal selon le type d'erreur
    if (friendlyError.requiresReauth && onReauth != null) {
      buttons.add(
        FilledButton.icon(
          onPressed: onReauth,
          icon: const Icon(Icons.login_rounded, size: 18),
          label: Text(friendlyError.actionLabel ?? 'Se reconnecter'),
          style: FilledButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          ),
        ),
      );
    } else if (friendlyError.shouldStartNew && onNewConversation != null) {
      buttons.add(
        FilledButton.icon(
          onPressed: onNewConversation,
          icon: const Icon(Icons.add_comment_rounded, size: 18),
          label: Text(friendlyError.actionLabel ?? 'Nouvelle conversation'),
          style: FilledButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          ),
        ),
      );
    } else if (friendlyError.canRetry && onRetry != null) {
      buttons.add(
        FilledButton.icon(
          onPressed: onRetry,
          icon: const Icon(Icons.refresh_rounded, size: 18),
          label: Text(friendlyError.actionLabel ?? 'Réessayer'),
          style: FilledButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          ),
        ),
      );
    }

    // Bouton secondaire pour nouvelle conversation (si ce n'est pas déjà le bouton principal)
    if (!friendlyError.shouldStartNew &&
        onNewConversation != null &&
        friendlyError.canRetry) {
      buttons.add(
        TextButton.icon(
          onPressed: onNewConversation,
          icon: Icon(
            Icons.add_comment_outlined,
            size: 18,
            color: theme.colorScheme.primary,
          ),
          label: Text(
            'Nouvelle conversation',
            style: TextStyle(color: theme.colorScheme.primary),
          ),
        ),
      );
    }

    if (buttons.isEmpty) {
      // Aucune action possible, afficher juste un message
      return Text(
        'Contactez le support si le problème persiste.',
        style: TextStyle(
          color: theme.colorScheme.onSurfaceVariant,
          fontSize: 12,
        ),
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children:
          buttons
              .map(
                (button) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: button,
                ),
              )
              .toList(),
    );
  }
}

/// Widget inline pour afficher une erreur dans le chat (style message)
/// Utilisé quand une erreur survient pendant une conversation active
class AdhaInlineErrorWidget extends StatelessWidget {
  final String errorMessage;
  final VoidCallback? onRetry;

  const AdhaInlineErrorWidget({
    super.key,
    required this.errorMessage,
    this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    final friendlyError = AdhaErrorHelper.parseError(errorMessage);
    final theme = Theme.of(context);

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.errorContainer.withOpacity(0.2),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: theme.colorScheme.error.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: theme.colorScheme.errorContainer.withOpacity(0.5),
              shape: BoxShape.circle,
            ),
            child: Icon(
              friendlyError.icon,
              size: 20,
              color: theme.colorScheme.error,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  friendlyError.title,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  friendlyError.message,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    height: 1.4,
                  ),
                ),
                if (friendlyError.canRetry && onRetry != null) ...[
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 32,
                    child: TextButton.icon(
                      onPressed: onRetry,
                      icon: const Icon(Icons.refresh_rounded, size: 16),
                      label: Text(friendlyError.actionLabel ?? 'Réessayer'),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        textStyle: const TextStyle(fontSize: 13),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
