import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../subscription/widgets/subscription_banner_overlay.dart'
    show wanzoLandProfileUrl;
import '../bloc/auth_bloc.dart';
import '../widgets/join_code_form.dart';

/// Message affiché en tête à un compte retiré de son entreprise.
const String kRevokedFromCompanyMessage =
    'Vous ne faites plus partie de cette entreprise. Vous pouvez rejoindre '
    'une autre entreprise avec un code, ou créer la vôtre sur Wanzo Land.';

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

  Future<void> _openWanzoLand() async {
    try {
      await launchUrl(
        Uri.parse(wanzoLandProfileUrl),
        mode: LaunchMode.externalApplication,
      );
    } catch (_) {}
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
                  // Compte retiré de son entreprise : pas de « configuration
                  // en cours », un message sobre puis les issues.
                  final revoked = state is AuthSyncPending && state.revoked;

                  if (revoked) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Icon(
                          Icons.group_off_outlined,
                          size: 56,
                          color: theme.colorScheme.primary,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          kRevokedFromCompanyMessage,
                          key: const Key('revoked_from_company_message'),
                          style: theme.textTheme.bodyLarge,
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 8),
                        Center(
                          child: TextButton.icon(
                            onPressed: () => _openWanzoLand(),
                            icon: const Icon(Icons.open_in_new),
                            label: const Text('Ouvrir Wanzo Land'),
                          ),
                        ),
                        const SizedBox(height: 20),
                        const Divider(),
                        const SizedBox(height: 16),
                        Text(
                          'Rejoindre une entreprise',
                          style: theme.textTheme.titleMedium,
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Saisissez le code reçu de son administrateur.',
                          style: theme.textTheme.bodyMedium,
                        ),
                        const SizedBox(height: 12),
                        const JoinCodeForm(),
                        const SizedBox(height: 12),
                        Center(
                          child: TextButton.icon(
                            onPressed: busy ? null : _manualRetry,
                            icon: const Icon(Icons.refresh),
                            label: const Text('Vérifier à nouveau'),
                          ),
                        ),
                        const SizedBox(height: 12),
                        JoinAccountFooter(enabled: !busy),
                      ],
                    );
                  }

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
