import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../bloc/adha_state.dart';
import 'package:wanzo/l10n/app_localizations.dart';

/// Widget pour afficher les erreurs liées à l'abonnement/quota ADHA
///
/// Affiche un message clair avec:
/// - Icône et couleur adaptées au type d'erreur
/// - Barre de progression de l'utilisation (si disponible)
/// - Avertissement de période de grâce (si applicable)
/// - Boutons d'action (renouveler, voir les plans, etc.)
class AdhaSubscriptionErrorWidget extends StatelessWidget {
  final AdhaSubscriptionError error;
  final VoidCallback? onNewConversation;
  final VoidCallback? onRetry;

  const AdhaSubscriptionErrorWidget({
    super.key,
    required this.error,
    this.onNewConversation,
    this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Icône avec fond circulaire
            _buildIconSection(theme),
            const SizedBox(height: 24),

            // Titre
            Text(
              _getTitle(l10n),
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w600,
                color: theme.colorScheme.onSurface,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),

            // Message explicatif
            Text(
              error.message,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),

            // Barre de progression d'utilisation (si disponible)
            if (error.currentUsage != null && error.limit != null) ...[
              const SizedBox(height: 20),
              _buildUsageIndicator(theme),
            ],

            // Avertissement période de grâce
            if (error.gracePeriodDaysRemaining != null) ...[
              const SizedBox(height: 16),
              _buildGracePeriodWarning(theme, l10n),
            ],

            const SizedBox(height: 32),

            // Boutons d'action
            _buildActionButtons(context, theme, l10n),
          ],
        ),
      ),
    );
  }

  Widget _buildIconSection(ThemeData theme) {
    final iconData = _getIcon();
    final color = _getColor(theme);

    return Container(
      width: 80,
      height: 80,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        shape: BoxShape.circle,
      ),
      child: Icon(iconData, size: 40, color: color),
    );
  }

  IconData _getIcon() {
    switch (error.errorType) {
      case SubscriptionErrorType.quotaExhausted:
        return Icons.token_rounded;
      case SubscriptionErrorType.subscriptionExpired:
        return Icons.event_busy_rounded;
      case SubscriptionErrorType.subscriptionPastDue:
        return Icons.warning_amber_rounded;
      case SubscriptionErrorType.featureNotAvailable:
        return Icons.lock_rounded;
    }
  }

  Color _getColor(ThemeData theme) {
    switch (error.errorType) {
      case SubscriptionErrorType.quotaExhausted:
        return theme.colorScheme.primary;
      case SubscriptionErrorType.subscriptionExpired:
        return theme.colorScheme.error;
      case SubscriptionErrorType.subscriptionPastDue:
        return Colors.orange;
      case SubscriptionErrorType.featureNotAvailable:
        return theme.colorScheme.secondary;
    }
  }

  String _getTitle(AppLocalizations l10n) {
    switch (error.errorType) {
      case SubscriptionErrorType.quotaExhausted:
        return l10n.subscriptionQuotaExhaustedTitle;
      case SubscriptionErrorType.subscriptionExpired:
        return l10n.subscriptionExpiredTitle;
      case SubscriptionErrorType.subscriptionPastDue:
        return l10n.subscriptionPastDueTitle;
      case SubscriptionErrorType.featureNotAvailable:
        return l10n.subscriptionFeatureNotAvailableTitle;
    }
  }

  Widget _buildUsageIndicator(ThemeData theme) {
    final usage = error.currentUsage!;
    final limit = error.limit!;
    final progress = limit > 0 ? (usage / limit).clamp(0.0, 1.0) : 1.0;

    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Utilisation',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            Text(
              '$usage / $limit tokens',
              style: theme.textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.w600,
                color: theme.colorScheme.onSurface,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: progress,
            backgroundColor: theme.colorScheme.surfaceContainerHighest,
            valueColor: AlwaysStoppedAnimation<Color>(
              progress >= 1.0
                  ? theme.colorScheme.error
                  : theme.colorScheme.primary,
            ),
            minHeight: 8,
          ),
        ),
      ],
    );
  }

  Widget _buildGracePeriodWarning(ThemeData theme, AppLocalizations l10n) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.orange.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.orange.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(Icons.schedule_rounded, color: Colors.orange.shade700, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              l10n.subscriptionGracePeriodRemaining(
                error.gracePeriodDaysRemaining!,
              ),
              style: theme.textTheme.bodySmall?.copyWith(
                color: Colors.orange.shade800,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons(
    BuildContext context,
    ThemeData theme,
    AppLocalizations l10n,
  ) {
    final List<Widget> buttons = [];

    // Bouton principal: lien vers l'URL de renouvellement
    if (error.renewalUrl != null && error.renewalUrl!.isNotEmpty) {
      buttons.add(
        FilledButton.icon(
          onPressed: () => _openRenewalUrl(error.renewalUrl!),
          icon: Icon(_getPrimaryActionIcon(), size: 18),
          label: Text(_getPrimaryActionLabel(l10n)),
          style: FilledButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          ),
        ),
      );
    }

    // Bouton secondaire: nouvelle conversation
    if (onNewConversation != null) {
      buttons.add(
        TextButton.icon(
          onPressed: onNewConversation,
          icon: Icon(
            Icons.add_comment_outlined,
            size: 18,
            color: theme.colorScheme.primary,
          ),
          label: Text(
            l10n.subscriptionNewConversationButton,
            style: TextStyle(color: theme.colorScheme.primary),
          ),
        ),
      );
    }

    // Message de support si aucune action n'est disponible
    if (buttons.isEmpty) {
      return Text(
        l10n.subscriptionContactSupport,
        style: TextStyle(
          color: theme.colorScheme.onSurfaceVariant,
          fontSize: 12,
        ),
        textAlign: TextAlign.center,
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

  IconData _getPrimaryActionIcon() {
    switch (error.errorType) {
      case SubscriptionErrorType.quotaExhausted:
      case SubscriptionErrorType.subscriptionExpired:
        return Icons.refresh_rounded;
      case SubscriptionErrorType.subscriptionPastDue:
        return Icons.payment_rounded;
      case SubscriptionErrorType.featureNotAvailable:
        return Icons.upgrade_rounded;
    }
  }

  String _getPrimaryActionLabel(AppLocalizations l10n) {
    switch (error.errorType) {
      case SubscriptionErrorType.quotaExhausted:
      case SubscriptionErrorType.subscriptionExpired:
        return l10n.subscriptionRenewButton;
      case SubscriptionErrorType.subscriptionPastDue:
        return l10n.subscriptionPayNowButton;
      case SubscriptionErrorType.featureNotAvailable:
        return l10n.subscriptionViewPlansButton;
    }
  }

  Future<void> _openRenewalUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }
}
