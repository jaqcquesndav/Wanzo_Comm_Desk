import 'package:flutter/material.dart';

import '../../../core/services/api_client.dart';

/// Message affiché quand une invitation attend ce compte mais que son email
/// n'est pas encore confirmé (le rattachement l'exige).
const String kConfirmEmailMessage =
    'Confirmez votre adresse email : ouvrez le mail de confirmation reçu, '
    'puis touchez Vérifier.';

const String kConfirmEmailHint = '(cela peut prendre quelques secondes)';

/// Le serveur signale-t-il une invitation ou une demande qui attend la
/// confirmation de l'email de ce compte ? GET auth/pending-invitation,
/// champ `needsEmailConfirmation` (le serveur fait foi, jamais le profil
/// local, souvent périmé). Ancienne réponse (`{ pending }` seul), hors ligne
/// ou erreur : `false`, rien n'est affiché.
Future<bool> fetchPendingInvitation() async {
  try {
    final res = await ApiClient().get('auth/pending-invitation', requiresAuth: true);
    final body = res is Map && res['data'] is Map ? res['data'] : res;
    return body is Map && body['needsEmailConfirmation'] == true;
  } catch (_) {
    return false;
  }
}

/// Le serveur signale une invitation ou une demande qui attend la
/// confirmation de l'email : un seul message et « Vérifier », qui relance
/// la vérification existante. Pas de bouton « Renvoyer » : Auth0 ne le permet
/// pas sans son API de gestion.
class EmailConfirmationNotice extends StatefulWidget {
  const EmailConfirmationNotice({
    super.key,
    required this.onVerify,
    this.verifying = false,
    this.loadPending = fetchPendingInvitation,
  });

  final VoidCallback onVerify;
  final bool verifying;
  final Future<bool> Function() loadPending;

  @override
  State<EmailConfirmationNotice> createState() => _EmailConfirmationNoticeState();
}

class _EmailConfirmationNoticeState extends State<EmailConfirmationNotice> {
  bool _pending = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant EmailConfirmationNotice old) {
    super.didUpdateWidget(old);
    // Après une vérification : l'invitation a pu être acceptée entre-temps.
    if (old.verifying && !widget.verifying) _load();
  }

  Future<void> _load() async {
    final pending = await widget.loadPending();
    if (mounted && pending != _pending) setState(() => _pending = pending);
  }

  @override
  Widget build(BuildContext context) {
    if (!_pending) return const SizedBox.shrink();
    return Card(
      key: const Key('email_confirmation_notice'),
      color: Colors.orange.withAlpha(30),
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          const Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Icon(Icons.mark_email_read_outlined, color: Colors.orange),
            SizedBox(width: 10),
            Expanded(
              child: Text(kConfirmEmailMessage, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            ),
          ]),
          const SizedBox(height: 12),
          FilledButton.icon(
            key: const Key('email_confirmation_verify'),
            style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
            onPressed: widget.verifying ? null : widget.onVerify,
            icon: widget.verifying
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.verified_outlined),
            label: const Text('Vérifier'),
          ),
          const SizedBox(height: 6),
          const Text(kConfirmEmailHint, textAlign: TextAlign.center, style: TextStyle(fontSize: 13)),
        ]),
      ),
    );
  }
}
