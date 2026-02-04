import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:wanzo/constants/constants.dart';
import 'package:wanzo/core/platform/platform_service.dart';
import '../bloc/auth_bloc.dart';

/// Écran d'accueil affiché au démarrage de l'application
/// Optimisé pour être rapide quand l'utilisateur est déjà connecté
/// Adapté pour desktop et mobile
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
  bool _isQuickStart = false;
  final PlatformService _platform = PlatformService.instance;

  @override
  void initState() {
    super.initState();

    final currentState = context.read<AuthBloc>().state;
    _isQuickStart = currentState is AuthAuthenticated;

    final animationDuration =
        _isQuickStart
            ? const Duration(milliseconds: 300)
            : const Duration(milliseconds: 800);

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

    if (_isQuickStart) {
      _navigateToDashboard();
    } else {
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
    final screenSize = MediaQuery.of(context).size;
    final isDesktop = screenSize.width >= _platform.desktopMinWidth;
    final isTablet = screenSize.width >= _platform.tabletMinWidth && !isDesktop;

    // Tailles adaptatives
    final logoSize = isDesktop ? 120.0 : (isTablet ? 100.0 : 80.0);
    final titleSize =
        isDesktop ? 42.0 : (isTablet ? 36.0 : WanzoTypography.fontSizeXxl);
    final subtitleSize = isDesktop ? 18.0 : WanzoTypography.fontSizeMd;

    return BlocListener<AuthBloc, AuthState>(
      listener: (context, state) {
        if (_hasNavigated) return;

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
              child: Container(
                constraints: BoxConstraints(
                  maxWidth: isDesktop ? 600 : double.infinity,
                ),
                padding: EdgeInsets.symmetric(horizontal: isDesktop ? 48 : 24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    FadeTransition(
                      opacity: _opacityAnimation,
                      child: ScaleTransition(
                        scale: _scaleAnimation,
                        child: Column(
                          children: [
                            // Logo adaptatif
                            Container(
                              padding: EdgeInsets.all(isDesktop ? 24 : 16),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(
                                  isDesktop ? 24 : 16,
                                ),
                              ),
                              child: Image.asset(
                                'assets/images/splash_logo.jpg',
                                height: logoSize,
                                color: Colors.white,
                                errorBuilder: (context, error, stackTrace) {
                                  return Image.asset(
                                    'assets/images/logo.jpg',
                                    height: logoSize,
                                    color: Colors.white,
                                    errorBuilder: (_, __, ___) {
                                      return Icon(
                                        Icons.storefront,
                                        size: logoSize,
                                        color: Colors.white,
                                      );
                                    },
                                  );
                                },
                              ),
                            ),
                            SizedBox(
                              height: isDesktop ? 32 : WanzoSpacing.base,
                            ),
                            Text(
                              'WANZO',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: titleSize,
                                fontWeight: WanzoTypography.fontWeightBold,
                                letterSpacing: isDesktop ? 4.0 : 2.0,
                              ),
                            ),
                            if (!_isQuickStart) ...[
                              SizedBox(
                                height: isDesktop ? 16 : WanzoSpacing.sm,
                              ),
                              Text(
                                isDesktop
                                    ? 'Solution de gestion commerciale pour entreprises'
                                    : 'Gestion simplifiée',
                                style: TextStyle(
                                  color: Colors.white70,
                                  fontSize: subtitleSize,
                                  fontWeight: WanzoTypography.fontWeightMedium,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ],
                            // Version desktop affiche plus d'infos
                            if (isDesktop && !_isQuickStart) ...[
                              const SizedBox(height: 48),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  _buildFeatureChip(Icons.inventory_2, 'Stock'),
                                  const SizedBox(width: 16),
                                  _buildFeatureChip(
                                    Icons.point_of_sale,
                                    'Ventes',
                                  ),
                                  const SizedBox(width: 16),
                                  _buildFeatureChip(
                                    Icons.analytics,
                                    'Analytics',
                                  ),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                    if (!_isQuickStart) ...[
                      SizedBox(height: isDesktop ? 48 : WanzoSpacing.xxl),
                      FadeTransition(
                        opacity: _opacityAnimation,
                        child: const CircularProgressIndicator(
                          valueColor: AlwaysStoppedAnimation<Color>(
                            Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildFeatureChip(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white, size: 18),
          const SizedBox(width: 8),
          Text(
            label,
            style: const TextStyle(color: Colors.white, fontSize: 14),
          ),
        ],
      ),
    );
  }
}
