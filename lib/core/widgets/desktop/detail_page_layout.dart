import 'package:flutter/material.dart';

/// Layout adaptatif pour les pages de détail
///
/// Sur desktop (>= 900px): affiche un layout à 2 colonnes
///   - Colonne principale (60%): header + contenu principal
///   - Sidebar (40%): informations complémentaires
///
/// Sur mobile/tablette: layout vertical standard
class DetailPageLayout extends StatelessWidget {
  /// Widget header (affiché en haut sur toute la largeur)
  final Widget header;

  /// Contenu principal
  final Widget mainContent;

  /// Contenu de la sidebar (optionnel)
  /// Si null, le layout reste sur une seule colonne même en desktop
  final Widget? sidebar;

  /// Actions dans la barre d'app (optionnel)
  final List<Widget>? actions;

  /// Ratio de la colonne principale (default: 3 = 60%)
  final int mainFlex;

  /// Ratio de la sidebar (default: 2 = 40%)
  final int sidebarFlex;

  /// Breakpoint pour le mode desktop
  final double desktopBreakpoint;

  /// Padding du contenu
  final EdgeInsets contentPadding;

  /// Afficher un divider vertical entre les colonnes
  final bool showDivider;

  const DetailPageLayout({
    super.key,
    required this.header,
    required this.mainContent,
    this.sidebar,
    this.actions,
    this.mainFlex = 3,
    this.sidebarFlex = 2,
    this.desktopBreakpoint = 900.0,
    this.contentPadding = const EdgeInsets.all(16.0),
    this.showDivider = true,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isDesktop = constraints.maxWidth >= desktopBreakpoint;
        final hasSidebar = sidebar != null;

        if (isDesktop && hasSidebar) {
          return _buildDesktopLayout(context);
        }

        return _buildMobileLayout(context, hasSidebar);
      },
    );
  }

  Widget _buildDesktopLayout(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Header Card pleine largeur
        Padding(
          padding: EdgeInsets.fromLTRB(
            contentPadding.left,
            contentPadding.top,
            contentPadding.right,
            0,
          ),
          child: header,
        ),
        const SizedBox(height: 16),

        // Contenu en 2 colonnes
        Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Colonne principale
              Expanded(
                flex: mainFlex,
                child: SingleChildScrollView(
                  padding: EdgeInsets.fromLTRB(
                    contentPadding.left,
                    0,
                    showDivider ? 8 : contentPadding.right / 2,
                    contentPadding.bottom,
                  ),
                  child: mainContent,
                ),
              ),

              // Divider vertical
              if (showDivider)
                Container(
                  width: 1,
                  color: theme.dividerColor.withValues(alpha: 0.5),
                ),

              // Sidebar
              Expanded(
                flex: sidebarFlex,
                child: SingleChildScrollView(
                  padding: EdgeInsets.fromLTRB(
                    showDivider ? 8 : contentPadding.left / 2,
                    0,
                    contentPadding.right,
                    contentPadding.bottom,
                  ),
                  child: sidebar!,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMobileLayout(BuildContext context, bool hasSidebar) {
    return SingleChildScrollView(
      padding: contentPadding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          header,
          const SizedBox(height: 16),
          mainContent,
          if (hasSidebar) ...[
            const SizedBox(height: 24),
            const Divider(),
            const SizedBox(height: 16),
            sidebar!,
          ],
        ],
      ),
    );
  }
}

/// Widget pour une section dans le DetailPageLayout
class DetailSection extends StatelessWidget {
  final String title;
  final IconData? icon;
  final Widget child;
  final List<Widget>? actions;
  final EdgeInsets? padding;
  final bool showCard;

  const DetailSection({
    super.key,
    required this.title,
    this.icon,
    required this.child,
    this.actions,
    this.padding,
    this.showCard = true,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header de section
        Row(
          children: [
            if (icon != null) ...[
              Icon(icon, size: 20, color: theme.colorScheme.primary),
              const SizedBox(width: 8),
            ],
            Expanded(
              child: Text(
                title,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: theme.colorScheme.primary,
                ),
              ),
            ),
            if (actions != null) ...actions!,
          ],
        ),
        const SizedBox(height: 12),
        child,
      ],
    );

    if (!showCard) {
      return Padding(padding: padding ?? EdgeInsets.zero, child: content);
    }

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: padding ?? const EdgeInsets.all(16),
        child: content,
      ),
    );
  }
}

/// Widget pour une ligne d'information clé/valeur
class DetailInfoRow extends StatelessWidget {
  final String label;
  final String value;
  final IconData? icon;
  final Color? valueColor;
  final bool isHighlighted;
  final Widget? trailing;

  const DetailInfoRow({
    super.key,
    required this.label,
    required this.value,
    this.icon,
    this.valueColor,
    this.isHighlighted = false,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 16, color: theme.colorScheme.outline),
            const SizedBox(width: 8),
          ],
          Expanded(
            flex: 2,
            child: Text(
              label,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.outline,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 3,
            child: Text(
              value,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: isHighlighted ? FontWeight.w600 : FontWeight.normal,
                color:
                    valueColor ??
                    (isHighlighted ? theme.colorScheme.primary : null),
              ),
              textAlign: TextAlign.end,
            ),
          ),
          if (trailing != null) ...[const SizedBox(width: 8), trailing!],
        ],
      ),
    );
  }
}

/// Widget pour les boutons d'action dans une page de détail
class DetailActionBar extends StatelessWidget {
  final List<DetailAction> actions;
  final bool isCompact;

  const DetailActionBar({
    super.key,
    required this.actions,
    this.isCompact = false,
  });

  @override
  Widget build(BuildContext context) {
    if (isCompact) {
      return Wrap(
        spacing: 8,
        runSpacing: 8,
        children:
            actions
                .map((action) => _buildCompactAction(context, action))
                .toList(),
      );
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children:
          actions.asMap().entries.map((entry) {
            final index = entry.key;
            final action = entry.value;
            return Padding(
              padding: EdgeInsets.only(left: index > 0 ? 8 : 0),
              child: _buildAction(context, action),
            );
          }).toList(),
    );
  }

  Widget _buildAction(BuildContext context, DetailAction action) {
    if (action.isPrimary) {
      return FilledButton.icon(
        onPressed: action.onPressed,
        icon: Icon(action.icon, size: 18),
        label: Text(action.label),
        style:
            action.isDestructive
                ? FilledButton.styleFrom(backgroundColor: Colors.red)
                : null,
      );
    }

    return OutlinedButton.icon(
      onPressed: action.onPressed,
      icon: Icon(action.icon, size: 18),
      label: Text(action.label),
      style:
          action.isDestructive
              ? OutlinedButton.styleFrom(foregroundColor: Colors.red)
              : null,
    );
  }

  Widget _buildCompactAction(BuildContext context, DetailAction action) {
    return IconButton(
      onPressed: action.onPressed,
      icon: Icon(action.icon),
      tooltip: action.label,
      color: action.isDestructive ? Colors.red : null,
    );
  }
}

/// Modèle pour une action dans DetailActionBar
class DetailAction {
  final String label;
  final IconData icon;
  final VoidCallback? onPressed;
  final bool isPrimary;
  final bool isDestructive;

  const DetailAction({
    required this.label,
    required this.icon,
    this.onPressed,
    this.isPrimary = false,
    this.isDestructive = false,
  });
}
