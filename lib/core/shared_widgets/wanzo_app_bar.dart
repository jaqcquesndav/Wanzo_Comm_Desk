import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:badges/badges.dart' as badges;
import 'dart:io';
import 'package:go_router/go_router.dart';
import '../../constants/spacing.dart';
import '../../constants/typography.dart';
import '../services/business_context_service.dart';
import '../modules/activity_mode.dart';
import '../../features/auth/bloc/auth_bloc.dart';
import '../utils/logout_confirmation.dart';
import '../../features/settings/bloc/settings_bloc.dart';
import '../../features/settings/bloc/settings_state.dart';
import '../../features/notifications/bloc/notifications_bloc.dart';
import 'adha_logo.dart';
import 'app_bar_actions.dart';
import 'app_bar_fit.dart';

/// AppBar personnalisé et réutilisable pour toute l'application Wanzo.
///
/// Ordre des actions, lu depuis le bord droit : profil, notifications, Adha,
/// menu 3 points, puis au plus deux actions de la page et la pastille du
/// mode. Sur un écran étroit ou avec une grande police, ce qui ne tient plus
/// passe dans le menu 3 points, dans le même ordre ; le profil reste visible.
class WanzoAppBar extends StatelessWidget implements PreferredSizeWidget {
  /// Titre de l'AppBar
  final String title;

  /// Actions propres à la page (au plus deux visibles, le reste replié).
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
    final settingsState = context.watch<SettingsBloc>().state;
    String logoPath = 'assets/images/logo.jpg'; // Logo par défaut

    if (settingsState is SettingsLoaded &&
        settingsState.settings.companyLogo.isNotEmpty) {
      logoPath = settingsState.settings.companyLogo;
    }

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
    final authState = context.read<AuthBloc>().state;
    final user = authState is AuthAuthenticated ? authState.user : null;
    final userName = user?.name ?? 'Utilisateur';

    final activity = BusinessContextService().activityMode;
    final showMode = activity != ActivityMode.retail;
    final page = splitPageActions(additionalActions);

    // Éléments rangés par priorité : notifications, Adha, actions de la
    // page, pastille du mode. Le profil, lui, reste toujours affiché.
    final items = <_HeaderItem>[
      _HeaderItem(
        width: AppBarFit.iconAction,
        widget: _notificationsButton(context),
        entry: HeaderMenuEntry(
          icon: const Icon(Icons.notifications_outlined),
          label: _notificationsLabel(context),
          onTap: () => context.go('/notifications'),
        ),
      ),
      _HeaderItem(
        width: AppBarFit.iconAction,
        widget: const AdhaHeaderButton(),
        entry: HeaderMenuEntry(
          icon: const AdhaLogo(size: 22),
          label: HeaderRules.adhaTooltip,
          onTap: () => context.push('/adha'),
        ),
      ),
      for (final w in page.visible)
        _HeaderItem(
          width: AppBarFit.iconAction,
          widget: w,
          entry: headerEntryOf(w),
          isPage: true,
        ),
      if (showMode)
        _HeaderItem(
          width: AppBarFit.pillWidth(
            context,
            activity.shortLabel,
            const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
            chrome: 20 + 14 + 4 + 8,
          ),
          widget: _modePill(context),
          entry: HeaderMenuEntry(
            icon: const Icon(Icons.tune),
            label: 'Mode : ${activity.label}',
            onTap: () => context.push('/settings'),
          ),
        ),
    ];
    // Un widget de page qui ne se replie pas reste affiché quoi qu'il arrive.
    final rigid = items.where((i) => i.entry == null).toList();
    final flexible = items.where((i) => i.entry != null).toList();
    final hasPageMenu = page.folded.isNotEmpty || page.pageMenu != null;
    final shownCount = AppBarFit.fitCount(
      context,
      hasBack: onBackPressed != null,
      hasLogo: onBackPressed == null,
      reserved: rigid.length * AppBarFit.iconAction +
          (hasPageMenu ? AppBarFit.iconAction : 0),
      menuShown: hasPageMenu,
      widths: [for (final i in flexible) i.width],
    );
    final shown = {...rigid, ...flexible.take(shownCount)};
    final hidden = flexible.skip(shownCount).toList();

    // Menu 3 points : éléments masqués dans l'ordre, les actions de page
    // repliées juste après les autres actions de page.
    final menu = <HeaderMenuEntry>[
      for (final i in hidden.where((i) => !i.isPage && i.widget is! _ModePill))
        i.entry!,
      for (final i in hidden.where((i) => i.isPage)) i.entry!,
      ...page.folded,
      for (final i in hidden.where((i) => i.widget is _ModePill)) i.entry!,
    ];

    bool isShown(_HeaderItem i) => shown.contains(i);
    final modeItem = items.where((i) => i.widget is _ModePill);
    final notifItem = items[0];
    final adhaItem = items[1];

