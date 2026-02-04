// filepath: c:\Users\DevSpace\Flutter\wanzo\lib\features\connectivity\widgets\subtle_offline_indicator.dart

import 'package:flutter/material.dart';
import '../../../core/utils/connectivity_service.dart';

/// Widget qui affiche un indicateur discret du mode hors ligne (petit nuage)
class SubtleOfflineIndicator extends StatelessWidget {
  /// Constructeur
  const SubtleOfflineIndicator({super.key});

  @override
  Widget build(BuildContext context) {
    final connectivityService = ConnectivityService();
    
    return ValueListenableBuilder<bool>(
      valueListenable: connectivityService.connectionStatus,
      builder: (context, isConnected, child) {
        if (isConnected) {
          return const SizedBox.shrink(); // Pas d'indicateur si connecté
        }
        
        // Petit indicateur nuage pour le mode hors ligne
        return Container(
          padding: const EdgeInsets.symmetric(
            vertical: 2, 
            horizontal: 5,
          ),
          decoration: BoxDecoration(
            color: Colors.grey.shade200.withAlpha(230),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.cloud_off,
                size: 14,
                color: Colors.grey.shade700,
              ),
              const SizedBox(width: 2),
              Text(
                'Hors ligne',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w500,
                  color: Colors.grey.shade700,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
