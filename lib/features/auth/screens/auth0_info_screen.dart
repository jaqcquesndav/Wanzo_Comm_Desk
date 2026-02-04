import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../../constants/constants.dart';
import '../../../core/platform/platform_service.dart';
import '../bloc/auth_bloc.dart';

/// Écran d'information sur la transition vers Auth0
/// Adapté pour desktop et mobile
class Auth0InfoScreen extends StatelessWidget {
  static const String routeName = '/auth0_info';
  final PlatformService _platform = PlatformService.instance;

  Auth0InfoScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final isDesktop = screenSize.width >= _platform.desktopMinWidth;
    final isTablet = screenSize.width >= _platform.tabletMinWidth && !isDesktop;

    return BlocListener<AuthBloc, AuthState>(
      listener: (context, state) {
        if (state is AuthAuthenticated) {
          context.go('/dashboard');
        } else if (state is AuthFailure) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Échec de l\'authentification: ${state.message}'),
              backgroundColor: Colors.red,
            ),
          );
        }
      },
      child:
          isDesktop
              ? _buildDesktopLayout(context)
              : _buildMobileLayout(context, isTablet),
    );
  }

  Widget _buildDesktopLayout(BuildContext context) {
    return Scaffold(
      body: Row(
        children: [
          // Panneau gauche avec branding
          Expanded(
            flex: 5,
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    WanzoColors.primary,
                    WanzoColors.primary.withValues(alpha: 0.85),
                  ],
                ),
              ),
              child: Stack(
                children: [
                  // Cercles décoratifs
                  Positioned(
                    top: -80,
                    left: -80,
                    child: Container(
                      width: 250,
                      height: 250,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white.withValues(alpha: 0.1),
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: -100,
                    right: -100,
                    child: Container(
                      width: 350,
                      height: 350,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white.withValues(alpha: 0.08),
                      ),
                    ),
                  ),
                  // Contenu
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.all(48),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(24),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(24),
                            ),
                            child: Image.asset(
                              'assets/images/logo.jpg',
                              height: 100,
                              errorBuilder: (_, __, ___) {
                                return const Icon(
                                  Icons.storefront,
                                  size: 100,
                                  color: Colors.white,
                                );
                              },
                            ),
                          ),
                          const SizedBox(height: 32),
                          const Text(
                            'WANZO',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 48,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 4,
                            ),
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            'Gestion commerciale intelligente',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 20,
                            ),
                          ),
                          const SizedBox(height: 48),
                          // Features list
                          _buildFeatureItem(
                            Icons.security,
                            'Sécurité renforcée',
                          ),
                          _buildFeatureItem(
                            Icons.cloud_sync,
                            'Synchronisation cloud',
                          ),
                          _buildFeatureItem(Icons.devices, 'Multi-plateforme'),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Panneau droit avec formulaire
          Expanded(
            flex: 4,
            child: Container(
              color: Colors.white,
              padding: const EdgeInsets.all(48),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
                    constraints: const BoxConstraints(maxWidth: 400),
                    child: Column(
                      children: [
                        const Icon(
                          Icons.lock_outline,
                          size: 64,
                          color: WanzoColors.primary,
                        ),
                        const SizedBox(height: 24),
                        const Text(
                          'Connexion sécurisée',
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Authentification sécurisée avec Auth0 pour protéger vos données professionnelles.',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey[600],
                            height: 1.5,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 48),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: () {
                              context.read<AuthBloc>().add(
                                const AuthLoginWithAuth0Requested(),
                              );
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: WanzoColors.primary,
                              padding: const EdgeInsets.symmetric(vertical: 20),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.login, color: Colors.white),
                                SizedBox(width: 12),
                                Text(
                                  'Se connecter',
                                  style: TextStyle(
                                    fontSize: 18,
                                    color: Colors.white,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),
                        TextButton.icon(
                          onPressed: () => context.go('/onboarding'),
                          icon: const Icon(Icons.arrow_back),
                          label: const Text('Retour à la présentation'),
                        ),
                        const SizedBox(height: 32),
                        const Divider(),
                        const SizedBox(height: 16),
                        // Bouton bypass pour le développement
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.orange.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: Colors.orange.withValues(alpha: 0.3),
                            ),
                          ),
                          child: Column(
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    Icons.developer_mode,
                                    color: Colors.orange[700],
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Mode Développement',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: Colors.orange[700],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              SizedBox(
                                width: double.infinity,
                                child: OutlinedButton.icon(
                                  onPressed: () {
                                    context.read<AuthBloc>().add(
                                      const AuthLoginWithDemoAccountRequested(),
                                    );
                                  },
                                  icon: const Icon(Icons.skip_next),
                                  label: const Text(
                                    'Bypass Auth0 (Compte Démo)',
                                  ),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: Colors.orange[700],
                                    side: BorderSide(
                                      color: Colors.orange[700]!,
                                    ),
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 12,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeatureItem(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: Colors.white, size: 20),
          ),
          const SizedBox(width: 16),
          Text(text, style: const TextStyle(color: Colors.white, fontSize: 16)),
        ],
      ),
    );
  }

  Widget _buildMobileLayout(BuildContext context, bool isTablet) {
    return Scaffold(
      appBar: AppBar(title: const Text('Authentification'), centerTitle: true),
      body: Center(
        child: SingleChildScrollView(
          padding: EdgeInsets.all(isTablet ? 48 : 24),
          child: Container(
            constraints: BoxConstraints(
              maxWidth: isTablet ? 500 : double.infinity,
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: WanzoColors.primary.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Image.asset(
                    'assets/images/logo.jpg',
                    height: isTablet ? 120 : 100,
                    errorBuilder: (_, __, ___) {
                      return Icon(
                        Icons.security,
                        size: isTablet ? 120 : 100,
                        color: WanzoColors.primary,
                      );
                    },
                  ),
                ),
                SizedBox(height: isTablet ? 48 : 32),
                Text(
                  'Authentification sécurisée',
                  style: TextStyle(
                    fontSize: isTablet ? 28 : WanzoTypography.fontSizeLg,
                    fontWeight: WanzoTypography.fontWeightBold,
                  ),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: isTablet ? 24 : 16),
                Text(
                  'Pour votre sécurité, vous serez redirigé vers une page d\'authentification sécurisée où vous pourrez vous connecter ou créer un compte.',
                  style: TextStyle(
                    fontSize: isTablet ? 18 : WanzoTypography.fontSizeMd,
                    color: Colors.grey[600],
                    height: 1.5,
                  ),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: isTablet ? 48 : 32),
                SizedBox(
                  width: isTablet ? 300 : double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      context.read<AuthBloc>().add(
                        const AuthLoginWithAuth0Requested(),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size(double.infinity, 56),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(
                          WanzoBorderRadius.md,
                        ),
                      ),
                    ),
                    child: const Text(
                      'Continuer',
                      style: TextStyle(
                        fontSize: WanzoTypography.fontSizeMd,
                        fontWeight: WanzoTypography.fontWeightMedium,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                TextButton(
                  onPressed: () => context.go('/onboarding'),
                  child: const Text(
                    'Retour',
                    style: TextStyle(
                      fontSize: WanzoTypography.fontSizeMd,
                      fontWeight: WanzoTypography.fontWeightMedium,
                    ),
                  ),
                ),
                const SizedBox(height: 32),
                const Divider(),
                const SizedBox(height: 16),
                // Bouton bypass pour le développement
                Container(
                  width: isTablet ? 300 : double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.orange.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.orange.withValues(alpha: 0.3)),
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.developer_mode, color: Colors.orange[700]),
                          const SizedBox(width: 8),
                          Text(
                            'Mode Développement',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.orange[700],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: () {
                            context.read<AuthBloc>().add(
                              const AuthLoginWithDemoAccountRequested(),
                            );
                          },
                          icon: const Icon(Icons.skip_next),
                          label: const Text('Bypass Auth0 (Compte Démo)'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.orange[700],
                            side: BorderSide(color: Colors.orange[700]!),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
