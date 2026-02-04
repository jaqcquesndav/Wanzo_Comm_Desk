import './settings_event.dart'; // Import the base class

/// Événement pour mettre à jour les paramètres de notification
class UpdateNotificationSettingsEvent extends SettingsEvent { // Changed class name and fixed extends
  /// Notifications push activées
  final bool pushNotificationsEnabled;
  
  /// Notifications in-app activées
  final bool inAppNotificationsEnabled;
  
  /// Notifications par email activées
  final bool emailNotificationsEnabled;
  
  /// Notifications sonores activées
  final bool soundNotificationsEnabled;
  
  const UpdateNotificationSettingsEvent({
    required this.pushNotificationsEnabled,
    required this.inAppNotificationsEnabled,
    required this.emailNotificationsEnabled,
    required this.soundNotificationsEnabled,
  });
  
  @override
  List<Object?> get props => [
    pushNotificationsEnabled,
    inAppNotificationsEnabled,
    emailNotificationsEnabled,
    soundNotificationsEnabled,
  ];
}
