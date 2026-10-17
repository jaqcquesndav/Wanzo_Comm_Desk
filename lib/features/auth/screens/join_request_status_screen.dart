import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../bloc/auth_bloc.dart';
import '../widgets/join_code_form.dart';

/// Écran d'un compte sans entreprise dont la demande de rattachement attend
/// l'accord de l'administrateur, ou vient d'être refusée.
///
/// Le statut est vérifié au retour au premier plan, par le bouton
/// « Vérifier », et par quelques vérifications espacées (bornées, jamais une
/// boucle). Aide et déconnexion restent toujours accessibles.
class JoinRequestStatusScreen extends StatefulWidget {
  /// Délais des vérifications automatiques, comptés depuis la précédente.
  final List<Duration> autoCheckDelays;

  const JoinRequestStatusScreen({
    super.key,
    this.autoCheckDelays = const [
      Duration(seconds: 30),
      Duration(minutes: 1),
      Duration(minutes: 2),
      Duration(minutes: 5),
    ],
  });

  @override
  State<JoinRequestStatusScreen> createState() =>
      _JoinRequestStatusScreenState();
}

class _JoinRequestStatusScreenState extends State<JoinRequestStatusScreen>
    with WidgetsBindingObserver {
  Timer? _timer;
  int _nextDelay = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _scheduleNext();
  }

  @override
  void dispose() {
    _timer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _check(silent: true);
  }

  void _scheduleNext() {
    _timer?.cancel();
    if (_nextDelay >= widget.autoCheckDelays.length) return;
    final delay = widget.autoCheckDelays[_nextDelay++];
    _timer = Timer(delay, () {
      if (!mounted) return;
      _check(silent: true);
      _scheduleNext();
    });
  }

  void _check({required bool silent}) {
    final s = context.read<AuthBloc>().state;
    if (s is AuthJoinRequestState && s.request.isPending) {
      context.read<AuthBloc>().add(AuthJoinRequestCheckRequested(silent: silent));
    }
  }

  Future<void> _confirmCancel() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Annuler la demande ?'),
        content: const Text(
          "L'administrateur ne la verra plus. Vous pourrez saisir un autre code ensuite.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Garder'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Annuler la demande'),
          ),
        ],
      ),
    );
    if (ok == true && mounted) {
      context.read<AuthBloc>().add(const AuthJoinRequestCancelRequested());
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: BlocBuilder<AuthBloc, AuthState>(
                buildWhen: (_, s) => s is AuthJoinRequestState,
                builder: (context, state) {
                  if (state is! AuthJoinRequestState) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  final body = state.request.isRefused
                      ? _RefusedView(state: state)
                      : _PendingView(
                          state: state,
                          onCheck: () => _check(silent: false),
                          onCancel: _confirmCancel,
                        );
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      body,
                      const SizedBox(height: 24),
                      JoinAccountFooter(enabled: !state.busy),
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

String _formatDate(DateTime? d) {
  if (d == null) return '';
  String two(int v) => v.toString().padLeft(2, '0');
  return '${two(d.day)}/${two(d.month)}/${d.year} à ${two(d.hour)}h${two(d.minute)}';
}

class _PendingView extends StatelessWidget {
  final AuthJoinRequestState state;
  final VoidCallback onCheck;
  final VoidCallback onCancel;

  const _PendingView({
    required this.state,
    required this.onCheck,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final request = state.request;
    final sent = _formatDate(request.createdAt);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Icon(Icons.hourglass_top_rounded, size: 72, color: theme.colorScheme.primary),
        const SizedBox(height: 20),
        Text(
          'Demande envoyée à ${request.destinationLabel}',
          style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 12),
        Text(
          "En attente de l'accord de l'administrateur. Vous entrerez dans "
          "l'application dès qu'il aura accepté votre demande.",
          style: theme.textTheme.bodyLarge,
          textAlign: TextAlign.center,
        ),
        if (sent.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(
            'Envoyée le $sent',
            style: theme.textTheme.bodySmall,
            textAlign: TextAlign.center,
          ),
        ],
        if (state.notice != null) ...[
          const SizedBox(height: 16),
          _Notice(text: state.notice!),
        ],
        const SizedBox(height: 24),
        SizedBox(
          height: 48,
          child: FilledButton.icon(
            key: const Key('join_request_check'),
            onPressed: state.busy ? null : onCheck,
            icon: state.busy
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.refresh),
            label: const Text('Vérifier'),
          ),
        ),
        const SizedBox(height: 12),
        OutlinedButton(
          key: const Key('join_request_cancel'),
          onPressed: state.busy ? null : onCancel,
          child: const Text('Annuler la demande'),
        ),
      ],
    );
  }
}

class _RefusedView extends StatelessWidget {
  final AuthJoinRequestState state;

  const _RefusedView({required this.state});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final request = state.request;
    final reason = (request.reason ?? '').trim();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Icon(Icons.block, size: 72, color: theme.colorScheme.error),
        const SizedBox(height: 20),
        Text(
          'Demande refusée',
          style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 12),
        Text(
          "${request.destinationLabel} n'a pas accepté votre demande de rattachement.",
          style: theme.textTheme.bodyLarge,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Motif', style: theme.textTheme.labelLarge),
                const SizedBox(height: 4),
                Text(reason.isEmpty ? 'Aucun motif précisé.' : reason),
              ],
            ),
          ),
        ),
        if (state.notice != null) ...[
          const SizedBox(height: 12),
          _Notice(text: state.notice!),
        ],
        const SizedBox(height: 24),
        Text('Essayer avec un autre code', style: theme.textTheme.titleMedium),
        const SizedBox(height: 12),
        const JoinCodeForm(),
      ],
    );
  }
}

class _Notice extends StatelessWidget {
  final String text;

  const _Notice({required this.text});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline, color: scheme.primary),
          const SizedBox(width: 12),
          Expanded(child: Text(text)),
        ],
      ),
    );
  }
}

