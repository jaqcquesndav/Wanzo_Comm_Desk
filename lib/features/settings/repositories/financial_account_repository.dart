import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';
import 'package:uuid/uuid.dart';
import '../../../core/exceptions/api_exceptions.dart';
import '../models/financial_account.dart';
import '../services/financial_account_api_service.dart';
import '../services/financial_account_pin_store.dart';

/// Issue d'une écriture de compte financier.
enum FinancialAccountWriteOutcome {
  /// Confirmée par le serveur.
  synced,

  /// Réseau coupé : gardée sur ce poste, envoyée au retour du réseau
  /// (file hors ligne ; le serveur est idempotent sur l'id).
  queuedOffline,

  /// Pas de service API (tests, mode démo) : locale seulement.
  localOnly,
}

/// Refus du serveur sur une écriture : la modification locale est annulée
/// et [message] (texte du serveur) est affiché tel quel.
class FinancialAccountRejectedException implements Exception {
  final String message;
  final int? statusCode;
  const FinancialAccountRejectedException(this.message, {this.statusCode});

  @override
  String toString() => message;
}

/// Repository des comptes financiers (banque, Mobile Money).
///
/// Hors ligne d'abord : chaque écriture est posée dans la box locale puis
/// envoyée au serveur (`/financial-accounts`). Réseau coupé : l'écriture part
/// dans la file hors ligne du client HTTP. Refus du serveur (droits, doublon,
/// numéro invalide) : la box revient à l'état précédent et le message du
/// serveur remonte à l'écran. Le PIN Mobile Money ne quitte jamais le poste.
class FinancialAccountRepository {
  /// Box lue par l'écran des comptes (et par la synchro générale).
  static const accountsBoxName = 'financial_accounts';
  late Box<FinancialAccount> _accountsBox;
  final _uuid = const Uuid();
  final FinancialAccountApiService? _apiService;
  final FinancialAccountPinStore _pinStore;

  /// Constructeur avec service API optionnel
  FinancialAccountRepository({
    FinancialAccountApiService? apiService,
    FinancialAccountPinStore? pinStore,
  }) : _apiService = apiService,
       _pinStore = pinStore ?? FinancialAccountPinStore();

  /// Initialisation du repository ([box] : injection pour les tests).
  Future<void> init({Box<FinancialAccount>? box}) async {
    if (box != null) {
      _accountsBox = box;
    } else {
      try {
        _accountsBox = await Hive.openBox<FinancialAccount>(accountsBoxName);
      } catch (e) {
        debugPrint('Error opening financial accounts box: $e');
        await Hive.deleteBoxFromDisk(accountsBoxName);
        _accountsBox = await Hive.openBox<FinancialAccount>(accountsBoxName);
      }
    }
    await _purgeLegacyPins();
  }

  /// Anciennes fiches : le PIN était stocké en clair (« encrypted_1234 »)
  /// dans Hive. On le déplace dans le coffre du poste puis on l'efface.
  Future<void> _purgeLegacyPins() async {
    for (final account in _accountsBox.values.toList()) {
      final legacy = account.encryptedPin;
      if (legacy == null || legacy.isEmpty) continue;
      final pin = legacy.startsWith('encrypted_')
          ? legacy.substring('encrypted_'.length)
          : legacy;
      await _pinStore.save(account.id, pin);
      await _accountsBox.put(account.id, account.withoutPin());
    }
  }

  /// Obtenir tous les comptes financiers
  List<FinancialAccount> getAllAccounts() {
    return _accountsBox.values.toList()..sort((a, b) => b.isDefault ? 1 : -1);
  }

  /// Obtenir les comptes bancaires uniquement
  List<FinancialAccount> getBankAccounts() {
    return _accountsBox.values
        .where((account) => account.type == FinancialAccountType.bankAccount)
        .toList()..sort((a, b) => b.isDefault ? 1 : -1);
  }

  /// Obtenir les comptes Mobile Money uniquement
  List<FinancialAccount> getMobileMoneyAccounts() {
    return _accountsBox.values
        .where((account) => account.type == FinancialAccountType.mobileMoney)
        .toList()..sort((a, b) => b.isDefault ? 1 : -1);
  }

  /// Obtenir un compte par son ID
  FinancialAccount? getAccountById(String id) {
    return _accountsBox.get(id);
  }

  /// Obtenir le compte par défaut
  FinancialAccount? getDefaultAccount() {
    try {
      return _accountsBox.values.firstWhere((account) => account.isDefault);
    } catch (e) {
      return _accountsBox.values.isNotEmpty ? _accountsBox.values.first : null;
    }
  }

  // ---------------------------------------------------------------------------
  // Écritures (locale puis serveur)
  // ---------------------------------------------------------------------------

