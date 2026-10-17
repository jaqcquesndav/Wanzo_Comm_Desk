import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../core/exceptions/api_exceptions.dart';
import '../../../core/utils/connectivity_service.dart';
import '../repositories/financial_account_repository.dart';
import '../models/financial_account.dart';
import 'financial_account_event.dart';
import 'financial_account_state.dart';

/// BLoC pour gérer les comptes financiers
class FinancialAccountBloc
    extends Bloc<FinancialAccountEvent, FinancialAccountState> {
  /// Repository pour accéder aux comptes financiers
  final FinancialAccountRepository _repository;

  /// Retour du réseau : relance la synchronisation (injectable pour les tests).
  StreamSubscription<bool>? _connectivitySub;
  VoidCallback? _connectivityListener;

  FinancialAccountBloc({
    required FinancialAccountRepository repository,
    Stream<bool>? onlineChanges,
    bool listenToConnectivity = true,
  }) : _repository = repository,
       super(const FinancialAccountInitial()) {
    on<LoadFinancialAccounts>(_onLoadFinancialAccounts);
    on<AddFinancialAccount>(_onAddFinancialAccount);
    on<UpdateFinancialAccount>(_onUpdateFinancialAccount);
    on<DeleteFinancialAccount>(_onDeleteFinancialAccount);
    on<SetDefaultFinancialAccount>(_onSetDefaultFinancialAccount);
    on<FilterAccountsByType>(_onFilterAccountsByType);
    on<SyncFinancialAccounts>(_onSyncFinancialAccounts);

    if (onlineChanges != null) {
      _connectivitySub = onlineChanges.listen((online) {
        if (online && !isClosed) add(const SyncFinancialAccounts());
      });
    } else if (listenToConnectivity) {
      final status = ConnectivityService().connectionStatus;
      var wasOnline = status.value;
      _connectivityListener = () {
        final online = status.value;
        if (online && !wasOnline && !isClosed) {
          add(const SyncFinancialAccounts());
        }
        wasOnline = online;
      };
      status.addListener(_connectivityListener!);
    }
  }

  @override
  Future<void> close() {
    _connectivitySub?.cancel();
    if (_connectivityListener != null) {
      ConnectivityService().connectionStatus.removeListener(
        _connectivityListener!,
      );
    }
    return super.close();
  }

  /// Chargement : la box locale s'affiche tout de suite, puis la
  /// synchronisation avec le serveur est lancée (fusion, sans suppression).
  Future<void> _onLoadFinancialAccounts(
    LoadFinancialAccounts event,
    Emitter<FinancialAccountState> emit,
  ) async {
    emit(const FinancialAccountLoading());
    try {
      final accounts = _repository.getAllAccounts();
      emit(
        FinancialAccountLoaded(accounts: accounts, filteredAccounts: accounts),
      );
      add(const SyncFinancialAccounts());
    } catch (e) {
      emit(FinancialAccountError('Erreur lors du chargement des comptes: $e'));
    }
  }

  /// Exécute une écriture puis publie le résultat. Refus du serveur : message
  /// du serveur, puis la liste (restaurée) reste affichée.
  Future<void> _write(
    Emitter<FinancialAccountState> emit, {
    required Future<FinancialAccountWriteOutcome> Function() action,
    required String successMessage,
    required String errorPrefix,
  }) async {
    try {
      final outcome = await action();
      final updatedAccounts = _repository.getAllAccounts();
      emit(
        FinancialAccountOperationSuccess(
          message: outcome == FinancialAccountWriteOutcome.queuedOffline
              ? '$successMessage sur cet ordinateur. Envoi au serveur au retour du réseau.'
              : successMessage,
          accounts: updatedAccounts,
        ),
      );
      emit(
        FinancialAccountLoaded(
          accounts: updatedAccounts,
          filteredAccounts: updatedAccounts,
        ),
      );
    } on FinancialAccountRejectedException catch (e) {
      emit(FinancialAccountError(e.message));
      _emitCurrent(emit);
    } catch (e) {
      emit(FinancialAccountError('$errorPrefix: $e'));
      _emitCurrent(emit);
    }
  }

  void _emitCurrent(Emitter<FinancialAccountState> emit) {
    final accounts = _repository.getAllAccounts();
    emit(FinancialAccountLoaded(accounts: accounts, filteredAccounts: accounts));
  }

  /// Gère l'ajout d'un nouveau compte financier
  Future<void> _onAddFinancialAccount(
    AddFinancialAccount event,
    Emitter<FinancialAccountState> emit,
  ) async {
    final validationError =
        _validateAccount(event.account) ?? _checkForDuplicates(event.account);
    if (validationError != null) {
      emit(FinancialAccountError(validationError));
      return;
    }
    await _write(
      emit,
      action: () => _repository.addAccount(event.account, pin: event.pin),
      successMessage: 'Compte ajouté',
      errorPrefix: 'Erreur lors de l\'ajout du compte',
    );
  }

  /// Gère la mise à jour d'un compte financier
  Future<void> _onUpdateFinancialAccount(
    UpdateFinancialAccount event,
    Emitter<FinancialAccountState> emit,
  ) async {
    final validationError =
        _validateAccount(event.account) ??
        _checkForDuplicates(event.account, excludeId: event.account.id);
    if (validationError != null) {
      emit(FinancialAccountError(validationError));
      return;
    }
    await _write(
      emit,
      action: () => _repository.updateAccount(event.account, pin: event.pin),
      successMessage: 'Compte mis à jour',
      errorPrefix: 'Erreur lors de la mise à jour du compte',
    );
  }

  /// Gère la suppression d'un compte financier
  Future<void> _onDeleteFinancialAccount(
    DeleteFinancialAccount event,
    Emitter<FinancialAccountState> emit,
  ) async {
    await _write(
      emit,
      action: () => _repository.deleteAccount(event.accountId),
      successMessage: 'Compte supprimé',
      errorPrefix: 'Erreur lors de la suppression du compte',
    );
  }

  /// Gère la définition d'un compte par défaut
  Future<void> _onSetDefaultFinancialAccount(
    SetDefaultFinancialAccount event,
    Emitter<FinancialAccountState> emit,
  ) async {
    await _write(
      emit,
      action: () => _repository.setDefaultAccount(event.accountId),
      successMessage: 'Compte par défaut défini',
      errorPrefix: 'Erreur lors de la définition du compte par défaut',
    );
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
        filteredAccounts =
            currentState.accounts
                .where((account) => account.type == event.accountType)
                .toList();
      }

      emit(
        FinancialAccountLoaded(
          accounts: currentState.accounts,
          filteredAccounts: filteredAccounts,
          filterType: event.accountType,
        ),
      );
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

      // Validation du numéro de téléphone (minimum 6 chiffres pour certains pays)
      if (account.phoneNumber != null) {
        final phoneRegex = RegExp(r'^\+?[0-9]{6,15}$');
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

  /// Synchronisation avec le serveur, en arrière-plan : la liste affichée
  /// reste en place (pas d'écran de chargement). Hors ligne, rien ne change ;
  /// une autre erreur est signalée sans effacer la liste.
  Future<void> _onSyncFinancialAccounts(
    SyncFinancialAccounts event,
    Emitter<FinancialAccountState> emit,
  ) async {
    try {
      final syncedAccounts = await _repository.fullSync();
      final current = state;
      final filter = current is FinancialAccountLoaded ? current.filterType : null;
      emit(
        FinancialAccountLoaded(
          accounts: syncedAccounts,
          filteredAccounts: filter == null
              ? syncedAccounts
              : syncedAccounts.where((a) => a.type == filter).toList(),
          filterType: filter,
        ),
      );
    } on NetworkException {
      // Hors ligne : la box locale reste affichée.
    } on OfflineQueuedException {
      // idem
    } catch (e) {
      if (e.toString().contains('Service API non disponible')) return;
      debugPrint('FinancialAccountBloc: synchronisation impossible : $e');
      emit(
        FinancialAccountError(
          'Synchronisation des comptes impossible : ${financialAccountErrorMessage(e)}',
        ),
      );
      _emitCurrent(emit);
    }
  }
}
