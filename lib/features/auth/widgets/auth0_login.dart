import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../bloc/auth_bloc.dart';
import '../services/auth0_service.dart';
import '../services/offline_auth_service.dart'; // Import OfflineAuthService
import '../../../core/utils/connectivity_service.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart'; // Import FlutterSecureStorage
import '../../../core/services/database_service.dart'; // Import DatabaseService

/// Widget pour gérer la connexion avec Auth0
class Auth0Login extends StatefulWidget {
  final Function(String, String)? onDemoLogin;

  const Auth0Login({super.key, this.onDemoLogin});

  @override
  State<Auth0Login> createState() => _Auth0LoginState();
}

class _Auth0LoginState extends State<Auth0Login> {
  final ConnectivityService _connectivityService = ConnectivityService();
  bool _offlineAuthAvailable = false;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _checkOfflineAuthAvailability();
  }

  /// Vérifie si l'authentification hors ligne est disponible
  Future<void> _checkOfflineAuthAvailability() async {
    final connectivityService = ConnectivityService();
    final databaseService = DatabaseService();
    final secureStorage = const FlutterSecureStorage();

    final offlineAuthServiceInstance = OfflineAuthService(
      secureStorage: secureStorage,
      databaseService: databaseService,
      connectivityService: connectivityService,
    );
    final auth0Service = Auth0Service(offlineAuthService: offlineAuthServiceInstance);
    await auth0Service.init();

    final isAvailable = await offlineAuthServiceInstance.canLoginOffline();

    if (mounted) {
      setState(() {
        _offlineAuthAvailable = isAvailable;
      });
    }
  }

  /// Lance le processus d'authentification
  Future<void> _performAuth0Login() async {
    if (_isLoading) return;
    
    setState(() {
      _isLoading = true;
    });
    
    try {
      context.read<AuthBloc>().add(const AuthLoginWithAuth0Requested());
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur: $e')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isConnected = _connectivityService.isConnected;
    
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Bannière de statut hors ligne (si déconnecté)
        if (!isConnected)
          Container(
            margin: const EdgeInsets.only(bottom: 16),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: _offlineAuthAvailable ? Colors.amber.shade100 : Colors.red.shade100,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: _offlineAuthAvailable ? Colors.amber.shade700 : Colors.red.shade700,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.wifi_off,
                  color: _offlineAuthAvailable ? Colors.amber.shade800 : Colors.red.shade800,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    _offlineAuthAvailable
                        ? 'Mode hors ligne: connexion possible avec vos identifiants sauvegardés'
                        : 'Mode hors ligne: connexion impossible sans accès Internet',
                    style: TextStyle(
                      color: _offlineAuthAvailable ? Colors.amber.shade800 : Colors.red.shade800,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),        // Bouton de connexion Auth0 ou hors ligne avec expérience intégrée
        ElevatedButton.icon(
          onPressed: (!isConnected && !_offlineAuthAvailable) || _isLoading
              ? null // Désactivé si hors ligne sans authentification disponible
              : _performAuth0Login,
          icon: Icon(isConnected ? Icons.login : Icons.offline_bolt),
          label: Text(isConnected ? 'Se connecter' : 'Connexion hors ligne'),
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
            minimumSize: const Size(double.infinity, 48),
          ),
        ),
        
        if (isConnected) const SizedBox(height: 16),
        
        // Option de démonstration (visible uniquement en mode connecté)
        if (isConnected)
          TextButton(
            onPressed: () {
              if (widget.onDemoLogin != null) {
                widget.onDemoLogin!('test@wanzo.com', 'password');
              }
            },
            child: const Text('Utiliser le compte de démonstration'),
          ),
      ],
    );
  }
}
