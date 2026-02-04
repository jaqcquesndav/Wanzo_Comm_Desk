import 'package:flutter_bloc/flutter_bloc.dart';
import '../repositories/financial_account_repository.dart';
import '../models/financial_account.dart';
import 'financial_account_event.dart';
import 'financial_account_state.dart';

/// BLoC pour gérer les comptes financiers
class FinancialAccountBloc extends Bloc<FinancialAccountEvent, FinancialAccountState> {
  /// Repository pour accéder aux comptes financiers
  final FinancialAccountRepository _repository;

  FinancialAccountBloc({
    required FinancialAccountRepository repository,
  }) : _repository = repository, super(const FinancialAccountInitial()) {
    on<LoadFinancialAccounts>(_onLoadFinancialAccounts);
    on<AddFinancialAccount>(_onAddFinancialAccount);
    on<UpdateFinancialAccount>(_onUpdateFinancialAccount);
    on<DeleteFinancialAccount>(_onDeleteFinancialAccount);
    on<SetDefaultFinancialAccount>(_onSetDefaultFinancialAccount);
    on<FilterAccountsByType>(_onFilterAccountsByType);
    on<SyncFinancialAccounts>(_onSyncFinancialAccounts);
  }

  /// Gère le chargement des comptes financiers
  Future<void> _onLoadFinancialAccounts(
    LoadFinancialAccounts event,
    Emitter<FinancialAccountState> emit,
  ) async {
    emit(const FinancialAccountLoading());
    try {
      final accounts = _repository.getAllAccounts();
      emit(FinancialAccountLoaded(
        accounts: accounts,
        filteredAccounts: accounts,
      ));
    } catch (e) {
      emit(FinancialAccountError('Erreur lors du chargement des comptes: $e'));
    }
  }

  /// Gère l'ajout d'un nouveau compte financier
  Future<void> _onAddFinancialAccount(
    AddFinancialAccount event,
    Emitter<FinancialAccountState> emit,
  ) async {
    try {
      // Validations
      final validationError = _validateAccount(event.account);
      if (validationError != null) {
        emit(FinancialAccountError(validationError));
        return;
      }

      // Vérifier les doublons
      final duplicateError = _checkForDuplicates(event.account);
      if (duplicateError != null) {
        emit(FinancialAccountError(duplicateError));
        return;
      }

      // Ajouter le compte
      await _repository.addAccount(event.account);
      final updatedAccounts = _repository.getAllAccounts();
      
      emit(FinancialAccountOperationSuccess(
        message: 'Compte ajouté avec succès',
        accounts: updatedAccounts,
      ));
      
      // Recharger les comptes
      emit(FinancialAccountLoaded(
        accounts: updatedAccounts,
        filteredAccounts: updatedAccounts,
      ));
    } catch (e) {
      emit(FinancialAccountError('Erreur lors de l\'ajout du compte: $e'));
    }
  }

  /// Gère la mise à jour d'un compte financier
  Future<void> _onUpdateFinancialAccount(
    UpdateFinancialAccount event,
    Emitter<FinancialAccountState> emit,
  ) async {
    try {
      // Validations
      final validationError = _validateAccount(event.account);
      if (validationError != null) {
        emit(FinancialAccountError(validationError));
        return;
      }

      // Vérifier les doublons (en excluant le compte actuel)
      final duplicateError = _checkForDuplicates(event.account, excludeId: event.account.id);
      if (duplicateError != null) {
        emit(FinancialAccountError(duplicateError));
        return;
      }

      // Mettre à jour le compte
      await _repository.updateAccount(event.account);
      final updatedAccounts = _repository.getAllAccounts();
      
      emit(FinancialAccountOperationSuccess(
        message: 'Compte mis à jour avec succès',
        accounts: updatedAccounts,
      ));
      
      // Recharger les comptes
      emit(FinancialAccountLoaded(
        accounts: updatedAccounts,
        filteredAccounts: updatedAccounts,
      ));
    } catch (e) {
      emit(FinancialAccountError('Erreur lors de la mise à jour du compte: $e'));
    }
  }

