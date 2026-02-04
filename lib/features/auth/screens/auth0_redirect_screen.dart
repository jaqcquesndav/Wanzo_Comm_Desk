import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../bloc/auth_bloc.dart';
import '../../../constants/constants.dart';
import '../../../core/platform/platform_service.dart';

/// Écran de transition qui lance automatiquement l'authentification Auth0
/// Adapté pour desktop et mobile
class Auth0RedirectScreen extends StatefulWidget {
  static const String routeName = '/auth0_redirect';

  const Auth0RedirectScreen({super.key});

  @override
  State<Auth0RedirectScreen> createState() => _Auth0RedirectScreenState();
}

class _Auth0RedirectScreenState extends State<Auth0RedirectScreen> {
  bool _isRedirecting = false;
  final PlatformService _platform = PlatformService.instance;

  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(milliseconds: 300), _initiateAuth0Login);
  }

  Future<void> _initiateAuth0Login() async {
    if (_isRedirecting) return;

    setState(() {
      _isRedirecting = true;
    });

    try {
      context.read<AuthBloc>().add(const AuthLoginWithAuth0Requested());
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur d\'authentification: $e'),
            backgroundColor: Colors.red,
          ),
        );

        setState(() {
          _isRedirecting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final isDesktop = screenSize.width >= _platform.desktopMinWidth;
    final logoSize = isDesktop ? 120.0 : 80.0;
    final fontSize = isDesktop ? 24.0 : WanzoTypography.fontSizeLg;

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
          context.go('/onboarding');
        }
      },
      child: Scaffold(
        backgroundColor: WanzoColors.primary,
        body: Center(
          child: Container(
            constraints: BoxConstraints(
              maxWidth: isDesktop ? 500 : double.infinity,
            ),
            padding: EdgeInsets.all(isDesktop ? 48 : 24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Logo avec container décoratif sur desktop
                if (isDesktop)
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: _buildLogo(logoSize),
                  )
                else
                  _buildLogo(logoSize),
                SizedBox(height: isDesktop ? 48 : 32),
                Text(
                  isDesktop
                      ? 'Connexion en cours...'
                      : 'Redirection vers Auth0...',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: fontSize,
                    fontWeight: WanzoTypography.fontWeightMedium,
                  ),
                ),
                if (isDesktop) ...[
                  const SizedBox(height: 12),
                  Text(
                    'Vous allez être redirigé vers la page d\'authentification sécurisée',
                    style: TextStyle(color: Colors.white70, fontSize: 16),
                    textAlign: TextAlign.center,
                  ),
                ],
                SizedBox(height: isDesktop ? 48 : 24),
                SizedBox(
                  width: isDesktop ? 48 : 36,
                  height: isDesktop ? 48 : 36,
                  child: const CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    strokeWidth: 3,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLogo(double size) {
    return Image.asset(
      'assets/images/logo.jpg',
      height: size,
      color: Colors.white,
      errorBuilder: (_, __, ___) {
        return Icon(Icons.storefront, size: size, color: Colors.white);
      },
    );
  }
}
