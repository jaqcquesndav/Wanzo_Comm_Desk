import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../bloc/auth_bloc.dart';
import '../widgets/join_code_form.dart';

/// Écran d'un compte sans entreprise.
///
/// Deux situations y mènent : l'entreprise vient d'être créée et ses données
/// sont encore en route (synchronisation), ou le compte n'appartient à aucune
/// entreprise. Dans le second cas, l'utilisateur saisit le code reçu de son
/// administrateur : une demande est envoyée et son écran d'attente s'affiche.
///
/// Les vérifications automatiques sont espacées et bornées (jamais une
/// boucle) ; le bouton « Réessayer » en relance une à la demande.
class SyncPendingScreen extends StatefulWidget {
  /// Délais des vérifications automatiques, comptés depuis la précédente.
  final List<Duration> autoRetryDelays;

  const SyncPendingScreen({
    super.key,
    this.autoRetryDelays = const [
      Duration(seconds: 5),
      Duration(seconds: 10),
      Duration(seconds: 20),
      Duration(seconds: 40),
      Duration(seconds: 80),
      Duration(minutes: 3),
    ],
  });

  @override
  State<SyncPendingScreen> createState() => _SyncPendingScreenState();
}

class _SyncPendingScreenState extends State<SyncPendingScreen> {
  Timer? _retryTimer;
  int _retryIndex = 0;

  bool get _exhausted => _retryIndex >= widget.autoRetryDelays.length;

  @override
  void initState() {
    super.initState();
    _scheduleNext();
  }

  @override
  void dispose() {
    _retryTimer?.cancel();
    super.dispose();
  }

  void _scheduleNext() {
    _retryTimer?.cancel();
    if (_exhausted) {
      if (mounted) setState(() {});
      return;
    }
    final delay = widget.autoRetryDelays[_retryIndex++];
    _retryTimer = Timer(delay, () {
      if (!mounted) return;
      context.read<AuthBloc>().add(const AuthRefreshProfileRequested());
      _scheduleNext();
    });
  }

  void _manualRetry() {
    _retryIndex = 0;
    context.read<AuthBloc>().add(const AuthRefreshProfileRequested());
    _scheduleNext();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: SafeArea(
        // Affiche juste apres la premiere connexion : il doit tenir en
        // paysage et avec une grande police, donc defiler plutot que deborder.
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: BlocBuilder<AuthBloc, AuthState>(
                builder: (context, state) {
                  final message = state is AuthSyncPending
                      ? state.message ?? 'Synchronisation en cours...'
                      : 'Synchronisation en cours...';
                  final busy = state is AuthJoinBusinessUnitInProgress;

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Icon(Icons.sync, size: 64, color: Colors.orange),
                      const SizedBox(height: 20),
                      Text(
                        'Configuration en cours',
                        style: theme.textTheme.headlineSmall
                            ?.copyWith(fontWeight: FontWeight.bold),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        message,
                        style: theme.textTheme.bodyLarge
                            ?.copyWith(color: Colors.grey[600]),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      if (!_exhausted)
                        const Center(child: CircularProgressIndicator())
                      else
                        Text(
                          'La configuration prend plus de temps que prévu.',
                          style: theme.textTheme.bodySmall
                              ?.copyWith(color: Colors.red[400]),
                          textAlign: TextAlign.center,
                        ),
                      const SizedBox(height: 16),
                      OutlinedButton.icon(
                        onPressed: busy ? null : _manualRetry,
                        icon: const Icon(Icons.refresh),
                        label: const Text('Réessayer'),
                      ),
                      const SizedBox(height: 28),
                      const Divider(),
                      const SizedBox(height: 16),
                      Text(
                        'Vous rejoignez une entreprise existante ?',
                        style: theme.textTheme.titleMedium,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        "Saisissez le code reçu de votre administrateur. Il "
                        "recevra votre demande et vous donnera accès.",
                        style: theme.textTheme.bodyMedium,
                      ),
                      const SizedBox(height: 12),
                      const JoinCodeForm(),
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