  Map<String, FinancialAccount> _snapshot() =>
      Map<String, FinancialAccount>.from(_accountsBox.toMap().cast());

  Future<void> _restore(Map<String, FinancialAccount> snapshot) async {
    await _accountsBox.clear();
    await _accountsBox.putAll(snapshot);
  }

  /// Envoie l'écriture au serveur. Réseau coupé → file hors ligne. Refus →
  /// restauration de [snapshot] et [FinancialAccountRejectedException].
  Future<FinancialAccountWriteOutcome> _send(
    Map<String, FinancialAccount> snapshot,
    Future<FinancialAccount?> Function(FinancialAccountApiService api) call,
  ) async {
    final api = _apiService;
    if (api == null) return FinancialAccountWriteOutcome.localOnly;
    try {
      final fromServer = await call(api);
      if (fromServer != null) {
        // Le serveur fait foi (comptes par défaut, champs normalisés).
        await _accountsBox.put(fromServer.id, fromServer.withoutPin());
      }
      return FinancialAccountWriteOutcome.synced;
    } on OfflineQueuedException {
      return FinancialAccountWriteOutcome.queuedOffline;
    } on NetworkException {
      return FinancialAccountWriteOutcome.queuedOffline;
    } on ApiException catch (e) {
      await _restore(snapshot);
      throw FinancialAccountRejectedException(
        financialAccountErrorMessage(e),
        statusCode: e.statusCode,
      );
    }
  }

  /// Ajouter un nouveau compte financier. [pin] reste sur le poste.
  Future<FinancialAccountWriteOutcome> addAccount(
    FinancialAccount account, {
    String? pin,
  }) async {
    final snapshot = _snapshot();
    final accountId = account.id.isEmpty ? _uuid.v4() : account.id;
    final now = DateTime.now();

    final isFirstAccount = _accountsBox.isEmpty;
    final shouldBeDefault = account.isDefault || isFirstAccount;
    if (shouldBeDefault) {
      await _removeDefaultFromOtherAccounts();
    }

    final newAccount = account
        .copyWith(id: accountId, isDefault: shouldBeDefault, updatedAt: now)
        .withoutPin();
    await _accountsBox.put(accountId, newAccount);
    if (pin != null && pin.trim().isNotEmpty) {
      await _pinStore.save(accountId, pin);
    }

    return _send(snapshot, (api) async {
      final res = await api.createFinancialAccount(newAccount);
      return res.data;
    });
  }

  /// Mettre à jour un compte financier
  Future<FinancialAccountWriteOutcome> updateAccount(
    FinancialAccount account, {
    String? pin,
  }) async {
    final existingAccount = _accountsBox.get(account.id);
    if (existingAccount == null) {
      throw Exception('Compte non trouvé');
    }
    final snapshot = _snapshot();

    if (account.isDefault && !existingAccount.isDefault) {
      await _removeDefaultFromOtherAccounts();
    }

    final updatedAccount = account
        .copyWith(updatedAt: DateTime.now())
        .withoutPin();
    await _accountsBox.put(account.id, updatedAccount);
    if (pin != null && pin.trim().isNotEmpty) {
      await _pinStore.save(account.id, pin);
    }

    return _send(snapshot, (api) async {
      final res = await api.updateFinancialAccount(account.id, updatedAccount);
      return res.data;
    });
  }

  /// Supprimer un compte financier
  Future<FinancialAccountWriteOutcome> deleteAccount(String id) async {
    final account = _accountsBox.get(id);
    if (account == null) {
      throw Exception('Compte non trouvé');
    }
    final snapshot = _snapshot();

    await _accountsBox.delete(id);
    // Si c'était le compte par défaut, le premier restant le devient (le
    // serveur applique la même règle, sa réponse suivante fera foi).
    if (account.isDefault && _accountsBox.isNotEmpty) {
      final first = _accountsBox.values.first;
      await _accountsBox.put(first.id, first.copyWith(isDefault: true));
    }

    final outcome = await _send(snapshot, (api) async {
      await api.deleteFinancialAccount(id);
      return null;
    });
    await _pinStore.remove(id);
    return outcome;
  }

  /// Définir un compte comme compte par défaut
  Future<FinancialAccountWriteOutcome> setDefaultAccount(String id) async {
    final account = _accountsBox.get(id);
    if (account == null) {
      throw Exception('Compte non trouvé');
    }
    final snapshot = _snapshot();

    await _removeDefaultFromOtherAccounts();
    await _accountsBox.put(
      id,
      account.copyWith(isDefault: true, updatedAt: DateTime.now()),
    );

    return _send(snapshot, (api) async {
      final res = await api.setDefaultAccount(id);
      return res.data;
    });
  }

