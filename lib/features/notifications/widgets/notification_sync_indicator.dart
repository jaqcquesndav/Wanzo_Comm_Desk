// filepath: c:\Users\DevSpace\Flutter\wanzo\lib\features\notifications\widgets\notification_sync_indicator.dart

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../bloc/sync_status_bloc.dart';
import 'offline_sync_badge.dart';

/// Widget affichant l'état de synchronisation des notifications
class NotificationSyncIndicator extends StatelessWidget {
  /// Taille de l'indicateur
  final double size;
  
  /// Couleur de l'indicateur
  final Color? color;
  
  /// Constructeur
  const NotificationSyncIndicator({
    super.key,
    this.size = 24,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<SyncStatusBloc, SyncStatusState>(
      builder: (context, state) {
        if (state is SyncStatusInProgress) {
          // Synchronisation en cours
          return _buildSyncingIndicator();
        } else if (state is SyncStatusReady) {
          // En attente ou prêt
          return _buildReadyIndicator(state);
        } else if (state is SyncStatusError) {
          // Erreur
          return _buildErrorIndicator();
        } else {
          // Chargement ou état initial
          return const SizedBox.shrink();
        }
      },
    );
  }
  
  /// Construit l'indicateur de synchronisation en cours
  Widget _buildSyncingIndicator() {
    return SizedBox(
      width: size,
      height: size,
      child: CircularProgressIndicator(
        strokeWidth: 2,
        valueColor: AlwaysStoppedAnimation<Color>(
          color ?? Colors.amber.shade700,
        ),
      ),
    );
  }
  
  /// Construit l'indicateur de notifications en attente
  Widget _buildReadyIndicator(SyncStatusReady state) {
    if (state.pendingCount <= 0) {
      return const SizedBox.shrink();
    }
    
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Icon(
          Icons.sync,
          size: size,
          color: color ?? Colors.amber.shade700,
        ),
        Positioned(
          top: -size/4,
          right: -size/4,
          child: OfflineSyncBadge(
            pendingCount: state.pendingCount,
            size: size * 0.7,
            color: Colors.amber.shade700,
          ),
        ),
      ],
    );
  }
  
  /// Construit l'indicateur d'erreur
  Widget _buildErrorIndicator() {
    return Icon(
      Icons.sync_problem,
      size: size,
      color: Colors.red.shade700,
    );
  }
}
