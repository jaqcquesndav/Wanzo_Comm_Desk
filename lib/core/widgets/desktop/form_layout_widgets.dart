import 'package:flutter/material.dart';
import '../../platform/platform_service.dart';

/// Layout de formulaire responsive avec grille adaptative
/// Sur desktop: affiche les champs en colonnes multiples
/// Sur mobile: affiche les champs en colonne unique
class FormGridLayout extends StatelessWidget {
  /// Les enfants du formulaire
  final List<Widget> children;

  /// Nombre de colonnes sur desktop (défaut: 2)
  final int desktopColumns;

  /// Nombre de colonnes sur tablet (défaut: 2)
  final int tabletColumns;

  /// Espacement horizontal entre les colonnes
  final double horizontalSpacing;

  /// Espacement vertical entre les lignes
  final double verticalSpacing;

  /// Espacement vertical sur mobile
  final double mobileVerticalSpacing;

  const FormGridLayout({
    super.key,
    required this.children,
    this.desktopColumns = 2,
    this.tabletColumns = 2,
    this.horizontalSpacing = 24,
    this.verticalSpacing = 20,
    this.mobileVerticalSpacing = 16,
  });

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final platform = PlatformService.instance;
    final isDesktop = screenWidth >= platform.desktopMinWidth;
    final isTablet = screenWidth >= platform.tabletMinWidth && !isDesktop;

    if (!isDesktop && !isTablet) {
      // Mobile: colonne unique
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children:
            children
                .expand(
                  (child) => [child, SizedBox(height: mobileVerticalSpacing)],
                )
                .toList()
              ..removeLast(),
      );
    }

    // Desktop/Tablet: grille
    final columns = isDesktop ? desktopColumns : tabletColumns;
    final rows = <Widget>[];

    for (var i = 0; i < children.length; i += columns) {
      final rowChildren = <Widget>[];

      for (var j = 0; j < columns && i + j < children.length; j++) {
        if (j > 0) {
          rowChildren.add(SizedBox(width: horizontalSpacing));
        }
        rowChildren.add(Expanded(child: children[i + j]));
      }

      // Remplir les colonnes vides si nécessaire
      final remaining = columns - (children.length - i).clamp(0, columns);
      for (var k = 0; k < remaining; k++) {
        rowChildren.add(SizedBox(width: horizontalSpacing));
        rowChildren.add(const Expanded(child: SizedBox()));
      }

      rows.add(
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: rowChildren,
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children:
          rows
              .expand((row) => [row, SizedBox(height: verticalSpacing)])
              .toList()
            ..removeLast(),
    );
  }
}

/// Section de formulaire avec titre et contenu groupé
class FormSection extends StatelessWidget {
  /// Titre de la section
  final String title;

  /// Description optionnelle
  final String? description;

  /// Icône optionnelle
  final IconData? icon;

  /// Couleur de l'icône
  final Color? iconColor;

  /// Contenu de la section
  final Widget child;

  /// Padding interne
  final EdgeInsets? padding;

  /// Afficher le card background
  final bool showCard;

  /// Afficher le divider sous le header
  final bool showHeaderDivider;

