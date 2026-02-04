import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'wanzo_app_bar.dart';
import 'wanzo_bottom_navigation_bar.dart';

/// Structure de base pour les écrans principaux de l'application
/// Intègre l'AppBar commun et la barre de navigation inférieure
class WanzoScaffold extends StatelessWidget {
  /// L'index actif dans la BottomNavigationBar
  final int currentIndex;
  
  /// Le titre à afficher dans l'AppBar
  final String title;
  
  /// Le contenu principal de l'écran
  final Widget body;
  
  /// Bouton d'action flottant (optionnel)
  final Widget? floatingActionButton;
  
  /// Actions additionnelles pour l'AppBar
  final List<Widget>? appBarActions;
  
  /// Callback pour le bouton de retour (null = pas de bouton)
  final VoidCallback? onBackPressed;
  
  /// Constructeur
  const WanzoScaffold({
    super.key,
    required this.currentIndex,
    required this.title,
    required this.body,
    this.floatingActionButton,
    this.appBarActions,
    this.onBackPressed,
  });
    @override
  Widget build(BuildContext context) {    // Items de navigation
    final List<BottomNavItem> navigationItems = [
      BottomNavItem(
        icon: Icons.dashboard,
        activeIcon: Icons.dashboard_outlined,
        label: 'Tableau de bord',
        route: '/dashboard',
      ),
      BottomNavItem(
        icon: Icons.swap_horiz, // Changed icon to represent operations
        activeIcon: Icons.swap_horiz_outlined, // Changed icon
        label: 'Opérations', // Changed label from 'Ventes' to 'Opérations'
        route: '/operations', // Changed route from '/sales' to '/operations'
      ),
      BottomNavItem(
        icon: Icons.inventory,
        activeIcon: Icons.inventory_outlined,
        label: 'Stock',
        route: '/inventory',
      ),
      BottomNavItem(
        icon: Icons.groups,
        activeIcon: Icons.groups_outlined,
        label: 'Contacts',
        route: '/contacts',
      ),
      BottomNavItem(
        icon: Icons.smart_toy,
        activeIcon: Icons.smart_toy_outlined,
        label: 'Adha',
        route: '/adha',
      ),
    ];
    
    return Scaffold(
      appBar: WanzoAppBar(
        title: title,
        additionalActions: appBarActions,
        onBackPressed: onBackPressed,
      ),
      body: body,
      bottomNavigationBar: currentIndex >= 0 && currentIndex < navigationItems.length
          ? WanzoBottomNavigationBar(
              currentIndex: currentIndex,
              items: navigationItems,
              onTap: (index) {
                // Éviter de recharger la page courante
                if (index == currentIndex) {
                  return;
                }
                switch (index) {
                  case 0:
                    context.go('/dashboard');
                    break;
                  case 1:
                    context.go('/operations'); // Changed route from '/sales' to '/operations'
                    break;
                  case 2:
                    context.go('/inventory');
                    break;
                  case 3:
                    context.go('/contacts');
                    break;
                  case 4:
                    context.go('/adha');
                    break;
                  default:
                    context.go('/dashboard');
                }
              },
            )
          : null, // Do not build the bottom navigation bar if currentIndex is invalid
      floatingActionButton: floatingActionButton,
    );
  }
}
