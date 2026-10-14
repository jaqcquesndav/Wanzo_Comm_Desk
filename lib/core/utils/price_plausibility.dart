import 'package:flutter/material.dart';

/// Garde-fou de vraisemblance des prix : un prix en dollars enregistré comme
/// un nombre de francs (21 $ devenus 21 FC, soit 0,01 $) ne doit plus passer
/// sans qu'on le signale. Seuils volontairement bas : ils ne gênent pas une
/// saisie normale, ils attrapent l'erreur de devise.

/// En dessous, un prix de vente en CDF est suspect (21 FC = 0,01 $).
const double kPrixCdfMinimumPlausible = 50;

/// En dessous, un prix en devise étrangère (USD, FCFA) est suspect.
const double kPrixDeviseMinimumPlausible = 0.10;

/// Au-delà de ce multiple du total, un montant reçu est suspect.
const double kMultipleEncaisseSuspect = 20;

/// Vrai si [prix] (strictement positif) est anormalement bas pour [codeDevise].
/// Un prix nul n'est pas signalé (article offert ou prix non renseigné).
bool prixAnormalementBas(double prix, String codeDevise) {
  if (!(prix > 0)) return false;
  final cdf = codeDevise.trim().toUpperCase() == 'CDF';
  return prix < (cdf ? kPrixCdfMinimumPlausible : kPrixDeviseMinimumPlausible);
}

/// Vrai si le montant reçu dépasse de loin le total (ex. 126 $ pour 0,05 $).
bool encaissementDisproportionne({required double recu, required double total}) =>
    total > 0 && recu > kMultipleEncaisseSuspect * total;

/// Formate un prix lisiblement pour les messages (« 21 FC », « 0,01 USD »).
String libellePrix(double prix, String codeDevise) {
  final code = codeDevise.trim().toUpperCase();
  final decimales = code == 'CDF' ? (prix == prix.roundToDouble() ? 0 : 2) : 2;
  final txt = prix.toStringAsFixed(decimales).replaceAll('.', ',');
  return code == 'CDF' ? '$txt FC' : '$txt $code';
}

/// Choix de l'utilisateur devant un prix en francs suspect, à la saisie.
enum ChoixDevisePrix {
  /// Rien de suspect, ou l'utilisateur confirme que c'est bien en francs.
  garder,

  /// Le montant tapé était en dollars : basculer la devise sur USD.
  enDollars,

  /// Fenêtre fermée sans choix : ne rien enregistrer.
  annule,
}

/// À la saisie d'un prix de vente : si la devise choisie est CDF et le prix
/// inférieur à [kPrixCdfMinimumPlausible], demande si c'était des francs.
Future<ChoixDevisePrix> verifierPrixSaisi(
  BuildContext context, {
  required double prix,
  required String codeDevise,
}) async {
  if (codeDevise.trim().toUpperCase() != 'CDF' ||
      !prixAnormalementBas(prix, 'CDF')) {
    return ChoixDevisePrix.garder;
  }
  final choix = await showDialog<ChoixDevisePrix>(
    context: context,
    builder: (ctx) => AlertDialog(
      icon: const Icon(Icons.help_outline),
      title: const Text('Prix très bas'),
      content: Text(
        'Vous avez saisi ${libellePrix(prix, 'CDF')}.\n'
        'Ce prix est-il en francs (CDF) ? 21 FC = 0,01 \$.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, ChoixDevisePrix.enDollars),
          child: const Text('C\'était en dollars'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(ctx, ChoixDevisePrix.garder),
          child: const Text('Oui, en francs'),
        ),
      ],
    ),
  );
  return choix ?? ChoixDevisePrix.annule;
}

/// Choix devant un prix de vente suspect au moment d'encaisser.
enum ChoixPrixVente { corriger, continuer, annule }

/// Avant de valider une vente : signale une ligne au prix anormalement bas.
Future<ChoixPrixVente> confirmerPrixVenteBas(
  BuildContext context, {
  required String article,
  required double prix,
  required String codeDevise,
  bool peutCorriger = true,
}) async {
  final choix = await showDialog<ChoixPrixVente>(
    context: context,
    builder: (ctx) => AlertDialog(
      icon: const Icon(Icons.warning_amber_rounded, color: Colors.orange),
      title: const Text('Prix anormalement bas'),
      content: Text(
        'Prix anormalement bas (${libellePrix(prix, codeDevise)} pour '
        '$article). Le prix de cet article a peut-être été saisi en dollars '
        'au lieu de francs. Vérifiez la fiche article.',
      ),
      actions: [
        if (peutCorriger)
          TextButton(
            onPressed: () => Navigator.pop(ctx, ChoixPrixVente.corriger),
            child: const Text('Corriger l\'article'),
          ),
        FilledButton(
          onPressed: () => Navigator.pop(ctx, ChoixPrixVente.continuer),
          child: const Text('Continuer quand même'),
        ),
      ],
    ),
  );
  return choix ?? ChoixPrixVente.annule;
}

/// Avant de valider une vente : montant reçu très supérieur au total.
Future<bool> confirmerEncaissementDisproportionne(
  BuildContext context, {
  required double recu,
  required double total,
  required String codeDevise,
}) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      icon: const Icon(Icons.warning_amber_rounded, color: Colors.orange),
      title: const Text('Montant reçu inhabituel'),
      content: Text(
        'Montant reçu ${libellePrix(recu, codeDevise)} pour un total de '
        '${libellePrix(total, codeDevise)}. Vérifiez la devise et les prix '
        'avant de valider.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: const Text('Vérifier'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(ctx, true),
          child: const Text('Continuer quand même'),
        ),
      ],
    ),
  );
  return ok == true;
}
