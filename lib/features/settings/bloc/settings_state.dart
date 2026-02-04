import 'package:equatable/equatable.dart';
import '../models/settings.dart';

/// États pour le bloc Settings
abstract class SettingsState extends Equatable {
  const SettingsState();

  @override
  List<Object?> get props => [];
}

/// État initial du bloc Settings
class SettingsInitial extends SettingsState {
  const SettingsInitial();
}

/// Chargement des paramètres en cours
class SettingsLoading extends SettingsState {
  const SettingsLoading();
}

/// Paramètres chargés
class SettingsLoaded extends SettingsState {
  /// Paramètres actuels
  final Settings settings;

  const SettingsLoaded(this.settings);

  @override
  List<Object?> get props => [settings];
}

/// Mise à jour des paramètres réussie
class SettingsUpdated extends SettingsState {
  /// Paramètres mis à jour
  final Settings settings;
  
  /// Message de succès
  final String message;

  const SettingsUpdated({
    required this.settings,
    this.message = 'Paramètres mis à jour avec succès',
  });

  @override
  List<Object?> get props => [settings, message];
}

/// Erreur lors de la gestion des paramètres
class SettingsError extends SettingsState {
  /// Message d'erreur
  final String message;

  const SettingsError(this.message);

  @override
  List<Object?> get props => [message];
}
