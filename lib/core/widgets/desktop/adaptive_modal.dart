import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../platform/platform_service.dart';

/// Configuration des tailles de modal
enum ModalSize {
  /// Small modal (400px) - Pour les formulaires simples
  small,

  /// Medium modal (600px) - Pour les formulaires moyens
  medium,

  /// Large modal (800px) - Pour les formulaires complexes
  large,

  /// Extra large modal (1000px) - Pour les formulaires très complexes
  extraLarge,

  /// Full width avec marges - Pour les formulaires en grille
  fullWidth,
}

/// Extension pour obtenir la largeur maximale
extension ModalSizeExtension on ModalSize {
  double get maxWidth {
    switch (this) {
      case ModalSize.small:
        return 450;
      case ModalSize.medium:
        return 600;
      case ModalSize.large:
        return 800;
      case ModalSize.extraLarge:
        return 1000;
      case ModalSize.fullWidth:
        return double.infinity;
    }
  }
}

/// Modal adaptative pour desktop et mobile
/// Sur desktop: affiche une modal centrée avec largeur contrôlée
/// Sur mobile: affiche une page plein écran (bottom sheet ou push)
class AdaptiveModal extends StatelessWidget {
  /// Titre de la modal
  final String title;

  /// Sous-titre optionnel
  final String? subtitle;

  /// Contenu de la modal
  final Widget child;

  /// Taille de la modal (desktop uniquement)
  final ModalSize size;

  /// Actions à afficher dans le header
  final List<Widget>? actions;

  /// Callback de fermeture
  final VoidCallback? onClose;

  /// Affiche le bouton de fermeture
  final bool showCloseButton;

  /// Hauteur maximale (en proportion de l'écran, 0.0 à 1.0)
  final double maxHeightFactor;

  /// Padding du contenu
  final EdgeInsets? contentPadding;

  /// Widget footer (boutons d'action)
  final Widget? footer;

  /// Couleur de l'icône du header
  final IconData? headerIcon;

  /// Couleur de l'icône
  final Color? headerIconColor;

  const AdaptiveModal({
    super.key,
    required this.title,
    this.subtitle,
    required this.child,
    this.size = ModalSize.medium,
    this.actions,
    this.onClose,
    this.showCloseButton = true,
    this.maxHeightFactor = 0.9,
    this.contentPadding,
    this.footer,
    this.headerIcon,
    this.headerIconColor,
  });

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final platform = PlatformService.instance;
    final isDesktop = screenSize.width >= platform.desktopMinWidth;
    final isTablet = screenSize.width >= platform.tabletMinWidth && !isDesktop;

