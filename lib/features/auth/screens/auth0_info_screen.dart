import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../../constants/constants.dart';
import '../bloc/auth_bloc.dart';

/// Écran d'information sur la transition vers Auth0
class Auth0InfoScreen extends StatelessWidget {
  static const String routeName = '/auth0_info';
  
  const Auth0InfoScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocListener<AuthBloc, AuthState>(
      listener: (context, state) {
        if (state is AuthAuthenticated) {
          // Redirection vers le dashboard en cas de succès
          context.go('/dashboard');
        } else if (state is AuthFailure) {
          // Affichage d'un message d'erreur en cas d'échec
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Échec de l\'authentification: ${state.message}'),
              backgroundColor: Colors.red,
            ),
          );
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Authentification'),
        ),
        body: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Image.asset(
                'assets/images/logo.jpg',
                height: 100,
                errorBuilder: (_, __, ___) {
                  return const Icon(
                    Icons.security,
                    size: 100,
                    color: WanzoColors.primary,
                  );
                },
              ),
              const SizedBox(height: 32),
              const Text(
                'Authentification sécurisée avec Auth0',
                style: TextStyle(
                  fontSize: WanzoTypography.fontSizeLg,
                  fontWeight: WanzoTypography.fontWeightBold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              const Text(
                'Pour votre sécurité, vous serez redirigé vers une page d\'authentification sécurisée où vous pourrez vous connecter ou créer un compte.',
                style: TextStyle(
                  fontSize: WanzoTypography.fontSizeMd,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: () {
                  // Lancer l'authentification Auth0 directement depuis cet écran
                  context.read<AuthBloc>().add(const AuthLoginWithAuth0Requested());
                },
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 50),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(WanzoBorderRadius.md),
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
            ],
          ),
        ),
      ),
    );
  }
}
