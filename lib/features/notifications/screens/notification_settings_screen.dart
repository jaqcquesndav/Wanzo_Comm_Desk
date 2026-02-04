import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../settings/bloc/settings_bloc.dart';
import '../../settings/bloc/settings_event.dart';
import '../../settings/bloc/settings_state.dart';
import '../../settings/models/settings.dart';
import '../bloc/notifications_bloc.dart';
import '../../../constants/spacing.dart';

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
  
  /// Vérifie si les paramètres ont été modifiés
  void _checkForChanges() {
    final hasChanges = 
        _pushNotificationsEnabled != widget.settings.pushNotificationsEnabled ||
        _inAppNotificationsEnabled != widget.settings.inAppNotificationsEnabled ||
        _emailNotificationsEnabled != widget.settings.emailNotificationsEnabled ||
        _soundNotificationsEnabled != widget.settings.soundNotificationsEnabled;
    
    if (hasChanges != _hasChanges) {
      setState(() {
        _hasChanges = hasChanges;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Paramètres des notifications'),
        actions: [
          // Bouton de sauvegarde (visible uniquement si des changements ont été apportés)
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
              const SnackBar(
                content: Text('Paramètres de notification mis à jour'),
              ),
            );
            
            // Rafraîchir les notifications après la mise à jour des paramètres
            context.read<NotificationsBloc>().add(LoadNotifications());
          } else if (state is SettingsError) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Erreur: ${state.message}'),
                backgroundColor: Colors.red,
              ),
            );
          }
        },
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Section de configuration générale des notifications
              _buildSection(
                title: 'Configuration générale',
                children: [
                  _buildSwitchTile(
                    title: 'Notifications push',
                    subtitle: 'Recevoir les notifications même quand l\'application est fermée',
                    value: _pushNotificationsEnabled,
                    onChanged: (value) {
                      setState(() {
                        _pushNotificationsEnabled = value;
                        _checkForChanges();
                      });
                    },
                  ),
                  _buildSwitchTile(
                    title: 'Notifications dans l\'application',
                    subtitle: 'Afficher les notifications lorsque l\'application est ouverte',
                    value: _inAppNotificationsEnabled,
                    onChanged: (value) {
                      setState(() {
                        _inAppNotificationsEnabled = value;
                        _checkForChanges();
                      });
                    },
                  ),
                  _buildSwitchTile(
                    title: 'Sons de notification',
                    subtitle: 'Jouer un son lors de la réception d\'une notification',
                    value: _soundNotificationsEnabled,
                    onChanged: (value) {
                      setState(() {
                        _soundNotificationsEnabled = value;
                        _checkForChanges();
                      });
                    },
                  ),
                  _buildSwitchTile(
                    title: 'Notifications par email',
                    subtitle: 'Recevoir les notifications importantes par email',
                    value: _emailNotificationsEnabled,
                    onChanged: (value) {
                      setState(() {
                        _emailNotificationsEnabled = value;
                        _checkForChanges();
                      });
                    },
                  ),
                ],
              ),
              
              const SizedBox(height: WanzoSpacing.md),
              
              // Section des types de notifications
              _buildSection(
                title: 'Types de notifications',
                children: [
                  _buildInfoTile(
                    title: 'Notifications de stock bas',
                    subtitle: 'Reçues lorsqu\'un produit atteint un seuil bas de stock',
                    icon: Icons.inventory,
                    iconColor: Colors.orange,
                  ),
                  _buildInfoTile(
                    title: 'Notifications de vente',
                    subtitle: 'Reçues lors d\'une nouvelle vente',
                    icon: Icons.receipt,
                    iconColor: Colors.blue,
                  ),
                  _buildInfoTile(
                    title: 'Notifications de paiement',
                    subtitle: 'Reçues lors d\'un nouveau paiement',
                    icon: Icons.payments,
                    iconColor: Colors.green,
                  ),
                ],
              ),
              
              const SizedBox(height: WanzoSpacing.md),
              
              // Bouton pour envoyer une notification de test
              Center(
                child: ElevatedButton.icon(
                  onPressed: _sendTestNotification,
                  icon: const Icon(Icons.send),
                  label: const Text('Envoyer une notification de test'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
  
  /// Construit une section avec un titre et une liste d'enfants
  Widget _buildSection({
    required String title,
    required List<Widget> children,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 16.0, bottom: 8.0),
          child: Text(
            title,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        Card(
          elevation: 2,
          margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
          child: Column(
            children: children,
          ),
        ),
      ],
    );
  }
  
  /// Construit un élément de liste avec un interrupteur
  Widget _buildSwitchTile({
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return SwitchListTile(
      title: Text(title),
      subtitle: Text(subtitle),
      value: value,
      onChanged: onChanged,
      activeColor: Theme.of(context).primaryColor,
    );
  }
  
  /// Construit un élément de liste informatif
  Widget _buildInfoTile({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color iconColor,
  }) {
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: iconColor.withOpacity(0.2),
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
    
    setState(() {
      _hasChanges = false;
    });
  }
  
  /// Envoie une notification de test pour vérifier la configuration
  void _sendTestNotification() {
    // Cette fonctionnalité nécessite d'avoir un service d'injection de dépendances
    // pour accéder au NotificationService. On pourrait l'implémenter comme ceci:
    // final notificationService = context.read<NotificationService>();
    
    // Pour l'instant, on affiche un message toast
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Une notification de test a été envoyée'),
      ),
    );
  }
}
