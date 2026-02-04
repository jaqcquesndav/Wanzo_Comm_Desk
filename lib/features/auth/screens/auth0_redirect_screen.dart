import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../bloc/auth_bloc.dart';
import '../../../constants/constants.dart';

/// Écran de transition qui lance automatiquement l'authentification Auth0
class Auth0RedirectScreen extends StatefulWidget {
  static const String routeName = '/auth0_redirect';

  const Auth0RedirectScreen({super.key});

  @override
  State<Auth0RedirectScreen> createState() => _Auth0RedirectScreenState();
}

class _Auth0RedirectScreenState extends State<Auth0RedirectScreen> {
  bool _isRedirecting = false;

  @override
  void initState() {
    super.initState();
    // Attendre un court instant avant de lancer l'authentification
    // pour permettre à l'écran de s'afficher
    Future.delayed(const Duration(milliseconds: 300), _initiateAuth0Login);
  }

  /// Lance le processus d'authentification Auth0
  Future<void> _initiateAuth0Login() async {
    if (_isRedirecting) return;
    
    setState(() {
      _isRedirecting = true;
    });
    
    try {
      // Utiliser le bloc pour lancer l'authentification Auth0
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
          
          // Retour à l'écran d'onboarding en cas d'échec
          context.go('/onboarding');
        }
      },
      child: Scaffold(
        backgroundColor: WanzoColors.primary,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Logo
              Image.asset(
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
              ),
              const SizedBox(height: 32),
              const Text(
                'Redirection vers Auth0...',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: WanzoTypography.fontSizeLg,
                  fontWeight: WanzoTypography.fontWeightMedium,
                ),
              ),
              const SizedBox(height: 24),
              const CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
