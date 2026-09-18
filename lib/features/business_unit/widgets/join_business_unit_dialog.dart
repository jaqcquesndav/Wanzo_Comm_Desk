import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../../../core/config/env_config.dart';
import '../../../core/services/api_client.dart';
import '../../../core/services/business_context_service.dart';
import '../../../services/cache_management_service.dart';

/// Rejoindre une unité d'affaires avec le code reçu par courriel.
///
/// Quand un administrateur rattache quelqu'un à une agence ou à un point de
/// vente, le serveur lui envoie un message portant le code de l'unité. Il ne
/// manquait plus que l'endroit où le saisir : la route existait, le service de
/// l'application aussi, mais aucun écran ne les appelait. Le code arrivait donc
/// dans une boîte aux lettres sans serrure correspondante.
///
/// Le changement vide les caches locaux avant de recharger : sans cela, les
/// données de l'unité précédente resteraient affichées sous le nom de la
/// nouvelle.
class JoinBusinessUnitDialog extends StatefulWidget {
  const JoinBusinessUnitDialog({super.key});

  static Future<bool?> show(BuildContext context) {
    return showDialog<bool>(
      context: context,
      builder: (_) => const JoinBusinessUnitDialog(),
    );
  }

  @override
  State<JoinBusinessUnitDialog> createState() => _JoinBusinessUnitDialogState();
}

class _JoinBusinessUnitDialogState extends State<JoinBusinessUnitDialog> {
  final TextEditingController _codeController = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _join() async {
    final code = _codeController.text.trim().toUpperCase();
    if (code.isEmpty) {
      setState(() => _error = "Saisissez le code de l'unité.");
      return;
    }

    setState(() {
      _busy = true;
      _error = null;
    });

    try {
      final headers = await ApiClient().getHeaders(requiresAuth: true);
      final response = await http
          .post(
            Uri.parse('${EnvConfig.commerceBaseUrl}/users/switch-unit'),
            headers: headers,
            body: json.encode({'code': code}),
          )
          .timeout(const Duration(seconds: 15));

      if (response.statusCode != 200) {
        setState(() {
          _busy = false;
          _error = _messageFor(response);
        });
        return;
      }

      // L'unité change : ce qui a été chargé pour la précédente n'a plus cours.
      await CacheManagementService.instance.clearAllBusinessUnitData();

      final corps = json.decode(response.body);
      final unite = corps is Map ? corps['data'] : null;
      if (unite is Map) {
        await BusinessContextService().applySwitchedUnit(
          businessUnitId: unite['businessUnitId']?.toString() ?? '',
          businessUnitCode: unite['businessUnitCode']?.toString() ?? code,
          businessUnitName: unite['businessUnitName']?.toString(),
          businessUnitType: unite['businessUnitType']?.toString(),
        );
      }

      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = "L'unité n'a pas pu être rejointe. Vérifiez votre connexion.";
      });
    }
  }

  /// Message utile plutôt qu'un code de statut.
  String _messageFor(http.Response response) {
    switch (response.statusCode) {
      case 404:
        return "Ce code ne correspond à aucune unité. Vérifiez le code communiqué par votre administrateur.";
      case 403:
        return "Vous n'avez pas accès à cette unité d'affaires.";
      case 400:
        try {
          final body = json.decode(response.body);
          final message = body is Map ? body['message']?.toString() : null;
          if (message != null && message.isNotEmpty) return message;
        } catch (_) {
          // Corps illisible : message générique ci-dessous.
        }
        return "Cette unité n'est pas active.";
      default:
        return "L'unité n'a pas pu être rejointe.";
    }
  }

  @override
  Widget build(BuildContext context) {
    final contexte = BusinessContextService();
    final uniteCourante = contexte.businessUnitName ?? contexte.businessUnitCode;

    return AlertDialog(
      title: const Text("Rejoindre une unité d'affaires"),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            uniteCourante == null
                ? "Vous travaillez au niveau de l'entreprise."
                : 'Unité actuelle : $uniteCourante',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _codeController,
            autofocus: true,
            textCapitalization: TextCapitalization.characters,
            decoration: InputDecoration(
              labelText: "Code de l'unité",
              hintText: 'BRN-XXXXXXXX',
              errorText: _error,
              border: const OutlineInputBorder(),
            ),
            onSubmitted: (_) => _busy ? null : _join(),
          ),
          const SizedBox(height: 8),
          Text(
            'Ce code vous a été communiqué par courriel lors de votre affectation.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.of(context).pop(false),
          child: const Text('Annuler'),
        ),
        FilledButton(
          onPressed: _busy ? null : _join,
          child: _busy
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Rejoindre'),
        ),
      ],
    );
  }
}
