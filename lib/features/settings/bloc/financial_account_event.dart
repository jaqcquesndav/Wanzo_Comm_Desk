import 'package:equatable/equatable.dart';
import '../models/financial_account.dart';

/// Événements pour le bloc FinancialAccounts
abstract class FinancialAccountEvent extends Equatable {
  const FinancialAccountEvent();

  @override
  List<Object?> get props => [];
}

/// Chargement de tous les comptes financiers
class LoadFinancialAccounts extends FinancialAccountEvent {
  const LoadFinancialAccounts();
}

/// Ajout d'un nouveau compte financier
class AddFinancialAccount extends FinancialAccountEvent {
  /// Compte à ajouter
  final FinancialAccount account;

  const AddFinancialAccount(this.account);

  @override
  List<Object?> get props => [account];
}

/// Mise à jour d'un compte financier
class UpdateFinancialAccount extends FinancialAccountEvent {
  /// Compte à mettre à jour
  final FinancialAccount account;

  const UpdateFinancialAccount(this.account);

  @override
  List<Object?> get props => [account];
}

/// Suppression d'un compte financier
class DeleteFinancialAccount extends FinancialAccountEvent {
  /// ID du compte à supprimer
  final String accountId;

  const DeleteFinancialAccount(this.accountId);

  @override
  List<Object?> get props => [accountId];
}

/// Définition d'un compte comme compte par défaut
class SetDefaultFinancialAccount extends FinancialAccountEvent {
  /// ID du compte à définir par défaut
  final String accountId;

  const SetDefaultFinancialAccount(this.accountId);

  @override
  List<Object?> get props => [accountId];
}

/// Filtrage des comptes par type
class FilterAccountsByType extends FinancialAccountEvent {
  /// Type de compte à filtrer (null pour tous)
  final FinancialAccountType? accountType;

  const FilterAccountsByType(this.accountType);

  @override
  List<Object?> get props => [accountType];
}

/// Synchronisation avec l'API
class SyncFinancialAccounts extends FinancialAccountEvent {
  const SyncFinancialAccounts();

  @override
  List<Object?> get props => [];
}
