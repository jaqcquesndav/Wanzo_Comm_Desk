// filepath: c:\Users\DevSpace\Flutter\wanzo\lib\features\connectivity\widgets\offline_auth_banner.dart

import 'package:flutter/material.dart';
import '../../../constants/constants.dart';

/// Widget affichant une bannière pour l'authentification hors ligne
class OfflineAuthBanner extends StatelessWidget {
  /// Indique si l'authentification hors ligne est disponible
  final bool offlineAuthAvailable;
  
  /// Constructeur
  const OfflineAuthBanner({
    super.key,
    required this.offlineAuthAvailable,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: WanzoSpacing.md, horizontal: WanzoSpacing.md),
      padding: const EdgeInsets.all(WanzoSpacing.md),
      decoration: BoxDecoration(
        color: offlineAuthAvailable 
            ? Colors.amber.shade100 
            : Colors.red.shade100,
        borderRadius: BorderRadius.circular(WanzoBorderRadius.md),
        border: Border.all(
          color: offlineAuthAvailable 
              ? Colors.amber.shade700 
              : Colors.red.shade700,
        ),
      ),
      child: Row(
        children: [
          Icon(
            offlineAuthAvailable
                ? Icons.wifi_off
                : Icons.signal_wifi_connected_no_internet_4_outlined,
            color: offlineAuthAvailable
                ? Colors.amber.shade800
                : Colors.red.shade800,
          ),
          const SizedBox(width: WanzoSpacing.md),
          Expanded(
            child: Text(
              offlineAuthAvailable
                  ? 'Vous êtes hors ligne. Connexion possible avec vos identifiants sauvegardés.'
                  : 'Vous êtes hors ligne. La connexion n\'est pas possible sans accès Internet.',
              style: TextStyle(
                color: offlineAuthAvailable
                    ? Colors.amber.shade800
                    : Colors.red.shade800,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
