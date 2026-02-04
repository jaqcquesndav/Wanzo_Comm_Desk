import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../constants/colors.dart';

/// Type de callback pour la navigation
typedef NavigationCallback = void Function(int index);

/// Modèle d'élément de navigation
class BottomNavItem {
  /// Icône à afficher
  final IconData icon;
  
  /// Icône active (sélectionnée)
  final IconData? activeIcon;
  
  /// Libellé de l'élément
  final String label;
  
  /// Route associée (pour GoRouter)
  final String route;
  
  /// Constructeur
  BottomNavItem({
    required this.icon,
    this.activeIcon,
    required this.label,
    required this.route,
  });
}

/// Bottom Navigation Bar réutilisable pour toute l'application Wanzo
class WanzoBottomNavigationBar extends StatelessWidget {
  /// Index sélectionné actuellement
  final int currentIndex;
  
  /// Éléments de navigation
  final List<BottomNavItem> items;
  
  /// Callback appelé lors du changement d'index
  final NavigationCallback? onTap;
  
  /// Constructeur
  const WanzoBottomNavigationBar({
    super.key,
    required this.currentIndex,
    required this.items,
    this.onTap,
  });
  
  @override
  Widget build(BuildContext context) {
    return BottomNavigationBar(
      currentIndex: currentIndex,
      onTap: (index) {
        if (onTap != null) {
          onTap!(index);
        } else {
          // Navigation par défaut avec GoRouter
          context.go(items[index].route);
        }
      },
      items: items.map((item) {
        return BottomNavigationBarItem(
          icon: Icon(item.icon),
          activeIcon: item.activeIcon != null ? Icon(item.activeIcon) : null,
          label: item.label,
        );
      }).toList(),
      type: BottomNavigationBarType.fixed,
      selectedItemColor: WanzoColors.primary,
      unselectedItemColor: Colors.grey,
    );
  }
}
