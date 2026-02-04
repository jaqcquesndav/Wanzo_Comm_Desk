// filepath: c:\Users\DevSpace\Flutter\wanzo\lib\features\auth\widgets\auth_error_dialog.dart

import 'package:flutter/material.dart';

/// Boîte de dialogue pour afficher une erreur d'authentification
class AuthErrorDialog extends StatelessWidget {
  /// Message d'erreur
  final String message;
  
  /// Fonction appelée lors de la nouvelle tentative
  final VoidCallback? onRetry;
  
  /// Constructeur
  const AuthErrorDialog({
    super.key,
    required this.message,
    this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(
        children: [
          Icon(
            Icons.error_outline,
            color: Theme.of(context).colorScheme.error,
          ),
          const SizedBox(width: 8.0),
          const Text('Erreur d\'authentification'),
        ],
      ),
      content: Text(
        message.contains('Exception:') ? message.split('Exception:').last.trim() : message,
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Fermer'),
        ),
        if (onRetry != null)
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              onRetry!();
            },
            child: const Text('Réessayer'),
          ),
      ],
    );
  }
}
