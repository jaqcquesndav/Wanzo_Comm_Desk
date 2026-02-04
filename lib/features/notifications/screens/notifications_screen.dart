import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:go_router/go_router.dart'; // Added go_router import
import '../bloc/notifications_bloc.dart';
import '../models/notification_model.dart';
import '../../../constants/colors.dart';
import '../../../constants/spacing.dart';

/// Écran qui affiche toutes les notifications à l'utilisateur
class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  final DateFormat _dateFormatter = DateFormat('dd/MM/yyyy HH:mm');

  @override
  void initState() {
    super.initState();
    context.read<NotificationsBloc>().add(LoadNotifications());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton( // Added leading IconButton for back navigation
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            if (context.canPop()) { // Check if there's a route to pop
              context.pop();
            } else {
              // If not, navigate to a default route (e.g., dashboard)
              context.go('/dashboard'); 
            }
          },
        ),
        title: const Text('Notifications'),
        actions: [
          // Bouton pour marquer toutes les notifications comme lues
          IconButton(
            icon: const Icon(Icons.done_all),
            tooltip: 'Marquer toutes comme lues',
            onPressed: () {
              context.read<NotificationsBloc>().add(MarkAllNotificationsAsRead());
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Toutes les notifications ont été marquées comme lues'),
                ),
              );
            },
          ),
          // Menu d'options
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'clear_all') {
                _showDeleteConfirmationDialog(context);
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem<String>(
                value: 'clear_all',
                child: Row(
                  children: [
                    Icon(Icons.delete_sweep, color: WanzoColors.error),
                    SizedBox(width: 8),
                    Text('Effacer tout'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: BlocBuilder<NotificationsBloc, NotificationsState>(
        builder: (context, state) {
          if (state is NotificationsLoading) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          } else if (state is NotificationsLoaded) {
            if (state.notifications.isEmpty) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.notifications_off_outlined,
                      size: 64,
                      color: Colors.grey[400],
                    ),
                    const SizedBox(height: WanzoSpacing.md),
                    Text(
                      'Aucune notification',
                      style: TextStyle(
                        fontSize: 18,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              );
            }
            
            return ListView.builder(
              itemCount: state.notifications.length,
              itemBuilder: (context, index) {
                final notification = state.notifications[index];
                return _buildNotificationCard(context, notification);
              },
            );
          } else if (state is NotificationsError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.error_outline,
                    size: 48,
                    color: WanzoColors.error,
                  ),
                  const SizedBox(height: WanzoSpacing.md),
                  Text(
                    'Erreur: ${state.message}',
                    style: const TextStyle(color: WanzoColors.error),
                  ),
                  ElevatedButton(
                    onPressed: () {
                      context.read<NotificationsBloc>().add(LoadNotifications());
                    },
                    child: const Text('Réessayer'),
                  ),
                ],
              ),
            );
          }
          
          return const Center(
            child: Text('Chargement des notifications...'),
          );
        },
      ),
    );
  }
  
  /// Construit la carte pour une notification
  Widget _buildNotificationCard(BuildContext context, NotificationModel notification) {
    return Dismissible(
      key: Key(notification.id),
      background: Container(
        color: WanzoColors.error,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 16.0),
        child: const Icon(
          Icons.delete,
          color: Colors.white,
        ),
      ),
      direction: DismissDirection.endToStart,
      onDismissed: (_) {
        context.read<NotificationsBloc>().add(DeleteNotification(notification.id));
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Notification supprimée'),
          ),
        );
      },
      child: Card(
        margin: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
        color: notification.isRead
            ? null
            : Theme.of(context).primaryColor.withOpacity(0.05),
        child: ListTile(
          leading: _getNotificationIcon(notification.type),
          title: Text(
            notification.title ?? 'Notification sans titre', // Provide a default value for null titles
            style: TextStyle(
              fontWeight: notification.isRead ? FontWeight.normal : FontWeight.bold,
            ),
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(notification.message),
              const SizedBox(height: 4.0),
              Text(
                _dateFormatter.format(notification.timestamp),
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
          onTap: () {
            // Marquer comme lue si ce n'est pas déjà le cas
            if (!notification.isRead) {
              context.read<NotificationsBloc>().add(
                MarkNotificationAsRead(notification.id)
              );
            }
            
            // Naviguer vers la route associée si elle existe
            if (notification.actionRoute != null && notification.actionRoute!.isNotEmpty) {
              Navigator.of(context).pushNamed(notification.actionRoute!);
            }
          },
          isThreeLine: true,
        ),
      ),
    );
  }
  
  /// Retourne l'icône appropriée selon le type de notification
  Widget _getNotificationIcon(NotificationType type) {
    IconData iconData;
    Color iconColor;
    
    switch (type) {
      case NotificationType.success:
        iconData = Icons.check_circle;
        iconColor = Colors.green;
        break;
      case NotificationType.warning:
        iconData = Icons.warning;
        iconColor = Colors.orange;
        break;
      case NotificationType.error:
        iconData = Icons.error;
        iconColor = WanzoColors.error;
        break;
      case NotificationType.lowStock:
        iconData = Icons.inventory;
        iconColor = Colors.orange;
        break;
      case NotificationType.sale:
        iconData = Icons.receipt;
        iconColor = WanzoColors.primary;
        break;
      case NotificationType.payment:
        iconData = Icons.payments;
        iconColor = Colors.green;
        break;
      case NotificationType.info:
        iconData = Icons.info;
        iconColor = Colors.blue;
        break;
    }
    
    return CircleAvatar(
      backgroundColor: iconColor.withOpacity(0.2),
      child: Icon(iconData, color: iconColor),
    );
  }
  
  /// Afficher une boîte de dialogue de confirmation pour la suppression de toutes les notifications
  void _showDeleteConfirmationDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Supprimer toutes les notifications'),
        content: const Text('Êtes-vous sûr de vouloir supprimer toutes vos notifications ? Cette action est irréversible.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              context.read<NotificationsBloc>().add(DeleteAllNotifications());
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Toutes les notifications ont été supprimées'),
                ),
              );
            },
            child: const Text('Supprimer tout'),
          ),
        ],
      ),
    );
  }
}