  /// Gère la suppression d'un compte financier
  Future<void> _onDeleteFinancialAccount(
    DeleteFinancialAccount event,
    Emitter<FinancialAccountState> emit,
  ) async {
    try {
      await _repository.deleteAccount(event.accountId);
      final updatedAccounts = _repository.getAllAccounts();
      
      emit(FinancialAccountOperationSuccess(
        message: 'Compte supprimé avec succès',
        accounts: updatedAccounts,
      ));
      
      // Recharger les comptes
      emit(FinancialAccountLoaded(
        accounts: updatedAccounts,
        filteredAccounts: updatedAccounts,
      ));
    } catch (e) {
      emit(FinancialAccountError('Erreur lors de la suppression du compte: $e'));
    }
  }

  /// Gère la définition d'un compte par défaut
  Future<void> _onSetDefaultFinancialAccount(
    SetDefaultFinancialAccount event,
    Emitter<FinancialAccountState> emit,
  ) async {
    try {
      await _repository.setDefaultAccount(event.accountId);
      final updatedAccounts = _repository.getAllAccounts();
      
      emit(FinancialAccountOperationSuccess(
        message: 'Compte par défaut défini avec succès',
        accounts: updatedAccounts,
      ));
      
      // Recharger les comptes
      emit(FinancialAccountLoaded(
        accounts: updatedAccounts,
        filteredAccounts: updatedAccounts,
      ));
    } catch (e) {
      emit(FinancialAccountError('Erreur lors de la définition du compte par défaut: $e'));
    }
  }

  /// Gère le filtrage des comptes par type
  Future<void> _onFilterAccountsByType(
    FilterAccountsByType event,
    Emitter<FinancialAccountState> emit,
  ) async {
    if (state is FinancialAccountLoaded) {
      final currentState = state as FinancialAccountLoaded;
      
      List<FinancialAccount> filteredAccounts;
      if (event.accountType == null) {
        filteredAccounts = currentState.accounts;
      } else {
        filteredAccounts = currentState.accounts
            .where((account) => account.type == event.accountType)
            .toList();
      }
      
      emit(FinancialAccountLoaded(
        accounts: currentState.accounts,
        filteredAccounts: filteredAccounts,
        filterType: event.accountType,
      ));
    }
  }

  /// Valide les données du compte
  String? _validateAccount(FinancialAccount account) {
    if (account.accountName.trim().isEmpty) {
      return 'Le nom du compte est requis';
    }

    if (account.type == FinancialAccountType.bankAccount) {
      if (!account.isValidBankAccount) {
        return 'Informations bancaires incomplètes';
      }
    } else if (account.type == FinancialAccountType.mobileMoney) {
      if (!account.isValidMobileMoneyAccount) {
        return 'Informations Mobile Money incomplètes';
      }
      
      // Validation du numéro de téléphone
      if (account.phoneNumber != null) {
        final phoneRegex = RegExp(r'^\+?[0-9]{8,15}$');
        if (!phoneRegex.hasMatch(account.phoneNumber!)) {
          return 'Numéro de téléphone invalide';
        }
      }
    }

    return null;
  }

  /// Vérifie les doublons
  String? _checkForDuplicates(FinancialAccount account, {String? excludeId}) {
    if (account.type == FinancialAccountType.bankAccount) {
      if (account.bankAccountNumber != null) {
        final exists = _repository.bankAccountNumberExists(
          account.bankAccountNumber!,
          excludeId: excludeId,
        );
        if (exists) {
          return 'Ce numéro de compte bancaire existe déjà';
        }
      }
    } else if (account.type == FinancialAccountType.mobileMoney) {
      if (account.phoneNumber != null) {
        final exists = _repository.mobileMoneyPhoneExists(
          account.phoneNumber!,
          excludeId: excludeId,
        );
        if (exists) {
          return 'Ce numéro de téléphone est déjà utilisé';
        }
      }
    }

    return null;
  }

  /// Gère la synchronisation avec l'API
  Future<void> _onSyncFinancialAccounts(
    SyncFinancialAccounts event,
    Emitter<FinancialAccountState> emit,
  ) async {
    emit(const FinancialAccountLoading());
    try {
      final syncedAccounts = await _repository.fullSync();
      emit(FinancialAccountLoaded(
        accounts: syncedAccounts,
        filteredAccounts: syncedAccounts,
      ));
    } catch (e) {
      emit(FinancialAccountError('Erreur lors de la synchronisation: ${e.toString()}'));
    }
  }
}
