import 'package:flutter/material.dart';

import '../../../core/services/business_context_service.dart';
import '../../../services/cache_management_service.dart';
import '../../auth/services/auth_backend_service.dart';

/// Changer d'unité d'affaires en saisissant son code.
///
/// Sert les deux cas, qui sont le même geste : rejoindre une unité quand on
/// n'en a pas encore, et passer d'une unité à une autre ensuite. Un
/// administrateur comme un employé peut le faire ; le serveur refuse le code
/// s'il ne donne pas accès.
///
/// Passe par `AuthBackendService.joinBusinessUnit`, le seul chemin qui
/// enregistre l'affectation ET prévient accounting-service (événement
/// `user.updated`). Une version précédente appelait `POST /users/switch-unit`,
/// qui ne fait que l'enregistrement local : le changement restait invisible de
/// la comptabilité.
///
/// Les caches locaux sont vidés avant de recharger, sinon les données de
/// l'unité précédente resteraient affichées sous le nom de la nouvelle.
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

  /// Remonte au niveau de l'entreprise generale. Aucun code a saisir : c'est
  /// le serveur qui retrouve l'unite racine.
  Future<void> _revenirEntreprise() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final reponse = await AuthBackendService().resetToCompanyUnit();
      await _appliquer(reponse, niveauEntreprise: true);
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (erreur) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = _message(erreur);
      });
    }
  }

  /// Vide ce qui appartenait a l'unite precedente, puis installe la nouvelle.
  /// L'ordre compte : sans purge prealable, les donnees de l'ancienne unite
  /// resteraient affichees sous le nom de la nouvelle.
  Future<void> _appliquer(
    JoinBusinessUnitResponse reponse, {
    bool niveauEntreprise = false,
  }) async {
    await CacheManagementService.instance.clearAllBusinessUnitData();
    await BusinessContextService().applySwitchedUnit(
      businessUnitId: reponse.businessUnitId,
      businessUnitCode: reponse.businessUnitCode,
      businessUnitName: reponse.businessUnitName,
      businessUnitType: reponse.businessUnitType,
      niveauEntreprise: niveauEntreprise,
    );
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
      final reponse = await AuthBackendService().joinBusinessUnit(code);
      await _appliquer(reponse);

      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (erreur) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = _message(erreur);
      });
    }
  }

  /// Le service remonte déjà un message explicite par cas (code inconnu, unité
  /// inactive, accès refusé) ; on l'affiche tel quel plutôt qu'un code d'état.
  String _message(Object erreur) {
    final texte = erreur.toString().replaceFirst('Exception: ', '').trim();
    return texte.isEmpty
        ? "L'unité n'a pas pu être rejointe. Vérifiez votre connexion."
        : texte;
  }

  @override
  Widget build(BuildContext context) {
    final contexte = BusinessContextService();
    final uniteCourante = contexte.businessUnitName ?? contexte.businessUnitCode;
    final premiereAffectation = uniteCourante == null;

    return AlertDialog(
      title: Text(
        premiereAffectation
            ? "Rejoindre une unité d'affaires"
            : "Changer d'unité d'affaires",
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            premiereAffectation
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
        // L'entreprise generale n'a pas de code : on y remonte d'un geste.
        if (!premiereAffectation)
          TextButton(
            onPressed: _busy ? null : _revenirEntreprise,
            child: const Text("Entreprise generale"),
          ),
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
              : Text(premiereAffectation ? 'Rejoindre' : 'Changer'),
        ),
      ],
    );
  }
}
