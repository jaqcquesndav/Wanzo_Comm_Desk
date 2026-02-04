// filepath: lib/features/users/bloc/users_bloc.dart
import 'package:flutter_bloc/flutter_bloc.dart';
import '../services/user_api_service.dart';
import 'users_event.dart';
import 'users_state.dart';

/// Bloc pour la gestion des utilisateurs
class UsersBloc extends Bloc<UsersEvent, UsersState> {
  final UserApiService _userApiService;

  UsersBloc({required UserApiService userApiService})
    : _userApiService = userApiService,
      super(UsersState.initial()) {
    on<LoadCurrentUser>(_onLoadCurrentUser);
    on<UpdateCurrentUserProfile>(_onUpdateCurrentUserProfile);
    on<UpdateCurrentUserSettings>(_onUpdateCurrentUserSettings);
    on<SwitchBusinessUnit>(_onSwitchBusinessUnit);
    on<ResetToCompany>(_onResetToCompany);
    on<LoadCurrentUnit>(_onLoadCurrentUnit);
    on<LoadAccessibleUnits>(_onLoadAccessibleUnits);
    on<LoadUsers>(_onLoadUsers);
    on<CreateUser>(_onCreateUser);
    on<UpdateUser>(_onUpdateUser);
    on<DeactivateUser>(_onDeactivateUser);
    on<SelectUser>(_onSelectUser);
    on<ClearUsersError>(_onClearError);
  }

  /// Charge le profil de l'utilisateur courant
  Future<void> _onLoadCurrentUser(
    LoadCurrentUser event,
    Emitter<UsersState> emit,
  ) async {
    emit(state.copyWith(status: UsersStatus.loading, clearError: true));

    try {
      final currentUser = await _userApiService.getCurrentUser();
      emit(
        state.copyWith(status: UsersStatus.loaded, currentUser: currentUser),
      );
    } catch (e) {
      emit(
        state.copyWith(status: UsersStatus.error, errorMessage: e.toString()),
      );
    }
  }

  /// Met à jour le profil de l'utilisateur courant
  Future<void> _onUpdateCurrentUserProfile(
    UpdateCurrentUserProfile event,
    Emitter<UsersState> emit,
  ) async {
    emit(state.copyWith(status: UsersStatus.updating, clearError: true));

    try {
      final updatedUser = await _userApiService.updateCurrentUserProfile(
        firstName: event.firstName,
        lastName: event.lastName,
        phoneNumber: event.phoneNumber,
        profilePictureUrl: event.profilePictureUrl,
      );
      emit(
        state.copyWith(status: UsersStatus.updated, currentUser: updatedUser),
      );
    } catch (e) {
      emit(
        state.copyWith(status: UsersStatus.error, errorMessage: e.toString()),
      );
    }
  }

  /// Met à jour les paramètres de l'utilisateur courant
  Future<void> _onUpdateCurrentUserSettings(
    UpdateCurrentUserSettings event,
    Emitter<UsersState> emit,
  ) async {
    emit(state.copyWith(status: UsersStatus.updating, clearError: true));

    try {
      await _userApiService.updateCurrentUserSettings(
        theme: event.theme,
        language: event.language,
        emailNotifications: event.emailNotifications,
        pushNotifications: event.pushNotifications,
      );

      // Recharger l'utilisateur pour avoir les settings mis à jour
      final updatedUser = await _userApiService.getCurrentUser();
      emit(
        state.copyWith(status: UsersStatus.updated, currentUser: updatedUser),
      );
    } catch (e) {
      emit(
        state.copyWith(status: UsersStatus.error, errorMessage: e.toString()),
      );
    }
  }

  /// Change l'unité d'affaires courante
  Future<void> _onSwitchBusinessUnit(
    SwitchBusinessUnit event,
    Emitter<UsersState> emit,
  ) async {
    emit(
      state.copyWith(
        status: UsersStatus.switchingBusinessUnit,
        clearError: true,
        clearBusinessUnitSwitch: true,
      ),
    );

    try {
      final switchData = await _userApiService.switchBusinessUnit(
        event.businessUnitCode,
      );

      // Recharger l'utilisateur pour avoir les nouvelles infos d'unité
      final updatedUser = await _userApiService.getCurrentUser();

      emit(
        state.copyWith(
          status: UsersStatus.businessUnitSwitched,
          currentUser: updatedUser,
          businessUnitSwitched: true,
          businessUnitSwitchData: switchData,
        ),
      );
    } catch (e) {
      emit(
        state.copyWith(status: UsersStatus.error, errorMessage: e.toString()),
      );
    }
  }

  /// Réinitialise vers l'Entreprise Générale (niveau company)
  Future<void> _onResetToCompany(
    ResetToCompany event,
    Emitter<UsersState> emit,
  ) async {
    emit(
      state.copyWith(
        status: UsersStatus.switchingBusinessUnit,
        clearError: true,
        clearBusinessUnitSwitch: true,
      ),
    );

    try {
      final resetData = await _userApiService.resetToCompany();

      // Recharger l'utilisateur pour avoir les nouvelles infos d'unité
      final updatedUser = await _userApiService.getCurrentUser();

      emit(
        state.copyWith(
          status: UsersStatus.businessUnitSwitched,
          currentUser: updatedUser,
          businessUnitSwitched: true,
          businessUnitSwitchData: resetData,
        ),
      );
    } catch (e) {
      emit(
        state.copyWith(status: UsersStatus.error, errorMessage: e.toString()),
      );
    }
  }

