import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:badges/badges.dart' as badges;
import '../../../constants/colors.dart';
import '../../../features/auth/bloc/auth_bloc.dart';
import '../../../features/settings/bloc/settings_bloc.dart';
import '../../../features/settings/bloc/settings_event.dart';
import '../../../features/settings/bloc/settings_state.dart';
import '../../../features/settings/models/settings.dart';
import '../../../features/notifications/bloc/notifications_bloc.dart';

/// Header desktop professionnel pour l'application Wanzo
/// Couvre toute la largeur de l'écran avec logo à gauche et profil à droite
class DesktopHeader extends StatelessWidget {
  /// Titre de la page actuelle
  final String title;

  /// Actions additionnelles à afficher
  final List<Widget>? actions;

  /// Callback pour le bouton de retour (null = pas de bouton)
  final VoidCallback? onBackPressed;

  /// Si le sidebar est étendu
  final bool isSidebarExpanded;

  /// Callback pour toggler le sidebar
  final VoidCallback? onToggleSidebar;

  const DesktopHeader({
    super.key,
    required this.title,
    this.actions,
    this.onBackPressed,
    this.isSidebarExpanded = true,
    this.onToggleSidebar,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final authState = context.read<AuthBloc>().state;
    final user = authState is AuthAuthenticated ? authState.user : null;
    final userName = user?.name ?? 'Utilisateur';
    final userEmail = user?.email ?? '';

    return Container(
      height: 64,
      width: double.infinity,
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        boxShadow: [
          BoxShadow(
            color: (isDark ? Colors.black : Colors.grey).withValues(alpha: 0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          // Zone logo + nom app (largeur fixe correspondant au sidebar)
          _buildBrandSection(context, theme, isDark),

          // Séparateur subtil
          Container(
            width: 1,
            height: 40,
            color:
                isDark
                    ? Colors.grey[800]?.withValues(alpha: 0.5)
                    : Colors.grey[300]?.withValues(alpha: 0.5),
          ),

          // Contenu principal du header
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Row(
                children: [
                  // Bouton retour si nécessaire
                  if (onBackPressed != null) ...[
                    IconButton(
                      icon: Icon(
                        Icons.arrow_back,
                        color: theme.colorScheme.onSurface,
                      ),
                      onPressed: onBackPressed,
                      tooltip: 'Retour',
                    ),
                    const SizedBox(width: 8),
                  ],

                  // Titre de la page
                  Text(
                    title,
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),

                  const Spacer(),

                  // Actions personnalisées
                  if (actions != null) ...actions!,

                  const SizedBox(width: 8),

                  // Bouton de notifications
                  _buildNotificationsButton(context, theme),

                  const SizedBox(width: 8),

                  // Divider vertical
                  Container(height: 32, width: 1, color: theme.dividerColor),

                  const SizedBox(width: 16),

                  // Menu utilisateur avec dropdown
                  _buildUserMenu(context, theme, isDark, userName, userEmail),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Section marque avec logo, nom et toggle sidebar
  Widget _buildBrandSection(
    BuildContext context,
    ThemeData theme,
    bool isDark,
  ) {
    // Largeur animée selon l'état du sidebar
    final width = isSidebarExpanded ? 260.0 : 72.0;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      width: width,
      padding: EdgeInsets.symmetric(horizontal: isSidebarExpanded ? 16 : 12),
      child: Row(
        children: [
          // Bouton toggle sidebar
          IconButton(
            icon: Icon(
              isSidebarExpanded ? Icons.menu_open : Icons.menu,
              color: isDark ? Colors.grey[400] : Colors.grey[700],
            ),
            onPressed: onToggleSidebar,
            tooltip: isSidebarExpanded ? 'Réduire le menu' : 'Étendre le menu',
          ),

          if (isSidebarExpanded) ...[
            const SizedBox(width: 8),

            // Logo
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: WanzoColors.primary,
                borderRadius: BorderRadius.circular(8),
                boxShadow: [
                  BoxShadow(
                    color: WanzoColors.primary.withValues(alpha: 0.3),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.asset(
                  'assets/images/logo.jpg',
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    return const Icon(
                      Icons.storefront,
                      color: Colors.white,
                      size: 20,
                    );
                  },
                ),
              ),
            ),

            const SizedBox(width: 12),

            // Nom de l'app
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Wanzo',
                    style: TextStyle(
                      color: theme.colorScheme.onSurface,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    'Business Manager',
                    style: TextStyle(
                      color: theme.colorScheme.onSurfaceVariant,
                      fontSize: 11,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildNotificationsButton(BuildContext context, ThemeData theme) {
    return BlocBuilder<NotificationsBloc, NotificationsState>(
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
                color: theme.colorScheme.onError,
                fontSize: 10,
                fontWeight: FontWeight.bold,
              ),
            ),
            badgeStyle: badges.BadgeStyle(
              badgeColor: theme.colorScheme.error,
              padding: const EdgeInsets.all(4),
            ),
            child: Icon(
              Icons.notifications_outlined,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          onPressed: () => context.go('/notifications'),
          tooltip: 'Notifications',
        );
      },
    );
  }

  Widget _buildUserMenu(
    BuildContext context,
    ThemeData theme,
    bool isDark,
    String userName,
    String userEmail,
  ) {
    return BlocBuilder<SettingsBloc, SettingsState>(
      builder: (context, settingsState) {
        AppThemeMode currentThemeMode = AppThemeMode.system;
        if (settingsState is SettingsLoaded) {
          currentThemeMode = settingsState.settings.themeMode;
        } else if (settingsState is SettingsUpdated) {
          currentThemeMode = settingsState.settings.themeMode;
        }

        return PopupMenuButton<String>(
          offset: const Offset(0, 50),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          onSelected:
              (value) => _handleMenuSelection(context, value, currentThemeMode),
          itemBuilder:
              (BuildContext context) => _buildMenuItems(
                context,
                theme,
                isDark,
                userName,
                userEmail,
                currentThemeMode,
              ),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest.withValues(
                alpha: 0.3,
              ),
              borderRadius: BorderRadius.circular(24),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircleAvatar(
                  radius: 16,
                  backgroundColor: WanzoColors.primary,
                  child: Text(
                    userName.isNotEmpty ? userName[0].toUpperCase() : 'U',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      userName,
                      style: TextStyle(
                        color: theme.colorScheme.onSurface,
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                    if (userEmail.isNotEmpty)
                      Text(
                        userEmail,
                        style: TextStyle(
                          color: theme.colorScheme.onSurfaceVariant,
                          fontSize: 11,
                        ),
                      ),
                  ],
                ),
                const SizedBox(width: 8),
                Icon(
                  Icons.keyboard_arrow_down,
                  color: theme.colorScheme.onSurfaceVariant,
                  size: 20,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  List<PopupMenuEntry<String>> _buildMenuItems(
    BuildContext context,
    ThemeData theme,
    bool isDark,
    String userName,
    String userEmail,
    AppThemeMode currentThemeMode,
  ) {
    return [
      // En-tête du menu avec info utilisateur
      PopupMenuItem<String>(
        enabled: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundColor: WanzoColors.primary,
                  child: Text(
                    userName.isNotEmpty ? userName[0].toUpperCase() : 'U',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 20,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        userName,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: theme.colorScheme.onSurface,
                        ),
                      ),
                      if (userEmail.isNotEmpty)
                        Text(
                          userEmail,
                          style: TextStyle(
                            fontSize: 12,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),

      const PopupMenuDivider(),

      // Profil
      PopupMenuItem<String>(
        value: 'profile',
        child: _buildMenuItem(
          icon: Icons.person_outline,
          label: 'Mon profil',
          color: theme.colorScheme.primary,
        ),
      ),

      // Paramètres
      PopupMenuItem<String>(
        value: 'settings',
        child: _buildMenuItem(
          icon: Icons.settings_outlined,
          label: 'Paramètres',
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),

      const PopupMenuDivider(),

      // Thème avec sous-menu
      PopupMenuItem<String>(
        enabled: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Apparence',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 12,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                _buildThemeOption(
                  context,
                  icon: Icons.light_mode,
                  label: 'Clair',
                  isSelected: currentThemeMode == AppThemeMode.light,
                  onTap: () => _changeTheme(context, AppThemeMode.light),
                ),
                const SizedBox(width: 8),
                _buildThemeOption(
                  context,
                  icon: Icons.dark_mode,
                  label: 'Sombre',
                  isSelected: currentThemeMode == AppThemeMode.dark,
                  onTap: () => _changeTheme(context, AppThemeMode.dark),
                ),
                const SizedBox(width: 8),
                _buildThemeOption(
                  context,
                  icon: Icons.brightness_auto,
                  label: 'Auto',
                  isSelected: currentThemeMode == AppThemeMode.system,
                  onTap: () => _changeTheme(context, AppThemeMode.system),
                ),
              ],
            ),
          ],
        ),
      ),

      const PopupMenuDivider(),

      // Déconnexion
      PopupMenuItem<String>(
        value: 'logout',
        child: _buildMenuItem(
          icon: Icons.logout,
          label: 'Déconnexion',
          color: theme.colorScheme.error,
        ),
      ),
    ];
  }

  Widget _buildMenuItem({
    required IconData icon,
    required String label,
    required Color color,
  }) {
    return Row(
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(width: 12),
        Text(label),
      ],
    );
  }

  Widget _buildThemeOption(
    BuildContext context, {
    required IconData icon,
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);

    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
          decoration: BoxDecoration(
            color:
                isSelected
                    ? WanzoColors.primary.withValues(alpha: 0.1)
                    : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isSelected ? WanzoColors.primary : theme.dividerColor,
              width: isSelected ? 2 : 1,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 20,
                color:
                    isSelected
                        ? WanzoColors.primary
                        : theme.colorScheme.onSurfaceVariant,
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  color:
                      isSelected
                          ? WanzoColors.primary
                          : theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _handleMenuSelection(
    BuildContext context,
    String value,
    AppThemeMode currentThemeMode,
  ) {
    switch (value) {
      case 'profile':
        context.push('/profile');
        break;
      case 'settings':
        context.push('/settings');
        break;
      case 'logout':
        context.read<AuthBloc>().add(const AuthLogoutRequested());
        break;
    }
  }

  void _changeTheme(BuildContext context, AppThemeMode themeMode) {
    context.read<SettingsBloc>().add(
      UpdateDisplaySettings(themeMode: themeMode),
    );
    Navigator.of(context).pop(); // Fermer le menu
  }
}