    return AppBar(
      title: Row(
        children: [
          // Logo Wanzo (uniquement sur l'écran principal)
          if (onBackPressed == null)
            Padding(
              padding: const EdgeInsets.only(right: WanzoSpacing.sm),
              child: _getLogo(context),
            ),
          Expanded(
            child: Text(
              title,
              overflow: TextOverflow.ellipsis,
              softWrap: false,
            ),
          ),
        ],
      ),
      leading:
          onBackPressed != null
              ? IconButton(
                icon: const Icon(Icons.arrow_back),
                tooltip: 'Retour',
                onPressed: onBackPressed,
              )
              : null,
      // De gauche à droite : mode, actions de la page, menu 3 points, Adha,
      // notifications, profil.
      actions: [
        for (final i in modeItem)
          if (isShown(i)) i.widget,
        for (final i in items.where((i) => i.isPage))
          if (isShown(i)) i.widget,
        if (menu.isNotEmpty || page.pageMenu != null)
          HeaderOverflowMenu(entries: menu, pageMenu: page.pageMenu),
        if (isShown(adhaItem)) adhaItem.widget,
        if (isShown(notifItem)) notifItem.widget,
        _profileMenu(context, userName),
      ],
    );
  }

  Widget _modePill(BuildContext context) => const _ModePill();

  Widget _notificationsButton(BuildContext context) {
    return BlocBuilder<NotificationsBloc, NotificationsState>(
      builder: (context, state) {
        final unreadCount =
            state is NotificationsLoaded ? state.unreadCount : 0;
        return IconButton(
          key: const ValueKey('app-bar-notifications'),
          tooltip: HeaderRules.notificationsTooltip,
          icon: badges.Badge(
            showBadge: unreadCount > 0,
            badgeContent: Text(
              unreadCount > 9 ? '9+' : unreadCount.toString(),
              style: TextStyle(
                color: Theme.of(context).colorScheme.onError,
                fontSize: 10,
              ),
            ),
            badgeStyle: badges.BadgeStyle(
              badgeColor: Theme.of(context).colorScheme.error,
              padding: const EdgeInsets.all(5),
            ),
            child: const Icon(Icons.notifications_outlined),
          ),
          onPressed: () => context.go('/notifications'),
        );
      },
    );
  }

  /// Menu du compte, toujours tout à droite.
  Widget _profileMenu(
    BuildContext context,
    String userName,
  ) {
    return PopupMenuButton<String>(
      key: const ValueKey('app-bar-profile'),
      tooltip: 'Profil',
      onSelected: (value) async {
        if (value == 'logout') {
          final ok = await confirmLogout(context);
          if (ok && context.mounted) {
            context.read<AuthBloc>().add(const AuthLogoutRequested());
          }
        } else if (value == 'profile') {
          context.push('/profile');
        } else if (value == 'settings') {
          context.push('/settings');
        }
      },
      itemBuilder: (BuildContext context) => [
        PopupMenuItem<String>(
          value: 'profile',
          child: _menuRow(context, Icons.person, 'Profil'),
        ),
        PopupMenuItem<String>(
          value: 'settings',
          child: _menuRow(context, Icons.settings, 'Paramètres'),
        ),
        const PopupMenuDivider(),
        PopupMenuItem<String>(
          value: 'logout',
          child: _menuRow(context, Icons.logout, 'Déconnexion',
              color: Theme.of(context).colorScheme.error),
        ),
      ],
      child: Padding(
        padding: const EdgeInsets.all(WanzoSpacing.sm),
        child: CircleAvatar(
          radius: 18,
          backgroundColor: Theme.of(context).colorScheme.primaryContainer,
          child: Text(
            userName.isNotEmpty ? userName[0].toUpperCase() : 'U',
            textScaler: TextScaler.noScaling,
            style: TextStyle(
              fontSize: WanzoTypography.fontSizeBase,
              color: Theme.of(context).colorScheme.onPrimaryContainer,
              fontWeight: WanzoTypography.fontWeightBold,
            ),
          ),
        ),
      ),
    );
  }

  Widget _menuRow(BuildContext context, IconData icon, String label,
          {Color? color}) =>
      Row(
        children: [
          Icon(icon, color: color ?? Theme.of(context).colorScheme.primary),
          const SizedBox(width: WanzoSpacing.sm),
          Flexible(child: Text(label, overflow: TextOverflow.ellipsis)),
        ],
      );

  String _notificationsLabel(BuildContext context) {
    final state = context.read<NotificationsBloc>().state;
    final n = state is NotificationsLoaded ? state.unreadCount : 0;
    return n > 0 ? 'Notifications (${n > 9 ? '9+' : n})' : 'Notifications';
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}

/// Un élément de l'en-tête et son équivalent dans le menu 3 points.
class _HeaderItem {
  final double width;
  final Widget widget;
  final HeaderMenuEntry? entry;
  final bool isPage;

  const _HeaderItem({
    required this.width,
    required this.widget,
    required this.entry,
    this.isPage = false,
  });
}

/// Pastille du mode d'activité courant (masquée en Boutique). Appui : ouvre
/// les paramètres, où se choisit le mode.
class _ModePill extends StatelessWidget {
  const _ModePill();

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: BusinessContextService(),
      builder: (context, _) {
        final mode = BusinessContextService().activityMode;
        if (mode == ActivityMode.retail) return const SizedBox.shrink();
        final scheme = Theme.of(context).colorScheme;
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
          child: Tooltip(
            message: 'Mode : ${mode.label}, appuyez pour changer',
            child: Material(
              color: scheme.primaryContainer,
              borderRadius: BorderRadius.circular(20),
              child: InkWell(
                borderRadius: BorderRadius.circular(20),
                onTap: () => context.push('/settings'),
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.tune,
                          size: 14, color: scheme.onPrimaryContainer),
                      const SizedBox(width: 4),
                      Text(
                        mode.shortLabel,
                        style: TextStyle(
                          color: scheme.onPrimaryContainer,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