  /// Charge l'unité courante de l'utilisateur
  Future<void> _onLoadCurrentUnit(
    LoadCurrentUnit event,
    Emitter<UsersState> emit,
  ) async {
    emit(state.copyWith(status: UsersStatus.loading, clearError: true));

    try {
      final currentUnit = await _userApiService.getCurrentUnit();
      emit(
        state.copyWith(
          status: UsersStatus.loaded,
          currentUnitData: currentUnit,
        ),
      );
    } catch (e) {
      emit(
        state.copyWith(status: UsersStatus.error, errorMessage: e.toString()),
      );
    }
  }

  /// Charge la liste des unités accessibles
  Future<void> _onLoadAccessibleUnits(
    LoadAccessibleUnits event,
    Emitter<UsersState> emit,
  ) async {
    emit(state.copyWith(status: UsersStatus.loading, clearError: true));

    try {
      final accessibleUnits = await _userApiService.getAccessibleUnits();
      emit(
        state.copyWith(
          status: UsersStatus.loaded,
          accessibleUnits: accessibleUnits,
        ),
      );
    } catch (e) {
      emit(
        state.copyWith(status: UsersStatus.error, errorMessage: e.toString()),
      );
    }
  }

  /// Charge la liste des utilisateurs (Admin)
  Future<void> _onLoadUsers(LoadUsers event, Emitter<UsersState> emit) async {
    emit(state.copyWith(status: UsersStatus.loading, clearError: true));

    try {
      final response = await _userApiService.getUsers(
        page: event.page,
        limit: event.limit,
        role: event.role,
        isActive: event.isActive,
        businessUnitId: event.businessUnitId,
        search: event.search,
      );

      emit(
        state.copyWith(
          status: UsersStatus.loaded,
          users: response.items,
          currentPage: response.page,
          totalPages: response.totalPages,
          totalUsers: response.total,
        ),
      );
    } catch (e) {
      emit(
        state.copyWith(status: UsersStatus.error, errorMessage: e.toString()),
      );
    }
  }

  /// Crée un nouvel utilisateur (Admin)
  Future<void> _onCreateUser(CreateUser event, Emitter<UsersState> emit) async {
    emit(state.copyWith(status: UsersStatus.creating, clearError: true));

    try {
      final newUser = await _userApiService.createUser(
        email: event.email,
        firstName: event.firstName,
        lastName: event.lastName,
        phoneNumber: event.phoneNumber,
        role: event.role,
        businessUnitCode: event.businessUnitCode,
        password: event.password,
      );

      // Ajouter le nouvel utilisateur à la liste
      final updatedUsers = [...state.users, newUser];

      emit(
        state.copyWith(
          status: UsersStatus.created,
          users: updatedUsers,
          totalUsers: state.totalUsers + 1,
        ),
      );
    } catch (e) {
      emit(
        state.copyWith(status: UsersStatus.error, errorMessage: e.toString()),
      );
    }
  }

  /// Met à jour un utilisateur (Admin)
  Future<void> _onUpdateUser(UpdateUser event, Emitter<UsersState> emit) async {
    emit(state.copyWith(status: UsersStatus.updating, clearError: true));

    try {
      final updatedUser = await _userApiService.updateUser(
        event.userId,
        firstName: event.firstName,
        lastName: event.lastName,
        phoneNumber: event.phoneNumber,
        role: event.role,
        isActive: event.isActive,
        businessUnitCode: event.businessUnitCode,
      );

      // Mettre à jour la liste
      final updatedUsers =
          state.users.map((user) {
            if (user.id == event.userId) {
              return updatedUser;
            }
            return user;
          }).toList();

      emit(
        state.copyWith(
          status: UsersStatus.updated,
          users: updatedUsers,
          selectedUser:
              state.selectedUser?.id == event.userId
                  ? updatedUser
                  : state.selectedUser,
        ),
      );
    } catch (e) {
      emit(
        state.copyWith(status: UsersStatus.error, errorMessage: e.toString()),
      );
    }
  }

  /// Désactive un utilisateur (Admin)
  Future<void> _onDeactivateUser(
    DeactivateUser event,
    Emitter<UsersState> emit,
  ) async {
    emit(state.copyWith(status: UsersStatus.updating, clearError: true));

    try {
      await _userApiService.deactivateUser(event.userId);

      // Mettre à jour la liste (marquer comme inactif)
      final updatedUsers =
          state.users.map((user) {
            if (user.id == event.userId) {
              return user.copyWith(isActive: false);
            }
            return user;
          }).toList();

      emit(state.copyWith(status: UsersStatus.updated, users: updatedUsers));
    } catch (e) {
      emit(
        state.copyWith(status: UsersStatus.error, errorMessage: e.toString()),
      );
    }
  }

  /// Sélectionne un utilisateur
  void _onSelectUser(SelectUser event, Emitter<UsersState> emit) {
    if (event.user == null) {
      emit(state.copyWith(clearSelectedUser: true));
    } else {
      emit(state.copyWith(selectedUser: event.user));
    }
  }

  /// Efface les erreurs
  void _onClearError(ClearUsersError event, Emitter<UsersState> emit) {
    emit(state.copyWith(clearError: true));
  }
}
