import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../bloc/settings_bloc.dart';
import '../bloc/settings_event.dart';
import '../bloc/settings_state.dart';
import '../models/settings.dart';
import '../../notifications/bloc/notifications_bloc.dart';
import '../../notifications/services/notification_service.dart';
import '../../notifications/models/notification_model.dart';
import '../../../constants/spacing.dart';
import '../../../constants/colors.dart';

/// Écran de configuration des paramètres de notification
class NotificationSettingsScreen extends StatefulWidget {
  /// Paramètres actuels
  final Settings settings;
  const NotificationSettingsScreen({
    super.key,
    required this.settings,
  });
  @override
  State<NotificationSettingsScreen> createState() => _NotificationSettingsScreenState();
}

class _NotificationSettingsScreenState extends State<NotificationSettingsScreen> {
  late bool _pushNotificationsEnabled;
  late bool _inAppNotificationsEnabled;
  late bool _emailNotificationsEnabled;
  late bool _soundNotificationsEnabled;
  bool _hasChanges = false;

  @override
  void initState() {
    super.initState();
    _pushNotificationsEnabled = widget.settings.pushNotificationsEnabled;
    _inAppNotificationsEnabled = widget.settings.inAppNotificationsEnabled;
    _emailNotificationsEnabled = widget.settings.emailNotificationsEnabled;
    _soundNotificationsEnabled = widget.settings.soundNotificationsEnabled;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text('Paramètres de notifications'),
        actions: [
          if (_hasChanges)
            IconButton(
              icon: const Icon(Icons.save),
              onPressed: _saveSettings,
              tooltip: 'Enregistrer les modifications',
            ),
        ],
      ),
      body: BlocListener<SettingsBloc, SettingsState>(
        listener: (context, state) {
          if (state is SettingsUpdated) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.message),
                backgroundColor: Colors.green,
              ),
            );
          } else if (state is SettingsError) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.message),
                backgroundColor: Colors.red,
              ),
            );
          }
        },
        child: BlocBuilder<SettingsBloc, SettingsState>(
          builder: (context, state) {
            if (state is SettingsLoading) {
              return const Center(
                child: CircularProgressIndicator(),
              );
            }
            
            return _buildSettingsForm();
          },
        ),
      ),
    );
  }
  /// Construit le formulaire des paramètres
  Widget _buildSettingsForm() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(WanzoSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Préférences de notification',
            style: TextStyle(
              fontSize: 18,              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: WanzoSpacing.md),
          
          // Notifications push
          SwitchListTile(
            title: const Text('Notifications push'),
            subtitle: const Text(
              'Recevoir des notifications même lorsque l\'application est fermée',
            ),
            value: _pushNotificationsEnabled,
            onChanged: (value) {
              setState(() {
                _pushNotificationsEnabled = value;
                _hasChanges = true;
              });
            },
          ),
          
          // Notifications in-app
          SwitchListTile(
            title: const Text('Notifications in-app'),
            subtitle: const Text(
              'Afficher des notifications à l\'intérieur de l\'application',
            ),
            value: _inAppNotificationsEnabled,
            onChanged: (value) {
              setState(() {
                _inAppNotificationsEnabled = value;
                _hasChanges = true;
              });
            },
          ),
          
          // Notifications par email
          SwitchListTile(
            title: const Text('Notifications par email'),
            subtitle: const Text(
              'Recevoir des notifications importantes par email',
            ),
            value: _emailNotificationsEnabled,
            onChanged: (value) {
              setState(() {
                _emailNotificationsEnabled = value;
                _hasChanges = true;
              });
            },
          ),
          
          // Notifications sonores
          SwitchListTile(
            title: const Text('Son des notifications'),
            subtitle: const Text(
              'Jouer un son lors de la réception d\'une notification',
            ),
            value: _soundNotificationsEnabled,
            onChanged: (value) {
              setState(() {
                _soundNotificationsEnabled = value;
                _hasChanges = true;
              });
            },
          ),
          
          const Divider(),
          
          const Text(
            'Types de notifications',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),          const SizedBox(height: WanzoSpacing.md),
          
          // Exemples de types de notifications disponibles
          _buildNotificationTypeItem(
            title: 'Ventes',
            subtitle: 'Notifications pour les nouvelles ventes et transactions',
            icon: Icons.receipt,
            iconColor: WanzoColors.primary,
          ),
          
          _buildNotificationTypeItem(
            title: 'Stock bas',
            subtitle: 'Alertes lorsque des produits sont presque épuisés',
            icon: Icons.inventory,
            iconColor: Colors.orange,
          ),
          
          _buildNotificationTypeItem(
            title: 'Paiements',
            subtitle: 'Notifications pour les paiements reçus',
            icon: Icons.payments,
            iconColor: Colors.green,
          ),
          
          _buildNotificationTypeItem(
            title: 'Système',
            subtitle: 'Notifications importantes liées au fonctionnement de l\'application',
            icon: Icons.info,
            iconColor: Colors.blue,
          ),
          
          const Divider(),
          
          Center(
            child: ElevatedButton.icon(
              icon: const Icon(Icons.send),
              label: const Text('Envoyer une notification de test'),
              onPressed: _sendTestNotification,
            ),
          ),
            const SizedBox(height: WanzoSpacing.md),
          
          Center(
            child: TextButton(
              onPressed: () {
                Navigator.of(context).pushNamed('/notifications');
              },
              child: const Text('Voir toutes les notifications'),
            ),
          ),
        ],
      ),
    );
  }
  /// Construit un élément représentant un type de notification
  Widget _buildNotificationTypeItem({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color iconColor,
  }) {
    // Using opacity 0.2 for the background
    final Color backgroundColor = Color.fromRGBO(
      iconColor.red,
      iconColor.green,
      iconColor.blue,
      0.2,
    );
    
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: backgroundColor,
        child: Icon(icon, color: iconColor),
      ),
      title: Text(title),
      subtitle: Text(subtitle),
    );
  }

  /// Enregistre les modifications des paramètres de notification
  void _saveSettings() {
    context.read<SettingsBloc>().add(
      UpdateNotificationSettings(
        pushNotificationsEnabled: _pushNotificationsEnabled,
        inAppNotificationsEnabled: _inAppNotificationsEnabled,
        emailNotificationsEnabled: _emailNotificationsEnabled,
        soundNotificationsEnabled: _soundNotificationsEnabled,
      ),
    );
    
    // Mettre à jour le service de notification si injecté dans le contexte
    try {
      final notificationService = context.read<NotificationService>();
      final updatedSettings = widget.settings.copyWith(
        pushNotificationsEnabled: _pushNotificationsEnabled,
        inAppNotificationsEnabled: _inAppNotificationsEnabled,
        emailNotificationsEnabled: _emailNotificationsEnabled,
        soundNotificationsEnabled: _soundNotificationsEnabled,
      );
      notificationService.updateSettings(updatedSettings);
    } catch (e) {
      // Le service peut ne pas être disponible dans le contexte
      debugPrint("NotificationService n'est pas disponible dans le contexte: $e");
    }
    
    setState(() {
      _hasChanges = false;
    });
  }

  /// Envoie une notification de test pour vérifier la configuration
  void _sendTestNotification() {
    // Essayer d'accéder au bloc des notifications
    try {
      final notificationsBloc = context.read<NotificationsBloc>();
      
      // Simuler l'ajout d'une notification
      notificationsBloc.add(NotificationAdded(
        NotificationModel.create(
          title: 'Notification de test',
          message: 'Ceci est une notification de test pour vérifier vos paramètres.',
          type: NotificationType.info,
        ),
      ));
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Notification de test envoyée'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      // Si le bloc n'est pas disponible
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Impossible d\'envoyer la notification de test'),
          backgroundColor: Colors.orange,
        ),
      );
    }
  }
}
