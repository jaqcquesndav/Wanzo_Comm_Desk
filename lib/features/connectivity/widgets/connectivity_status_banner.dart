// filepath: c:\Users\DevSpace\Flutter\wanzo\lib\features\connectivity\widgets\connectivity_status_banner.dart

import 'package:flutter/material.dart';
import '../../../core/utils/connectivity_service.dart';

/// Widget affichant l'état de connectivité (en ligne/hors ligne)
class ConnectivityStatusBanner extends StatefulWidget {
  final bool showAlways;
  final double height;
  final Color onlineColor;
  final Color offlineColor;
  
  /// Constructeur
  const ConnectivityStatusBanner({
    super.key,
    this.showAlways = false,
    this.height = 25.0,
    this.onlineColor = Colors.green, // Will be replaced by theme color
    this.offlineColor = Colors.red, // Will be replaced by theme color
  });

  @override
  State<ConnectivityStatusBanner> createState() => _ConnectivityStatusBannerState();
}

class _ConnectivityStatusBannerState extends State<ConnectivityStatusBanner> {
  final ConnectivityService _connectivityService = ConnectivityService();
  bool _isConnected = true;
  bool _showBanner = false;

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    // Vérifier l'état initial
    _isConnected = _connectivityService.isConnected;
    _showBanner = !_isConnected || widget.showAlways;
      // S'abonner aux changements de connectivité
    _connectivityService.connectionStatus.addListener(() {
      if (mounted) {
        setState(() {
          _isConnected = _connectivityService.isConnected;
          _showBanner = !_isConnected || widget.showAlways;
        });
      }
    });
    
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    if (!_showBanner) {
      return const SizedBox.shrink();
    }

    final theme = Theme.of(context);
    final currentOnlineColor = _isConnected ? theme.colorScheme.secondary : theme.colorScheme.error;
    // Use widget.onlineColor and widget.offlineColor if they are not the default ones.
    final onlineColor = widget.onlineColor == Colors.green ? currentOnlineColor : widget.onlineColor;
    final offlineColor = widget.offlineColor == Colors.red ? theme.colorScheme.error : widget.offlineColor;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      height: widget.height,
      color: _isConnected ? onlineColor : offlineColor,
      child: Center(
        child: Text(
          _isConnected ? 'En ligne' : 'Hors ligne',
          style: TextStyle(
            color: _isConnected ? theme.colorScheme.onSecondary : theme.colorScheme.onError,
            fontWeight: FontWeight.bold,
            fontSize: 12,
          ),
        ),
      ),
    );
  }
}
