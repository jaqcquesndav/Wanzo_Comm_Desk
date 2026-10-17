import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../bloc/auth_bloc.dart';
import '../widgets/join_code_form.dart';

/// Écran pour saisir le code d'une unité d'affaires.
///
/// Affiché quand un utilisateur non administrateur n'a pas encore d'unité.
/// Un compte déjà membre change d'unité tout de suite ; un compte sans
/// entreprise envoie une demande que l'administrateur accepte.
class JoinBusinessUnitScreen extends StatelessWidget {
  const JoinBusinessUnitScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: BlocBuilder<AuthBloc, AuthState>(
                buildWhen: (a, b) =>
                    (a is AuthJoinBusinessUnitInProgress) !=
                    (b is AuthJoinBusinessUnitInProgress),
                builder: (context, state) {
                  final busy = state is AuthJoinBusinessUnitInProgress;
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Icon(Icons.business, size: 72, color: theme.colorScheme.primary),
                      const SizedBox(height: 20),
                      Text(
                        "Rejoindre une unité d'affaires",
                        style: theme.textTheme.headlineSmall
                            ?.copyWith(fontWeight: FontWeight.bold),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Saisissez le code fourni par votre administrateur.',
                        style: theme.textTheme.bodyLarge,
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 24),
                      const JoinCodeForm(submitLabel: 'Rejoindre'),
                      const SizedBox(height: 24),
                      JoinAccountFooter(enabled: !busy),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}
