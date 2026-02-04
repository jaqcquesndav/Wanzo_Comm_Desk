import 'package:equatable/equatable.dart';
import '../models/financial_account.dart';

/// États pour le bloc FinancialAccounts
abstract class FinancialAccountState extends Equatable {
  const FinancialAccountState();

  @override
  List<Object?> get props => [];
}

/// État initial
class FinancialAccountInitial extends FinancialAccountState {
  const FinancialAccountInitial();
}

/// État de chargement
class FinancialAccountLoading extends FinancialAccountState {
  const FinancialAccountLoading();
}

/// État avec comptes chargés
class FinancialAccountLoaded extends FinancialAccountState {
  /// Liste de tous les comptes
  final List<FinancialAccount> accounts;
  
  /// Comptes filtrés (peut être identique à accounts si pas de filtre)
  final List<FinancialAccount> filteredAccounts;
  
  /// Type de filtre appliqué (null si pas de filtre)
  final FinancialAccountType? filterType;

  const FinancialAccountLoaded({
    required this.accounts,
    required this.filteredAccounts,
    this.filterType,
  });

  /// Obtenir les comptes bancaires
  List<FinancialAccount> get bankAccounts => 
      accounts.where((account) => account.type == FinancialAccountType.bankAccount).toList();

  /// Obtenir les comptes Mobile Money
  List<FinancialAccount> get mobileMoneyAccounts => 
      accounts.where((account) => account.type == FinancialAccountType.mobileMoney).toList();

  /// Obtenir le compte par défaut
  FinancialAccount? get defaultAccount {
    try {
      return accounts.firstWhere((account) => account.isDefault);
    } catch (e) {
      return null;
    }
  }

  /// Nombre total de comptes
  int get totalAccountsCount => accounts.length;

  /// Nombre de comptes bancaires
  int get bankAccountsCount => bankAccounts.length;

  /// Nombre de comptes Mobile Money
  int get mobileMoneyAccountsCount => mobileMoneyAccounts.length;

  @override
  List<Object?> get props => [accounts, filteredAccounts, filterType];

  FinancialAccountLoaded copyWith({
    List<FinancialAccount>? accounts,
    List<FinancialAccount>? filteredAccounts,
    FinancialAccountType? filterType,
  }) {
    return FinancialAccountLoaded(
      accounts: accounts ?? this.accounts,
      filteredAccounts: filteredAccounts ?? this.filteredAccounts,
      filterType: filterType ?? this.filterType,
    );
  }
}

/// État d'opération réussie
class FinancialAccountOperationSuccess extends FinancialAccountState {
  /// Message de succès
  final String message;
  
  /// Comptes mis à jour
  final List<FinancialAccount> accounts;

  const FinancialAccountOperationSuccess({
    required this.message,
    required this.accounts,
  });

  @override
  List<Object?> get props => [message, accounts];
}

/// État d'erreur
class FinancialAccountError extends FinancialAccountState {
  /// Message d'erreur
  final String message;

  const FinancialAccountError(this.message);

  @override
  List<Object?> get props => [message];
}
