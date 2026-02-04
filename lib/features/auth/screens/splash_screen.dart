import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart'; // Import go_router
import 'package:wanzo/constants/constants.dart';
import '../bloc/auth_bloc.dart';

/// Écran d'accueil affiché au démarrage de l'application
/// Optimisé pour être rapide quand l'utilisateur est déjà connecté
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _opacityAnimation;
  late Animation<double> _scaleAnimation;
  bool _hasNavigated = false;
  bool _isQuickStart = false; // Pour un démarrage rapide si déjà authentifié

  @override
  void initState() {
    super.initState();

    // Vérifier immédiatement l'état d'authentification actuel
    final currentState = context.read<AuthBloc>().state;
    _isQuickStart = currentState is AuthAuthenticated;

    // Si déjà authentifié, on fait une animation très courte
    final animationDuration =
        _isQuickStart
            ? const Duration(milliseconds: 300)
            : const Duration(milliseconds: 800);

    // Configuration des animations
    _controller = AnimationController(vsync: this, duration: animationDuration);

    _opacityAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.6, curve: Curves.easeIn),
      ),
    );

    _scaleAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.6, curve: Curves.easeOut),
      ),
    );

    _controller.forward();

    // Si déjà authentifié, naviguer immédiatement
    if (_isQuickStart) {
      _navigateToDashboard();
    } else {
      // Sinon, demander une vérification d'authentification
      context.read<AuthBloc>().add(const AuthCheckRequested());
    }
  }

  void _navigateToDashboard() {
    if (_hasNavigated || !mounted) return;
    _hasNavigated = true;

    // Délai minimal pour afficher le logo
    Future.delayed(const Duration(milliseconds: 200), () {
      if (mounted) {
        context.go('/dashboard');
      }
    });
  }

  void _navigateToOnboarding() {
    if (_hasNavigated || !mounted) return;
    _hasNavigated = true;

    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) {
        context.go('/onboarding');
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<AuthBloc, AuthState>(
      listener: (context, state) {
        if (_hasNavigated) return; // Éviter les navigations multiples

        if (state is AuthAuthenticated) {
          _navigateToDashboard();
        } else if (state is AuthUnauthenticated) {
          _navigateToOnboarding();
        }
      },
      child: Scaffold(
        backgroundColor: WanzoColors.primary,
        body: AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  FadeTransition(
                    opacity: _opacityAnimation,
                    child: ScaleTransition(
                      scale: _scaleAnimation,
                      child: Column(
                        children: [
                          // Logo de l'application
                          Image.asset(
                            'assets/images/splash_logo.jpg',
                            height: 80,
                            color: Colors.white,
                            errorBuilder: (context, error, stackTrace) {
                              return Image.asset(
                                'assets/images/logo.jpg',
                                height: 80,
                                color: Colors.white,
                                errorBuilder: (_, __, ___) {
                                  return const Icon(
                                    Icons.storefront,
                                    size: 80,
                                    color: Colors.white,
                                  );
                                },
                              );
                            },
                          ),
                          SizedBox(height: WanzoSpacing.base),
                          Text(
                            'WANZO',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: WanzoTypography.fontSizeXxl,
                              fontWeight: WanzoTypography.fontWeightBold,
                              letterSpacing: 2.0,
                            ),
                          ),
                          // Afficher "Gestion simplifiée" seulement si pas en mode quick start
                          if (!_isQuickStart) ...[
                            SizedBox(height: WanzoSpacing.sm),
                            Text(
                              'Gestion simplifiée',
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: WanzoTypography.fontSizeMd,
                                fontWeight: WanzoTypography.fontWeightMedium,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  // Afficher l'indicateur de chargement seulement si pas en mode quick start
                  if (!_isQuickStart) ...[
                    const SizedBox(height: WanzoSpacing.xxl),
                    FadeTransition(
                      opacity: _opacityAnimation,
                      child: const CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    ),
                  ],
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
