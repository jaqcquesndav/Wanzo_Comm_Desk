import 'package:flutter/material.dart';

/// Configuration spécifique pour la version desktop de Wanzo
class DesktopConfig {
  DesktopConfig._();

  // Tailles de fenêtre
  static const Size minimumWindowSize = Size(1024, 768);
  static const Size defaultWindowSize = Size(1400, 900);

  // Breakpoints
  static const double mobileBreakpoint = 600;
  static const double tabletBreakpoint = 900;
  static const double desktopBreakpoint = 1200;
  static const double largeDesktopBreakpoint = 1600;

  // Sidebar
  static const double sidebarExpandedWidth = 280;
  static const double sidebarCollapsedWidth = 72;

  // Spacing
  static const double contentPaddingDesktop = 32;
  static const double contentPaddingTablet = 24;
  static const double contentPaddingMobile = 16;

  // DataTable
  static const double dataTableRowHeight = 56;
  static const double dataTableHeaderHeight = 64;
  static const int dataTableDefaultPageSize = 25;
  static const List<int> dataTablePageSizeOptions = [10, 25, 50, 100];

  // Animations
  static const Duration sidebarAnimationDuration = Duration(milliseconds: 200);
  static const Duration pageTransitionDuration = Duration(milliseconds: 300);

  // Keyboard shortcuts
  static const String shortcutNewSale = 'Ctrl+N';
  static const String shortcutNewProduct = 'Ctrl+Shift+P';
  static const String shortcutSearch = 'Ctrl+K';
  static const String shortcutSettings = 'Ctrl+,';
  static const String shortcutHelp = 'F1';

  // Theme colors for desktop
  static const Color sidebarBackgroundColor = Color(0xFFF8F9FA);
  static const Color sidebarSelectedColor = Color(0xFFE3F2FD);
  static const Color sidebarHoverColor = Color(0xFFEEEEEE);

  // Fonts
  static const String monospaceFontFamily = 'Consolas';

  // Print settings
  static const double printMarginTop = 20;
  static const double printMarginBottom = 20;
  static const double printMarginLeft = 25;
  static const double printMarginRight = 25;
}

/// Extension pour les MediaQuery utilities desktop
extension DesktopMediaQueryExtension on BuildContext {
  /// Retourne true si l'écran est de taille mobile
  bool get isMobileScreen {
    return MediaQuery.of(this).size.width < DesktopConfig.mobileBreakpoint;
  }

  /// Retourne true si l'écran est de taille tablette
  bool get isTabletScreen {
    final width = MediaQuery.of(this).size.width;
    return width >= DesktopConfig.mobileBreakpoint &&
        width < DesktopConfig.desktopBreakpoint;
  }

  /// Retourne true si l'écran est de taille desktop
  bool get isDesktopScreen {
    return MediaQuery.of(this).size.width >= DesktopConfig.desktopBreakpoint;
  }

  /// Retourne true si l'écran est large desktop
  bool get isLargeDesktopScreen {
    return MediaQuery.of(this).size.width >=
        DesktopConfig.largeDesktopBreakpoint;
  }

  /// Retourne le padding de contenu approprié selon la taille de l'écran
  double get contentPadding {
    if (isDesktopScreen) return DesktopConfig.contentPaddingDesktop;
    if (isTabletScreen) return DesktopConfig.contentPaddingTablet;
    return DesktopConfig.contentPaddingMobile;
  }

  /// Retourne le nombre de colonnes pour une grille selon la taille de l'écran
  int get gridColumnCount {
    if (isLargeDesktopScreen) return 4;
    if (isDesktopScreen) return 3;
    if (isTabletScreen) return 2;
    return 1;
  }
}
