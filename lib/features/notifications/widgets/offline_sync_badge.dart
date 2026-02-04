// filepath: c:\Users\DevSpace\Flutter\wanzo\lib\features\notifications\widgets\offline_sync_badge.dart

import 'package:flutter/material.dart';

/// Widget affichant un badge pour les notifications en attente de synchronisation
class OfflineSyncBadge extends StatelessWidget {
  /// Nombre de notifications en attente de synchronisation
  final int pendingCount;
  
  /// Taille du badge
  final double size;
  
  /// Couleur du badge
  final Color color;
  
  /// Constructeur
  const OfflineSyncBadge({
    super.key,
    required this.pendingCount,
    this.size = 16,
    this.color = Colors.amber,
  });

  @override
  Widget build(BuildContext context) {
    if (pendingCount <= 0) return const SizedBox.shrink();
    
    return Container(
      height: size,
      width: size,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
      ),
      child: Center(
        child: Text(
          pendingCount > 9 ? '9+' : pendingCount.toString(),
          style: TextStyle(
            color: Colors.white,
            fontSize: size * 0.65,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}
