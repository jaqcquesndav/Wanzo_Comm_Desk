import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Préférence d'AFFICHAGE double devise (CDF + USD) pour les tableaux de bord
/// et les KPI.
///
/// La comptabilité reste tenue en CDF (devise fonctionnelle OHADA/SYSCOHADA) :
/// ce réglage ne change RIEN aux écritures ni aux montants stockés. C'est un
/// simple choix de présentation.
///
/// - OFF (défaut) : les cartes de montant montrent le CDF consolidé (vue
///   officielle).
/// - ON : les cartes montrent aussi l'USD RÉELLEMENT enregistré par devise
///   (ex. `salesTodayUsd`), sans conversion inventée ni taux de change appliqué.
///
/// Persistance locale via SharedPreferences. Singleton exposant un
/// [ValueNotifier] pour que les écrans se rafraîchissent sans provider global.
class CurrencyDisplayService {
  CurrencyDisplayService._();

  static final CurrencyDisplayService instance = CurrencyDisplayService._();

  static const String _prefKey = 'display_dual_currency';

  /// Notifie les écrans abonnés (via [ValueListenableBuilder] ou un listener).
  final ValueNotifier<bool> dualCurrency = ValueNotifier<bool>(false);

  bool _loaded = false;

  /// Charge la préférence persistée (idempotent). Best-effort : en cas d'échec
  /// on garde la valeur par défaut (false).
  Future<void> load() async {
    if (_loaded) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      dualCurrency.value = prefs.getBool(_prefKey) ?? false;
    } catch (_) {
      // Garde la valeur par défaut.
    }
    _loaded = true;
  }

  /// Met à jour et persiste le choix utilisateur.
  Future<void> setDualCurrency(bool value) async {
    _loaded = true;
    dualCurrency.value = value;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_prefKey, value);
    } catch (_) {
      // Best-effort : la valeur en mémoire reste correcte pour la session.
    }
  }

  /// Point d'accroche backend : si le profil société / les settings exposent un
  /// défaut `dualCurrencyDisplay`, appeler cette méthode une fois au démarrage
  /// ou à la synchro. Le choix explicite de l'utilisateur reste prioritaire :
  /// on n'écrase jamais une préférence déjà persistée.
  Future<void> seedDefault(bool backendDefault) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (prefs.containsKey(_prefKey)) {
        _loaded = true;
        return; // L'utilisateur a déjà choisi.
      }
    } catch (_) {
      // Si SharedPreferences est indisponible, on applique quand même le défaut
      // en mémoire pour la session.
    }
    await setDualCurrency(backendDefault);
  }
}
