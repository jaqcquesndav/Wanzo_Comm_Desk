// filepath: c:\Users\DevSpace\Flutter\wanzo\lib\features\notifications\widgets\offline_notification_indicator.dart

import 'package:flutter/material.dart';

/// Widget affichant un indicateur pour le mode hors ligne des notifications
class OfflineNotificationIndicator extends StatelessWidget {
  /// Nombre de notifications non synchronisées
  final int unsyncedCount;
  
  /// Taille de l'indicateur
  final double size;

  /// Constructeur
  const OfflineNotificationIndicator({
    super.key,
    required this.unsyncedCount,
    this.size = 16,
  });

  @override
  Widget build(BuildContext context) {
    if (unsyncedCount <= 0) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.amber.shade100,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.amber.shade300, width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.sync_problem,
            size: size,
            color: Colors.amber.shade800,
          ),
          const SizedBox(width: 4),
          Text(
            unsyncedCount.toString(),
            style: TextStyle(
              fontSize: size * 0.8,
              fontWeight: FontWeight.w600,
              color: Colors.amber.shade800,
            ),
          ),
        ],
      ),
    );
  }
}
