import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:badges/badges.dart' as badges;
import 'dart:io';
import 'package:go_router/go_router.dart'; // Import go_router
import '../../constants/spacing.dart';
import '../../constants/typography.dart';
import '../../features/auth/bloc/auth_bloc.dart';
import '../../features/settings/bloc/settings_bloc.dart';
import '../../features/settings/bloc/settings_state.dart';
import '../../features/notifications/bloc/notifications_bloc.dart';

/// AppBar personnalisé et réutilisable pour toute l'application Wanzo
class WanzoAppBar extends StatelessWidget implements PreferredSizeWidget {
  /// Titre de l'AppBar
  final String title;
  
  /// Actions supplémentaires à afficher (à côté du menu de profil)
  final List<Widget>? additionalActions;
  
  /// Callback pour le bouton de retour (null = pas de bouton de retour)
  final VoidCallback? onBackPressed;
  
  /// Constructor
  const WanzoAppBar({
    super.key,
    required this.title,
    this.additionalActions,
    this.onBackPressed,
  });
  
  /// Obtenir le logo à afficher dans l'AppBar
  Widget _getLogo(BuildContext context) {
    // Obtention des paramètres depuis le bloc
    final settingsState = context.watch<SettingsBloc>().state;
    String logoPath = 'assets/images/logo.jpg'; // Logo par défaut
    
    // Utiliser le logo de l'entreprise s'il est défini
    if (settingsState is SettingsLoaded && 
        settingsState.settings.companyLogo.isNotEmpty) {
      logoPath = settingsState.settings.companyLogo;
    }
    
    // Déterminer comment charger l'image selon le type de chemin
    if (logoPath.startsWith('assets/')) {
      return Image.asset(
        logoPath,
        height: 24,
        errorBuilder: (context, error, stackTrace) {
          return const SizedBox.shrink();
        },
      );
    } else {
      return Image.file(
        File(logoPath),
        height: 24,
        errorBuilder: (context, error, stackTrace) {
          // En cas d'erreur, revenir au logo par défaut
          return Image.asset(
            'assets/images/logo.jpg',
            height: 24,
            errorBuilder: (_, __, ___) => const SizedBox.shrink(),
          );
        },
      );
    }
  }
  
  @override
  Widget build(BuildContext context) {
    // Obtention de l'utilisateur connecté
    final authState = context.read<AuthBloc>().state;
    final user = authState is AuthAuthenticated ? authState.user : null;
    final userName = user?.name ?? 'Utilisateur';
      return AppBar(
      title: Row(
        children: [
          // Logo Wanzo (uniquement sur l'écran principal)
          if (onBackPressed == null)
            Padding(
              padding: const EdgeInsets.only(right: WanzoSpacing.sm),
              child: _getLogo(context),
            ),
          Expanded( // Wrap the Text widget with Expanded
            child: Text(
              title,
              overflow: TextOverflow.ellipsis, // Prevent long titles from overflowing
              softWrap: false, // Prevent wrapping to multiple lines
            ),
          ),
        ],
      ),
      leading: onBackPressed != null 
          ? IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: onBackPressed,
            )
          : null,      actions: [
        // Actions additionnelles si présentes
        if (additionalActions != null) ...additionalActions!,
        
        // Icône de notifications
        BlocBuilder<NotificationsBloc, NotificationsState>(
          builder: (context, state) {
            int unreadCount = 0;
            
            if (state is NotificationsLoaded) {
              unreadCount = state.unreadCount;
            }
            
            return IconButton(
              icon: badges.Badge(
                showBadge: unreadCount > 0,
                badgeContent: Text(
                  unreadCount > 9 ? '9+' : unreadCount.toString(),
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onError, // Use theme color
                    fontSize: 10,
                  ),
                ),
                badgeStyle: badges.BadgeStyle( // Use theme color
                  badgeColor: Theme.of(context).colorScheme.error,
                  padding: EdgeInsets.all(5),
                ),
                child: const Icon(Icons.notifications_outlined),
              ),
              onPressed: () {
                // Naviguer vers l'écran des notifications
                context.go('/notifications'); // Changed from Navigator.pushNamed
              },
            );
          },
        ),
        
        // Menu utilisateur
        PopupMenuButton<String>(
          onSelected: (value) {
            if (value == 'logout') {
              context.read<AuthBloc>().add(const AuthLogoutRequested());
            } else if (value == 'profile') {
              // Navigation vers le profil
              context.push('/profile'); // MODIFIED: Use context.push for profile
            } else if (value == 'settings') {
              // Navigation vers les paramètres
              context.push('/settings'); // MODIFIED: Use context.push to navigate
            }
          },
          itemBuilder: (BuildContext context) => [
            // Option de profil
            PopupMenuItem<String>(
              value: 'profile',
              child: Row(
                children: [
                  Icon(Icons.person, color: Theme.of(context).colorScheme.primary), // Use theme color
                  const SizedBox(width: WanzoSpacing.sm),
                  const Text('Profil'),
                ],
              ),
            ),
            // Option de paramètres
            PopupMenuItem<String>(
              value: 'settings',
              child: Row(
                children: [
                  Icon(Icons.settings, color: Theme.of(context).colorScheme.surfaceContainerHighest), // Use theme color (info mapped to surfaceVariant)
                  const SizedBox(width: WanzoSpacing.sm),
                  const Text('Paramètres'),
                ],
              ),
            ),
            const PopupMenuDivider(),
            // Option de déconnexion
            PopupMenuItem<String>(
              value: 'logout',
              child: Row(
                children: [
                  Icon(Icons.logout, color: Theme.of(context).colorScheme.error), // Use theme color
                  const SizedBox(width: WanzoSpacing.sm),
                  const Text('Déconnexion'),
                ],
              ),
            ),
          ],
          child: Padding(
            padding: const EdgeInsets.all(WanzoSpacing.sm), // Minimal padding for tap area
            child: CircleAvatar(
              radius: 18, // Results in a 36dp diameter circle
              backgroundColor: Theme.of(context).colorScheme.primaryContainer, // Use theme color
              child: Text(
                userName.isNotEmpty ? userName[0].toUpperCase() : 'U',
                style: TextStyle(
                  fontSize: WanzoTypography.fontSizeBase, // Ensure text fits well
                  color: Theme.of(context).colorScheme.onPrimaryContainer, // Use theme color
                  fontWeight: WanzoTypography.fontWeightBold,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}
