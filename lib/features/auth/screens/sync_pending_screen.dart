import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:wanzo/constants/constants.dart';
import 'package:wanzo/core/platform/platform_service.dart';
import '../bloc/auth_bloc.dart';

/// Écran affiché quand la synchronisation Kafka est en cours (Cas 3 de /auth/me)
///
/// L'utilisateur vient de s'inscrire et ses données entreprise
/// ne sont pas encore disponibles dans le service commercial.
/// Le système réessaie automatiquement toutes les 5 secondes (max 30 tentatives).
class SyncPendingScreen extends StatefulWidget {
  const SyncPendingScreen({super.key});

  @override
  State<SyncPendingScreen> createState() => _SyncPendingScreenState();
}

class _SyncPendingScreenState extends State<SyncPendingScreen>
    with SingleTickerProviderStateMixin {
  Timer? _retryTimer;
  int _retryCount = 0;
  static const int _maxRetries = 30; // 30 x 5s = 2.5 minutes
  static const Duration _retryInterval = Duration(seconds: 5);
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
    _startAutoRetry();
  }

  void _startAutoRetry() {
    _retryTimer = Timer.periodic(_retryInterval, (timer) {
      if (_retryCount >= _maxRetries) {
        timer.cancel();
        return;
      }
      _retryCount++;
      context.read<AuthBloc>().add(const AuthRefreshProfileRequested());
    });
  }

  void _manualRetry() {
    _retryCount = 0;
    context.read<AuthBloc>().add(const AuthRefreshProfileRequested());
    // Relancer le timer si arrêté
    if (_retryTimer == null || !_retryTimer!.isActive) {
      _startAutoRetry();
    }
  }

  @override
  void dispose() {
    _retryTimer?.cancel();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final platform = PlatformService.instance;
    final isDesktop = screenSize.width >= platform.desktopMinWidth;

    return BlocBuilder<AuthBloc, AuthState>(
      builder: (context, state) {
        final message = state is AuthSyncPending ? state.message : null;

        return Scaffold(
          backgroundColor: WanzoColors.primary,
          body: Center(
            child: Container(
              constraints: BoxConstraints(
                maxWidth: isDesktop ? 500 : double.infinity,
              ),
              padding: EdgeInsets.symmetric(
                horizontal: isDesktop ? 48 : 24,
                vertical: 32,
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Icône animée
                  AnimatedBuilder(
                    animation: _pulseController,
                    builder: (context, child) {
                      return Transform.scale(
                        scale: 0.9 + (_pulseController.value * 0.1),
                        child: Container(
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(24),
                          ),
                          child: const Icon(
                            Icons.cloud_sync,
                            size: 80,
                            color: Colors.white,
                          ),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 32),

                  // Titre
                  Text(
                    'Configuration en cours',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: isDesktop ? 28 : 24,
                      fontWeight: WanzoTypography.fontWeightBold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),

                  // Message
                  Text(
                    message ??
                        'Vos données entreprise sont en cours de synchronisation. '
                            'Cela peut prendre quelques instants...',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: isDesktop ? 16 : 14,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 32),

                  // Progress indicator
                  const CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                  const SizedBox(height: 16),

                  // Compteur de tentatives
                  Text(
                    'Tentative $_retryCount / $_maxRetries',
                    style: TextStyle(
                      color: Colors.white54,
                      fontSize: isDesktop ? 14 : 12,
                    ),
                  ),
                  const SizedBox(height: 32),

                  // Bouton réessayer
                  OutlinedButton.icon(
                    onPressed: _manualRetry,
                    icon: const Icon(Icons.refresh, color: Colors.white),
                    label: Text(
                      'Réessayer manuellement',
                      style: const TextStyle(color: Colors.white),
                    ),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Colors.white54),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 12,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Bouton déconnexion
                  TextButton.icon(
                    onPressed: () {
                      context.read<AuthBloc>().add(const AuthLogoutRequested());
                    },
                    icon: const Icon(Icons.logout, color: Colors.white54),
                    label: Text(
                      'Se déconnecter',
                      style: const TextStyle(color: Colors.white54),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
