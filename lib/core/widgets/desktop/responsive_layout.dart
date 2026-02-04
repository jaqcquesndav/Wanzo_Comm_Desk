import 'package:flutter/material.dart';
import '../../platform/platform_service.dart';

/// Layout responsive qui s'adapte automatiquement selon la taille de l'écran
/// Mobile: affiche le child directement
/// Desktop: affiche le child avec des marges et une largeur maximale
class ResponsiveLayout extends StatelessWidget {
  final Widget child;
  final double? maxWidth;
  final EdgeInsets? padding;
  final bool centerContent;

  const ResponsiveLayout({
    super.key,
    required this.child,
    this.maxWidth,
    this.padding,
    this.centerContent = true,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final screenWidth = constraints.maxWidth;
        final platform = PlatformService.instance;

        // Déterminer le type d'écran
        final isDesktopSize = screenWidth >= platform.desktopMinWidth;
        final isTabletSize =
            screenWidth >= platform.tabletMinWidth &&
            screenWidth < platform.desktopMinWidth;

        // Calculer la largeur maximale du contenu
        double contentMaxWidth;
        if (maxWidth != null) {
          contentMaxWidth = maxWidth!;
        } else if (isDesktopSize) {
          contentMaxWidth = 1200;
        } else if (isTabletSize) {
          contentMaxWidth = 800;
        } else {
          contentMaxWidth = screenWidth;
        }

        // Appliquer le padding
        final effectivePadding =
            padding ??
            EdgeInsets.symmetric(
              horizontal: isDesktopSize ? 32 : (isTabletSize ? 24 : 16),
              vertical: isDesktopSize ? 24 : 16,
            );

        Widget content = Container(
          constraints: BoxConstraints(maxWidth: contentMaxWidth),
          padding: effectivePadding,
          child: child,
        );

        if (centerContent && (isDesktopSize || isTabletSize)) {
          content = Center(child: content);
        }

        return content;
      },
    );
  }
}

/// Widget qui affiche différents children selon la taille de l'écran
class ResponsiveBuilder extends StatelessWidget {
  final Widget mobile;
  final Widget? tablet;
  final Widget? desktop;

  const ResponsiveBuilder({
    super.key,
    required this.mobile,
    this.tablet,
    this.desktop,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final platform = PlatformService.instance;
        final width = constraints.maxWidth;

        if (width >= platform.desktopMinWidth && desktop != null) {
          return desktop!;
        }

        if (width >= platform.tabletMinWidth && tablet != null) {
          return tablet!;
        }

        return mobile;
      },
    );
  }
}

/// Extension pour accéder facilement aux breakpoints
extension ResponsiveExtension on BuildContext {
  bool get isMobileSize {
    final width = MediaQuery.of(this).size.width;
    return width < PlatformService.instance.tabletMinWidth;
  }

  bool get isTabletSize {
    final width = MediaQuery.of(this).size.width;
    final platform = PlatformService.instance;
    return width >= platform.tabletMinWidth && width < platform.desktopMinWidth;
  }

  bool get isDesktopSize {
    final width = MediaQuery.of(this).size.width;
    return width >= PlatformService.instance.desktopMinWidth;
  }

  /// Retourne une valeur selon la taille de l'écran
  T responsive<T>({required T mobile, T? tablet, T? desktop}) {
    if (isDesktopSize && desktop != null) return desktop;
    if (isTabletSize && tablet != null) return tablet;
    return mobile;
  }
}
