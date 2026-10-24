import 'package:wanzo/core/utils/desktop_modal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/utils/logout_confirmation.dart';
import '../../subscription/widgets/subscription_banner_overlay.dart'
    show wanzoSupportEmailFallback;
import '../bloc/auth_bloc.dart';

/// Saisie d'un code d'unité ou d'entreprise.
///
/// Pour un compte sans entreprise, le serveur crée une demande que
/// l'administrateur doit accepter ; pour un compte déjà membre, l'unité est
/// changée tout de suite. Le message d'erreur du serveur s'affiche sous le
/// champ.
class JoinCodeForm extends StatefulWidget {
  /// Libellé du bouton.
  final String submitLabel;

  const JoinCodeForm({super.key, this.submitLabel = 'Envoyer la demande'});

  @override
  State<JoinCodeForm> createState() => _JoinCodeFormState();
}

class _JoinCodeFormState extends State<JoinCodeForm> {
  final _controller = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final code = _controller.text.trim().toUpperCase();
    if (code.length < 3) {
      setState(() => _error = 'Saisissez le code reçu de votre administrateur.');
      return;
    }
    setState(() => _error = null);
    FocusScope.of(context).unfocus();
    context.read<AuthBloc>().add(
      AuthJoinBusinessUnitRequested(businessUnitCode: code),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<AuthBloc, AuthState>(
      listenWhen: (_, s) => s is AuthJoinBusinessUnitFailure,
      listener: (context, state) {
        if (state is AuthJoinBusinessUnitFailure && mounted) {
          setState(() => _error = state.error);
        }
      },
      buildWhen: (a, b) =>
          (a is AuthJoinBusinessUnitInProgress) !=
          (b is AuthJoinBusinessUnitInProgress),
      builder: (context, state) {
        final busy = state is AuthJoinBusinessUnitInProgress;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              key: const Key('join_code_field'),
              controller: _controller,
              enabled: !busy,
              textCapitalization: TextCapitalization.characters,
              textInputAction: TextInputAction.send,
              decoration: InputDecoration(
                labelText: "Code de l'unité ou de l'entreprise",
                hintText: 'Ex : BRN-AB12CD34 ou COMP-AB12CD34',
                prefixIcon: const Icon(Icons.vpn_key_outlined),
                errorText: _error,
                errorMaxLines: 4,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onSubmitted: (_) => busy ? null : _submit(),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 48,
              child: FilledButton(
                key: const Key('join_code_submit'),
                onPressed: busy ? null : _submit,
                child: busy
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(widget.submitLabel),
              ),
            ),
          ],
        );
      },
    );
  }
}

/// Issues toujours disponibles sur les écrans d'un compte sans accès :
/// l'aide et la déconnexion. Aucun écran ne doit être une impasse.
class JoinAccountFooter extends StatelessWidget {
  final bool enabled;

  const JoinAccountFooter({super.key, this.enabled = true});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 8,
      children: [
        TextButton.icon(
          onPressed: () => showJoinHelpSheet(context),
          icon: const Icon(Icons.help_outline),
          label: const Text('Aide'),
        ),
        TextButton.icon(
          onPressed: enabled
              ? () async {
                  final bloc = context.read<AuthBloc>();
                  final confirmed = await confirmLogout(context);
                  if (confirmed) bloc.add(const AuthLogoutRequested());
                }
              : null,
          icon: const Icon(Icons.logout),
          label: const Text('Se déconnecter'),
        ),
      ],
    );
  }
}

/// Aide en modale : comment obtenir un code, et contact du support.
Future<void> showJoinHelpSheet(BuildContext context) {
  return showDesktopModal<void>(
    context,
    title: 'Rejoindre une entreprise',
    builder: (sheetContext) {
      final theme = Theme.of(sheetContext);
      Widget step(String n, String text) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(radius: 12, child: Text(n, style: const TextStyle(fontSize: 12))),
            const SizedBox(width: 12),
            Expanded(child: Text(text)),
          ],
        ),
      );
      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          step('1', "Demandez le code à l'administrateur de votre entreprise. Il le trouve dans la liste de ses unités d'affaires."),
          step('2', 'Saisissez le code ici puis envoyez la demande.'),
          step('3', "L'administrateur reçoit votre demande et choisit votre rôle. Vous entrez dans l'application dès qu'il l'accepte."),
          const SizedBox(height: 8),
          Text(
            "Si le code désigne plusieurs entreprises, demandez le code de l'entreprise elle-même (il commence par COMP-).",
            style: theme.textTheme.bodySmall,
          ),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: () async {
              final uri = Uri(
                scheme: 'mailto',
                path: wanzoSupportEmailFallback,
                queryParameters: {'subject': 'Rejoindre une entreprise sur Wanzo'},
              );
              try {
                await launchUrl(uri);
              } catch (_) {}
            },
            icon: const Icon(Icons.mail_outline),
            label: const Text('Écrire au support Wanzo'),
          ),
        ],
      );
    },
  );
}
