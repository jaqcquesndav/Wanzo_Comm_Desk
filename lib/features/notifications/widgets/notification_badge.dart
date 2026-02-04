import 'package:flutter/material.dart';
import 'package:badges/badges.dart' as badges;
import 'package:flutter_bloc/flutter_bloc.dart';
import '../bloc/notifications_bloc.dart';

/// Widget pour afficher l'icône de notification avec une badge
class NotificationBadge extends StatelessWidget {
  final Color? badgeColor;
  final Color? iconColor;
  final VoidCallback onTap;

  const NotificationBadge({
    super.key,
    this.badgeColor,
    this.iconColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<NotificationsBloc, NotificationsState>(
      builder: (context, state) {
        final int unreadCount = state is NotificationsLoaded ? state.unreadCount : 0;
        
        return badges.Badge(
          position: badges.BadgePosition.topEnd(top: -8, end: -4),
          showBadge: unreadCount > 0,
          badgeContent: Text(
            unreadCount > 99 ? '99+' : unreadCount.toString(),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 10,
              fontWeight: FontWeight.bold,
            ),
          ),
          badgeStyle: badges.BadgeStyle(
            shape: badges.BadgeShape.circle,
            badgeColor: badgeColor ?? Theme.of(context).colorScheme.error,
            elevation: 2,
            padding: const EdgeInsets.all(4),
          ),
          child: IconButton(
            icon: const Icon(Icons.notifications),
            color: iconColor,
            onPressed: onTap,
            tooltip: 'Notifications',
          ),
        );
      },
    );
  }
}
