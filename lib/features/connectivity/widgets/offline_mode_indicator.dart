// filepath: c:\Users\DevSpace\Flutter\wanzo\lib\features\connectivity\widgets\offline_mode_indicator.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/connectivity_provider.dart';

/// Widget pour afficher un indicateur de mode hors ligne
class OfflineModeIndicator extends StatelessWidget {
  final Color backgroundColor;
  final Color textColor;
  final double borderRadius;
  final EdgeInsets padding;
  
  /// Constructeur
  const OfflineModeIndicator({
    super.key,
    this.backgroundColor = Colors.red,
    this.textColor = Colors.white,
    this.borderRadius = 8.0,
    this.padding = const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
  });

  @override
  Widget build(BuildContext context) {
    return Consumer<ConnectivityProvider>(
      builder: (context, connectivityProvider, child) {
        // Ne rien afficher si connecté
        if (connectivityProvider.isConnected) {
          return const SizedBox.shrink();
        }
        
        // Formater le temps hors ligne
        String offlineTime;
        final seconds = connectivityProvider.offlineDurationInSeconds;
        
        if (seconds < 60) {
          offlineTime = '$seconds secondes';
        } else if (seconds < 3600) {
          final minutes = seconds ~/ 60;
          offlineTime = '$minutes minute${minutes > 1 ? 's' : ''}';
        } else {
          final hours = seconds ~/ 3600;
          final minutes = (seconds % 3600) ~/ 60;
          offlineTime = '$hours heure${hours > 1 ? 's' : ''} $minutes minute${minutes > 1 ? 's' : ''}';
        }
        
        return Container(
          padding: padding,
          margin: const EdgeInsets.all(8.0),
          decoration: BoxDecoration(
            color: backgroundColor,
            borderRadius: BorderRadius.circular(borderRadius),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.cloud_off,
                color: Colors.white,
                size: 18.0,
              ),
              const SizedBox(width: 8.0),
              Flexible(
                child: Text(
                  'Mode hors ligne ($offlineTime)',
                  style: TextStyle(
                    color: textColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 14.0,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