  const FormSection({
    super.key,
    required this.title,
    this.description,
    this.icon,
    this.iconColor,
    required this.child,
    this.padding,
    this.showCard = true,
    this.showHeaderDivider = true,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final screenWidth = MediaQuery.of(context).size.width;
    final platform = PlatformService.instance;
    final isDesktop = screenWidth >= platform.desktopMinWidth;

    final effectivePadding = padding ?? EdgeInsets.all(isDesktop ? 20 : 16);

    Widget content = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header
        Padding(
          padding: effectivePadding.copyWith(bottom: 0),
          child: Row(
            children: [
              if (icon != null) ...[
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: (iconColor ?? theme.colorScheme.primary).withOpacity(
                      0.1,
                    ),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    icon,
                    color: iconColor ?? theme.colorScheme.primary,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (description != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        description!,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurface.withValues(
                            alpha: 0.6,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),

        if (showHeaderDivider) ...[
          const SizedBox(height: 12),
          Divider(height: 1, color: theme.dividerColor.withValues(alpha: 0.5)),
        ],

        // Content
        Padding(
          padding: effectivePadding.copyWith(
            top: showHeaderDivider ? null : 12,
          ),
          child: child,
        ),
      ],
    );

    if (showCard) {
      return Card(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: theme.dividerColor.withValues(alpha: 0.5)),
        ),
        child: content,
      );
    }

    return content;
  }
}

/// Champ de formulaire avec label et aide optionnelle
/// Conçu pour un aspect professionnel et cohérent
class FormFieldContainer extends StatelessWidget {
  /// Label du champ
  final String label;

  /// Indique si le champ est requis
  final bool isRequired;

  /// Texte d'aide optionnel
  final String? helpText;

  /// Widget du champ
  final Widget child;

  /// Erreur à afficher
  final String? error;

  const FormFieldContainer({
    super.key,
    required this.label,
    this.isRequired = false,
    this.helpText,
    required this.child,
    this.error,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Label
        Row(
          children: [
            Text(
              label,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w500,
                color: theme.colorScheme.onSurface,
              ),
            ),
            if (isRequired) ...[
              const SizedBox(width: 4),
              Text(
                '*',
                style: TextStyle(
                  color: theme.colorScheme.error,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 8),

        // Field
        child,

        // Help text or error
        if (error != null || helpText != null) ...[
          const SizedBox(height: 6),
          Text(
            error ?? helpText!,
            style: theme.textTheme.bodySmall?.copyWith(
              color:
                  error != null
                      ? theme.colorScheme.error
                      : theme.colorScheme.onSurface.withValues(alpha: 0.6),
            ),
          ),
        ],
      ],
    );
  }
}

/// Widget d'action rapide pour les formulaires
/// Affiche des boutons d'action horizontaux stylisés
class QuickActionBar extends StatelessWidget {
  final List<QuickAction> actions;
  final EdgeInsets? padding;

  const QuickActionBar({super.key, required this.actions, this.padding});

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final platform = PlatformService.instance;
    final isDesktop = screenWidth >= platform.desktopMinWidth;

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding:
          padding ??
          EdgeInsets.symmetric(horizontal: isDesktop ? 0 : 16, vertical: 8),
      child: Row(
        children:
            actions.map((action) {
              return Padding(
                padding: const EdgeInsets.only(right: 12),
                child: _QuickActionButton(action: action),
              );
            }).toList(),
      ),
    );
  }
}

class QuickAction {
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final Color? color;
  final bool isOutlined;

  const QuickAction({
    required this.label,
    required this.icon,
    required this.onTap,
    this.color,
    this.isOutlined = false,
  });
}

class _QuickActionButton extends StatelessWidget {
  final QuickAction action;

  const _QuickActionButton({required this.action});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = action.color ?? theme.colorScheme.primary;

    if (action.isOutlined) {
      return OutlinedButton.icon(
        onPressed: action.onTap,
        style: OutlinedButton.styleFrom(
          foregroundColor: color,
          side: BorderSide(color: color.withValues(alpha: 0.5)),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
        icon: Icon(action.icon, size: 18),
        label: Text(action.label),
      );
    }

    return FilledButton.tonal(
      onPressed: action.onTap,
      style: FilledButton.styleFrom(
        backgroundColor: color.withValues(alpha: 0.1),
        foregroundColor: color,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(action.icon, size: 18),
          const SizedBox(width: 8),
          Text(action.label),
        ],
      ),
    );
  }
}

/// Indicateur de statut de formulaire
class FormStatusIndicator extends StatelessWidget {
  final String label;
  final FormStatus status;
  final String? message;

  const FormStatusIndicator({
    super.key,
    required this.label,
    required this.status,
    this.message,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    Color backgroundColor;
    Color textColor;
    IconData icon;

    switch (status) {
      case FormStatus.success:
        backgroundColor = Colors.green.withValues(alpha: 0.1);
        textColor = Colors.green[700]!;
        icon = Icons.check_circle;
        break;
      case FormStatus.warning:
        backgroundColor = Colors.orange.withValues(alpha: 0.1);
        textColor = Colors.orange[700]!;
        icon = Icons.warning;
        break;
      case FormStatus.error:
        backgroundColor = Colors.red.withValues(alpha: 0.1);
        textColor = Colors.red[700]!;
        icon = Icons.error;
        break;
      case FormStatus.info:
        backgroundColor = Colors.blue.withValues(alpha: 0.1);
        textColor = Colors.blue[700]!;
        icon = Icons.info;
        break;
      case FormStatus.neutral:
        backgroundColor = theme.colorScheme.surfaceContainerHighest;
        textColor = theme.colorScheme.onSurface.withValues(alpha: 0.7);
        icon = Icons.circle_outlined;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: textColor),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: textColor,
                  fontWeight: FontWeight.w500,
                ),
              ),
              if (message != null)
                Text(
                  message!,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: textColor.withValues(alpha: 0.8),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

enum FormStatus { success, warning, error, info, neutral }
