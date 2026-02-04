// filepath: c:\Users\DevSpace\Flutter\wanzo\lib\features\auth\widgets\auth_offline_indicator.dart

import 'package:flutter/material.dart';

/// Widget qui affiche un indicateur discret du mode d'authentification hors ligne
class AuthOfflineIndicator extends StatelessWidget {
  /// Indique si l'utilisateur est authentifié en mode hors ligne
  final bool isOfflineAuthenticated;
  
  /// Taille de l'indicateur
  final double size;
  
  /// Constructeur
  const AuthOfflineIndicator({
    super.key,
    required this.isOfflineAuthenticated,
    this.size = 14,
  });

  @override
  Widget build(BuildContext context) {
    if (!isOfflineAuthenticated) return const SizedBox.shrink();
    
    // Petit indicateur nuage pour l'authentification hors ligne
    return Container(
      padding: const EdgeInsets.symmetric(
        vertical: 2, 
        horizontal: 4,
      ),
      decoration: BoxDecoration(
        color: Colors.amber.shade100.withOpacity(0.9),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.person_outline,
            size: size,
            color: Colors.amber.shade800,
          ),
          const SizedBox(width: 2),
          Icon(
            Icons.cloud,
            size: size * 0.8,
            color: Colors.amber.shade800,
          ),
        ],
      ),
    );
  }
}
