import 'package:hive/hive.dart';
import 'package:uuid/uuid.dart';
import '../models/financial_account.dart';
import '../services/financial_account_api_service.dart';

/// Repository pour la gestion des comptes financiers
class FinancialAccountRepository {
  static const _accountsBoxName = 'financial_accounts';
  late final Box<FinancialAccount> _accountsBox;
  final _uuid = const Uuid();
  final FinancialAccountApiService? _apiService;

  /// Constructeur avec service API optionnel
  FinancialAccountRepository({FinancialAccountApiService? apiService})
      : _apiService = apiService;

  /// Initialisation du repository
  Future<void> init() async {
    try {
      _accountsBox = await Hive.openBox<FinancialAccount>(_accountsBoxName);
    } catch (e) {
      // Handle box opening error
      print('Error opening financial accounts box: $e');
      // Try to delete corrupted box if it exists
      await Hive.deleteBoxFromDisk(_accountsBoxName);
      // Retry opening
      _accountsBox = await Hive.openBox<FinancialAccount>(_accountsBoxName);
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
      // Si aucun compte par défaut n'est trouvé, retourner le premier compte disponible
      return _accountsBox.values.isNotEmpty ? _accountsBox.values.first : null;
    }
  }

  /// Ajouter un nouveau compte financier
  Future<FinancialAccount> addAccount(FinancialAccount account) async {
    final accountId = account.id.isEmpty ? _uuid.v4() : account.id;
    final now = DateTime.now();
    
    // Si c'est le premier compte ou si on veut le définir par défaut
    final isFirstAccount = _accountsBox.isEmpty;
    final shouldBeDefault = account.isDefault || isFirstAccount;
    
    // Si ce compte doit être par défaut, retirer le statut par défaut des autres
    if (shouldBeDefault) {
      await _removeDefaultFromOtherAccounts();
    }
    
    final newAccount = account.copyWith(
      id: accountId,
      isDefault: shouldBeDefault,
      createdAt: account.createdAt,
      updatedAt: now,
    );
    
    await _accountsBox.put(accountId, newAccount);
    return newAccount;
  }

  /// Mettre à jour un compte financier
  Future<FinancialAccount> updateAccount(FinancialAccount account) async {
    final existingAccount = _accountsBox.get(account.id);
    if (existingAccount == null) {
      throw Exception('Compte non trouvé');
    }
    
    // Si on change le statut par défaut
    if (account.isDefault && !existingAccount.isDefault) {
      await _removeDefaultFromOtherAccounts();
    }
    
    final updatedAccount = account.copyWith(
      updatedAt: DateTime.now(),
    );
    
    await _accountsBox.put(account.id, updatedAccount);
    return updatedAccount;
  }

  /// Supprimer un compte financier
  Future<void> deleteAccount(String id) async {
    final account = _accountsBox.get(id);
    if (account == null) {
      throw Exception('Compte non trouvé');
    }
    
    await _accountsBox.delete(id);
    
    // Si c'était le compte par défaut, définir un autre compte comme par défaut
    if (account.isDefault && _accountsBox.isNotEmpty) {
      final firstAccount = _accountsBox.values.first;
      await updateAccount(firstAccount.copyWith(isDefault: true));
    }
  }

  /// Définir un compte comme compte par défaut
  Future<void> setDefaultAccount(String id) async {
    final account = _accountsBox.get(id);
    if (account == null) {
      throw Exception('Compte non trouvé');
    }
    
    // Retirer le statut par défaut des autres comptes
    await _removeDefaultFromOtherAccounts();
    
    // Définir ce compte comme par défaut
    await updateAccount(account.copyWith(isDefault: true));
  }

  /// Retirer le statut par défaut de tous les comptes
  Future<void> _removeDefaultFromOtherAccounts() async {
    final defaultAccounts = _accountsBox.values.where((account) => account.isDefault);
    
    for (final account in defaultAccounts) {
      final updatedAccount = account.copyWith(
        isDefault: false,
        updatedAt: DateTime.now(),
      );
      await _accountsBox.put(account.id, updatedAccount);
    }
  }

  /// Vérifier si un numéro de compte bancaire existe déjà
  bool bankAccountNumberExists(String accountNumber, {String? excludeId}) {
    return _accountsBox.values.any((account) => 
        account.type == FinancialAccountType.bankAccount &&
        account.bankAccountNumber == accountNumber &&
        account.id != excludeId);
  }

  /// Vérifier si un numéro de téléphone Mobile Money existe déjà
  bool mobileMoneyPhoneExists(String phoneNumber, {String? excludeId}) {
    return _accountsBox.values.any((account) => 
        account.type == FinancialAccountType.mobileMoney &&
        account.phoneNumber == phoneNumber &&
        account.id != excludeId);
  }

  /// Obtenir le nombre total de comptes
  int getTotalAccountsCount() {
    return _accountsBox.length;
  }

  /// Obtenir le nombre de comptes bancaires
  int getBankAccountsCount() {
    return _accountsBox.values
        .where((account) => account.type == FinancialAccountType.bankAccount)
        .length;
  }

  /// Obtenir le nombre de comptes Mobile Money
  int getMobileMoneyAccountsCount() {
    return _accountsBox.values
        .where((account) => account.type == FinancialAccountType.mobileMoney)
        .length;
  }

  /// Synchroniser avec l'API - Récupérer les comptes depuis le serveur
  Future<List<FinancialAccount>> syncFromApi() async {
    if (_apiService == null) {
      throw Exception('Service API non disponible');
    }

    try {
      final response = await _apiService.getFinancialAccounts();
      if (response.success && response.data != null) {
        // Sauvegarder localement les comptes récupérés
        for (final account in response.data!) {
          await _accountsBox.put(account.id, account);
        }
        return response.data!;
      } else {
        throw Exception(response.message ?? 'Erreur lors de la synchronisation');
      }
    } catch (e) {
      throw Exception('Erreur de synchronisation depuis l\'API: $e');
    }
  }

  /// Synchroniser avec l'API - Envoyer les comptes locaux vers le serveur
  Future<List<FinancialAccount>> syncToApi() async {
    if (_apiService == null) {
      throw Exception('Service API non disponible');
    }

    try {
      final localAccounts = getAllAccounts();
      final response = await _apiService.syncAccounts(localAccounts);
      if (response.success && response.data != null) {
        // Mettre à jour les comptes locaux avec les données du serveur
        await _accountsBox.clear();
        for (final account in response.data!) {
          await _accountsBox.put(account.id, account);
        }
        return response.data!;
      } else {
        throw Exception(response.message ?? 'Erreur lors de la synchronisation');
      }
    } catch (e) {
      throw Exception('Erreur de synchronisation vers l\'API: $e');
    }
  }

  /// Synchronisation bidirectionnelle avec l'API
  Future<List<FinancialAccount>> fullSync() async {
    if (_apiService == null) {
      throw Exception('Service API non disponible');
    }
    
    try {
      // D'abord, envoyer les modifications locales
      await syncToApi();
      // Puis, récupérer les dernières données du serveur
      return await syncFromApi();
    } catch (e) {
      throw Exception('Erreur lors de la synchronisation complète: $e');
    }
  }

  /// Fermer le repository
  Future<void> close() async {
    await _accountsBox.close();
  }
}