    if (isDesktop || isTablet) {
      return _buildDesktopModal(context, screenSize, isDesktop);
    } else {
      return _buildMobileModal(context);
    }
  }

  Widget _buildDesktopModal(
    BuildContext context,
    Size screenSize,
    bool isDesktop,
  ) {
    final theme = Theme.of(context);

    // Calculer la largeur effective
    double effectiveMaxWidth = size.maxWidth;
    if (size == ModalSize.fullWidth) {
      effectiveMaxWidth = screenSize.width * 0.9;
    }

    // Limiter à 90% de l'écran
    effectiveMaxWidth = effectiveMaxWidth.clamp(0, screenSize.width * 0.95);

    final effectivePadding = contentPadding ?? const EdgeInsets.all(24);

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: EdgeInsets.symmetric(
        horizontal: isDesktop ? 40 : 24,
        vertical: 24,
      ),
      child: KeyboardListener(
        focusNode: FocusNode()..requestFocus(),
        onKeyEvent: (event) {
          if (event is KeyDownEvent &&
              event.logicalKey == LogicalKeyboardKey.escape) {
            Navigator.of(context).pop();
          }
        },
        child: Container(
          constraints: BoxConstraints(
            maxWidth: effectiveMaxWidth,
            maxHeight: screenSize.height * maxHeightFactor,
          ),
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.15),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Header
                _buildHeader(context, theme),

                // Divider
                Divider(height: 1, color: theme.dividerColor),

                // Content (scrollable)
                Flexible(
                  child: SingleChildScrollView(
                    padding: effectivePadding,
                    child: child,
                  ),
                ),

                // Footer
                if (footer != null) ...[
                  Divider(height: 1, color: theme.dividerColor),
                  _buildFooter(context, theme),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMobileModal(BuildContext context) {
    final theme = Theme.of(context);
    final effectivePadding = contentPadding ?? const EdgeInsets.all(16);

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title),
            if (subtitle != null)
              Text(
                subtitle!,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                ),
              ),
          ],
        ),
        leading:
            showCloseButton
                ? IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: onClose ?? () => Navigator.of(context).pop(),
                )
                : null,
        actions: actions,
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: effectivePadding,
              child: child,
            ),
          ),
          if (footer != null)
            SafeArea(
              child: Padding(padding: const EdgeInsets.all(16), child: footer!),
            ),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context, ThemeData theme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Row(
        children: [
          if (headerIcon != null) ...[
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: (headerIconColor ?? theme.colorScheme.primary)
                    .withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                headerIcon,
                color: headerIconColor ?? theme.colorScheme.primary,
                size: 24,
              ),
            ),
            const SizedBox(width: 16),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    subtitle!,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (actions != null) ...actions!,
          if (showCloseButton) ...[
            const SizedBox(width: 8),
            IconButton(
              icon: const Icon(Icons.close),
              onPressed: onClose ?? () => Navigator.of(context).pop(),
              tooltip: 'Fermer',
              style: IconButton.styleFrom(
                backgroundColor: theme.colorScheme.surfaceContainerHighest,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildFooter(BuildContext context, ThemeData theme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: footer,
    );
  }

  /// Méthode statique pour afficher une modal adaptative
  /// Retourne le résultat de la modal (si applicable)
  static Future<T?> show<T>({
    required BuildContext context,
    required String title,
    String? subtitle,
    required Widget child,
    ModalSize size = ModalSize.medium,
    List<Widget>? actions,
    bool showCloseButton = true,
    double maxHeightFactor = 0.9,
    EdgeInsets? contentPadding,
    Widget? footer,
    IconData? headerIcon,
    Color? headerIconColor,
    bool barrierDismissible = true,
  }) {
    final screenSize = MediaQuery.of(context).size;
    final platform = PlatformService.instance;
    final isDesktop = screenSize.width >= platform.desktopMinWidth;
    final isTablet = screenSize.width >= platform.tabletMinWidth && !isDesktop;

    if (isDesktop || isTablet) {
      return showDialog<T>(
        context: context,
        barrierDismissible: barrierDismissible,
        barrierColor: Colors.black54,
        builder:
            (context) => AdaptiveModal(
              title: title,
              subtitle: subtitle,
              size: size,
              actions: actions,
              showCloseButton: showCloseButton,
              maxHeightFactor: maxHeightFactor,
              contentPadding: contentPadding,
              footer: footer,
              headerIcon: headerIcon,
              headerIconColor: headerIconColor,
              child: child,
            ),
      );
    } else {
      // Sur mobile, utiliser une navigation plein écran
      return Navigator.of(context).push<T>(
        MaterialPageRoute(
          builder:
              (context) => AdaptiveModal(
                title: title,
                subtitle: subtitle,
                size: size,
                actions: actions,
                showCloseButton: showCloseButton,
                maxHeightFactor: maxHeightFactor,
                contentPadding: contentPadding,
                footer: footer,
                headerIcon: headerIcon,
                headerIconColor: headerIconColor,
                child: child,
              ),
          fullscreenDialog: true,
        ),
      );
    }
  }
}

/// Footer standard pour les modals de formulaire
class ModalFormFooter extends StatelessWidget {
  /// Texte du bouton d'annulation
  final String cancelText;

  /// Texte du bouton de confirmation
  final String confirmText;

  /// Callback d'annulation
  final VoidCallback? onCancel;

  /// Callback de confirmation
  final VoidCallback? onConfirm;

  /// Le bouton de confirmation est-il actif?
  final bool isConfirmEnabled;

  /// Afficher un indicateur de chargement
  final bool isLoading;

  /// Couleur du bouton de confirmation
  final Color? confirmColor;

  /// Icône du bouton de confirmation
  final IconData? confirmIcon;

  const ModalFormFooter({
    super.key,
    this.cancelText = 'Annuler',
    this.confirmText = 'Enregistrer',
    this.onCancel,
    this.onConfirm,
    this.isConfirmEnabled = true,
    this.isLoading = false,
    this.confirmColor,
    this.confirmIcon,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final screenWidth = MediaQuery.of(context).size.width;
    final platform = PlatformService.instance;
    final isDesktop = screenWidth >= platform.desktopMinWidth;

    final buttonStyle =
        isDesktop
            ? const EdgeInsets.symmetric(horizontal: 24, vertical: 14)
            : const EdgeInsets.symmetric(horizontal: 16, vertical: 12);

    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        // Bouton Annuler
        TextButton(
          onPressed:
              isLoading
                  ? null
                  : (onCancel ?? () => Navigator.of(context).pop()),
          style: TextButton.styleFrom(padding: buttonStyle),
          child: Text(cancelText),
        ),
        const SizedBox(width: 12),

        // Bouton Confirmer
        FilledButton.icon(
          onPressed: isLoading || !isConfirmEnabled ? null : onConfirm,
          style: FilledButton.styleFrom(
            backgroundColor: confirmColor ?? theme.colorScheme.primary,
            padding: buttonStyle,
          ),
          icon:
              isLoading
                  ? SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: theme.colorScheme.onPrimary,
                    ),
                  )
                  : Icon(confirmIcon ?? Icons.save, size: 18),
          label: Text(confirmText),
        ),
      ],
    );
  }
}
