import 'package:flutter/material.dart';
import '../../platform/platform_service.dart';

/// Conteneur responsive pour les formulaires
/// Adapte automatiquement la largeur et les marges selon l'écran
class ResponsiveFormContainer extends StatelessWidget {
  final Widget child;
  final double? maxWidth;
  final EdgeInsets? padding;
  final bool showCard;
  final bool useScroll;

  const ResponsiveFormContainer({
    super.key,
    required this.child,
    this.maxWidth,
    this.padding,
    this.showCard = true,
    this.useScroll = true,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final screenWidth = constraints.maxWidth;
        final platform = PlatformService.instance;

        final isDesktop = screenWidth >= platform.desktopMinWidth;
        final isTablet = screenWidth >= platform.tabletMinWidth && !isDesktop;

        // Largeur maximale du formulaire
        double contentMaxWidth;
        if (maxWidth != null) {
          contentMaxWidth = maxWidth!;
        } else if (isDesktop) {
          contentMaxWidth = 800;
        } else if (isTablet) {
          contentMaxWidth = 600;
        } else {
          contentMaxWidth = double.infinity;
        }

        // Padding adaptatif
        final effectivePadding =
            padding ?? EdgeInsets.all(isDesktop ? 32 : (isTablet ? 24 : 16));

        Widget content = Container(
          constraints: BoxConstraints(maxWidth: contentMaxWidth),
          padding: effectivePadding,
          child: child,
        );

        if (showCard && (isDesktop || isTablet)) {
          content = Card(
            elevation: 2,
            margin: EdgeInsets.symmetric(
              horizontal: isDesktop ? 48 : 24,
              vertical: 24,
            ),
            child: content,
          );
        }

        if (useScroll) {
          return Center(child: SingleChildScrollView(child: content));
        }
        return Center(child: content);
      },
    );
  }
}

/// Wrapper responsive pour les formulaires qui utilisent ListView
/// Limite la largeur sur desktop/tablet tout en gardant le scroll natif
class ResponsiveFormWrapper extends StatelessWidget {
  final Widget child;
  final double? maxWidth;
  final EdgeInsets? horizontalPadding;

  const ResponsiveFormWrapper({
    super.key,
    required this.child,
    this.maxWidth,
    this.horizontalPadding,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final screenWidth = constraints.maxWidth;
        final platform = PlatformService.instance;

        final isDesktop = screenWidth >= platform.desktopMinWidth;
        final isTablet = screenWidth >= platform.tabletMinWidth && !isDesktop;

        // Largeur maximale du formulaire
        double contentMaxWidth;
        if (maxWidth != null) {
          contentMaxWidth = maxWidth!;
        } else if (isDesktop) {
          contentMaxWidth = 800;
        } else if (isTablet) {
          contentMaxWidth = 600;
        } else {
          contentMaxWidth = double.infinity;
        }

        // Padding horizontal adaptatif
        final effectivePadding =
            horizontalPadding ??
            EdgeInsets.symmetric(
              horizontal: isDesktop ? 48 : (isTablet ? 24 : 0),
            );

        return Center(
          child: Container(
            constraints: BoxConstraints(maxWidth: contentMaxWidth),
            padding: effectivePadding,
            child: child,
          ),
        );
      },
    );
  }
}

/// Widget pour disposer les champs de formulaire en grille sur desktop
class ResponsiveFormFields extends StatelessWidget {
  final List<Widget> children;
  final int desktopColumns;
  final int tabletColumns;
  final double spacing;
  final double runSpacing;

  const ResponsiveFormFields({
    super.key,
    required this.children,
    this.desktopColumns = 2,
    this.tabletColumns = 2,
    this.spacing = 16,
    this.runSpacing = 16,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final screenWidth = constraints.maxWidth;
        final platform = PlatformService.instance;

        final isDesktop = screenWidth >= platform.desktopMinWidth;
        final isTablet = screenWidth >= platform.tabletMinWidth && !isDesktop;

        if (!isDesktop && !isTablet) {
          // Mobile: affiche verticalement
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children:
                children
                    .map(
                      (child) => Padding(
                        padding: EdgeInsets.only(bottom: runSpacing),
                        child: child,
                      ),
                    )
                    .toList(),
          );
        }

        // Desktop/Tablet: grille
        final columns = isDesktop ? desktopColumns : tabletColumns;
        final rows = <Widget>[];

        for (var i = 0; i < children.length; i += columns) {
          final rowChildren = <Widget>[];
          for (var j = 0; j < columns && i + j < children.length; j++) {
            if (j > 0) {
              rowChildren.add(SizedBox(width: spacing));
            }
            rowChildren.add(Expanded(child: children[i + j]));
          }
          // Remplir les colonnes restantes si nécessaire
          while (rowChildren.length < columns * 2 - 1) {
            rowChildren.add(SizedBox(width: spacing));
            rowChildren.add(const Expanded(child: SizedBox()));
          }
          rows.add(
            Padding(
              padding: EdgeInsets.only(bottom: runSpacing),
              child: Row(children: rowChildren),
            ),
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: rows,
        );
      },
    );
  }
}

/// Widget pour un header de formulaire adapté au desktop
class ResponsiveFormHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  final IconData? icon;

  const ResponsiveFormHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final screenWidth = constraints.maxWidth;
        final platform = PlatformService.instance;
        final isDesktop = screenWidth >= platform.desktopMinWidth;

        return Padding(
          padding: EdgeInsets.only(bottom: isDesktop ? 32 : 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  if (icon != null) ...[
                    Container(
                      padding: EdgeInsets.all(isDesktop ? 16 : 12),
                      decoration: BoxDecoration(
                        color: Theme.of(
                          context,
                        ).primaryColor.withAlpha((0.1 * 255).round()),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        icon,
                        size: isDesktop ? 32 : 24,
                        color: Theme.of(context).primaryColor,
                      ),
                    ),
                    SizedBox(width: isDesktop ? 16 : 12),
                  ],
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: TextStyle(
                            fontSize: isDesktop ? 28 : 22,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (subtitle != null) ...[
                          const SizedBox(height: 4),
                          Text(
                            subtitle!,
                            style: TextStyle(
                              fontSize: isDesktop ? 16 : 14,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
              SizedBox(height: isDesktop ? 24 : 16),
              Divider(color: Colors.grey.shade300),
            ],
          ),
        );
      },
    );
  }
}