  /// Retirer le statut par défaut de tous les comptes
  Future<void> _removeDefaultFromOtherAccounts() async {
    final defaultAccounts =
        _accountsBox.values.where((account) => account.isDefault).toList();
    for (final account in defaultAccounts) {
      await _accountsBox.put(
        account.id,
        account.copyWith(isDefault: false, updatedAt: DateTime.now()),
      );
    }
  }

  /// Vérifier si un numéro de compte bancaire existe déjà
  bool bankAccountNumberExists(String accountNumber, {String? excludeId}) {
    return _accountsBox.values.any(
      (account) =>
          account.type == FinancialAccountType.bankAccount &&
          account.bankAccountNumber == accountNumber &&
          account.id != excludeId,
    );
  }

  /// Vérifier si un numéro de téléphone Mobile Money existe déjà
  bool mobileMoneyPhoneExists(String phoneNumber, {String? excludeId}) {
    return _accountsBox.values.any(
      (account) =>
          account.type == FinancialAccountType.mobileMoney &&
          account.phoneNumber == phoneNumber &&
          account.id != excludeId,
    );
  }

  /// Obtenir le nombre total de comptes
  int getTotalAccountsCount() => _accountsBox.length;

  /// Obtenir le nombre de comptes bancaires
  int getBankAccountsCount() => _accountsBox.values
      .where((account) => account.type == FinancialAccountType.bankAccount)
      .length;

  /// Obtenir le nombre de comptes Mobile Money
  int getMobileMoneyAccountsCount() => _accountsBox.values
      .where((account) => account.type == FinancialAccountType.mobileMoney)
      .length;

  // ---------------------------------------------------------------------------
  // Synchronisation (fusion, jamais de suppression)
  // ---------------------------------------------------------------------------

  /// Fusionne des comptes reçus du serveur dans la box, sans rien effacer.
  Future<void> _merge(List<FinancialAccount> accounts) async {
    for (final account in accounts) {
      await _accountsBox.put(account.id, account.withoutPin());
    }
  }

  /// Récupère les comptes du serveur et les fusionne localement.
  Future<List<FinancialAccount>> syncFromApi() async {
    if (_apiService == null) {
      throw Exception('Service API non disponible');
    }
    final response = await _apiService.getFinancialAccounts(limit: 200);
    if (response.success && response.data != null) {
      await _merge(response.data!);
      return getAllAccounts();
    }
    throw Exception(response.message ?? 'Erreur lors de la synchronisation');
  }

  /// Envoie les comptes locaux (POST sync : fusion côté serveur) puis
  /// fusionne la réponse. Ne vide JAMAIS la box locale.
  Future<List<FinancialAccount>> syncToApi() async {
    if (_apiService == null) {
      throw Exception('Service API non disponible');
    }
    final localAccounts = getAllAccounts();
    if (localAccounts.isEmpty) return localAccounts;
    final response = await _apiService.syncAccounts(localAccounts);
    if (response.success && response.data != null) {
      await _merge(response.data!);
      return getAllAccounts();
    }
    throw Exception(response.message ?? 'Erreur lors de la synchronisation');
  }

  /// Synchronisation bidirectionnelle. Un rôle sans droit d'écriture (403
  /// sur l'envoi) reçoit quand même les comptes de l'entreprise.
  Future<List<FinancialAccount>> fullSync() async {
    if (_apiService == null) {
      throw Exception('Service API non disponible');
    }
    try {
      await syncToApi();
    } on AuthorizationException {
      debugPrint('FinancialAccountRepository: envoi refusé (lecture seule)');
    }
    return syncFromApi();
  }

  /// Fermer le repository
  Future<void> close() async {
    await _accountsBox.close();
  }
}

/// Texte affichable pour une erreur du serveur sur les comptes financiers :
/// le message rédigé par le serveur s'il existe, sinon un texte par code.
String financialAccountErrorMessage(Object error) {
  if (error is OfflineQueuedException || error is NetworkException) {
    return 'Pas de connexion internet.';
  }
  if (error is ApiException) {
    final body = error.responseBody;
    if (body is Map) {
      final m = body['message'];
      if (m is String && m.trim().isNotEmpty) return m.trim();
      if (m is List && m.isNotEmpty) return m.map((e) => '$e').join(', ');
    }
    switch (error.statusCode) {
      case 400:
        return 'Informations du compte refusées par le serveur.';
      case 403:
        return "Seuls le propriétaire, un gérant ou le comptable peuvent "
            "modifier les comptes financiers de l'entreprise.";
      case 404:
        return 'Compte financier introuvable sur le serveur.';
      case 409:
        return 'Ce numéro est déjà enregistré pour un autre compte.';
    }
    if ((error.statusCode ?? 0) >= 500) {
      return 'Le serveur a rencontré un problème. Réessayez dans quelques instants.';
    }
  }
  return "L'enregistrement n'a pas abouti. Réessayez dans quelques instants.";
}
