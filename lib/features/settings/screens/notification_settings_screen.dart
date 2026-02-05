import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:wanzo/core/widgets/desktop/responsive_form_container.dart';
import 'package:wanzo/core/platform/platform_service.dart';
import '../bloc/settings_bloc.dart';
import '../bloc/settings_event.dart';
import '../bloc/settings_state.dart';
import '../models/settings.dart';
import '../../notifications/bloc/notifications_bloc.dart';
import '../../notifications/services/notification_service.dart';
import '../../notifications/models/notification_model.dart';
import '../../../constants/colors.dart';

/// Écran de configuration des paramètres de notification
class NotificationSettingsScreen extends StatefulWidget {
  /// Paramètres actuels
  final Settings settings;
  const NotificationSettingsScreen({super.key, required this.settings});
  @override
  State<NotificationSettingsScreen> createState() =>
      _NotificationSettingsScreenState();
}

class _NotificationSettingsScreenState
    extends State<NotificationSettingsScreen> {
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
              return const Center(child: CircularProgressIndicator());
            }

            return _buildSettingsForm();
          },
        ),
      ),
    );
  }

  /// Construit le formulaire des paramètres
  Widget _buildSettingsForm() {
    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth >= PlatformService.instance.desktopMinWidth;
    final isTablet =
        screenWidth >= PlatformService.instance.tabletMinWidth &&
        screenWidth < PlatformService.instance.desktopMinWidth;

    return ResponsiveFormContainer(
      maxWidth: 900,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // En-tête principal
          ResponsiveFormHeader(
            title: 'Paramètres de notifications',
            subtitle: 'Configurez vos préférences de notification',
            icon: Icons.notifications,
          ),
          const SizedBox(height: 24),

          // Layout côte à côte sur desktop, empilé sur mobile
          if (isDesktop || isTablet)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: _buildPreferencesSection(context)),
                const SizedBox(width: 24),
                Expanded(child: _buildNotificationTypesSection(context)),
              ],
            )
          else ...[
            _buildPreferencesSection(context),
            const SizedBox(height: 24),
            _buildNotificationTypesSection(context),
          ],

          const SizedBox(height: 32),

          // Section actions
          _buildActionsSection(context, isDesktop, isTablet),
        ],
      ),
    );
  }

  Widget _buildPreferencesSection(BuildContext context) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade300),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.tune,
                  color: Theme.of(context).colorScheme.primary,
                  size: 24,
                ),
                const SizedBox(width: 12),
                Text(
                  'Préférences de notification',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Notifications push
            SwitchListTile(
              title: const Text('Notifications push'),
              subtitle: const Text(
                'Recevoir des notifications même lorsque l\'application est fermée',
              ),
              value: _pushNotificationsEnabled,
              contentPadding: EdgeInsets.zero,
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
              contentPadding: EdgeInsets.zero,
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
              contentPadding: EdgeInsets.zero,
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
              contentPadding: EdgeInsets.zero,
              onChanged: (value) {
                setState(() {
                  _soundNotificationsEnabled = value;
                  _hasChanges = true;
                });
              },
            ),

            if (_hasChanges) ...[
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _saveSettings,
                  icon: const Icon(Icons.save),
                  label: const Text('Enregistrer'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildNotificationTypesSection(BuildContext context) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade300),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.category, color: Colors.teal, size: 24),
                const SizedBox(width: 12),
                Text(
                  'Types de notifications',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            _buildNotificationTypeItem(
              title: 'Ventes',
              subtitle: 'Nouvelles ventes et transactions',
              icon: Icons.receipt,
              iconColor: WanzoColors.primary,
            ),

            _buildNotificationTypeItem(
              title: 'Stock bas',
              subtitle: 'Alertes produits épuisés',
              icon: Icons.inventory,
              iconColor: Colors.orange,
            ),

            _buildNotificationTypeItem(
              title: 'Paiements',
              subtitle: 'Paiements reçus',
              icon: Icons.payments,
              iconColor: Colors.green,
            ),

            _buildNotificationTypeItem(
              title: 'Système',
              subtitle: 'Notifications système',
              icon: Icons.info,
              iconColor: Colors.blue,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionsSection(
    BuildContext context,
    bool isDesktop,
    bool isTablet,
  ) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade300),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            Row(
              children: [
                Icon(
                  Icons.touch_app,
                  color: Theme.of(context).colorScheme.primary,
                  size: 24,
                ),
                const SizedBox(width: 12),
                Text(
                  'Actions',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            Wrap(
              spacing: 16,
              runSpacing: 16,
              alignment: WrapAlignment.center,
              children: [
                ElevatedButton.icon(
                  icon: const Icon(Icons.send),
                  label: const Text('Envoyer une notification de test'),
                  onPressed: _sendTestNotification,
                ),
                OutlinedButton.icon(
                  icon: const Icon(Icons.notifications_active),
                  label: const Text('Voir toutes les notifications'),
                  onPressed: () {
                    Navigator.of(context).pushNamed('/notifications');
                  },
                ),
              ],
            ),
          ],
        ),
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
    final Color backgroundColor = iconColor.withValues(alpha: 0.2);

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
      debugPrint(
        "NotificationService n'est pas disponible dans le contexte: $e",
      );
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
      notificationsBloc.add(
        NotificationAdded(
          NotificationModel.create(
            title: 'Notification de test',
            message:
                'Ceci est une notification de test pour vérifier vos paramètres.',
            type: NotificationType.info,
          ),
        ),
      );

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
